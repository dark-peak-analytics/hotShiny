library(hotShiny)
library(datamods)

ui <- fluidPage(
  h2("datamods"),
  fluidRow(
    column(6,
      import_file_ui("import", file_extensions = c(".csv", ".txt")),
      verbatimTextOutput("imported")
    ),
    column(6,
      filter_data_ui("filter", show_nrow = TRUE),
      verbatimTextOutput("filtered"),
      verbatimTextOutput("code")
    )
  )
)

server <- function(input, output, session) {
  imported <- import_file_server("import", trigger_return = "button", return_class = "data.frame")

  output$imported <- renderPrint({
    req(imported$data())
    cat(sprintf("name=%s rows=%d cols=%s", imported$name(), nrow(imported$data()),
                paste(names(imported$data()), collapse = ",")))
  })

  res_filter <- filter_data_server(
    "filter",
    data = reactive(imported$data()),
    name = reactive(imported$name()),
    widget_char = "picker",
    widget_num = "range"
  )

  output$filtered <- renderPrint({
    d <- res_filter$filtered()
    req(d)
    cat(sprintf("filtered rows=%d species=%s", nrow(d), paste(sort(unique(d$species)), collapse = ",")))
  })
  output$code <- renderPrint({
    req(res_filter$expr())
    print(res_filter$expr())
  })
}

shinyApp(ui, server)
