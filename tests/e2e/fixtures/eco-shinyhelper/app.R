library(hotShiny)
library(shinyhelper)

ui <- fluidPage(
  h2("shinyhelper"),
  helper(sliderInput("bins", "Bins", 1, 50, 10), type = "markdown", content = "bins"),
  helper(textInput("name", "Name"), type = "inline", title = "About names",
         content = c("Type <b>your</b> name.", "Second line."), size = "s", buttonLabel = "Got it"),
  helper(numericInput("missing", "Missing help", 1), type = "markdown", content = "nope",
         icon = "circle-exclamation", colour = "red"),
  uiOutput("dynamic"),
  textOutput("echo")
)

server <- function(input, output, session) {
  observe_helpers(help_dir = "helpfiles")
  output$dynamic <- renderUI(
    helper(checkboxInput("dyn", "Dynamic input"), type = "inline", title = "Dynamic help",
           content = "Rendered by renderUI")
  )
  output$echo <- renderText(paste("bins", input$bins))
}

shinyApp(ui, server)
