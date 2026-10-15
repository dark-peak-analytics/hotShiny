library(hotShiny)
library(bslib)

ui <- page_navbar(
  title = "bslib navbar fixture",
  id = "nav",
  theme = bs_theme(version = 5, preset = "shiny"),
  sidebar = sidebar(
    id = "sb",
    selectInput("dataset", "Dataset", c("mtcars", "iris")),
    actionButton("to_table", "Show table"),
    actionButton("hide_plot", "Hide plot tab"),
    actionButton("show_plot", "Show plot tab")
  ),
  nav_panel("Summary", value = "summary",
    layout_column_wrap(width = 1 / 3,
      value_box("Rows", textOutput("rows"), theme = "primary"),
      value_box("Cols", textOutput("cols"), theme = "secondary"),
      card(card_header("Dataset"), textOutput("name"))
    )
  ),
  nav_panel("Plot", value = "plot",
    card(full_screen = TRUE, card_header("Histogram"), plotOutput("hist", height = "250px"))
  ),
  nav_menu("More",
    nav_panel("Table", value = "table", tableOutput("tbl")),
    nav_panel("Notes", value = "notes", p("Some notes"))
  ),
  nav_spacer(),
  nav_item(tags$span(id = "nav_state", textOutput("state", inline = TRUE)))
)

server <- function(input, output, session) {
  data <- reactive(get(input$dataset, "package:datasets"))
  output$rows <- renderText(nrow(data()))
  output$cols <- renderText(ncol(data()))
  output$name <- renderText(input$dataset)
  output$hist <- renderPlot(hist(data()[[1]], main = input$dataset))
  output$tbl <- renderTable(head(data(), 3))
  observeEvent(input$to_table, nav_select("nav", "table"))
  observeEvent(input$hide_plot, nav_hide("nav", "plot"))
  observeEvent(input$show_plot, nav_show("nav", "plot"))
  output$state <- renderText(paste0("nav=", input$nav, " sb=", input$sb))
}

shinyApp(ui, server)
