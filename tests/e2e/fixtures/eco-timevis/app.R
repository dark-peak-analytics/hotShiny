library(hotShiny)
library(timevis)

items <- data.frame(
  id = c("i1", "i2", "i3"),
  content = c("Alpha", "Beta", "Gamma"),
  start = c("2024-01-05", "2024-01-12", "2024-01-20"),
  end = c(NA, "2024-01-15", NA),
  stringsAsFactors = FALSE
)

ui <- fluidPage(
  h2("timevis"),
  timevisOutput("tl"),
  textOutput("o_selected"),
  textOutput("o_data"),
  textOutput("o_window"),
  actionButton("add", "Add item"),
  actionButton("sel", "Select Gamma"),
  actionButton("rm", "Remove Alpha")
)

server <- function(input, output, session) {
  output$tl <- renderTimevis(
    timevis(items, options = list(start = "2024-01-01", end = "2024-01-31", editable = FALSE,
                                showCurrentTime = FALSE))
  )
  output$o_selected <- renderText(paste0("selected=", paste(input$tl_selected, collapse = ",")))
  output$o_data <- renderText({
    d <- input$tl_data
    if (is.null(d)) "data=NULL" else paste0("data=", class(d)[1], ":", paste(sort(d$content), collapse = ","))
  })
  output$o_window <- renderText({
    w <- input$tl_window
    if (is.null(w)) "window=NULL" else paste0("window=", substr(w[1], 1, 10))
  })
  observeEvent(input$add, addItem("tl", list(id = "i4", content = "Delta", start = "2024-01-25")))
  observeEvent(input$sel, setSelection("tl", "i3"))
  observeEvent(input$rm, removeItem("tl", "i1"))
}

shinyApp(ui, server)
