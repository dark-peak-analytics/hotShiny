# Converting between hotShiny and shiny apps
#
# publish_to_shiny() turns a hotShiny app into a plain shiny app in a new
# folder: library(hotShiny) becomes library(shiny), hotShiny-only calls are
# removed or rewritten, extended input arguments (class = ...) become
# htmltools::tagAppendAttributes() calls, and Tailwind support is wired in with
# shiny.tailwind when the app uses Tailwind classes. Rewrites are made on the
# source text (one edit at a time, re-parsing in between), so comments and
# formatting are kept.

# hotShiny-only functions and how publish_to_shiny() rewrites them.
dev_only_calls <- c("enable_hot_reload", "enable_strict_mode", "disable_strict_mode",
                    "enable_time_travel", "disable_time_travel", "visualize_graph",
                    "reactive_history", "replay_inputs", "strict_check")
dev_only_args <- c("hot_reload", "strict", "time_travel", "watch", "tailwind")

#' Publish a hotShiny app as a plain shiny app
#'
#' Copies the app in `app_dir` to `out_dir`, rewriting it so it runs with
#' `library(shiny)` alone:
#'
#' * `library(hotShiny)` / `hotShiny::` become `library(shiny)` / `shiny::`;
#' * development-only calls (`enable_hot_reload()`, `enable_strict_mode()`,
#'   ...) and `runApp()` arguments (`hot_reload`, `strict`, ...) are removed;
#'   the legacy `app()` becomes `shinyApp()`;
#' * extra attributes passed to input functions (e.g.
#'   `textInput("x", NULL, class = "rounded")`) become
#'   `htmltools::tagAppendAttributes(textInput("x", NULL), class = "rounded",
#'   .cssSelector = "input")`, which renders identically;
#' * when the app uses Tailwind (see `tailwind`), `shiny.tailwind` is loaded
#'   and `use_tailwind()` is added to the UI.
#'
#' A `PUBLISHED.md` report listing every change and the packages the
#' published app needs is written to `out_dir`.
#'
#' @param app_dir Directory of the hotShiny app.
#' @param out_dir Destination directory.
#' @param tailwind `TRUE`/`FALSE`, or `NULL` (default) to detect Tailwind
#'   utility classes in the source.
#' @param overwrite Replace `out_dir` if it exists?
#' @param quiet Suppress the summary message?
#' @return The report (a data frame of changes), invisibly.
#' @export
publish_to_shiny <- function(app_dir, out_dir, tailwind = NULL, overwrite = FALSE, quiet = FALSE) {
  app_dir <- normalizePath(app_dir, mustWork = TRUE)
  if (dir.exists(out_dir)) {
    if (!overwrite) stop(out_dir, " already exists (use overwrite = TRUE)", call. = FALSE)
    unlink(out_dir, recursive = TRUE)
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir)

  files <- list.files(app_dir, recursive = TRUE, all.files = FALSE, include.dirs = FALSE)
  files <- files[!grepl("^(rsconnect|renv/library|\\.git)/", files)]
  for (f in files) {
    dest <- file.path(out_dir, f)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(app_dir, f), dest, overwrite = TRUE)
  }

  r_files <- files[grepl("\\.[Rr]$", files)]
  changes <- list()
  sources <- list()
  for (f in r_files) {
    path <- file.path(out_dir, f)
    text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    res <- rewrite_for_shiny(text, f)
    sources[[f]] <- res$text
    changes <- c(changes, res$changes)
  }

  if (is.null(tailwind)) tailwind <- uses_tailwind(sources)
  if (isTRUE(tailwind) && !any(grepl("use_tailwind\\s*\\(", unlist(sources)))) {
    target <- tailwind_target(sources)
    if (is.null(target)) {
      warning("Tailwind classes found but no shinyApp() call or ui.R to attach use_tailwind() to.",
              call. = FALSE)
    } else {
      res <- add_tailwind(sources[[target]], target)
      sources[[target]] <- res$text
      changes <- c(changes, res$changes)
    }
  }

  for (f in names(sources)) writeLines(sources[[f]], file.path(out_dir, f), useBytes = TRUE)

  report <- if (length(changes)) do.call(rbind, changes) else
    data.frame(file = character(0), line = integer(0), change = character(0))
  report <- report[order(report$file, report$line), , drop = FALSE]
  rownames(report) <- NULL
  pkgs <- required_packages(sources)
  write_publish_report(out_dir, app_dir, report, pkgs)
  if (!quiet) {
    message("Published ", basename(app_dir), " to ", out_dir, " (", nrow(report), " changes). ",
            "Run it with shiny::runApp(\"", out_dir, "\").")
  }
  invisible(report)
}

change <- function(file, line, text) data.frame(file = file, line = line, change = text,
                                                 stringsAsFactors = FALSE)

# Apply rewrite rules one edit at a time until none applies.
rewrite_for_shiny <- function(text, file) {
  changes <- list()
  for (i in seq_len(10000)) {
    pd <- tryCatch(utils::getParseData(parse(text = text, keep.source = TRUE)),
                   error = function(e) NULL)
    if (is.null(pd)) {
      changes[[length(changes) + 1L]] <- change(file, NA_integer_, "could not parse; copied unchanged")
      break
    }
    edit <- next_shiny_edit(pd, text)
    if (is.null(edit)) break
    text <- apply_edit(text, edit)
    changes[[length(changes) + 1L]] <- change(file, edit$line1, edit$note)
  }
  list(text = text, changes = changes)
}

# Character offsets of a parse-data span within `text`.
span_offsets <- function(text, line1, col1, line2, col2) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  starts <- cumsum(c(1L, nchar(lines, type = "chars") + 1L))
  c(starts[line1] + col1 - 1L, starts[line2] + col2 - 1L)
}

apply_edit <- function(text, edit) {
  off <- span_offsets(text, edit$line1, edit$col1, edit$line2, edit$col2)
  paste0(substr(text, 1, off[1] - 1L), edit$replacement, substr(text, off[2] + 1L, nchar(text)))
}

span_text <- function(text, row) {
  off <- span_offsets(text, row$line1, row$col1, row$line2, row$col2)
  substr(text, off[1], off[2])
}

# Arguments of the call expression `call_id`, as spans with optional names.
call_args <- function(pd, call_id, text) {
  kids <- pd[pd$parent == call_id, ]
  kids <- kids[order(kids$line1, kids$col1), ]
  open <- which(kids$token == "'('")
  close <- which(kids$token == "')'")
  if (!length(open) || !length(close)) return(NULL)
  inner <- kids[seq_len(nrow(kids)) > open[1] & seq_len(nrow(kids)) < close[length(close)], ]
  args <- list()
  current <- NULL
  flush <- function() {
    if (!is.null(current)) args[[length(args) + 1L]] <<- current
    current <<- NULL
  }
  for (k in seq_len(nrow(inner))) {
    row <- inner[k, ]
    if (row$token == "','") {
      flush()
      next
    }
    if (is.null(current)) {
      current <- list(name = NULL, line1 = row$line1, col1 = row$col1, line2 = row$line2,
                      col2 = row$col2, value_id = NULL)
    }
    if (row$token == "SYMBOL_SUB" || row$token == "STR_CONST" && is.null(current$value_id) &&
        k < nrow(inner) && inner$token[k + 1] == "EQ_SUB") {
      current$name <- gsub("^[`'\"]|[`'\"]$", "", row$text)
    }
    if (row$token == "expr") current$value_id <- row$id
    current$line2 <- row$line2
    current$col2 <- row$col2
  }
  flush()
  lapply(args, function(a) {
    a$text <- span_text(text, a)
    a$value_text <- if (!is.null(a$value_id)) span_text(text, pd[pd$id == a$value_id, ]) else a$text
    a
  })
}

call_function_name <- function(pd, call_id) {
  kids <- pd[pd$parent == call_id, ]
  kids <- kids[order(kids$line1, kids$col1), ]
  if (!nrow(kids) || kids$token[1] != "expr") return(NULL)
  head <- pd[pd$parent == kids$id[1], ]
  head <- head[order(head$line1, head$col1), ]
  fn <- head$text[head$token == "SYMBOL_FUNCTION_CALL"]
  pkg <- head$text[head$token == "SYMBOL_PACKAGE"]
  if (!length(fn)) return(NULL)
  list(fn = fn[1], pkg = if (length(pkg)) pkg[1] else NULL, head = kids[1, ])
}

next_shiny_edit <- function(pd, text) {
  shiny_exports <- getNamespaceExports("shiny")

  # 1. hotShiny:: prefixes
  pk <- pd[pd$token == "SYMBOL_PACKAGE" & pd$text == "hotShiny", ]
  for (k in seq_len(nrow(pk))) {
    row <- pk[k, ]
    sib <- pd[pd$parent == row$parent & pd$line1 == row$line1 & pd$col1 > row$col1, ]
    fn <- sib$text[sib$token %in% c("SYMBOL_FUNCTION_CALL", "SYMBOL")][1]
    if (!is.na(fn) && (fn %in% shiny_exports || fn == "app")) {
      return(c(as.list(row[c("line1", "col1", "line2", "col2")]),
               list(replacement = "shiny", note = sprintf("hotShiny::%s -> shiny::%s", fn, fn))))
    }
  }

  # 2. library(hotShiny) / require(hotShiny) / requireNamespace("hotShiny")
  for (id in pd$id[pd$token == "expr"]) {
    info <- call_function_name(pd, id)
    if (is.null(info)) next
    if (info$fn %in% c("library", "require", "requireNamespace", "loadNamespace")) {
      args <- call_args(pd, id, text)
      if (length(args) && gsub("[\"'`]", "", args[[1]]$value_text) == "hotShiny") {
        a <- args[[1]]
        q <- if (grepl("^[\"']", a$value_text)) "\"shiny\"" else "shiny"
        return(list(line1 = a$line1, col1 = a$col1, line2 = a$line2, col2 = a$col2,
                    replacement = if (is.null(a$name)) q else paste0(a$name, " = ", q),
                    note = sprintf("%s(hotShiny) -> %s(shiny)", info$fn, info$fn)))
      }
    }
  }

  calls <- pd[pd$token == "expr", ]
  calls <- calls[order(-calls$line1, -calls$col1), ]
  for (id in calls$id) {
    info <- call_function_name(pd, id)
    if (is.null(info)) next
    if (!is.null(info$pkg) && !info$pkg %in% c("shiny", "hotShiny")) next
    row <- pd[pd$id == id, ]

    # 3. development-only calls
    if (info$fn %in% dev_only_calls) {
      args <- call_args(pd, id, text)
      replacement <- if (info$fn == "enable_hot_reload" && length(args)) args[[1]]$value_text else "invisible(NULL)"
      return(c(as.list(row[c("line1", "col1", "line2", "col2")]),
               list(replacement = replacement, note = sprintf("removed %s()", info$fn))))
    }

    # 4. legacy app() -> shinyApp()
    if (info$fn == "app" && (is.null(info$pkg) || info$pkg != "base")) {
      args <- call_args(pd, id, text)
      keep <- Filter(function(a) !identical(a$name, "bootstrap"), args)
      if (length(args) >= 2) {
        replacement <- sprintf("shinyApp(%s)", paste(vapply(keep, `[[`, "", "text"), collapse = ", "))
        return(c(as.list(row[c("line1", "col1", "line2", "col2")]),
                 list(replacement = replacement, note = "app() -> shinyApp()")))
      }
    }

    # 5. runApp(..., hot_reload = ...) dev arguments
    if (info$fn == "runApp") {
      args <- call_args(pd, id, text)
      drop <- vapply(args, function(a) !is.null(a$name) && a$name %in% dev_only_args, TRUE)
      if (any(drop)) {
        replacement <- sprintf("%srunApp(%s)", if (!is.null(info$pkg)) paste0(info$pkg, "::") else "",
                               paste(vapply(args[!drop], `[[`, "", "text"), collapse = ", "))
        return(c(as.list(row[c("line1", "col1", "line2", "col2")]),
                 list(replacement = replacement, note = "removed hotShiny-only runApp() arguments")))
      }
    }

    # 6. extended input arguments -> tagAppendAttributes()
    if (info$fn %in% names(ui_extension_targets)) {
      shiny_fn <- get(info$fn, envir = asNamespace("shiny"))
      fmls <- names(formals(shiny_fn))
      dots_at <- match("...", fmls)
      # Arguments before `...` may be partially matched; those after need exact names.
      partial <- if (is.na(dots_at)) fmls else fmls[seq_len(dots_at - 1L)]
      known <- setdiff(fmls, "...")
      args <- call_args(pd, id, text)
      extra <- vapply(args, function(a) !is.null(a$name) && !a$name %in% known &&
                        !any(startsWith(partial, a$name)), TRUE)
      if (any(extra)) {
        fn_text <- span_text(text, info$head)
        inner <- sprintf("%s(%s)", fn_text, paste(vapply(args[!extra], `[[`, "", "text"), collapse = ", "))
        sel <- ui_extension_targets[[info$fn]]
        extra_text <- paste(vapply(args[extra], `[[`, "", "text"), collapse = ", ")
        replacement <- sprintf("htmltools::tagAppendAttributes(%s, %s%s)", inner, extra_text,
                               if (!is.null(sel)) sprintf(", .cssSelector = \"%s\"", sel) else "")
        return(c(as.list(row[c("line1", "col1", "line2", "col2")]),
                 list(replacement = replacement,
                      note = sprintf("%s(%s = ...) -> tagAppendAttributes()", info$fn,
                                     paste(vapply(args[extra], `[[`, "", "name"), collapse = ", ")))))
      }
    }

    # 7. `<app>$runApp(...)` from the legacy API
    if (info$fn == "runApp") next
  }

  dollar <- pd[pd$token == "'$'", ]
  for (k in seq_len(nrow(dollar))) {
    sib <- pd[pd$parent == dollar$parent[k], ]
    sib <- sib[order(sib$line1, sib$col1), ]
    if (nrow(sib) == 3 && sib$token[3] == "SYMBOL_FUNCTION_CALL" && sib$text[3] == "runApp") {
      obj <- span_text(text, sib[1, ])
      call_id <- pd$parent[pd$id == dollar$parent[k]]
      call_row <- pd[pd$id == call_id, ]
      args <- call_args(pd, call_id, text)
      keep <- Filter(function(a) !(a$name %||% "") %in% dev_only_args, args)
      replacement <- sprintf("shiny::runApp(%s)", paste(c(obj, vapply(keep, `[[`, "", "text")), collapse = ", "))
      return(c(as.list(call_row[c("line1", "col1", "line2", "col2")]),
               list(replacement = replacement, note = "app$runApp() -> shiny::runApp(app)")))
    }
  }
  NULL
}

# Signals that a class string uses Tailwind rather than Bootstrap (which shares
# names such as `rounded`, `shadow`, `text-muted`, `p-3`): colour shades,
# variant prefixes (`md:`, `hover:`), Tailwind size scales and spacing steps
# beyond Bootstrap's 0-5.
tailwind_class_pattern <- paste0(
  "(^|\\s)(",
  "([a-z]+:)+[a-z-]+[A-Za-z0-9./-]*|",
  "(bg|text|border|ring|from|to|via|fill|stroke|outline|divide|placeholder)-",
  "(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|",
  "sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}|",
  "rounded-(sm|md|lg|xl|2xl|3xl|full)|shadow-(sm|md|lg|xl|2xl|inner)|",
  "text-(xs|sm|base|lg|[2-9]?xl)|font-(thin|light|normal|medium|semibold|bold|extrabold)|",
  "(max|min)-[wh]-[a-z0-9]+|space-[xy]-[0-9]+|gap-[0-9]+|grid-cols-[0-9]+|",
  "-?(p|px|py|pt|pb|pl|pr|m|mx|my|mt|mb|ml|mr|w|h)-([6-9]|[1-9][0-9]+|px|\\[[^]]+\\])",
  ")(\\s|$)"
)

uses_tailwind <- function(sources) {
  for (src in sources) {
    pd <- tryCatch(utils::getParseData(parse(text = src, keep.source = TRUE)), error = function(e) NULL)
    if (is.null(pd)) next
    subs <- pd[pd$token == "SYMBOL_SUB" & pd$text == "class", ]
    for (k in seq_len(nrow(subs))) {
      sib <- pd[pd$parent == subs$parent[k] & pd$token == "expr" & pd$line1 >= subs$line1[k], ]
      vals <- pd$text[pd$token == "STR_CONST" & pd$parent %in% sib$id]
      vals <- gsub("^[\"']|[\"']$", "", vals)
      if (any(grepl(tailwind_class_pattern, vals, perl = TRUE))) return(TRUE)
    }
  }
  FALSE
}

tailwind_target <- function(sources) {
  for (f in names(sources)) if (grepl("shinyApp\\s*\\(", sources[[f]])) return(f)
  if ("ui.R" %in% names(sources)) return("ui.R")
  NULL
}

add_tailwind <- function(text, file) {
  wrap <- function(ui) {
    sprintf(paste0("local({ .hs_ui <- %s; if (is.function(.hs_ui)) function(req) htmltools::tagList(",
                   "shiny.tailwind::use_tailwind(), if (length(formals(.hs_ui))) .hs_ui(req) else .hs_ui()) ",
                   "else htmltools::tagList(shiny.tailwind::use_tailwind(), .hs_ui) })"), ui)
  }
  pd <- utils::getParseData(parse(text = text, keep.source = TRUE))
  for (id in pd$id[pd$token == "expr"]) {
    info <- call_function_name(pd, id)
    if (is.null(info) || info$fn != "shinyApp") next
    args <- call_args(pd, id, text)
    ui_arg <- Filter(function(a) identical(a$name, "ui"), args)
    a <- if (length(ui_arg)) ui_arg[[1]] else Filter(function(a) is.null(a$name), args)[[1]]
    edit <- list(line1 = a$line1, col1 = a$col1, line2 = a$line2, col2 = a$col2,
                 replacement = if (is.null(a$name)) wrap(a$value_text) else paste0(a$name, " = ", wrap(a$value_text)))
    return(list(text = apply_edit(text, edit),
                changes = list(change(file, a$line1, "added shiny.tailwind::use_tailwind() to the UI"))))
  }
  # ui.R: wrap the value of the file's last top-level expression.
  exprs <- parse(text = text, keep.source = TRUE)
  ref <- attr(exprs, "srcref")[[length(exprs)]]
  edit <- list(line1 = ref[1], col1 = ref[5], line2 = ref[3], col2 = ref[6],
               replacement = wrap(paste(as.character(ref), collapse = "\n")))
  list(text = apply_edit(text, edit),
       changes = list(change(file, ref[1], "added shiny.tailwind::use_tailwind() to the UI")))
}

required_packages <- function(sources) {
  pkgs <- "shiny"
  for (src in sources) {
    m <- gregexpr("(library|require)\\(\\s*[\"']?([A-Za-z][A-Za-z0-9.]*)", src)
    hits <- regmatches(src, m)[[1]]
    pkgs <- c(pkgs, sub(".*\\(\\s*[\"']?", "", hits))
    m2 <- regmatches(src, gregexpr("([A-Za-z][A-Za-z0-9.]*)::", src))[[1]]
    pkgs <- c(pkgs, sub("::$", "", m2))
  }
  sort(unique(setdiff(pkgs, c("hotShiny", "base", "utils", "stats", "graphics", "grDevices", "methods", "tools"))))
}

write_publish_report <- function(out_dir, app_dir, report, pkgs) {
  lines <- c(
    "# Published from hotShiny",
    "",
    sprintf("Source: `%s`", app_dir),
    sprintf("Published: %s with hotShiny %s", format(Sys.time(), "%Y-%m-%d %H:%M"),
            as.character(utils::packageVersion("hotShiny"))),
    "",
    "Run with:",
    "",
    "```r",
    sprintf("shiny::runApp(\"%s\")", out_dir),
    "```",
    "",
    "## Required packages",
    "",
    paste0("- ", pkgs),
    "",
    "## Changes",
    ""
  )
  if (nrow(report)) {
    lines <- c(lines, sprintf("- `%s:%s` %s", report$file, report$line, report$change))
  } else {
    lines <- c(lines, "None: the app already used only the shiny API.")
  }
  writeLines(lines, file.path(out_dir, "PUBLISHED.md"))
}
