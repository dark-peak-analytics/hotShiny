library(hotShiny)
library(promises)
library(future)

# Two background workers at most: the e2e suite shares the machine.
plan(multisession, workers = 2)

ui <- fluidPage(
  h2("Async"),
  fluidRow(
    column(4,
      h4("Synchronous"),
      numericInput("n", "n", 1),
      textOutput("fast")
    ),
    column(4,
      h4("future_promise output"),
      actionButton("go_future", "Compute in future"),
      textOutput("future_out"),
      actionButton("go_slow", "Slow future"),
      textOutput("slow_out"),
      h4("promises + later"),
      actionButton("go_later", "Resolve via later"),
      textOutput("later_out"),
      actionButton("go_fail", "Reject"),
      textOutput("fail_out")
    ),
    column(4,
      h4("ExtendedTask"),
      actionButton("run_task", "Run task"),
      textOutput("task_status"),
      textOutput("task_result"),
      textOutput("task_runs"),
      h4("Async renderUI"),
      actionButton("go_ui", "Build UI"),
      uiOutput("async_ui")
    )
  )
)

server <- function(input, output, session) {
  output$fast <- renderText(paste0("fast=", input$n * 2))

  output$future_out <- renderText({
    req(input$go_future)
    n <- isolate(input$n)
    future_promise({
      Sys.sleep(1)
      c(value = n * 10, worker = Sys.getpid())
    }) %...>% (function(v) {
      paste0("future=", v[["value"]], " in-worker=", v[["worker"]] != Sys.getpid())
    })
  })

  output$slow_out <- renderText({
    req(input$go_slow)
    future_promise({
      Sys.sleep(4)
      "slow done"
    })
  })

  output$later_out <- renderText({
    req(input$go_later)
    k <- input$go_later
    promise(function(resolve, reject) {
      later::later(function() resolve(k), 0.5)
    }) %...>% (function(v) paste0("later=", v))
  })

  output$fail_out <- renderText({
    req(input$go_fail)
    promise(function(resolve, reject) {
      later::later(function() reject(simpleError("async boom")), 0.2)
    }) %...>% (function(v) "never")
  })

  runs <- reactiveVal(0)
  task <- ExtendedTask$new(function(n) {
    future_promise({
      Sys.sleep(1.5)
      n + 100
    })
  })
  observeEvent(input$run_task, {
    runs(runs() + 1)
    task$invoke(input$n)
  })
  output$task_status <- renderText(paste0("status=", task$status()))
  output$task_result <- renderText(paste0("result=", task$result()))
  output$task_runs <- renderText(paste0("runs=", runs()))

  output$async_ui <- renderUI({
    req(input$go_ui)
    n <- isolate(input$n)
    promise(function(resolve, reject) {
      later::later(function() resolve(n), 0.3)
    }) %...>% (function(v) {
      tagList(
        tags$b(id = "ui_label", paste0("ui for n=", v)),
        textInput("dyn_text", "Dynamic text", value = paste0("seed", v)),
        textOutput("dyn_echo")
      )
    })
  })
  output$dyn_echo <- renderText(paste0("echo=", input$dyn_text))
}

shinyApp(ui, server)
