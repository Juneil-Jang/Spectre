################################################################################
### setup.R
### Description: Run this ONCE to synchronize your R environment.
###              It installs the exact package versions used by the developer.
################################################################################

if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")

message(">>> Starting Environment Synchronization...")

if (file.exists("renv.lock")) {
  # Restore exact versions from lockfile
  renv::restore(prompt = FALSE)
  message(">>> Environment synchronized successfully! (Identical to developer's setup)")
} else {
  # Fallback: Install latest versions
  warning("⚠️ 'renv.lock' not found. Installing latest versions instead.")
  if (!requireNamespace("BiocManager", quietly = T)) install.packages("BiocManager")
  BiocManager::install(c("flowCore", "Biobase"), update=F)
  if (!requireNamespace("Spectre", quietly=T)) remotes::install_github("ImmuneDynamics/Spectre")
  if (!requireNamespace("FastPG", quietly=T)) remotes::install_github("sararselitsky/FastPG")
  # Add other dependencies...
}

message(">>> Setup Complete! You can now use wrapper.R.")