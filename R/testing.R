# Server testing with shiny::testServer()
#
# testServer() drives a server function through shiny's MockShinySession,
# which is built on shiny's reactive engine: it stores inputs in shiny's
# ReactiveValues, flushes with shiny's flushReact() and fires timers from its
# own mock clock. Objects created by hotShiny's engine would never be flushed
# by it. Server code written with library(hotShiny) therefore runs on shiny's
# engine under testServer(), exactly as the same code written with
# library(shiny) does: for the duration of the test, hotShiny's reactive
# primitives (in its namespace, the attached package and the imports of
# packages that import them) are pointed at shiny's own. This is the inverse
# of the bridge (bridge.R), which points shiny's primitives at hotShiny's
# while a hotShiny app runs.
#
# Without it, the outcome would depend on search-path order: shiny's
# testServer() calls require(shiny), so unqualified calls usually resolve to
# shiny's functions, but hotShiny::reactive() (or library(shiny) before
# library(hotShiny)) would mix engines and fail with "Operation not allowed
# without an active reactive context".

#' Test a server function or module
#'
#' Same interface and behaviour as [shiny::testServer()]. The server code runs
#' on shiny's reactive engine with [shiny::MockShinySession], as it would
#' under `library(shiny)`; hotShiny's reactive functions are routed to shiny's
#' for the duration of the test.
#'
#' @param app,expr,args,session As in [shiny::testServer()].
#' @export
testServer <- function(app = NULL, expr, args = list(), session = MockShinySession$new()) {
  if (bridge_active()) {
    stop("testServer() can't be used while a hotShiny app is running.", call. = FALSE)
  }
  quosure <- rlang::enquo(expr)
  # shiny's testServer() attaches shiny; do it first, behind hotShiny, so the
  # attached shiny does not mask hotShiny (and this function) afterwards.
  pos <- match("package:hotShiny", search())
  if (!is.na(pos) && !"package:shiny" %in% search()) {
    suppressPackageStartupMessages(
      library("shiny", pos = pos + 1L, character.only = TRUE, warn.conflicts = FALSE)
    )
  }
  restore <- use_shiny_engine()
  on.exit(restore(), add = TRUE)
  rlang::inject(shiny::testServer(app, !!quosure, args = args, session = session))
}

# Names of hotShiny's reactive primitives that have a shiny counterpart.
engine_functions <- function() {
  setdiff(names(bridged_functions()),
          c("getCurrentContext", "hasCurrentContext", "runApp", "shinyApp",
            "shinyAppDir", "shinyAppFile", "stopApp", "isRunning"))
}

# Point every binding of hotShiny's reactive primitives at shiny's originals;
# returns a function that undoes it.
use_shiny_engine <- function() {
  hs_ns <- asNamespace("hotShiny")
  envs <- list(hs_ns)
  if ("package:hotShiny" %in% search()) envs <- c(envs, as.environment("package:hotShiny"))
  for (pkg in setdiff(loadedNamespaces(), c("shiny", "hotShiny", "base"))) {
    imports <- tryCatch(parent.env(asNamespace(pkg)), error = function(e) NULL)
    if (!is.null(imports) && !identical(imports, .BaseNamespaceEnv)) envs <- c(envs, imports)
  }
  saved <- list()
  for (name in engine_functions()) {
    ours <- get(name, envir = hs_ns, inherits = FALSE)
    theirs <- shiny_original(name)
    for (env in envs) {
      if (!exists(name, envir = env, inherits = FALSE)) next
      if (!identical(get(name, envir = env, inherits = FALSE), ours)) next
      saved[[length(saved) + 1L]] <- list(env = env, name = name, value = ours)
      replace_binding(env, name, theirs)
    }
  }
  function() {
    for (s in rev(saved)) try(replace_binding(s$env, s$name, s$value), silent = TRUE)
    invisible(NULL)
  }
}
