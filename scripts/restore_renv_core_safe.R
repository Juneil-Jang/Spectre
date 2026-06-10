################################################################################
### Safe project-local renv restore.
### This wrapper refuses to restore into a user/global library and never cleans it.
################################################################################

spectre_find_project_dir <- function() {
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

  stop("Run this script from the Spectre project root.", call. = FALSE)
}

PROJECT_DIR <- spectre_find_project_dir()
setwd(PROJECT_DIR)

Sys.setenv(
  RENV_CONFIG_CONSENT = "TRUE",
  RENV_CONFIG_SYNCHRONIZED_CHECK = "FALSE"
)

activate_script <- file.path(PROJECT_DIR, "renv", "activate.R")
if (!file.exists(activate_script)) {
  stop("renv/activate.R is missing; refusing to restore into a non-project library.", call. = FALSE)
}
source(activate_script)

source(file.path(PROJECT_DIR, "scripts", "renv_core_repos.R"))
repo_info <- spectre_use_r4_bioc_repos()
project_library <- spectre_use_project_renv_library(PROJECT_DIR)
spectre_add_windows_rtools_to_path()

message(">>> Restoring only into project renv library:")
message("    ", project_library)
message(">>> clean = FALSE, so user/global libraries will not be removed or pruned.")

renv::restore(
  project = PROJECT_DIR,
  library = project_library,
  repos = repo_info$repos,
  clean = FALSE,
  prompt = FALSE
)

helper_packages <- c("openxlsx")
missing_helpers <- helper_packages[!vapply(helper_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_helpers) > 0) {
  message(">>> Installing helper package(s): ", paste(missing_helpers, collapse = ", "))
  renv::install(
    missing_helpers,
    project = PROJECT_DIR,
    library = project_library,
    prompt = FALSE
  )
}

message(">>> Safe project-local restore completed.")
