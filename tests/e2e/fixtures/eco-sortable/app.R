library(hotShiny)
library(sortable)

ui <- fluidPage(
  h2("sortable"),
  fluidRow(
    column(6,
      rank_list(text = "Rank these", labels = c("apple", "banana", "cherry"), input_id = "rank"),
      textOutput("o_rank")
    ),
    column(6,
      bucket_list(
        header = "Buckets", group_name = "grp", orientation = "horizontal",
        add_rank_list(text = "Left", labels = c("one", "two", "three"), input_id = "left"),
        add_rank_list(text = "Right", labels = character(0), input_id = "right")
      ),
      textOutput("o_left"),
      textOutput("o_right"),
      textOutput("o_grp")
    )
  )
)

server <- function(input, output, session) {
  output$o_rank <- renderText(paste0("rank=", paste(input$rank, collapse = ",")))
  output$o_left <- renderText(paste0("left=", paste(input$left, collapse = ",")))
  output$o_right <- renderText(paste0("right=", paste(input$right, collapse = ",")))
  output$o_grp <- renderText({
    g <- input$grp
    paste0("grp=", paste(names(g), vapply(g, function(x) paste(x, collapse = "+"), ""),
                         sep = ":", collapse = ";"))
  })
}

shinyApp(ui, server)
