# Showcase mode: the app's code shown next to it, with the code of each
# reactive highlighted as it runs.
#
# The page itself is rendered by shiny's own UI handler, which wraps the UI in
# the showcase layout whenever shiny's showcase default is on; hotShiny only
# has to decide the mode the way shiny::runApp() does and, while running, send
# shiny-showcase.js the "showcase-src" messages it highlights code with.

# Resolve the display mode for an app and hand it to shiny: `display.mode`
# wins, otherwise "DisplayMode: Showcase" in the app's DESCRIPTION file.
setup_showcase <- function(app_dir, display.mode = c("auto", "normal", "showcase")) {
  display.mode <- match.arg(display.mode)
  globals <- shiny_internal(".globals")
  set_default <- shiny_internal("setShowcaseDefault")
  set_default(0)
  desc <- if (!is.null(app_dir)) read_app_description(app_dir)
  if (identical(unname(desc["DisplayMode"]), "Showcase")) {
    set_default(1)
    include_www <- if ("IncludeWWW" %in% names(desc)) as.logical(desc[["IncludeWWW"]]) else TRUE
    if (is.na(include_www)) {
      stop("In your Description file, `IncludeWWW` must be set to `True` (default) or `False`",
           call. = FALSE)
    }
    globals$IncludeWWW <- include_www
  }
  if (is.null(globals$IncludeWWW) || is.na(globals$IncludeWWW)) globals$IncludeWWW <- TRUE
  if (display.mode == "normal") set_default(0)
  else if (display.mode == "showcase") set_default(1)
  invisible(globals$showcaseDefault)
}

read_app_description <- function(app_dir) {
  files <- list.files(app_dir, full.names = TRUE)
  file <- files[tolower(basename(files)) == "description"]
  if (!length(file)) return(character(0))
  dcf <- read.dcf(file[[1]])
  if (!nrow(dcf)) return(character(0))
  dcf[1, ]
}

# The showcase mode a request asks for with `?showcase=0|1`, or NULL. Only
# honoured when the app started in a mode that allows overriding, as in shiny.
showcase_mode_of_query <- function(query) {
  if (!isTRUE(shiny_internal(".globals")$showcaseOverride)) return(NULL)
  if (is.null(query) || !nzchar(query)) return(NULL)
  shiny_internal("showcaseModeOfQuerystring")(query)
}

# Attach the source reference shiny attaches to a reactive expression's label
# (its first statement), so its context can be highlighted in showcase mode.
label_with_srcref <- function(label, expr, fn_name) {
  shiny_internal("exprToLabel")(expr, fn_name, label)
}

# Same for `output$x <- render*({ ... })`: the whole `{ ... }` block.
output_label_srcref <- function(label, value_expr) {
  if (length(value_expr) <= 1) return(label)
  body <- value_expr[[2]]
  attr(label, "srcref") <- shiny_internal("srcrefFromShinyCall")(body)
  ref <- attr(body, "srcref")
  if (length(ref) > 0) attr(label, "srcfile") <- shiny_internal("srcFileOfRef")(ref[[1]])
  label
}

# Called for every new context: in showcase mode the session tells the page
# which code is about to run.
showcase_context_created <- function(domain, label) {
  if (is.null(domain) || is.null(attr(label, "srcref"))) return(invisible(NULL))
  session <- root_session(domain)
  if (!is.null(session)) {
    session$reactlog(list(srcref = as.vector(attr(label, "srcref")),
                          srcfile = attr(label, "srcfile")))
  }
  invisible(NULL)
}
