# Reactive engine semantics, exercised at the console (no session).

test_that("reactiveVal reads, writes and invalidates dependents", {
  rv <- reactiveVal(1)
  runs <- 0
  r <- reactive({
    runs <<- runs + 1
    rv() * 2
  })
  expect_equal(isolate(r()), 2)
  expect_equal(isolate(r()), 2)
  expect_equal(runs, 1) # cached
  rv(5)
  expect_equal(isolate(r()), 10)
  expect_equal(runs, 2)
  rv(5) # identical value: no invalidation
  expect_equal(isolate(r()), 10)
  expect_equal(runs, 2)
})

test_that("observers run on flush, in priority order, and re-run on change", {
  rv <- reactiveVal(0)
  log <- character(0)
  o1 <- observe({ rv(); log <<- c(log, "low") }, priority = 0)
  o2 <- observe({ rv(); log <<- c(log, "high") }, priority = 10)
  flush_react()
  expect_equal(log, c("high", "low"))
  rv(1)
  flush_react()
  expect_equal(log, c("high", "low", "high", "low"))
  o1$destroy(); o2$destroy()
  rv(2)
  flush_react()
  expect_length(log, 4)
})

test_that("isolate() hides dependencies", {
  a <- reactiveVal(1)
  b <- reactiveVal(1)
  runs <- 0
  o <- observe({
    a()
    isolate(b())
    runs <<- runs + 1
  })
  flush_react()
  b(2); flush_react()
  expect_equal(runs, 1)
  a(2); flush_react()
  expect_equal(runs, 2)
  o$destroy()
})

test_that("reactive errors are cached and re-signalled; req() is silent", {
  rv <- reactiveVal(-1)
  runs <- 0
  r <- reactive({
    runs <<- runs + 1
    if (rv() < 0) stop("negative")
    rv()
  })
  expect_error(isolate(r()), "negative")
  expect_error(isolate(r()), "negative")
  expect_equal(runs, 1)
  q <- reactive({ req(FALSE); 1 })
  expect_error(isolate(q()), class = "shiny.silent.error")
})

test_that("observeEvent honours ignoreNULL, ignoreInit and once", {
  ev <- reactiveVal(NULL)
  hits <- 0
  o <- observeEvent(ev(), hits <<- hits + 1)
  flush_react()
  expect_equal(hits, 0) # NULL ignored
  ev(1); flush_react()
  expect_equal(hits, 1)
  ev(2); flush_react()
  expect_equal(hits, 2)

  ev2 <- reactiveVal(1)
  init_hits <- 0
  observeEvent(ev2(), init_hits <<- init_hits + 1, ignoreInit = TRUE)
  flush_react()
  expect_equal(init_hits, 0)
  ev2(2); flush_react()
  expect_equal(init_hits, 1)

  ev3 <- reactiveVal(1)
  once_hits <- 0
  observeEvent(ev3(), once_hits <<- once_hits + 1, once = TRUE)
  flush_react()
  ev3(2); flush_react()
  expect_equal(once_hits, 1)
  o$destroy()
})

test_that("eventReactive only recomputes on its event", {
  ev <- reactiveVal(1)
  x <- reactiveVal("a")
  er <- eventReactive(ev(), x())
  expect_equal(isolate(er()), "a")
  x("b")
  expect_equal(isolate(er()), "a")
  ev(2)
  expect_equal(isolate(er()), "b")
})

test_that("bindEvent works on reactives and observers", {
  ev <- reactiveVal(1)
  x <- reactiveVal(1)
  r <- bindEvent(reactive(x() * 10), ev())
  expect_equal(isolate(r()), 10)
  x(2)
  expect_equal(isolate(r()), 10)
  ev(2)
  expect_equal(isolate(r()), 20)

  seen <- NULL
  o <- bindEvent(observe(seen <<- x()), ev())
  flush_react()
  expect_equal(seen, 2)
  x(3); flush_react()
  expect_equal(seen, 2)
  ev(3); flush_react()
  expect_equal(seen, 3)
  o$destroy()
})

test_that("reactiveValues track keys, names and lists", {
  rv <- reactiveValues(a = 1)
  expect_s3_class(rv, "reactivevalues")
  expect_true(is.reactivevalues(rv))
  runs <- 0
  o <- observe({ rv$a; runs <<- runs + 1 })
  flush_react()
  rv$b <- 2; flush_react()
  expect_equal(runs, 1) # only `a` was read
  rv$a <- 5; flush_react()
  expect_equal(runs, 2)
  expect_equal(isolate(reactiveValuesToList(rv)), list(a = 5, b = 2))
  expect_setequal(isolate(names(rv)), c("a", "b"))
  expect_error(rv$a, "outside of reactive consumer")
  o$destroy()
})

test_that("objects carry shiny's classes", {
  expect_true(is.reactive(reactive(1)))
  expect_s3_class(reactive(1), "reactiveExpr")
  expect_s3_class(reactiveVal(1), "reactiveVal")
  o <- observe(NULL)
  expect_s3_class(o, "Observer")
  o$destroy()
})

test_that("makeReactiveBinding creates a reactive variable", {
  env <- new.env()
  env$x <- 1
  makeReactiveBinding("x", env)
  seen <- NULL
  o <- observe(seen <<- env$x)
  flush_react()
  expect_equal(seen, 1)
  env$x <- 2
  flush_react()
  expect_equal(seen, 2)
  o$destroy()
})

test_that("labels come from the assigned name and the graph records edges", {
  g <- hotShiny:::app_graph()
  src <- "counter <- reactiveVal(1)\ndoubled <- reactive(counter() * 2)"
  env <- new.env()
  eval(parse(text = src, keep.source = TRUE), env)
  expect_equal(attr(env$counter, "label"), "counter")
  isolate(env$doubled())
  edges <- g$edges()
  expect_true(any(edges$from == "reactiveVal:counter" & edges$to == "reactive:doubled"))
})
