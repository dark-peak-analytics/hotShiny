library(hotShiny)

counterUI <- function(id, label) {
  ns <- NS(id)
  wellPanel(
    id = ns("panel"),
    h4(label),
    actionButton(ns("inc"), "Increment"),
    textInput(ns("name"), "Name", value = id),
    textOutput(ns("count")),
    textOutput(ns("greeting"))
  )
}

counterServer <- function(id, step = 1) {
  moduleServer(id, function(input, output, session) {
    count <- reactiveVal(0)
    observeEvent(input$inc, count(count() + step))
    output$count <- renderText(paste0("count=", count()))
    output$greeting <- renderText(paste0("hi ", input$name, " from ", session$ns("")))
    reactive(count())
  })
}

ui <- fluidPage(
  h2("Reactivity"),
  fluidRow(
    column(6,
      counterUI("a", "Counter A"),
      counterUI("b", "Counter B (step 10)"),
      textOutput("total")
    ),
    column(6,
      h4("reactiveValues + isolate"),
      numericInput("x", "x", 1),
      actionButton("snap", "Snapshot x"),
      textOutput("snapshot"),
      textOutput("doubled"),
      h4("eventReactive / ignoreInit"),
      actionButton("go", "Go"),
      textOutput("event_result"),
      textOutput("observer_runs"),
      h4("Generated outputs"),
      lapply(1:3, function(i) textInput(paste0("gen", i), paste("Gen", i), value = paste0("v", i))),
      lapply(1:3, function(i) textOutput(paste0("gen_out", i))),
      textOutput("gen_all"),
      h4("Timers"),
      textOutput("ticks"),
      h4("debounce"),
      textInput("typing", "Type quickly"),
      textOutput("debounced")
    )
  )
)

server <- function(input, output, session) {
  a <- counterServer("a")
  b <- counterServer("b", step = 10)
  output$total <- renderText(paste0("total=", a() + b()))

  rv <- reactiveValues(snap = NULL, runs = 0)
  observeEvent(input$snap, rv$snap <- input$x)
  output$snapshot <- renderText(paste0("snapshot=", if (is.null(rv$snap)) "none" else rv$snap))
  doubled <- reactive(input$x * 2)
  output$doubled <- renderText(paste0("doubled=", doubled(), " isolated-snap=", isolate(rv$snap) %||% "none"))

  res <- eventReactive(input$go, paste0("went with x=", input$x))
  output$event_result <- renderText(res())
  observeEvent(input$go, rv$runs <- rv$runs + 1, ignoreInit = TRUE)
  output$observer_runs <- renderText(paste0("runs=", rv$runs))

  lapply(1:3, function(i) {
    output[[paste0("gen_out", i)]] <- renderText(paste0("gen", i, "=", input[[paste0("gen", i)]]))
  })
  output$gen_all <- renderText(paste(vapply(1:3, function(i) input[[paste0("gen", i)]] %||% "", ""), collapse = "|"))

  ticks <- reactiveVal(0)
  observe({
    invalidateLater(300)
    isolate(ticks(ticks() + 1))
  })
  output$ticks <- renderText(paste0("ticking=", ticks() > 2))

  typed <- debounce(reactive(input$typing), 400)
  output$debounced <- renderText(paste0("debounced=", typed()))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

shinyApp(ui, server)
