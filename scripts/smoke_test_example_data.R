################################################################################
### Smoke test for the bundled example dataset
### Run after setup: source("scripts/smoke_test_example_data.R")
################################################################################

project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

source(file.path(project_dir, "scripts", "help_functions.R"))
source(file.path(project_dir, "scripts", "run_spectre_unified.R"))

settings <- list(
  project_dir = project_dir,
  data_dir = "example_data/data",
  metadata_dir = "example_data/metadata",
  output_dir = "example_results_smoke",
  metadata_file = "sample.details.csv",
  marker_file = "ORIGINAL MARKERS.csv",
  phenok = 5,
  flow_type = "aurora",
  cofactor = 2000,
  random_seed = 42,
  umap_cells = 1000,
  batch_align = FALSE,
  balance_samples = FALSE,
  clustering_markers = NULL,
  do_qc_plots = FALSE,
  do_marker_umaps = FALSE,
  do_proportion_plots = TRUE,
  do_summary = TRUE,
  do_fcs_export = FALSE,
  reuse_existing = FALSE
)

run_spectre_unified(settings)
