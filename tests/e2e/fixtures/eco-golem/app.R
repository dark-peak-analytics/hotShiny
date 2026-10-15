library(hotShiny)
# Launch the ShinyApp (Do not remove this comment)
# To deploy, run: rsconnect::deployApp()
# Or use the blue button on top of this file
# Note that you'll need to upload the whole package to RStudio Connect
# (This file is what golem::add_rstudioconnect_file() generates.)

pkgload::load_all(export_all = FALSE,helpers = FALSE,attach_testthat = FALSE)
options( "golem.app.prod" = TRUE)
ecogolem::run_app(title = "Golem on hotShiny", n = 5) # add parameters here (if any)
