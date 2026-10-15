library(hotShiny)

ui <- fluidPage(
  title = "Layouts fixture",
  tags$head(tags$style(".marker { color: rgb(200, 0, 0); }")),
  titlePanel("Layouts", windowTitle = "Layouts window"),
  fluidRow(
    column(3, wellPanel(p(class = "marker", "Well panel"), helpText("Help text"))),
    column(3, offset = 1, inputPanel(textInput("a", "A"), textInput("b", "B"))),
    column(5, flowLayout(actionButton("f1", "Flow 1", icon = icon("star")), actionButton("f2", "Flow 2")))
  ),
  splitLayout(cellWidths = c("30%", "70%"), p("Left split"), p("Right split")),
  verticalLayout(p("Vertical 1"), p("Vertical 2")),
  navlistPanel(
    "Header",
    tabPanel("One", p("Navlist one")),
    tabPanel("Two", p("Navlist two")),
    widths = c(3, 9)
  ),
  tabsetPanel(type = "pills",
    tabPanel("Pill A", icon = icon("house"), p("Pill A body")),
    tabPanel("Pill B", p("Pill B body"))
  ),
  absolutePanel(top = 10, right = 10, width = 120, draggable = FALSE, p(id = "abs", "Absolute")),
  tags$footer(code("code"), pre("pre block"), strong("strong"), em("em"), a(href = "#", "link"),
              img(src = "logo.png", alt = "logo", width = 1, height = 1))
)

server <- function(input, output, session) {}

shinyApp(ui, server)
