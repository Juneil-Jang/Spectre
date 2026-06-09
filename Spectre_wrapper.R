################################################################################
### Optional RStudio entry point
### Edit config.xlsx, not this file.
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

source(file.path(PROJECT_DIR, "scripts", "run_from_config.R"))
