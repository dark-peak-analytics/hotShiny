library(hotShiny)
library(shinytoastr)

modUI <- function(id) actionButton(NS(id, "warn"), "Module warning")
modServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$warn, toastr_warning(paste("module warning", input$warn), timeOut = 0))
  })
}

ui <- fluidPage(
  useToastr(),
  h2("shinytoastr"),
  actionButton("success", "Success"),
  actionButton("error", "Error"),
  actionButton("info", "Info"),
  actionButton("quick", "Quick"),
  modUI("m")
)

server <- function(input, output, session) {
  observeEvent(input$success, toastr_success("It worked", title = "Yay", timeOut = 0, closeButton = TRUE))
  observeEvent(input$error, toastr_error("It broke", position = "bottom-left", timeOut = 0, progressBar = TRUE))
  observeEvent(input$info, toastr_info(paste("info", input$info), newestOnTop = TRUE, timeOut = 0))
  observeEvent(input$quick, toastr_success("gone soon", timeOut = 500, hideDuration = 100))
  modServer("m")
}

shinyApp(ui, server)
