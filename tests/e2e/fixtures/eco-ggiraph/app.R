library(hotShiny)
library(ggiraph)
library(ggplot2)

cars <- mtcars[1:8, ]
cars$name <- rownames(cars)

ui <- fluidPage(
  h2("ggiraph"),
  girafeOutput("plot", width = "500px", height = "400px"),
  textOutput("selected"),
  actionButton("select_two", "Select Mazda RX4 and Valiant"),
  actionButton("reset", "Clear selection")
)

server <- function(input, output, session) {
  output$plot <- renderGirafe({
    p <- ggplot(cars, aes(wt, mpg, data_id = name, tooltip = name)) +
      geom_point_interactive(size = 4) +
      theme_minimal()
    girafe(ggobj = p, width_svg = 5, height_svg = 4,
           options = list(opts_selection(type = "multiple"), opts_sizing(rescale = FALSE)))
  })
  output$selected <- renderText({
    paste("selected:", paste(sort(input$plot_selected), collapse = ","))
  })
  observeEvent(input$select_two, {
    session$sendCustomMessage("plot_set", c("Mazda RX4", "Valiant"))
  })
  observeEvent(input$reset, {
    session$sendCustomMessage("plot_set", character(0))
  })
}

shinyApp(ui, server)
