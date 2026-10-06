library(hotShiny)
library(echarts4r)

df <- data.frame(fruit = c("apple", "banana", "cherry", "date"), sales = c(3, 7, 5, 2))

ui <- fluidPage(
  h2("echarts4r"),
  echarts4rOutput("bars", height = "300px"),
  textOutput("clicked"),
  actionButton("add_series", "Add series")
)

server <- function(input, output, session) {
  output$bars <- renderEcharts4r({
    df |>
      e_charts(fruit) |>
      e_bar(sales, name = "sales") |>
      e_animation(show = FALSE)
  })
  output$clicked <- renderText({
    d <- input$bars_clicked_data
    if (is.null(d)) "clicked: none"
    else sprintf("clicked: %s = %s (row %s, %s)", d$value[1], d$value[2],
                 input$bars_clicked_row, input$bars_clicked_serie)
  })
  observeEvent(input$add_series, {
    echarts4rProxy("bars", data = transform(df, target = sales + 1), x = fruit) |>
      e_line(target, name = "target") |>
      e_execute()
  })
}

shinyApp(ui, server)
