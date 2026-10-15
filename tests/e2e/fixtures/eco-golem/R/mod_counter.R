#' counter UI Function
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_counter_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "golem-counter",
      actionButton(ns("inc"), paste("Increment", id)),
      textOutput(ns("count"))
    )
  )
}

#' counter Server Functions
#'
#' @noRd
mod_counter_server <- function(id, step = 1) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    count <- reactiveVal(0)
    observeEvent(input$inc, count(count() + step))
    output$count <- renderText(paste0(ns("count"), "=", count()))
    reactive(count())
  })
}
