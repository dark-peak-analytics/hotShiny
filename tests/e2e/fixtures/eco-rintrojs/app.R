library(hotShiny)
library(rintrojs)

ui <- fluidPage(
  introjsUI(),
  h2("rintrojs"),
  introBox(actionButton("tour", "Start tour"), data.step = 1, data.intro = "This button starts the tour"),
  introBox(textInput("name", "Name"), data.step = 2, data.intro = "Type your name here"),
  div(id = "server_step", "A step defined on the server"),
  textOutput("tour_state")
)

server <- function(input, output, session) {
  done <- reactiveVal("not finished")
  observeEvent(input$tour, {
    introjs(session,
      options = list(
        steps = data.frame(
          element = c("#tour", "#name", "#server_step"),
          intro = c("This button starts the tour", "Type your name here", "Defined in R")
        ),
        nextLabel = "Onward", prevLabel = "Back", doneLabel = "Finish"
      ),
      events = list(oncomplete = I('Shiny.setInputValue("tour_done", Date.now());'))
    )
  })
  observeEvent(input$tour_done, done("finished"))
  output$tour_state <- renderText(paste("tour", done()))
}

shinyApp(ui, server)
