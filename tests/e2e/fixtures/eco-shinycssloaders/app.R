library(hotShiny)
library(shinycssloaders)

ui <- fluidPage(
  h2("shinycssloaders"),
  actionButton("redraw", "Redraw"),
  actionButton("fail", "Fail"),
  actionButton("recover", "Recover"),
  actionButton("page", "Page spinner"),
  actionButton("manual_show", "Show table spinner"),
  actionButton("manual_hide", "Hide table spinner"),
  textOutput("page_done"),
  fluidRow(
    column(6, withSpinner(plotOutput("plot", height = "250px"), type = 1)),
    column(6, withSpinner(textOutput("maybe"), type = 4, color = "#0dc5c1", proxy.height = "80px"))
  ),
  withSpinner(tableOutput("tbl"), type = 6, hide.ui = FALSE)
)

server <- function(input, output, session) {
  output$plot <- renderPlot({
    input$redraw
    if (input$redraw > 0) Sys.sleep(1.5)
    plot(1:10, main = paste("draw", input$redraw))
  })
  state <- reactiveVal("ok")
  observeEvent(input$fail, state("fail"))
  observeEvent(input$recover, state("ok"))
  output$maybe <- renderText({
    if (input$fail > 0 || input$recover > 0) Sys.sleep(0.8)
    if (state() == "fail") stop("boom from server")
    paste("value is", state())
  })
  observeEvent(input$page, showPageSpinner({
    Sys.sleep(1.2)
    output$page_done <- renderText(paste("page work done", input$page))
  }, caption = "Working on it"))
  observeEvent(input$manual_show, showSpinner("tbl"))
  observeEvent(input$manual_hide, hideSpinner("tbl"))
  output$tbl <- renderTable({
    input$redraw
    if (input$redraw > 0) Sys.sleep(1)
    data.frame(x = 1:3, y = c("a", "b", "c"))
  })
}

shinyApp(ui, server)
