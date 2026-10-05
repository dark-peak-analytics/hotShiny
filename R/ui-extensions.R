# UI extensions
#
# Every UI function is shiny's own (re-exported), so markup is identical to
# shiny's. The input functions below are thin wrappers that additionally
# accept extra attributes through `...` — most usefully `class`, which is
# appended to the control's classes (handy for Tailwind utility classes):
#
#   textInput("name", NULL, class = "border rounded-xl")
#
# Without extra arguments the wrappers return exactly what shiny returns.
# publish_to_shiny() rewrites extension calls into plain shiny
# (htmltools::tagAppendAttributes()), so published apps don't need hotShiny.

# Where extra attributes land, per input function: a CSS selector inside the
# input's container, or NULL for the container itself.
ui_extension_targets <- list(
  textInput = "input",
  textAreaInput = "textarea",
  passwordInput = "input",
  numericInput = "input",
  selectInput = "select",
  selectizeInput = "select",
  varSelectInput = "select",
  varSelectizeInput = "select",
  dateInput = "input",
  dateRangeInput = NULL,
  sliderInput = "input",
  fileInput = NULL,
  checkboxInput = "input",
  checkboxGroupInput = NULL,
  radioButtons = NULL
)

apply_extra_attribs <- function(tag, extra, selector) {
  if (!length(extra)) return(tag)
  if (is.null(names(extra)) || any(!nzchar(names(extra)))) {
    stop("Extra arguments to input functions must be named attributes (e.g. class = ...)", call. = FALSE)
  }
  args <- c(list(tag), extra)
  if (!is.null(selector)) {
    found <- htmltools::tagQuery(tag)$find(selector)$length() > 0
    if (found) args$.cssSelector <- selector
  }
  # `class` is appended by tagAppendAttributes; other attributes replace.
  others <- setdiff(names(extra), "class")
  if (length(others)) {
    q <- htmltools::tagQuery(tag)
    if (!is.null(args$.cssSelector)) q <- q$find(selector)
    q$removeAttrs(others)
    tag <- q$allTags()
    args[[1]] <- tag
  }
  do.call(htmltools::tagAppendAttributes, args)
}

ui_extend <- function(name) {
  fn <- get(name, envir = asNamespace("shiny"))
  selector <- ui_extension_targets[[name]]
  fmls <- formals(fn)
  if ("..." %in% names(fmls)) return(fn)
  wrapper <- function() {
    call <- match.call(expand.dots = FALSE)
    extra <- lapply(call$..., eval, envir = parent.frame())
    call$... <- NULL
    call[[1]] <- fn
    tag <- eval(call, parent.frame())
    apply_extra_attribs(tag, extra, selector)
  }
  formals(wrapper) <- c(fmls, alist(... = ))
  environment(wrapper) <- list2env(list(fn = fn, selector = selector),
                                   parent = asNamespace("hotShiny"))
  wrapper
}

#' Input controls (shiny's, extended with extra attributes)
#'
#' These are [shiny::textInput()] and friends with one addition: any extra
#' named argument becomes an HTML attribute of the control (`class` is
#' appended to the existing classes). With no extra arguments the output is
#' identical to shiny's.
#'
#' @name ui-extensions
#' @param ... Extra attributes, e.g. `class = "border rounded-xl"`.
#' @seealso [publish_to_shiny()], which rewrites these into plain shiny.
NULL

#' @rdname ui-extensions
#' @export
textInput <- ui_extend("textInput")
#' @rdname ui-extensions
#' @export
textAreaInput <- ui_extend("textAreaInput")
#' @rdname ui-extensions
#' @export
passwordInput <- ui_extend("passwordInput")
#' @rdname ui-extensions
#' @export
numericInput <- ui_extend("numericInput")
#' @rdname ui-extensions
#' @export
selectInput <- ui_extend("selectInput")
#' @rdname ui-extensions
#' @export
varSelectInput <- ui_extend("varSelectInput")
#' @rdname ui-extensions
#' @export
dateInput <- ui_extend("dateInput")
#' @rdname ui-extensions
#' @export
dateRangeInput <- ui_extend("dateRangeInput")
#' @rdname ui-extensions
#' @export
sliderInput <- ui_extend("sliderInput")
#' @rdname ui-extensions
#' @export
fileInput <- ui_extend("fileInput")
#' @rdname ui-extensions
#' @export
checkboxInput <- ui_extend("checkboxInput")
#' @rdname ui-extensions
#' @export
checkboxGroupInput <- ui_extend("checkboxGroupInput")
#' @rdname ui-extensions
#' @export
radioButtons <- ui_extend("radioButtons")
