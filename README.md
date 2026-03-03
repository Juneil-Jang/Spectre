# 🧪 Standardized Spectre FACS Analysis Pipeline

![R Version](https://img.shields.io/badge/R-4.1.0+-276DC3?style=flat-square&logo=r&logoColor=white)
![Spectre](https://img.shields.io/badge/Spectre-v1.0-orange?style=flat-square)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square)

Welcome! This is a **fully automated pipeline** for analyzing high-dimensional cytometry data (Flow, CyTOF, Aurora). It is designed to be **Solid** (100% reproducible), **Fast** (analyzes millions of cells in minutes), and **Friendly** (no coding skills required).

---

## 🌟 Key Features

- ⚡ **High-Speed Analysis:** Uses *Landmark Clustering* to process huge datasets (5M+ cells) without crashing your computer.
- 🛡️ **100% Reproducible:** "Solid Result" guarantee. Run the same data today and next year, and you will get the exact same clusters and UMAPs.
- 🤖 **Auto-Batch Correction:**
  - **Single Batch:** Skips correction automatically.
  - **Multi-Batch (No Refs):** Uses the whole population to align batches.
  - **Multi-Batch (With Refs):** Uses specific control samples to align batches (`CytoNorm`).
- 📝 **Auto-Notebook:** Automatically saves an `analysis_log.txt` for every run (records date, settings, and cell counts).

---

## 📂 Installation (One-Time Setup)

### 1. Prerequisites
- Download and install **[R (version 4.1.0 or higher)](https://cloud.r-project.org/)**.
- Download and install **[RStudio Desktop](https://posit.co/download/rstudio-desktop/)**.

### 2. Download the Pipeline
1. Click the green **Code** button above ➔ **Download ZIP**.
2. Unzip the folder to a **fixed location** on your computer (e.g., `C:/Pipelines/My-FACS-Pipeline`).
> ⚠️ **Note:** Do not move this folder later, or you will need to update your scripts.

### 3. Install Packages
1. Open the file `setup.R` in RStudio.
2. Click the **Source** button (top right of the script editor).
3. Wait for the installation to finish. *(This ensures you have the exact same package versions as the developer).*

---

## 🚀 How to Run Analysis (Daily Usage)

### Step 1: Organize Your Experiment Folder
Create a new folder for your experiment. Structure it **exactly** like this:

```text
My_Experiment_2026/
├── data/                    <-- Put your .fcs files here
├── metadata/                <-- Put your 2 CSV files here (see below)
└── wrapper.R                <-- Copy this file from the pipeline's 'template' folder
```

### Step 2: Prepare Metadata (Excel/CSV)
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

---

### Step 3: Configure wrapper.R
Open your copy of wrapper.R in RStudio and modify only the [REQUIRED SETTINGS] section:

 --- Example Configuration ---
1. Where did you save the pipeline code?
pipeline_path <- "C:/Pipelines/My-FACS-Pipeline"

2. File names
meta_file_name   <- "sample.details.csv"
marker_file_name <- "ORIGINAL MARKERS.csv"

3. Batch Correction
ref_samples <- c("BatchCtrl_Run1", "BatchCtrl_Run2") # Or set to NULL if no refs

---

### Step 4: Run!
Click the [Source] button in RStudio. Sit back and relax ☕. 
The script will automatically create a new timestamped folder (Output_Result_YYYY-MM-DD_HH-MM).

---

## 📊 Understanding the Output

Go to your output folder. You will see 3 main sub-folders and essential summary files:

> 📂 1 - data prep

cell.dat.csv: The raw data combined and transformed (arcsinh).

Marker Plots: PNG images showing the expression of every marker before batch correction.

---

> 📂 2 - batch alignment

Pre_Aligned_*.png: UMAPs showing your data before correction.

Post_Aligned_*.png: UMAPs showing your data after correction (Batches should now overlap).

cell.dat_allAligned.csv: The full dataset after batch correction.

---

> 📂 3 - clustering and DR_fastPG

🌟 cell.dat_Clustered.csv: The master file containing all cells, marker values, and Cluster IDs.

Heatmap_Znorm.png: A heatmap summarizing what markers each cluster expresses.

UMAP_Clusters.png: Map of all defined clusters.

UMAP_MarkerName.png: Individual marker expression (Cleaned with a 2% noise cutoff).

Clustered_*.fcs: FCS files containing cluster IDs (can be opened in FlowJo).

---

> 📄 Main Folder Files

📝 analysis_log.txt: Your automated Lab Notebook recording all run details.

📈 sum.dat_fastPGk=30.csv: Summary table showing the percentage and count of each cluster per sample.

---

❓ FAQ & Troubleshooting
<details>
<summary><b>1. I get an error saying "Reference samples not found".</b></summary>
Check your wrapper.R. The names in ref_samples must <b>exactly match</b> the Sample column in your sample.details.csv.
</details>

<details>
<summary><b>2. The UMAP looks messy or "over-corrected".</b></summary>
If you don't have reference controls (ref_samples = NULL) but have multiple batches, the pipeline assumes all batches are biologically similar. If Batch 1 is "Healthy" and Batch 2 is "Disease", this might merge them incorrectly. Treat them as one batch or consult the developer.
</details>

<details>
<summary><b>3. It says "R version too old".</b></summary>
You are likely using R 3.6 or 4.0. Please install R 4.1.0 or newer to ensure the math (RNG) works correctly.
</details>

<details>
<summary><b>4. My computer ran out of memory.</b></summary>
If you have >10 million cells, try increasing the <code>subsample_size</code> in the wrapper or ask for server access.
</details>

Maintained by: [Juneil Jang / Su Lab]