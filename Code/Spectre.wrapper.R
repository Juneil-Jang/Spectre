################################################################################
### FACS Analysis Wrapper
### [Instructions]
### 1. Copy this file into your specific experiment folder.
### 2. Modify the [REQUIRED SETTINGS] section below.
### 3. Click the 'Source' button to run the analysis.
################################################################################

# ==============================================================================
# [REQUIRED SETTINGS] Please modify ONLY this section!
# ==============================================================================

# 1. Path to the Pipeline Code (Ask your lab manager for this path)
#    e.g., "C:/Lab_Pipelines/My-FACS-Pipeline"
pipeline_path <- "C:/Users/Public/Documents/My-FACS-Pipeline" 

# 2. Metadata File Names (Must be inside your 'metadata' folder)
meta_file_name   <- "sample.details.csv"
marker_file_name <- "ORIGINAL MARKERS.csv"

# 3. Reference Samples for Batch Correction
#    Enter the 'Sample' names of your batch controls.
#    If you do NOT have reference samples, set this to NULL.
ref_samples <- c("Ref_Sample_1_neg", "Ref_Sample_2_neg")
# ref_samples <- NULL  <-- if no reference samples used

# 4. Analysis Options
k_value <- 30            # Clustering granularity (Default: 30)
machine_type <- "aurora" # Machine: "aurora", "cytof", or "flow"

# ==============================================================================
# [AUTO RUN] Do not modify the code below
# ==============================================================================
if (!requireNamespace("rstudioapi", quietly = TRUE)) install.packages("rstudioapi")
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# Check R Version
if (getRversion() < "4.1.0") stop("❌ R version is too old. Please update to 4.1.0 or higher.")

# Load Pipeline
if (!dir.exists(pipeline_path)) stop("❌ Cannot find the pipeline path. Please check 'pipeline_path'.")
source(file.path(pipeline_path, "scripts_main", "help_functions.R"))
source(file.path(pipeline_path, "scripts_main", "run.spectre_main.R"))

# Execute Analysis
tryCatch({
  run.spectre_main(
    phenok = k_value,
    metaFile = meta_file_name,
    markerFile = marker_file_name,
    ref.ctrls = ref_samples,
    flowType = machine_type,
    subsample_size = 100000, 
    # Auto-generate output folder name with timestamp to prevent overwriting
    output_name = paste0("Result_", format(Sys.time(), "%Y-%m-%d_%H-%M")) 
  )
}, error = function(e) {
  message("\n❌ An error occurred: ", e$message)
  message("Please check your metadata filenames and column headers.")
})