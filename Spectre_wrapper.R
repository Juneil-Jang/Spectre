################################################################################
### Spectre Cytometry Analysis Wrapper
### Open this file in RStudio, edit only SETTINGS, then click Source.
################################################################################

find_project_dir <- function() {
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    active_path <- tryCatch(
      rstudioapi::getActiveDocumentContext()$path,
      error = function(e) ""
    )
    if (nzchar(active_path)) {
      return(dirname(normalizePath(active_path, winslash = "/", mustWork = FALSE)))
    }
  }

  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[[1]])
    return(dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)))
  }

  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

PROJECT_DIR <- find_project_dir()
setwd(PROJECT_DIR)

source(file.path(PROJECT_DIR, "scripts", "help_functions.R"))
source(file.path(PROJECT_DIR, "scripts", "run_spectre_unified.R"))

################################################################################
### SETTINGS
################################################################################

# Set TRUE to run the small bundled example dataset.
# Set FALSE to run your own files in data/ and metadata/.
use_example_data <- FALSE

settings <- list(
  project_dir = PROJECT_DIR,
  data_dir = if (use_example_data) "example_data/data" else "data",
  metadata_dir = if (use_example_data) "example_data/metadata" else "metadata",
  output_dir = if (use_example_data) "example_results" else "results",

  metadata_file = "sample.details.csv",
  marker_file = "ORIGINAL MARKERS.csv",

  meta_columns = c(
    sample = "Sample",
    group = "Group",
    batch = "Batch",
    donor = "Donor"
  ),

  phenok = if (use_example_data) 10 else 100,
  flow_type = "aurora",
  cofactor = 2000,
  random_seed = 42,
  umap_cells = if (use_example_data) 2000 else 100000,

  # Batch alignment modes:
  # 1. No batch alignment:
  #    batch_align = FALSE
  # 2. Alignment with named control samples:
  #    batch_align = TRUE
  #    batch_controls = c("Control_1", "Control_2")
  # 3. Alignment without controls, using all samples:
  #    batch_align = TRUE
  #    batch_controls = character(0)
  batch_align = FALSE,
  batch_controls = character(0),
  exclude_batch_controls_after_alignment = TRUE,

  # Optional filters. Use exact transformed column names.
  # Examples:
  # analysis_filters = c(
  #   "CD3_asinh > 1",
  #   "`FSC-H` > `FSC-A` * 0.85 & `FSC-H` < `FSC-A` * 1.15"
  # )
  pre_batch_filters = character(0),
  analysis_filters = character(0),

  # Optional equal downsampling across samples after filtering.
  balance_samples = FALSE,
  cells_per_sample = NULL,

  # NULL uses all transformed/aligned markers.
  # You may also provide marker names, transformed column names, or positions.
  clustering_markers = NULL,

  # Keep QC settings modest for everyday wet-lab runs.
  plot_against = "CD45RO_asinh",
  qc_plots = list(
    c("SSC-A", "FSC-A"),
    c("FSC-H", "FSC-A")
  ),

  do_qc_plots = TRUE,
  do_marker_umaps = TRUE,
  do_proportion_plots = TRUE,
  do_summary = TRUE,
  do_fcs_export = TRUE,
  reuse_existing = FALSE
)

result <- run_spectre_unified(settings)
