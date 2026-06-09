################################################################################
### Create a small random-sampled FCS test dataset
### Run after package setup: source("scripts/create_test_data.R")
################################################################################

cells_per_file <- 500
random_seed <- 42

create_test_data <- function(project_dir = getwd(),
                             input_data_dir = file.path(project_dir, "data"),
                             input_metadata_dir = file.path(project_dir, "metadata"),
                             output_dir = file.path(project_dir, "example_data"),
                             cells_per_file = 500,
                             random_seed = 42) {
  if (!requireNamespace("flowCore", quietly = TRUE)) {
    stop(
      "Package 'flowCore' is required to sample FCS files.\n",
      "Open this project in RStudio and run source('scripts/setup_renv_core.R') first.",
      call. = FALSE
    )
  }

  input_data_dir <- normalizePath(input_data_dir, winslash = "/", mustWork = TRUE)
  input_metadata_dir <- normalizePath(input_metadata_dir, winslash = "/", mustWork = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)

  out_data_dir <- file.path(output_dir, "data")
  out_metadata_dir <- file.path(output_dir, "metadata")
  dir.create(out_data_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(out_metadata_dir, recursive = TRUE, showWarnings = FALSE)

  metadata_path <- file.path(input_metadata_dir, "sample.details.csv")
  if (!file.exists(metadata_path)) {
    stop("Metadata file not found: ", metadata_path, call. = FALSE)
  }

  sample_details <- utils::read.csv(metadata_path, check.names = FALSE)
  if (!"FileName" %in% names(sample_details)) {
    stop("sample.details.csv must contain a FileName column.", call. = FALSE)
  }

  marker_candidates <- c(
    file.path(input_metadata_dir, "ORIGINAL MARKERS.csv"),
    file.path(input_data_dir, "ORIGINAL MARKERS.csv")
  )
  marker_path <- marker_candidates[file.exists(marker_candidates)][1]
  if (is.na(marker_path)) {
    stop(
      "ORIGINAL MARKERS.csv was not found in metadata/ or data/.",
      call. = FALSE
    )
  }

  set.seed(random_seed)
  sampled_counts <- integer(nrow(sample_details))

  for (i in seq_len(nrow(sample_details))) {
    file_name <- as.character(sample_details$FileName[[i]])
    fcs_path <- file.path(input_data_dir, file_name)
    if (!file.exists(fcs_path)) {
      matches <- list.files(
        input_data_dir,
        pattern = "\\.fcs$",
        full.names = TRUE,
        ignore.case = TRUE
      )
      matches <- matches[tolower(basename(matches)) == tolower(file_name)]
      if (length(matches) == 0) {
        stop("FCS file listed in metadata was not found: ", file_name, call. = FALSE)
      }
      fcs_path <- matches[[1]]
    }

    message("Sampling ", basename(fcs_path))
    frame <- flowCore::read.FCS(
      fcs_path,
      transformation = FALSE,
      truncate_max_range = FALSE
    )
    n_cells <- nrow(flowCore::exprs(frame))
    keep_n <- min(as.integer(cells_per_file), n_cells)
    keep_idx <- sort(sample.int(n_cells, keep_n))
    sampled_frame <- frame[keep_idx, ]

    out_path <- file.path(out_data_dir, basename(fcs_path))
    flowCore::write.FCS(sampled_frame, filename = out_path, what = "numeric")
    sampled_counts[[i]] <- keep_n
  }

  count_cols <- intersect(
    c("Cells per sample", "Cells.per.sample", "Cells_per_sample"),
    names(sample_details)
  )
  if (length(count_cols) == 0) {
    sample_details[["Cells per sample"]] <- sampled_counts
  } else {
    sample_details[[count_cols[[1]]]] <- sampled_counts
  }

  utils::write.csv(
    sample_details,
    file = file.path(out_metadata_dir, "sample.details.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  file.copy(
    marker_path,
    file.path(out_metadata_dir, "ORIGINAL MARKERS.csv"),
    overwrite = TRUE
  )

  message("Wrote example dataset to: ", output_dir)
  invisible(output_dir)
}

create_test_data(
  cells_per_file = cells_per_file,
  random_seed = random_seed
)
