# Reactive sources: reactiveVal() and reactiveValues()
#
# The returned objects have the same shape and classes as shiny's
# (`reactiveVal` functions with an ".impl" attribute; `reactivevalues` lists
# holding `impl`, `readonly`, `ns`) so code written against shiny's internals
# — `.subset2(input, "impl")`, `attr(x, ".impl")` — keeps working.

domain_ns <- function(domain) {
  if (is.null(domain)) return("")
  ns <- tryCatch(domain$ns(character(0)), error = function(e) NULL)
  paste(ns %||% "", collapse = "")
}

ReactiveVal <- R6::R6Class("ReactiveVal",
  cloneable = FALSE,
  public = list(
    label = NULL,
    node = NULL,
    graph = NULL,

    initialize = function(value, label, node = NULL, graph = NULL) {
      private$value <- value
      self$label <- label
      self$node <- node
      self$graph <- graph
      private$deps <- Dependents$new(node, graph)
    },

    get = function() {
      private$deps$register()
      if (private$frozen) shiny::req(FALSE)
      private$value
    },

    set = function(value) {
      if (identical(private$value, value)) return(invisible(FALSE))
      private$value <- value
      if (!is.null(self$graph)) self$graph$record("set", self$node)
      private$deps$invalidate()
      invisible(TRUE)
    },

    # Read without taking a dependency (used for state preservation).
    peek = function() private$value,

    freeze = function(session = NULL) {
      if (is.null(session)) rlang::abort("Can't freeze a reactiveVal without a reactive domain.")
      session$onFlushed(function() self$thaw())
      private$frozen <- TRUE
    },

    thaw = function() private$frozen <- FALSE,

    isFrozen = function() private$frozen,

    format = function(...) {
      str <- utils::capture.output(utils::str(private$value))
      c(paste0("reactiveVal: ", str[1]), str[-1])
    }
  ),
  private = list(value = NULL, deps = NULL, frozen = FALSE)
)

#' Create a reactive value
#'
#' Same interface as [shiny::reactiveVal()]: call the result with no arguments
#' to read the value (taking a reactive dependency), or with one argument to
#' set it. During a hot reload the value of a `reactiveVal` is carried over to
#' its replacement (matched by label), so app state survives code edits.
#'
#' @param value The initial value.
#' @param label A label used in the reactive graph. Defaults to the name the
#'   reactiveVal is assigned to.
#' @export
reactiveVal <- function(value = NULL, label = NULL) {
  if (is.null(label)) label <- infer_label(sys.call(), "reactiveVal")
  domain <- current_domain()
  graph <- graph_for_domain(domain)
  node <- graph$add_node("reactiveVal", label, domain_ns(domain))
  value <- hot_state_initial(domain, node, value)
  rv <- ReactiveVal$new(value, label, node, graph)
  hot_state_register(domain, node, function() rv$peek())
  structure(
    function(x) {
      if (missing(x)) {
        rv$get()
      } else {
        force(x)
        rv$set(x)
      }
    },
    class = c("reactiveVal", "reactive", "function"),
    label = label,
    .impl = rv
  )
}

ReactiveValues <- R6::R6Class("ReactiveValues",
  cloneable = FALSE,
  public = list(
    .label = NULL,
    .values = NULL,
    .metadata = NULL,
    .dedupe = TRUE,
    node = NULL,
    graph = NULL,
    is_input = FALSE,

    initialize = function(dedupe = TRUE, label = "reactiveValues", node = NULL,
                          graph = NULL, is_input = FALSE) {
      self$.label <- label
      self$.dedupe <- dedupe
      self$.values <- fastmap::fastmap()
      self$.metadata <- fastmap::fastmap()
      self$node <- node
      self$graph <- graph
      self$is_input <- is_input
      private$keyDeps <- fastmap::fastmap()
      private$namesDeps <- Dependents$new(node, graph)
      private$allDeps <- Dependents$new(node, graph)
      private$visibleDeps <- Dependents$new(node, graph)
      private$frozen <- character(0)
    },

    get = function(key) {
      private$depsFor(key)$register()
      if (key %in% private$frozen) shiny::req(FALSE)
      self$.values$get(key)
    },

    set = function(key, value, force = FALSE) {
      has <- self$.values$has(key)
      if (has && self$.dedupe && !force && identical(self$.values$get(key), value)) {
        return(invisible(FALSE))
      }
      if (!has) {
        private$namesDeps$invalidate()
      }
      self$.values$set(key, value)
      if (!is.null(self$graph)) {
        self$graph$record("set", private$nodeFor(key),
                          list(key = key, value = if (self$is_input) value))
      }
      private$depsFor(key)$invalidate()
      private$allDeps$invalidate()
      if (!startsWith(key, ".")) private$visibleDeps$invalidate()
      invisible(TRUE)
    },

    mset = function(values) {
      for (key in names(values)) {
        self$set(key, values[[key]])
      }
      invisible(NULL)
    },

    names = function() {
      private$namesDeps$register()
      self$.values$keys()
    },

    toList = function(all.names = FALSE) {
      keys <- self$.values$keys(sort = TRUE)
      if (all.names) {
        private$allDeps$register()
      } else {
        private$visibleDeps$register()
        keys <- keys[!startsWith(keys, ".")]
      }
      keys <- setdiff(keys, private$frozen)
      stats::setNames(lapply(keys, self$.values$get), keys)
    },

    # Read without taking a dependency.
    peek = function(key) self$.values$get(key),
    keys = function() self$.values$keys(),

    freeze = function(key, invalidate = FALSE) {
      private$frozen <- union(private$frozen, key)
      if (invalidate) private$depsFor(key)$invalidate()
    },

    thaw = function(key) {
      private$frozen <- setdiff(private$frozen, key)
    },

    isFrozen = function(key) key %in% private$frozen,

    setMeta = function(key, metaKey, value) {
      meta <- self$.metadata$get(key) %||% list()
      meta[[metaKey]] <- value
      self$.metadata$set(key, meta)
    },

    getMeta = function(key, metaKey) {
      (self$.metadata$get(key) %||% list())[[metaKey]]
    },

    destroyByPrefix = function(prefix) {
      for (key in self$.values$keys()) {
        if (startsWith(key, prefix)) {
          self$.values$remove(key)
          private$keyDeps$remove(key)
        }
      }
      private$namesDeps$invalidate()
      private$allDeps$invalidate()
      private$visibleDeps$invalidate()
    }
  ),
  private = list(
    keyDeps = NULL,
    namesDeps = NULL,
    allDeps = NULL,
    visibleDeps = NULL,
    frozen = NULL,

    nodeFor = function(key) {
      if (is.null(self$graph)) return(NULL)
      if (self$is_input) return(self$graph$ensure_input(key))
      self$graph$ensure_node(paste0(self$node, "$", key), "reactiveValues",
                             paste0(self$.label, "$", key))
    },

    depsFor = function(key) {
      d <- private$keyDeps$get(key)
      if (is.null(d)) {
        d <- Dependents$new(private$nodeFor(key), self$graph)
        private$keyDeps$set(key, d)
      }
      d
    }
  )
)

new_reactivevalues <- function(impl, readonly = FALSE, ns = identity) {
  structure(list(impl = impl, readonly = readonly, ns = ns),
            class = c("hs_reactivevalues", "reactivevalues"))
}

#' Create an object for storing reactive values
#'
#' Same interface as [shiny::reactiveValues()]. Values are carried across hot
#' reloads (matched by the object's label).
#'
#' @param ... Named initial values.
#' @export
reactiveValues <- function(...) {
  args <- list(...)
  if (length(args) && (is.null(names(args)) || any(names(args) == ""))) {
    rlang::abort("All arguments passed to reactiveValues() must be named.")
  }
  label <- infer_label(sys.call(), "reactiveValues")
  domain <- current_domain()
  graph <- graph_for_domain(domain)
  node <- graph$add_node("reactiveValues", label, domain_ns(domain))
  impl <- ReactiveValues$new(dedupe = TRUE, label = label, node = node, graph = graph)
  restored <- hot_state_initial(domain, node, NULL)
  impl$mset(if (is.list(restored)) utils::modifyList(args, restored) else args)
  hot_state_register(domain, node, function() {
    keys <- impl$keys()
    stats::setNames(lapply(keys, impl$peek), keys)
  })
  new_reactivevalues(impl)
}

#' @export
`$.hs_reactivevalues` <- function(x, name) {
  if (!has_current_context()) {
    rlang::abort(c(
      paste0("Can't access reactive value '", name, "' outside of reactive consumer."),
      i = "Do you need to wrap inside reactive() or observe()?"
    ))
  }
  .subset2(x, "impl")$get(.subset2(x, "ns")(name))
}

#' @export
`[[.hs_reactivevalues` <- `$.hs_reactivevalues`

#' @export
`$<-.hs_reactivevalues` <- function(x, name, value) {
  if (isTRUE(.subset2(x, "readonly"))) {
    rlang::abort(paste0("Can't modify read-only reactive value '", name, "'"))
  }
  .subset2(x, "impl")$set(.subset2(x, "ns")(name), value)
  x
}

#' @export
`[[<-.hs_reactivevalues` <- `$<-.hs_reactivevalues`

#' @export
`[.hs_reactivevalues` <- function(x, i) rlang::abort("Can't index reactivevalues with `[`.")

#' @export
`[<-.hs_reactivevalues` <- function(x, i, value) rlang::abort("Can't index reactivevalues with `[`.")

#' @export
names.hs_reactivevalues <- function(x) {
  prefix <- .subset2(x, "ns")("")
  res <- .subset2(x, "impl")$names()
  if (nzchar(prefix)) {
    res <- res[startsWith(res, prefix)]
    res <- substring(res, nchar(prefix) + 1)
  }
  res
}

#' @export
print.hs_reactivevalues <- function(x, ...) {
  impl <- .subset2(x, "impl")
  cat("<ReactiveValues>\n")
  cat("  Values:   ", paste0(impl$.values$keys(sort = TRUE), collapse = ", "), "\n", sep = "")
  cat("  Readonly: ", .subset2(x, "readonly"), "\n", sep = "")
  invisible(x)
}

#' @export
str.hs_reactivevalues <- function(object, ...) {
  utils::str(unclass(object), ...)
}
