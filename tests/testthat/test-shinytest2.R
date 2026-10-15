# shinytest2's AppDriver launches the app with plain shiny::runApp(app_dir) in
# a child process. A hotShiny app.R hands itself over to hotShiny from there
# (see handoff_on_start()), so AppDriver drives hotShiny apps unchanged. Each
# scenario runs against the hotShiny fixture and against its plain-shiny
# publication; both must produce the same values, snapshot JSON and downloads.

skip_if_no_shinytest2 <- function() {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if_not_installed("chromote")
  skip_if(is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)), "Chrome not found")
}

st2_fixture <- function() {
  dir <- test_path("..", "e2e", "fixtures", "eco-shinytest2")
  skip_if_not(dir.exists(dir), "e2e fixtures not available")
  normalizePath(dir)
}

# A private copy of the fixture, as written (hotShiny) or published to shiny.
st2_app_dir <- function(runtime) {
  src <- st2_fixture()
  root <- tempfile("st2-")
  dir.create(root)
  if (identical(runtime, "hotshiny")) {
    file.copy(src, root, recursive = TRUE)
    file.path(root, basename(src))
  } else {
    out <- file.path(root, basename(src))
    publish_to_shiny(src, out, quiet = TRUE)
    out
  }
}

st2_driver <- function(runtime) {
  shinytest2::AppDriver$new(
    st2_app_dir(runtime),
    name = paste0("st2-", runtime),
    load_timeout = 30000,
    timeout = 10000,
    seed = 1
  )
}

snapshot_json <- function(app) {
  url <- app$get_js("Shiny.shinyapp.getTestSnapshotBaseUrl()")
  paste(readLines(paste0(url, "&input=1&output=1&export=1&format=json&sortC=1"), warn = FALSE),
        collapse = "\n")
}

run_scenario <- function(runtime) {
  app <- st2_driver(runtime)
  on.exit(app$stop(), add = TRUE)
  res <- list()
  res$initial <- app$get_values()

  app$set_inputs(name = "tester", n = 3, letter = "b")
  app$click("go")
  app$click("go")
  app$click("counter-inc")
  res$greeting <- app$get_value(output = "greeting")
  res$exports <- app$get_values(export = TRUE)
  res$after_inputs <- app$get_values()

  app$set_inputs(shout = TRUE, n = 7)
  res$error_state <- app$get_values(output = c("failing", "greeting", "rounded", "secret"))
  app$set_inputs(n = 3)

  csv <- file.path(tempfile("csv-"), "data.csv")
  dir.create(dirname(csv))
  utils::write.csv(data.frame(x = 1:3, y = c("a", "b", "c")), csv, row.names = FALSE)
  app$upload_file(upload = csv)
  res$after_upload <- app$get_values()

  dl <- app$get_download("dl")
  res$download_name <- basename(dl)
  res$download <- readLines(dl)

  res$json <- snapshot_json(app)
  res
}

test_that("AppDriver drives a hotShiny app: inputs, clicks, exports, upload, download", {
  skip_if_no_shinytest2()
  res <- run_scenario("hotshiny")

  # snapshotPreprocessInput("name", toupper) applies to snapshots only.
  expect_equal(res$initial$input$name, "WORLD")
  expect_equal(res$initial$output$greeting, "Hello world x2 (a)")
  expect_equal(res$initial$export$clicks, 0)

  expect_equal(res$greeting, "Hello tester x3 (b)")
  expect_equal(res$exports$export$clicks, 2)
  expect_equal(res$exports$export$name_upper, "TESTER")
  expect_equal(res$exports$export[["counter-count"]], 1)
  expect_equal(res$after_inputs$output$`counter-count`, "count=1")
  expect_equal(as.character(res$after_inputs$output$html_out$html), "<em id=\"em\">clicked 2 times</em>")
  # snapshotPreprocessInput / snapshotPreprocessOutput / snapshotExclude
  expect_equal(res$after_inputs$input$name, "TESTER")
  expect_equal(res$after_inputs$output$rounded, "pi=9.42")
  expect_false("secret" %in% names(res$after_inputs$output))
  expect_equal(names(res$after_inputs$input), sort(names(res$after_inputs$input), method = "radix"))

  expect_equal(res$error_state$output$failing$message, "n is too large")
  expect_equal(res$error_state$output$greeting, "HELLO TESTER X7 (B)")

  # Snapshots show the upload's file name, not its temp path (as in shiny).
  expect_equal(res$after_upload$input$upload$name, "data.csv")
  expect_equal(res$after_upload$input$upload$datapath, "0.csv")
  expect_equal(res$after_upload$export$rows, 3)
  expect_match(res$after_upload$output$contents, "<td> c </td>", fixed = TRUE)

  expect_equal(res$download_name, "report-tester.txt")
  expect_equal(res$download, c("name: tester", "n: 3"))
})

test_that("AppDriver sees the same values, snapshot JSON and downloads on shiny and hotShiny", {
  skip_if_no_shinytest2()
  hot <- run_scenario("hotshiny")
  ref <- run_scenario("shiny")
  for (step in names(ref)) {
    expect_identical(hot[[step]], ref[[step]], label = paste0("hotShiny ", step),
                     expected.label = paste0("shiny ", step))
  }
})

test_that("getTestSnapshotUrl() builds shiny's URL", {
  skip_if_no_shinytest2()
  app <- st2_driver("hotshiny")
  on.exit(app$stop(), add = TRUE)
  url <- app$get_js("Shiny.shinyapp.getTestSnapshotBaseUrl({fullUrl: false})")
  expect_match(url, "^/session/[0-9a-f]+/dataobj/shinytest\\?w=&nonce=")
  base <- sub("^/", "", sub("&nonce=.*$", "", url))
  status <- function(query) curl::curl_fetch_memory(paste0(app$get_url(), base, query))$status_code
  expect_equal(status("&input=1&format=json"), 200)
  expect_equal(status("&input=1&format=rds"), 200)
  # Bad requests answer as shiny does.
  expect_equal(status("&format=json"), 400)
  expect_equal(status("&input=1&format=xml"), 400)
})
