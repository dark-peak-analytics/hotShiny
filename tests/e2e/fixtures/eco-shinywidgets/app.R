library(hotShiny)
library(shinyWidgets)

show <- function(x) {
  if (is.null(x)) return("NULL")
  paste0(class(x)[1], ":", paste(format(x), collapse = ","))
}

ui <- fluidPage(
  h2("shinyWidgets"),
  fluidRow(
    column(4,
      pickerInput("pk1", "Picker", choices = c("alpha", "beta", "gamma", "delta"),
                  selected = "beta", options = pickerOptions(liveSearch = TRUE)),
      textOutput("o_pk1"),
      pickerInput("pk2", "Picker multiple", choices = c("x", "y", "z"), multiple = TRUE,
                  options = pickerOptions(actionsBox = TRUE)),
      textOutput("o_pk2"),
      switchInput("sw", "Switch", value = TRUE),
      textOutput("o_sw"),
      materialSwitch("ms", "Material", value = FALSE, status = "primary"),
      textOutput("o_ms"),
      prettyCheckbox("pc", "Pretty", value = FALSE, status = "success"),
      textOutput("o_pc")
    ),
    column(4,
      radioGroupButtons("rgb", "Group buttons", choices = c("one", "two", "three"), selected = "one"),
      textOutput("o_rgb"),
      airDatepickerInput("adp", "Air date", value = as.Date("2024-03-15")),
      textOutput("o_adp"),
      sliderTextInput("stx", "Slider text", choices = c("low", "mid", "high"), selected = "mid"),
      textOutput("o_stx"),
      noUiSliderInput("nus", "noUi", min = 0, max = 100, value = 40, step = 1),
      textOutput("o_nus"),
      virtualSelectInput("vs", "Virtual select", choices = c("red", "green", "blue"), selected = "red"),
      textOutput("o_vs")
    ),
    column(4,
      actionButton("upd", "Update all"),
      actionButton("alert", "Sweet alert"),
      actionButton("confirm_btn", "Confirm alert"),
      textOutput("o_confirm"),
      dropdownButton(
        inputId = "dd", label = "Dropdown", circle = FALSE,
        textInput("dd_text", "Inside dropdown", value = "a")
      ),
      textOutput("o_dd")
    )
  )
)

server <- function(input, output, session) {
  output$o_pk1 <- renderText(show(input$pk1))
  output$o_pk2 <- renderText(show(input$pk2))
  output$o_sw <- renderText(show(input$sw))
  output$o_ms <- renderText(show(input$ms))
  output$o_pc <- renderText(show(input$pc))
  output$o_rgb <- renderText(show(input$rgb))
  output$o_adp <- renderText(show(input$adp))
  output$o_stx <- renderText(show(input$stx))
  output$o_nus <- renderText(show(input$nus))
  output$o_vs <- renderText(show(input$vs))
  output$o_confirm <- renderText(show(input$confirm))
  output$o_dd <- renderText(paste0("state=", show(input$dd_state), " text=", input$dd_text))

  # update*() without a session argument rely on the default reactive domain.
  observeEvent(input$upd, {
    updatePickerInput(inputId = "pk1", selected = "delta")
    updatePickerInput(inputId = "pk2", choices = c("x", "y", "z", "w"), selected = c("y", "w"))
    updateSwitchInput(inputId = "sw", value = FALSE)
    updateMaterialSwitch(session, "ms", value = TRUE)
    updatePrettyCheckbox(inputId = "pc", value = TRUE)
    updateRadioGroupButtons(inputId = "rgb", selected = "three")
    updateAirDateInput(inputId = "adp", value = as.Date("2025-01-02"))
    updateSliderTextInput(inputId = "stx", selected = "high")
    updateNoUiSliderInput(inputId = "nus", value = 75)
    updateVirtualSelect("vs", selected = "blue")
  })

  observeEvent(input$alert, {
    sendSweetAlert(title = "Hello", text = "From the server", type = "success")
  })
  observeEvent(input$confirm_btn, {
    confirmSweetAlert(inputId = "confirm", title = "Sure?", btn_labels = c("No", "Yes"))
  })
}

shinyApp(ui, server)
