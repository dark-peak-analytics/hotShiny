# hotShiny ↔ shiny compatibility

Goal: an app runs identically whichever of `library(hotShiny)` or
`library(shiny)` it loads. That means the same markup, the same behaviour, and
the same extension packages working.

## What is identical by construction

- **UI**: every UI function, renderer and helper is shiny's own, re-exported.
  The exceptions are the input functions that additionally accept extra HTML
  attributes; with no extra arguments they return shiny's markup unchanged.
- **Client**: the browser runs the real `shiny.js`, jQuery, selectize,
  ion.rangeSlider and bootstrap-datepicker, served from the installed shiny
  package. Input/output bindings, `Shiny.*` APIs and `shiny:*` events are
  therefore shiny's.
- **Wire protocol**: the server speaks shiny's messages:
  - `init`/`update`, using shiny's input handlers;
  - `config`, `busy`, `recalculating`, `progress`;
  - `values`/`errors`/`inputMessages` per flush;
  - `custom`, `modal`, `notification`, `shiny-insert-ui` and friends;
  - `response`.

  JSON is encoded with shiny's own encoder.
- **Page rendering**: shiny's `renderPage()`, with dependencies registered
  through shiny's resource-path registry.

## Re-implemented with shiny's semantics

- **The reactive engine**:
  - `reactive`, `observe`, `observeEvent`, `eventReactive`, `bindEvent`;
  - `reactiveVal`, `reactiveValues`, `isolate`;
  - `invalidateLater`, `reactiveTimer`, `debounce`, `throttle`;
  - `reactivePoll`, `reactiveFileReader`, `freezeReactiveVal`,
    `makeReactiveBinding`.

  Dependencies are tracked dynamically. Objects carry shiny's classes
  (`reactiveExpr`, `reactiveVal`, `Observer`, `reactivevalues`) and internal
  shapes (`.subset2(x, "impl")`, `attr(x, ".impl")`).
- **The session** (one per browser): the full `ShinySession` surface. It
  covers:
  - module scopes;
  - output definition with silent/validation/cancel/progress conditions;
  - `getCurrentOutputInfo()`, `onFlush`/`onFlushed`, `onSessionEnded`;
  - `sendCustomMessage`/`sendInputMessage`;
  - uploads, downloads and `registerDataObj()`;
  - `setCurrentTheme()`, `freezeValue()`, `reload()`, `close()`;
  - test-mode snapshots.
- **The app runner**: `runApp()`, `shinyApp()`, `shinyAppDir()`,
  `shinyAppFile()`, `stopApp()` and `isRunning()`. App objects are regular
  `shiny.appobj`s.

## The bridge

While a hotShiny app runs, shiny's reactive primitives are replaced by
hotShiny's in three places:

- shiny's namespace;
- `package:shiny`;
- every loaded package's imports.

So `shiny::observe()`, shiny's own `renderPlot()`/`bindCache()`/`ExtendedTask`,
and extension packages all run on hotShiny's engine. The originals are restored
when the app stops. Package-specific substitutes use the same mechanism
(`register_substitute()`).

## Not supported

- **Bookmarking.** The functions exist so apps that configure it still run,
  but state is not saved or restored. `shiny2hotshiny_check()` lists
  bookmarking calls.
- **reactlog.** Use `visualize_graph()` and `reactive_history()` instead.

## Verified

- `tests/e2e` (Playwright): every fixture runs under plain shiny and under
  hotShiny.
  - **Behaviour** specs must pass in both runtimes.
  - **Parity** specs require the same normalised live DOM, the same
    dependencies, and a pixel difference of at most 0.2%. Normalisation only
    canonicalises ids that shiny randomises per render.
  - **Hot-reload** specs cover in-place updates, state preservation, new
    dependencies, error recovery and no disconnects.
- See [docs/ECOSYSTEM_COMPAT.md](docs/ECOSYSTEM_COMPAT.md) for the
  extension-package inventory and the e2e matrix.
