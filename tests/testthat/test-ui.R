test_that("UI functions are shiny's own", {
  expect_identical(hotShiny::fluidPage, shiny::fluidPage)
  expect_identical(hotShiny::tags, shiny::tags)
  expect_identical(hotShiny::renderPlot, shiny::renderPlot)
})

test_that("extended inputs are identical to shiny without extras", {
  same <- function(a, b) expect_identical(as.character(a), as.character(b))
  same(hotShiny::textInput("x", "X", "v"), shiny::textInput("x", "X", "v"))
  same(hotShiny::selectInput("s", "S", c("a", "b")), shiny::selectInput("s", "S", c("a", "b")))
  same(hotShiny::sliderInput("n", "N", 1, 10, 5), shiny::sliderInput("n", "N", 1, 10, 5))
  same(hotShiny::radioButtons("r", "R", c("a", "b")), shiny::radioButtons("r", "R", c("a", "b")))
  same(hotShiny::textInput("x", "X", updateOn = "blur"), shiny::textInput("x", "X", updateOn = "blur"))
})

test_that("extra attributes match tagAppendAttributes()", {
  expect_identical(
    as.character(hotShiny::textInput("x", NULL, class = "rounded-xl", `data-k` = "1")),
    as.character(htmltools::tagAppendAttributes(shiny::textInput("x", NULL), class = "rounded-xl",
                                                `data-k` = "1", .cssSelector = "input"))
  )
  expect_identical(
    as.character(hotShiny::checkboxGroupInput("g", "G", c("a", "b"), class = "ring-2")),
    as.character(htmltools::tagAppendAttributes(shiny::checkboxGroupInput("g", "G", c("a", "b")),
                                                class = "ring-2"))
  )
})
