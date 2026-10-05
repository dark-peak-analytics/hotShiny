library(hotShiny)
library(bslib)

ui <- page_sidebar(
  title = "bslib fixture",
  theme = bs_theme(version = 5, primary = "#7b2cbf"),
  sidebar = sidebar(
    sliderInput("bins", "Bins", 5, 50, 20),
    input_switch("dark", "Dark mode"),
    input_task_button("task", "Run task")
  ),
  layout_columns(
    value_box(title = "Bins", value = textOutput("bins_txt"), showcase = icon("chart-bar")),
    card(card_header("Histogram"), plotOutput("hist", height = "250px")),
    card(card_header("Task"), textOutput("task_result"))
  ),
  navset_card_tab(id = "cards",
    nav_panel("First", "First panel"),
    nav_panel("Second", "Second panel")
  )
)

server <- function(input, output, session) {
  output$bins_txt <- renderText(input$bins)
  output$hist <- renderPlot(hist(faithful$waiting, breaks = input$bins, main = NULL))
  observeEvent(input$dark, {
    session$setCurrentTheme(bs_theme(version = 5, primary = "#7b2cbf",
                                     bg = if (isTRUE(input$dark)) "#111111" else "#ffffff",
                                     fg = if (isTRUE(input$dark)) "#eeeeee" else "#000000"))
  }, ignoreInit = TRUE)
  task <- ExtendedTask$new(function(x) promises::promise_resolve(x * 2))
  bind_task_button(task, "task")
  observeEvent(input$task, task$invoke(input$bins))
  output$task_result <- renderText(paste0("task=", task$result()))
}

shinyApp(ui, server)
