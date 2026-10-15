write_app <- function(code) {
  dir <- tempfile("app")
  dir.create(dir)
  writeLines(code, file.path(dir, "app.R"))
  dir
}

test_that("publish_to_shiny rewrites hotShiny code into plain shiny", {
  src <- write_app(c(
    "library(hotShiny)",
    "ui <- fluidPage(textInput('x', NULL, class = 'border rounded-xl'), hotShiny::textOutput('o'))",
    "server <- function(input, output, session) output$o <- renderText(input$x)",
    "a <- app(ui, server, bootstrap = FALSE)",
    "enable_hot_reload(a)",
    "a"
  ))
  out <- tempfile("pub")
  report <- publish_to_shiny(src, out, quiet = TRUE)
  code <- readLines(file.path(out, "app.R"))
  expect_true(any(grepl("library(shiny)", code, fixed = TRUE)))
  expect_false(any(grepl("hotShiny", code)))
  expect_true(any(grepl("tagAppendAttributes(textInput('x', NULL), class = 'border rounded-xl', .cssSelector = \"input\")", code, fixed = TRUE)))
  expect_true(any(grepl("shinyApp(", code, fixed = TRUE)))
  expect_true(any(grepl("shiny.tailwind::use_tailwind()", code, fixed = TRUE)))
  expect_true(file.exists(file.path(out, "PUBLISHED.md")))
  expect_gt(nrow(report), 4)

  # The published app builds under shiny and renders the same input markup.
  app <- shiny::shinyAppDir(out)
  expect_s3_class(app, "shiny.appobj")
})

test_that("publish_to_shiny leaves plain shiny code alone", {
  src <- write_app(c(
    "library(hotShiny)",
    "shinyApp(fluidPage(p('hi')), function(input, output) {})"
  ))
  out <- tempfile("pub")
  report <- publish_to_shiny(src, out, quiet = TRUE)
  expect_equal(nrow(report), 1)
  expect_equal(readLines(file.path(out, "app.R"))[2], "shinyApp(fluidPage(p('hi')), function(input, output) {})")
})

test_that("Bootstrap utility classes are not mistaken for Tailwind", {
  src <- write_app(c(
    "library(hotShiny)",
    "shinyApp(fluidPage(div(class = 'text-muted p-3 rounded shadow', 'x')), function(input, output) {})"
  ))
  out <- tempfile("pub")
  publish_to_shiny(src, out, quiet = TRUE)
  expect_false(any(grepl("use_tailwind", readLines(file.path(out, "app.R")))))
})
