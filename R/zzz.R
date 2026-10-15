.onLoad <- function(libname, pkgname) {
  op <- options()
  defaults <- list(
    hotshiny.verbose = FALSE,
    hotshiny.hot_reload = FALSE,
    hotshiny.strict = FALSE,
    hotshiny.time_travel = FALSE
  )
  toset <- !(names(defaults) %in% names(op))
  if (any(toset)) options(defaults[toset])
  register_builtin_substitutes()
  invisible(NULL)
}

register_builtin_substitutes <- function() invisible(NULL)
