library(hotShiny)
library(reactable)

cars <- mtcars[1:12, 1:4]

ui <- fluidPage(
  h2("reactable"),
  reactableOutput("tbl"),
  textOutput("selected"),
  textOutput("page"),
  actionButton("select_two", "Select rows 2 and 3"),
  actionButton("clear", "Clear selection"),
  actionButton("filter_merc", "Show only Merc")
)

server <- function(input, output, session) {
  shown <- reactiveVal(cars)
  output$tbl <- renderReactable({
    reactable(shown(), searchable = TRUE, selection = "multiple", onClick = "select",
              defaultPageSize = 5, rownames = TRUE)
  })
  output$selected <- renderText({
    paste("selected:", paste(getReactableState("tbl", "selected"), collapse = ","))
  })
  output$page <- renderText(paste("page:", getReactableState("tbl", "page")))
  observeEvent(input$select_two, updateReactable("tbl", selected = c(2, 3)))
  observeEvent(input$clear, updateReactable("tbl", selected = NA))
  observeEvent(input$filter_merc, {
    shown(cars[grepl("Merc", rownames(cars)), ])
  })
}

shinyApp(ui, server)
