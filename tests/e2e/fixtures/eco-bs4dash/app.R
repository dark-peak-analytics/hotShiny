library(hotShiny)
library(bs4Dash)

ui <- dashboardPage(
  title = "bs4Dash fixture",
  help = NULL,
  dark = FALSE,
  header = dashboardHeader(title = "bs4Dash fixture"),
  sidebar = dashboardSidebar(
    sidebarMenu(id = "tabs",
      menuItem("Home", tabName = "home", icon = icon("house")),
      menuItem("Other", tabName = "other", icon = icon("gear"))
    )
  ),
  body = dashboardBody(
    tabItems(
      tabItem("home",
        fluidRow(
          valueBoxOutput("vbox", width = 4),
          column(8,
            actionButton("inc", "Increment"),
            actionButton("toggle_box", "Toggle box"),
            actionButton("retitle", "Retitle box"),
            actionButton("goto_other", "Go to other")
          )
        ),
        fluidRow(
          box(id = "mybox", title = "Managed box", collapsible = TRUE, width = 6,
              p(id = "mybox_body", "Managed box body")),
          column(6, uiOutput("dyn_box"))
        ),
        tabBox(id = "tabcard", title = "Tab box", width = 12,
          tabPanel("Alpha", "Alpha content"),
          tabPanel("Beta", "Beta content")
        ),
        verbatimTextOutput("state")
      ),
      tabItem("other", h2("Other tab"), p("Other content"))
    )
  )
)

server <- function(input, output, session) {
  n <- reactiveVal(0)
  observeEvent(input$inc, n(n() + 1))
  observeEvent(input$toggle_box, updateBox("mybox", action = "toggle"))
  observeEvent(input$retitle, updateBox("mybox", action = "update",
                                        options = list(title = h2("Renamed box"))))
  observeEvent(input$goto_other, updateTabItems(session, "tabs", "other"))

  output$vbox <- renderValueBox(
    valueBox(n(), "Clicks", icon = icon("hand-pointer"), color = if (n() > 1) "danger" else "info")
  )
  output$dyn_box <- renderUI(
    box(title = paste("Dynamic box", n()), status = "success", solidHeader = TRUE,
        width = 12, p(paste("rendered for", n())))
  )
  output$state <- renderText(paste0(
    "tab=", input$tabs, " card=", input$tabcard,
    " collapsed=", isTRUE(input$mybox$collapsed), " dark=", input$dark_mode
  ))
}

shinyApp(ui, server)
