library(hotShiny)
library(bslib)

ui <- page_sidebar(
  title = "bslib fixture",
  theme = bs_theme(version = 5, primary = "#7b2cbf"),
  sidebar = sidebar(
    id = "sb",
    sliderInput("bins", "Bins", 5, 50, 20),
    input_switch("dark", "Dark mode"),
    input_task_button("task", "Run task"),
    actionButton("close_sb", "Close sidebar"),
    input_dark_mode(id = "mode", mode = "light")
  ),
  layout_columns(
    value_box(title = "Bins", value = textOutput("bins_txt"), showcase = icon("chart-bar")),
    card(card_header("Histogram"), plotOutput("hist", height = "250px")),
    card(card_header("Task"), textOutput("task_result"))
  ),
  navset_card_tab(id = "cards",
    nav_panel("First", "First panel"),
    nav_panel("Second", "Second panel"),
    nav_panel("Third", value = "third", "Third panel")
  ),
  card(
    card_header("Controls"),
    div(
      actionButton("go_second", "Go to second"),
      actionButton("add_tab", "Add tab"),
      actionButton("remove_first", "Remove first"),
      actionButton("open_b", "Open B"),
      actionButton("flip_switch", "Flip switch")
    ),
    verbatimTextOutput("state")
  ),
  accordion(id = "acc", open = "A",
    accordion_panel("A", "Panel A body"),
    accordion_panel("B", "Panel B body")
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
  task <- ExtendedTask$new(function(x) {
    promises::promise(function(resolve, reject) later::later(function() resolve(x * 2), 1))
  })
  bind_task_button(task, "task")
  observeEvent(input$task, task$invoke(input$bins))
  output$task_result <- renderText(paste0("task=", task$result()))

  observeEvent(input$close_sb, toggle_sidebar("sb", open = FALSE))
  observeEvent(input$go_second, nav_select("cards", "Second"))
  observeEvent(input$add_tab, {
    nav_insert("cards", nav_panel("Added", value = "added", "Added panel"), select = TRUE)
  })
  observeEvent(input$remove_first, nav_remove("cards", "First"))
  observeEvent(input$open_b, accordion_panel_open("acc", "B"))
  observeEvent(input$flip_switch, update_switch("dark", value = !isTRUE(input$dark)))

  output$state <- renderText(paste0(
    "sb=", input$sb, " cards=", input$cards,
    " acc=", paste(input$acc, collapse = ","), " dark=", input$dark, " mode=", input$mode
  ))
}

shinyApp(ui, server)
