library(hotShiny)

ui <- fluidPage(
  h2(id = "title", "Version one"),
  textInput("name", "Name", value = "initial"),
  checkboxInput("flag", "Flag", value = FALSE),
  selectInput("pick", "Pick", c("a", "b", "c")),
  actionButton("inc", "Increment"),
  textOutput("count"),
  textOutput("greeting"),
  div(id = "extra-slot")
)

server <- function(input, output, session) {
  count <- reactiveVal(0)
  observeEvent(input$inc, count(count() + 1))
  output$count <- renderText(paste0("count=", count()))
  output$greeting <- renderText(paste0("hello ", input$name))
}

shinyApp(ui, server)
