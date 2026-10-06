# testServer() runs hotShiny-written server code on shiny's engine (with
# shiny's MockShinySession), as the same code written for library(shiny).

# Build functions whose free variables resolve through the search path, as
# they do in an app or test file (test files here run inside the namespace).
in_global <- function(f) {
  environment(f) <- new.env(parent = globalenv())
  f
}

test_that("testServer() drives a hotShiny server function on shiny's engine", {
  server <- in_global(function(input, output, session) {
    doubled <- hotShiny::reactive(input$x * 2)
    plus_one <- reactive(doubled() + 1)
    clicks <- hotShiny::reactiveVal(0)
    hotShiny::observeEvent(input$go, clicks(clicks() + 1))
    output$txt <- renderText(paste("value", plus_one()))
  })
  testServer(server, {
    expect_s3_class(session, "MockShinySession")
    # hotShiny's primitives are shiny's own while the test runs
    expect_identical(hotShiny::reactive, shiny::reactive)
    session$setInputs(x = 2)
    expect_equal(doubled(), 4)
    expect_equal(plus_one(), 5)
    expect_equal(output$txt, "value 5")
    session$setInputs(go = 1)
    session$setInputs(go = 2)
    expect_equal(clicks(), 2)
  })
  expect_identical(hotShiny::reactive, get("reactive", asNamespace("hotShiny")))
  expect_false(identical(hotShiny::reactive, shiny::reactive))
})

test_that("testServer() works for modules and the mock clock", {
  counter <- in_global(function(id) {
    moduleServer(id, function(input, output, session) {
      ticks <- reactiveVal(0)
      observe({
        invalidateLater(1000)
        isolate(ticks(ticks() + 1))
      })
      output$n <- renderText(ticks())
    })
  })
  testServer(counter, {
    session$flushReact()
    expect_equal(ticks(), 1)
    session$elapse(3000)
    expect_equal(ticks(), 4)
    expect_equal(output$n, "4")
  })
})

test_that("testServer() runs shiny example apps written for hotShiny", {
  fixtures <- test_path("..", "e2e", "fixtures")
  skip_if_not(dir.exists(file.path(fixtures, "ex-11_timer")))
  testServer(file.path(fixtures, "ex-11_timer"), {
    session$flushReact()
    first <- output$currentTime
    expect_match(first, "^The current time is ")
    Sys.sleep(0.01)
    session$elapse(1000)
    expect_false(identical(output$currentTime, first))
  })
  # As with shiny: a server function without `session` can't be tested.
  expect_error(testServer(file.path(fixtures, "ex-07_widgets"), {}),
               "must declare input, output, and session")
})

test_that("testServer() is refused while a hotShiny app runs", {
  hotShiny:::install_bridge()
  on.exit(hotShiny:::uninstall_bridge(), add = TRUE)
  expect_error(testServer(function(input, output, session) NULL, {}), "hotShiny app is running")
})
