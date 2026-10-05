# Hot reload
#
# When a watched source file changes:
#   1. The app's source is re-loaded (app.R, or ui.R/server.R/global.R).
#   2. For every live session, the values of all reactiveVal()/reactiveValues()
#      objects are snapshotted by their stable graph id; every observer and
#      output created by the old server function is destroyed.
#   3. The new UI is rendered (with structural keys, see below) and sent to the
#      client, which swaps only the subtrees that changed.
#   4. The new server function runs in the *same* session: inputs, clientData,
#      userData and the connection survive, and reactive values whose ids match
#      are restored instead of re-initialised.
#
# In dev mode every UI element carries a `data-hs-key` attribute holding its
# position in the UI tree, which is what lets the client map the freshly
# rendered page onto the live DOM even after widgets (selectize,
# ion.rangeSlider, ...) have rewritten parts of it. Keys are only added when
# hot reload is enabled.

# -- reactive state preservation -------------------------------------------------

.hs_app_hot <- new.env(parent = emptyenv())
.hs_app_hot$registry <- list()
.hs_app_hot$restore <- NULL
.hs_app_hot$observers <- list()

hot_store <- function(domain) {
  s <- root_session(domain)
  if (!is.null(s)) s$hot else .hs_app_hot
}

hot_state_initial <- function(domain, node, value) {
  store <- hot_store(domain)
  restore <- store$restore
  if (!is.null(restore) && node %in% names(restore)) return(restore[[node]])
  value
}

hot_state_register <- function(domain, node, getter) {
  store <- hot_store(domain)
  store$registry[[node]] <- getter
  invisible(NULL)
}

hot_track_observer <- function(domain, observer) {
  store <- hot_store(domain)
  store$observers[[observer$node]] <- observer
  invisible(NULL)
}

new_hot_store <- function(restore = NULL) {
  e <- new.env(parent = emptyenv())
  e$registry <- list()
  e$restore <- restore
  e$observers <- list()
  e
}

snapshot_hot_state <- function(store) {
  lapply(store$registry, function(getter) tryCatch(getter(), error = function(e) NULL))
}

# -- UI keying ---------------------------------------------------------------------

key_ui <- function(x, path = "k") {
  if (inherits(x, "shiny.tag")) {
    if (is.null(x$attribs[["data-hs-key"]])) x$attribs[["data-hs-key"]] <- path
    if (length(x$children)) {
      x$children <- key_children(x$children, path)
    }
    return(x)
  }
  if (inherits(x, "shiny.tag.list") || (is.list(x) && !is.object(x))) {
    attrs <- attributes(x)
    out <- key_children(x, path)
    attributes(out) <- attrs
    return(out)
  }
  x
}

key_children <- function(children, path) {
  i <- 0L
  lapply(children, function(child) {
    if (inherits(child, "shiny.tag") || inherits(child, "shiny.tag.list") ||
        (is.list(child) && !is.object(child))) {
      i <<- i + 1L
      key_ui(child, paste0(path, ".", i))
    } else {
      child
    }
  })
}

# Render the page for dev mode: same as shiny's renderPage(), but with
# structural keys and a fixed RNG seed so random tab ids are stable between
# renders.
render_dev_page <- function(app, req = fake_request(), test_mode = FALSE) {
  ui <- app$hotshiny$ui
  if (is.null(ui)) return(NULL)
  seed <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit({
    if (is.null(seed)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", seed, envir = globalenv())
  }, add = TRUE)
  set.seed(20240901L)
  value <- shiny::withReactiveDomain(NULL, {
    if (is.function(ui)) {
      if (length(formals(ui)) > 0) ui(req) else ui()
    } else {
      ui
    }
  })
  if (is.null(value) || inherits(value, "httpResponse")) return(value)
  value <- htmltools::tagify(value)
  if (!inherits(value, "html_document")) value <- key_ui(value)
  shiny_internal("renderPage")(value, 0, test_mode)
}

# -- reloading ---------------------------------------------------------------------

hot_reload_session <- function(server, session, ui_changed = TRUE, html = NULL) {
  if (session$isClosed()) return(invisible(NULL))
  shiny::withReactiveDomain(session, {
    snapshot <- snapshot_hot_state(session$hot)
    for (o in session$hot$observers) try(o$destroy(), silent = TRUE)
    session$.resetServer()
    session$graph$clear()
    session$hot <- new_hot_store(restore = snapshot)
    if (ui_changed && !is.null(html)) {
      session$sendCustomMessage("hotshiny-reload", list(html = html))
    }
    ok <- tryCatch({
      run_server_function(app_server_function(server$app), session)
      TRUE
    }, error = function(e) {
      print_error(e)
      session$sendCustomMessage("hotshiny-error", list(message = conditionMessage(e)))
      FALSE
    })
    session$hot$restore <- NULL
    if (ok) session$sendCustomMessage("hotshiny-reloaded", list(time = format(Sys.time(), "%H:%M:%S")))
    session$requestFlush()
  })
  invisible(NULL)
}

HotReloader <- R6::R6Class("HotReloader",
  cloneable = FALSE,
  public = list(
    server = NULL,
    interval = 0.4,

    initialize = function(server, extra = NULL, interval = 0.4) {
      self$server <- server
      self$interval <- interval
      app <- server$app
      dirs <- unique(c(app$hotshiny$appDir, extra))
      private$roots <- dirs[!is.na(dirs) & nzchar(dirs)]
      private$mtimes <- private$scan()
    },

    start = function() {
      private$active <- TRUE
      private$schedule()
    },

    stop = function() private$active <- FALSE,

    # Re-load the app's source and push it into every session.
    reload = function(changed = character(0)) {
      server <- self$server
      old <- server$app
      dir <- old$hotshiny$appDir
      if (is.null(dir)) return(invisible(FALSE))
      started <- Sys.time()
      new_app <- tryCatch(
        if (!is.null(old$hotshiny$appFile)) shinyAppFile(old$hotshiny$appFile) else shinyAppDir(dir),
        error = function(e) {
          message("[hotShiny] reload failed: ", conditionMessage(e))
          for (s in server$sessions()) s$sendCustomMessage("hotshiny-error", list(message = conditionMessage(e)))
          NULL
        }
      )
      if (is.null(new_app)) return(invisible(FALSE))
      new_app$options <- old$options
      server$app <- new_app
      bridge_loaded_packages()
      html <- tryCatch(render_dev_page(new_app, test_mode = server$test_mode), error = function(e) {
        message("[hotShiny] UI render failed: ", conditionMessage(e))
        NULL
      })
      if (inherits(html, "httpResponse")) html <- NULL
      for (s in server$sessions()) hot_reload_session(server, s, ui_changed = TRUE, html = html)
      server$service()
      elapsed <- round(as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000)
      log_info("reloaded ", paste(basename(changed), collapse = ", "), " in ", elapsed, "ms")
      invisible(TRUE)
    }
  ),
  private = list(
    roots = character(0),
    mtimes = NULL,
    active = FALSE,

    scan = function() {
      files <- unlist(lapply(private$roots, function(r) {
        if (dir.exists(r)) {
          list.files(r, pattern = "\\.(R|r|css|js|html|md)$", recursive = TRUE, full.names = TRUE)
        } else if (file.exists(r)) r
      }))
      files <- files[!grepl("(^|/)(renv|packrat|node_modules|\\.git)/", files)]
      if (!length(files)) return(stats::setNames(numeric(0), character(0)))
      stats::setNames(as.numeric(file.mtime(files)), files)
    },

    schedule = function() {
      if (!private$active) return(invisible(NULL))
      later::later(function() {
        if (!private$active) return(invisible(NULL))
        now <- private$scan()
        old <- private$mtimes
        changed <- union(setdiff(names(now), names(old)), setdiff(names(old), names(now)))
        common <- intersect(names(now), names(old))
        changed <- c(changed, common[now[common] != old[common]])
        private$mtimes <- now
        if (length(changed)) tryCatch(self$reload(changed), error = function(e) print_error(e))
        private$schedule()
      }, self$interval)
    }
  )
)
