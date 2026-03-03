🧪 Standardized Spectre FACS Analysis Pipeline
Welcome! This is a fully automated pipeline for analyzing high-dimensional cytometry data (Flow, CyTOF, Aurora).

It is designed to be Solid (100% reproducible), Fast (analyzes millions of cells in minutes), and Friendly (no coding skills required).

🌟 Key Features
⚡ High-Speed Analysis: Uses "Landmark Clustering" to process huge datasets (5M+ cells) without crashing your computer.

🛡️ 100% Reproducible: "Solid Result" guarantee. If you run the same data today and next year, you will get the exact same clusters and UMAPs.

🤖 Auto-Batch Correction:

Single Batch: Skips correction automatically.

Multi-Batch (No Refs): Uses the whole population to align batches.

Multi-Batch (With Refs): Uses specific control samples to align batches (CytoNorm).

📝 Auto-Notebook: Automatically saves an analysis_log.txt for every run (records date, settings, and cell counts).

📂 Installation (One-Time Setup)
1. Prerequisites
Download and install R (version 4.1.0 or higher).

Download and install RStudio Desktop.

2. Download the Pipeline
Click the green Code button above -> Download ZIP.

Unzip the folder to a fixed location on your computer (e.g., C:/Pipelines/My-FACS-Pipeline).

Note: Do not move this folder later, or you will need to update your scripts.

3. Install Packages
Open the file setup.R in RStudio.

Click the Source button (top right of the script editor).

Wait for the installation to finish. (It ensures you have the exact same package versions as the developer).

🚀 How to Run Analysis (Daily Usage)
Step 1: Organize Your Experiment Folder
Create a new folder for your experiment. Structure it exactly like this:

Plaintext

My_Experiment_2026/
├── data/                    <-- Put your .fcs files here
├── metadata/                <-- Put your 2 CSV files here (see below)
└── wrapper.R                <-- Copy this file from the pipeline's 'template' folder
Step 2: Prepare Metadata (Excel/CSV)
You need two CSV files in the metadata folder:

1. sample.details.csv (Must contain these columns):

FileName: Exact name of the .fcs file (e.g., Sample_01.fcs).

Sample: Unique sample ID.

Group: Experimental group (e.g., Mock, Treated).

Batch: Batch number (e.g., 1, 2).

Donor: Donor ID (optional).

2. ORIGINAL MARKERS.csv (Must contain these columns):

Channel: The machine channel name (e.g., FJComp-APC-A).

Marker: The biological name you want to use (e.g., CD3, CD45RA).

Step 3: Configure wrapper.R
Open your copy of wrapper.R in RStudio and modify only the [REQUIRED SETTINGS] section:

R

# --- Example Configuration ---

# 1. Where did you save the pipeline code?
pipeline_path <- "C:/Pipelines/My-FACS-Pipeline"

# 2. File names
meta_file_name   <- "sample.details.csv"
marker_file_name <- "ORIGINAL MARKERS.csv"

# 3. Batch Correction
# If you have reference controls, list them here:
ref_samples <- c("BatchCtrl_Run1", "BatchCtrl_Run2")

# If you DO NOT have reference controls, set to NULL:
# ref_samples <- NULL
Step 4: Run!
Click the [Source] button in RStudio.

Sit back and relax ☕.

The script will automatically create a new folder: Output_Result_YYYY-MM-DD_HH-MM.

It will never overwrite your previous results.

📊 Understanding the Output
Go to your output folder (e.g., Output_Result_YYYY-MM-DD...). You will see 3 main sub-folders and some files:

📂 1 - data prep
cell.dat.csv: The raw data combined and transformed (arcsinh).

Marker Plots: PNG images showing the expression of every marker before batch correction. Use these to check if your data looks normal.

📂 2 - batch alignment
Pre_Aligned_*.png: UMAPs showing your data before correction. (If you see strong batch effects here, that's normal).

Post_Aligned_*.png: UMAPs showing your data after correction. (Batches should now overlap/mix together).

cell.dat_allAligned.csv: The full dataset after batch correction.

📂 3 - clustering and DR_fastPG
cell.dat_Clustered.csv: 🌟 The Master File. Contains all your cells, their marker values, and their assigned Cluster ID. Use this for statistical analysis.

UMAP_Clusters.png: The final map showing where each Cluster is located.

UMAP_MarkerName.png: UMAPs colored by marker intensity. (Cleaned with a 2% noise cutoff).

Heatmap_Znorm.png: A heatmap summarizing what markers each cluster expresses.

Clustered_*.fcs files: New FCS files containing the cluster IDs. You can open these in FlowJo to check the populations manually.

📄 Main Folder Files
analysis_log.txt: 📝 Your Lab Notebook. It records the date, user, settings (k-value, cofactor), and cell counts.

sum.dat_fastPGk=30.csv: A summary table showing the percentage and count of each cluster per sample. (Great for quick Excel graphing).

❓ FAQ & Troubleshooting
Q: I get an error saying "Reference samples not found".

A: Check your wrapper.R. The names in ref_samples must exactly match the Sample column in your sample.details.csv.

Q: The UMAP looks messy or "over-corrected".

A: If you don't have reference controls (ref_samples = NULL) but have multiple batches, the pipeline assumes all batches are biologically similar. If Batch 1 is "Healthy" and Batch 2 is "Disease", this might merge them incorrectly. In that case, treat them as one batch or consult the developer.

Q: It says "R version too old".

A: You are likely using R 3.6 or 4.0. Please install R 4.1.0 or newer to ensure the math (RNG) works correctly.

Q: My computer ran out of memory.

A: The pipeline is optimized to handle large data, but if you have >10 million cells, try increasing the subsample_size in the wrapper or ask for server access.

Maintained by: [Your Name / Lab Name]