# The hotShiny server: HTTP routes, the websocket protocol and the event loop.

.hs_server <- new.env(parent = emptyenv())

#' Create a Shiny app object
#'
#' Same interface as [shiny::shinyApp()]. The result is a regular
#' `shiny.appobj` (so tools that expect one keep working) that hotShiny runs
#' on its own engine.
#'
#' @param ui The UI definition (a tag object, or a function of the request).
#' @param server The server function.
#' @param onStart A function called before the app starts.
#' @param options Named list of app options (e.g. `port`).
#' @param uiPattern A regular expression for the UI path.
#' @param enableBookmarking Not supported; must be `NULL` or `"disable"`.
#' @export
shinyApp <- function(ui, server, onStart = NULL, options = list(), uiPattern = "/",
                     enableBookmarking = NULL) {
  if (!is.function(server)) stop("`server` must be a function", call. = FALSE)
  if (!is.null(enableBookmarking) && !identical(enableBookmarking, "disable")) {
    warning("hotShiny does not support bookmarking; enableBookmarking is ignored.", call. = FALSE)
  }
  app <- shiny_original("shinyApp")(ui, server, onStart = onStart, options = options,
                                       uiPattern = uiPattern)
  app$hotshiny <- list(ui = ui, server = server)
  class(app) <- c("hotshiny.appobj", class(app))
  app
}

#' @export
print.hotshiny.appobj <- function(x, ...) {
  opts <- x$options %||% list()
  args <- opts[intersect(names(opts), c("port", "launch.browser", "host", "quiet",
                                         "display.mode", "test.mode"))]
  do.call(runApp, c(list(x), args))
}

#' @rdname shinyApp
#' @param appDir A directory containing `app.R`, or `ui.R` and `server.R`.
#' @export
shinyAppDir <- function(appDir, options = list()) {
  appDir <- normalizePath(appDir, mustWork = TRUE)
  loaded <- load_app_dir(appDir)
  loaded$options <- utils::modifyList(loaded$options %||% list(), options)
  loaded
}

#' @rdname shinyApp
#' @param appFile Path to an app file.
#' @export
shinyAppFile <- function(appFile, options = list()) {
  appFile <- normalizePath(appFile, mustWork = TRUE)
  app <- source_app_file(appFile)
  app$options <- utils::modifyList(app$options %||% list(), options)
  app$hotshiny$appFile <- appFile
  app$hotshiny$appDir <- dirname(appFile)
  app
}

# Source an app file in a fresh environment; its value must be an app object.
source_app_file <- function(file) {
  env <- new.env(parent = globalenv())
  old_wd <- setwd(dirname(file))
  on.exit(setwd(old_wd), add = TRUE)
  exprs <- parse(file, keep.source = TRUE, encoding = "UTF-8")
  value <- NULL
  for (e in exprs) value <- withVisible(eval(e, env))$value
  if (!inherits(value, "shiny.appobj")) {
    if (is.list(value) && !is.null(value$ui) && !is.null(value$server)) {
      value <- shinyApp(value$ui, value$server)
    } else {
      stop(file, " did not return a shiny app object (the last expression should be shinyApp(...)).",
           call. = FALSE)
    }
  }
  as_hotshiny_app(value)
}

# Load app.R, or the ui.R/server.R(/global.R) layout.
load_app_dir <- function(dir) {
  app_file <- file.path(dir, "app.R")
  if (file.exists(app_file)) {
    app <- source_app_file(app_file)
    app$hotshiny$appFile <- app_file
    app$hotshiny$appDir <- dir
    return(app)
  }
  ui_file <- file.path(dir, "ui.R")
  server_file <- file.path(dir, "server.R")
  if (!file.exists(server_file)) stop("No app.R or server.R found in ", dir, call. = FALSE)
  env <- new.env(parent = globalenv())
  old_wd <- setwd(dir)
  on.exit(setwd(old_wd), add = TRUE)
  src <- function(f) {
    value <- NULL
    for (e in parse(f, keep.source = TRUE, encoding = "UTF-8")) value <- withVisible(eval(e, env))$value
    value
  }
  if (file.exists(file.path(dir, "global.R"))) src(file.path(dir, "global.R"))
  ui <- if (file.exists(ui_file)) src(ui_file) else NULL
  server <- src(server_file)
  if (is.null(ui) && file.exists(file.path(dir, "www", "index.html"))) {
    ui <- htmltools::htmlTemplate(file.path(dir, "www", "index.html"))
  }
  app <- shinyApp(ui, server)
  app$hotshiny$appDir <- dir
  app
}

# Accept app objects built by shiny::shinyApp() too (UI via its httpHandler,
# server via serverFuncSource()).
as_hotshiny_app <- function(app) {
  if (inherits(app, "hotshiny.appobj")) return(app)
  app$hotshiny <- list(ui = NULL, server = NULL, foreign = TRUE)
  class(app) <- c("hotshiny.appobj", class(app))
  app
}

app_server_function <- function(app) {
  app$hotshiny$server %||% app$serverFuncSource()
}

#' Run a Shiny application on hotShiny
#'
#' Same interface as [shiny::runApp()], plus switches for hotShiny's
#' development subsystems. Apps keep using only the Shiny API; the subsystems
#' are enabled here (or through options), never inside the app file, so the
#' same app runs under plain shiny unchanged.
#'
#' @param appDir An app object, a directory with `app.R` (or `ui.R` and
#'   `server.R`), or the path of an app file.
#' @param port,host,launch.browser,quiet,display.mode,test.mode,workerId As in
#'   [shiny::runApp()].
#' @param hot_reload Watch the app's source files and hot-reload changes into
#'   running sessions, preserving inputs and reactive state. Defaults to
#'   `getOption("hotshiny.hot_reload", FALSE)`.
#' @param strict Enable strict mode (warn about side effects in reactive
#'   code). Defaults to `getOption("hotshiny.strict", FALSE)`.
#' @param time_travel Record reactive events for inspection with
#'   [reactive_history()]. Defaults to `getOption("hotshiny.time_travel", FALSE)`.
#' @param watch Extra files or directories to watch when hot reload is on.
#' @param tailwind Load Tailwind CSS (shiny.tailwind's CDN build) into the
#'   page without touching the app's code; [publish_to_shiny()] adds the
#'   equivalent `shiny.tailwind::use_tailwind()` call to published apps.
#'   Defaults to `getOption("hotshiny.tailwind", FALSE)`.
#' @export
runApp <- function(appDir = getwd(),
                   port = getOption("shiny.port"),
                   launch.browser = getOption("shiny.launch.browser", interactive()),
                   host = getOption("shiny.host", "127.0.0.1"),
                   workerId = "", quiet = FALSE,
                   display.mode = c("auto", "normal", "showcase"),
                   test.mode = getOption("shiny.testmode", FALSE),
                   hot_reload = getOption("hotshiny.hot_reload", FALSE),
                   strict = getOption("hotshiny.strict", FALSE),
                   time_travel = getOption("hotshiny.time_travel", FALSE),
                   watch = NULL,
                   tailwind = getOption("hotshiny.tailwind", FALSE)) {
  if (isTRUE(.hs_server$running)) stop("Can't call `runApp()` from within `runApp()`.", call. = FALSE)

  # Route shiny's reactive primitives to hotShiny before the app's code runs,
  # so reactives created at the top level of app.R/global.R live on our engine.
  install_bridge()
  on.exit(uninstall_bridge(), add = TRUE)

  app <- if (inherits(appDir, "shiny.appobj")) {
    as_hotshiny_app(appDir)
  } else if (is.list(appDir) && !is.null(appDir$ui) && !is.null(appDir$server)) {
    shinyApp(appDir$ui, appDir$server)
  } else if (is.character(appDir) && length(appDir) == 1 && dir.exists(appDir)) {
    shinyAppDir(appDir)
  } else if (is.character(appDir) && length(appDir) == 1 && file.exists(appDir)) {
    shinyAppFile(appDir)
  } else {
    stop("appDir must be an app object, an app directory or an app file", call. = FALSE)
  }

  port <- port %||% app$options$port %||% random_port(host)
  server <- HotServer$new(app, test_mode = isTRUE(test.mode), hot_reload = isTRUE(hot_reload),
                          strict = isTRUE(strict), time_travel = isTRUE(time_travel),
                          watch = watch, tailwind = isTRUE(tailwind))
  server$run(host = host, port = as.integer(port), launch.browser = launch.browser, quiet = quiet)
}

random_port <- function(host) {
  for (i in 1:20) {
    port <- sample(3000:8000, 1)
    if (port %in% c(3659, 4045, 5060, 5061, 6000, 6566, 6665:6669, 6697)) next
    ok <- tryCatch({
      srv <- httpuv::startServer(host, port, list())
      httpuv::stopServer(srv)
      TRUE
    }, error = function(e) FALSE)
    if (ok) return(port)
  }
  stop("Failed to find a free port", call. = FALSE)
}

#' Stop the running app
#'
#' Same as [shiny::stopApp()].
#' @param returnValue The value [runApp()] returns.
#' @export
stopApp <- function(returnValue = invisible()) {
  srv <- .hs_server$current
  if (is.null(srv)) {
    return(shiny_original("stopApp")(returnValue))
  }
  srv$stop(returnValue)
  invisible(NULL)
}

#' @rdname stopApp
#' @export
isRunning <- function() isTRUE(.hs_server$running) || shiny_original("isRunning")()

last_session <- function() {
  srv <- .hs_server$current
  if (is.null(srv)) return(NULL)
  srv$last_session()
}

request_service <- function() {
  .hs_server$service_requested <- TRUE
  invisible(NULL)
}

#' The running hotShiny server
#'
#' Returns the server object of the app started by [runApp()] in this R
#' process (or `NULL`). Useful for tooling: `$sessions()`, `$reload()`.
#' @export
running_server <- function() .hs_server$current

HotServer <- R6::R6Class("HotServer",
  cloneable = FALSE,
  public = list(
    app = NULL,
    options = NULL,
    test_mode = FALSE,
    hot_reload = FALSE,
    strict = FALSE,
    time_travel = FALSE,
    watch = NULL,
    tailwind = FALSE,
    url = NULL,

    initialize = function(app, test_mode = FALSE, hot_reload = FALSE, strict = FALSE,
                          time_travel = FALSE, watch = NULL, tailwind = FALSE) {
      self$tailwind <- tailwind
      self$app <- app
      self$test_mode <- test_mode
      self$hot_reload <- hot_reload
      self$strict <- strict
      self$time_travel <- time_travel
      self$watch <- watch
      private$session_map <- fastmap::fastmap()
      private$needs_flush <- fastmap::fastmap()
    },

    run = function(host, port, launch.browser = FALSE, quiet = FALSE) {
      shiny_internal("initCurrentAppState")(self$app)
      on.exit(shiny_internal("clearCurrentAppState")(), add = TRUE)
      # bindCache(cache = "app"), the default, resolves to this option; shiny
      # provides the same 200MB memory cache unless the app configured one.
      if (is.null(shiny::getShinyOption("cache", default = NULL))) {
        shiny::shinyOptions(cache = cachem::cache_mem(max_size = 200 * 1024^2))
      }
      if (length(self$app$options)) {
        shiny::shinyOptions(!!!self$app$options[setdiff(names(self$app$options), "port")])
      }
      if (self$test_mode) shiny::shinyOptions(testmode = TRUE)
      self$options <- shiny_internal("getCurrentAppState")()$options

      .hs_server$current <- self
      .hs_server$running <- TRUE
      install_bridge()
      on.exit({
        .hs_server$running <- FALSE
        .hs_server$current <- NULL
      }, add = TRUE)

      if (is.function(self$app$onStart)) self$app$onStart()
      on.exit(shiny_internal(".globals")$onStopCallbacks$invoke(onError = print_error), add = TRUE)

      if (self$strict) enable_strict_mode()
      if (self$hot_reload) private$start_hot_reload()

      private$httpuv <- httpuv::startServer(host, port, list(
        call = function(req) self$handle_http(req),
        onWSOpen = function(ws) self$handle_ws(ws)
      ))
      on.exit({
        for (s in private$session_map$as_list()) try(s$close(), silent = TRUE)
        httpuv::stopServer(private$httpuv)
        if (!is.null(private$reloader)) private$reloader$stop()
      }, add = TRUE)

      display_host <- if (host %in% c("0.0.0.0", "::")) "127.0.0.1" else host
      self$url <- sprintf("http://%s:%d", display_host, port)
      if (!quiet) message("\nListening on ", self$url)
      if (self$hot_reload && !quiet) log_info("hot reload enabled")
      if (isTRUE(launch.browser)) utils::browseURL(self$url)
      else if (is.function(launch.browser)) launch.browser(self$url)

      private$stopped <- FALSE
      while (!private$stopped) {
        httpuv::service(100)
        self$service()
      }
      private$return_value
    },

    stop = function(value = invisible()) {
      private$stopped <- TRUE
      private$return_value <- value
    },

    # Run pending observers, then send every session's pending outputs.
    service = function() {
      .hs_server$service_requested <- FALSE
      tryCatch(flush_react(), error = function(e) print_error(e))
      for (s in private$needs_flush$as_list()) {
        tryCatch(s$flushOutput(), error = function(e) {
          print_error(e)
          s$close()
        })
      }
      invisible(NULL)
    },

    request_flush = function(session) private$needs_flush$set(session$token, session),
    unrequest_flush = function(session) private$needs_flush$remove(session$token),

    sessions = function() private$session_map$as_list(),

    last_session = function() {
      s <- private$session_map$as_list()
      if (length(s)) s[[length(s)]] else NULL
    },

    # -- HTTP --------------------------------------------------------------------

    handle_http = function(req) {
      res <- tryCatch(private$route(req), error = function(e) {
        print_error(e)
        http_response(500, "text/plain", paste("Internal error:", conditionMessage(e)))
      })
      private$to_rook(res)
    },

    # -- websocket ---------------------------------------------------------------

    handle_ws = function(ws) {
      bridge_loaded_packages()
      session <- HotSession$new(ws, self)
      private$session_map$set(session$token, session)
      ws$onMessage(function(binary, msg) {
        tryCatch(private$on_message(session, binary, msg), error = function(e) {
          print_error(e)
        })
        self$service()
      })
      ws$onClose(function() {
        session$wsClosed()
        private$session_map$remove(session$token)
        private$needs_flush$remove(session$token)
      })
      invisible(NULL)
    },

    # Re-run the (possibly new) server function in every live session.
    reload_sessions = function(ui_changed = TRUE) {
      for (s in private$session_map$as_list()) hot_reload_session(self, s, ui_changed)
      self$service()
    },

    # Render the UI page for a request (also used by hot reload).
    render_ui = function(req = NULL) {
      req <- req %||% fake_request()
      if (self$hot_reload && !is.null(self$app$hotshiny$ui) &&
          identical(req$REQUEST_METHOD, "GET") && identical(req$PATH_INFO, "/")) {
        html <- render_dev_page(self$app, req, self$test_mode)
        if (inherits(html, "httpResponse") || is.null(html)) return(html)
        return(http_response(200, content = html))
      }
      shiny::withReactiveDomain(NULL, self$app$httpHandler(req))
    }
  ),

  private = list(
    httpuv = NULL,
    session_map = NULL,
    needs_flush = NULL,
    stopped = FALSE,
    return_value = NULL,
    reloader = NULL,

    on_message = function(session, binary, msg) {
      shiny::withReactiveDomain(session, {
        if (is.character(msg)) msg <- charToRaw(msg)
        trace <- getOption("shiny.trace", FALSE)
        if (isTRUE(trace) || identical(trace, "recv")) {
          message("RECV ", if (binary) "$$binary data$$" else rawToChar(msg))
        }
        if (identical(as.raw(c(0x03, 0xe9)), msg)) return(invisible(NULL))
        msg <- shiny_internal("decodeMessage")(msg)
        msg$data <- shiny_internal("applyInputHandlers")(msg$data, session)
        switch(msg$method,
          init = {
            session$manageInputs(msg$data, now = TRUE)
            if (!is.null(msg$data$.clientdata_singletons)) {
              session$singletons <- strsplit(msg$data$.clientdata_singletons, ",")[[1]]
            }
            run_server_function(app_server_function(self$app), session)
          },
          update = session$manageInputs(msg$data),
          session$dispatch(msg)
        )
        session$requestFlush()
      })
    },

    route = function(req) {
      path <- req$PATH_INFO %||% "/"
      method <- req$REQUEST_METHOD

      if (startsWith(path, "/session/")) {
        m <- regmatches(path, regexec("^/session/([^/]+)(/.*)$", path))[[1]]
        if (length(m)) {
          s <- private$session_map$get(m[2])
          if (is.null(s)) return(http_response(404, "text/html", "<h1>Not Found</h1>"))
          sub <- as.environment(as.list(req, all.names = TRUE))
          sub$PATH_INFO <- m[3]
          return(s$handleRequest(sub))
        }
      }

      ui_res <- tryCatch(self$render_ui(req), error = function(e) {
        print_error(e)
        http_response(500, "text/html", paste0("<pre>", htmltools::htmlEscape(conditionMessage(e)), "</pre>"))
      })
      if (!is.null(ui_res)) return(private$decorate_page(ui_res))

      if (method %in% c("GET", "HEAD")) {
        f <- private$static_file(utils::URLdecode(path))
        if (!is.null(f)) return(f)
      }
      http_response(404, "text/html", "<h1>Not Found</h1>")
    },

    # Inject the hot-reload client into the page when hot reload is on.
    decorate_page = function(res) {
      if (!is.character(res$content) || !grepl("text/html", res$content_type)) return(res)
      inject <- character(0)
      if (self$tailwind && !grepl("cdn.tailwindcss.com", res$content, fixed = TRUE)) {
        inject <- c(inject, as.character(shiny.tailwind_cdn()))
      }
      if (self$hot_reload) {
        inject <- c(inject, '<script src="__hotshiny__/hotshiny-dev.js" data-hotshiny-dev></script>')
      }
      if (length(inject)) {
        res$content <- sub("</head>", paste0(paste(inject, collapse = "\n"), "\n</head>"),
                           res$content, fixed = TRUE)
      }
      res
    },

    static_file = function(path) {
      parts <- strsplit(sub("^/", "", path), "/", fixed = TRUE)[[1]]
      if (length(parts) == 0 || any(parts %in% c("..", "."))) return(NULL)
      prefix <- parts[1]
      rest <- paste(parts[-1], collapse = "/")
      roots <- c(
        `__hotshiny__` = system.file("www", package = "hotShiny"),
        shared = system.file("www", "shared", package = "shiny"),
        unlist(shiny::resourcePaths())
      )
      if (prefix %in% names(roots) && nzchar(rest)) {
        f <- file.path(roots[[prefix]], rest)
        if (file.exists(f) && !dir.exists(f)) return(file_response(f))
      }
      www <- file.path(self$app$hotshiny$appDir %||% getwd(), "www")
      f <- file.path(www, paste(parts, collapse = "/"))
      if (dir.exists(www) && file.exists(f) && !dir.exists(f)) return(file_response(f))
      NULL
    },

    to_rook = function(res) {
      if (is_promise(res)) return(promises::then(res, function(r) private$to_rook(r)))
      if (!inherits(res, "httpResponse")) return(res)
      body <- res$content
      if (is.list(body) && !is.null(body$file)) {
        file <- body$file
        size <- file.info(file)$size
        bytes <- readBin(file, "raw", n = size)
        if (isTRUE(body$owned)) unlink(file)
        body <- bytes
      } else if (inherits(body, "shiny.tag") || inherits(body, "shiny.tag.list")) {
        body <- as.character(body)
      }
      if (is.character(body)) body <- enc2utf8(paste(body, collapse = "\n"))
      headers <- as.list(res$headers %||% list())
      headers[["Content-Type"]] <- res$content_type
      list(status = res$status, headers = headers, body = body)
    },

    start_hot_reload = function() {
      private$reloader <- HotReloader$new(self, extra = self$watch)
      private$reloader$start()
    }
  )
)

# The script tag shiny.tailwind::use_tailwind() emits (CDN build with the
# forms/typography/aspect-ratio/line-clamp plugins).
shiny.tailwind_cdn <- function() {
  if (requireNamespace("shiny.tailwind", quietly = TRUE)) {
    return(htmltools::doRenderTags(shiny.tailwind::use_tailwind()))
  }
  "<script src='https://cdn.tailwindcss.com?plugins=forms,typography,aspect-ratio,line-clamp'></script>"
}

file_response <- function(path) {
  size <- file.info(path)$size
  http_response(200, content_type(path), readBin(path, "raw", n = size),
                list(`Cache-Control` = "no-cache"))
}

fake_request <- function() {
  req <- new.env()
  req$REQUEST_METHOD <- "GET"
  req$PATH_INFO <- "/"
  req$QUERY_STRING <- ""
  req$HTTP_HOST <- "localhost"
  req$SERVER_NAME <- "localhost"
  req
}

run_server_function <- function(server, session) {
  args <- list(input = session$input, output = session$output)
  formals_names <- names(formals(server))
  if ("clientData" %in% formals_names) args$clientData <- session$clientData
  if ("session" %in% formals_names) args$session <- session
  shiny::withReactiveDomain(session, do.call(server, args))
  invisible(NULL)
}
