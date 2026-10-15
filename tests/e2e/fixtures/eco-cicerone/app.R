library(hotShiny)
library(cicerone)

guide <- Cicerone$new(id = "guide", next_btn_text = "Next one", done_btn_text = "All done")$
  step("tour", "Start", "This starts the guide")$
  step("name", "Name", "Enter a name")$
  step("other", "Last", "Below the tabs")

ui <- fluidPage(
  use_cicerone(),
  h2("cicerone"),
  actionButton("tour", "Start guide"),
  tabsetPanel(id = "tabs",
    tabPanel("A", textInput("name", "Name")),
    tabPanel("B", div(id = "b_content", "Content on B"))
  ),
  div(id = "other", "Below the tabs"),
  textOutput("current_tab"),
  textOutput("next_el")
)

server <- function(input, output, session) {
  observeEvent(input$tour, {
    guide$init()$start()
  })
  # cicerone 1.0.4's own tab_id/tab support throws in the browser ("step is
  # not defined") under plain shiny too, so the tab is switched from R.
  observeEvent(input$guide_cicerone_next, {
    if (identical(input$guide_cicerone_next$highlighted, "name")) updateTabsetPanel(session, "tabs", "B")
  })
  output$current_tab <- renderText(paste("tab", input$tabs))
  output$next_el <- renderText({
    req(input$guide_cicerone_next)
    paste("left", input$guide_cicerone_next$highlighted,
          "has_next", input$guide_cicerone_next$has_next)
  })
}

shinyApp(ui, server)
