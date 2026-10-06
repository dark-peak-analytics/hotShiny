library(hotShiny)
library(shinyjs)

jsCode <- "shinyjs.paint = function(params) {
  var defaultParams = { id: null, col: 'red' };
  params = shinyjs.getParams(params, defaultParams);
  $('#' + params.id).css('background-color', params.col);
};"

panelUI <- function(id) {
  ns <- NS(id)
  div(
    id = ns("box"),
    h4("Module"),
    actionButton(ns("toggle"), "Toggle text"),
    actionButton(ns("paint"), "Paint"),
    actionButton(ns("disable"), "Disable input"),
    actionButton(ns("reset"), "Reset input"),
    textInput(ns("txt"), "Module text", "mod"),
    textOutput(ns("txt_value")),
    div(id = ns("msg"), "module message"),
    div(id = ns("clicked"), "not clicked")
  )
}

panelServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$toggle, toggle("msg"))
    observeEvent(input$paint, js$paint(id = session$ns("box"), col = "rgb(0, 128, 0)"))
    observeEvent(input$disable, disable("txt"))
    observeEvent(input$reset, reset("txt"))
    output$txt_value <- renderText(paste0("mod txt=", input$txt))
    onclick("msg", html("clicked", "module msg clicked"))
  })
}

ui <- fluidPage(
  useShinyjs(),
  extendShinyjs(text = jsCode, functions = c("paint")),
  tags$style(".highlight { color: rgb(200, 0, 0); }"),
  h2("shinyjs"),
  fluidRow(
    column(6,
      actionButton("hide", "Hide"),
      actionButton("show", "Show"),
      actionButton("toggle", "Toggle"),
      div(id = "target", "target text"),
      actionButton("disable", "Disable"),
      actionButton("enable", "Enable"),
      textInput("name", "Name", "initial"),
      actionButton("addcls", "Add class"),
      actionButton("rmcls", "Remove class"),
      div(id = "styled", "styled"),
      actionButton("delay", "Delayed"),
      div(id = "delayed", "waiting"),
      div(id = "clickme", "click me"),
      textOutput("clicks"),
      actionButton("runjs", "Run JS"),
      div(id = "jsout", ""),
      actionButton("paint", "Paint"),
      div(id = "canvas", "canvas"),
      actionButton("hidden_show", "Show hidden"),
      hidden(div(id = "hiddenbox", "was hidden"))
    ),
    column(6,
      div(id = "form",
        textInput("f_text", "Form text", "default text"),
        numericInput("f_num", "Form number", 5),
        checkboxInput("f_chk", "Form check", FALSE),
        selectInput("f_sel", "Form select", c("a", "b", "c"), "a")
      ),
      actionButton("reset", "Reset form"),
      actionButton("reset_one", "Reset text only"),
      textOutput("form_state"),
      panelUI("m1")
    )
  )
)

server <- function(input, output, session) {
  observeEvent(input$hide, hide("target"))
  observeEvent(input$show, show("target"))
  observeEvent(input$toggle, toggle("target"))
  observeEvent(input$disable, disable("name"))
  observeEvent(input$enable, enable("name"))
  observeEvent(input$addcls, addClass("styled", "highlight"))
  observeEvent(input$rmcls, removeClass("styled", "highlight"))
  observeEvent(input$delay, delay(300, html("delayed", "done after delay")))
  clicks <- reactiveVal(0)
  onclick("clickme", clicks(clicks() + 1))
  output$clicks <- renderText(paste0("clicks=", clicks()))
  observeEvent(input$runjs, runjs("document.getElementById('jsout').textContent = 'ran ' + (1 + 1);"))
  observeEvent(input$paint, js$paint(id = "canvas", col = "rgb(255, 0, 0)"))
  observeEvent(input$hidden_show, show("hiddenbox"))
  observeEvent(input$reset, reset("form"))
  observeEvent(input$reset_one, reset("f_text"))
  output$form_state <- renderText(paste(input$f_text, input$f_num, input$f_chk, input$f_sel, sep = "|"))
  panelServer("m1")
}

shinyApp(ui, server)
