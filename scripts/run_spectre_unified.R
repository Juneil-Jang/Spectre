################################################################################
### Unified Spectre pipeline
### Supports both reference-control and no-reference batch alignment.
################################################################################

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

as_flag <- function(x) {
  isTRUE(x)
}

normalise_path <- function(path, base_dir = NULL) {
  if (is.null(path) || !nzchar(path)) {
    return(path)
  }
  if (!is.null(base_dir) && !grepl("^[A-Za-z]:|^/|^~", path)) {
    path <- file.path(base_dir, path)
  }
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  path
}

require_columns <- function(dat, cols, location) {
  missing_cols <- setdiff(cols, names(dat))
  if (length(missing_cols) > 0) {
    stop(
      "Missing column(s) in ", location, ": ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }
}

load_spectre_packages <- function() {
  packages <- c(
    "Spectre", "data.table", "dplyr", "FastPG", "CytoNorm",
    "flowCore", "stringr", "pheatmap", "RColorBrewer", "scales"
  )
  missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(
      "Missing R package(s): ", paste(missing_packages, collapse = ", "), "\n",
      "Open RStudio in this project and run renv::restore() first.",
      call. = FALSE
    )
  }

  suppressPackageStartupMessages({
    library(Spectre)
    library(data.table)
    library(dplyr)
    library(FastPG)
    library(CytoNorm)
    library(flowCore)
    library(stringr)
  })

  try(Spectre::package.check(), silent = TRUE)
  try(Spectre::package.load(), silent = TRUE)
}

normalise_meta_columns <- function(meta_columns) {
  defaults <- c(sample = "Sample", group = "Group", batch = "Batch", donor = "Donor")
  if (is.null(meta_columns)) {
    return(defaults)
  }

  meta_columns <- as.character(meta_columns)
  if (is.null(names(meta_columns)) || all(names(meta_columns) == "")) {
    names(meta_columns) <- names(defaults)[seq_along(meta_columns)]
  }

  for (nm in names(defaults)) {
    if (!nm %in% names(meta_columns)) {
      meta_columns <- c(meta_columns, stats::setNames(defaults[[nm]], nm))
    }
    if (is.na(meta_columns[[nm]]) || !nzchar(meta_columns[[nm]])) {
      meta_columns[[nm]] <- defaults[[nm]]
    }
  }

  meta_columns[names(defaults)]
}

standardise_setting_aliases <- function(settings) {
  aliases <- c(
    PrimaryDirectory = "project_dir",
    InputFolder = "data_dir",
    MetaFolder = "metadata_dir",
    metaFile = "metadata_file",
    markerFile = "marker_file",
    meta_col = "meta_columns",
    flowType = "flow_type",
    coFactor = "cofactor",
    do.batchAlign = "batch_align",
    ref.ctrls = "batch_controls",
    do.plot = "do_marker_umaps",
    do.summary = "do_summary",
    do.fcsExport = "do_fcs_export",
    do.Rerun = "reuse_existing",
    plot.against = "plot_against",
    subsample_size = "umap_cells"
  )

  for (old_name in names(aliases)) {
    new_name <- aliases[[old_name]]
    if (!is.null(settings[[old_name]]) && is.null(settings[[new_name]])) {
      settings[[new_name]] <- settings[[old_name]]
    }
  }

  settings
}

normalise_settings <- function(settings) {
  settings <- standardise_setting_aliases(settings)

  defaults <- list(
    project_dir = getwd(),
    data_dir = "data",
    metadata_dir = "metadata",
    output_dir = NULL,
    metadata_file = "sample.details.csv",
    marker_file = "ORIGINAL MARKERS.csv",
    meta_columns = c(sample = "Sample", group = "Group", batch = "Batch", donor = "Donor"),
    phenok = 100,
    flow_type = "aurora",
    cofactor = NULL,
    random_seed = 42,
    umap_cells = 100000,
    batch_align = FALSE,
    batch_mode = "auto",
    batch_controls = character(0),
    exclude_batch_controls_after_alignment = TRUE,
    pre_batch_filters = character(0),
    analysis_filters = character(0),
    balance_samples = FALSE,
    cells_per_sample = NULL,
    extra_transform_cols = character(0),
    clustering_markers = NULL,
    plot_against = NULL,
    qc_plots = list(),
    do_qc_plots = TRUE,
    do_marker_umaps = TRUE,
    do_summary = TRUE,
    do_fcs_export = TRUE,
    reuse_existing = FALSE
  )

  cfg <- utils::modifyList(defaults, settings)
  cfg$project_dir <- normalise_path(cfg$project_dir)
  cfg$data_dir <- normalise_path(cfg$data_dir, cfg$project_dir)
  cfg$metadata_dir <- normalise_path(cfg$metadata_dir, cfg$project_dir)
  cfg$output_dir <- normalise_path(cfg$output_dir %||% cfg$project_dir, cfg$project_dir)
  cfg$meta_columns <- normalise_meta_columns(cfg$meta_columns)
  cfg$flow_type <- tolower(cfg$flow_type)

  if (!cfg$flow_type %in% c("cytof", "aurora", "flow")) {
    stop("flow_type must be one of: cytof, aurora, flow.", call. = FALSE)
  }

  default_cofactor <- switch(cfg$flow_type, cytof = 5, aurora = 2000, flow = 200)
  cfg$cofactor <- cfg$cofactor %||% default_cofactor
  cfg$phenok <- as.integer(cfg$phenok)
  cfg$random_seed <- as.integer(cfg$random_seed)
  cfg$umap_cells <- cfg$umap_cells %||% Inf
  cfg$batch_controls <- as.character(cfg$batch_controls %||% character(0))
  cfg$pre_batch_filters <- as.character(cfg$pre_batch_filters %||% character(0))
  cfg$analysis_filters <- as.character(cfg$analysis_filters %||% character(0))
  cfg$extra_transform_cols <- as.character(cfg$extra_transform_cols %||% character(0))
  cfg$plot_against <- trimws(cfg$plot_against %||% "")
  if (!nzchar(cfg$plot_against)) {
    cfg$plot_against <- NULL
  }

  cfg$batch_mode <- tolower(gsub("-", "_", cfg$batch_mode %||% "auto"))
  allowed_batch_modes <- c("auto", "none", "reference", "all_samples", "all")
  if (!cfg$batch_mode %in% allowed_batch_modes) {
    stop("batch_mode must be auto, none, reference, or all_samples.", call. = FALSE)
  }
  if (cfg$batch_mode == "all") {
    cfg$batch_mode <- "all_samples"
  }

  if (!as_flag(cfg$batch_align)) {
    cfg$batch_mode <- "none"
  } else if (cfg$batch_mode == "auto") {
    cfg$batch_mode <- if (length(cfg$batch_controls) > 0) "reference" else "all_samples"
  }

  if (cfg$batch_mode == "reference" && length(cfg$batch_controls) == 0) {
    stop(
      "batch_mode is 'reference', but batch_controls is empty. ",
      "Add control sample names or set batch_mode = 'all_samples'.",
      call. = FALSE
    )
  }

  cfg
}

clean_channel_name <- function(x) {
  x <- toupper(as.character(x))
  x <- gsub("COMP[-_ ]?", "", x)
  x <- gsub("[^A-Z0-9]", "", x)
  x
}

clean_marker_name <- function(x) {
  x <- stringr::str_replace_all(as.character(x), "[^[:print:]]", "")
  stringr::str_trim(x)
}

find_channel_match <- function(target, data_channels) {
  if (is.na(target) || !nzchar(target)) {
    return(integer(0))
  }

  exact <- which(data_channels == target)
  if (length(exact) > 0) {
    return(exact[[1]])
  }

  prefix <- which(startsWith(data_channels, target) | startsWith(target, data_channels))
  if (length(prefix) > 0) {
    return(prefix[[1]])
  }

  contains <- which(grepl(target, data_channels, fixed = TRUE))
  if (length(contains) > 0) {
    return(contains[[1]])
  }

  integer(0)
}

read_marker_file <- function(marker_path) {
  if (!file.exists(marker_path)) {
    stop("Marker file not found: ", marker_path, call. = FALSE)
  }

  markers <- data.table::fread(marker_path, check.names = FALSE)
  if (ncol(markers) < 2) {
    stop("Marker file must have at least two columns: channel and marker.", call. = FALSE)
  }

  channel_col <- names(markers)[[1]]
  marker_col <- names(markers)[[2]]
  markers[[marker_col]] <- clean_marker_name(markers[[marker_col]])
  markers <- markers[!is.na(markers[[channel_col]]) & !is.na(markers[[marker_col]])]
  markers <- markers[nzchar(as.character(markers[[channel_col]])) & nzchar(as.character(markers[[marker_col]]))]

  list(data = markers, channel_col = channel_col, marker_col = marker_col)
}

read_input_data <- function(cfg) {
  fcs_files <- list.files(cfg$data_dir, pattern = "\\.fcs$", full.names = TRUE, ignore.case = TRUE)
  if (length(fcs_files) == 0) {
    stop("No .fcs files found in: ", cfg$data_dir, call. = FALSE)
  }
  if (!exists("read.cytofFiles", mode = "function")) {
    stop("read.cytofFiles() was not found. Source scripts/help_functions.R first.", call. = FALSE)
  }

  message(">>> Importing ", length(fcs_files), " FCS file(s)")
  data_list <- read.cytofFiles(
    file.loc = cfg$data_dir,
    file.type = ".fcs",
    do.embed.file.names = TRUE
  )
  cell_dat <- Spectre::do.merge.files(dat = data_list)
  rm(data_list)
  gc()
  data.table::as.data.table(cell_dat)
}

rename_marker_columns <- function(cell_dat, marker_info, out_dir) {
  markers <- marker_info$data
  channel_col <- marker_info$channel_col
  marker_col <- marker_info$marker_col

  csv_channels <- clean_channel_name(markers[[channel_col]])
  data_channels <- clean_channel_name(names(cell_dat))
  raw_marker_cols <- character(0)
  mapping <- data.table::data.table(
    channel = character(0),
    old_column = character(0),
    new_marker = character(0)
  )

  for (i in seq_len(nrow(markers))) {
    target <- csv_channels[[i]]
    marker <- as.character(markers[[marker_col]][[i]])
    idx <- find_channel_match(target, data_channels)

    if (length(idx) == 0) {
      warning(
        "Marker channel was not found in FCS data and will be skipped: ",
        markers[[channel_col]][[i]],
        call. = FALSE
      )
      next
    }

    old_name <- names(cell_dat)[[idx]]
    new_name <- marker
    if (new_name %in% setdiff(names(cell_dat), old_name)) {
      new_name <- make.unique(c(names(cell_dat), new_name), sep = "_")
      new_name <- new_name[[length(new_name)]]
      warning(
        "Duplicate marker name '", marker, "' renamed to '", new_name, "'.",
        call. = FALSE
      )
    }

    if (!identical(old_name, new_name)) {
      data.table::setnames(cell_dat, old_name, new_name)
    }
    raw_marker_cols <- c(raw_marker_cols, new_name)
    mapping <- data.table::rbindlist(
      list(
        mapping,
        data.table::data.table(
          channel = as.character(markers[[channel_col]][[i]]),
          old_column = old_name,
          new_marker = new_name
        )
      )
    )
  }

  raw_marker_cols <- unique(raw_marker_cols)
  if (length(raw_marker_cols) == 0) {
    stop("No marker columns matched between marker_file and FCS data.", call. = FALSE)
  }

  data.table::fwrite(mapping, file.path(out_dir, "marker_mapping.csv"))
  message(">>> Matched ", length(raw_marker_cols), " marker column(s)")

  list(data = cell_dat, marker_cols = raw_marker_cols, mapping = mapping)
}

add_metadata <- function(cell_dat, cfg) {
  meta_path <- file.path(cfg$metadata_dir, cfg$metadata_file)
  if (!file.exists(meta_path)) {
    stop("Metadata file not found: ", meta_path, call. = FALSE)
  }

  meta_dat <- data.table::fread(meta_path, check.names = FALSE)
  require_columns(meta_dat, c("FileName", unname(cfg$meta_columns)), "metadata")
  cell_dat <- do.add.cols(cell_dat, "FileName", meta_dat, "FileName", rmv.ext = TRUE)
  cell_dat <- data.table::as.data.table(cell_dat)
  list(data = cell_dat, metadata = meta_dat)
}

transform_markers <- function(cell_dat, marker_cols, cfg) {
  transform_cols <- unique(c(marker_cols, cfg$extra_transform_cols))
  missing_cols <- setdiff(transform_cols, names(cell_dat))
  if (length(missing_cols) > 0) {
    warning(
      "These requested transform columns were not found and will be skipped: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  transform_cols <- intersect(transform_cols, names(cell_dat))
  if (length(transform_cols) == 0) {
    stop("No columns are available for arcsinh transformation.", call. = FALSE)
  }

  numeric_cols <- vapply(cell_dat[, ..transform_cols], is.numeric, logical(1))
  if (!all(numeric_cols)) {
    stop(
      "Non-numeric transform column(s): ",
      paste(transform_cols[!numeric_cols], collapse = ", "),
      call. = FALSE
    )
  }

  message(">>> Applying arcsinh transformation with cofactor ", cfg$cofactor)
  cell_dat <- do.asinh(cell_dat, use.cols = transform_cols, cofactor = cfg$cofactor)
  transformed_cols <- paste0(transform_cols, "_asinh")
  transformed_cols <- transformed_cols[transformed_cols %in% names(cell_dat)]

  list(data = data.table::as.data.table(cell_dat), transformed_cols = transformed_cols)
}

evaluate_filters <- function(cell_dat, filters, label = "analysis") {
  if (length(filters) == 0) {
    return(cell_dat)
  }

  cell_dat <- data.table::as.data.table(cell_dat)
  for (i in seq_along(filters)) {
    filter_text <- filters[[i]]
    keep <- tryCatch(
      eval(parse(text = filter_text), envir = cell_dat, enclos = parent.frame()),
      error = function(e) {
        stop(
          "Could not evaluate ", label, " filter ", i, ": ", filter_text, "\n",
          e$message,
          call. = FALSE
        )
      }
    )

    if (!is.logical(keep) || length(keep) != nrow(cell_dat)) {
      stop(
        "Filter must return TRUE/FALSE for every row: ", filter_text,
        call. = FALSE
      )
    }

    keep[is.na(keep)] <- FALSE
    before <- nrow(cell_dat)
    cell_dat <- cell_dat[keep]
    message(">>> Filter ", i, " kept ", nrow(cell_dat), " / ", before, " cells: ", filter_text)

    if (nrow(cell_dat) == 0) {
      stop("All cells were removed by filter: ", filter_text, call. = FALSE)
    }
  }

  cell_dat
}

balance_by_sample <- function(cell_dat, sample_col, cfg) {
  if (!as_flag(cfg$balance_samples)) {
    return(cell_dat)
  }

  require_columns(cell_dat, sample_col, "cell data")
  counts <- cell_dat[, .N, by = sample_col]
  min_cells <- min(counts$N)
  target <- cfg$cells_per_sample %||% min_cells
  target <- min(as.integer(target), min_cells)

  if (target < 1) {
    stop("cells_per_sample must be at least 1.", call. = FALSE)
  }
  if (target < 500) {
    warning(
      "The smallest sample has fewer than 500 cells after filtering. ",
      "Consider reviewing QC filters or removing poor-quality samples.",
      call. = FALSE
    )
  }

  set.seed(cfg$random_seed)
  message(">>> Balancing every sample to ", target, " cells")
  cell_dat[, .SD[sample.int(.N, target)], by = sample_col]
}

subsample_for_umap <- function(cell_dat, max_cells, seed) {
  max_cells <- as.numeric(max_cells)
  if (!is.finite(max_cells) || nrow(cell_dat) <= max_cells) {
    return(data.table::copy(cell_dat))
  }

  set.seed(seed)
  idx <- sample.int(nrow(cell_dat), max_cells)
  message(">>> Subsampling ", max_cells, " cells for UMAP plotting")
  data.table::copy(cell_dat[idx])
}

safe_run_umap <- function(cell_dat, use_cols, max_cells, seed) {
  require_columns(cell_dat, use_cols, "cell data")
  plot_dat <- subsample_for_umap(cell_dat, max_cells, seed)
  run.umap(plot_dat, use.cols = use_cols)
}

make_colour_plot_safe <- function(dat, x_axis, y_axis = NULL, col_axis = NULL, path = NULL, ...) {
  needed <- c(x_axis, y_axis, col_axis)
  needed <- needed[!is.null(needed) & nzchar(needed)]
  missing_cols <- setdiff(needed, names(dat))
  if (length(missing_cols) > 0) {
    warning(
      "Skipping plot because column(s) were not found: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
    return(invisible(NULL))
  }

  args <- list(dat, x_axis)
  if (!is.null(y_axis)) {
    args[[length(args) + 1]] <- y_axis
  }
  if (!is.null(col_axis)) {
    args[[length(args) + 1]] <- col_axis
  }
  args <- c(args, list(...))
  if (!is.null(path)) {
    args$path <- path
  }
  do.call(make.colour.plot, args)
}

make_multi_plot_safe <- function(dat, plot_cols, group_col = NULL, path = NULL, ...) {
  needed <- c("UMAP_X", "UMAP_Y", plot_cols, group_col)
  missing_cols <- setdiff(needed, names(dat))
  if (length(missing_cols) > 0) {
    warning(
      "Skipping multi plot because column(s) were not found: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
    return(invisible(NULL))
  }

  args <- list(dat, "UMAP_X", "UMAP_Y", plot_cols)
  if (!is.null(group_col)) {
    args[[length(args) + 1]] <- group_col
  }
  args <- c(args, list(...))
  if (!is.null(path)) {
    args$path <- path
  }
  do.call(make.multi.plot, args)
}

make_qc_plots <- function(cell_dat, transformed_cols, cfg, out_dir) {
  if (!as_flag(cfg$do_qc_plots)) {
    return(invisible(NULL))
  }

  qc_dir <- ensure_dir(file.path(out_dir, "QC plots"))
  qc_dat <- subsample_for_umap(cell_dat, cfg$umap_cells, cfg$random_seed)

  if (!is.null(cfg$plot_against) && cfg$plot_against %in% names(qc_dat)) {
    for (marker in transformed_cols) {
      make_colour_plot_safe(
        qc_dat,
        x_axis = marker,
        y_axis = cfg$plot_against,
        col.min.threshold = 0,
        path = qc_dir,
        fast = TRUE
      )
    }
  }

  for (plot_pair in cfg$qc_plots) {
    if (length(plot_pair) >= 2) {
      make_colour_plot_safe(
        qc_dat,
        x_axis = plot_pair[[1]],
        y_axis = plot_pair[[2]],
        path = qc_dir,
        fast = TRUE
      )
    }
  }
}

prepare_cytonorm_model <- function(dat, cellular_cols, batch_col, sample_col, model_dir) {
  ensure_dir(model_dir)
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(model_dir)

  if (exists("run_with_fallback", mode = "function")) {
    run_with_fallback(
      expr_primary = quote(prep.cytonorm(
        dat = dat,
        cellular.cols = cellular_cols,
        cluster.cols = cellular_cols,
        batch.col = batch_col,
        sample.col = sample_col,
        xdim = 10,
        ydim = 10,
        meta.k = 5
      )),
      expr_fallback = quote(amshaw(
        dat = dat,
        cellular.cols = cellular_cols,
        cluster.cols = cellular_cols,
        batch.col = batch_col,
        sample.col = sample_col,
        xdim = 10,
        ydim = 10,
        meta.k = 5
      ))
    )
  } else {
    prep.cytonorm(
      dat = dat,
      cellular.cols = cellular_cols,
      cluster.cols = cellular_cols,
      batch.col = batch_col,
      sample.col = sample_col,
      xdim = 10,
      ydim = 10,
      meta.k = 5
    )
  }
}

run_batch_alignment <- function(cell_dat, transformed_cols, cfg, dirs) {
  sample_col <- cfg$meta_columns[["sample"]]
  group_col <- cfg$meta_columns[["group"]]
  batch_col <- cfg$meta_columns[["batch"]]
  donor_col <- cfg$meta_columns[["donor"]]

  require_columns(cell_dat, c(sample_col, group_col, batch_col, donor_col), "cell data")
  require_columns(cell_dat, transformed_cols, "cell data")

  if (cfg$batch_mode == "none") {
    return(list(data = cell_dat, analysis_cols = transformed_cols))
  }

  ensure_dir(dirs$out2)
  message(">>> Batch alignment mode: ", cfg$batch_mode)

  pre_dir <- ensure_dir(file.path(dirs$out2, "1 - pre-alignment plots"))
  pre_dat <- safe_run_umap(cell_dat, transformed_cols, cfg$umap_cells, cfg$random_seed)
  make_colour_plot_safe(pre_dat, "UMAP_X", "UMAP_Y", batch_col, col.type = "factor", filename = "Batches.png", path = pre_dir)
  make_colour_plot_safe(pre_dat, "UMAP_X", "UMAP_Y", group_col, col.type = "factor", filename = "Groups.png", path = pre_dir)
  make_colour_plot_safe(pre_dat, "UMAP_X", "UMAP_Y", donor_col, col.type = "factor", filename = "Donors.png", path = pre_dir)
  rm(pre_dat)
  gc()

  model_dat <- cell_dat
  reference_group <- NULL
  if (cfg$batch_mode == "reference") {
    missing_refs <- setdiff(cfg$batch_controls, unique(cell_dat[[sample_col]]))
    if (length(missing_refs) > 0) {
      stop(
        "These batch_controls were not found in metadata sample column: ",
        paste(missing_refs, collapse = ", "),
        call. = FALSE
      )
    }

    model_dat <- do.filter(cell_dat, use.col = sample_col, values = cfg$batch_controls)
    if (nrow(model_dat) == 0) {
      stop("Reference control filtering returned zero cells.", call. = FALSE)
    }

    ref_groups <- unique(model_dat[[group_col]])
    if (length(ref_groups) == 1) {
      reference_group <- ref_groups[[1]]
      message(">>> Reference control group: ", reference_group)
    }
  }

  model_dir <- ensure_dir(file.path(dirs$out2, "2 - cytonorm model"))
  cytnrm <- prepare_cytonorm_model(
    dat = model_dat,
    cellular_cols = transformed_cols,
    batch_col = batch_col,
    sample_col = sample_col,
    model_dir = model_dir
  )

  prep_plot_dir <- ensure_dir(file.path(dirs$out2, "3 - model QC plots"))
  prep_dat <- safe_run_umap(cytnrm$dt, transformed_cols, cfg$umap_cells, cfg$random_seed)
  make_colour_plot_safe(prep_dat, "UMAP_X", "UMAP_Y", "File", col.type = "factor", filename = "Model_batches.png", path = prep_plot_dir)
  make_colour_plot_safe(prep_dat, "UMAP_X", "UMAP_Y", "prep.fsom.metacluster", col.type = "factor", add.label = TRUE, filename = "Model_metaclusters.png", path = prep_plot_dir)
  rm(prep_dat)
  gc()

  message(">>> Training CytoNorm")
  cytnrm <- train.cytonorm(model = cytnrm, align.cols = transformed_cols)
  saveRDS(cytnrm, file.path(model_dir, "cytonorm_model.rds"))

  message(">>> Applying CytoNorm")
  cell_dat <- run.cytonorm(dat = cell_dat, model = cytnrm, batch.col = batch_col)
  cell_dat <- data.table::as.data.table(cell_dat)
  aligned_cols <- paste0(transformed_cols, "_aligned")
  require_columns(cell_dat, aligned_cols, "aligned cell data")

  aligned_plot_dir <- ensure_dir(file.path(dirs$out2, "4 - aligned plots"))
  aligned_plot_dat <- safe_run_umap(cell_dat, aligned_cols, cfg$umap_cells, cfg$random_seed)
  make_colour_plot_safe(aligned_plot_dat, "UMAP_X", "UMAP_Y", batch_col, col.type = "factor", filename = "Aligned_batches.png", path = aligned_plot_dir)
  make_colour_plot_safe(aligned_plot_dat, "UMAP_X", "UMAP_Y", group_col, col.type = "factor", filename = "Aligned_groups.png", path = aligned_plot_dir)
  make_colour_plot_safe(aligned_plot_dat, "UMAP_X", "UMAP_Y", sample_col, col.type = "factor", filename = "Aligned_samples.png", path = aligned_plot_dir)
  make_colour_plot_safe(aligned_plot_dat, "UMAP_X", "UMAP_Y", donor_col, col.type = "factor", filename = "Aligned_donors.png", path = aligned_plot_dir)
  make_multi_plot_safe(aligned_plot_dat, aligned_cols, figure.title = "Aligned markers", save.each.plot = TRUE, path = aligned_plot_dir)
  rm(aligned_plot_dat)
  gc()

  if (cfg$batch_mode == "reference" && as_flag(cfg$exclude_batch_controls_after_alignment)) {
    before <- nrow(cell_dat)
    if (!is.null(reference_group)) {
      cell_dat <- cell_dat[cell_dat[[group_col]] != reference_group]
      message(">>> Removed reference-control group after alignment: ", before - nrow(cell_dat), " cells")
    } else {
      cell_dat <- cell_dat[!cell_dat[[sample_col]] %in% cfg$batch_controls]
      message(">>> Removed reference-control sample(s) after alignment: ", before - nrow(cell_dat), " cells")
    }
  }

  aligned_data_dir <- ensure_dir(file.path(dirs$out2, "5 - aligned data"))
  data.table::fwrite(cell_dat, file.path(aligned_data_dir, "cell.dat_allAligned.csv"))
  capture.output(sessionInfo(), file = file.path(dirs$out2, "session_info.txt"))

  list(data = cell_dat, analysis_cols = aligned_cols)
}

resolve_clustering_cols <- function(analysis_cols, requested_markers) {
  if (is.null(requested_markers) || length(requested_markers) == 0) {
    return(analysis_cols)
  }

  if (is.numeric(requested_markers)) {
    if (any(requested_markers < 1 | requested_markers > length(analysis_cols))) {
      stop("clustering_markers numeric positions are outside the marker range.", call. = FALSE)
    }
    return(analysis_cols[requested_markers])
  }

  resolved <- character(0)
  for (marker in as.character(requested_markers)) {
    candidates <- unique(c(
      marker,
      paste0(marker, "_asinh"),
      paste0(marker, "_aligned"),
      paste0(marker, "_asinh_aligned")
    ))
    matched <- intersect(candidates, analysis_cols)
    if (length(matched) == 0) {
      stop("Requested clustering marker not found: ", marker, call. = FALSE)
    }
    resolved <- c(resolved, matched[[1]])
  }

  unique(resolved)
}

run_clustering <- function(cell_dat, clustering_cols, cfg, threads) {
  require_columns(cell_dat, clustering_cols, "cell data")
  numeric_cols <- vapply(cell_dat[, ..clustering_cols], is.numeric, logical(1))
  if (!all(numeric_cols)) {
    stop(
      "Non-numeric clustering column(s): ",
      paste(clustering_cols[!numeric_cols], collapse = ", "),
      call. = FALSE
    )
  }

  message(">>> Running FastPG clustering with k = ", cfg$phenok)
  matrix_dat <- as.matrix(cell_dat[, ..clustering_cols])
  storage.mode(matrix_dat) <- "double"
  output_fastpg <- FastPG::fastCluster(data = matrix_dat, k = cfg$phenok, num_threads = threads)
  cell_dat[, fastPG_Clusters := output_fastpg[[2]]]
  cell_dat
}

make_cluster_outputs <- function(cell_dat, clustering_cols, cfg, dirs) {
  sample_col <- cfg$meta_columns[["sample"]]
  group_col <- cfg$meta_columns[["group"]]
  batch_col <- cfg$meta_columns[["batch"]]
  donor_col <- cfg$meta_columns[["donor"]]

  plot_dat <- safe_run_umap(cell_dat, clustering_cols, cfg$umap_cells, cfg$random_seed)
  data.table::fwrite(plot_dat, file.path(dirs$out3, "cell.dat_umap.csv"))

  exp <- do.aggregate(as.data.table(cell_dat), clustering_cols, by = "fastPG_Clusters")
  if (cfg$flow_type == "cytof" && exists("make.cytofheatmap", mode = "function")) {
    make.cytofheatmap(
      exp,
      "fastPG_Clusters",
      plot.cols = clustering_cols,
      normalise = FALSE,
      standard.colours = "rev(RdBu)",
      path = dirs$out3
    )
  } else {
    make.pheatmap(
      exp,
      "fastPG_Clusters",
      plot.cols = clustering_cols,
      normalise = TRUE,
      standard.colours = "rev(RdBu)",
      path = dirs$out3
    )
    if (exists("make.z_norm_pheatmap", mode = "function")) {
      make.z_norm_pheatmap(
        exp,
        "fastPG_Clusters",
        plot.cols = clustering_cols,
        normalise = FALSE,
        standard.colours = "rev(RdBu)",
        file.name = "fastPG_Clusters_znorm.png",
        path = dirs$out3
      )
    }
  }

  make_colour_plot_safe(plot_dat, "UMAP_X", "UMAP_Y", "fastPG_Clusters", col.type = "factor", add.label = TRUE, path = dirs$out3)
  make_colour_plot_safe(plot_dat, "UMAP_X", "UMAP_Y", group_col, col.type = "factor", path = dirs$out3)
  make_colour_plot_safe(plot_dat, "UMAP_X", "UMAP_Y", sample_col, col.type = "factor", path = dirs$out3)
  make_colour_plot_safe(plot_dat, "UMAP_X", "UMAP_Y", batch_col, col.type = "factor", path = dirs$out3)
  make_colour_plot_safe(plot_dat, "UMAP_X", "UMAP_Y", donor_col, col.type = "factor", path = dirs$out3)

  if (as_flag(cfg$do_marker_umaps)) {
    for (marker in clustering_cols) {
      threshold <- suppressWarnings(stats::quantile(plot_dat[[marker]], probs = 0.01, na.rm = TRUE))
      make_colour_plot_safe(
        plot_dat,
        "UMAP_X",
        "UMAP_Y",
        marker,
        col.min.threshold = threshold,
        path = dirs$out3
      )
    }
  }

  group_names <- unique(plot_dat[[group_col]])
  for (group_name in group_names) {
    group_dir <- ensure_dir(file.path(dirs$out3, "Groups"))
    group_dat <- plot_dat[plot_dat[[group_col]] == group_name]
    make_colour_plot_safe(
      group_dat,
      "UMAP_X",
      "UMAP_Y",
      "fastPG_Clusters",
      col.type = "factor",
      filename = paste0("group_fastPG_clusters_", make.names(group_name), ".png"),
      path = group_dir
    )
  }

  plot_dat
}

write_summary <- function(cell_dat, meta_dat, clustering_cols, cfg, out_dir) {
  if (!as_flag(cfg$do_summary)) {
    return(invisible(NULL))
  }

  sample_col <- cfg$meta_columns[["sample"]]
  group_col <- cfg$meta_columns[["group"]]
  count_col <- intersect(c("Cells.per.sample", "Cells per sample", "Cells_per_sample"), names(meta_dat))
  if (length(count_col) == 0) {
    warning("No cell-count column found in metadata; summary will use observed cell counts.", call. = FALSE)
    counts <- cell_dat[, .N, by = sample_col]
    data.table::setnames(counts, "N", "Cells per sample")
  } else {
    counts <- meta_dat[, c(sample_col, count_col[[1]]), with = FALSE]
    data.table::setnames(counts, count_col[[1]], "Cells per sample")
  }

  sum_dat <- create.sumtable(
    dat = cell_dat,
    sample.col = sample_col,
    pop.col = "fastPG_Clusters",
    use.cols = clustering_cols,
    annot.cols = c(group_col),
    counts = counts
  )
  data.table::fwrite(sum_dat, file.path(out_dir, paste0("Summary_fastPG_k", cfg$phenok, ".csv")))
}

write_fcs_outputs <- function(cell_dat, clustering_cols, cfg, out_dir) {
  if (!as_flag(cfg$do_fcs_export)) {
    return(invisible(NULL))
  }

  sample_col <- cfg$meta_columns[["sample"]]
  group_col <- cfg$meta_columns[["group"]]
  export_dir <- ensure_dir(file.path(out_dir, "FCS files"))
  export_cols <- unique(c(
    clustering_cols,
    "fastPG_Clusters",
    sample_col,
    group_col,
    cfg$meta_columns[["batch"]],
    cfg$meta_columns[["donor"]],
    "UMAP_X",
    "UMAP_Y"
  ))
  export_cols <- intersect(export_cols, names(cell_dat))
  export_dat <- cell_dat[, ..export_cols]

  write.files(
    export_dat,
    file.prefix = file.path(export_dir, "Clustered_by_sample"),
    divide.by = sample_col,
    write.csv = FALSE,
    write.fcs = TRUE
  )
  write.files(
    export_dat,
    file.prefix = file.path(export_dir, "Clustered_by_group"),
    divide.by = group_col,
    write.csv = FALSE,
    write.fcs = TRUE
  )
  write.files(
    export_dat,
    file.prefix = file.path(export_dir, "Clustered_by_cluster"),
    divide.by = "fastPG_Clusters",
    write.csv = TRUE,
    write.fcs = TRUE
  )
}

run_spectre_unified <- function(settings = list()) {
  cfg <- normalise_settings(settings)
  load_spectre_packages()
  set.seed(cfg$random_seed)

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(cfg$project_dir)

  threads <- data.table::getDTthreads()
  message(">>> Using ", threads, " data.table thread(s)")

  dirs <- list(
    out1 = ensure_dir(file.path(cfg$output_dir, "Output 1 - Data Prep")),
    out2 = ensure_dir(file.path(cfg$output_dir, "Output 2 - Batch Alignment")),
    out3 = ensure_dir(file.path(cfg$output_dir, paste0("Output 3 - Clustering_k", cfg$phenok)))
  )

  transformed_file <- file.path(dirs$out1, "cell.dat_transformed.csv")
  aligned_file <- file.path(dirs$out2, "5 - aligned data", "cell.dat_allAligned.csv")
  marker_path <- file.path(cfg$data_dir, cfg$marker_file)

  meta_path <- file.path(cfg$metadata_dir, cfg$metadata_file)
  if (!file.exists(meta_path)) {
    stop("Metadata file not found: ", meta_path, call. = FALSE)
  }
  meta_dat <- data.table::fread(meta_path, check.names = FALSE)
  require_columns(meta_dat, c("FileName", unname(cfg$meta_columns)), "metadata")

  if (as_flag(cfg$reuse_existing) && file.exists(transformed_file)) {
    message(">>> Reusing transformed data: ", transformed_file)
    cell_dat <- data.table::fread(transformed_file, check.names = FALSE)
    transformed_cols <- grep("_asinh$", names(cell_dat), value = TRUE)
    if (length(transformed_cols) == 0) {
      stop("Reused transformed data has no *_asinh columns.", call. = FALSE)
    }
  } else {
    marker_info <- read_marker_file(marker_path)
    cell_dat <- read_input_data(cfg)
    renamed <- rename_marker_columns(cell_dat, marker_info, dirs$out1)
    cell_dat <- renamed$data
    metadata_added <- add_metadata(cell_dat, cfg)
    cell_dat <- metadata_added$data
    meta_dat <- metadata_added$metadata
    transformed <- transform_markers(cell_dat, renamed$marker_cols, cfg)
    cell_dat <- transformed$data
    transformed_cols <- transformed$transformed_cols
    data.table::fwrite(cell_dat, transformed_file)
    capture.output(sessionInfo(), file = file.path(dirs$out1, "session_info.txt"))
  }

  make_qc_plots(cell_dat, transformed_cols, cfg, dirs$out1)
  cell_dat <- evaluate_filters(cell_dat, cfg$pre_batch_filters, label = "pre-batch")

  if (as_flag(cfg$reuse_existing) && cfg$batch_mode != "none" && file.exists(aligned_file)) {
    message(">>> Reusing aligned data: ", aligned_file)
    cell_dat <- data.table::fread(aligned_file, check.names = FALSE)
    analysis_cols <- grep("_asinh_aligned$", names(cell_dat), value = TRUE)
    if (length(analysis_cols) == 0) {
      stop("Reused aligned data has no *_asinh_aligned columns.", call. = FALSE)
    }
  } else {
    aligned <- run_batch_alignment(cell_dat, transformed_cols, cfg, dirs)
    cell_dat <- aligned$data
    analysis_cols <- aligned$analysis_cols
  }

  cell_dat <- evaluate_filters(cell_dat, cfg$analysis_filters, label = "analysis")
  cell_dat <- balance_by_sample(cell_dat, cfg$meta_columns[["sample"]], cfg)

  clustering_cols <- resolve_clustering_cols(analysis_cols, cfg$clustering_markers)
  cell_dat <- run_clustering(cell_dat, clustering_cols, cfg, threads)

  data.table::fwrite(cell_dat, file.path(dirs$out3, paste0("cell.dat_Clustered_k", cfg$phenok, ".csv")))
  plot_dat <- make_cluster_outputs(cell_dat, clustering_cols, cfg, dirs)
  write_summary(cell_dat, meta_dat, clustering_cols, cfg, dirs$out3)
  write_fcs_outputs(cell_dat, clustering_cols, cfg, dirs$out3)

  result <- list(
    settings = cfg,
    clustering_cols = clustering_cols,
    transformed_cols = transformed_cols,
    clustered_data = cell_dat,
    plot_data = plot_dat,
    output_dirs = dirs
  )

  saveRDS(result, file.path(dirs$out3, paste0("Analysis_Completed_k", cfg$phenok, ".rds")))
  message(">>> Pipeline completed successfully.")
  invisible(result)
}
