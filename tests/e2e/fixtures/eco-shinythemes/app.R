library(hotShiny)
library(shinythemes)

ui <- navbarPage(
  "shinythemes fixture",
  id = "nav",
  theme = shinytheme("flatly"),
  tabPanel("Inputs",
    sidebarLayout(
      sidebarPanel(
        sliderInput("n", "Points", 10, 100, 40),
        selectInput("col", "Colour", c("steelblue", "tomato")),
        actionButton("go", "Go", class = "btn-primary"),
        checkboxInput("flag", "Flag", TRUE)
      ),
      mainPanel(
        wellPanel(textOutput("summary")),
        tableOutput("tbl")
      )
    )
  ),
  tabPanel("About", value = "about", h3("About tab"), p(class = "text-success", "Themed text")),
  navbarMenu("More",
    tabPanel("Sub A", "Sub A content"),
    tabPanel("Sub B", "Sub B content")
  ),
  header = themeSelector()
)

server <- function(input, output, session) {
  output$summary <- renderText(paste0("n=", input$n, " col=", input$col, " go=", input$go,
                                      " tab=", input$nav))
  output$tbl <- renderTable(head(mtcars[, 1:4], 3), rownames = TRUE)
}

shinyApp(ui, server)
