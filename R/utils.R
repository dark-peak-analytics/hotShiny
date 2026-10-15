# Small internal helpers shared across the package.

`%||%` <- function(a, b) if (is.null(a)) b else a

# Access a non-exported object from the shiny namespace. hotShiny reuses a
# handful of shiny's pure helpers (JSON encoding, message decoding, page
# rendering) so the wire format is byte-identical to shiny's.
shiny_internal <- function(name) {
  get(name, envir = asNamespace("shiny"), inherits = FALSE)
}

log_debug <- function(...) {
  if (isTRUE(getOption("hotshiny.verbose", FALSE))) {
    message("[hotShiny] ", ...)
  }
}

log_info <- function(...) {
  message("[hotShiny] ", ...)
}

# Callback registry returning an unregister function per callback, mirroring
# the semantics shiny exposes from session$onFlush() and friends.
Callbacks <- R6::R6Class("HsCallbacks",
  cloneable = FALSE,
  public = list(
    initialize = function() {
      private$fns <- fastmap::fastmap()
    },
    register = function(fn) {
      if (!is.function(fn)) stop("callback must be a function", call. = FALSE)
      private$next_id <- private$next_id + 1L
      id <- sprintf("%010d", private$next_id)
      private$fns$set(id, fn)
      invisible(function() {
        private$fns$remove(id)
        invisible(NULL)
      })
    },
    invoke = function(..., onError = NULL) {
      keys <- sort(private$fns$keys())
      for (id in keys) {
        fn <- private$fns$get(id)
        if (is.null(fn)) next
        if (is.null(onError)) {
          fn(...)
        } else {
          tryCatch(fn(...), error = onError)
        }
      }
      invisible(NULL)
    },
    count = function() private$fns$size()
  ),
  private = list(fns = NULL, next_id = 0L)
)

# Random hex id of `bytes` bytes, drawn from shiny's private seed so the user's
# RNG stream is never disturbed (same as shiny's session tokens).
random_id <- function(bytes = 16) {
  shiny_internal("createUniqueId")(bytes)
}

# Label for a reactive object, derived the way shiny derives it: when the
# statement that created it reads `name <- fn(...)`, the label is `name`.
# `call` is the constructor's own sys.call(), which carries the srcref of the
# whole statement when the app was sourced with keep.source = TRUE.
infer_label <- function(call, fallback) {
  ref <- attr(call, "srcref")
  if (is.null(ref)) return(fallback)
  line <- tryCatch(as.character(ref)[1], error = function(e) NA_character_)
  if (is.na(line)) return(fallback)
  m <- regmatches(line, regexec("^\\s*([A-Za-z.][A-Za-z0-9._]*|`[^`]+`)\\s*(<<?-|=)[^=]", line))[[1]]
  if (length(m) >= 2 && nzchar(m[2])) gsub("`", "", m[2]) else fallback
}

is_promise <- function(x) promises::is.promising(x)
