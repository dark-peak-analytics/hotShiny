library(hotShiny)
library(colourpicker)

ui <- fluidPage(
  h2("colourpicker"),
  colourInput("col", "Colour", value = "#FF0000"),
  textOutput("o_col"),
  colourInput("col_lim", "Limited palette", value = "blue", palette = "limited",
              allowedCols = c("red", "blue", "green")),
  textOutput("o_col_lim"),
  colourInput("col_alpha", "With alpha", value = "#00FF0080", allowTransparent = TRUE),
  textOutput("o_col_alpha"),
  actionButton("upd", "Update"),
  plotOutput("plot", height = "120px")
)

server <- function(input, output, session) {
  output$o_col <- renderText(paste0("col=", input$col))
  output$o_col_lim <- renderText(paste0("lim=", input$col_lim))
  output$o_col_alpha <- renderText(paste0("alpha=", input$col_alpha))
  output$plot <- renderPlot({
    par(mar = c(0, 0, 0, 0))
    plot.new()
    rect(0, 0, 1, 1, col = input$col, border = NA)
  })
  observeEvent(input$upd, {
    updateColourInput(session, "col", value = "#123456", label = "Relabelled")
    updateColourInput(session, "col_lim", value = "green")
  })
}

shinyApp(ui, server)
