counterUI <- function(id) {
  ns <- NS(id)
  tagList(
    h3(id = ns("label"), "Counter one"),
    actionButton(ns("inc"), "Increment"),
    textOutput(ns("count"))
  )
}

counterServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    count <- reactiveVal(0)
    observeEvent(input$inc, count(count() + 1))
    output$count <- renderText(paste0("count=", count()))
  })
}
