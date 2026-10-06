# HotSession: one per connected browser
#
# Implements the public surface of shiny's ShinySession (the object packages
# receive as `session`), including module scopes, output definition, the
# input/clientData stores, custom/input messages, file upload/download,
# data objects, theming and test snapshots. Messages use shiny's wire format,
# so the client is the real shiny.js.

# Base class so `inherits(session, "ShinySession")` holds, which shiny's own
# helpers (update*Input(), insertUI(), validate_session_object(), ...) check.
ShinySessionBase <- R6::R6Class("ShinySession", cloneable = FALSE)

new_output_writer <- function(session, ns = identity) {
  structure(list(impl = session, ns = ns), class = c("hs_shinyoutput", "shinyoutput"))
}

#' @export
`$<-.hs_shinyoutput` <- function(x, name, value) {
  name <- .subset2(x, "ns")(name)
  label <- deparse(substitute(value))[1]
  .subset2(x, "impl")$defineOutput(name, value, label)
  invisible(x)
}

#' @export
`[[<-.hs_shinyoutput` <- `$<-.hs_shinyoutput`

#' @export
`$.hs_shinyoutput` <- function(x, name) {
  name <- .subset2(x, "ns")(name)
  if (isTRUE(getOption("shiny.allowoutputreads", FALSE))) {
    return(.subset2(x, "impl")$getOutput(name))
  }
  rlang::abort(paste0("Can't read output '", name, "'"))
}

#' @export
`[[.hs_shinyoutput` <- `$.hs_shinyoutput`

#' @export
`[.hs_shinyoutput` <- function(x, i) rlang::abort("Can't index shinyoutput with `[`.")

#' @export
`[<-.hs_shinyoutput` <- function(x, i, value) rlang::abort("Can't index shinyoutput with `[`.")

# An upload in progress: files posted to session/<token>/upload/<job>.
UploadJob <- R6::R6Class("HsUploadJob",
  cloneable = FALSE,
  public = list(
    dir = NULL,
    pending = NULL,
    files = NULL,
    initialize = function(dir, file_infos) {
      self$dir <- dir
      self$pending <- file_infos
      self$files <- data.frame(name = character(), size = numeric(), type = character(),
                               datapath = character(), stringsAsFactors = FALSE)
    },
    receive = function(req) {
      if (length(self$pending) < 1) stop("Unexpected file in upload")
      info <- self$pending[[1]]
      self$pending <- self$pending[-1]
      base <- basename(info$name)
      ext <- tools::file_ext(base)
      path <- file.path(self$dir, paste0(nrow(self$files), if (nzchar(ext)) paste0(".", ext)))
      con <- file(path, open = "wb")
      on.exit(close(con), add = TRUE)
      input <- req$rook.input
      while (length(buf <- input$read(2^16)) > 0) writeBin(buf, con)
      self$files <- rbind(self$files, data.frame(
        name = base, size = info$size, type = info$type %||% "", datapath = path,
        stringsAsFactors = FALSE
      ))
    },
    finish = function() {
      if (length(self$pending) > 0) stop("File upload job was stopped prematurely")
      self$files
    }
  )
)

HotSession <- R6::R6Class("HotSession",
  inherit = ShinySessionBase,
  cloneable = FALSE,
  public = list(
    restoreContext = NULL,
    progressStack = NULL,
    input = NULL,
    output = NULL,
    clientData = NULL,
    token = NULL,
    files = NULL,
    downloads = NULL,
    closed = FALSE,
    request = NULL,
    singletons = character(0),
    userData = NULL,
    cache = NULL,
    user = NULL,
    groups = NULL,
    options = NULL,
    graph = NULL,
    app = NULL,
    hot = NULL,

    initialize = function(ws, app) {
      private$ws <- ws
      self$app <- app
      self$token <- random_id(16)
      self$graph <- HsGraph$new(paste0("session ", self$token))
      self$graph$set_recording(isTRUE(app$time_travel))
      self$hot <- new_hot_store()
      self$progressStack <- fastmap::faststack()
      self$files <- fastmap::fastmap()
      self$downloads <- fastmap::fastmap()
      self$userData <- new.env(parent = emptyenv())
      # Read the app state now, not the server's startup snapshot: rendering the
      # page records options there (bootstrapLib() stores the bslib theme), and
      # getCurrentTheme()/setCurrentTheme() inside the session rely on them.
      self$options <- shiny_internal("getCurrentAppState")()$options %||% app$options %||% list()
      self$cache <- cachem::cache_mem(max_size = 200 * 1024^2)
      self$request <- ws$request

      private$input_impl <- ReactiveValues$new(dedupe = FALSE, label = "input",
                                               graph = self$graph, is_input = TRUE)
      private$clientdata_impl <- ReactiveValues$new(dedupe = TRUE, label = "clientData",
                                                    graph = self$graph, is_input = TRUE)
      self$input <- new_reactivevalues(private$input_impl, readonly = TRUE)
      self$clientData <- new_reactivevalues(private$clientdata_impl, readonly = TRUE)
      self$output <- new_output_writer(self)

      private$outputs <- list()
      private$output_options <- list()
      private$values <- fastmap::fastmap()
      private$errors <- fastmap::fastmap()
      private$input_messages <- fastmap::fastqueue()
      private$cycle_queue <- fastmap::fastqueue()
      private$uploads <- fastmap::fastmap()
      private$upload_dir <- tempfile("hotshiny-upload-")
      private$cb <- list(
        closed = Callbacks$new(), flush = Callbacks$new(), flushed = Callbacks$new(),
        input = Callbacks$new(), error = Callbacks$new()
      )
      private$destroy_cbs <- list()
      private$test_mode <- isTRUE(app$test_mode)
      private$theme_dep <- shiny::withReactiveDomain(self, ReactiveVal$new(0, "theme counter"))
      if (private$test_mode) private$enable_test_snapshot()

      creds <- ws$request$HTTP_SHINY_SERVER_CREDENTIALS
      if (!is.null(creds)) {
        try({
          creds <- jsonlite::fromJSON(creds)
          self$user <- creds$user
          self$groups <- creds$groups
        }, silent = TRUE)
      }

      private$send(config = list(workerId = "", sessionId = self$token, user = self$user))
    },

    # -- scopes ------------------------------------------------------------------

    rootScope = function() self,

    ns = function(id) shiny::NS(NULL, id),

    makeScope = function(namespace) {
      ns <- shiny::NS(namespace)
      self_ns <- namespace
      bookmark_exclude <- character(0)
      root <- self
      shiny_internal("createSessionProxy")(self,
        input = new_reactivevalues(private$input_impl, readonly = TRUE, ns = ns),
        output = new_output_writer(self, ns = ns),
        sendInputMessage = function(inputId, message) root$sendInputMessage(ns(inputId), message),
        registerDataObj = function(name, data, filterFunc) root$registerDataObj(ns(name), data, filterFunc),
        ns = ns,
        makeScope = function(namespace) root$makeScope(ns(namespace)),
        setBookmarkExclude = function(names) bookmark_exclude <<- names,
        getBookmarkExclude = function() bookmark_exclude,
        onBookmark = function(fun) invisible(function() NULL),
        onBookmarked = function(fun) stop("onBookmarked() can't be used in a module."),
        onRestore = function(fun) invisible(function() NULL),
        onRestored = function(fun) invisible(function() NULL),
        exportTestValues = function(..., quoted_ = FALSE, env_ = parent.frame()) {
          dots <- if (quoted_) list(...) else eval(substitute(alist(...)))
          names(dots) <- ns(names(dots))
          do.call(root$exportTestValues, c(dots, quoted_ = TRUE, env_ = env_), quote = TRUE)
        },
        onDestroy = function(callback) root$.registerDestroy(self_ns, callback),
        destroy = function(namespace = NULL) {
          if (length(namespace) == 0) root$.destroyScope(self_ns) else root$.destroyScope(ns(namespace))
        }
      )
    },

    .registerDestroy = function(ns, callback) {
      key <- if (length(ns) == 0) "..root" else ns
      cbs <- private$destroy_cbs[[key]] %||% Callbacks$new()
      private$destroy_cbs[[key]] <- cbs
      cbs$register(callback)
    },

    .destroyScope = function(namespace) {
      prefix <- paste0(namespace, "-")
      keys <- names(private$destroy_cbs)
      for (k in keys[keys == namespace | startsWith(keys, prefix)]) {
        private$destroy_cbs[[k]]$invoke(onError = print_error)
        private$destroy_cbs[[k]] <- NULL
      }
      private$input_impl$destroyByPrefix(prefix)
      for (name in names(private$outputs)) {
        if (startsWith(name, prefix)) {
          private$outputs[[name]]$destroy()
          private$outputs[[name]] <- NULL
          private$values$remove(name)
          private$errors$remove(name)
        }
      }
      invisible(NULL)
    },

    onDestroy = function(callback) self$.registerDestroy(NULL, callback),

    destroy = function(namespace = NULL) {
      if (length(namespace) == 0) {
        stop("`$destroy()` cannot be called on the root session without a `namespace`.", call. = FALSE)
      }
      self$.destroyScope(namespace)
    },

    # -- lifecycle ---------------------------------------------------------------

    onSessionEnded = function(sessionEndedCallback) private$cb$closed$register(sessionEndedCallback),
    onEnded = function(endedCallback) self$onSessionEnded(endedCallback),
    onInputReceived = function(callback) private$cb$input$register(callback),
    onUnhandledError = function(callback) private$cb$error$register(callback),

    onFlush = function(flushCallback, once = TRUE) {
      private$register_once(private$cb$flush, flushCallback, once)
    },
    onFlushed = function(flushedCallback, once = TRUE) {
      private$register_once(private$cb$flushed, flushedCallback, once)
    },

    unhandledError = function(e, close = TRUE) {
      private$cb$error$invoke(e, onError = print_error)
      if (close) {
        message("Fatal error, closing session: ", conditionMessage(e))
        self$close()
      }
      invisible(NULL)
    },

    close = function() {
      if (!self$closed) private$ws$close()
      invisible(NULL)
    },

    wsClosed = function() {
      if (self$closed) return(invisible(NULL))
      self$closed <- TRUE
      for (o in private$outputs) o$suspend()
      shiny::withReactiveDomain(self, private$cb$closed$invoke(onError = print_error))
      unlink(private$upload_dir, recursive = TRUE)
      invisible(NULL)
    },

    isClosed = function() isTRUE(self$closed),
    isEnded = function() self$isClosed(),
    setShowcase = function(value) invisible(NULL),

    allowReconnect = function(value) {
      if (!(identical(value, TRUE) || identical(value, FALSE) || identical(value, "force"))) {
        stop('value must be TRUE, FALSE, or "force"')
      }
      private$send(allowReconnect = value)
    },

    reload = function() private$send(reload = TRUE),

    # -- reactive cycle ------------------------------------------------------------

    requestFlush = function() {
      self$app$request_flush(self)
      invisible(NULL)
    },

    cycleStartAction = function(callback) {
      private$cycle_queue$add(callback)
      if (private$busy == 0L) private$start_cycle()
      invisible(NULL)
    },

    incrementBusyCount = function() {
      if (private$busy == 0L) private$send(busy = "busy")
      private$busy <- private$busy + 1L
      invisible(NULL)
    },

    decrementBusyCount = function() {
      private$busy <- private$busy - 1L
      if (private$busy == 0L) {
        private$send(busy = "idle")
        self$requestFlush()
        later::later(function() {
          if (private$busy == 0L) private$start_cycle()
          request_service()
        })
      }
      invisible(NULL)
    },

    manageInputs = function(data, now = FALSE) {
      force(data)
      apply <- function() {
        private$cb$input$invoke(data)
        nms <- names(data)
        is_cd <- grepl("^\\.clientdata_", nms)
        private$input_impl$mset(data[nms[!is_cd]])
        cd <- data[nms[is_cd]]
        names(cd) <- sub("^\\.clientdata_", "", names(cd))
        private$clientdata_impl$mset(cd)
        self$manageHiddenOutputs()
      }
      if (isTRUE(now)) apply() else self$cycleStartAction(apply)
      invisible(NULL)
    },

    # Programmatic input change (used by session$setInputValue-like tools and
    # time-travel replay).
    setInputs = function(values) {
      private$input_impl$mset(values)
      self$requestFlush()
    },

    flushOutput = function() {
      if (private$busy > 0L) return(invisible(NULL))
      self$app$unrequest_flush(self)
      if (self$closed) return(invisible(NULL))
      shiny::withReactiveDomain(self, {
        private$cb$flush$invoke()
        on.exit(shiny::withReactiveDomain(self, private$cb$flushed$invoke()), add = TRUE)
        pending <- length(private$progress_keys) > 0 || private$values$size() > 0 ||
          private$errors$size() > 0 || private$input_messages$size() > 0
        if (!pending) {
          if (private$test_mode) private$send(values = structure(list(), names = character(0)))
          return(invisible(NULL))
        }
        private$progress_keys <- character(0)
        values <- private$values$as_list()
        private$values <- fastmap::fastmap()
        errors <- private$errors$as_list()
        private$errors <- fastmap::fastmap()
        input_messages <- private$input_messages$as_list()
        private$input_messages$reset()
        if (private$test_mode) private$store_output_values(c(values, errors))
        private$send(errors = errors, values = values, inputMessages = input_messages)
      })
      invisible(NULL)
    },

    # -- outputs -------------------------------------------------------------------

    defineOutput = function(name, func, label = NULL) {
      force(name)
      if (!is.null(private$outputs[[name]])) private$outputs[[name]]$destroy()
      if (is.null(func)) func <- function(...) shiny::req(FALSE)
      if (!is.function(func)) {
        rlang::abort(c(
          paste0("Unexpected ", class(func)[[1]], " object for output$", name),
          i = "Did you forget to use a render function?"
        ))
      }
      output_attrs <- attr(func, "outputAttrs", TRUE)
      output_attrs$renderFunc <- func
      render <- if (length(formals(func)) != 0) {
        orig <- func
        function() orig(name = name, shinysession = self)
      } else {
        func
      }

      obs <- Observer$new(function() {
        private$send(recalculating = list(name = name, status = "recalculating"))
        value <- tryCatch(
          private$with_current_output(name, render()),
          error = function(cond) private$classify_output_error(cond)
        )
        if (is_promise(value)) {
          self$incrementBusyCount()
          promises::finally(
            promises::then(value,
              onFulfilled = function(v) private$finish_output(name, v),
              onRejected = function(e) private$finish_output(name, private$classify_output_error(e))
            ),
            function() self$decrementBusyCount()
          )
        } else {
          private$finish_output(name, value)
        }
        invisible(NULL)
      }, label = paste0("output$", name), suspended = private$should_suspend(name),
      domain = self, kind = "output", node_label = name)

      for (a in names(output_attrs)) attr(obs, a) <- output_attrs[[a]]
      obs$onInvalidate(function() self$showProgress(name))
      private$outputs[[name]] <- obs
      if (is.null(private$output_options[[name]])) private$output_options[[name]] <- list()
      invisible(NULL)
    },

    getOutput = function(name) {
      attr(private$outputs[[name]], "renderFunc", exact = TRUE)
    },

    outputNames = function() names(private$outputs),

    outputOptions = function(name, ...) {
      if (is.null(name)) return(private$output_options)
      if (!name %in% names(private$outputs)) stop(name, " is not in list of output objects")
      opts <- list(...)
      if (length(opts) == 0) return(private$output_options[[name]])
      valid <- c("suspendWhenHidden", "priority")
      for (o in names(opts)) {
        if (!o %in% valid) stop(o, " is not a valid option")
        private$output_options[[name]][[o]] <- opts[[o]]
      }
      if ("suspendWhenHidden" %in% names(opts)) self$manageHiddenOutputs(name)
      if ("priority" %in% names(opts)) private$outputs[[name]]$setPriority(opts[["priority"]])
      invisible(NULL)
    },

    manageHiddenOutputs = function(outputsToCheck = NULL) {
      for (name in outputsToCheck %||% names(private$outputs)) {
        o <- private$outputs[[name]]
        if (is.null(o)) next
        if (private$should_suspend(name)) o$suspend() else o$resume()
      }
      invisible(NULL)
    },

    showProgress = function(id, persistent = FALSE) {
      if (self$closed) return(invisible(NULL))
      if (!id %in% private$progress_keys) private$progress_keys <- c(private$progress_keys, id)
      self$sendProgress("binding", list(id = id, persistent = persistent))
    },

    getCurrentOutputInfo = function() {
      name <- private$current_output
      if (is.null(name)) return(NULL)
      if (!is.null(private$output_info[[name]])) return(private$output_info[[name]])
      info <- list(name = name)
      cd_names <- isolate(names(self$clientData))
      add <- function(prop, wrap = identity) {
        key <- paste0("output_", name, "_", prop)
        if (key %in% cd_names) {
          r <- NULL
          info[[prop]] <<- function() {
            if (is.null(r)) r <<- reactive(wrap(self$clientData[[key]]), label = key, domain = self)
            r()
          }
        }
      }
      css_colors <- function(x) htmltools::parseCssColors(x %||% "", mustWork = FALSE)
      add("width"); add("height")
      add("bg", css_colors); add("fg", css_colors); add("accent", css_colors)
      add("font")
      private$output_info[[name]] <- info
      info
    },

    freezeValue = function(x, name) {
      if (!inherits(x, "reactivevalues")) stop("x must be a reactivevalues object")
      impl <- .subset2(x, "impl")
      key <- .subset2(x, "ns")(name)
      is_input <- identical(impl, private$input_impl)
      impl$freeze(key, invalidate = is_input)
      if (is_input) private$send(frozen = list(ids = list(key)))
      self$onFlushed(function() impl$thaw(key))
    },

    # -- messages ------------------------------------------------------------------

    sendCustomMessage = function(type, message) {
      data <- list()
      data[[type]] <- message
      private$send(custom = data)
    },

    sendBinaryMessage = function(type, message) {
      bytes <- charToRaw(type)
      if (length(bytes) > 255) stop("'type' argument is too long")
      private$write(c(as.raw(length(bytes)), bytes, message))
    },

    sendInputMessage = function(inputId, message) {
      private$input_messages$add(list(id = inputId, message = message))
      self$requestFlush()
    },

    sendProgress = function(type, message) private$send(progress = list(type = type, message = message)),
    sendNotification = function(type, message) private$send(notification = list(type = type, message = message)),
    sendModal = function(type, message) private$send(modal = list(type = type, message = message)),

    sendInsertUI = function(selector, multiple, where, content) {
      private$send(`shiny-insert-ui` = list(selector = selector, multiple = multiple,
                                            where = where, content = content))
    },
    sendRemoveUI = function(selector, multiple) {
      private$send(`shiny-remove-ui` = list(selector = selector, multiple = multiple))
    },
    sendInsertTab = function(inputId, liTag, divTag, menuName, target, position, select) {
      private$send(`shiny-insert-tab` = list(inputId = inputId, liTag = liTag, divTag = divTag,
                                             menuName = menuName, target = target,
                                             position = position, select = select))
    },
    sendRemoveTab = function(inputId, target) {
      private$send(`shiny-remove-tab` = list(inputId = inputId, target = target))
    },
    sendChangeTabVisibility = function(inputId, target, type) {
      private$send(`shiny-change-tab-visibility` = list(inputId = inputId, target = target, type = type))
    },
    updateQueryString = function(queryString, mode) {
      private$send(updateQueryString = list(queryString = queryString, mode = mode))
    },
    resetBrush = function(brushId) private$send(resetBrush = list(brushId = brushId)),

    # Raw message, used by hotShiny's dev tooling (hot reload).
    sendRaw = function(...) private$send(...),

    dispatch = function(msg) {
      method <- msg$method
      handler <- switch(method,
        uploadInit = private$upload_init,
        uploadEnd = private$upload_end,
        NULL
      )
      if (is.null(handler)) {
        private$send_error_response(msg, paste("Unknown method", method))
        return(invisible(NULL))
      }
      value <- try(do.call(handler, as.list(append(msg$args, msg$blobs))), silent = TRUE)
      if (inherits(value, "try-error")) {
        private$send_error_response(msg, conditionMessage(attr(value, "condition")))
      } else if (!is.null(msg$tag)) {
        private$send(response = list(tag = msg$tag, value = value))
      }
      invisible(NULL)
    },

    # -- theming -------------------------------------------------------------------

    getCurrentTheme = function() {
      private$theme_dep$get()
      shiny::getCurrentTheme()
    },

    setCurrentTheme = function(theme) {
      if (!inherits(theme, "bs_theme")) {
        stop("`session$setCurrentTheme()` expects a `bslib::bs_theme()` object.", call. = FALSE)
      }
      shiny::withReactiveDomain(self, {
        current <- bslib::theme_version(shiny::getCurrentTheme())
        nxt <- bslib::theme_version(theme)
        if (!identical(current, nxt)) {
          stop("session$setCurrentTheme() cannot be used to change the Bootstrap version from ",
               current, " to ", nxt, ".", call. = FALSE)
        }
        shiny::shinyOptions(bootstrapTheme = theme)
        private$theme_dep$set(isolate(private$theme_dep$get()) + 1)
        funcs <- shiny::getShinyOption("themeDependencyFuncs", default = list())
        deps <- unlist(lapply(funcs, function(f) {
          d <- f(theme)
          if (length(d) == 0) return(NULL)
          if (inherits(d, "html_dependency")) list(d) else d
        }), recursive = FALSE)
        deps <- lapply(deps, function(d) {
          d$restyle <- TRUE
          d
        })
        if (length(deps)) shiny::insertUI(selector = "body", where = "afterEnd", ui = htmltools::tagList(deps))
      })
      invisible(NULL)
    },

    # -- HTTP ------------------------------------------------------------------------

    fileUrl = function(name, file, contentType = "application/octet-stream") {
      bytes <- file.info(file)$size
      if (is.na(bytes)) return(NULL)
      data <- readBin(file, "raw", n = bytes)
      paste0("data:", contentType, ";base64,", base64enc::base64encode(data))
    },

    registerDownload = function(name, filename, contentType, func) {
      self$downloads$set(name, list(filename = filename, contentType = contentType, func = func))
      sprintf("session/%s/download/%s?w=", utils::URLencode(self$token, TRUE),
              utils::URLencode(name, TRUE))
    },

    registerDataObj = function(name, data, filterFunc) {
      self$downloads$set(name, list(data = data, filter = filterFunc))
      sprintf("session/%s/dataobj/%s?w=&nonce=%s", utils::URLencode(self$token, TRUE),
              utils::URLencode(name, TRUE), random_id(8))
    },

    handleRequest = function(req) {
      sub <- req$PATH_INFO
      m <- regmatches(sub, regexec("^/([a-z]+)/([^?]*)", sub, ignore.case = TRUE))[[1]]
      if (length(m) == 0) return(http_response(400, "text/html", "<h1>Bad Request</h1>"))
      kind <- m[2]
      rest <- m[3]
      if (kind == "file") {
        f <- self$files$get(utils::URLdecode(rest))
        if (is.null(f)) return(http_response(404, "text/html", "<h1>Not Found</h1>"))
        return(http_response(200, f$contentType, f$data))
      }
      if (kind == "upload" && identical(req$REQUEST_METHOD, "POST")) {
        job <- private$uploads$get(rest)
        if (is.null(job)) return(http_response(404, "text/html", "<h1>Not Found</h1>"))
        job$receive(req)
        return(http_response(200, "text/plain", "OK"))
      }
      parts <- regmatches(rest, regexec("^([^/]+)(/[^/]+)?$", rest))[[1]]
      if (length(parts) == 0) return(http_response(404, "text/html", "<h1>Not Found</h1>"))
      obj_name <- utils::URLdecode(parts[2])
      obj <- self$downloads$get(obj_name)
      if (kind == "dataobj") {
        if (is.null(obj)) return(http_response(404, "text/html", "<h1>Not Found</h1>"))
        return(shiny::withReactiveDomain(self, obj$filter(obj$data, req)))
      }
      if (kind == "download") {
        if (is.null(obj)) return(http_response(404, "text/html", "<h1>Not Found</h1>"))
        return(private$serve_download(obj, obj_name, parts[3]))
      }
      http_response(404, "text/html", "<h1>Not Found</h1>")
    },

    # -- testing -----------------------------------------------------------------------

    exportTestValues = function(..., quoted_ = FALSE, env_ = parent.frame()) {
      if (!private$test_mode) return(invisible(NULL))
      dots <- if (quoted_) list(...) else eval(substitute(alist(...)))
      for (n in names(dots)) private$test_exports[[n]] <- list(expr = dots[[n]], env = env_)
      invisible(NULL)
    },

    getTestSnapshotUrl = function(input = TRUE, output = TRUE, export = TRUE, format = "json") {
      flag <- function(x) if (isTRUE(x)) "1" else if (isFALSE(x)) NULL else paste(x, collapse = ",")
      q <- c(input = flag(input), output = flag(output), export = flag(export), format = format)
      paste0(private$test_snapshot_url, "&", paste(names(q), q, sep = "=", collapse = "&"))
    },

    # Bookmarking is not supported; these keep apps that merely configure it running.
    setBookmarkExclude = function(names) private$bookmark_exclude <- names,
    getBookmarkExclude = function() private$bookmark_exclude,
    onBookmark = function(fun) invisible(function() NULL),
    onBookmarked = function(fun) invisible(function() NULL),
    onRestore = function(fun) invisible(function() NULL),
    onRestored = function(fun) invisible(function() NULL),
    doBookmark = function() invisible(NULL),
    reactlog = function(logEntry) invisible(NULL),

    # -- hot reload support ----------------------------------------------------------

    # Tear down everything the server function created, keeping inputs,
    # clientData, userData and the connection.
    .resetServer = function() {
      for (name in names(private$outputs)) private$outputs[[name]]$destroy()
      private$outputs <- list()
      private$output_options <- list()
      private$output_info <- list()
      private$values <- fastmap::fastmap()
      private$errors <- fastmap::fastmap()
      for (k in names(private$destroy_cbs)) private$destroy_cbs[[k]]$invoke(onError = print_error)
      private$destroy_cbs <- list()
      invisible(NULL)
    },

    .inputValues = function() {
      keys <- private$input_impl$keys()
      stats::setNames(lapply(keys, private$input_impl$peek), keys)
    }
  ),

  private = list(
    ws = NULL,
    input_impl = NULL,
    clientdata_impl = NULL,
    outputs = NULL,
    output_options = NULL,
    output_info = list(),
    values = NULL,
    errors = NULL,
    input_messages = NULL,
    cycle_queue = NULL,
    busy = 0L,
    progress_keys = character(0),
    uploads = NULL,
    upload_dir = NULL,
    cb = NULL,
    destroy_cbs = NULL,
    current_output = NULL,
    theme_dep = NULL,
    bookmark_exclude = character(0),
    test_mode = FALSE,
    test_exports = list(),
    test_snapshot_url = NULL,
    output_values = list(),

    write = function(json) {
      if (self$closed) return(invisible(NULL))
      trace <- getOption("shiny.trace", FALSE)
      if (isTRUE(trace) || identical(trace, "send")) message("SEND ", json)
      private$ws$send(json)
      invisible(NULL)
    },

    send = function(...) {
      msg <- list(...)
      private$write(shiny_internal("toJSON")(msg))
    },

    send_error_response = function(msg, error) {
      if (is.null(msg$tag)) return(invisible(NULL))
      private$send(response = list(tag = msg$tag, error = error))
    },

    register_once = function(cbs, fn, once) {
      if (!isTRUE(once)) return(cbs$register(fn))
      dereg <- NULL
      dereg <- cbs$register(function() {
        dereg()
        fn()
      })
      dereg
    },

    start_cycle = function() {
      if (private$cycle_queue$size() > 0) {
        head <- private$cycle_queue$remove()
        on.exit({
          if (private$busy == 0L && private$cycle_queue$size() > 0L) {
            later::later(function() {
              if (private$busy == 0L) private$start_cycle()
              request_service()
            })
          }
        }, add = TRUE)
        shiny::withReactiveDomain(self, head())
      }
      invisible(NULL)
    },

    should_suspend = function(name) {
      hidden <- private$clientdata_impl$.values$get(paste0("output_", name, "_hidden"))
      if (is.null(hidden)) hidden <- TRUE
      hidden && isTRUE(private$output_options[[name]]$suspendWhenHidden %||% TRUE)
    },

    with_current_output = function(name, expr) {
      if (!is.null(private$current_output)) stop("Nested calls to withCurrentOutput() are not allowed.")
      promises::with_promise_domain(
        shiny_internal("createVarPromiseDomain")(private, "current_output", name),
        expr
      )
    },

    classify_output_error = function(cond) {
      if (inherits(cond, "shiny.custom.error")) {
        print_error(cond)
        return(structure(list(), class = "try-error", condition = cond))
      }
      if (inherits(cond, "shiny.output.cancel")) return(structure(list(), class = "cancel-output"))
      if (inherits(cond, "shiny.output.progress")) return(structure(list(), class = "progress-output"))
      if (rlang::cnd_inherits(cond, "shiny.silent.error")) {
        while (!inherits(cond, "shiny.silent.error")) cond <- cond$parent
        return(structure(list(), class = "try-error", condition = cond))
      }
      print_error(cond)
      if (isTRUE(getOption("shiny.sanitize.errors", FALSE))) {
        cond <- simpleError(paste("An error has occurred. Check your logs or contact the app",
                                  "author for clarification."))
      }
      self$unhandledError(cond, close = FALSE)
      structure(list(), class = "try-error", condition = cond)
    },

    finish_output = function(name, value) {
      self$requestFlush()
      if (inherits(value, "progress-output")) {
        self$showProgress(name, persistent = TRUE)
        private$errors$remove(name)
        private$values$remove(name)
        return(invisible(NULL))
      }
      private$send(recalculating = list(name = name, status = "recalculated"))
      if (inherits(value, "cancel-output")) return(invisible(NULL))
      private$errors$remove(name)
      private$values$remove(name)
      node <- private$outputs[[name]]$node
      if (inherits(value, "try-error")) {
        cond <- attr(value, "condition")
        type <- setdiff(class(cond), c("simpleError", "error", "condition"))
        private$errors$set(name, list(
          message = conditionMessage(cond),
          call = utils::capture.output(print(conditionCall(cond))),
          type = if (length(type)) type
        ))
        if (!is.null(node)) self$graph$end_run(node, "error", conditionMessage(cond))
      } else {
        private$values$set(name, value)
      }
      invisible(NULL)
    },

    serve_download = function(dl, name, suffix) {
      filename <- if (is.function(dl$filename)) {
        shiny::withReactiveDomain(self, isolate(dl$filename()))
      } else {
        dl$filename
      }
      if (!nzchar(suffix) && grepl("[^ -~]", filename)) {
        return(http_response(302, "text/html", "<h1>Found</h1>", c(
          Location = sprintf("%s/%s", utils::URLencode(name, TRUE), utils::URLencode(filename, TRUE)),
          `Cache-Control` = "no-cache"
        )))
      }
      ext <- tools::file_ext(filename)
      tmp <- tempfile(fileext = if (nzchar(ext)) paste0(".", ext) else "")
      finish <- function() {
        if (!file.exists(tmp)) return(http_response(404, "text/plain", "404 Not found"))
        disp <- if (!nzchar(suffix)) {
          paste0('attachment; filename="', gsub('(["\\\\])', "\\\\\\1", filename), '"')
        } else {
          "attachment"
        }
        http_response(200, dl$contentType %||% content_type(filename),
                      list(file = tmp, owned = TRUE),
                      c(`Content-Disposition` = disp, `Cache-Control` = "no-cache"))
      }
      self$incrementBusyCount()
      result <- tryCatch(
        shiny::withReactiveDomain(self, isolate(dl$func(tmp))),
        error = function(e) {
          self$decrementBusyCount()
          unlink(tmp)
          stop(e)
        }
      )
      if (is_promise(result)) {
        return(promises::finally(promises::then(result, function(...) finish()),
                                 function() self$decrementBusyCount()))
      }
      self$decrementBusyCount()
      finish()
    },

    upload_init = function(fileInfos) {
      max_size <- getOption("shiny.maxRequestSize", 5 * 1024 * 1024)
      fileInfos <- lapply(fileInfos, function(fi) {
        if (is.null(fi$type)) fi$type <- content_type(fi$name)
        fi
      })
      sizes <- vapply(fileInfos, function(fi) as.numeric(fi$size), numeric(1))
      if (max_size > 0 && any(sizes > max_size)) stop("Maximum upload size exceeded")
      id <- random_id(6)
      dir <- file.path(private$upload_dir, id)
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      private$uploads$set(id, UploadJob$new(dir, fileInfos))
      list(jobId = id, uploadUrl = paste0("session/", self$token, "/upload/", id, "?w="))
    },

    upload_end = function(jobId, inputId) {
      job <- private$uploads$get(jobId)
      if (is.null(job)) stop("Unknown upload job")
      private$uploads$remove(jobId)
      private$input_impl$set(inputId, job$finish())
      invisible(NULL)
    },

    enable_test_snapshot = function() {
      private$test_snapshot_url <- self$registerDataObj("shinytest", NULL, function(data, req) {
        params <- shiny::parseQueryString(req$QUERY_STRING)
        values <- list()
        if (!is.null(params$input)) {
          all <- isolate(shiny::reactiveValuesToList(self$input, all.names = TRUE))
          values$input <- if (params$input == "1") all else all[intersect(strsplit(params$input, ",")[[1]], names(all))]
        }
        if (!is.null(params$output)) {
          all <- private$output_values
          values$output <- if (params$output == "1") all else all[intersect(strsplit(params$output, ",")[[1]], names(all))]
        }
        if (!is.null(params$export)) {
          ex <- private$test_exports
          if (params$export != "1") ex <- ex[intersect(strsplit(params$export, ",")[[1]], names(ex))]
          values$export <- isolate(lapply(ex, function(item) eval(item$expr, envir = item$env)))
        }
        values <- lapply(values, function(v) v[order(names(v))])
        http_response(200, "application/json", shiny_internal("toJSON")(values, pretty = TRUE))
      })
    },

    store_output_values = function(values) {
      for (n in names(values)) private$output_values[[n]] <- values[[n]]
    }
  )
)

# Shiny's httpResponse, constructed without depending on its internals.
http_response <- function(status = 200L, content_type = "text/html; charset=UTF-8",
                          content = "", headers = list()) {
  shiny::httpResponse(status = status, content_type = content_type, content = content,
                      headers = headers)
}

content_type <- function(file, default = "application/octet-stream") {
  shiny_internal("getContentType")(file, default)
}
