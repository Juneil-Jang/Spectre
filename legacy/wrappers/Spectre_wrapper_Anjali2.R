################################################################################
### Spectre Analysis Wrapper
### Edit only the SETTINGS block below, then run this file in RStudio.
################################################################################

find_this_script_dir <- function() {
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

PROJECT_DIR <- find_this_script_dir()
setwd(PROJECT_DIR)

source(file.path(PROJECT_DIR, "scripts", "help_functions.R"))
source(file.path(PROJECT_DIR, "scripts", "run_spectre_unified.R"))

# ==============================================================================
# SETTINGS
# ==============================================================================

settings <- list(
  project_dir = PROJECT_DIR,
  data_dir = "data",
  metadata_dir = "metadata",
  metadata_file = "sample.details.csv",
  marker_file = "ORIGINAL MARKERS.csv",

  # Metadata columns in sample.details.csv
  meta_columns = c(
    sample = "Sample",
    group = "Group",
    batch = "Batch",
    donor = "Donor"
  ),

  # Core analysis settings
  phenok = 100,
  flow_type = "aurora",      # cytof, aurora, or flow
  cofactor = 2000,           # defaults: cytof=5, aurora=2000, flow=200
  random_seed = 42,
  umap_cells = 100000,       # use fewer cells for faster UMAP plotting

  # Batch alignment:
  # - batch_align = FALSE: skip alignment
  # - batch_align = TRUE and batch_controls has sample names: use reference controls
  # - batch_align = TRUE and batch_controls = character(0): align using all samples
  batch_align = FALSE,
  batch_controls = character(0),
  exclude_batch_controls_after_alignment = TRUE,

  # Optional gating/filtering after transformation or alignment.
  # Use column names exactly as they appear after transformation.
  # Example:
  # analysis_filters = c(
  #   "CD3_asinh > 1.0",
  #   "`LIVE DEAD NIR-A_LiveDead_asinh` < 2.0",
  #   "`FSC-H` > `FSC-A` * 0.85 & `FSC-H` < `FSC-A` * 1.15"
  # )
  pre_batch_filters = character(0),
  analysis_filters = character(0),

  # Optional equal downsampling across samples after filtering.
  balance_samples = FALSE,
  cells_per_sample = NULL,   # NULL uses the smallest sample size

  # Optional clustering marker subset.
  # NULL uses all transformed/aligned markers.
  # Can be marker names, transformed column names, or numeric positions.
  clustering_markers = NULL,

  # Quick QC plots. Keep this short for wetlab-friendly runtimes.
  plot_against = "CD45RO_asinh",
  qc_plots = list(
    c("SSC-A", "FSC-A"),
    c("FSC-H", "FSC-A")
  ),

  # Outputs
  do_qc_plots = TRUE,
  do_marker_umaps = TRUE,
  do_summary = TRUE,
  do_fcs_export = TRUE,
  reuse_existing = FALSE
)

result <- run_spectre_unified(settings)
