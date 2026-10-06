library(hotShiny)
library(bslib)
library(thematic)

thematic_shiny()

light <- bs_theme(version = 5, bg = "#ffffff", fg = "#222222", primary = "#e36209")
dark <- bs_theme(version = 5, bg = "#1d1f21", fg = "#c5c8c6", primary = "#e36209")

ui <- page_fluid(
  theme = dark,
  h2("thematic fixture"),
  input_switch("light", "Light theme"),
  # Not a slider: ion.rangeSlider label offsets vary between page loads.
  numericInput("n", "Points", 50, min = 10, max = 200),
  plotOutput("plot", width = "400px", height = "300px"),
  # Asks shiny.js to report this output's computed colours, as plots do.
  tagAppendAttributes(textOutput("info"), class = "shiny-report-theme")
)

server <- function(input, output, session) {
  observeEvent(input$light, {
    session$setCurrentTheme(if (isTRUE(input$light)) light else dark)
  }, ignoreInit = TRUE)
  output$plot <- renderPlot({
    set.seed(1)
    plot(rnorm(input$n), main = paste("n =", input$n), pch = 19)
  })
  output$info <- renderText({
    info <- getCurrentOutputInfo()
    paste0("n=", input$n, " bg=", info$bg(), " fg=", info$fg())
  })
}

shinyApp(ui, server)
