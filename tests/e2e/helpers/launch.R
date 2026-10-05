# Launch a fixture app for the e2e suite.
#
# Usage: Rscript launch.R <runtime> <app_dir> <port> [hot_reload]
#   runtime    "shiny"    -> convert with hotShiny::publish_to_shiny(), run with shiny::runApp()
#              "hotshiny" -> run the app as written with hotShiny::runApp()
#   hot_reload "true" to enable hotShiny's hot reload (hotshiny runtime only)
#
# Both runtimes print shiny's "Listening on http://..." line, which the harness waits for.

args <- commandArgs(trailingOnly = TRUE)
runtime <- args[[1]]
app_dir <- normalizePath(args[[2]], mustWork = TRUE)
port <- as.integer(args[[3]])
hot_reload <- length(args) >= 4 && tolower(args[[4]]) == "true"

options(shiny.launch.browser = FALSE, warn = 1)

if (identical(runtime, "shiny")) {
  out_dir <- file.path(tempfile("published-"), basename(app_dir))
  if (requireNamespace("hotShiny", quietly = TRUE) &&
      exists("publish_to_shiny", envir = asNamespace("hotShiny"))) {
    hotShiny::publish_to_shiny(app_dir, out_dir, overwrite = TRUE, quiet = TRUE)
  } else {
    # Bootstrap fallback (before publish_to_shiny exists): plain library swap.
    dir.create(dirname(out_dir), recursive = TRUE, showWarnings = FALSE)
    file.copy(app_dir, dirname(out_dir), recursive = TRUE)
    for (f in list.files(out_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)) {
      src <- readLines(f)
      src <- gsub("library\\(hotShiny\\)", "library(shiny)", src)
      writeLines(src, f)
    }
  }
  shiny::runApp(out_dir, port = port, host = "127.0.0.1", launch.browser = FALSE)
} else if (identical(runtime, "hotshiny")) {
  hotShiny::runApp(app_dir, port = port, host = "127.0.0.1", launch.browser = FALSE,
                   hot_reload = hot_reload)
} else {
  stop("Unknown runtime: ", runtime)
}
