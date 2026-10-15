library(hotShiny)
library(shinyWidgets)

cars <- data.frame(
  make = c("audi", "audi", "bmw", "bmw", "fiat"),
  fuel = c("petrol", "diesel", "petrol", "diesel", "petrol"),
  stringsAsFactors = FALSE
)

pickerModUI <- function(id) {
  ns <- NS(id)
  tagList(
    pickerInput(ns("pk"), "Module picker", choices = c("a", "b", "c")),
    textOutput(ns("o_pk")),
    actionButton(ns("upd"), "Update in module"),
    actionButton(ns("ask"), "Ask in module"),
    textOutput(ns("o_ok"))
  )
}

pickerModServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$o_pk <- renderText(paste0("pk=", input$pk))
    output$o_ok <- renderText(paste0("ok=", if (is.null(input$ok)) "NULL" else input$ok))
    # no session argument: the module's reactive domain namespaces the id
    observeEvent(input$upd, updatePickerInput(inputId = "pk", selected = "c"))
    observeEvent(input$ask, confirmSweetAlert(inputId = "ok", title = "Module question"))
  })
}

ui <- fluidPage(
  h2("shinyWidgets modules"),
  pickerModUI("m1"),
  actionButton("name_btn", "Ask name"),
  textOutput("o_name"),
  selectizeGroupUI("flt", params = list(
    make = list(inputId = "make", title = "Make"),
    fuel = list(inputId = "fuel", title = "Fuel")
  )),
  textOutput("o_rows")
)

server <- function(input, output, session) {
  pickerModServer("m1")
  observeEvent(input$name_btn, {
    inputSweetAlert(inputId = "name", title = "Your name?", input = "text")
  })
  output$o_name <- renderText(paste0("name=", if (is.null(input$name)) "NULL" else input$name))
  filtered <- callModule(selectizeGroupServer, "flt", data = cars, vars = c("make", "fuel"))
  output$o_rows <- renderText(paste0("rows=", nrow(filtered()), " makes=",
                                     paste(unique(filtered()$make), collapse = ",")))
}

shinyApp(ui, server)
