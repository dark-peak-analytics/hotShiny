# The ui.R/server.R layout, with global.R and modules in R/.

write_twofile_app <- function() {
  dir <- tempfile("app")
  dir.create(file.path(dir, "R"), recursive = TRUE)
  writeLines('greeting_prefix_appdir_test <- "hello"', file.path(dir, "global.R"))
  writeLines(c(
    "counterServer <- function(id) moduleServer(id, function(input, output, session) {",
    "  output$count <- renderText('count=0')",
    "})"
  ), file.path(dir, "R", "counter.R"))
  writeLines('fluidPage(textInput("name", "Name"), textOutput("greeting"))', file.path(dir, "ui.R"))
  writeLines(c(
    "function(input, output, session) {",
    "  counterServer('counter')",
    "  output$greeting <- renderText(paste(greeting_prefix_appdir_test, input$name))",
    "}"
  ), file.path(dir, "server.R"))
  dir
}

test_that("shinyAppDir() loads ui.R/server.R with global.R and R/ modules", {
  dir <- write_twofile_app()
  on.exit(rm(list = "greeting_prefix_appdir_test", envir = globalenv()), add = TRUE)
  a <- hotShiny::shinyAppDir(dir)
  expect_s3_class(a, "hotshiny.appobj")
  expect_identical(a$hotshiny$appDir, normalizePath(dir))
  server <- a$hotshiny$server
  expect_true(exists("counterServer", envir = environment(server)))
  hotShiny::testServer(server, {
    session$setInputs(name = "Ada")
    expect_equal(output$greeting, "hello Ada")
  })
})

test_that("legacy app() accepts the paths of ui.R and server.R", {
  dir <- write_twofile_app()
  on.exit(rm(list = "greeting_prefix_appdir_test", envir = globalenv()), add = TRUE)
  a <- hotShiny::app(file.path(dir, "ui.R"), file.path(dir, "server.R"))
  expect_s3_class(a, "hotshiny.appobj")
  expect_identical(a$hotshiny$appDir, normalizePath(dir))
  expect_true(is.function(a$runApp))
})

test_that("a file path as the server points to runApp() on the directory", {
  expect_error(hotShiny::shinyApp("ui.R", "server.R"), "runApp\\(\"path/to/app\"")
  expect_error(hotShiny::app("no/such/ui.R", "no/such/server.R"), "runApp\\(\"path/to/app\"")
})
