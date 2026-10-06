library(hotShiny)
library(shinyvalidate)

ui <- fluidPage(
  h2("shinyvalidate"),
  textInput("name", "Name"),
  textInput("email", "Email"),
  numericInput("age", "Age", 10),
  checkboxInput("has_phone", "I have a phone"),
  textInput("phone", "Phone"),
  actionButton("submit", "Submit"),
  textOutput("valid"),
  textOutput("submitted")
)

server <- function(input, output, session) {
  iv <- InputValidator$new()
  iv$add_rule("name", sv_required())
  iv$add_rule("email", sv_required())
  iv$add_rule("email", sv_email())
  iv$add_rule("age", function(value) if (!is.na(value) && value < 18) "Must be 18 or older")

  phone_iv <- InputValidator$new()
  phone_iv$condition(~ isTRUE(input$has_phone))
  phone_iv$add_rule("phone", sv_required(message = "Phone is required"))
  phone_iv$add_rule("phone", ~ if (!grepl("^[0-9]+$", .)) "Digits only")
  iv$add_validator(phone_iv)

  output$valid <- renderText(paste("valid:", iv$is_valid()))
  observeEvent(input$submit, {
    iv$enable()
    output$submitted <- renderText(if (iv$is_valid()) paste("submitted", input$name) else "fix errors")
  })
}

shinyApp(ui, server)
