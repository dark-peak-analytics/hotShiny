# shiny -> hotShiny
#
# hotShiny runs shiny apps unmodified, so "translating" an app only means
# swapping the library call. shiny2hotshiny_check() reports the few features
# hotShiny does not implement (bookmarking), so they can be found ahead of time.

unsupported_features <- c(
  enableBookmarking = "bookmarking is not supported (state is not saved to URLs/server)",
  bookmarkButton = "bookmarking is not supported",
  onBookmark = "bookmarking is not supported",
  onBookmarked = "bookmarking is not supported",
  onRestore = "bookmarking is not supported",
  onRestored = "bookmarking is not supported",
  showBookmarkUrlModal = "bookmarking is not supported"
)

app_source_files <- function(path) {
  if (dir.exists(path)) {
    list.files(path, pattern = "\\.[Rr]$", full.names = TRUE, recursive = TRUE)
  } else if (file.exists(path)) {
    path
  } else {
    stop("Path not found: ", path, call. = FALSE)
  }
}

#' Check and translate shiny apps for hotShiny
#'
#' `shiny2hotshiny_check()` lists uses of shiny features hotShiny does not
#' implement. `shiny2hotshiny_translate()` swaps `library(shiny)` for
#' `library(hotShiny)` (the only change hotShiny needs). The reverse
#' direction is [publish_to_shiny()].
#'
#' @param path An app file or directory.
#' @return `shiny2hotshiny_check()`: a data frame of findings
#'   (`file`, `line`, `feature`, `message`).
#' @export
shiny2hotshiny_check <- function(path) {
  findings <- list()
  for (f in app_source_files(path)) {
    pd <- tryCatch(utils::getParseData(parse(f, keep.source = TRUE)), error = function(e) NULL)
    if (is.null(pd)) next
    hits <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% names(unsupported_features), ]
    for (k in seq_len(nrow(hits))) {
      findings[[length(findings) + 1L]] <- data.frame(
        file = f, line = hits$line1[k], feature = hits$text[k],
        message = unname(unsupported_features[hits$text[k]]), stringsAsFactors = FALSE
      )
    }
  }
  res <- if (length(findings)) do.call(rbind, findings) else
    data.frame(file = character(0), line = integer(0), feature = character(0), message = character(0))
  class(res) <- c("shiny2hotshiny_report", class(res))
  res
}

#' @export
print.shiny2hotshiny_report <- function(x, ...) {
  if (!nrow(x)) {
    cat("No incompatibilities found: the app runs on hotShiny unchanged.\n")
  } else {
    cat(nrow(x), "finding(s):\n")
    for (i in seq_len(nrow(x))) cat(sprintf("  %s:%d  %s(): %s\n", basename(x$file[i]), x$line[i],
                                            x$feature[i], x$message[i]))
  }
  invisible(x)
}

#' @rdname shiny2hotshiny_check
#' @param output Output file (for a single file) or directory; defaults to
#'   rewriting in place.
#' @export
shiny2hotshiny_translate <- function(path, output = path) {
  files <- app_source_files(path)
  for (f in files) {
    src <- readLines(f, warn = FALSE)
    new <- gsub("\\b(library|require)\\((\\s*[\"']?)shiny([\"']?\\s*)\\)", "\\1(\\2hotShiny\\3)", src)
    new <- gsub("\\bshiny::", "hotShiny::", new)
    dest <- if (dir.exists(path)) file.path(output, substring(f, nchar(path) + 2)) else output
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    writeLines(new, dest)
  }
  invisible(files)
}
