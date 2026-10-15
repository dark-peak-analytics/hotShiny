library(hotShiny)
library(shinydashboard)
library(shinydashboardPlus)

ui <- dashboardPage(
  title = "shinydashboardPlus fixture",
  header = dashboardHeader(title = "Plus fixture"),
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
          box(id = "mybox", title = "Managed box", status = "primary", solidHeader = TRUE,
              collapsible = TRUE, closable = TRUE, width = 6,
              label = boxLabel("new", status = "warning"),
              p(id = "mybox_body", "Managed box body")),
          column(6, uiOutput("dyn_box"))
        ),
        fluidRow(
          column(12,
            actionButton("inc", "Increment"),
            actionButton("toggle_box", "Toggle box"),
            actionButton("restore_box", "Restore box"),
            actionButton("retitle", "Retitle box"),
            actionButton("goto_other", "Go to other"),
            actionButton("toggle_cb", "Toggle controlbar")
          )
        ),
        verbatimTextOutput("state")
      ),
      tabItem("other", h2("Other tab"), p("Other content"))
    )
  ),
  controlbar = dashboardControlbar(id = "controlbar", collapsed = TRUE,
    controlbarMenu(id = "cbmenu",
      controlbarItem("Settings", p("Controlbar settings"))
    )
  ),
  footer = dashboardFooter(left = "Left footer", right = "Right footer")
)

server <- function(input, output, session) {
  n <- reactiveVal(0)
  observeEvent(input$inc, n(n() + 1))
  observeEvent(input$toggle_box, updateBox("mybox", action = "toggle"))
  observeEvent(input$restore_box, updateBox("mybox", action = "restore"))
  observeEvent(input$retitle, updateBox("mybox", action = "update",
                                        options = list(title = h2("Renamed box"))))
  observeEvent(input$goto_other, updateTabItems(session, "tabs", "other"))
  observeEvent(input$toggle_cb, updateControlbar("controlbar"))

  output$dyn_box <- renderUI(
    userBox(
      title = userDescription(title = paste("User", n()), subtitle = "dynamic",
                              type = 2, image = NULL),
      status = if (n() > 1) "danger" else "success", width = 12,
      p(id = "dyn_body", paste("rendered for", n()))
    )
  )
  output$state <- renderText(paste0(
    "tab=", input$tabs,
    " collapsed=", isTRUE(input$mybox$collapsed),
    " visible=", isTRUE(input$mybox$visible),
    " cb=", input$controlbar
  ))
}

shinyApp(ui, server)
