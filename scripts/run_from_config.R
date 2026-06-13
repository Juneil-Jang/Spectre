################################################################################
### Run Spectre from config.xlsx
### This is the no-code entry point used by RUN_WINDOWS.bat and RUN_MAC.command.
################################################################################

spectre_find_project_dir <- function(config_path = NULL) {
  if (!is.null(config_path) && nzchar(config_path)) {
    return(dirname(normalizePath(config_path, winslash = "/", mustWork = FALSE)))
  }

  frame_paths <- vapply(sys.frames(), function(frame) {
    path <- frame$ofile
    if (is.null(path)) NA_character_ else path
  }, character(1))
  frame_paths <- frame_paths[!is.na(frame_paths)]

  if (length(frame_paths) > 0) {
    return(dirname(dirname(normalizePath(frame_paths[[length(frame_paths)]], winslash = "/", mustWork = FALSE))))
  }

  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

spectre_find_script_path <- function() {
  frame_paths <- vapply(sys.frames(), function(frame) {
    path <- frame$ofile
    if (is.null(path)) NA_character_ else path
  }, character(1))
  frame_paths <- frame_paths[!is.na(frame_paths)]

  if (length(frame_paths) > 0) {
    return(normalizePath(frame_paths[[length(frame_paths)]], winslash = "/", mustWork = FALSE))
  }

  NA_character_
}

spectre_find_pipeline_dir <- function(pipeline_arg = NULL, config_dir = NULL) {
  candidates <- character(0)

  if (!is.null(pipeline_arg) && nzchar(pipeline_arg)) {
    candidates <- c(candidates, pipeline_arg)
  }

  env_pipeline <- Sys.getenv("SPECTRE_PIPELINE_DIR", unset = "")
  if (nzchar(env_pipeline)) {
    candidates <- c(candidates, env_pipeline)
  }

  script_path <- spectre_find_script_path()
  if (!is.na(script_path) && nzchar(script_path)) {
    candidates <- c(candidates, dirname(dirname(script_path)))
  }

  if (!is.null(config_dir) && nzchar(config_dir)) {
    candidates <- c(candidates, config_dir)
  }

  for (candidate in candidates) {
    candidate <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
    if (
      file.exists(file.path(candidate, "renv", "activate.R")) &&
      file.exists(file.path(candidate, "scripts", "run_spectre_unified.R"))
    ) {
      return(candidate)
    }
  }

  stop(
    "Could not find the Spectre pipeline folder. ",
    "Use the generated experiment runner or pass the pipeline folder as the second argument.",
    call. = FALSE
  )
}

spectre_blank <- function(x) {
  length(x) == 0 || is.na(x) || !nzchar(trimws(as.character(x)))
}

spectre_value <- function(values, name, default = NULL) {
  if (!name %in% names(values) || spectre_blank(values[[name]])) {
    return(default)
  }
  trimws(as.character(values[[name]]))
}

spectre_bool <- function(values, name, default = FALSE) {
  raw <- spectre_value(values, name, NULL)
  if (is.null(raw)) {
    return(default)
  }

  x <- tolower(trimws(raw))
  if (x %in% c("true", "t", "yes", "y", "1")) {
    return(TRUE)
  }
  if (x %in% c("false", "f", "no", "n", "0")) {
    return(FALSE)
  }

  stop("Setting '", name, "' must be TRUE/FALSE or YES/NO.", call. = FALSE)
}

spectre_int <- function(values, name, default = NULL, nullable = FALSE) {
  raw <- spectre_value(values, name, NULL)
  if (is.null(raw)) {
    if (nullable) {
      return(NULL)
    }
    return(as.integer(default))
  }

  out <- suppressWarnings(as.integer(raw))
  if (is.na(out)) {
    stop("Setting '", name, "' must be an integer.", call. = FALSE)
  }
  out
}

spectre_number <- function(values, name, default = NULL) {
  raw <- spectre_value(values, name, NULL)
  if (is.null(raw)) {
    return(default)
  }

  out <- suppressWarnings(as.numeric(raw))
  if (is.na(out)) {
    stop("Setting '", name, "' must be numeric.", call. = FALSE)
  }
  out
}

spectre_vector <- function(values, name) {
  raw <- spectre_value(values, name, NULL)
  if (is.null(raw)) {
    return(character(0))
  }

  out <- unlist(strsplit(raw, "[,;\\n]+"))
  out <- trimws(out)
  out[nzchar(out)]
}

spectre_filters <- function(values, name) {
  raw <- spectre_value(values, name, NULL)
  if (is.null(raw)) {
    return(character(0))
  }

  out <- unlist(strsplit(raw, "[;\\n]+"))
  out <- trimws(out)
  out[nzchar(out)]
}

spectre_qc_pairs <- function(values, name = "qc_plot_pairs") {
  raw <- spectre_value(values, name, NULL)
  if (is.null(raw)) {
    return(list(c("SSC-A", "FSC-A"), c("FSC-H", "FSC-A")))
  }

  pairs <- unlist(strsplit(raw, "[;\\n]+"))
  pairs <- trimws(pairs)
  pairs <- pairs[nzchar(pairs)]
  lapply(pairs, function(pair) {
    cols <- trimws(unlist(strsplit(pair, "\\|")))
    if (length(cols) < 2 || any(!nzchar(cols[1:2]))) {
      stop("Setting '", name, "' must use pairs like SSC-A|FSC-A.", call. = FALSE)
    }
    cols[1:2]
  })
}

spectre_activate_project <- function(pipeline_dir) {
  activate_script <- file.path(pipeline_dir, "renv", "activate.R")
  if (!file.exists(activate_script)) {
    stop(
      "renv/activate.R was not found in the Spectre pipeline folder. ",
      "Please run SETUP first or restore the project files.",
      call. = FALSE
    )
  }

  Sys.setenv(
    RENV_CONFIG_CONSENT = "TRUE",
    RENV_CONFIG_SYNCHRONIZED_CHECK = "FALSE"
  )

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(pipeline_dir)

  tryCatch(
    source(activate_script),
    error = function(e) {
      stop(
        "Could not activate the project R environment.\n",
        "Please run SETUP_WINDOWS.bat or SETUP_MAC.command first.\n",
        "Original error: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

spectre_read_config <- function(config_path) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop(
      "Package 'openxlsx' is required to read config.xlsx.\n",
      "Please run SETUP_WINDOWS.bat or SETUP_MAC.command first.",
      call. = FALSE
    )
  }

  dat <- tryCatch(
    openxlsx::read.xlsx(config_path, sheet = "Settings", detectDates = FALSE),
    error = function(e) {
      stop("Could not read the Settings sheet in config.xlsx: ", conditionMessage(e), call. = FALSE)
    }
  )

  names(dat) <- tolower(gsub("[^A-Za-z0-9]+", "_", names(dat)))
  if (!all(c("setting", "value") %in% names(dat))) {
    stop("config.xlsx must contain a Settings sheet with Setting and Value columns.", call. = FALSE)
  }

  dat <- dat[!is.na(dat$setting) & nzchar(trimws(as.character(dat$setting))), , drop = FALSE]
  values <- as.character(dat$value)
  names(values) <- trimws(as.character(dat$setting))
  values
}

spectre_build_settings <- function(values, project_dir, pipeline_dir = project_dir) {
  use_example <- spectre_bool(values, "use_example_data", default = TRUE)

  settings <- list(
    project_dir = project_dir,
    data_dir = spectre_value(values, "data_dir", "data"),
    metadata_dir = spectre_value(values, "metadata_dir", "metadata"),
    output_dir = spectre_value(values, "output_dir", "results"),
    metadata_file = spectre_value(values, "metadata_file", "sample.details.csv"),
    marker_file = spectre_value(values, "marker_file", "ORIGINAL MARKERS.csv"),
    meta_columns = c(
      sample = spectre_value(values, "sample_column", "Sample"),
      group = spectre_value(values, "group_column", "Group"),
      batch = spectre_value(values, "batch_column", "Batch"),
      donor = spectre_value(values, "donor_column", "Donor")
    ),
    phenok = spectre_int(values, "phenok", default = 100),
    flow_type = tolower(spectre_value(values, "flow_type", "aurora")),
    cofactor = spectre_number(values, "cofactor", default = 2000),
    random_seed = spectre_int(values, "random_seed", default = 42),
    umap_cells = spectre_int(values, "umap_cells", default = 100000),
    batch_align = spectre_bool(values, "batch_align", default = FALSE),
    batch_controls = spectre_vector(values, "batch_controls"),
    exclude_batch_controls_after_alignment = spectre_bool(
      values,
      "exclude_batch_controls_after_alignment",
      default = TRUE
    ),
    pre_batch_filters = spectre_filters(values, "pre_batch_filters"),
    analysis_filters = spectre_filters(values, "analysis_filters"),
    balance_samples = spectre_bool(values, "balance_samples", default = FALSE),
    cells_per_sample = spectre_int(values, "cells_per_sample", default = NULL, nullable = TRUE),
    clustering_markers = spectre_vector(values, "clustering_markers"),
    plot_against = spectre_value(values, "plot_against", "CD45RO_asinh"),
    qc_plots = spectre_qc_pairs(values),
    do_qc_plots = spectre_bool(values, "do_qc_plots", default = TRUE),
    do_marker_umaps = spectre_bool(values, "do_marker_umaps", default = TRUE),
    do_proportion_plots = spectre_bool(values, "do_proportion_plots", default = TRUE),
    do_pdf_plots = spectre_bool(values, "do_pdf_plots", default = TRUE),
    do_summary = spectre_bool(values, "do_summary", default = TRUE),
    do_fcs_export = spectre_bool(values, "do_fcs_export", default = TRUE),
    reuse_existing = spectre_bool(values, "reuse_existing", default = FALSE)
  )

  if (use_example) {
    settings$data_dir <- file.path(pipeline_dir, "example_data", "data")
    settings$metadata_dir <- file.path(pipeline_dir, "example_data", "metadata")
    settings$output_dir <- file.path(project_dir, "example_results")
    settings$phenok <- min(settings$phenok, 10)
    settings$umap_cells <- min(settings$umap_cells, 2000)
    settings$do_fcs_export <- FALSE
  }

  settings
}

spectre_preflight <- function(cfg) {
  problems <- character(0)

  if (!dir.exists(cfg$data_dir)) {
    problems <- c(problems, paste0("Data folder not found: ", cfg$data_dir))
  }
  if (!dir.exists(cfg$metadata_dir)) {
    problems <- c(problems, paste0("Metadata folder not found: ", cfg$metadata_dir))
  }

  fcs_files <- character(0)
  if (dir.exists(cfg$data_dir)) {
    fcs_files <- list.files(cfg$data_dir, pattern = "\\.fcs$", ignore.case = TRUE)
    if (length(fcs_files) == 0) {
      problems <- c(problems, paste0("No .fcs files found in: ", cfg$data_dir))
    }
  }

  meta_path <- file.path(cfg$metadata_dir, cfg$metadata_file)
  meta <- NULL
  if (!file.exists(meta_path)) {
    problems <- c(problems, paste0("Metadata file not found: ", meta_path))
  } else {
    meta <- tryCatch(
      utils::read.csv(meta_path, check.names = FALSE),
      error = function(e) {
        problems <<- c(problems, paste0("Could not read metadata file: ", conditionMessage(e)))
        NULL
      }
    )
  }

  if (!is.null(meta)) {
    required_cols <- c("FileName", unname(cfg$meta_columns))
    missing_cols <- setdiff(required_cols, names(meta))
    if (length(missing_cols) > 0) {
      problems <- c(problems, paste0("Metadata is missing column(s): ", paste(missing_cols, collapse = ", ")))
    }

    if ("FileName" %in% names(meta) && length(fcs_files) > 0) {
      missing_files <- setdiff(tolower(meta$FileName), tolower(fcs_files))
      if (length(missing_files) > 0) {
        problems <- c(
          problems,
          paste0("FCS file(s) listed in metadata were not found: ", paste(meta$FileName[tolower(meta$FileName) %in% missing_files], collapse = ", "))
        )
      }
    }

    sample_col <- cfg$meta_columns[["sample"]]
    if (cfg$batch_mode == "reference" && sample_col %in% names(meta)) {
      missing_controls <- setdiff(cfg$batch_controls, unique(as.character(meta[[sample_col]])))
      if (length(missing_controls) > 0) {
        problems <- c(
          problems,
          paste0("Batch control sample(s) not found in metadata: ", paste(missing_controls, collapse = ", "))
        )
      }
    }
  }

  marker_path <- tryCatch(
    resolve_marker_path(cfg),
    error = function(e) {
      problems <<- c(problems, conditionMessage(e))
      NA_character_
    }
  )

  if (length(problems) > 0) {
    stop(
      "Preflight check failed. Please fix these item(s):\n- ",
      paste(problems, collapse = "\n- "),
      call. = FALSE
    )
  }

  message("Preflight check passed.")
  message("  FCS files: ", length(fcs_files))
  message("  Metadata: ", meta_path)
  message("  Markers: ", marker_path)
  invisible(TRUE)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  config_path <- if (length(args) > 0) args[[1]] else "config.xlsx"
  pipeline_arg <- if (length(args) > 1) args[[2]] else NULL
  project_dir <- spectre_find_project_dir(config_path)
  pipeline_dir <- spectre_find_pipeline_dir(pipeline_arg, project_dir)
  config_path <- normalizePath(config_path, winslash = "/", mustWork = FALSE)

  if (!file.exists(config_path)) {
    stop("config.xlsx was not found: ", config_path, call. = FALSE)
  }

  setwd(project_dir)
  spectre_activate_project(pipeline_dir)

  source(file.path(pipeline_dir, "scripts", "help_functions.R"))
  source(file.path(pipeline_dir, "scripts", "run_spectre_unified.R"))

  values <- spectre_read_config(config_path)
  settings <- spectre_build_settings(values, project_dir, pipeline_dir)
  cfg <- normalise_settings(settings)

  message("Starting Spectre pipeline from config.xlsx")
  message("Pipeline: ", pipeline_dir)
  message("Experiment: ", project_dir)
  message("Output: ", cfg$output_dir)

  spectre_preflight(cfg)
  run_spectre_unified(settings)
}

if (!identical(Sys.getenv("SPECTRE_CONFIG_RUNNER_NO_MAIN"), "TRUE")) {
  tryCatch(
    main(),
    error = function(e) {
      message("")
      message("Spectre run failed:")
      message(conditionMessage(e))
      quit(status = 1, save = "no")
    }
  )
}
