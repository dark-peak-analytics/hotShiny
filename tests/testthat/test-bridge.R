test_that("the bridge routes shiny's primitives and restores them", {
  orig <- get("reactiveVal", asNamespace("shiny"))
  hotShiny:::install_bridge()
  on.exit(hotShiny:::uninstall_bridge(), add = TRUE)
  expect_identical(get("reactiveVal", asNamespace("shiny")), hotShiny::reactiveVal)
  # shiny's own helpers now build on hotShiny's engine
  rv <- shiny::reactiveVal(1)
  r <- shiny::reactive(rv() + 1)
  expect_equal(hotShiny::isolate(r()), 2)
  expect_true(bridge_active())
  hotShiny:::uninstall_bridge()
  expect_identical(get("reactiveVal", asNamespace("shiny")), orig)
  expect_false(bridge_active())
})

test_that("register_substitute replaces and restores package functions", {
  register_substitute("tools", "toTitleCase", function(text) "SUBSTITUTED")
  on.exit(rm("tools::toTitleCase", envir = hotShiny:::.hs_substitutes), add = TRUE)
  hotShiny:::install_bridge()
  expect_equal(tools::toTitleCase("x"), "SUBSTITUTED")
  hotShiny:::uninstall_bridge()
  expect_equal(tools::toTitleCase("hello world"), "Hello World")
})
