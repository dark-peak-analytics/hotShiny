library(hotShiny)
library(shinyAce)

ui <- fluidPage(
  h2("shinyAce"),
  aceEditor("ed", value = "x <- 1", mode = "r", height = "150px",
            autoComplete = "live", autoCompleters = "rlang", debounce = 100),
  textOutput("o_ed"),
  aceEditor("ro", value = "read only", readOnly = TRUE, height = "60px"),
  actionButton("upd", "Update"),
  actionButton("mode", "Python mode")
)

server <- function(input, output, session) {
  aceAutocomplete("ed")
  output$o_ed <- renderText(paste0("ed=", gsub("\n", "\\\\n", input$ed)))
  observeEvent(input$upd, updateAceEditor(session, "ed", value = "y <- 2\nz <- 3"))
  observeEvent(input$mode, updateAceEditor(session, "ed", mode = "python"))
}

shinyApp(ui, server)
