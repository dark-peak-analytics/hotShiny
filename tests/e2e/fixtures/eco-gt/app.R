library(hotShiny)
library(gt)

cars <- head(mtcars[, c("mpg", "cyl", "hp", "wt")], 12)
cars$model <- rownames(cars)
rownames(cars) <- NULL

ui <- fluidPage(
  h2("gt"),
  sliderInput("rows", "Rows", min = 2, max = 12, value = 5, step = 1),
  selectInput("cyl", "Cylinders", c("all", "4", "6", "8")),
  checkboxInput("highlight", "Highlight heavy cars", FALSE),
  gt_output("table"),
  textOutput("shown"),
  h4("Static gt in renderUI"),
  uiOutput("static_gt")
)

server <- function(input, output, session) {
  data <- reactive({
    d <- cars
    if (input$cyl != "all") d <- d[d$cyl == as.numeric(input$cyl), ]
    head(d, input$rows)
  })

  output$table <- render_gt({
    tbl <- gt(data(), rowname_col = "model") |>
      tab_header(title = "Motor Trend cars", subtitle = paste("cyl:", input$cyl)) |>
      fmt_number(columns = wt, decimals = 2) |>
      cols_label(mpg = "Miles/gallon", hp = "Horsepower") |>
      tab_source_note("Source: mtcars")
    if (isTRUE(input$highlight)) {
      tbl <- tab_style(tbl, style = cell_fill(color = "#ffe4b5"),
                       locations = cells_body(rows = wt > 3))
    }
    tbl
  })

  output$shown <- renderText(paste0("rows shown=", nrow(data())))

  output$static_gt <- renderUI({
    gt(data.frame(a = 1:2, b = c("x", "y"))) |>
      tab_options(table.font.size = px(12)) |>
      as_raw_html()
  })
}

shinyApp(ui, server)
