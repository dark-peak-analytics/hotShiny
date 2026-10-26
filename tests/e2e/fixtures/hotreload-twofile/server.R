library(hotShiny)

function(input, output, session) {
  counterServer("counter")
  output$greeting <- renderText(paste(greeting_prefix, input$name))
}
