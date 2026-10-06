library(hotShiny)
library(dygraphs)

ui <- fluidPage(
  h2("dygraphs"),
  sliderInput("smooth", "Roll period", min = 1, max = 12, value = 1),
  dygraphOutput("dy", height = "300px"),
  textOutput("window"),
  textOutput("clicked")
)

server <- function(input, output, session) {
  output$dy <- renderDygraph({
    dygraph(ldeaths, main = "Deaths") |>
      dyRoller(rollPeriod = input$smooth) |>
      dyRangeSelector() |>
      dyOptions(animatedZooms = FALSE)
  })
  output$window <- renderText({
    w <- input$dy_date_window
    if (is.null(w)) "window: none" else paste("window:", paste(substr(w, 1, 7), collapse = " to "))
  })
  output$clicked <- renderText({
    req(input$dy_click)
    paste("clicked:", substr(input$dy_click$x, 1, 7))
  })
}

shinyApp(ui, server)
