library(hotShiny)
library(shinybusy)

ui <- fluidPage(
  add_busy_spinner(spin = "fading-circle", position = "top-right", timeout = 100),
  add_busy_bar(color = "rgb(255, 0, 0)", timeout = 100),
  h2("shinybusy"),
  actionButton("slow", "Slow work"),
  actionButton("modal", "Modal spinner"),
  actionButton("progress", "Modal progress"),
  actionButton("notify", "Notify"),
  actionButton("report", "Report"),
  textOutput("slow_done"),
  textOutput("modal_done"),
  textOutput("progress_done"),
  plotOutput("plot", height = "200px")
)

server <- function(input, output, session) {
  output$slow_done <- renderText({
    if (input$slow > 0) Sys.sleep(1.5)
    paste("slow", input$slow)
  })
  observeEvent(input$modal, {
    show_modal_spinner(spin = "cube-grid", color = "firebrick", text = "Please wait...")
    Sys.sleep(1)
    update_modal_spinner(text = "Nearly done")
    Sys.sleep(1)
    remove_modal_spinner()
    output$modal_done <- renderText(paste("modal done", input$modal))
  })
  observeEvent(input$progress, {
    show_modal_progress_line(text = "Progress")
    for (i in 1:5) {
      update_modal_progress(value = i / 5, text = paste("step", i))
      Sys.sleep(0.3)
    }
    remove_modal_progress()
    output$progress_done <- renderText("progress done")
  })
  observeEvent(input$notify, notify_success("Saved!", position = "right-bottom"))
  observeEvent(input$report, report_success("All good", "The report body"))
  output$plot <- renderPlot(plot(1:5))
}

shinyApp(ui, server)
