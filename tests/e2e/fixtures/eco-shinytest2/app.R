library(hotShiny)

counterUI <- function(id) {
  ns <- NS(id)
  tagList(actionButton(ns("inc"), "Increment"), textOutput(ns("count")))
}

counterServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    count <- reactiveVal(0)
    observeEvent(input$inc, count(count() + 1))
    output$count <- renderText(paste0("count=", count()))
    exportTestValues(count = count())
    count
  })
}

ui <- fluidPage(
  h2("shinytest2"),
  textInput("name", "Name", "world"),
  numericInput("n", "n", 2, min = 0, max = 10),
  selectInput("letter", "Letter", c("a", "b", "c")),
  checkboxInput("shout", "Shout", FALSE),
  actionButton("go", "Go"),
  textOutput("greeting"),
  verbatimTextOutput("summary"),
  uiOutput("html_out"),
  textOutput("failing"),
  textOutput("secret"),
  textOutput("rounded"),
  counterUI("counter"),
  fileInput("upload", "Upload CSV", accept = ".csv"),
  tableOutput("contents"),
  downloadButton("dl", "Download")
)

server <- function(input, output, session) {
  clicks <- reactiveVal(0)
  observeEvent(input$go, clicks(clicks() + 1))
  counter <- counterServer("counter")

  output$greeting <- renderText({
    g <- paste0("Hello ", input$name, " x", input$n, " (", input$letter, ")")
    if (isTRUE(input$shout)) toupper(g) else g
  })
  output$summary <- renderPrint(list(clicks = clicks(), n = input$n))
  output$html_out <- renderUI(tags$em(id = "em", paste("clicked", clicks(), "times")))
  output$failing <- renderText({
    if (input$n > 5) stop("n is too large")
    "n ok"
  })
  output$secret <- snapshotExclude(renderText(paste("secret", clicks())))
  output$rounded <- snapshotPreprocessOutput(
    renderText(paste0("pi=", pi * input$n)),
    function(value) sub("([0-9]+\\.[0-9]{2}).*", "\\1", value)
  )
  snapshotPreprocessInput("name", function(value) toupper(value))

  data <- reactive({
    req(input$upload)
    utils::read.csv(input$upload$datapath)
  })
  output$contents <- renderTable(data())

  output$dl <- downloadHandler(
    filename = function() paste0("report-", input$name, ".txt"),
    content = function(file) writeLines(c(paste("name:", input$name), paste("n:", input$n)), file)
  )

  exportTestValues(
    clicks = clicks(),
    name_upper = toupper(input$name),
    rows = if (is.null(input$upload)) 0L else nrow(data())
  )
}

shinyApp(ui, server)
