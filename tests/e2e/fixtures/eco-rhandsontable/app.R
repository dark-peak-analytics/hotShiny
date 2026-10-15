library(hotShiny)
library(rhandsontable)

df <- data.frame(name = c("a", "b", "c"), value = c(1, 2, 3), flag = c(TRUE, FALSE, TRUE),
                 stringsAsFactors = FALSE)

ui <- fluidPage(
  h2("rhandsontable"),
  rHandsontableOutput("hot"),
  textOutput("o_sum"),
  textOutput("o_names"),
  textOutput("o_flags"),
  textOutput("o_select"),
  actionButton("reset", "Reset")
)

server <- function(input, output, session) {
  data <- reactiveVal(df)
  observeEvent(input$reset, data(transform(df, value = value * 10)))
  output$hot <- renderRHandsontable({
    rhandsontable(data(), selectCallback = TRUE, rowHeaders = NULL)
  })
  edited <- reactive({
    if (is.null(input$hot)) data() else hot_to_r(input$hot)
  })
  output$o_sum <- renderText(paste0("sum=", sum(edited()$value), " class=", class(edited()$value)))
  output$o_names <- renderText(paste0("names=", paste(edited()$name, collapse = ",")))
  output$o_flags <- renderText(paste0("flags=", paste(edited()$flag, collapse = ",")))
  output$o_select <- renderText({
    s <- input$hot_select
    if (is.null(s)) "select=NULL" else paste0("select=r", s$select$r, "c", s$select$c)
  })
}

shinyApp(ui, server)
