# The shiny namespace bridge
#
# Extension packages call shiny's reactive primitives directly
# (`shiny::observe()`, `shiny::reactiveVal()`, or copies imported with
# importFrom(shiny, ...)), and shiny's own helpers (renderPlot(), bindCache(),
# ExtendedTask, ...) call them unqualified from inside shiny's namespace. While
# a hotShiny app runs, the bridge points all of those bindings at hotShiny's
# implementations, so every reactive object in the process lives on one
# engine. The original bindings are restored when the app stops.
#
# Package-specific substitutes (compat-pkg.R) use the same machinery.

bridged_functions <- function() {
  ns <- asNamespace("hotShiny")
  fns <- list(
    reactive = ns$reactive,
    observe = ns$observe,
    observeEvent = ns$observeEvent,
    eventReactive = ns$eventReactive,
    reactiveVal = ns$reactiveVal,
    reactiveValues = ns$reactiveValues,
    isolate = ns$isolate,
    maskReactiveContext = ns$maskReactiveContext,
    invalidateLater = ns$invalidateLater,
    reactiveTimer = ns$reactiveTimer,
    debounce = ns$debounce,
    throttle = ns$throttle,
    reactivePoll = ns$reactivePoll,
    reactiveFileReader = ns$reactiveFileReader,
    bindEvent = ns$bindEvent,
    freezeReactiveVal = ns$freezeReactiveVal,
    makeReactiveBinding = ns$makeReactiveBinding,
    reactiveConsole = ns$reactiveConsole,
    execCount = ns$execCount,
    getCurrentContext = function() require_context(),
    hasCurrentContext = function() has_current_context(),
    runApp = ns$runApp,
    shinyApp = ns$shinyApp,
    shinyAppDir = ns$shinyAppDir,
    shinyAppFile = ns$shinyAppFile,
    stopApp = ns$stopApp,
    isRunning = ns$isRunning
  )
  fns
}

.hs_bridge <- new.env(parent = emptyenv())
.hs_bridge$saved <- list()     # list of list(env, name, value)
.hs_bridge$installed <- FALSE

replace_binding <- function(env, name, value) {
  locked <- bindingIsLocked(name, env)
  if (locked) (get("unlockBinding", baseenv()))(name, env)
  assign(name, value, envir = env)
  if (locked) lockBinding(name, env)
}

patch_env <- function(env, name, value, original) {
  if (!exists(name, envir = env, inherits = FALSE)) return(FALSE)
  current <- get(name, envir = env, inherits = FALSE)
  if (identical(current, value)) return(FALSE)
  if (!identical(current, original)) return(FALSE)
  .hs_bridge$saved[[length(.hs_bridge$saved) + 1L]] <- list(env = env, name = name, value = current)
  replace_binding(env, name, value)
  TRUE
}

# Point shiny's reactive primitives (in shiny's namespace, the attached
# package:shiny, and every loaded package's imports) at hotShiny's.
install_bridge <- function() {
  shiny_ns <- asNamespace("shiny")
  fns <- bridged_functions()
  if (is.null(.hs_bridge$originals)) {
    .hs_bridge$originals <- lapply(stats::setNames(names(fns), names(fns)),
                                   function(n) get0(n, envir = shiny_ns, inherits = FALSE))
  }
  originals <- .hs_bridge$originals
  for (name in names(fns)) {
    orig <- originals[[name]]
    if (is.null(orig)) next
    patch_env(shiny_ns, name, fns[[name]], orig)
    if ("package:shiny" %in% search()) {
      patch_env(as.environment("package:shiny"), name, fns[[name]], orig)
    }
  }
  bridge_loaded_packages()
  apply_package_substitutes()
  .hs_bridge$installed <- TRUE
  invisible(TRUE)
}

# Patch imports environments of loaded packages that hold copies of shiny's
# functions (importFrom(shiny, ...) / import(shiny)). Called at start-up and
# again whenever packages may have been loaded since (app load, new session).
bridge_loaded_packages <- function() {
  fns <- bridged_functions()
  originals <- .hs_bridge$originals
  if (is.null(originals)) return(invisible(FALSE))
  for (pkg in setdiff(loadedNamespaces(), c("shiny", "hotShiny", "base"))) {
    imports <- tryCatch(parent.env(asNamespace(pkg)), error = function(e) NULL)
    if (is.null(imports) || identical(imports, .BaseNamespaceEnv)) next
    for (name in names(fns)) {
      orig <- originals[[name]]
      if (!is.null(orig)) patch_env(imports, name, fns[[name]], orig)
    }
  }
  invisible(TRUE)
}

# The original shiny function, even while the bridge is installed.
shiny_original <- function(name) {
  .hs_bridge$originals[[name]] %||% get(name, envir = asNamespace("shiny"))
}

uninstall_bridge <- function() {
  saved <- rev(.hs_bridge$saved)
  for (s in saved) try(replace_binding(s$env, s$name, s$value), silent = TRUE)
  .hs_bridge$saved <- list()
  .hs_bridge$installed <- FALSE
  invisible(TRUE)
}

#' Is the shiny bridge active?
#'
#' `TRUE` while a hotShiny app is running, i.e. while shiny's reactive
#' primitives are routed to hotShiny's engine.
#' @export
bridge_active <- function() isTRUE(.hs_bridge$installed)

#' @rdname bridge_active
#' @param symbol,env As in [shiny::makeReactiveBinding()].
#' @export
makeReactiveBinding <- function(symbol, env = parent.frame()) {
  if (exists(symbol, envir = env, inherits = FALSE)) {
    initial <- get(symbol, envir = env, inherits = FALSE)
    rm(list = symbol, envir = env, inherits = FALSE)
  } else {
    initial <- NULL
  }
  rv <- ReactiveVal$new(initial, symbol)
  makeActiveBinding(symbol, env = env, function(v) {
    if (missing(v)) rv$get() else rv$set(v)
  })
  invisible(NULL)
}

#' @rdname bridge_active
#' @param enabled Ignored (hotShiny reactives always work at the console).
#' @export
reactiveConsole <- function(enabled) invisible(NULL)

#' @rdname bridge_active
#' @param x A reactive expression or observer.
#' @export
execCount <- function(x) {
  if (inherits(x, "reactiveExpr")) return(attr(x, "observable", exact = TRUE)$.execCount)
  if (inherits(x, "Observer")) return(x$.execCount)
  stop("Unexpected argument to execCount")
}
