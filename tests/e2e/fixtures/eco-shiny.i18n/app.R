library(hotShiny)
library(shiny.i18n)

i18n <- Translator$new(translation_json_path = "translation.json")
i18n$set_translation_language("en")

langUI <- function(id) {
  ns <- NS(id)
  selectInput(ns("lang"), i18n$t("Language"), choices = i18n$get_languages(), selected = "en")
}

langServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    # update_lang() from inside a module must reach the root session
    observeEvent(input$lang, update_lang(input$lang), ignoreInit = TRUE)
  })
}

ui <- fluidPage(
  usei18n(i18n),
  h2(id = "hello", i18n$t("Hello")),
  p(id = "bye", i18n$t("Goodbye")),
  langUI("picker"),
  textOutput("server_text"),
  uiOutput("dynamic")
)

server <- function(input, output, session) {
  # creates the per-session language reactiveVal that server-side i18n$t() reads
  update_lang("en")
  langServer("picker")
  output$server_text <- renderText(paste0(i18n$t("Server says"), ": ", i18n$t("Hello")))
  output$dynamic <- renderUI(tags$span(id = "dyn", i18n$t("Goodbye")))
}

shinyApp(ui, server)
