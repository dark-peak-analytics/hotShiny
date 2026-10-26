# hotShiny

A drop-in replacement for [shiny](https://shiny.posit.co/r/) with **hot reload**,
an inspectable **reactive graph**, **strict mode** and **time-travel**
debugging.

An app written for hotShiny is a shiny app: swap `library(hotShiny)` for
`library(shiny)` (or let `publish_to_shiny()` do it) and it runs unchanged.
The reverse holds too: shiny apps run on hotShiny unmodified.

## Installation

```r
pak::pak("dark-peak-analytics/hotShiny")
```

## Quick start

Write a normal shiny app:

```r
# app.R
library(hotShiny)

ui <- fluidPage(
  textInput("name", "Name:"),
  textOutput("greeting")
)

server <- function(input, output, session) {
  greeting <- reactive(paste("Hello,", input$name))
  output$greeting <- renderText(greeting())
}

shinyApp(ui, server)
```

Run it with hot reload on:

```r
hotShiny::runApp("app.R", hot_reload = TRUE)
```

Edit `app.R` and save. The page updates in place without a refresh. Inputs,
`reactiveVal()` and `reactiveValues()` state, and scroll position are kept.

### Apps split into ui.R / server.R and modules

Pass the app's directory instead of a file:

```
myapp/
├── global.R
├── ui.R
├── server.R
└── R/
    ├── counter_module.R
    └── plot_module.R
```

```r
hotShiny::runApp("myapp", hot_reload = TRUE)
```

As with `shiny::runApp()`, `global.R` and every file in `R/` are sourced
first, so modules don't need to be `source()`d by hand. Every file in the
directory is watched, so an edit to a module reloads just like an edit to
`ui.R` or `server.R`.

Development features are switched on by the launcher, never inside the app
file, so the file stays plain shiny:

| Feature | `runApp()` argument | Option |
|---|---|---|
| Hot reload | `hot_reload = TRUE` | `hotshiny.hot_reload` |
| Strict mode (warn about side effects in `reactive()`) | `strict = TRUE` | `hotshiny.strict` |
| Reactive history / time travel | `time_travel = TRUE` | `hotshiny.time_travel` |
| Tailwind CSS without code changes | `tailwind = TRUE` | `hotshiny.tailwind` |

## How it works

- **UI, client and protocol are shiny's.** Every UI function, renderer and
  helper is re-exported from shiny, so markup is byte-identical. The browser
  runs the real `shiny.js`, and the server speaks shiny's websocket protocol.
  Extension packages (htmlwidgets, DT, plotly, bslib, shinyWidgets, shinyjs, …)
  therefore render and behave as they do on shiny.
- **The reactive engine is hotShiny's.** It follows shiny's semantics:
  dependencies are tracked dynamically, reactives are lazy and cached,
  observers run in priority order, and so on. It also records each session's
  reactive graph with stable node ids, which is what hot reload, graph
  inspection and time travel are built on.
- **A bridge keeps the ecosystem on one engine.** While a hotShiny app runs,
  shiny's reactive primitives are routed to hotShiny's. That covers calls from
  inside shiny's namespace, from `package:shiny`, and from packages that
  imported them. As a result, code that calls `shiny::observe()`,
  `shiny::reactiveVal()` and so on (shiny's own `renderPlot()`, `bindCache()`,
  `ExtendedTask`, and many extension packages) runs on hotShiny's engine.
  Packages that need more get a package-specific substitute, applied when the
  package is detected (`register_substitute()`). See
  [docs/ECOSYSTEM_COMPAT.md](docs/ECOSYSTEM_COMPAT.md).
- **Each browser has its own session.** The session implements the full
  `ShinySession` surface: modules, uploads, downloads, data objects,
  `setCurrentTheme()`, test snapshots and more.

### Hot reload

When a source file changes, hotShiny:

1. re-loads the app;
2. snapshots every session's `reactiveVal()` / `reactiveValues()` state by
   stable id;
3. destroys the old observers and outputs;
4. re-runs the new server function in the same session, restoring the
   matching state.

On the client, only the parts of the page whose markup changed are swapped,
then rebound through Shiny with their input values restored. New widget
dependencies are loaded. The websocket stays connected throughout.

Event handlers (`observeEvent()`) created during a reload do not re-fire for
events that were already handled before it.

## Publishing to plain shiny

```r
hotShiny::publish_to_shiny("myapp", "myapp-shiny")
shiny::runApp("myapp-shiny")
```

This writes a copy of the app that needs only shiny:

- `library(hotShiny)` and `hotShiny::` become `shiny`;
- development-only calls are removed;
- hotShiny's extended input arguments become
  `htmltools::tagAppendAttributes()` calls;
- if the app uses Tailwind utility classes, `shiny.tailwind` is added.

A `PUBLISHED.md` file lists every change and the packages the published app
needs.

## Styling with Tailwind

hotShiny's input functions accept extra attributes. `class` is appended to
the control's own classes:

```r
textInput("name", NULL, class = "border rounded-xl px-3 py-2")
selectInput("pick", "Pick", c("a", "b"), class = "ring-2 ring-blue-300")
```

With no extra arguments these functions return exactly what shiny returns.

Run with `runApp(..., tailwind = TRUE)` to load Tailwind's CDN build during
development. Alternatively, call `shiny.tailwind::use_tailwind()` in the UI
yourself, which works in both runtimes. `publish_to_shiny()` converts the
extra attributes and adds `use_tailwind()` when it detects Tailwind classes.

## Developer tools

```r
visualize_graph()                 # nodes and run-time dependency edges of a session
cat(visualize_graph(format = "dot"))
reactive_history()                # recorded events (time_travel = TRUE)
replay_inputs(42)                 # rewind a session's inputs to event 42
strict_check(function() { write.csv(x, "f.csv"); x })
```

## Testing

- `tests/testthat`: engine semantics, UI extensions, publishing and the bridge
  (`testthat::test_local()`).
- `tests/e2e`: Playwright end-to-end suite. Every fixture app runs both
  under plain shiny (produced with `publish_to_shiny()`) and under hotShiny.
  - **Behaviour** specs assert identical results in both runtimes.
  - **Parity** specs diff the live DOM, the loaded dependencies and the
    rendered pixels.
  - **Hot-reload** specs edit app sources while a browser is connected.

  ```sh
  R CMD INSTALL .
  cd tests/e2e && npm ci && npx playwright test
  ```

## License

MIT
