library(hotShiny)
library(logger)

log_threshold(INFO)
# Plain layout so the e2e spec can match lines exactly; logs go to stderr.
log_layout(layout_glue_generator("{level} {msg}"))

# Also show every log line in the page, to see logging order from the browser.
log_lines <- NULL
log_appender(function(lines) {
  cat(lines, sep = "\n", file = stderr())
  if (!is.null(log_lines)) log_lines(c(isolate(log_lines()), lines))
})

ui <- fluidPage(
  h2("logger"),
  textInput("name", "Name", "ann"),
  numericInput("n", "n", 1),
  textInput("ignored", "Not logged", "x"),
  actionButton("go", "Go"),
  verbatimTextOutput("log")
)

server <- function(input, output, session) {
  log_lines <<- reactiveVal(character())
  log_shiny_input_changes(input, excluded_inputs = "ignored")
  output$log <- renderText(paste(log_lines(), collapse = "\n"))
}

shinyApp(ui, server)
