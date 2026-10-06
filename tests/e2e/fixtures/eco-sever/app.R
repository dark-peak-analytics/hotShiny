library(hotShiny)
library(sever)

ui <- fluidPage(
  useSever(),
  h2("sever"),
  actionButton("close", "Close session"),
  actionButton("fail", "Fail output"),
  textOutput("session_info"),
  textOutput("maybe")
)

server <- function(input, output, session) {
  sever(
    html = sever_default(title = "Gone", subtitle = "The session was closed", button = "Reconnect now"),
    bg_color = "rgb(10, 20, 30)", color = "rgb(255, 255, 255)"
  )
  cleave(html = span(id = "cleaved", "Output broke"), bg_color = "rgb(250, 240, 230)")
  output$session_info <- renderText("session alive")
  output$maybe <- renderText({
    if (input$fail > 0) stop("kaput")
    "output fine"
  })
  observeEvent(input$close, session$close())
}

shinyApp(ui, server)
