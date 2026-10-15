# hotShiny compatibility report: 63 R packages checked against the planned core and shiny-namespace bridge

## 0. Headline findings

I checked these against the shiny 1.14.0 sources installed here.

1. **`getDefaultReactiveDomain()` can be satisfied by the core without patching anything.** In shiny 1.14 it is just `.globals$domain`. `shiny::withReactiveDomain(domain, expr)` sets that value and carries it through promise domains. If hotShiny runs every observer, render, `onFlushed` callback and module call inside `shiny::withReactiveDomain(hotSession, ...)`, the real versions of many functions work unchanged. That list is `getDefaultReactiveDomain`, `insertUI`/`removeUI`, `showModal`, `update*`, `onStop`, `getCurrentOutputInfo`, `shinyOptions`/`getShinyOption`/`getCurrentTheme`, `restoreInput`, `moduleServer`/`callModule` and `invalidateLater`'s session argument. They call methods on `session$`, so the requirement shifts from routing to the session object's surface. The session must:
   - inherit class `"ShinySession"`, because `validate_session_object` checks for `ShinySession`, `MockShinySession` or `session_proxy`;
   - have module proxies of class `"session_proxy"`;
   - have a mutable `$options` field;
   - have a `$singletons` field, which `processDeps()` reads;
   - have `$restoreContext` set to `NULL`;
   - provide `$makeScope()`.

   This takes **about 30 libraries** off the bridge. I mark it as "adjusted" in the table.
2. **Library `.onLoad` hooks write into two shiny registries.** They are `shiny:::inputHandlers` (via `registerInputHandler`, used by 12 libraries) and `shiny:::.globals$resourcePaths` (via `addResourcePath`, used by 24 or more libraries plus every htmlwidget dependency). The core should read both registries live. Routing these calls is the wrong fix, because most libraries register before hotShiny loads.
3. **Only the reactive primitives truly need the bridge.** These are `observe`, `observeEvent`, `isolate`, `reactive`/`eventReactive`, `reactiveVal`, `reactiveValues`, `invalidateLater`, `bindEvent`, `debounce`/`throttle`, `ExtendedTask` and shiny's own `renderPlot`. On top of those come `isRunning`/app state and the app runner (`shinyApp`, `runApp`). Each of these creates objects that live in shiny's ReactiveEnvironment, which hotShiny never flushes or tracks.
4. **Dynamic dependency tracking is mandatory.** Today hotShiny tracks dependencies statically from the AST. That cannot see inside closures built by packages through `exprToFunction` or `installExprFunction`, which almost every library here does.
5. **`isolate` is unusual.** `shiny::isolate` only stops shiny's own dependency tracking. hotShiny reads inside it would still create hotShiny dependencies, so it must be routed even when no shiny reactive object is involved.

## 1. All libraries

The table is sorted by adjusted verdict, then popularity. **R** is the research verdict and **A** is my adjusted verdict, assuming the decisions in section 0.

| Library | Category | Pop. | R | A | Effort | Reason |
|---|---|---|---|---|---|---|
| shinytest2 | testing | high | shim | **shim** | L | Its child process calls the real `shiny::runApp(dir)`, so the launcher must be substituted. Also needs the testmode snapshot dataobj. |
| bslib | UI/theming | very high | bridge | bridge | L | Needs `isRunning`/app state for `bootstrapLib` theme registration, `ExtendedTask`, and `observe` (task button, themer). Also `session$setCurrentTheme` and `$options`. |
| shinyWidgets | inputs | very high | bridge | bridge | M | Widgets alone are core. `pickerGroupServer`/`selectizeGroupServer` need `observe`, `reactive`, `reactiveValues` and `isolate` through the imports env. `bs_dependency_defer` needs `isRunning`. |
| shinyjs | JS helpers | very high | bridge | bridge | S | `observeEvent(once=TRUE)` in `onclick`/`delay`/`reset`, plus `isolate`. Modules need the `session_proxy` class. |
| plotly | charts | very high | bridge | bridge | M | `event_data(priority='input')` builds `shiny::reactiveValues` plus `shiny::observe`. Needs `rootScope`/`userData`. |
| golem | framework | high | bridge | bridge | M | Builds a real `shiny.appobj` and launches it with `print()`, so needs `shinyApp`/`runApp` routing and app-level `getShinyOption`. |
| shinymanager | auth | high | bridge | bridge | M | `observe`, `observeEvent`, `isolate`, `reactiveValues`, plus `session$reload` and a UI function that receives the request. |
| shinyvalidate | validation | high | bridge | bridge | M | Its own `reactiveVal` plus `observe` inside `withReactiveDomain`, and `isolate`. |
| promises/future + ExtendedTask | async | very high | core | core + bridge | L | The runtime must be promise-aware. `shiny::ExtendedTask` uses shiny's internal `reactiveVal`, so it must be routed. |
| bs4Dash | dashboard | high | bridge | bridge | M | `observeEvent`/`eventReactive` (`useAutoColor`), plus `setCurrentTheme`/`$options`. |
| visNetwork | network | high | bridge | bridge | M | The widget and proxy are core. The `visTree` module and editors use `shiny::reactive`/`observe`/`isolate`. |
| logger | logging | high | bridge | bridge | S | `log_shiny_input_changes` uses `observe`, `isolate` and `reactiveValuesToList(input)`. |
| esquisse | ggplot builder | medium | bridge | bridge | L | Imports nearly the whole reactive surface, plus shiny's `renderPlot`, `bindEvent`, `debounce` and download. |
| datamods | data modules | medium | bridge | bridge | L | Same pattern as esquisse, plus upload/download and `outputOptions(suspendWhenHidden)`. |
| rhino | framework | medium | bridge | bridge | L | `box::use(shiny[...])` pulls from the shiny namespace, so the bridge must patch before that runs. Needs `shinyApp` routing and a box cache purge on reload. |
| shiny.router | routing | medium | bridge | bridge | S | `shiny::reactiveVal`, `observeEvent`, `isolate`. |
| shinyAce | editor | medium | bridge | bridge | S | `aceAutocomplete`/`aceAnnotate` use `shiny::observe`/`observeEvent`. |
| shinyFiles | file chooser | medium | bridge | bridge | S | `observe`/`observeEvent` via imports, plus `invalidateLater` polling. |
| jsTreeR | tree | medium | bridge | bridge | S | The widget is core. `treeNavigatorServer` needs `reactiveVal`/`observeEvent`. |
| shinyalert | alerts | high | bridge | bridge | S | `observeEvent` for `callbackR`. `insertUI` is core. |
| shinyhelper | help modals | medium | bridge | bridge | S | `observeEvent`. `showModal` is core. |
| shinyauthr | auth | medium | bridge | bridge | S | `reactive*`, `observe*`, `reactiveValuesToList`. `moduleServer` is core. |
| thematic | plot theming | medium | bridge | bridge (minor) | M | `getCurrentOutputInfo` and `onStop` are core. Needs `isRunning`, and clientData `bg`/`fg`/`accent`/`font`. |
| shinyFeedback | feedback | medium | bridge | core (+bridge for valueBoxModule) | S | The main path is session-only. `valueBoxModule` uses `shiny::reactive`. |
| ShinyState | hooks | low | bridge | bridge | S | `shiny::reactiveVal`/`reactive`/`observe*`/`isolate`, plus `shinyApp`. |
| reactlog | devtools | medium | bridge | **defer** (hotShiny-native) | L | shiny's `rLog` never sees hotShiny events. This is an exporter feature, not integration work. |
| htmlwidgets | widget framework | very high | core | core | M | Pure `createRenderFunction`/`createWebDependency`. Needs json passthrough and a live resource-path registry. |
| DT | tables | very high | bridge | core (input-impl compat) | L | `snapshotPreprocessInput` needs `.subset2(input,'impl')$setMeta` (see section 7), plus the dataobj POST endpoint and `httpResponse`. |
| leaflet | maps | very high | bridge | core | S | Domain only, plus `ns(NULL)`, an `onSessionEnded` that returns an unregister function, and `onFlushed(once)`. |
| shinydashboard | dashboard | very high | bridge | core | S | `renderMenu` is real `renderUI`, which is pure. `updateTabsetPanel` works through the domain. |
| fontawesome | icons | very high | core | core | S | Pure htmltools. |
| shinycssloaders | spinners | very high | bridge | core | S | `insertUI` works through the domain. Needs recalculating/progress messages. |
| config | config | very high | core | core | S | No shiny use. |
| reactable | tables | high | bridge | core | S | Domain only. |
| highcharter | charts | high | bridge | core | S | Domain only. |
| ggiraph | charts | high | core | core | S | Explicit session. |
| gt | tables | high | bridge | core | S | Uses the same pure functions as htmlwidgets. Bridge was inconsistent with the htmlwidgets verdict. |
| shinydashboardPlus | dashboard | high | bridge | core | S | Domain plus `createWebDependency`, which is pure. |
| shinythemes | themes | high | bridge | core | S | Live resource-path registry plus the `shared/bootstrap` path. |
| colourpicker | inputs | high | bridge | core | S | Domain only. Its gadgets are deferred. |
| waiter | loading | high | bridge | core | S | Domain plus a `session$progressStack` field. |
| shinybusy | busy | high | bridge | core | S | `showModal`/`insertUI`/`sendModal` work through the session. Needs busy/idle messages. |
| miniUI | gadget UI | high | core | core | S | Markup only. `runGadget` is a runner issue. |
| echarts4r | charts | medium | bridge | core | M | Domain, the handler registry, and plain zero-argument outputs. |
| rhandsontable | grid | medium | bridge | core | S | Handler registry. `editAnywhere` is deferred. |
| timevis | timeline | medium | bridge | core | S | Domain plus handler registry. |
| billboarder | charts | medium | bridge | core | S | Domain only. |
| dygraphs | charts | medium | core | core | S | Plain htmlwidget. |
| fresh | theming | medium | core | core | S | sass plus htmltools. |
| shiny.semantic | UI framework | medium | bridge | core | M | Session-deep: `progressStack`, dataobj, the `uploadInit`/`uploadEnd` protocol, `clientData` `url_*`. |
| shiny.fluent | UI framework | medium | bridge | core | M | `exprToFunction` is pure. Needs plain-function outputs. |
| shinyjqui | interactions | medium | bridge | core | M | `insertUI(immediate)` through the session, `onFlushed` timing, and an htmlDependency with `package='shiny'`. Bookmarking is deferred. |
| sortable | DnD lists | medium | bridge | core | S | Handler registry plus domain. |
| shinyTree | tree | medium | core | core | S | Old-style `function(shinysession, name)` output. Needs dynamic tracking. |
| shinytoastr | toasts | medium | bridge | core | S | Domain plus registry. |
| sever | disconnect | medium | bridge | core | S | Domain. Hot reload must not fire `shiny:disconnected`. |
| rintrojs | tours | medium | core | core | S | Explicit session. |
| cicerone | tours | medium | bridge | core | S | Domain plus registry, and the `bootstrapTabInput` binding name. |
| shiny.i18n | i18n | medium | bridge | core | S | Needs the `session_proxy` class and `rootScope`. |
| shinyloadtest | load test | medium | core | core | S | Protocol and URL layout must be byte-compatible, with no hot-reload frames. |
| shinyglide | wizard | low | core | core | S | Uses shiny.js internals only. |
| shiny.tailwind | CSS | low | core | core | S | Markup only. |
| argonDash | dashboard | low | bridge | core | S | Full `<html>` document UI plus the registry. |

**Popularity notes.** promises and future should be very high rather than high, since they are dependencies of shiny itself. rhandsontable sits at the upper end of medium.

## 2. Must be rewritten or substituted (shim)

**shinytest2.** This is the only true shim.
- **What to substitute:** the `AppDriver$new` child-process launcher. It is internal, and the name is something like `app_start_shiny()` in `R/app-driver-start.R`; I could not verify it because shinytest2 is not installed. The launcher runs `callr::r_bg(function(...) shiny::runApp(app_dir, ...))`.
  - The substitute should call `hotShiny::runApp` with `options(shiny.testmode=TRUE)` and print exactly `Listening on http://...` to stderr.
  - Substitute the snapshot-URL helper too if hotShiny's URL differs.
- **Why the bridge doesn't help:** the bridge is not active in a fresh child process, and the real `runApp` would receive a hotShiny app object.
- **Fallback with no shim:** if `app.R` calls `hotShiny::runApp(...)` itself (it blocks, and `shiny::runApp(dir)` sources `app.R`), the app starts under hotShiny. This is hacky but gives zero-shim compatibility.
- **Core work either way:** `session$getTestSnapshotUrl`, the `dataobj/shinytest?input=1&output=1&export=1&format=json` endpoint using shiny's serialisation, and `exportTestValues`.

No other library needs package-specific code. The research's DT, plotly and leaflet concerns are all met by the session surface plus the bridge.

## 3. Generic shiny-namespace bridge surface

**Mechanism.** Install a dispatcher for each function. If the current domain is a hotShiny session, or a hotShiny context is active, it calls the hotShiny version. Otherwise it calls the original. Install it in four places:
1. the `asNamespace("shiny")` binding, which also covers shiny-internal unqualified calls such as `renderPlot`'s internal `reactive`, `debounce`, `bindCache` and `ExtendedTask`;
2. `package:shiny`;
3. the imports env of every loaded package that has a copy of the function (`identical()` match);
4. a `packageEvent(..., "onLoad")` hook for packages loaded later.

Packages using `import(shiny)` or `importFrom` (waiter, shinybusy, shinyWidgets, colourpicker, shinyFiles, jsTreeR, esquisse, datamods, shinytoastr) copied the function objects when they loaded. Patching the shiny namespace alone does not reach those copies.

**Routing required**, ranked by how many libraries need each (adjusted counts):

| Rank | Function | Libraries |
|---|---|---|
| 1 | `observeEvent` | about 17: shinyjs, shinyalert, shinyhelper, shinyAce, shinyFiles, jsTreeR, esquisse, datamods, shiny.router, bslib, bs4Dash, shinyWidgets, visNetwork, shinymanager, shinyauthr, ShinyState, rhino |
| 2 | `observe` | about 15: plotly, visNetwork, bslib, shinyWidgets, shinyAce, shinyFiles, esquisse, datamods, shinyvalidate, shinymanager, shinyauthr, ShinyState, logger, rhino, ExtendedTask |
| 3 | `isolate` | about 12: plotly, visNetwork, shinyWidgets, esquisse, datamods, shiny.router, shinyjs, shinyvalidate, shinymanager, ShinyState, logger, rhino. Must suppress hotShiny tracking. |
| 4 | `reactive` / `eventReactive` | about 10: visNetwork, bs4Dash, shinyWidgets, esquisse, datamods, shinyFeedback, shinyauthr, ShinyState, rhino, plus shiny-internal users |
| 5 | `reactiveVal` | 7: shiny.router, shinyvalidate, jsTreeR, datamods, shinyauthr, ShinyState, ExtendedTask. Must keep shiny's call semantics and class `c("reactiveVal","reactive","function")`. |
| 6 | `reactiveValues` | 6: plotly, shinyWidgets, esquisse, datamods, shinymanager, shinyauthr |
| 7 | `isRunning` / app state | 5: bslib (`bootstrapLib` theme registration), shinyWidgets and bs4Dash (`bs_dependency_defer`), golem, thematic, logger. Alternatively set `shiny:::.globals$appState` and give it an `$options` field. |
| 8 | `shinyApp` / `shinyAppDir` / `runApp` / `runGadget` | 5: golem, rhino, ShinyState, shinytest2, miniUI gadgets |
| 9 | shiny's `renderPlot` | 3: esquisse, datamods, and thematic via user code. Its internal reactive goes stale, so route it to hotShiny's `renderPlot`. |
| 10 | `reactiveValuesToList` | 2: logger, shinyauthr. Or provide input-impl compat. |
| 11 | `bindEvent` | 2: esquisse, datamods. It inspects Observer internals. |
| 11 | `invalidateLater` | 2: shinyFiles, esquisse. It uses shiny's `getCurrentContext()`. |
| 11 | `ExtendedTask` | 2: bslib `bind_task_button`, async apps |
| 14 | `debounce` / `throttle` | 1–2: esquisse |
| 15 | `reactlog` / `reactlogShow` / `reactlogReset` | 1: reactlog (deferred) |

hotShiny objects should carry shiny's classes so that `shiny::is.reactive` and similar checks pass natively: `reactiveExpr`, `reactive`, `function`, `Observer`, `reactivevalues`. Observers should expose `destroy`, `suspend`, `resume`, `setPriority` and `onInvalidate`.

**No routing needed** if the core handles them. Counts are in parentheses.
- **Satisfied by the `withReactiveDomain` wrapping:** `getDefaultReactiveDomain` (about 32), `withReactiveDomain`, `getCurrentOutputInfo`, `getCurrentTheme`/`shinyOptions`/`getShinyOption`/`registerThemeDependency` (needs `session$options`), `restoreInput` (needs `restoreContext=NULL`), `insertUI`/`removeUI`, `showModal`/`removeModal`, `showNotification`, `update*` (needs class ShinySession), `moduleServer`/`callModule` (needs `makeScope`), `onStop`, `getUrlHash`/`getQueryString`/`updateQueryString`.
- **Satisfied by reading shiny's registries:** `registerInputHandler` (12), `addResourcePath` (24 or more).
- **Pure functions:** `createWebDependency`, `installExprFunction`, `createRenderFunction`, `markRenderFunction`, `exprToFunction`, shiny's `renderUI`/`renderText`, `parseQueryString`, `httpResponse`, `snapshotPreprocessOutput`.
- **Core honours shiny's condition classes:** `req`, `validate`, `need`, `cancelOutput` (`shiny.silent.error`, `validation`, `shiny.output.cancel`, `shiny.output.progress`).

**Fallback:** if hotShiny does not adopt `withReactiveDomain` wrapping, `getDefaultReactiveDomain` becomes bridge item #1 at about 32 libraries, followed by `insertUI`, `showModal`, `update*`, `shinyOptions` and the rest.

## 4. ShinySession surface (union)

**Class and fields**
- class `c("ShinySession", ...)`; module proxies of class `"session_proxy"` with `rootScope()`
- `token`
- `input`: reactivevalues-like, with `[[`/`$`, plus `.subset2(input,"impl")` exposing `get`, `set`, `toList`, `names` and `setMeta` (needed by DT and `reactiveValuesToList`)
- `output`
- `clientData`: `url_*`, `url_hash`, `url_search`, `output_<id>_width/height/hidden/bg/fg/accent/font`, `pixelratio`
- `userData`: a per-client env
- `options`: mutable
- `singletons`
- `restoreContext = NULL`
- `progressStack`: a Stack with `push`, `pop`, `peek`, `size` (waiter, shiny.semantic, `withProgress`)
- `request`: a Rook env, also passed to UI-as-function (shinymanager)

**Messaging**

| Method | Libraries |
|---|---|
| `sendCustomMessage` | about 35 |
| `sendInputMessage` | about 15 |
| `sendInsertUI` / `sendRemoveUI` | |
| `sendModal("show"/"remove")` | shinybusy calls it directly |
| `sendNotification` | |
| `sendInsertTab` / `sendRemoveTab` | bslib |
| `sendProgress` | |
| `updateQueryString(mode = push/replace)` | |
| `reload()` | shinymanager, shinyauthr |
| `close()` | sever |

**Lifecycle**
- `ns`, including `ns(NULL)` (about 18 libraries)
- `makeScope(id)`
- `onFlushed(fn, once=TRUE)`, with timing after outputs are sent (DT, plotly, leaflet, shinyjqui, `insertUI`)
- `onFlush(once=TRUE)` (bslib handlers)
- `onSessionEnded` / `onEnded`, both returning an unregister function (leaflet, `onStop`)
- `onDestroy`
- `isClosed`
- `cycleStartAction`
- `getCurrentOutputInfo` (DT, thematic)

**Theme:** `setCurrentTheme`, which mirrors ShinySession: Bootstrap version check, rerun `themeDependencyFuncs`, `restyle=TRUE`, `insertUI` to body afterEnd. Also `getCurrentTheme`.

**HTTP:** `registerDataObj` (DT, shiny.semantic, shinytest2) with the exact URL `session/<token>/dataobj/<name>?w=&nonce=`, POST bodies passed through `rook.input`, and filters that may return `httpResponse` objects or promises. Also `fileUrl`, `registerDownload`, and upload `uploadInit`/`uploadEnd`.

**Testing and bookmarking:** `setBookmarkExclude`/`getBookmarkExclude` as no-op stores (shinymanager), `getTestSnapshotUrl`, `exportTestValues`.

**Output assignment** must accept three kinds of value:
- a `shiny.render.function`, called as `f(shinysession=, name=)`, with promise results resolved;
- a plain zero-argument function (echarts4r box, shiny.react);
- a legacy `function(shinysession, name, ...)` (shinyTree).

`json`-class values pass through without re-encoding. `outputOptions(suspendWhenHidden=FALSE)` must be honoured.

## 5. Browser-side surface

All of this comes free with the real shiny.js. The server must emit the messages that drive the events.

**JS APIs**

| API | Libraries |
|---|---|
| `Shiny.setInputValue` / `onInputChange` (incl. `priority:'event'`, `:type` suffixes) | about 38 |
| `addCustomMessageHandler` | about 36 |
| `InputBinding` + `inputBindings.register` | about 16 |
| `bindAll` / `unbindAll` | about 13 |
| `OutputBinding` + `outputBindings.register` | about 9 |
| `renderDependencies` (with restyle) | about 8 |
| `initializeInputs` | about 5 |
| `renderHtml` | about 4 |
| `htmlOutputBinding` | 3 |
| `renderContent` / `renderContentAsync` | 2 |
| `compareVersion` / `Shiny.version` | 2 |
| `shinyapp.isConnected` / `reconnect` | 2 |
| `shinyapp.$inputValues` / `$values` / `$errors` | 1 (shinytest2) |
| `shinyapp.$updateConditionals` | 1 |
| `shinyapp.makeRequest` (upload) | 1 |
| `inputBindings.bindingNames['shiny.bootstrapTabInput']` | 1 |
| `$(el).data('shiny-input-binding')` | 1 |
| `HTMLWidgets.shinyMode` | about 13 widgets |

**jQuery `shiny:*` events**

| Event | Libraries |
|---|---|
| `shiny:value` | about 9 |
| `shiny:recalculating` / `recalculated` | 5 |
| `shiny:outputinvalidated` | 4 |
| `shiny:inputchanged` | 4 |
| `shiny:error` | 3 |
| `shiny:busy` / `idle` | 3 |
| `shiny:bound` | 2 |
| `shiny:connected` | 2 |
| `shiny:sessioninitialized` | 2 |
| `shiny:message` | 2 |
| `shiny:disconnected` | 1 |
| `shiny:visualchange` | 1 |
| `shiny:client-message` | 1 |

Plus the `shown`/`hidden` triggers used for visibility.

**Server messages that drive those events:**
- `progress {type:'binding', message:{id}}`, which drives `outputinvalidated`/`recalculating`;
- `busy: busy/idle`;
- `errors`;
- `config` with `sessionId`/`workerId`;
- `inputMessages`, `custom`, `modal`, `notification`, `shiny-insert-ui`, `updateQueryString`, `shiny-insert-tab`.

**CSS classes and IDs:** `.recalculating`, `html.shiny-busy`, `.shiny-bound-input/-output`, `.shiny-input-container`, `.shiny-output-error`, `.shiny-report-size`, `.shiny-report-theme`, `.html-widget-output`, `#shiny-disconnected-overlay`, `.shiny-html-output`, `.shiny-text-output`, `.shiny-plot-output`.

## 6. Implementation order and e2e matrix

**Order** (what each step unlocks):
1. **Core prerequisites.**
   - Switch to dynamic dependency tracking.
   - Wrap every reactive, render and flush callback in `shiny::withReactiveDomain(session)`.
   - Make the session class `ShinySession`, with `options`, `singletons`, `restoreContext` and a `session_proxy` scope.
   - Read `shiny:::inputHandlers` and serve `shiny:::.globals$resourcePaths` live.
   - Honour shiny condition classes.

   This unlocks roughly 35 "core" libraries.
2. **Output protocol.** Accept `shiny.render.function`, plain and legacy functions, and json passthrough. Unlocks htmlwidgets and all 12 widgets, gt, the shinydashboard family, shiny.fluent and shinyTree.
3. **Session messaging.** `sendCustomMessage`/`sendInputMessage`, `onFlushed`, `insertUI`/modal/notification, `progressStack`, recalculating and busy messages. Unlocks the shinyjs client side, waiter, shinybusy, shinycssloaders, leaflet and other proxies, and timevis.
4. **Bridge dispatcher, part 1:** `observe`, `observeEvent`, `isolate`, `reactive`, `reactiveVal`, `reactiveValues`, including imports-env patching. Unlocks about 17 libraries: shinyjs, plotly, shinyalert, shinyhelper, shinyvalidate, shiny.router, shinyAce, shinyFiles, the auth packages, ShinyState and visNetwork.
5. **App state.** `isRunning`, `bootstrapLib` theme, `setCurrentTheme`. Unlocks bslib, bs4Dash, BS5 markup in shinyWidgets, and thematic.
6. **HTTP endpoints.** dataobj, upload, download. Unlocks DT server mode, shiny.semantic, datamods and esquisse.
7. **Async.** Promises plus routed `ExtendedTask`, `bindEvent`, `debounce`, `invalidateLater` and `renderPlot`. Unlocks esquisse, datamods and `bind_task_button`.
8. **Runner.** `shinyApp`/`runApp` routing (golem, rhino), the shinytest2 shim, and testmode snapshots.
9. **Deferred:** reactlog exporter, bookmarking (`onRestored`, `restoreInput` with real values), gadgets.

**Prioritised e2e matrix:**

| # | Scenario | Proves |
|---|---|---|
| 1 | plotly: `renderPlotly` inside `renderUI`, click events, `event_data(priority='input')`, proxy `addTraces` | Deps registered at render time, json passthrough, bridged `observe`/`reactiveValues`, event priority |
| 2 | DT server mode: search, select, cell edit, `selectRows` proxy, `replaceData` | dataobj POST, `input impl$setMeta`, `:DT.cellInfo` handler, `onFlushed` |
| 3 | bslib `page_sidebar` with `setCurrentTheme`, `input_task_button` and dark mode | Theme pipeline, `isRunning`, onLoad handler registry, `onFlush`, `ExtendedTask` |
| 4 | shinyWidgets: picker, airDatepicker, `updatePickerInput` without session, `sendSweetAlert` | Domain wrapping, typed handlers, `insertUI`, BS5 markup |
| 5 | leaflet: map click adds markers, awesome-markers deps loaded via proxy, inside a module | Runtime resource paths, `ns(NULL)`, `session_proxy` |
| 6 | shinyjs: hide, show, reset, delay, `onclick`, inside `moduleServer` | Bridged `observeEvent(once)`, markup fidelity for `reset` |
| 7 | shinyvalidate in two browser contexts | Bridged `reactiveVal`/`observe` inside `withReactiveDomain`, per-client state |
| 8 | shinydashboard: `renderMenu`, `updateTabItems`, `sidebarCollapsed` | Real shiny `renderUI` function, `validate_session_object` |
| 9 | shinycssloaders plus shinybusy plus waiter around a slow `renderPlot`, and one that errors | recalculating/busy messages, `shiny:*` events, `progressStack` |
| 10 | datamods `import_file` and `filter_data` | Upload endpoint, `suspendWhenHidden=FALSE`, many bridged imports |
| 11 | esquisse: drag variables, code tab, PNG export | Routed `renderPlot`, `bindEvent`/`debounce`, download, clientData sizes |
| 12 | Async: `future_promise` render next to a sync output, `ExtendedTask` | Non-blocking flush, busy state |
| 13 | golem skeleton run via `run_app()` | `shinyApp`/`print`/`runApp` routing, app-level `getShinyOption` |
| 14 | shinytest2 `AppDriver` on a hotShiny app: `set_inputs`, `expect_values`, upload, download | Shim, testmode snapshot |
| 15 | timevis plus rhandsontable `selectCallback` (typed `:timevisDF` and custom deserializer) plus shiny.router hash navigation | onLoad handler registry, `clientData url_hash`, `updateQueryString` |

## 7. Where I disagree with the research

- **About 30 "bridge" verdicts should be "core".** These are libraries whose only runtime coupling is the domain or the registries: leaflet, reactable, highcharter, billboarder, timevis, echarts4r, rhandsontable, sortable, colourpicker, shinytoastr, cicerone, sever, shinycssloaders, shinybusy, waiter, shiny.semantic, shiny.fluent, shinyjqui, shinydashboard(Plus), shinythemes, argonDash and shiny.i18n. This is because `getDefaultReactiveDomain` is `.globals$domain` and can be set with `withReactiveDomain`, as covered in section 0. It holds only if decision 1 in section 6 is adopted.
- **gt** should be core. It uses exactly the same pure functions the research rated core for htmlwidgets.
- **DT:** in 1.14, `snapshotPreprocessInput` calls `stop()` when the session is NULL and requires `.subset2(session$input,"impl")$setMeta`. Routing it is unnecessary if hotShiny's input exposes a compatible `impl`. I recommend that, because it also fixes `reactiveValuesToList`.
- **moduleServer / callModule** need no routing. They call `session$makeScope` and `withReactiveDomain`. The research listed them as bridge items for jsTreeR, esquisse and others.
- **getCurrentTheme** is `getShinyOption("bootstrapTheme")`, not a session method. It needs `session$options`, or app state when there is no session. That matters for bslib and bs4Dash.
- **isolate** must be bridged even for libraries with no shiny reactive objects, because shiny's version does not suppress hotShiny's tracking. The research treated it only as part of the reactive-primitive set.
- **reactlog** is better marked "defer, hotShiny-native exporter" than bridge.
- **promises / ExtendedTask** is core plus bridge, not pure core, because `shiny::ExtendedTask` uses shiny's internal `reactiveVal`.
- **shinytest2:** I agree it is a shim, but the `app.R`-calls-`hotShiny::runApp` fallback in section 2 may avoid it. I could not verify the internal launcher's name because shinytest2 is not installed.

Assumptions: shiny 1.14.0 as installed at `/home/jesus/R/x86_64-pc-linux-gnu-library/4.6`. I checked these function bodies: `getDefaultReactiveDomain`, `withReactiveDomain`, `getShinyOption`/`shinyOptions`, `getCurrentTheme`, `isRunning`, `validate_session_object`, `processDeps`, `insertUI`, `showModal`, `invalidateLater`, `snapshotPreprocessInput`, `restoreInput`, `registerInputHandler`, `addResourcePath`, `observe`, `reactiveVal`, `isolate`, `req`. No files were modified.
## 8. Verified results (e2e)

Every package below has a fixture app in `tests/e2e/fixtures/eco-*` (written
with `library(hotShiny)`), behaviour specs in `tests/e2e/specs/ecosystem/`
and a parity spec in `tests/e2e/specs/parity/`. Each fixture runs under both
runtimes:

- **shiny**, after `publish_to_shiny()`;
- **hotShiny**.

The behaviour specs must pass in both runtimes. The parity specs require the
normalised live DOM and the loaded dependencies to match, and at most 0.2% of
pixels to differ.

| Group | Packages | Status |
|---|---|---|
| htmlwidgets | DT (client + server-side processing, selection, editing, proxy, modules), plotly (event_data click/hover/relayout/selected, proxy, inside renderUI, bindCache), reactable, echarts4r, visNetwork, dygraphs, highcharter, ggiraph | pass |
| UI frameworks | bslib (page_sidebar/page_navbar, navs, accordion, sidebar, input_switch, dark mode, setCurrentTheme, task button + ExtendedTask), shinydashboard, shinydashboardPlus, bs4Dash, shinythemes, fresh, thematic | pass |
| Inputs | shinyWidgets (pickers, switches, airDatepicker, sliders, virtualSelect, update* without session, sweet alerts, modules), colourpicker, sortable, shinyjqui, rhandsontable, timevis, shinyAce, shiny.router, jsTreeR, shinyTree | pass |
| UX helpers | shinyjs (incl. modules, extendShinyjs), shinycssloaders, waiter, shinybusy, shinyalert, shinyFeedback, shinyvalidate (two sessions), sever, shinytoastr, shinyhelper, rintrojs, cicerone, shiny.i18n | pass |
| Frameworks / async / testing | promises + future, ExtendedTask, golem (with_golem_options), shinytest2 AppDriver on a hotShiny app, shinymanager, gt, logger, datamods | pass |
| shiny's own examples | 01_hello … 11_timer (no 08 in shiny 1.14), including showcase mode | pass |
| leaflet | — | not tested: leaflet could not be installed on the test machine (needs GDAL/udunits system libraries) |

Core fixes these packages required, now in hotShiny:

- static resource paths are served from httpuv's I/O thread, like shiny;
- `shinyOptions(server =)` is set, so dependencies added at runtime are served;
- the app-level `cache` defaults to the same 200MB memory cache as shiny's
  (needed by `bindCache`);
- `appOptions` are applied, which golem needs;
- an output's domain is the module scope it was assigned in;
- `reactiveValues` keep insertion order;
- test-mode snapshots are shiny-compatible;
- showcase mode and its srcrefs;
- a hotShiny `testServer()` runs on shiny's `MockShinySession`.

Parity normalisation only canonicalises ids that shiny or the widget
libraries randomise on every render (session tokens, selectize/plotly/
highcharts/girafe/gt/shinyjs/shinybusy ids). Content is never dropped.

A few vendor races exist in plain shiny as well and can make a parity run
flaky under heavy machine load: AdminLTE OverlayScrollbars in bs4Dash,
bootstrap-select's aria attributes, and ion.rangeSlider label positions.
