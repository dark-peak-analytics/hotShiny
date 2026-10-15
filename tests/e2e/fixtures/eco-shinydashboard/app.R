library(hotShiny)
library(shinydashboard)

ui <- dashboardPage(
  dashboardHeader(title = "Dashboard fixture", dropdownMenuOutput("messages")),
  dashboardSidebar(
    sidebarMenu(id = "tabs",
      menuItem("Overview", tabName = "overview", icon = icon("gauge")),
      menuItem("Details", tabName = "details", icon = icon("table"),
               badgeLabel = "new", badgeColor = "green")
    ),
    sidebarMenuOutput("dyn_menu")
  ),
  dashboardBody(
    tabItems(
      tabItem("overview",
        fluidRow(
          valueBoxOutput("count_box"),
          infoBoxOutput("info_box"),
          valueBox(42, "Static box", icon = icon("star"), color = "purple")
        ),
        fluidRow(
          box(id = "main_box", title = "Controls", status = "primary", solidHeader = TRUE,
              collapsible = TRUE, width = 6,
              actionButton("inc", "Increment"),
              actionButton("goto_details", "Go to details"),
              actionButton("add_item", "Add menu item"),
              p(id = "box_body", "Box body text")),
          box(title = "State", width = 6, verbatimTextOutput("state"))
        )
      ),
      tabItem("details", h2("Details tab"), textOutput("details_txt")),
      tabItem("extra", h2("Extra tab"), p("Reached the dynamic tab"))
    )
  )
)

server <- function(input, output, session) {
  n <- reactiveVal(0)
  extra <- reactiveVal(FALSE)
  observeEvent(input$inc, n(n() + 1))
  observeEvent(input$goto_details, updateTabItems(session, "tabs", "details"))
  observeEvent(input$add_item, extra(TRUE))

  output$count_box <- renderValueBox(
    valueBox(n(), "Clicks", icon = icon("hand-pointer"), color = if (n() > 2) "red" else "aqua")
  )
  output$info_box <- renderInfoBox(
    infoBox("Doubled", n() * 2, icon = icon("calculator"), fill = TRUE)
  )
  output$messages <- renderMenu(
    dropdownMenu(type = "messages", badgeStatus = "success",
                 messageItem("Support", paste("You clicked", n(), "times")))
  )
  output$dyn_menu <- renderMenu({
    items <- list(menuItem("Dynamic", tabName = "dynamic_home", icon = icon("bolt")))
    if (extra()) items <- c(items, list(menuItem("Extra", tabName = "extra", icon = icon("plus"))))
    sidebarMenu(.list = items)
  })
  output$details_txt <- renderText(paste("details for", n()))
  output$state <- renderText(paste0("tab=", input$tabs, " collapsed=", input$sidebarCollapsed))
}

shinyApp(ui, server)
