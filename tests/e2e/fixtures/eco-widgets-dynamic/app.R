library(hotShiny)
library(DT)
library(dygraphs)
library(reactable)

# No widget is in the static UI: every htmlwidget dependency reaches the
# browser with a renderUI / insertUI message.
ui <- fluidPage(
  h2("widgets in dynamic UI"),
  actionButton("show", "Show widgets"),
  uiOutput("dyn"),
  actionButton("insert", "Insert reactable"),
  div(id = "anchor"),
  textOutput("dt_selected")
)

server <- function(input, output, session) {
  output$dyn <- renderUI({
    req(input$show)
    tagList(
      DTOutput("dt"),
      dygraphOutput("dy", height = "200px")
    )
  })
  output$dt <- renderDT(datatable(mtcars[1:12, 1:3], options = list(pageLength = 5)), server = TRUE)
  output$dy <- renderDygraph(dygraph(ldeaths))
  output$dt_selected <- renderText(paste("dt selected:", paste(input$dt_rows_selected, collapse = ",")))

  observeEvent(input$insert, {
    id <- paste0("rt", input$insert)
    insertUI("#anchor", "beforeEnd", div(class = "inserted", reactableOutput(id)))
    output[[id]] <- renderReactable(reactable(head(iris, 3)))
  })
}

shinyApp(ui, server)
