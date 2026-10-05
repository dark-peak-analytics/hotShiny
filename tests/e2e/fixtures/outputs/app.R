library(hotShiny)

ui <- fluidPage(
  h2("Outputs"),
  fluidRow(
    column(4,
      numericInput("n", "Rows", value = 3, min = 1, max = 10),
      textInput("need", "Type something (validate)", value = ""),
      checkboxInput("fail", "Make plot error", value = FALSE),
      downloadButton("dl", "Download CSV"),
      downloadLink("dl_txt", "Download text"),
      fileInput("upload", "Upload a CSV", accept = ".csv"),
      tableOutput("uploaded")
    ),
    column(8,
      h4("text"), textOutput("txt"),
      h4("inline text"), p("Rows: ", textOutput("txt_inline", inline = TRUE)),
      h4("print"), verbatimTextOutput("prn"),
      h4("table"), tableOutput("tbl"),
      h4("validate"), textOutput("validated"),
      h4("req"), textOutput("required"),
      h4("ui"), uiOutput("dyn"),
      h4("html"), htmlOutput("html"),
      h4("plot"), plotOutput("plt", width = "400px", height = "300px"),
      h4("image"), imageOutput("img", width = "100px", height = "100px")
    )
  )
)

server <- function(input, output, session) {
  output$txt <- renderText(paste("n is", input$n))
  output$txt_inline <- renderText(input$n)
  output$prn <- renderPrint(summary(head(mtcars$mpg, input$n)))
  output$tbl <- renderTable(head(mtcars[, 1:4], input$n), rownames = TRUE)
  output$validated <- renderText({
    validate(need(nchar(input$need) > 0, "Please type something"))
    paste("You typed", input$need)
  })
  output$required <- renderText({
    req(input$need)
    paste("Required ok:", toupper(input$need))
  })
  output$dyn <- renderUI({
    tagList(
      sliderInput("dyn_slider", "Dynamic slider", min = 1, max = 10, value = input$n),
      textOutput("dyn_value")
    )
  })
  output$dyn_value <- renderText(paste("dynamic:", input$dyn_slider))
  output$html <- renderUI(HTML(sprintf("<strong id='strong-n'>%s</strong>", input$n)))
  output$plt <- renderPlot({
    if (isTRUE(input$fail)) stop("Deliberate plot failure")
    plot(seq_len(input$n), main = paste("n =", input$n))
  })
  output$img <- renderImage({
    f <- tempfile(fileext = ".png")
    grDevices::png(f, width = 100, height = 100)
    graphics::par(mar = c(0, 0, 0, 0))
    graphics::plot.new()
    graphics::rect(0, 0, 1, 1, col = "steelblue")
    grDevices::dev.off()
    list(src = f, contentType = "image/png", width = 100, height = 100, alt = "square")
  }, deleteFile = TRUE)
  output$uploaded <- renderTable({
    req(input$upload)
    utils::read.csv(input$upload$datapath)
  })
  output$dl <- downloadHandler(
    filename = function() "cars.csv",
    content = function(file) utils::write.csv(head(mtcars, input$n), file, row.names = FALSE)
  )
  output$dl_txt <- downloadHandler(
    filename = "hello.txt",
    content = function(file) writeLines(c("hello", "world"), file)
  )
}

shinyApp(ui, server)
