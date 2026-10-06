library(hotShiny)
library(jsTreeR)

nodes <- list(
  list(text = "Fruits", state = list(opened = TRUE), children = list(
    list(text = "Apple"), list(text = "Banana")
  )),
  list(text = "Vegetables", children = list(
    list(text = "Carrot"), list(text = "Leek")
  ))
)

ui <- fluidPage(
  h2("jsTreeR"),
  jstreeOutput("tree"),
  textOutput("o_selected"),
  textOutput("o_checked")
)

server <- function(input, output, session) {
  output$tree <- renderJstree(jstree(nodes, checkboxes = TRUE, selectLeavesOnly = FALSE))
  output$o_selected <- renderText(paste0("selected=", paste(vapply(input$tree_selected, `[[`, "", "text"), collapse = ",")))
  output$o_checked <- renderText(paste0("checked=", paste(vapply(input$tree_checked, `[[`, "", "text"), collapse = ",")))
}

shinyApp(ui, server)
