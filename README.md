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