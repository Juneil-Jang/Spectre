################################################################################
### Verify the core-pinned Spectre renv environment.
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

source(file.path(PROJECT_DIR, "scripts", "renv_core_repos.R"))
repo_info <- spectre_use_r4_bioc_repos(quiet = TRUE)

expected_shas <- spectre_core_package_shas()
failures <- character(0)

for (pkg in names(expected_shas)) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    failures <- c(failures, paste0(pkg, " is not installed"))
    next
  }

  desc <- utils::packageDescription(pkg)
  observed_sha <- desc[["RemoteSha"]]
  observed_version <- as.character(utils::packageVersion(pkg))

  message(pkg, " ", observed_version, " @ ", observed_sha %||% "<no RemoteSha>")

  if (is.null(observed_sha) || is.na(observed_sha) || !identical(observed_sha, expected_shas[[pkg]])) {
    failures <- c(
      failures,
      paste0(pkg, " RemoteSha mismatch: expected ", expected_shas[[pkg]], ", observed ", observed_sha)
    )
  }
}

lock_text <- paste(readLines(file.path(PROJECT_DIR, "renv.lock"), warn = FALSE), collapse = "\n")
for (pkg in c("BiocManager", "BiocVersion")) {
  if (grepl(paste0("\"", pkg, "\""), lock_text, fixed = TRUE)) {
    failures <- c(failures, paste0(pkg, " should not be recorded in renv.lock"))
  }
}

for (sha in expected_shas) {
  if (!grepl(sha, lock_text, fixed = TRUE)) {
    failures <- c(failures, paste0("renv.lock is missing pinned SHA: ", sha))
  }
}

message("R version: ", as.character(getRversion()))
message("Bioconductor repositories: ", repo_info$bioconductor_version)

if (length(failures) > 0) {
  stop(
    "Core renv check failed:\n- ",
    paste(failures, collapse = "\n- "),
    call. = FALSE
  )
}

message("Core renv check passed.")
