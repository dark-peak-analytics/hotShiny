#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  step <- golem::get_golem_options("n")
  a <- mod_counter_server("counter_1", step = 1)
  b <- mod_counter_server("counter_2", step = step)
  output$server_opts <- renderText(paste0(
    "server sees title=", golem::get_golem_options("title"),
    " n=", step,
    " all=", paste(sort(names(golem::get_golem_options())), collapse = ",")
  ))
  output$total <- renderText(paste0("total=", a() + b()))
  observeEvent(input$hide, golem::invoke_js("hide", "#target"))
  observeEvent(input$show, golem::invoke_js("show", "#target"))
}
