library(hotShiny)
library(shinymanager)

credentials <- data.frame(
  user = c("alice", "bob"),
  password = c("wonderland", "builder"),
  admin = c(FALSE, TRUE),
  role = c("analyst", "manager"),
  stringsAsFactors = FALSE
)

ui <- fluidPage(
  h2(id = "app_title", "Secured app"),
  numericInput("n", "n", 2),
  textOutput("doubled"),
  verbatimTextOutput("auth_info")
)

ui <- secure_app(ui)

server <- function(input, output, session) {
  res_auth <- secure_server(check_credentials = check_credentials(credentials))
  output$doubled <- renderText(paste0("doubled=", input$n * 2))
  output$auth_info <- renderPrint({
    cat(sprintf("user=%s role=%s admin=%s", res_auth$user, res_auth$role, res_auth$admin))
  })
}

shinyApp(ui, server)
