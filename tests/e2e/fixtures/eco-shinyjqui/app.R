library(hotShiny)
library(shinyjqui)

ui <- fluidPage(
  h2("shinyjqui"),
  fluidRow(
    column(6,
      jqui_sortable(tags$ul(
        id = "lst",
        tags$li(id = "i_a", "A", style = "padding:8px;border:1px solid #ccc;"),
        tags$li(id = "i_b", "B", style = "padding:8px;border:1px solid #ccc;"),
        tags$li(id = "i_c", "C", style = "padding:8px;border:1px solid #ccc;")
      )),
      textOutput("o_order")
    ),
    column(6,
      jqui_resizable(div(id = "box", style = "width:200px;height:100px;background:#def;", "resize me")),
      textOutput("o_size"),
      actionButton("add", "Add resizable"),
      div(id = "slot"),
      textOutput("o_size2")
    )
  )
)

server <- function(input, output, session) {
  output$o_order <- renderText({
    o <- input$lst_order
    paste0("order=", paste(if (is.data.frame(o)) o$id else unlist(o), collapse = ","))
  })
  output$o_size <- renderText({
    s <- input$box_size
    if (is.null(s)) "size=NULL" else paste0("size=", round(s$width), "x", round(s$height))
  })
  observeEvent(input$add, {
    insertUI("#slot", ui = div(id = "box2", style = "width:100px;height:50px;background:#fed;", "new"))
    jqui_resizable(ui = "#box2")
  })
  output$o_size2 <- renderText({
    s <- input$box2_size
    if (is.null(s)) "size2=NULL" else paste0("size2=", round(s$width), "x", round(s$height))
  })
}

shinyApp(ui, server)
