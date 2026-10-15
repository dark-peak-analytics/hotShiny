library(hotShiny)
library(DT)

cars <- mtcars[1:15, 1:5]

tableModUI <- function(id) {
  ns <- NS(id)
  tagList(
    DTOutput(ns("tbl")),
    textOutput(ns("rows_all")),
    textOutput(ns("selected")),
    actionButton(ns("select_first"), "Select first row (module)")
  )
}

tableModServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$tbl <- renderDT(
      datatable(data.frame(make = sub(" .*", "", rownames(cars)), cars[, 1:2]), filter = "top", selection = "single", options = list(pageLength = 20)),
      server = TRUE
    )
    output$rows_all <- renderText(paste("module rows:", length(input$tbl_rows_all)))
    output$selected <- renderText(paste("module selected:", paste(input$tbl_rows_selected, collapse = ",")))
    proxy <- dataTableProxy("tbl")
    observeEvent(input$select_first, selectRows(proxy, 1))
  })
}

ui <- fluidPage(
  h2("DT"),
  h4("client-side"),
  DTOutput("client"),
  textOutput("client_selected"),
  h4("server-side"),
  DTOutput("server"),
  textOutput("server_selected"),
  textOutput("server_search"),
  actionButton("select_rows", "Select rows 2 and 4"),
  actionButton("replace", "Replace data"),
  h4("editable"),
  DTOutput("edit"),
  textOutput("edit_info"),
  verbatimTextOutput("edit_data"),
  h4("module"),
  tableModUI("mod")
)

server <- function(input, output, session) {
  output$client <- renderDT(
    datatable(cars, selection = "multiple", options = list(pageLength = 5)),
    server = FALSE
  )
  output$client_selected <- renderText(
    paste("client selected:", paste(input$client_rows_selected, collapse = ","))
  )

  server_data <- reactiveVal(cars)
  output$server <- renderDT(
    datatable(isolate(server_data()), options = list(pageLength = 5)),
    server = TRUE
  )
  output$server_selected <- renderText(
    paste("server selected:", paste(input$server_rows_selected, collapse = ","))
  )
  output$server_search <- renderText(
    paste("server search:", input$server_search)
  )
  proxy <- dataTableProxy("server")
  observeEvent(input$select_rows, selectRows(proxy, c(2, 4)))
  observeEvent(input$replace, {
    d <- server_data()
    d$mpg <- d$mpg * 10
    server_data(d)
    replaceData(proxy, d, resetPaging = FALSE)
  })

  edited <- reactiveVal(head(cars, 4))
  output$edit <- renderDT(
    datatable(isolate(edited()), editable = "cell", options = list(dom = "t")),
    server = TRUE
  )
  edit_proxy <- dataTableProxy("edit")
  output$edit_info <- renderText({
    info <- input$edit_cell_edit
    req(info)
    sprintf("edited row %s col %s -> %s", info$row, info$col, info$value)
  })
  observeEvent(input$edit_cell_edit, {
    edited(editData(edited(), input$edit_cell_edit, edit_proxy))
  })
  output$edit_data <- renderPrint(edited()[, 1:3])

  tableModServer("mod")
}

shinyApp(ui, server)
