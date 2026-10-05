library(hotShiny)

ui <- navbarPage(
  "Dynamic UI",
  id = "nav",
  tabPanel("Insert",
    actionButton("add", "Add item"),
    actionButton("remove", "Remove item"),
    div(id = "items"),
    textOutput("item_count")
  ),
  tabPanel("Modals",
    actionButton("show_modal", "Show modal"),
    actionButton("notify", "Notify"),
    actionButton("progress", "Run progress"),
    textOutput("modal_value"),
    textOutput("progress_done")
  ),
  tabPanel("Conditional",
    checkboxInput("show_extra", "Show extra", FALSE),
    conditionalPanel("input.show_extra", p(id = "extra", "Extra content")),
    selectInput("pick", "Pick", c("none", "alpha", "beta")),
    conditionalPanel("input.pick == 'beta'", p(id = "beta-only", "Beta selected"))
  ),
  navbarMenu("More",
    tabPanel("Tabs",
      tabsetPanel(id = "inner",
        tabPanel("First", value = "first", p("First tab body")),
        tabPanel("Second", value = "second", p("Second tab body"))
      ),
      actionButton("to_second", "Go to second"),
      actionButton("add_tab", "Append tab"),
      textOutput("inner_value")
    )
  )
)

server <- function(input, output, session) {
  n <- reactiveVal(0)
  observeEvent(input$add, {
    n(n() + 1)
    insertUI("#items", "beforeEnd",
             div(id = paste0("item", n()), class = "inserted-item", paste("Item", n())))
  })
  observeEvent(input$remove, {
    if (n() > 0) {
      removeUI(paste0("#item", n()))
      n(n() - 1)
    }
  })
  output$item_count <- renderText(paste0("items=", n()))

  observeEvent(input$show_modal, {
    showModal(modalDialog(
      title = "A modal",
      textInput("modal_text", "In modal", "typed in modal"),
      footer = tagList(modalButton("Cancel"), actionButton("modal_ok", "OK"))
    ))
  })
  observeEvent(input$modal_ok, removeModal())
  output$modal_value <- renderText(paste0("modal_text=", input$modal_text))

  observeEvent(input$notify, showNotification("Hello notification", id = "note1", duration = NULL, type = "warning"))

  observeEvent(input$progress, {
    withProgress(message = "Working", value = 0, {
      for (i in 1:3) {
        incProgress(1 / 3, detail = paste("step", i))
        Sys.sleep(0.1)
      }
    })
    output$progress_done <- renderText("progress=done")
  })

  observeEvent(input$to_second, updateTabsetPanel(session, "inner", selected = "second"))
  observeEvent(input$add_tab, appendTab("inner", tabPanel("Third", value = "third", p("Third tab body")), select = TRUE))
  output$inner_value <- renderText(paste0("inner=", input$inner))
}

shinyApp(ui, server)
