library(hotShiny)
library(waiter)

ui <- fluidPage(
  useWaiter(),
  useWaitress(),
  autoWaiter("auto_txt", html = span("auto waiting"), color = "rgb(10, 20, 30)"),
  h2("waiter"),
  actionButton("full", "Full screen"),
  actionButton("redraw", "Redraw plot"),
  actionButton("manual", "Manual show"),
  actionButton("manual_hide", "Manual hide"),
  actionButton("auto", "Auto"),
  actionButton("progress", "Waitress"),
  textOutput("full_done"),
  fluidRow(
    column(6, plotOutput("plot", height = "250px")),
    column(6,
      div(id = "box", style = "height:120px;border:1px solid #ccc", "a box"),
      textOutput("auto_txt"),
      textOutput("progress_done")
    )
  )
)

server <- function(input, output, session) {
  observeEvent(input$full, {
    waiter_show(html = tagList(spin_fading_circles(), span(id = "full-msg", "Loading everything")))
    Sys.sleep(1)
    waiter_update(html = span(id = "full-msg", "Almost there"))
    Sys.sleep(1)
    waiter_hide()
    output$full_done <- renderText(paste("full done", input$full))
  })

  w <- Waiter$new(id = "plot", html = span(id = "plot-msg", "Plot loading"), color = "rgba(0, 0, 255, 0.5)")
  output$plot <- renderPlot({
    if (input$redraw > 0) {
      w$show()
      Sys.sleep(1.5)
    }
    plot(1:10, main = paste("draw", input$redraw))
  })

  box <- Waiter$new(id = "box", html = span(id = "box-msg", "Box busy"), color = "rgb(255, 255, 0)")
  observeEvent(input$manual, box$show())
  observeEvent(input$manual_hide, box$hide())

  output$auto_txt <- renderText({
    if (input$auto > 0) Sys.sleep(1)
    paste("auto", input$auto)
  })

  waitress <- Waitress$new("#box", theme = "overlay-percent")
  observeEvent(input$progress, {
    waitress$start()
    for (i in 1:4) {
      waitress$inc(25)
      Sys.sleep(0.3)
    }
    waitress$close()
    output$progress_done <- renderText("progress done")
  })
}

shinyApp(ui, server)
