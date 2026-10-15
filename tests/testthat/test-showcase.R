test_that("display mode comes from DESCRIPTION or display.mode, as in shiny", {
  globals <- shiny:::.globals
  old <- globals$showcaseDefault
  on.exit(shiny:::setShowcaseDefault(old %||% 0), add = TRUE)
  dir <- withr::local_tempdir()
  writeLines("Title: x\nDisplayMode: Showcase", file.path(dir, "DESCRIPTION"))
  hotShiny:::setup_showcase(dir)
  expect_equal(globals$showcaseDefault, 1)
  expect_true(globals$IncludeWWW)
  hotShiny:::setup_showcase(dir, "normal")
  expect_equal(globals$showcaseDefault, 0)
  hotShiny:::setup_showcase(NULL, "showcase")
  expect_equal(globals$showcaseDefault, 1)
  hotShiny:::setup_showcase(NULL)
  expect_equal(globals$showcaseDefault, 0)
})

test_that("app files get the source references shiny gives them", {
  dir <- withr::local_tempdir()
  file <- file.path(dir, "app.R")
  writeLines(c("x <- 1", "f <- function() {", "  r <- reactive({", "    x + 1", "  })", "}", "f"), file)
  block <- hotShiny:::parse_app_file(file)
  # shiny's own parse of the same file (see shiny:::sourceUTF8)
  lines <- c("..stacktraceon..({", sprintf('#line 1 "%s"', normalizePath(file, winslash = "/")),
             readLines(file), "})")
  ref <- parse(text = lines, keep.source = FALSE, srcfile = srcfilecopy(file, lines, isFile = TRUE))
  ref_block <- ref[[1]][[2]]
  inner <- function(b) attr(b[[3]][[3]][[3]][[2]][[3]][[2]], "srcref")
  expect_equal(lapply(inner(block), as.vector), lapply(inner(ref_block), as.vector))
  # evaluating the block yields the last expression's value
  expect_true(is.function(eval(block, new.env())))
})

test_that("reactive and output labels carry srcrefs for showcase highlighting", {
  expr <- parse(text = "reactive({\n  1 + 1\n})", keep.source = TRUE)[[1]][[2]]
  label <- hotShiny:::label_with_srcref("r", expr, "reactive")
  expect_equal(as.vector(label), "r")
  expect_equal(as.vector(attr(label, "srcref"))[1:4], c(2, 3, 2, 7))
  out <- hotShiny:::output_label_srcref("x", parse(text = "renderText({\n  1\n})", keep.source = TRUE)[[1]])
  expect_equal(as.vector(attr(out, "srcref")), c(1, 12, 2, 3, 12, 3))
})
