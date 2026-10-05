# hotShiny reactive engine
#
# A push-invalidate / pull-evaluate engine with shiny's semantics:
#
# * A *context* is created for every evaluation of a reactive expression,
#   observer or output. While it runs it is the "current context"; every
#   reactive source read during that time registers the context as a dependent.
# * Writing a source invalidates its dependents. Invalidating a context runs
#   its onInvalidate callbacks immediately; observers react by scheduling
#   themselves on the flush queue, reactive expressions by invalidating their
#   own dependents (lazily re-evaluated on next read).
# * flush_react() drains the queue in priority order (FIFO within a priority).
#
# Contexts expose the same method names as shiny's Context class (`run`,
# `invalidate`, `onInvalidate`, `addPendingFlush`, `onFlush`, `isWeak`) so
# shiny code that obtains "the current context" through the bridge (see
# bridge.R) can operate on hotShiny contexts directly.
#
# Every edge (source -> context) is also recorded in the session's reactive
# graph (graph.R), which powers graph inspection, time travel and hot reload.

.rx <- new.env(parent = emptyenv())
.rx$current <- NULL
.rx$next_id <- 0L
.rx$in_flush <- FALSE

rx_next_id <- function() {
  .rx$next_id <- .rx$next_id + 1L
  as.character(.rx$next_id)
}

# Priority queue of contexts awaiting flush. Higher priority first; insertion
# order breaks ties.
.rx$queue <- list()
.rx$queue_seq <- 0

rx_enqueue <- function(ctx, priority) {
  .rx$queue_seq <- .rx$queue_seq + 1
  .rx$queue[[length(.rx$queue) + 1L]] <- list(ctx = ctx, priority = priority, seq = .rx$queue_seq)
}

rx_dequeue <- function() {
  q <- .rx$queue
  pr <- vapply(q, function(e) e$priority, numeric(1))
  sq <- vapply(q, function(e) e$seq, numeric(1))
  i <- order(-pr, sq)[1]
  item <- q[[i]]
  .rx$queue <- q[-i]
  item$ctx
}

has_pending_flush <- function() length(.rx$queue) > 0

#' Run all pending observers
#'
#' Drains the reactive flush queue. Called by the server after every incoming
#' message and timer tick; exposed for tests.
#' @return `TRUE` invisibly if anything was flushed.
#' @keywords internal
#' @export
flush_react <- function() {
  if (!has_pending_flush() || .rx$in_flush) return(invisible(FALSE))
  .rx$in_flush <- TRUE
  on.exit(.rx$in_flush <- FALSE, add = TRUE)
  while (has_pending_flush()) {
    ctx <- rx_dequeue()
    ctx$executeFlushCallbacks()
  }
  invisible(TRUE)
}

#' The current hotShiny reactive context
#'
#' @return The context object, or `NULL` outside of a reactive consumer.
#' @keywords internal
#' @export
current_context <- function() .rx$current

has_current_context <- function() !is.null(.rx$current)

require_context <- function(what = "this operation") {
  ctx <- .rx$current
  if (is.null(ctx)) {
    rlang::abort(c(
      "Operation not allowed without an active reactive context.",
      paste0("You tried to do something that can only be done from inside a ",
             "reactive consumer.")
    ))
  }
  ctx
}

run_with_context <- function(ctx, fn) {
  old <- .rx$current
  .rx$current <- ctx
  on.exit(.rx$current <- old, add = TRUE)
  fn()
}

# Promise domain that restores the reactive context (and reactive domain)
# inside promise callbacks, so `then()` handlers created during a reactive
# evaluation still see that evaluation's context.
hs_promise_domain <- function() {
  promises::new_promise_domain(
    wrapOnFulfilled = function(onFulfilled) {
      ctx <- .rx$current
      function(...) run_with_context(ctx, function() onFulfilled(...))
    },
    wrapOnRejected = function(onRejected) {
      ctx <- .rx$current
      function(...) run_with_context(ctx, function() onRejected(...))
    }
  )
}

current_domain <- function() shiny::getDefaultReactiveDomain()

# The graph a node belongs to: the session's when a session (or module scope)
# is active, otherwise the app-level graph.
graph_for_domain <- function(domain) {
  session <- root_session(domain)
  if (!is.null(session) && inherits(session, "HotSession")) session$graph else app_graph()
}

root_session <- function(domain) {
  if (is.null(domain)) return(NULL)
  if (inherits(domain, "HotSession")) return(domain)
  if (inherits(domain, "session_proxy")) {
    root <- tryCatch(domain$rootScope(), error = function(e) NULL)
    if (inherits(root, "HotSession")) return(root)
  }
  NULL
}

HsContext <- R6::R6Class("Context",
  cloneable = FALSE,
  public = list(
    id = NULL,
    .label = "",
    .reactType = "other",
    .domain = NULL,
    .invalidated = FALSE,
    .invalidateCallbacks = list(),
    .flushCallbacks = list(),
    node = NULL,
    graph = NULL,

    initialize = function(domain = current_domain(), label = "", type = "other",
                          node = NULL, graph = NULL) {
      self$id <- rx_next_id()
      self$.label <- label
      self$.reactType <- type
      self$.domain <- domain
      self$node <- node
      self$graph <- graph
    },

    run = function(func) {
      promises::with_promise_domain(hs_promise_domain(), {
        shiny::withReactiveDomain(self$.domain, {
          run_with_context(self, func)
        })
      })
    },

    invalidate = function() {
      if (self$.invalidated) return(invisible(NULL))
      self$.invalidated <- TRUE
      cbs <- self$.invalidateCallbacks
      self$.invalidateCallbacks <- list()
      for (fn in cbs) fn()
      invisible(NULL)
    },

    onInvalidate = function(func) {
      if (self$.invalidated) {
        func()
      } else {
        self$.invalidateCallbacks[[length(self$.invalidateCallbacks) + 1L]] <- func
      }
      invisible(NULL)
    },

    addPendingFlush = function(priority = 0) {
      rx_enqueue(self, priority)
    },

    onFlush = function(func) {
      self$.flushCallbacks[[length(self$.flushCallbacks) + 1L]] <- func
      invisible(NULL)
    },

    executeFlushCallbacks = function() {
      for (fn in self$.flushCallbacks) fn()
      invisible(NULL)
    },

    isWeak = function() FALSE
  )
)

# The set of contexts that depend on one reactive source.
Dependents <- R6::R6Class("HsDependents",
  cloneable = FALSE,
  public = list(
    node = NULL,
    graph = NULL,

    initialize = function(node = NULL, graph = NULL) {
      private$ctxs <- fastmap::fastmap()
      self$node <- node
      self$graph <- graph
    },

    register = function() {
      ctx <- require_context()
      id <- ctx$id
      if (!private$ctxs$has(id)) {
        private$ctxs$set(id, ctx)
        if (!is.null(self$graph) && !is.null(self$node) && !is.null(ctx$node)) {
          self$graph$add_edge(self$node, ctx$node)
        }
        ctxs <- private$ctxs
        ctx$onInvalidate(function() ctxs$remove(id))
      }
      invisible(NULL)
    },

    invalidate = function() {
      ctxs <- private$ctxs
      ids <- ctxs$keys()
      ids <- ids[order(as.numeric(ids))]
      for (id in ids) {
        ctx <- ctxs$get(id)
        if (!is.null(ctx)) ctx$invalidate()
      }
      invisible(NULL)
    },

    count = function() private$ctxs$size()
  ),
  private = list(ctxs = NULL)
)
