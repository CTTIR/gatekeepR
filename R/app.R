# All review mutations and classifications use the public review APIs.

#' Launch the gatekeepR review application
#'
#' Review threshold, structure, disposition and state decisions in a local
#' Shiny session. Every change requires a reviewer and reason and appends a
#' ledger entry. A locked download uses one verified snapshot; subsequent
#' edits invalidate that download until a new snapshot is locked. Choosing
#' `REVIEWED` is an explicit human assessment, not automatic panel validation.
#'
#' @param review An existing [gk_review()] object.
#' @param cellspec A cellspec object or path used to build a review.
#' @param config A [gk_config()] used with cellspec.
#' @param workdir A saved review directory to resume, or a new checkpoint
#'   directory when supplying `review` or `cellspec`. Checkpoints are written
#'   only when Save checkpoint is clicked. Existing directories must be resumed
#'   with `workdir` alone, preventing replacement with an unrelated review.
#' @param export A verified export directory to inspect read-only.
#' @param reviewer Initial reviewer identifier; it can be changed in the app.
#' @param max_upload_mb Reserved compatibility option. There is no upload view.
#' @param allow_local_paths Allow `cellspec` to be a local path. Explicit
#'   `workdir` and `export` arguments are trusted host configuration; there are
#'   no browser-supplied local path inputs.
#' @param max_plot_points Maximum cells displayed in the map. The cell table
#'   shows at most 500 cells, or this limit if it is smaller.
#'   Display limits never change analysis, ledgers or exported rows.
#' @param ... Reserved application options.
#' @details
#' Review state is private to each browser session. When a checkpoint directory
#' is configured, only the first active browser session can save it. Separate
#' R processes are additionally protected by the checkpoint ownership rules in
#' [gk_save_review()]. The download is a gzip-compressed tar archive containing
#' a `review` directory that can be checked with [gk_verify_export()].
#' @return A shiny.appobj.
#' @family app
#' @export
gk_app <- function(review = NULL, cellspec = NULL, config = NULL, workdir = NULL,
                   export = NULL, reviewer = NULL, max_upload_mb = 2048,
                   allow_local_paths = FALSE, max_plot_points = 50000L, ...) {
  .gk_require("shiny", "gk_app")
  .gk_check_number(max_upload_mb, min = 1)
  .gk_check_flag(allow_local_paths)
  max_plot_points <- .gk_check_count(max_plot_points, min = 1L)
  if (!is.null(reviewer)) .gk_check_string(reviewer)
  if (sum(!vapply(list(review, cellspec, export), is.null, logical(1))) > 1L ||
      (!is.null(export) && !is.null(workdir))) {
    .gk_abort("Supply one review source: review, cellspec, workdir or export.", class = "input")
  }
  if (!is.null(workdir)) {
    .gk_check_string(workdir)
    if ((!is.null(review) || !is.null(cellspec)) && file.exists(workdir)) {
      .gk_abort("An existing workdir must be resumed with workdir alone; use a new directory for this review.", class = "input")
    }
    if (is.null(review) && is.null(cellspec)) review <- gk_load_review(workdir)
    workdir <- .gk_review_path(workdir)
  }
  if (!is.null(export)) export <- gk_read_export(export)
  if (!is.null(review)) .gk_check_class(review, "gk_review")
  if (is.null(review) && !is.null(cellspec)) {
    if (is.character(cellspec) && !isTRUE(allow_local_paths)) {
      .gk_abort("Local paths are disabled; set allow_local_paths = TRUE.", class = "input")
    }
    .gk_check_class(config, "gk_config")
    prep <- gk_prepare(cellspec, config, quiet = TRUE)
    thresholds <- gk_thresholds(prep, config, seed = 5420L)
    classification <- gk_classify(prep, thresholds, config)
    states <- gk_state_calls(prep, thresholds, classification, config)
    structures <- gk_structures(classification, prep)
    review <- gk_review(classification, states, structures, thresholds, prep)
  }
  editable <- !is.null(review) && !isTRUE(review$locked)
  loaded <- !is.null(review) || !is.null(export)
  images <- if (!is.null(review)) unique(review$prepared$cells$image_id) else
    if (!is.null(export)) unique(export$cells$image_id) else character()
  panel <- if (!is.null(review)) review$config$panel$markers else NULL
  identity_markers <- panel$marker[panel$role %in% c("identity", "conditional_identity")]
  state_markers <- panel$marker[panel$role == "state"]
  bbox_inputs <- function(prefix) shiny::fluidRow(
    shiny::column(3, shiny::numericInput(paste0(prefix, "_xmin"), "X minimum", 0)),
    shiny::column(3, shiny::numericInput(paste0(prefix, "_xmax"), "X maximum", 1)),
    shiny::column(3, shiny::numericInput(paste0(prefix, "_ymin"), "Y minimum", 0)),
    shiny::column(3, shiny::numericInput(paste0(prefix, "_ymax"), "Y maximum", 1))
  )
  checkpoint_owner <- NULL
  shiny::shinyApp(
    ui = shiny::fluidPage(
      shiny::titlePanel(shiny::tagList(.cttir_brand_logo(), "gatekeepR review"),
                       windowTitle = "gatekeepR"),
      if (!loaded) shiny::p("No review loaded. Supply a review, workdir, export, or cellspec."),
      if (!is.null(export)) shiny::p("Verified export: read-only inspection. No review decisions can be changed here."),
      if (!is.null(review) && !editable) shiny::p("This review is locked and is displayed read-only."),
      if (loaded) shiny::selectInput("image", "Image", choices = images),
      if (editable) shiny::fluidRow(
        shiny::column(4, shiny::textInput("reviewer", "Reviewer", value = reviewer %||% "")),
        shiny::column(8, shiny::textInput("reason", "Reason for the next decision", value = ""))
      ),
      shiny::textOutput("action_status"),
      shiny::tabsetPanel(
        shiny::tabPanel("Overview", shiny::verbatimTextOutput("overview"),
                        shiny::plotOutput("map", height = "450px")),
        shiny::tabPanel("Thresholds",
          if (!is.null(review)) shiny::selectInput("cut_marker", "Identity marker", choices = identity_markers),
          if (editable) shiny::tagList(
            shiny::numericInput("cut_estimate", "Threshold", value = 0),
            shiny::actionButton("set_cut", "Record threshold")),
          if (!is.null(review)) shiny::plotOutput("density", height = "300px"),
          shiny::tableOutput("thresholds")),
        shiny::tabPanel("Structures",
          if (editable) shiny::tagList(
            shiny::radioButtons("structure_mode", "Selection", c("Structure ID" = "ID", "Bounding box" = "BBOX"), inline = TRUE),
            shiny::conditionalPanel("input.structure_mode === 'ID'",
              shiny::selectInput("structure_id", "Structure", choices = character())),
            shiny::conditionalPanel("input.structure_mode === 'BBOX'", bbox_inputs("structure")),
            shiny::selectInput("structure_decision", "Decision", c("Unresolved", "Tumor", "Benign")),
            shiny::actionButton("set_structure", "Record structure decision")),
          shiny::tableOutput("structures")),
        shiny::tabPanel("Cells",
          if (editable) shiny::tagList(
            shiny::radioButtons("disposition_mode", "Selection", c("Cell ID" = "ID", "Bounding box" = "BBOX"), inline = TRUE),
            shiny::conditionalPanel("input.disposition_mode === 'ID'",
              shiny::selectizeInput("cell_id", "Cell", choices = character())),
            shiny::conditionalPanel("input.disposition_mode === 'BBOX'", bbox_inputs("disposition")),
            shiny::selectInput("disposition", "Disposition", c("EXCLUDE", "DELETE", "RESTORE")),
            shiny::p("Exclusions and deletions remain in the ledger; RESTORE returns selected cells to their base disposition."),
            shiny::actionButton("set_disposition", "Record disposition")),
          shiny::textOutput("cell_limit"), shiny::tableOutput("cells")),
        shiny::tabPanel("States",
          if (editable && length(state_markers)) shiny::tagList(
            shiny::selectInput("state_marker", "State marker", choices = state_markers),
            shiny::selectInput("state_parent", "Parent set", choices = character()),
            shiny::selectInput("state_action", "Action", c("SET_CUT", "ENABLE", "DISABLE")),
            shiny::conditionalPanel("input.state_action === 'SET_CUT'",
              shiny::numericInput("state_estimate", "State threshold", value = 0)),
            shiny::actionButton("set_state", "Record state decision")),
          shiny::p("State results below show at most the first 500 rows for the selected image."),
          shiny::tableOutput("states")),
        shiny::tabPanel("Ledger",
          if (editable) shiny::actionButton("revert", "Revert last decision"),
          shiny::p("Reverting adds a new ledger entry; earlier entries are retained. Showing up to 1,000 entries."),
          shiny::tableOutput("ledger")),
        shiny::tabPanel("Rules", shiny::tableOutput("rules")),
        shiny::tabPanel("Save and export",
          if (editable) shiny::tagList(
            if (!is.null(workdir)) shiny::tagList(
              shiny::p(paste("Checkpoint:", workdir)),
              shiny::actionButton("save_checkpoint", "Save checkpoint")) else
                shiny::p("No checkpoint directory is configured. Start gk_app with workdir to save and resume a review."),
            shiny::radioButtons("snapshot_status", "Snapshot status", choices = c("PENDING", "REVIEWED")),
            shiny::conditionalPanel("input.snapshot_status === 'REVIEWED'",
              shiny::checkboxInput("confirm_reviewed", "I have completed the review and intend to record REVIEWED status.", FALSE)),
            shiny::p("A status records your assessment; it does not validate a study-specific marker panel."),
            shiny::actionButton("lock_snapshot", "Lock current snapshot")),
          shiny::verbatimTextOutput("snapshot"), shiny::uiOutput("download_ui"))
      )
    ),
    server = function(input, output, session) {
      # A reopened browser starts from the latest checkpoint, not the app's
      # original in-memory review. Retain the revision used for conflict checks.
      initial_review <- if (editable && !is.null(workdir) &&
        file.exists(file.path(workdir, "review.rds"))) gk_load_review(workdir) else review
      current_review <- shiny::reactiveVal(initial_review)
      locked_snapshot <- shiny::reactiveVal(NULL)
      action_status <- shiny::reactiveVal("")
      if (editable && !is.null(workdir) && is.null(checkpoint_owner)) checkpoint_owner <<- session$token
      session$onSessionEnded(function() {
        if (identical(checkpoint_owner, session$token)) checkpoint_owner <<- NULL
      })
      effective <- shiny::reactive({
        if (!is.null(current_review())) gk_replay(current_review()) else NULL
      })
      current_cells <- shiny::reactive({
        if (!is.null(current_review())) effective()$cells else if (!is.null(export)) export$cells else data.frame()
      })
      for_image <- function(dat) {
        if (is.null(dat) || !nrow(dat)) return(data.frame())
        dat[dat$image_id == input$image, , drop = FALSE]
      }
      action <- function(fun, message) {
        tryCatch({
          if (!editable) .gk_abort("This view is read-only.", class = "locked")
          fun()
          shiny::removeNotification("decision-error", session = session)
          action_status(message)
        }, error = function(e) {
          action_status(paste("Decision not applied:", conditionMessage(e)))
          shiny::showNotification(conditionMessage(e), type = "error", duration = NULL,
            id = "decision-error", session = session)
        })
      }
      mutate_review <- function(fun, message) {
        action(function() {
          updated <- fun(current_review())
          # Validate replay before replacing the session's known-good state.
          gk_replay(updated)
          current_review(updated)
          locked_snapshot(NULL)
        }, paste(message, "Lock a new snapshot before downloading."))
      }
      get_bbox <- function(prefix) vapply(c("xmin", "xmax", "ymin", "ymax"),
        function(name) input[[paste0(prefix, "_", name)]], numeric(1))
      if (editable) {
        shiny::observeEvent(input$image, {
          dat <- review$prepared$cells
          ids <- dat$cell_id[dat$image_id == input$image]
          shiny::updateSelectizeInput(session, "cell_id", choices = ids,
                                      selected = utils::head(ids, 1L), server = TRUE)
          structures <- review$structures$structures
          choices <- structures$structure_id[structures$image_id == input$image]
          shiny::updateSelectInput(session, "structure_id", choices = choices)
        }, ignoreInit = FALSE)
        shiny::observeEvent(input$state_marker, {
          shiny::updateSelectInput(session, "state_parent", choices = review$config$panel$parents[[input$state_marker]])
        }, ignoreInit = FALSE)
        shiny::observeEvent(list(input$image, input$cut_marker), {
          if (is.null(input$cut_marker)) return()
          th <- effective()$thresholds
          row <- th[th$image_id == input$image & th$marker == input$cut_marker & is.na(th$parent), , drop = FALSE]
          if (nrow(row) && is.finite(row$estimate[1])) shiny::updateNumericInput(session, "cut_estimate", value = row$estimate[1])
        }, ignoreInit = FALSE)
        shiny::observeEvent(input$set_cut, mutate_review(function(rv) {
          gk_set_cut(rv, input$image, input$cut_marker, estimate = input$cut_estimate,
                     reviewer = input$reviewer, reason = input$reason)
        }, "Threshold recorded."))
        shiny::observeEvent(input$set_structure, mutate_review(function(rv) {
          gk_decide_structure(rv, input$image,
            structure_id = if (identical(input$structure_mode, "ID")) input$structure_id else NULL,
            bbox = if (identical(input$structure_mode, "BBOX")) get_bbox("structure") else NULL,
            decision = input$structure_decision, reviewer = input$reviewer, reason = input$reason)
        }, "Structure decision recorded."))
        shiny::observeEvent(input$set_disposition, mutate_review(function(rv) {
          gk_dispose(rv, input$image,
            cell_id = if (identical(input$disposition_mode, "ID")) input$cell_id else NULL,
            bbox = if (identical(input$disposition_mode, "BBOX")) get_bbox("disposition") else NULL,
            disposition = input$disposition, reviewer = input$reviewer, reason = input$reason)
        }, "Disposition recorded."))
        shiny::observeEvent(input$set_state, mutate_review(function(rv) {
          gk_set_state(rv, input$image, input$state_marker, input$state_parent,
            action = input$state_action,
            estimate = if (identical(input$state_action, "SET_CUT")) input$state_estimate else NULL,
            reviewer = input$reviewer, reason = input$reason)
        }, "State decision recorded."))
        shiny::observeEvent(input$revert, mutate_review(function(rv) {
          gk_revert_last(rv, reviewer = input$reviewer, reason = input$reason)
        }, "Last decision reverted."))
        shiny::observeEvent(input$save_checkpoint, action(function() {
          if (is.null(workdir)) .gk_abort("No checkpoint directory configured.", class = "input")
          if (!identical(checkpoint_owner, session$token))
            .gk_abort("Another browser session owns this checkpoint. Close that session and reopen this review before saving.", class = "lockfile")
          if (dir.exists(workdir) && is.null(current_review()$checkpoint_revision))
            .gk_abort("The checkpoint directory appeared after this session started. Reopen the app with workdir alone before saving.", class = "lockfile")
          saved <- gk_save_review(current_review(), workdir, overwrite = dir.exists(workdir))
          updated <- current_review()
          updated$checkpoint_revision <- attr(saved, "checkpoint_revision")
          updated$working_dir <- normalizePath(workdir, mustWork = TRUE)
          current_review(updated)
        }, "Checkpoint saved."))
        shiny::observeEvent(input$lock_snapshot, action(function() {
          if (identical(input$snapshot_status, "REVIEWED") && !isTRUE(input$confirm_reviewed))
            .gk_abort("Confirm the completed review before recording REVIEWED status.", class = "input")
          snap <- gk_lock(current_review(), reviewer = input$reviewer, status = input$snapshot_status)
          locked_snapshot(snap)
        }, "Snapshot locked. Later edits require a new snapshot."))
      }
      output$action_status <- shiny::renderText(action_status())
      output$overview <- shiny::renderPrint({
        if (!loaded) { cat("No review loaded.\n"); return(invisible(NULL)) }
        dat <- current_cells()
        cat("Mode:", if (editable) "Editable review" else "Read-only inspection", "\n")
        cat("Images:", length(unique(dat$image_id)), "\nCells:", nrow(dat), "\n")
        cat("Awaiting review:", sum(dat$pending_review %in% TRUE), "\n")
        cat("Included in analysis:", sum(dat$analysed %in% TRUE), "\n")
        logs <- if (!is.null(current_review())) gk_ledgers(current_review()) else export$ledgers
        cat("Ledger entries:", sum(vapply(logs, nrow, integer(1))), "\n")
        print(table(dat$cell_type, useNA = "ifany"))
      })
      output$map <- shiny::renderPlot({
        shiny::validate(shiny::need(loaded, "Load a review to view cell positions."),
                        shiny::need(requireNamespace("ggplot2", quietly = TRUE), "Install ggplot2 to view the optional cell map."))
        dat <- for_image(current_cells())
        shiny::validate(shiny::need(nrow(dat) > 0L, "No cells for this image."))
        shown <- utils::head(dat, max_plot_points)
        gk_plot_map(structure(list(cells = shown), class = "gk_replayed"), input$image) +
          ggplot2::labs(subtitle = paste("Displaying", nrow(shown), "of", nrow(dat), "cells; review and exports include all cells."))
      })
      output$cells <- shiny::renderTable(utils::head(for_image(current_cells()), min(500L, max_plot_points)))
      output$cell_limit <- shiny::renderText({
        n <- nrow(for_image(current_cells()))
        paste("Displaying", min(n, 500L, max_plot_points), "of", n, "cells for this image.")
      })
      output$thresholds <- shiny::renderTable({
        th <- if (!is.null(current_review())) effective()$thresholds else if (!is.null(export)) export$thresholds else NULL
        for_image(th)
      })
      output$density <- shiny::renderPlot({
        shiny::validate(shiny::need(!is.null(current_review()), "Density evidence is available in the editable review."),
          shiny::need(requireNamespace("ggplot2", quietly = TRUE), "Install ggplot2 to view optional density plots."),
          shiny::need(!is.null(input$cut_marker) && nzchar(input$cut_marker), "Select an identity marker."))
        gk_plot_density(effective()$thresholds, input$cut_marker, input$image)
      })
      output$structures <- shiny::renderTable({
        st <- if (!is.null(current_review())) current_review()$structures$structures else if (!is.null(export)) export$structures else NULL
        if (!is.null(st) && nrow(st)) {
          cells <- current_cells()
          st$current_decision <- vapply(seq_len(nrow(st)), function(i) {
            choices <- cells$structure_decision[cells$image_id == st$image_id[i] &
              !is.na(cells$structure_id) & cells$structure_id == st$structure_id[i]]
            choices <- unique(ifelse(is.na(choices), "Pending", choices))
            paste(sort(choices), collapse = ", ")
          }, character(1))
        }
        for_image(st)
      })
      output$states <- shiny::renderTable({
        st <- if (!is.null(current_review())) effective()$state_calls else if (!is.null(export)) export$state_calls else NULL
        utils::head(for_image(st), 500L)
      })
      output$rules <- shiny::renderTable({
        cfg <- if (!is.null(current_review())) current_review()$config else if (!is.null(export)) export$config else NULL
        if (is.null(cfg)) data.frame() else .gk_rule_table(cfg$hierarchy)
      })
      output$ledger <- shiny::renderTable({
        logs <- if (!is.null(current_review())) gk_ledgers(current_review()) else if (!is.null(export)) export$ledgers else list()
        .gk_app_ledger_table(logs)
      })
      output$snapshot <- shiny::renderPrint({
        snap <- if (!is.null(export)) export$snapshot else locked_snapshot()
        if (is.null(snap)) { cat("No current snapshot. Lock the current review before downloading.\n"); return(invisible(NULL)) }
        cat("Review ID:", snap$review_id, "\nStatus:", snap$status,
            "\nReviewer:", snap$reviewer, "\nLocked:", snap$locked_utc, "\n")
      })
      output$download_ui <- shiny::renderUI({
        if (!is.null(locked_snapshot())) shiny::downloadButton("download_snapshot", "Download verified snapshot (.tar.gz)")
      })
      output$download_snapshot <- shiny::downloadHandler(
        filename = function() paste0(locked_snapshot()$review_id, ".tar.gz"),
        contentType = "application/gzip",
        content = function(file) {
          snap <- shiny::isolate(locked_snapshot())
          if (is.null(snap)) .gk_abort("Lock the current review before downloading.", class = "locked")
          .gk_app_archive(snap, file)
        }
      )
    }
  )
}

.gk_app_ledger_table <- function(logs) {
  rows <- lapply(names(logs), function(name) {
    dat <- logs[[name]]
    if (!nrow(dat)) return(NULL)
    details <- intersect(c("marker", "parent", "new_estimate", "action", "decision",
      "disposition", "structure_id", "cell_id", "mode", "xmin", "xmax", "ymin", "ymax"), names(dat))
    decision <- vapply(seq_len(nrow(dat)), function(i) {
      values <- vapply(dat[i, details, drop = FALSE], as.character, character(1))
      values <- values[!is.na(values)]
      paste(paste(names(values), values, sep = "="), collapse = "; ")
    }, character(1))
    data.frame(ledger = name, dat[, c("order", "entry_id", "time_utc", "reviewer", "image_id", "reason", "reverts"), drop = FALSE],
      decision = decision, stringsAsFactors = FALSE)
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  utils::head(out[order(out$order), , drop = FALSE], 1000L)
}

.gk_app_archive <- function(snapshot, file) {
  .gk_check_class(snapshot, "gk_snapshot")
  .gk_check_string(file)
  file <- file.path(normalizePath(dirname(file), mustWork = TRUE), basename(file))
  stage <- tempfile("gatekeepR-download-")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  gk_export(snapshot, file.path(stage, "review"))
  gk_verify_export(file.path(stage, "review"), strict = TRUE)
  previous <- setwd(stage)
  on.exit(setwd(previous), add = TRUE, after = FALSE)
  utils::tar(file, files = "review", compression = "gzip", tar = "internal")
  invisible(file)
}
