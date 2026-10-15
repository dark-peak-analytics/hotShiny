library(hotShiny)
library(shinyWidgets)

show <- function(x) {
  if (is.null(x)) return("NULL")
  paste0(class(x)[1], ":", paste(format(x), collapse = ","))
}

ui <- fluidPage(
  h2("More shinyWidgets"),
  fluidRow(
    column(6,
      checkboxGroupButtons("cgb", "Checkbox buttons", choices = c("p", "q", "r"), selected = "p"),
      textOutput("o_cgb"),
      awesomeRadio("ar", "Awesome radio", choices = c("left", "right"), selected = "left"),
      textOutput("o_ar"),
      searchInput("si", "Search", btnSearch = icon("magnifying-glass"), btnReset = icon("xmark")),
      textOutput("o_si"),
      numericRangeInput("nri", "Range", value = c(10, 20)),
      textOutput("o_nri")
    ),
    column(6,
      airDatepickerInput("rng", "Date range", range = TRUE,
                         value = as.Date(c("2024-05-01", "2024-05-10"))),
      textOutput("o_rng"),
      airDatepickerInput("dt", "Date time", timepicker = TRUE, tz = "UTC",
                         value = as.POSIXct("2024-05-01 10:30:00", tz = "UTC")),
      textOutput("o_dt"),
      knobInput("kn", "Knob", value = 30, min = 0, max = 100, width = "120px", height = "120px"),
      textOutput("o_kn"),
      actionButton("upd", "Update")
    )
  )
)

server <- function(input, output, session) {
  output$o_cgb <- renderText(show(input$cgb))
  output$o_ar <- renderText(show(input$ar))
  output$o_si <- renderText(show(input$si))
  output$o_nri <- renderText(show(input$nri))
  output$o_rng <- renderText(show(input$rng))
  output$o_dt <- renderText(show(format(input$dt, "%Y-%m-%d %H:%M %Z")))
  output$o_kn <- renderText(show(input$kn))
  observeEvent(input$upd, {
    updateCheckboxGroupButtons(inputId = "cgb", selected = c("q", "r"))
    updateAwesomeRadio(session, "ar", selected = "right")
    updateSearchInput(session, "si", value = "found", trigger = TRUE)
    updateNumericRangeInput(inputId = "nri", value = c(1, 2))
    updateAirDateInput(session, "rng", value = as.Date(c("2025-06-01", "2025-06-03")))
    updateKnobInput(session, "kn", value = 70)
  })
}

shinyApp(ui, server)
