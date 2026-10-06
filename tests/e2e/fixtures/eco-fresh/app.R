library(hotShiny)
library(fresh)

theme <- create_theme(
  theme = "default",
  bs_vars_global(body_bg = "#fdf6e3", text_color = "#073642"),
  bs_vars_color(brand_primary = "#d33682", brand_success = "#859900"),
  bs_vars_navbar(default_bg = "#268bd2", default_color = "#ffffff",
                 default_link_color = "#ffffff", default_link_active_color = "#002b36"),
  bs_vars_wells(bg = "#eee8d5")
)

ui <- fluidPage(
  use_theme(theme),
  navbarPage("fresh fixture", id = "nav",
    tabPanel("One",
      wellPanel(
        actionButton("go", "Go", class = "btn-primary"),
        actionButton("add", "Add button")
      ),
      uiOutput("dyn"),
      textOutput("txt")
    ),
    tabPanel("Two", value = "two", p(class = "text-success", "Two content"))
  )
)

server <- function(input, output, session) {
  output$dyn <- renderUI({
    if (input$add > 0) actionButton("dyn_btn", paste("Dynamic", input$add), class = "btn-success")
  })
  output$txt <- renderText(paste0("go=", input$go, " tab=", input$nav))
}

shinyApp(ui, server)
