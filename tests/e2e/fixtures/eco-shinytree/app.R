library(hotShiny)
library(shinyTree)

ui <- fluidPage(
  h2("shinyTree"),
  shinyTree("tree", checkbox = TRUE),
  textOutput("o_selected"),
  actionButton("more", "Replace tree")
)

server <- function(input, output, session) {
  big <- reactiveVal(FALSE)
  observeEvent(input$more, big(TRUE))
  output$tree <- renderTree({
    if (big()) {
      list(Root = structure(list(One = "", Two = "", Three = ""), stopened = TRUE))
    } else {
      list(
        Fruits = structure(list(Apple = "", Banana = ""), stopened = TRUE),
        Vegetables = list(Carrot = "")
      )
    }
  })
  output$o_selected <- renderText({
    sel <- get_selected(input$tree)
    paste0("selected=", paste(unlist(sel), collapse = ","))
  })
}

shinyApp(ui, server)
