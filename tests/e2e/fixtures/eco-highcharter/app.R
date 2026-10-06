library(hotShiny)
library(highcharter)

ui <- fluidPage(
  h2("highcharter"),
  highchartOutput("hc", height = "300px"),
  textOutput("clicked"),
  actionButton("add_series", "Add series")
)

server <- function(input, output, session) {
  output$hc <- renderHighchart({
    highchart() |>
      hc_chart(type = "column", animation = FALSE) |>
      hc_xAxis(categories = c("a", "b", "c")) |>
      hc_plotOptions(series = list(animation = FALSE)) |>
      hc_add_series(name = "first", data = c(3, 6, 2)) |>
      hc_add_event_point(event = "click")
  })
  output$clicked <- renderText({
    d <- input$hc_click
    if (is.null(d)) "clicked: none" else sprintf("clicked: %s x=%s y=%s", d$series, d$x, d$y)
  })
  observeEvent(input$add_series, {
    highchartProxy("hc") |>
      hcpxy_add_series(name = "second", data = c(1, 2, 3), id = "second")
  })
}

shinyApp(ui, server)
