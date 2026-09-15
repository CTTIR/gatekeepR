# A small review shell; all classification remains in gk_classify()/gk_replay().

#' Launch the gatekeepR review application
#'
#' @param review An existing gk_review() object.
#' @param cellspec A cellspec object or path used to build a review.
#' @param config A gk_config() used with cellspec.
#' @param workdir A saved review directory.
#' @param export A verified export directory to inspect.
#' @param reviewer Reviewer identifier shown in the app.
#' @param max_upload_mb Maximum upload size for a future upload view.
#' @param allow_local_paths Allow local path inputs.
#' @param max_plot_points Maximum points shown in map views.
#' @param ... Reserved application options.
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
  if (is.null(review) && !is.null(workdir)) review <- gk_load_review(workdir)
  if (is.null(review) && !is.null(export)) export <- gk_read_export(export)
  if (!is.null(review)) .gk_check_class(review, "gk_review")
  if (is.null(review) && !is.null(cellspec)) {
    if (is.character(cellspec) && !isTRUE(allow_local_paths)) {
      .gk_abort("Local paths are disabled; set allow_local_paths = TRUE.", class = "input")
    }
    .gk_check_class(config, "gk_config")
    prep <- gk_prepare(cellspec, config, quiet = TRUE)
    thresholds <- gk_thresholds(prep, config, seed = 5420L)
    classification <- suppressWarnings(gk_classify(prep, thresholds, config))
    states <- gk_state_calls(prep, thresholds, classification, config)
    structures <- gk_structures(classification, prep)
    review <- gk_review(classification, states, structures, thresholds, prep)
  }
  shiny::shinyApp(
    ui = shiny::fluidPage(
      shiny::titlePanel("gatekeepR review"),
      shiny::tabsetPanel(
        shiny::tabPanel("Overview", shiny::verbatimTextOutput("overview")),
        shiny::tabPanel("Cells", shiny::tableOutput("cells")),
        shiny::tabPanel("Rules", shiny::tableOutput("rules"))
      )
    ),
    server = function(input, output, session) {
      if (!is.null(review)) {
        effective <- shiny::reactive(gk_replay(review))
        output$overview <- shiny::renderPrint({
          print(review); print(effective())
          if (!is.null(reviewer)) cat("Reviewer:", reviewer, "\n")
        })
        output$cells <- shiny::renderTable({
          dat <- effective()$cells
          dat[seq_len(min(nrow(dat), max_plot_points)), , drop = FALSE]
        })
        output$rules <- shiny::renderTable(.gk_rule_table(review$config$hierarchy))
      } else if (!is.null(export)) {
        output$overview <- shiny::renderPrint(print(export$snapshot))
        output$cells <- shiny::renderTable(utils::head(export$cells, max_plot_points))
        output$rules <- shiny::renderTable(.gk_rule_table(export$config$hierarchy))
      } else {
        output$overview <- shiny::renderPrint(cat("No review loaded. Supply a review, workdir, export, or cellspec.\n"))
        output$cells <- shiny::renderTable(data.frame())
        output$rules <- shiny::renderTable(data.frame())
      }
    }
  )
}
