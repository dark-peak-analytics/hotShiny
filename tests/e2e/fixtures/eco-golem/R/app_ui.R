#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    fluidPage(
      h1(id = "title", golem::get_golem_options("title")),
      p(id = "ui_opts", paste0("ui sees n=", golem::get_golem_options("n"),
                               " prod=", golem::app_prod())),
      p(id = "config", get_golem_config("greeting")),
      mod_counter_ui("counter_1"),
      mod_counter_ui("counter_2"),
      textOutput("server_opts"),
      textOutput("total"),
      div(id = "target", "I can be hidden by golem's JS handlers"),
      actionButton("hide", "Hide with invoke_js"),
      actionButton("show", "Show with invoke_js")
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  tags$head(
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "ecogolem"
    )
  )
}
