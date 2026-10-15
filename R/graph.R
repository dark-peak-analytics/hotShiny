# The reactive graph
#
# Each session owns a graph describing its reactive objects (inputs, reactive
# values, reactive expressions, observers, outputs) and the dependency edges
# recorded *at run time* by the engine. Node ids are stable across hot
# reloads: they are derived from the module namespace, the node type and the
# label (the assigned variable name when available), plus an ordinal for
# duplicates. That stability is what lets hot reload carry state from the old
# graph to the new one.

HsGraph <- R6::R6Class("HsGraph",
  cloneable = FALSE,
  public = list(
    label = NULL,
    version = 1L,

    initialize = function(label = "app") {
      self$label <- label
      private$node_map <- fastmap::fastmap()
      private$in_map <- fastmap::fastmap()
      private$ordinals <- fastmap::fastmap()
      private$event_q <- fastmap::fastqueue()
    },

    # Register a node and return its stable id.
    add_node = function(type, label = NULL, ns = "", meta = list()) {
      # Labels may carry srcref attributes (for showcase mode); nodes keep the text.
      if (!is.null(label)) label <- as.character(label)
      base <- paste0(if (nzchar(ns %||% "")) paste0(ns, "/") else "", type, ":",
                     label %||% "<anon>")
      n <- (private$ordinals$get(base) %||% 0L) + 1L
      private$ordinals$set(base, n)
      id <- if (n == 1L) base else paste0(base, "#", n)
      private$node_map$set(id, c(list(id = id, type = type, label = label %||% "<anon>",
                                   ns = ns %||% "", runs = 0L, status = "pending",
                                   error = NULL), meta))
      private$in_map$set(id, character(0))
      self$record("create", id)
      id
    },

    # Nodes whose id is known up front (inputs, keys of reactiveValues).
    ensure_node = function(id, type, label) {
      if (!private$node_map$has(id)) {
        private$node_map$set(id, list(id = id, type = type, label = label, ns = "",
                                   runs = 0L, status = "ok", error = NULL))
        private$in_map$set(id, character(0))
      }
      id
    },

    # Inputs are keyed by their (namespaced) input id.
    ensure_input = function(name) {
      self$ensure_node(paste0("input:", name), "input", name)
    },

    has_node = function(id) private$node_map$has(id),
    get_node = function(id) private$node_map$get(id),

    remove_node = function(id) {
      private$node_map$remove(id)
      private$in_map$remove(id)
      self$record("destroy", id)
    },

    # Called when a node starts a new evaluation: its dependencies are
    # re-recorded from scratch, exactly as the engine re-tracks them.
    begin_run = function(id) {
      if (!private$node_map$has(id)) return(invisible(NULL))
      private$in_map$set(id, character(0))
      node <- private$node_map$get(id)
      node$runs <- node$runs + 1L
      node$status <- "running"
      private$node_map$set(id, node)
      self$record("run", id)
      invisible(NULL)
    },

    end_run = function(id, status = "ok", error = NULL) {
      if (!private$node_map$has(id)) return(invisible(NULL))
      node <- private$node_map$get(id)
      node$status <- status
      node$error <- error
      private$node_map$set(id, node)
      invisible(NULL)
    },

    add_edge = function(from, to) {
      if (!private$node_map$has(to)) return(invisible(NULL))
      deps <- private$in_map$get(to) %||% character(0)
      if (!from %in% deps) private$in_map$set(to, c(deps, from))
      invisible(NULL)
    },

    record = function(event, id, data = NULL) {
      if (!isTRUE(private$recording)) return(invisible(NULL))
      private$event_q$add(list(time = Sys.time(), event = event, node = id, data = data))
      while (private$event_q$size() > private$max_events) private$event_q$remove()
      invisible(NULL)
    },

    set_recording = function(on, max_events = 5000L) {
      private$recording <- isTRUE(on)
      private$max_events <- as.integer(max_events)
      invisible(NULL)
    },

    events = function() private$event_q$as_list(),

    nodes = function() {
      ids <- sort(private$node_map$keys())
      stats::setNames(lapply(ids, private$node_map$get), ids)
    },

    edges = function() {
      ids <- sort(private$in_map$keys())
      out <- lapply(ids, function(to) {
        from <- private$in_map$get(to)
        if (length(from)) data.frame(from = from, to = to, stringsAsFactors = FALSE)
      })
      out <- do.call(rbind, c(list(data.frame(from = character(0), to = character(0))), out))
      rownames(out) <- NULL
      out
    },

    # A content signature per node, used to describe what a hot reload changed.
    signature = function() {
      n <- self$nodes()
      vapply(n, function(x) paste(x$type, x$code_hash %||% ""), character(1))
    },

    snapshot = function() {
      list(label = self$label, version = self$version, nodes = self$nodes(),
           edges = self$edges())
    },

    reset_ordinals = function() {
      private$ordinals <- fastmap::fastmap()
    },

    # Drop everything the server function created (inputs stay), so that a
    # re-run regenerates the same stable ids.
    clear = function() {
      for (id in private$node_map$keys()) {
        if (!identical(private$node_map$get(id)$type, "input")) {
          private$node_map$remove(id)
          private$in_map$remove(id)
        }
      }
      self$version <- self$version + 1L
      self$reset_ordinals()
      self$record("reload", NA_character_)
    }
  ),
  private = list(
    node_map = NULL,
    in_map = NULL,
    ordinals = NULL,
    event_q = NULL,
    recording = FALSE,
    max_events = 5000L
  )
)

.hs_app_graph <- new.env(parent = emptyenv())

app_graph <- function() {
  if (is.null(.hs_app_graph$graph)) .hs_app_graph$graph <- HsGraph$new("app")
  .hs_app_graph$graph
}

#' Inspect the reactive graph
#'
#' Returns the reactive graph of a session (nodes and the dependency edges
#' recorded during its most recent evaluations), or renders it as Graphviz DOT.
#'
#' @param session A session object. Defaults to the current reactive domain,
#'   or the most recently connected session of the running app.
#' @param format `"list"` (default) or `"dot"`.
#' @export
visualize_graph <- function(session = NULL, format = c("list", "dot")) {
  format <- match.arg(format)
  graph <- if (inherits(session, "HsGraph")) session else {
    session <- session %||% root_session(current_domain()) %||% last_session()
    if (is.null(session)) app_graph() else session$graph
  }
  snap <- graph$snapshot()
  if (format == "list") return(snap)
  shape <- c(input = "box", reactiveVal = "box", reactiveValues = "box",
             reactive = "ellipse", observer = "hexagon", output = "doubleoctagon")
  lines <- c("digraph reactive {", "  rankdir=LR;")
  for (n in snap$nodes) {
    lines <- c(lines, sprintf('  "%s" [label="%s\\n%s", shape=%s];', n$id, n$type, n$label,
                              shape[[n$type]] %||% "ellipse"))
  }
  for (i in seq_len(nrow(snap$edges))) {
    lines <- c(lines, sprintf('  "%s" -> "%s";', snap$edges$from[i], snap$edges$to[i]))
  }
  paste(c(lines, "}"), collapse = "\n")
}
