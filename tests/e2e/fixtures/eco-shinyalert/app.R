library(hotShiny)
library(shinyalert)

alertModuleUI <- function(id) {
  ns <- NS(id)
  tagList(actionButton(ns("ask"), "Module ask"), textOutput(ns("answer")))
}

alertModuleServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$ask, {
      shinyalert("Module question", "Proceed?", showCancelButton = TRUE, inputId = "modq",
                 callbackR = function(x) output$answer <- renderText(paste("module callback", x)))
    })
    output$answer <- renderText(if (!is.null(input$modq)) paste("module input", input$modq))
  })
}

ui <- fluidPage(
  h2("shinyalert"),
  actionButton("simple", "Simple"),
  actionButton("confirm", "Confirm"),
  actionButton("prompt", "Prompt"),
  actionButton("html", "HTML alert"),
  actionButton("chain", "Chain"),
  textOutput("confirm_result"),
  textOutput("prompt_result"),
  textOutput("input_value"),
  textOutput("chain_result"),
  alertModuleUI("m")
)

server <- function(input, output, session) {
  observeEvent(input$simple, shinyalert("Hello", "A simple alert", type = "success"))
  observeEvent(input$confirm, {
    shinyalert("Are you sure?", "Confirm or cancel", type = "warning", showCancelButton = TRUE,
               callbackR = function(value) output$confirm_result <- renderText(paste("confirmed:", value)))
  })
  observeEvent(input$prompt, {
    shinyalert("Your name", type = "input", inputPlaceholder = "type here", inputId = "name_alert",
               callbackR = function(value) output$prompt_result <- renderText(paste("hello", value)))
  })
  output$input_value <- renderText(paste("input$name_alert =", input$name_alert %||% "NULL"))
  observeEvent(input$html, {
    shinyalert("Rich", html = TRUE, text = tagList(
      textInput("inside", "Inside alert", "abc"),
      textOutput("inside_echo")
    ))
  })
  output$inside_echo <- renderText(paste("echo", input$inside))
  observeEvent(input$chain, {
    shinyalert("First", "Then a second", callbackR = function(x) {
      shinyalert("Second", "Done", callbackR = function(y) output$chain_result <- renderText("chain finished"))
    })
  })
  alertModuleServer("m")
}

shinyApp(ui, server)
