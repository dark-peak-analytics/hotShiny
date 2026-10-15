# Package-specific substitutes
#
# Most extension packages work through the generic bridge (bridge.R). The few
# that need a package-specific change register a substitute here: while a
# hotShiny app runs, `pkg::name` is replaced by the substitute (in the
# package's namespace and its exports), and restored when the app stops.
# Substitutes for packages loaded later are applied from a load hook.
#
# See docs/ECOSYSTEM_COMPAT.md for which packages need what.

.hs_substitutes <- new.env(parent = emptyenv())

#' Register a hotShiny substitute for a function of another package
#'
#' While a hotShiny app is running, `pkg::name` is replaced by `replacement`.
#' The original is restored when the app stops.
#'
#' @param pkg Package name.
#' @param name Function name inside `pkg`.
#' @param replacement A function, or a function of the original returning
#'   the replacement (when `wrap = TRUE`).
#' @param wrap If `TRUE`, `replacement(original)` is called to build the
#'   substitute.
#' @export
register_substitute <- function(pkg, name, replacement, wrap = FALSE) {
  key <- paste0(pkg, "::", name)
  .hs_substitutes[[key]] <- list(pkg = pkg, name = name, replacement = replacement, wrap = wrap)
  if (bridge_active() && isNamespaceLoaded(pkg)) apply_package_substitutes(pkg)
  invisible(key)
}

#' @rdname register_substitute
#' @export
registered_substitutes <- function() {
  keys <- sort(ls(.hs_substitutes))
  data.frame(
    package = vapply(keys, function(k) .hs_substitutes[[k]]$pkg, ""),
    name = vapply(keys, function(k) .hs_substitutes[[k]]$name, ""),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

apply_package_substitutes <- function(only = NULL) {
  for (key in ls(.hs_substitutes)) {
    sub <- .hs_substitutes[[key]]
    if (!is.null(only) && !identical(sub$pkg, only)) next
    if (isNamespaceLoaded(sub$pkg)) {
      apply_substitute(sub)
    } else if (!isTRUE(.hs_bridge$hooked[[sub$pkg]])) {
      .hs_bridge$hooked[[sub$pkg]] <- TRUE
      pkg <- sub$pkg
      setHook(packageEvent(pkg, "onLoad"), function(...) {
        if (bridge_active()) later::later(function() apply_package_substitutes(pkg), 0)
      })
    }
  }
  invisible(NULL)
}

apply_substitute <- function(sub) {
  ns <- asNamespace(sub$pkg)
  if (!exists(sub$name, envir = ns, inherits = FALSE)) return(invisible(FALSE))
  original <- get(sub$name, envir = ns, inherits = FALSE)
  if (isTRUE(attr(original, "hotshiny_substitute"))) return(invisible(FALSE))
  value <- if (isTRUE(sub$wrap)) sub$replacement(original) else sub$replacement
  attr(value, "hotshiny_substitute") <- TRUE
  targets <- list(ns)
  pkg_env <- paste0("package:", sub$pkg)
  if (pkg_env %in% search()) targets <- c(targets, list(as.environment(pkg_env)))
  for (env in targets) {
    if (exists(sub$name, envir = env, inherits = FALSE)) {
      .hs_bridge$saved[[length(.hs_bridge$saved) + 1L]] <- list(
        env = env, name = sub$name, value = get(sub$name, envir = env, inherits = FALSE)
      )
      replace_binding(env, sub$name, value)
    }
  }
  invisible(TRUE)
}
