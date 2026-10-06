# Reactive expressions, observers and the reactive helpers built on them.

# Turn a captured expression into a zero-argument function, so `return()`
# works inside reactive code exactly as it does in shiny.
quo_function <- function(q) {
  rlang::new_function(list(), rlang::quo_get_expr(q), rlang::quo_get_env(q))
}

# Capture `x` the way shiny's reactive()/observe() do: unevaluated by default,
# or pre-quoted (an expression or quosure) when quoted = TRUE.
capture_quo <- function(x_quo, env, quoted, env_missing) {
  if (quoted) {
    x <- rlang::eval_tidy(x_quo)
    if (rlang::is_quosure(x)) return(x)
    return(rlang::new_quosure(x, env))
  }
  if (!env_missing) return(rlang::new_quosure(rlang::quo_get_expr(x_quo), env))
  x_quo
}

short_label <- function(prefix, q) {
  txt <- paste(deparse(rlang::quo_get_expr(q), width.cutoff = 60L), collapse = " ")
  txt <- gsub("\\s+", " ", txt)
  if (nchar(txt) > 60) txt <- paste0(substr(txt, 1, 57), "...")
  sprintf("%s(%s)", prefix, txt)
}

# Reactive expressions --------------------------------------------------------

Observable <- R6::R6Class("Observable",
  cloneable = FALSE,
  public = list(
    .func = NULL,
    .label = NULL,
    .domain = NULL,
    .value = NULL,
    .visible = TRUE,
    .error = FALSE,
    .invalidated = TRUE,
    .running = FALSE,
    .execCount = 0L,
    .dependents = NULL,
    node = NULL,
    graph = NULL,

    initialize = function(func, label = "reactive", domain = current_domain(),
                          node = NULL, graph = NULL) {
      if (length(formals(func)) > 0) {
        rlang::abort(c(
          "Can't make a reactive expression from a function that takes arguments.",
          "Only functions without arguments can become reactive expressions."
        ))
      }
      self$.func <- func
      self$.label <- label
      self$.domain <- domain
      self$node <- node
      self$graph <- graph
      self$.dependents <- Dependents$new(node, graph)
    },

    getValue = function() {
      self$.dependents$register()
      if (self$.invalidated || self$.running) self$.updateValue()
      if (self$.error) stop(self$.value)
      if (self$.visible) self$.value else invisible(self$.value)
    },

    .updateValue = function() {
      ctx <- HsContext$new(self$.domain, self$.label, type = "observable",
                           node = self$node, graph = self$graph)
      ctx$onInvalidate(function() {
        self$.invalidated <- TRUE
        self$.value <- NULL
        self$.error <- FALSE
        self$.dependents$invalidate()
      })
      self$.execCount <- self$.execCount + 1L
      self$.invalidated <- FALSE
      was_running <- self$.running
      self$.running <- TRUE
      on.exit(self$.running <- was_running, add = TRUE)
      if (!is.null(self$graph)) self$graph$begin_run(self$node)
      res <- tryCatch(
        {
          r <- ctx$run(function() withVisible(self$.func()))
          self$.value <- r$value
          self$.visible <- r$visible
          self$.error <- FALSE
          "ok"
        },
        error = function(cond) {
          self$.value <- cond
          self$.error <- TRUE
          self$.visible <- FALSE
          if (inherits(cond, "shiny.silent.error")) "silent" else "error"
        }
      )
      if (!is.null(self$graph)) {
        self$graph$end_run(self$node, res,
                           if (identical(res, "error")) conditionMessage(self$.value))
      }
      invisible(NULL)
    },

    format = function() {
      label <- sprintf("reactive(%s)", self$.label)
      if (self$.error) return(c(label, "(error)"))
      c(label, utils::capture.output(utils::str(self$.value)))
    }
  )
)

new_reactive <- function(func, label, domain, kind = "reactive") {
  strict_warn(func, label)
  graph <- graph_for_domain(domain)
  node <- graph$add_node(kind, label, domain_ns(domain))
  o <- Observable$new(func, label, domain, node, graph)
  structure(
    function() o$getValue(),
    observable = o,
    class = c("reactiveExpr", "reactive", "function")
  )
}

#' Create a reactive expression
#'
#' Same interface and semantics as [shiny::reactive()]: lazily evaluated,
#' cached until one of the reactive values it read changes.
#'
#' @param x An expression (quoted or unquoted).
#' @param env The parent environment for the expression.
#' @param quoted Is `x` a quoted expression?
#' @param ... Not used.
#' @param label A label for the reactive graph.
#' @param domain The reactive domain (session).
#' @param ..stacktraceon Ignored; kept for signature compatibility.
#' @export
reactive <- function(x, env = parent.frame(), quoted = FALSE, ..., label = NULL,
                     domain = shiny::getDefaultReactiveDomain(), ..stacktraceon = TRUE) {
  q <- capture_quo(rlang::enquo0(x), env, quoted, missing(env))
  if (is.null(label)) label <- infer_label(sys.call(), short_label("reactive", q))
  label <- label_with_srcref(label, rlang::quo_get_expr(q), "reactive")
  new_reactive(quo_function(q), label, domain)
}

# Observers ---------------------------------------------------------------------

Observer <- R6::R6Class("Observer",
  cloneable = FALSE,
  public = list(
    .func = NULL,
    .label = NULL,
    .domain = NULL,
    .priority = 0,
    .autoDestroy = FALSE,
    .autoDestroyHandle = NULL,
    .invalidateCallbacks = list(),
    .execCount = 0L,
    .onResume = NULL,
    .suspended = FALSE,
    .destroyed = FALSE,
    .ctx = NULL,
    node = NULL,
    graph = NULL,

    initialize = function(observerFunc, label = "observer", suspended = FALSE,
                          priority = 0, domain = current_domain(), autoDestroy = TRUE,
                          kind = "observer", node_label = label) {
      if (length(formals(observerFunc)) > 0) {
        rlang::abort(c(
          "Can't make an observer from a function that takes arguments.",
          "Only functions without arguments can become observers."
        ))
      }
      self$.func <- observerFunc
      self$.label <- label
      self$.domain <- domain
      self$.priority <- normalize_priority(priority)
      self$.suspended <- isTRUE(suspended)
      self$.onResume <- function() NULL
      self$graph <- graph_for_domain(domain)
      self$node <- self$graph$add_node(kind, node_label, domain_ns(domain))
      self$setAutoDestroy(autoDestroy)
      hot_track_observer(domain, self)
      self$.createContext()$invalidate()
    },

    .createContext = function() {
      ctx <- HsContext$new(self$.domain, self$.label, type = "observer",
                           node = self$node, graph = self$graph)
      self$.ctx <- ctx
      ctx$onInvalidate(function() {
        self$.ctx <- NULL
        for (cb in self$.invalidateCallbacks) cb()
        continue <- function() {
          ctx$addPendingFlush(self$.priority)
          if (!is.null(self$.domain)) self$.domain$incrementBusyCount()
        }
        if (!self$.suspended) continue() else self$.onResume <- continue
      })
      ctx$onFlush(function() {
        on.exit(if (!is.null(self$.domain)) self$.domain$decrementBusyCount(), add = TRUE)
        if (self$.destroyed) return(invisible(NULL))
        self$.runSafely()
      })
      ctx
    },

    .runSafely = function() {
      if (!is.null(self$graph)) self$graph$begin_run(self$node)
      status <- "ok"
      err <- NULL
      result <- tryCatch(self$run(), error = function(e) {
        if (rlang::cnd_inherits(e, "shiny.silent.error")) {
          status <<- "silent"
          return(NULL)
        }
        status <<- "error"
        err <<- conditionMessage(e)
        print_error(e)
        session <- root_session(self$.domain)
        if (!is.null(session)) session$unhandledError(e, close = TRUE)
        NULL
      })
      if (is_promise(result)) {
        if (!is.null(self$.domain)) self$.domain$incrementBusyCount()
        promises::finally(
          promises::catch(result, function(e) {
            if (rlang::cnd_inherits(e, "shiny.silent.error")) return(NULL)
            print_error(e)
            session <- root_session(self$.domain)
            if (!is.null(session)) session$unhandledError(e, close = TRUE)
          }),
          function() if (!is.null(self$.domain)) self$.domain$decrementBusyCount()
        )
      }
      if (!is.null(self$graph)) self$graph$end_run(self$node, status, err)
      invisible(NULL)
    },

    run = function() {
      ctx <- self$.createContext()
      self$.execCount <- self$.execCount + 1L
      ctx$run(self$.func)
    },

    onInvalidate = function(callback) {
      self$.invalidateCallbacks[[length(self$.invalidateCallbacks) + 1L]] <- callback
      invisible(NULL)
    },

    setPriority = function(priority = 0) {
      self$.priority <- normalize_priority(priority)
    },

    setAutoDestroy = function(autoDestroy) {
      old <- self$.autoDestroy
      if (identical(old, autoDestroy)) return(invisible(old))
      self$.autoDestroy <- autoDestroy
      if (autoDestroy) {
        if (!self$.destroyed && !is.null(self$.domain)) {
          if (isTRUE(tryCatch(self$.domain$isEnded(), error = function(e) FALSE))) {
            self$destroy()
          } else {
            self$.autoDestroyHandle <- self$.domain$onEnded(function() self$destroy())
          }
        }
      } else if (is.function(self$.autoDestroyHandle)) {
        self$.autoDestroyHandle()
        self$.autoDestroyHandle <- NULL
      }
      invisible(old)
    },

    suspend = function() {
      self$.suspended <- TRUE
      invisible(NULL)
    },

    resume = function() {
      if (self$.suspended) {
        self$.suspended <- FALSE
        resume <- self$.onResume
        self$.onResume <- function() NULL
        resume()
      }
      invisible(NULL)
    },

    destroy = function() {
      self$suspend()
      if (self$.destroyed) return(invisible(NULL))
      self$.destroyed <- TRUE
      if (is.function(self$.autoDestroyHandle)) {
        self$.autoDestroyHandle()
        self$.autoDestroyHandle <- NULL
      }
      if (!is.null(self$.ctx)) self$.ctx$invalidate()
      if (!is.null(self$graph)) self$graph$remove_node(self$node)
      invisible(NULL)
    }
  )
)

normalize_priority <- function(priority) {
  if (!is.numeric(priority) || length(priority) != 1 || is.na(priority)) {
    stop("priority must be a single number", call. = FALSE)
  }
  priority
}

print_error <- function(e) {
  if (!isTRUE(getOption("show.error.messages", TRUE))) return(invisible(NULL))
  call <- conditionCall(e)
  msg <- conditionMessage(e)
  if (is.null(call)) {
    message("Warning: Error: ", msg)
  } else {
    message("Warning: Error in ", paste(deparse(call, nlines = 1L), collapse = ""), ": ", msg)
  }
  invisible(NULL)
}

#' Create a reactive observer
#'
#' Same interface and semantics as [shiny::observe()].
#'
#' @inheritParams reactive
#' @param suspended Start the observer suspended?
#' @param priority Execution priority (higher runs first).
#' @param autoDestroy Destroy the observer when its session ends?
#' @export
observe <- function(x, env = parent.frame(), quoted = FALSE, ..., label = NULL,
                    suspended = FALSE, priority = 0,
                    domain = shiny::getDefaultReactiveDomain(), autoDestroy = TRUE,
                    ..stacktraceon = TRUE) {
  q <- capture_quo(rlang::enquo0(x), env, quoted, missing(env))
  label <- label %||% infer_label(sys.call(), short_label("observe", q))
  o <- Observer$new(quo_function(q), label = label, suspended = suspended,
                    priority = priority, domain = domain, autoDestroy = autoDestroy)
  invisible(o)
}

is_null_event <- function(value) {
  is.null(value) || (inherits(value, "shinyActionButtonValue") && all(value == 0))
}

#' Event handlers
#'
#' Same interface and semantics as [shiny::observeEvent()] and
#' [shiny::eventReactive()].
#'
#' @param eventExpr The event expression (its value triggers the handler).
#' @param handlerExpr,valueExpr The code to run in response, evaluated in
#'   [isolate()].
#' @param event.env,handler.env,value.env Environments for the expressions.
#' @param event.quoted,handler.quoted,value.quoted Are the expressions quoted?
#' @param ignoreNULL Ignore the event when it is `NULL` (or an unclicked
#'   action button)?
#' @param ignoreInit Ignore the first evaluation?
#' @param once Destroy the observer after its first run?
#' @inheritParams observe
#' @export
observeEvent <- function(eventExpr, handlerExpr,
                         event.env = parent.frame(), event.quoted = FALSE,
                         handler.env = parent.frame(), handler.quoted = FALSE,
                         ..., label = NULL, suspended = FALSE, priority = 0,
                         domain = shiny::getDefaultReactiveDomain(), autoDestroy = TRUE,
                         ignoreNULL = TRUE, ignoreInit = FALSE, once = FALSE) {
  eq <- capture_quo(rlang::enquo0(eventExpr), event.env, event.quoted, missing(event.env))
  hq <- capture_quo(rlang::enquo0(handlerExpr), handler.env, handler.quoted, missing(handler.env))
  label <- label %||% infer_label(sys.call(), short_label("observeEvent", eq))
  event_fn <- quo_function(eq)
  handler_fn <- quo_function(hq)
  initialized <- FALSE
  skip_first <- ignoreInit || hot_restoring(domain)
  o <- NULL
  o <- Observer$new(function() {
    value <- event_fn()
    if (skip_first && !initialized) {
      initialized <<- TRUE
      return(invisible(NULL))
    }
    initialized <<- TRUE
    if (ignoreNULL && is_null_event(value)) return(invisible(NULL))
    if (once) on.exit(o$destroy(), add = TRUE)
    isolate(handler_fn())
  }, label = label, suspended = suspended, priority = priority, domain = domain,
  autoDestroy = autoDestroy, kind = "observer")
  invisible(o)
}

#' @rdname observeEvent
#' @export
eventReactive <- function(eventExpr, valueExpr,
                          event.env = parent.frame(), event.quoted = FALSE,
                          value.env = parent.frame(), value.quoted = FALSE,
                          ..., label = NULL, domain = shiny::getDefaultReactiveDomain(),
                          ignoreNULL = TRUE, ignoreInit = FALSE) {
  eq <- capture_quo(rlang::enquo0(eventExpr), event.env, event.quoted, missing(event.env))
  vq <- capture_quo(rlang::enquo0(valueExpr), value.env, value.quoted, missing(value.env))
  label <- label %||% infer_label(sys.call(), short_label("eventReactive", eq))
  event_fn <- quo_function(eq)
  value_fn <- quo_function(vq)
  new_reactive(event_gate(event_fn, value_fn, ignoreNULL, ignoreInit), label, domain)
}

# Body shared by eventReactive() and bindEvent() on reactives/renderers: take a
# dependency on the event only, then compute the value in isolation.
# `with_dots = TRUE` for render functions, which receive (shinysession, name, ...).
event_gate <- function(event_fn, value_fn, ignoreNULL, ignoreInit, with_dots = FALSE) {
  initialized <- FALSE
  gate <- function() {
    value <- event_fn()
    if (ignoreInit && !initialized) {
      initialized <<- TRUE
      shiny::req(FALSE)
    }
    initialized <<- TRUE
    shiny::req(!ignoreNULL || !is_null_event(value))
  }
  if (with_dots) {
    function(...) {
      gate()
      isolate(value_fn(...))
    }
  } else {
    function() {
      gate()
      isolate(value_fn())
    }
  }
}

#' Make an object respond only to specified reactive events
#'
#' Same interface as [shiny::bindEvent()], for reactive expressions,
#' observers and render functions created with hotShiny or shiny.
#'
#' @param x A reactive expression, observer or render function.
#' @param ... Event expressions.
#' @param ignoreNULL,ignoreInit,once See [observeEvent()].
#' @param label A label for the reactive graph.
#' @export
bindEvent <- function(x, ..., ignoreNULL = TRUE, ignoreInit = FALSE, once = FALSE,
                      label = NULL) {
  qs <- rlang::enquos(...)
  if (length(qs) == 0) rlang::abort("bindEvent() requires at least one event expression.")
  event_fn <- function() {
    vals <- lapply(qs, rlang::eval_tidy)
    if (length(vals) == 1) vals[[1]] else vals
  }
  if (inherits(x, "reactiveExpr")) {
    o <- attr(x, "observable", exact = TRUE)
    if (!inherits(o, "Observable")) rlang::abort("bindEvent() can only bind hotShiny reactive expressions.")
    value_fn <- o$.func
    gated <- event_gate(event_fn, value_fn, ignoreNULL, ignoreInit)
    res <- new_reactive(gated, label %||% o$.label, o$.domain)
    class(res) <- c("reactive.event", class(res))
    return(res)
  }
  if (inherits(x, "Observer")) {
    handler <- x$.func
    initialized <- FALSE
    skip_first <- ignoreInit || hot_restoring(x$.domain)
    x$.func <- function() {
      value <- event_fn()
      if (skip_first && !initialized) {
        initialized <<- TRUE
        return(invisible(NULL))
      }
      initialized <<- TRUE
      if (ignoreNULL && is_null_event(value)) return(invisible(NULL))
      if (once) on.exit(x$destroy(), add = TRUE)
      isolate(handler())
    }
    class(x) <- unique(c("Observer.event", class(x)))
    return(invisible(x))
  }
  if (is.function(x)) {
    gated <- event_gate(event_fn, x, ignoreNULL, ignoreInit, with_dots = TRUE)
    for (a in setdiff(names(attributes(x)), c("class", "srcref"))) {
      attr(gated, a) <- attr(x, a, exact = TRUE)
    }
    class(gated) <- unique(c("shiny.render.function.event", class(x)))
    return(gated)
  }
  rlang::abort("bindEvent() doesn't know how to handle objects of class ", class(x)[1])
}

#' Create a non-reactive scope for an expression
#'
#' Same as [shiny::isolate()]: reads inside `expr` do not create
#' dependencies for the calling reactive context.
#'
#' @param expr An expression.
#' @export
isolate <- function(expr) {
  ctx <- HsContext$new(current_domain(), "[isolate]", type = "isolate")
  on.exit(ctx$invalidate(), add = TRUE)
  ctx$run(function() expr)
}

#' @rdname isolate
#' @export
maskReactiveContext <- function(expr) {
  run_with_context(NULL, function() expr)
}

# Timers ------------------------------------------------------------------------

#' Scheduled invalidation
#'
#' Same interface as [shiny::invalidateLater()] and [shiny::reactiveTimer()].
#'
#' @param millis,intervalMs Milliseconds to wait.
#' @param session The session (domain) the timer belongs to.
#' @export
invalidateLater <- function(millis, session = shiny::getDefaultReactiveDomain()) {
  force(session)
  ctx <- require_context()
  if (!is.null(session) && isTRUE(session$isEnded())) return(invisible(NULL))
  unreg <- NULL
  cancel <- later::later(function() {
    if (is.function(unreg)) unreg()
    if (is.null(session)) {
      ctx$invalidate()
    } else if (!isTRUE(session$isClosed())) {
      session$cycleStartAction(function() ctx$invalidate())
    }
    request_service()
  }, millis / 1000)
  if (!is.null(session)) unreg <- session$onEnded(cancel)
  invisible(NULL)
}

#' @rdname invalidateLater
#' @export
reactiveTimer <- function(intervalMs = 1000, session = shiny::getDefaultReactiveDomain()) {
  force(session)
  deps <- Dependents$new()
  cancel <- NULL
  tick <- function() {
    cancel <<- later::later(tick, intervalMs / 1000)
    if (is.null(session)) {
      deps$invalidate()
    } else if (!isTRUE(session$isClosed())) {
      session$cycleStartAction(function() deps$invalidate())
    }
    request_service()
  }
  cancel <- later::later(tick, intervalMs / 1000)
  if (!is.null(session)) session$onEnded(function() cancel())
  function() {
    deps$register()
    Sys.time()
  }
}

# Rate limiting -----------------------------------------------------------------

#' Slow down a reactive expression
#'
#' Same interface and semantics as [shiny::debounce()] and [shiny::throttle()].
#'
#' @param r A reactive expression.
#' @param millis Milliseconds (a number or a function returning one).
#' @param priority Priority of the internal observers.
#' @param domain The reactive domain.
#' @export
debounce <- function(r, millis, priority = 100, domain = shiny::getDefaultReactiveDomain()) {
  force(r)
  millis_fn <- if (is.function(millis)) millis else { m <- millis; function() m }
  state <- ReactiveValues$new(dedupe = TRUE, label = "debounce")
  state$mset(list(trigger = NULL, when = NULL))
  first_run <- TRUE
  observe({
    try(r(), silent = TRUE)
    if (first_run) {
      first_run <<- FALSE
      return()
    }
    state$set("when", Sys.time() + millis_fn() / 1000)
  }, label = "debounce tracker", domain = domain, priority = priority)
  observe({
    when <- state$get("when")
    if (is.null(when)) return()
    now <- Sys.time()
    if (now >= when) {
      state$set("trigger", (isolate(state$get("trigger")) %||% 0) + 1)
      state$set("when", NULL)
    } else {
      invalidateLater(max(1, as.numeric(difftime(when, now, units = "secs")) * 1000), domain)
    }
  }, label = "debounce timer", domain = domain, priority = priority)
  er <- new_reactive(function() {
    state$get("trigger")
    isolate(r())
  }, label = "debounce result", domain = domain)
  primer <- NULL
  primer <- observe({
    primer$destroy()
    try(er(), silent = TRUE)
  }, label = "debounce primer", domain = domain, priority = priority)
  er
}

#' @rdname debounce
#' @export
throttle <- function(r, millis, priority = 100, domain = shiny::getDefaultReactiveDomain()) {
  force(r)
  millis_fn <- if (is.function(millis)) millis else { m <- millis; function() m }
  state <- ReactiveValues$new(dedupe = TRUE, label = "throttle")
  state$mset(list(trigger = 0, last = NULL, pending = FALSE))
  blackout_left <- function() {
    last <- state$peek("last")
    if (is.null(last)) return(0)
    max(0, millis_fn() - as.numeric(difftime(Sys.time(), last, units = "secs")) * 1000)
  }
  fire <- function() {
    state$set("last", Sys.time())
    state$set("pending", FALSE)
    state$set("trigger", isolate(state$get("trigger")) + 1)
  }
  observe({
    try(r(), silent = TRUE)
    isolate({
      state$set("pending", TRUE)
      if (blackout_left() <= 0) fire()
    })
  }, label = "throttle tracker", domain = domain, priority = priority)
  observe({
    if (!state$get("pending")) return()
    left <- blackout_left()
    if (left > 0) invalidateLater(left, domain) else isolate(fire())
  }, label = "throttle timer", domain = domain, priority = priority)
  new_reactive(function() {
    state$get("trigger")
    isolate(r())
  }, label = "throttle result", domain = domain)
}

# Polling -----------------------------------------------------------------------

#' Reactive polling
#'
#' Same interface as [shiny::reactivePoll()] and [shiny::reactiveFileReader()].
#'
#' @param intervalMillis Polling interval (number or function).
#' @param session The session (domain), or `NULL`.
#' @param checkFunc Cheap function whose value changes when the data changes.
#' @param valueFunc Function returning the actual value.
#' @param filePath Path of the file to read.
#' @param readFunc Function reading the file.
#' @param ... Further arguments to `readFunc`.
#' @export
reactivePoll <- function(intervalMillis, session, checkFunc, valueFunc) {
  interval <- if (is.function(intervalMillis)) intervalMillis else { m <- intervalMillis; function() m }
  cookie <- ReactiveVal$new(isolate(checkFunc()), "reactivePoll cookie")
  observe({
    cookie$set(checkFunc())
    invalidateLater(interval(), session)
  }, label = "reactivePoll", domain = session)
  new_reactive(function() {
    cookie$get()
    valueFunc()
  }, label = "reactivePoll value", domain = session)
}

#' @rdname reactivePoll
#' @export
reactiveFileReader <- function(intervalMillis, session, filePath, readFunc, ...) {
  filePath <- as.character(filePath)
  extra <- list(...)
  reactivePoll(intervalMillis, session,
    function() {
      info <- file.info(filePath)
      paste(info$mtime, info$size)
    },
    function() do.call(readFunc, c(list(filePath), extra))
  )
}

# Freezing ------------------------------------------------------------------------

#' @rdname reactiveVal
#' @param x A reactiveVal.
#' @export
freezeReactiveVal <- function(x) {
  domain <- current_domain()
  if (is.null(domain)) rlang::abort("freezeReactiveVal() must be called from inside a session.")
  if (!inherits(x, "reactiveVal")) rlang::abort("`x` must be a reactiveVal.")
  attr(x, ".impl", exact = TRUE)$freeze(domain)
  invisible(NULL)
}
