library(hotShiny)
library(visNetwork)

nodes <- data.frame(id = 1:4, label = c("alpha", "beta", "gamma", "delta"))
edges <- data.frame(from = c(1, 1, 2), to = c(2, 3, 4))

ui <- fluidPage(
  h2("visNetwork"),
  visNetworkOutput("net", height = "400px"),
  textOutput("selected"),
  actionButton("add_node", "Add node"),
  actionButton("select_beta", "Select beta")
)

server <- function(input, output, session) {
  output$net <- renderVisNetwork({
    visNetwork(nodes, edges) |>
      visOptions(nodesIdSelection = TRUE) |>
      visPhysics(enabled = FALSE) |>
      visLayout(randomSeed = 1)
  })
  output$selected <- renderText(paste("selected:", input$net_selected))
  observeEvent(input$add_node, {
    visNetworkProxy("net") |>
      visUpdateNodes(data.frame(id = 5, label = "epsilon")) |>
      visUpdateEdges(data.frame(from = 4, to = 5))
  })
  observeEvent(input$select_beta, {
    visNetworkProxy("net") |> visSelectNodes(id = 2)
  })
}

shinyApp(ui, server)
