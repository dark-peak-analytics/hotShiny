library(hotShiny)

ui <- fluidPage(
  titlePanel("Core inputs"),
  sidebarLayout(
    sidebarPanel(
      textInput("txt", "Text", value = "hello"),
      textAreaInput("area", "Text area", value = "line"),
      passwordInput("pwd", "Password"),
      numericInput("num", "Number", value = 5, min = 0, max = 10, step = 1),
      selectInput("sel", "Select", choices = c("Apple" = "a", "Banana" = "b", "Cherry" = "c"), selected = "b"),
      selectInput("selmulti", "Select multiple", choices = c("x", "y", "z"), multiple = TRUE),
      selectInput("selnative", "Native select", choices = c("one", "two"), selectize = FALSE),
      checkboxInput("chk", "Checkbox", value = TRUE),
      checkboxGroupInput("chkgrp", "Checkbox group", choices = c("r", "g", "b"), selected = "g", inline = TRUE),
      radioButtons("radio", "Radio", choices = c("low", "mid", "high"), selected = "mid"),
      sliderInput("slider", "Slider", min = 0, max = 100, value = 30),
      sliderInput("range", "Range", min = 0, max = 100, value = c(20, 80)),
      dateInput("date", "Date", value = "2024-03-15"),
      dateRangeInput("daterange", "Date range", start = "2024-01-01", end = "2024-01-31"),
      actionButton("btn", "Click me"),
      actionLink("lnk", "Link"),
      hr(),
      actionButton("update_all", "Update all inputs", class = "btn-warning")
    ),
    mainPanel(
      h3("Values"),
      tags$dl(
        tags$dt("txt"), tags$dd(textOutput("o_txt")),
        tags$dt("area"), tags$dd(textOutput("o_area")),
        tags$dt("pwd"), tags$dd(textOutput("o_pwd")),
        tags$dt("num"), tags$dd(textOutput("o_num")),
        tags$dt("sel"), tags$dd(textOutput("o_sel")),
        tags$dt("selmulti"), tags$dd(textOutput("o_selmulti")),
        tags$dt("selnative"), tags$dd(textOutput("o_selnative")),
        tags$dt("chk"), tags$dd(textOutput("o_chk")),
        tags$dt("chkgrp"), tags$dd(textOutput("o_chkgrp")),
        tags$dt("radio"), tags$dd(textOutput("o_radio")),
        tags$dt("slider"), tags$dd(textOutput("o_slider")),
        tags$dt("range"), tags$dd(textOutput("o_range")),
        tags$dt("date"), tags$dd(textOutput("o_date")),
        tags$dt("daterange"), tags$dd(textOutput("o_daterange")),
        tags$dt("btn"), tags$dd(textOutput("o_btn")),
        tags$dt("lnk"), tags$dd(textOutput("o_lnk"))
      )
    )
  )
)

fmt <- function(x) {
  if (is.null(x)) return("NULL")
  paste0(class(x)[1], ":", paste(format(x), collapse = ","))
}

server <- function(input, output, session) {
  output$o_txt <- renderText(fmt(input$txt))
  output$o_area <- renderText(fmt(input$area))
  output$o_pwd <- renderText(fmt(input$pwd))
  output$o_num <- renderText(fmt(input$num))
  output$o_sel <- renderText(fmt(input$sel))
  output$o_selmulti <- renderText(fmt(input$selmulti))
  output$o_selnative <- renderText(fmt(input$selnative))
  output$o_chk <- renderText(fmt(input$chk))
  output$o_chkgrp <- renderText(fmt(input$chkgrp))
  output$o_radio <- renderText(fmt(input$radio))
  output$o_slider <- renderText(fmt(input$slider))
  output$o_range <- renderText(fmt(input$range))
  output$o_date <- renderText(fmt(input$date))
  output$o_daterange <- renderText(fmt(input$daterange))
  output$o_btn <- renderText(fmt(as.integer(input$btn)))
  output$o_lnk <- renderText(fmt(as.integer(input$lnk)))

  observeEvent(input$update_all, {
    updateTextInput(session, "txt", value = "updated")
    updateTextAreaInput(session, "area", value = "new area")
    updateNumericInput(session, "num", value = 9)
    updateSelectInput(session, "sel", selected = "c")
    updateSelectInput(session, "selmulti", selected = c("x", "z"))
    updateCheckboxInput(session, "chk", value = FALSE)
    updateCheckboxGroupInput(session, "chkgrp", selected = c("r", "b"))
    updateRadioButtons(session, "radio", selected = "high")
    updateSliderInput(session, "slider", value = 77)
    updateSliderInput(session, "range", value = c(10, 40))
    updateDateInput(session, "date", value = "2025-12-25")
    updateDateRangeInput(session, "daterange", start = "2025-02-01", end = "2025-02-28")
    updateActionButton(session, "btn", label = "Relabelled")
  })
}

shinyApp(ui, server)
