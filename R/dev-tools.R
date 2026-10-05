# Developer subsystems: strict mode, reactive history, and the legacy
# (pre-0.3) entry points kept for backwards compatibility.

# -- strict mode -------------------------------------------------------------------

side_effect_fns <- c(
  "write.csv", "write.table", "writeLines", "saveRDS", "save", "cat", "print",
  "file.create", "file.remove", "unlink", "dir.create", "assign", "<<-",
  "system", "system2", "download.file", "sink"
)

nondeterministic_fns <- c("runif", "rnorm", "sample", "Sys.time", "Sys.Date", "date")

#' Strict mode
#'
#' In strict mode hotShiny inspects every reactive expression the first time
#' it is created and warns about side effects (writing files, printing,
#' global assignment) and non-deterministic calls. Reactive expressions should
#' be pure so that hot reload and time travel can re-run them safely; side
#' effects belong in observers. Usually enabled with
#' `runApp(strict = TRUE)` or `options(hotshiny.strict = TRUE)`.
#'
#' @export
enable_strict_mode <- function() {
  options(hotshiny.strict = TRUE)
  invisible(TRUE)
}

#' @rdname enable_strict_mode
#' @export
disable_strict_mode <- function() {
  options(hotshiny.strict = FALSE)
  invisible(FALSE)
}

#' @rdname enable_strict_mode
#' @param fn A function or expression to check.
#' @return `strict_check()` returns a data frame of findings.
#' @export
strict_check <- function(fn) {
  expr <- if (is.function(fn)) body(fn) else fn
  found <- list()
  walk <- function(e) {
    if (is.call(e)) {
      head <- e[[1]]
      name <- if (is.symbol(head)) as.character(head) else if (is.call(head) &&
        identical(head[[1]], as.name("::"))) as.character(head[[3]]) else ""
      if (identical(name, "isolate")) return(invisible(NULL))
      if (name %in% side_effect_fns) {
        found[[length(found) + 1L]] <<- data.frame(type = "side_effect", call = name)
      } else if (name %in% nondeterministic_fns) {
        found[[length(found) + 1L]] <<- data.frame(type = "nondeterministic", call = name)
      }
      for (arg in as.list(e)[-1]) if (!missing(arg)) walk(arg)
    }
    invisible(NULL)
  }
  walk(expr)
  if (!length(found)) return(data.frame(type = character(0), call = character(0)))
  unique(do.call(rbind, found))
}

strict_warn <- function(fn, label) {
  if (!isTRUE(getOption("hotshiny.strict", FALSE))) return(invisible(NULL))
  issues <- strict_check(fn)
  if (nrow(issues)) {
    warning(sprintf("[hotShiny strict] reactive '%s' calls %s; reactive expressions should be ",
                    label, paste(sprintf("%s() (%s)", issues$call, issues$type), collapse = ", ")),
            "free of side effects. Move them to an observer.", call. = FALSE)
  }
  invisible(NULL)
}

# -- reactive history (time travel) ------------------------------------------------

#' Reactive history
#'
#' When an app runs with `runApp(time_travel = TRUE)`, every reactive event of
#' a session (node creation, evaluation, value writes, input changes, hot
#' reloads) is recorded. `reactive_history()` returns them as a data frame;
#' `replay_inputs()` re-applies the input values recorded up to a given event,
#' rewinding the session to that point.
#'
#' @param session A session; defaults to the most recently connected one.
#' @export
reactive_history <- function(session = NULL) {
  session <- session %||% last_session()
  if (is.null(session)) return(NULL)
  ev <- session$graph$events()
  if (!length(ev)) {
    return(data.frame(time = as.POSIXct(character(0)), event = character(0), node = character(0)))
  }
  data.frame(
    time = do.call(c, lapply(ev, `[[`, "time")),
    event = vapply(ev, `[[`, "", "event"),
    node = vapply(ev, function(e) e$node %||% NA_character_, ""),
    stringsAsFactors = FALSE
  )
}

#' @rdname reactive_history
#' @param upto Index of the last event to replay.
#' @export
replay_inputs <- function(upto, session = NULL) {
  session <- session %||% last_session()
  if (is.null(session)) stop("No session to replay into", call. = FALSE)
  ev <- session$graph$events()[seq_len(upto)]
  values <- list()
  for (e in ev) {
    if (identical(e$event, "set") && startsWith(e$node %||% "", "input:") && !is.null(e$data$key)) {
      values[[e$data$key]] <- e$data$value
    }
  }
  for (id in names(values)) session$sendInputMessage(id, list(value = values[[id]]))
  session$setInputs(values)
  invisible(values)
}

# -- legacy entry points -----------------------------------------------------------

#' Legacy hotShiny entry points
#'
#' `app()`, `enable_hot_reload()` and `enable_time_travel()` are the pre-0.3
#' API. They still work, but apps should now use [shinyApp()] and enable
#' development features from the launcher, e.g.
#' `hotShiny::runApp("app.R", hot_reload = TRUE)`, so the app file runs
#' unchanged under plain shiny.
#'
#' @param ui,server UI and server, as for [shiny::shinyApp()].
#' @param ... Passed to [shinyApp()].
#' @param bootstrap Ignored (the UI is shiny's).
#' @export
app <- function(ui, server, ..., bootstrap = TRUE) {
  a <- shinyApp(ui, server, ...)
  a$runApp <- function(host = "127.0.0.1", port = 3838, ...) {
    runApp(a, host = host, port = port, hot_reload = isTRUE(attr(a, "hot_reload")) ||
             getOption("hotshiny.hot_reload", FALSE), ...)
  }
  a
}

#' @rdname app
#' @param app An app object from [app()].
#' @param watch_paths Ignored; the app directory is watched.
#' @export
enable_hot_reload <- function(app, watch_paths = NULL) {
  options(hotshiny.hot_reload = TRUE)
  invisible(app)
}

#' @rdname app
#' @param max_history Ignored.
#' @export
enable_time_travel <- function(app = NULL, max_history = 5000) {
  options(hotshiny.time_travel = TRUE)
  invisible(app)
}

#' @rdname app
#' @export
disable_time_travel <- function(app = NULL) {
  options(hotshiny.time_travel = FALSE)
  invisible(app)
}
