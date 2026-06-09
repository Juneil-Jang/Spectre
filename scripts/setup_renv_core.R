################################################################################
### Bootstrap this project for R 4.0-4.5 with core package pins only.
### Run once in RStudio:
### source("scripts/setup_renv_core.R")
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

Sys.setenv(RENV_CONFIG_CONSENT = "TRUE")

activate_script <- file.path(PROJECT_DIR, "renv", "activate.R")
if (!file.exists(activate_script)) {
  stop(
    "renv/activate.R is missing. Refusing to install renv into a user/global library.\n",
    "Create or restore the project-local renv bootstrap first.",
    call. = FALSE
  )
}
source(activate_script)

source(file.path(PROJECT_DIR, "scripts", "renv_core_repos.R"))
repo_info <- spectre_use_r4_bioc_repos()
project_library <- spectre_use_project_renv_library(PROJECT_DIR)

renv::settings$snapshot.type("explicit", project = PROJECT_DIR)
renv::settings$r.version(NULL, project = PROJECT_DIR)
renv::settings$bioconductor.version(NULL, project = PROJECT_DIR)
spectre_write_core_renv_settings(PROJECT_DIR)

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", lib = project_library, repos = getOption("repos")[["CRAN"]])
}

message(">>> Preparing Bioconductor ", repo_info$bioconductor_version, " for R ", getRversion())
BiocManager::install(
  version = repo_info$bioconductor_version,
  lib = project_library,
  ask = FALSE,
  update = FALSE
)

core_refs <- unname(spectre_core_package_refs())
message(">>> Installing core pinned packages:")
message("    ", paste(core_refs, collapse = "\n    "))
renv::install(
  core_refs,
  project = PROJECT_DIR,
  library = project_library,
  prompt = FALSE
)

helper_packages <- c("openxlsx")
message(">>> Installing helper package(s): ", paste(helper_packages, collapse = ", "))
renv::install(
  helper_packages,
  project = PROJECT_DIR,
  library = project_library,
  prompt = FALSE
)

spectre_write_core_lockfile(PROJECT_DIR)

message(">>> Core renv setup complete.")
message(">>> Minimal lockfile written to: ", file.path(PROJECT_DIR, "renv.lock"))
message(">>> Run source('scripts/check_renv_core.R') to verify installed package SHAs.")
