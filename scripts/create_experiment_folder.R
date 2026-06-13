################################################################################
### Create a portable Spectre experiment folder.
### The experiment folder stores data/config/results and calls this pipeline.
################################################################################

spectre_find_pipeline_dir <- function() {
  frame_paths <- vapply(sys.frames(), function(frame) {
    path <- frame$ofile
    if (is.null(path)) NA_character_ else path
  }, character(1))
  frame_paths <- frame_paths[!is.na(frame_paths)]

  if (length(frame_paths) > 0) {
    return(dirname(dirname(normalizePath(frame_paths[[length(frame_paths)]], winslash = "/", mustWork = FALSE))))
  }

  if (file.exists("renv.lock") && dir.exists("scripts")) {
    return(normalizePath(getwd(), winslash = "/", mustWork = FALSE))
  }

  stop("Run this script from the Spectre pipeline folder.", call. = FALSE)
}

spectre_write_lines <- function(lines, path) {
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

spectre_activate_pipeline <- function(pipeline_dir) {
  activate_script <- file.path(pipeline_dir, "renv", "activate.R")
  if (!file.exists(activate_script)) {
    stop(
      "renv/activate.R was not found in the Spectre pipeline folder.\n",
      "Run SETUP_WINDOWS.bat or SETUP_MAC.command first.",
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

  source(activate_script)
  invisible(TRUE)
}

spectre_update_config <- function(config_path) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop(
      "Package 'openxlsx' is required to create experiment config.xlsx.\n",
      "Run SETUP_WINDOWS.bat or SETUP_MAC.command in the Spectre folder first.",
      call. = FALSE
    )
  }

  wb <- openxlsx::loadWorkbook(config_path)
  settings <- openxlsx::read.xlsx(config_path, sheet = "Settings", detectDates = FALSE)
  names(settings) <- trimws(names(settings))

  set_value <- function(setting, value) {
    idx <- which(settings[["Setting"]] == setting)
    if (length(idx) == 1) {
      settings[idx, "Value"] <<- value
    }
  }

  set_value("use_example_data", "FALSE")
  set_value("data_dir", "data")
  set_value("metadata_dir", "metadata")
  set_value("output_dir", "results")
  set_value("phenok", "100")
  set_value("umap_cells", "100000")
  set_value("do_fcs_export", "TRUE")
  set_value("reuse_existing", "FALSE")

  openxlsx::writeData(wb, "Settings", settings)
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  invisible(config_path)
}

spectre_windows_runner <- function() {
  c(
    "@echo off",
    "setlocal",
    "",
    "cd /d \"%~dp0\"",
    "set \"EXPERIMENT_DIR=%CD%\"",
    "set \"CONFIG_FILE=%EXPERIMENT_DIR%\\config.xlsx\"",
    "set \"PIPELINE_PATH_FILE=%EXPERIMENT_DIR%\\spectre_pipeline_path.txt\"",
    "",
    "echo ============================================================",
    "echo Spectre Portable Experiment Runner",
    "echo ============================================================",
    "echo Experiment: %EXPERIMENT_DIR%",
    "",
    "if not exist \"%PIPELINE_PATH_FILE%\" (",
    "  echo ERROR: spectre_pipeline_path.txt was not found.",
    "  echo Re-create this experiment folder from the Spectre pipeline folder.",
    "  echo.",
    "  pause",
    "  exit /b 1",
    ")",
    "",
    "set /p PIPELINE_DIR=<\"%PIPELINE_PATH_FILE%\"",
    "set \"PIPELINE_DIR=%PIPELINE_DIR:\"=%\"",
    "",
    "if not exist \"%CONFIG_FILE%\" (",
    "  echo ERROR: config.xlsx was not found in this experiment folder.",
    "  echo.",
    "  pause",
    "  exit /b 1",
    ")",
    "",
    "if not exist \"%PIPELINE_DIR%\\scripts\\run_from_config.R\" (",
    "  echo ERROR: Could not find Spectre pipeline scripts at:",
    "  echo %PIPELINE_DIR%",
    "  echo.",
    "  echo If the Spectre folder moved, edit spectre_pipeline_path.txt.",
    "  echo.",
    "  pause",
    "  exit /b 1",
    ")",
    "",
    "set \"RSCRIPT=\"",
    "for /f \"delims=\" %%I in ('where Rscript.exe 2^>nul') do (",
    "  if not defined RSCRIPT set \"RSCRIPT=%%I\"",
    ")",
    "",
    "if not defined RSCRIPT (",
    "  for /f \"usebackq delims=\" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command \"$r = Get-ChildItem -Path 'C:\\Program Files\\R' -Filter Rscript.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName; if ($r) { $r }\"`) do (",
    "    set \"RSCRIPT=%%I\"",
    "  )",
    ")",
    "",
    "if not defined RSCRIPT (",
    "  echo ERROR: Rscript.exe was not found.",
    "  echo Please install R 4.x from https://cloud.r-project.org/",
    "  echo.",
    "  pause",
    "  exit /b 1",
    ")",
    "",
    "echo Pipeline  : %PIPELINE_DIR%",
    "echo Config    : %CONFIG_FILE%",
    "echo Rscript   : %RSCRIPT%",
    "echo.",
    "",
    "\"%RSCRIPT%\" --vanilla \"%PIPELINE_DIR%\\scripts\\run_from_config.R\" \"%CONFIG_FILE%\" \"%PIPELINE_DIR%\"",
    "set \"STATUS=%ERRORLEVEL%\"",
    "",
    "echo.",
    "if \"%STATUS%\"==\"0\" (",
    "  echo Spectre run completed successfully.",
    ") else (",
    "  echo Spectre run failed. Please read the message above.",
    ")",
    "echo.",
    "pause",
    "exit /b %STATUS%"
  )
}

spectre_mac_runner <- function() {
  c(
    "#!/bin/bash",
    "set -u",
    "",
    "cd \"$(dirname \"$0\")\" || exit 1",
    "EXPERIMENT_DIR=\"$(pwd)\"",
    "CONFIG_FILE=\"$EXPERIMENT_DIR/config.xlsx\"",
    "PIPELINE_PATH_FILE=\"$EXPERIMENT_DIR/spectre_pipeline_path.txt\"",
    "",
    "echo \"============================================================\"",
    "echo \"Spectre Portable Experiment Runner\"",
    "echo \"============================================================\"",
    "echo \"Experiment: $EXPERIMENT_DIR\"",
    "echo",
    "",
    "if [ ! -f \"$PIPELINE_PATH_FILE\" ]; then",
    "  echo \"ERROR: spectre_pipeline_path.txt was not found.\"",
    "  echo \"Re-create this experiment folder from the Spectre pipeline folder.\"",
    "  echo",
    "  read -r -n 1 -p \"Press any key to close...\"",
    "  echo",
    "  exit 1",
    "fi",
    "",
    "PIPELINE_DIR=\"$(head -n 1 \"$PIPELINE_PATH_FILE\")\"",
    "PIPELINE_DIR=\"${PIPELINE_DIR%$'\\r'}\"",
    "",
    "if [ ! -f \"$CONFIG_FILE\" ]; then",
    "  echo \"ERROR: config.xlsx was not found in this experiment folder.\"",
    "  echo",
    "  read -r -n 1 -p \"Press any key to close...\"",
    "  echo",
    "  exit 1",
    "fi",
    "",
    "if [ ! -f \"$PIPELINE_DIR/scripts/run_from_config.R\" ]; then",
    "  echo \"ERROR: Could not find Spectre pipeline scripts at:\"",
    "  echo \"$PIPELINE_DIR\"",
    "  echo",
    "  echo \"If the Spectre folder moved, edit spectre_pipeline_path.txt.\"",
    "  echo",
    "  read -r -n 1 -p \"Press any key to close...\"",
    "  echo",
    "  exit 1",
    "fi",
    "",
    "if command -v Rscript >/dev/null 2>&1; then",
    "  RSCRIPT=\"$(command -v Rscript)\"",
    "elif [ -x \"/Library/Frameworks/R.framework/Resources/bin/Rscript\" ]; then",
    "  RSCRIPT=\"/Library/Frameworks/R.framework/Resources/bin/Rscript\"",
    "else",
    "  echo \"ERROR: Rscript was not found.\"",
    "  echo \"Please install R 4.x from https://cloud.r-project.org/\"",
    "  echo",
    "  read -r -n 1 -p \"Press any key to close...\"",
    "  echo",
    "  exit 1",
    "fi",
    "",
    "echo \"Pipeline  : $PIPELINE_DIR\"",
    "echo \"Config    : $CONFIG_FILE\"",
    "echo \"Rscript   : $RSCRIPT\"",
    "echo",
    "",
    "\"$RSCRIPT\" --vanilla \"$PIPELINE_DIR/scripts/run_from_config.R\" \"$CONFIG_FILE\" \"$PIPELINE_DIR\"",
    "STATUS=$?",
    "",
    "echo",
    "if [ \"$STATUS\" -eq 0 ]; then",
    "  echo \"Spectre run completed successfully.\"",
    "else",
    "  echo \"Spectre run failed. Please read the message above.\"",
    "fi",
    "echo",
    "read -r -n 1 -p \"Press any key to close...\"",
    "echo",
    "exit \"$STATUS\""
  )
}

spectre_experiment_readme <- function() {
  c(
    "# Spectre Experiment Folder",
    "",
    "This folder contains one cytometry experiment. The Spectre pipeline code stays in the central Spectre folder.",
    "",
    "## Folder Layout",
    "",
    "- `data/`: put all `.fcs` files here.",
    "- `metadata/`: put `sample.details.csv` and `ORIGINAL MARKERS.csv` here.",
    "- `results/`: analysis outputs will be written here.",
    "- `config.xlsx`: edit the yellow Value cells for this experiment.",
    "- `RUN_SPECTRE_WINDOWS.bat`: double-click on Windows.",
    "- `RUN_SPECTRE_MAC.command`: double-click on macOS.",
    "- `spectre_pipeline_path.txt`: points this experiment to the central Spectre pipeline folder.",
    "",
    "## Important",
    "",
    "Do not move the central Spectre pipeline folder after creating this experiment. If it moves, edit `spectre_pipeline_path.txt` or re-create the experiment folder.",
    "",
    "You may move this experiment folder itself. The runners use files next to themselves for `config.xlsx`, `data/`, `metadata/`, and `results/`."
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1 || !nzchar(args[[1]])) {
    stop("Usage: Rscript scripts/create_experiment_folder.R <experiment_folder>", call. = FALSE)
  }

  pipeline_dir <- spectre_find_pipeline_dir()
  spectre_activate_pipeline(pipeline_dir)
  experiment_dir <- normalizePath(args[[1]], winslash = "/", mustWork = FALSE)
  dir.create(experiment_dir, recursive = TRUE, showWarnings = FALSE)

  for (subdir in c("data", "metadata", "results")) {
    dir.create(file.path(experiment_dir, subdir), recursive = TRUE, showWarnings = FALSE)
  }

  config_src <- file.path(pipeline_dir, "config.xlsx")
  config_dst <- file.path(experiment_dir, "config.xlsx")
  if (!file.exists(config_dst)) {
    if (!file.exists(config_src)) {
      stop("Central config.xlsx was not found: ", config_src, call. = FALSE)
    }
    file.copy(config_src, config_dst, overwrite = FALSE)
    spectre_update_config(config_dst)
    message("Created config.xlsx")
  } else {
    message("config.xlsx already exists; not overwriting it.")
  }

  pipeline_path <- normalizePath(pipeline_dir, winslash = "/", mustWork = TRUE)
  spectre_write_lines(pipeline_path, file.path(experiment_dir, "spectre_pipeline_path.txt"))
  spectre_write_lines(spectre_windows_runner(), file.path(experiment_dir, "RUN_SPECTRE_WINDOWS.bat"))
  mac_runner <- spectre_write_lines(spectre_mac_runner(), file.path(experiment_dir, "RUN_SPECTRE_MAC.command"))
  Sys.chmod(mac_runner, mode = "0755")
  spectre_write_lines(spectre_experiment_readme(), file.path(experiment_dir, "README_EXPERIMENT.md"))

  message("Created portable Spectre experiment folder:")
  message("  ", experiment_dir)
  message("")
  message("Next steps:")
  message("  1. Put .fcs files in data/")
  message("  2. Put sample.details.csv and ORIGINAL MARKERS.csv in metadata/")
  message("  3. Edit config.xlsx")
  message("  4. Double-click RUN_SPECTRE_WINDOWS.bat or RUN_SPECTRE_MAC.command")
}

tryCatch(
  main(),
  error = function(e) {
    message("")
    message("Could not create Spectre experiment folder:")
    message(conditionMessage(e))
    quit(status = 1, save = "no")
  }
)
