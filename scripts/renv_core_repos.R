################################################################################
### R 4.x / Bioconductor repository helper for this Spectre project.
### Keep this dependency-free: .Rprofile sources it before packages are restored.
################################################################################

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

spectre_r_version_parts <- function(r_version = getRversion()) {
  parts <- strsplit(as.character(r_version), ".", fixed = TRUE)[[1]]
  list(
    version = as.character(r_version),
    major = as.integer(parts[[1]]),
    minor = as.integer(parts[[2]])
  )
}

spectre_core_bioc_version <- function(r_version = getRversion()) {
  r <- spectre_r_version_parts(r_version)
  if (!identical(r$major, 4L)) {
    stop(
      "This Spectre renv setup supports R 4.0 through R 4.5 only. ",
      "Current R is ", r$version, ".",
      call. = FALSE
    )
  }

  versions <- c(
    "0" = "3.12",
    "1" = "3.14",
    "2" = "3.16",
    "3" = "3.18",
    "4" = "3.20",
    "5" = "3.22"
  )
  bioc_version <- versions[[as.character(r$minor)]]

  if (is.null(bioc_version)) {
    stop(
      "This Spectre renv setup supports R 4.0 through R 4.5 only. ",
      "Current R is ", r$version, ".",
      call. = FALSE
    )
  }

  bioc_version
}

spectre_core_repositories <- function(
    bioc_version = spectre_core_bioc_version(),
    cran = "https://cloud.r-project.org") {
  bioc_root <- paste0("https://bioconductor.org/packages/", bioc_version)
  c(
    BioCsoft = paste0(bioc_root, "/bioc"),
    BioCann = paste0(bioc_root, "/data/annotation"),
    BioCexp = paste0(bioc_root, "/data/experiment"),
    BioCworkflows = paste0(bioc_root, "/workflows"),
    CRAN = cran
  )
}

spectre_use_r4_bioc_repos <- function(quiet = FALSE) {
  bioc_version <- spectre_core_bioc_version()
  repos <- spectre_core_repositories(bioc_version)

  options(
    repos = repos,
    BioC_mirror = "https://bioconductor.org",
    renv.config.repos.override = repos,
    renv.config.bioconductor.version = bioc_version
  )

  if (!quiet) {
    message(
      "Using Bioconductor ", bioc_version,
      " repositories for R ", as.character(getRversion()), "."
    )
  }

  invisible(list(bioconductor_version = bioc_version, repos = repos))
}

spectre_core_package_refs <- function() {
  c(
    Spectre = "immunedynamics/Spectre@159dc9f6d700b0dbd9fed8677cd94521c661691e",
    FastPG = "sararselitsky/FastPG@44c9282fdd3de97e8e98a7c9165b7cc67d130e1a",
    CytoNorm = "saeyslab/CytoNorm@b1046ac76d4873acdcc82e92003e8eb919ebdd01"
  )
}

spectre_core_package_shas <- function() {
  c(
    Spectre = "159dc9f6d700b0dbd9fed8677cd94521c661691e",
    FastPG = "44c9282fdd3de97e8e98a7c9165b7cc67d130e1a",
    CytoNorm = "b1046ac76d4873acdcc82e92003e8eb919ebdd01"
  )
}

spectre_core_lock_records <- function() {
  list(
    CytoNorm = list(
      Package = "CytoNorm",
      Version = "2.0.9",
      Source = "GitHub",
      Type = "Package",
      Title = "Normalisation of cytometry data measured across multiple batches",
      Depends = c("R (>= 3.5)"),
      Imports = c(
        "flowCore", "FlowSOM", "emdist", "dplyr", "stringr", "pheatmap",
        "ggplot2 (>= 3.5.1)", "ggpubr", "methods", "gridExtra",
        "ggridges", "tidyr"
      ),
      License = "GPL (>= 2)",
      RemoteType = "github",
      RemoteHost = "api.github.com",
      RemoteRepo = "CytoNorm",
      RemoteUsername = "saeyslab",
      RemoteRef = spectre_core_package_shas()[["CytoNorm"]],
      RemoteSha = spectre_core_package_shas()[["CytoNorm"]],
      NeedsCompilation = "no"
    ),
    FastPG = list(
      Package = "FastPG",
      Version = "0.0.8",
      Source = "GitHub",
      Title = "Fast PhenoGraph-like clustering",
      Depends = c("R (>= 4.0)"),
      Imports = c(
        "Rcpp (>= 1.0.3)", "RcppParallel (>= 4.4.4)",
        "flowCore", "checkmate", "RcppHNSW"
      ),
      LinkingTo = c("Rcpp", "RcppParallel", "BH"),
      License = "MIT + file LICENSE",
      RemoteType = "github",
      RemoteHost = "api.github.com",
      RemoteRepo = "FastPG",
      RemoteUsername = "sararselitsky",
      RemoteRef = spectre_core_package_shas()[["FastPG"]],
      RemoteSha = spectre_core_package_shas()[["FastPG"]],
      NeedsCompilation = "yes"
    ),
    Spectre = list(
      Package = "Spectre",
      Version = "1.3.0",
      Source = "GitHub",
      Type = "Package",
      Title = "High-dimensional cytometry and imaging analysis",
      Depends = c("R (>= 3.6.0)"),
      Imports = c(
        "colorRamps", "data.table", "dendsort", "factoextra", "flowCore",
        "FlowSOM", "fs", "ggplot2", "ggpointdensity", "ggpubr",
        "ggrepel", "ggthemes", "gridExtra", "gtools", "irlba",
        "lifecycle", "parallel", "patchwork", "pheatmap", "RColorBrewer",
        "rstudioapi", "rsvd", "Rtsne", "scales", "scattermore", "umap",
        "uwot", "viridis"
      ),
      Remotes = "saeyslab/CytoNorm, JinmiaoChenLab/Rphenograph",
      License = "MIT + file LICENSE",
      RemoteType = "github",
      RemoteHost = "api.github.com",
      RemoteRepo = "Spectre",
      RemoteUsername = "immunedynamics",
      RemotePkgRef = "immunedynamics/Spectre",
      RemoteRef = spectre_core_package_shas()[["Spectre"]],
      RemoteSha = spectre_core_package_shas()[["Spectre"]],
      NeedsCompilation = "no"
    )
  )
}

spectre_json_escape <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  paste0("\"", x, "\"")
}

spectre_json_encode <- function(x, indent = 0) {
  pad <- paste(rep(" ", indent), collapse = "")
  pad_child <- paste(rep(" ", indent + 2), collapse = "")

  if (is.null(x)) {
    return("null")
  }

  if (is.character(x)) {
    if (length(x) == 1) {
      return(spectre_json_escape(x))
    }
    values <- vapply(x, spectre_json_escape, character(1))
    return(paste0("[\n", pad_child, paste(values, collapse = paste0(",\n", pad_child)), "\n", pad, "]"))
  }

  if (is.numeric(x) || is.integer(x)) {
    return(paste(x, collapse = ", "))
  }

  if (is.logical(x)) {
    return(tolower(as.character(x)))
  }

  if (is.list(x)) {
    nms <- names(x)
    is_object <- !is.null(nms) && all(nzchar(nms))
    if (is_object) {
      entries <- character(length(x))
      for (i in seq_along(x)) {
        entries[[i]] <- paste0(
          pad_child,
          spectre_json_escape(nms[[i]]),
          ": ",
          spectre_json_encode(x[[i]], indent + 2)
        )
      }
      return(paste0("{\n", paste(entries, collapse = ",\n"), "\n", pad, "}"))
    }

    entries <- vapply(x, spectre_json_encode, character(1), indent = indent + 2)
    return(paste0("[\n", pad_child, paste(entries, collapse = paste0(",\n", pad_child)), "\n", pad, "]"))
  }

  stop("Cannot encode object as JSON: ", typeof(x), call. = FALSE)
}

spectre_write_core_lockfile <- function(project_dir = getwd()) {
  lock <- list(
    R = list(
      Version = "4.0.0",
      Repositories = list(list(Name = "CRAN", URL = "https://cloud.r-project.org"))
    ),
    Packages = spectre_core_lock_records()
  )
  lockfile <- file.path(project_dir, "renv.lock")
  writeLines(spectre_json_encode(lock), lockfile, useBytes = TRUE)
  invisible(lockfile)
}

spectre_write_core_renv_settings <- function(project_dir = getwd()) {
  settings <- c(
    "{",
    "  \"bioconductor.version\": null,",
    "  \"external.libraries\": [],",
    "  \"ignored.packages\": [],",
    "  \"package.dependency.fields\": [",
    "    \"Imports\",",
    "    \"Depends\",",
    "    \"LinkingTo\"",
    "  ],",
    "  \"ppm.enabled\": null,",
    "  \"ppm.ignored.urls\": [],",
    "  \"r.version\": null,",
    "  \"snapshot.type\": \"explicit\",",
    "  \"use.cache\": true,",
    "  \"vcs.ignore.cellar\": true,",
    "  \"vcs.ignore.library\": true,",
    "  \"vcs.ignore.local\": true,",
    "  \"vcs.manage.ignores\": true",
    "}"
  )

  settings_file <- file.path(project_dir, "renv", "settings.json")
  writeLines(settings, settings_file, useBytes = TRUE)
  invisible(settings_file)
}

spectre_assert_project_local_path <- function(path, project_dir = getwd(), label = "path") {
  project_norm <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)

  if (!startsWith(tolower(path_norm), paste0(tolower(project_norm), "/"))) {
    stop(
      label, " must be inside the project directory.\n",
      "  project: ", project_norm, "\n",
      "  ", label, ": ", path_norm,
      call. = FALSE
    )
  }

  invisible(path_norm)
}

spectre_project_renv_library <- function(project_dir = getwd()) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    stop("renv is not available. Source renv/activate.R first.", call. = FALSE)
  }

  project_library <- renv::paths$library(project = project_dir)
  spectre_assert_project_local_path(project_library, project_dir, "project renv library")
  dir.create(project_library, recursive = TRUE, showWarnings = FALSE)
  normalizePath(project_library, winslash = "/", mustWork = FALSE)
}

spectre_use_project_renv_library <- function(project_dir = getwd()) {
  project_library <- spectre_project_renv_library(project_dir)
  .libPaths(unique(c(project_library, .libPaths())))
  invisible(project_library)
}
