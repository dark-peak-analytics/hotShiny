library(hotShiny)
library(shinyFeedback)

modUI <- function(id) {
  ns <- NS(id)
  numericInput(ns("qty"), "Module quantity", 1)
}

modServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$qty, {
      feedbackWarning("qty", isTRUE(input$qty > 10), "That is a lot")
    })
  })
}

ui <- fluidPage(
  useShinyFeedback(),
  h2("shinyFeedback"),
  numericInput("num", "Number (must be even)", 2),
  textInput("word", "Word"),
  selectInput("pick", "Pick", c("ok", "bad")),
  loadingButton("save", "Save", loadingLabel = "Saving..."),
  textOutput("saved"),
  actionButton("toast", "Toast"),
  modUI("m")
)

server <- function(input, output, session) {
  observeEvent(input$num, {
    if (!is.na(input$num) && input$num %% 2 != 0) {
      showFeedbackDanger("num", text = "Odd numbers are not allowed")
    } else {
      hideFeedback("num")
    }
  })
  observeEvent(input$word, {
    if (nzchar(input$word)) {
      showFeedbackSuccess("word", text = "Nice word")
    } else {
      hideFeedback("word")
    }
  })
  observeEvent(input$pick, feedbackDanger("pick", input$pick == "bad", "Bad pick"))
  observeEvent(input$save, {
    Sys.sleep(1.5)
    resetLoadingButton("save")
    output$saved <- renderText(paste("saved", input$save))
  })
  observeEvent(input$toast, showToast("success", "Toasted!", .options = list(timeOut = 0)))
  modServer("m")
}

shinyApp(ui, server)
