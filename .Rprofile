source("renv/activate.R")

local({
  helper <- file.path("scripts", "renv_core_repos.R")
  if (file.exists(helper)) {
    source(helper)
    spectre_use_r4_bioc_repos(quiet = TRUE)
  }
})
