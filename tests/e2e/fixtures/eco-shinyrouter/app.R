library(hotShiny)
library(shiny.router)

home_page <- div(h3("Home page"), textOutput("o_home"))
other_page <- div(h3("Other page"), textInput("other_txt", "Other text", "o"), textOutput("o_other"))
params_page <- div(h3("Params page"), textOutput("o_params"))

ui <- fluidPage(
  h2("shiny.router"),
  tags$ul(
    tags$li(a(href = route_link("/"), id = "lnk_home", "Home")),
    tags$li(a(href = route_link("other"), id = "lnk_other", "Other")),
    tags$li(a(href = route_link("params?x=7&y=b"), id = "lnk_params", "Params"))
  ),
  actionButton("go_other", "Go to other from server"),
  textOutput("o_page"),
  router_ui(
    route("/", home_page),
    route("other", other_page),
    route("params", params_page),
    page_404 = page404(div(h3("Not found")))
  )
)

server <- function(input, output, session) {
  router_server()
  output$o_page <- renderText(paste0("page=", get_page()))
  output$o_home <- renderText("home output")
  output$o_other <- renderText(paste0("other=", input$other_txt))
  output$o_params <- renderText({
    q <- get_query_param()
    paste0("x=", q$x, " y=", q$y)
  })
  observeEvent(input$go_other, change_page("other"))
}

shinyApp(ui, server)
