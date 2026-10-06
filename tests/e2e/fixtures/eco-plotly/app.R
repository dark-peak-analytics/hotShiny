library(hotShiny)
library(plotly)

pts <- data.frame(x = 1:5, y = c(2, 4, 3, 5, 1))

ui <- fluidPage(
  h2("plotly"),
  fluidRow(
    column(6,
      plotlyOutput("static", height = "300px"),
      textOutput("click_static"),
      textOutput("hover_static"),
      textOutput("relayout_static"),
      actionButton("add_trace", "Add trace"),
      actionButton("restyle", "Recolour markers")
    ),
    column(6,
      numericInput("n", "Points in dynamic plot", value = 4, min = 2, max = 8),
      uiOutput("dyn_ui"),
      textOutput("click_dyn"),
      textOutput("selected_dyn")
    )
  )
)

server <- function(input, output, session) {
  output$static <- renderPlotly({
    plot_ly(pts, x = ~x, y = ~y, type = "scatter", mode = "markers",
            marker = list(size = 14), source = "A") |>
      layout(xaxis = list(range = c(0, 6)), yaxis = list(range = c(0, 6)),
             showlegend = FALSE)
  })
  output$click_static <- renderText({
    d <- event_data("plotly_click", source = "A")
    if (is.null(d)) "click A: none" else sprintf("click A: x=%s y=%s curve=%s", d$x, d$y, d$curveNumber)
  })
  output$hover_static <- renderText({
    d <- event_data("plotly_hover", source = "A")
    if (is.null(d)) "hover A: none" else sprintf("hover A: x=%s y=%s", d$x, d$y)
  })

  output$relayout_static <- renderText({
    d <- event_data("plotly_relayout", source = "A")
    if (is.null(d[["xaxis.range[0]"]])) "relayout A: none"
    else sprintf("relayout A: x from %.0f to %.0f", d[["xaxis.range[0]"]], d[["xaxis.range[1]"]])
  })

  proxy <- plotlyProxy("static", session)
  observeEvent(input$add_trace, {
    plotlyProxyInvoke(proxy, "addTraces", list(
      x = c(1, 5), y = c(5, 5), type = "scatter", mode = "lines",
      name = paste("added", input$add_trace)
    ))
  })
  observeEvent(input$restyle, {
    plotlyProxyInvoke(proxy, "restyle", list(marker.color = "red"), list(0))
  })

  output$dyn_ui <- renderUI({
    tagList(
      p(id = "dyn_label", paste("dynamic plot with", input$n, "points")),
      plotlyOutput("dyn", height = "250px")
    )
  })
  output$dyn <- renderPlotly({
    n <- input$n
    plot_ly(x = seq_len(n), y = seq_len(n), type = "bar", source = "B") |>
      layout(xaxis = list(range = c(0, n + 1)), yaxis = list(range = c(0, n + 1)),
             dragmode = "select")
  }) |> bindCache(input$n)
  output$click_dyn <- renderText({
    d <- event_data("plotly_click", source = "B")
    if (is.null(d)) "click B: none" else sprintf("click B: x=%s y=%s", d$x, d$y)
  })
  output$selected_dyn <- renderText({
    d <- event_data("plotly_selected", source = "B")
    if (is.null(d)) "selected B: none" else paste("selected B:", paste(d$x, collapse = ","))
  })
}

shinyApp(ui, server)
