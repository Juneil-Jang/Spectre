# Spectre Cytometry Analysis Pipeline

This repository contains a wet-lab friendly R pipeline for high-dimensional cytometry analysis using Spectre, FastPG, and CytoNorm.

The main entry point is:

```r
source("Spectre_wrapper.R")
```

Open `Spectre_wrapper.R` in RStudio, edit only the `SETTINGS` block, and click **Source**.

## What This Pipeline Does

- Imports `.fcs` files.
- Adds sample metadata from `sample.details.csv`.
- Renames instrument channels using `ORIGINAL MARKERS.csv`.
- Applies arcsinh transformation.
- Optionally performs CytoNorm batch alignment.
- Runs FastPG clustering.
- Generates UMAPs, heatmaps, summary tables, cluster proportions, and optional clustered FCS exports.

## Repository Layout

```text
Spectre/
  Spectre_wrapper.R              # Main user-facing wrapper
  README.md                      # This manual
  renv.lock                      # Minimal core-pinned renv lockfile
  scripts/                       # Active scripts only
    run_spectre_unified.R
    help_functions.R
    setup_renv_core.R
    restore_renv_core_safe.R
    check_renv_core.R
    create_test_data.R
    smoke_test_example_data.R
  example_data/                  # Small random-sampled test dataset
    data/
    metadata/
  legacy/                        # Archived old scripts, not used for new runs
```

Your real experiment files should go in local `data/` and `metadata/` folders. These folders are ignored by Git so large or private experiment data are not uploaded accidentally.

## 1. Install R and RStudio

### Windows

1. Install R 4.x from CRAN: <https://cloud.r-project.org/>
2. Install RStudio Desktop: <https://posit.co/download/rstudio-desktop/>
3. Install Rtools matching your R version if package compilation is needed:
   <https://cran.r-project.org/bin/windows/Rtools/>
4. Restart Windows after installing R/Rtools if RStudio cannot find the compiler.

### macOS

1. Install R 4.x from CRAN: <https://cloud.r-project.org/>
2. Install RStudio Desktop: <https://posit.co/download/rstudio-desktop/>
3. Install Apple Command Line Tools:

```bash
xcode-select --install
```

4. If R package compilation fails on macOS, install the CRAN-recommended Fortran toolchain for your R version from:
   <https://mac.r-project.org/tools/>

## 2. Open the Project

Open `JJ_R_Env.Rproj` in RStudio. Opening the project file is recommended because it sets the working directory correctly on both Windows and macOS.

If RStudio asks whether to activate `renv`, allow it.

## 3. Set Up the R Environment

This project supports R 4.0 through R 4.5 by pinning only the core analysis packages and letting each R minor version use its compatible CRAN/Bioconductor repositories.

Run this once in the RStudio Console:

```r
source("scripts/setup_renv_core.R")
source("scripts/check_renv_core.R")
```

If you need to restore the project later, prefer this safe wrapper instead of raw `renv::restore()`:

```r
source("scripts/restore_renv_core_safe.R")
```

The safe restore uses the project-local renv library and `clean = FALSE`, so it does not prune or delete packages from your normal user R library.

### Core pinned packages

| Package | GitHub SHA |
| --- | --- |
| Spectre | `159dc9f6d700b0dbd9fed8677cd94521c661691e` |
| FastPG | `44c9282fdd3de97e8e98a7c9165b7cc67d130e1a` |
| CytoNorm | `b1046ac76d4873acdcc82e92003e8eb919ebdd01` |

## 4. Try the Bundled Example Dataset

A small random-sampled test dataset is included under `example_data/`.

Option A: use the wrapper.

1. Open `Spectre_wrapper.R`.
2. Set:

```r
use_example_data <- TRUE
```

3. Click **Source**.

Option B: run the smoke test script.

```r
source("scripts/smoke_test_example_data.R")
```

Example outputs are written to `example_results/` or `example_results_smoke/`. These folders are ignored by Git.

## 5. Prepare Your Own Data

Create this folder structure:

```text
Spectre/
  data/
    Sample_01.fcs
    Sample_02.fcs
  metadata/
    sample.details.csv
    ORIGINAL MARKERS.csv
```

The pipeline also accepts `ORIGINAL MARKERS.csv` inside `data/` for backward compatibility, but `metadata/` is recommended.

### sample.details.csv

Required columns:

| Column | Meaning |
| --- | --- |
| `FileName` | Exact FCS filename, including `.fcs` |
| `Sample` | Sample name used in plots and summaries |
| `Group` | Experimental group, such as `Control` or `Treatment` |
| `Batch` | Batch, run, or acquisition ID |
| `Donor` | Donor or subject ID |

Optional but recommended:

| Column | Meaning |
| --- | --- |
| `Cells per sample` | Original or sampled cell count |

### ORIGINAL MARKERS.csv

This file needs at least two columns:

| Column position | Meaning |
| --- | --- |
| First column | Instrument/channel name from the FCS file |
| Second column | Clean marker name to use in analysis |

Example:

```csv
Channel name,markers
BUV395-A_CD3,CD3
BUV661-A_CD4,CD4
BV570-A_CD45RO,CD45RO
```

## 6. Run a Real Analysis

1. Put FCS files in `data/`.
2. Put `sample.details.csv` and `ORIGINAL MARKERS.csv` in `metadata/`.
3. Open `Spectre_wrapper.R`.
4. Keep:

```r
use_example_data <- FALSE
```

5. Edit only the `settings <- list(...)` section.
6. Click **Source** in RStudio.

## 7. Important Wrapper Settings

### Core settings

```r
phenok = 100
flow_type = "aurora"
cofactor = 2000
random_seed = 42
umap_cells = 100000
```

Common cofactors:

| Data type | Typical cofactor |
| --- | --- |
| CyTOF | `5` |
| Aurora / spectral flow | `2000` |
| Conventional flow | `200` |

### Batch alignment

No batch alignment:

```r
batch_align = FALSE
batch_controls = character(0)
```

Batch alignment with control samples:

```r
batch_align = TRUE
batch_controls = c("BatchCtrl_1", "BatchCtrl_2")
```

Batch alignment without controls, using all samples:

```r
batch_align = TRUE
batch_controls = character(0)
```

### Optional filters

Use exact column names after transformation. For names containing spaces or symbols, wrap the column name in backticks.

```r
analysis_filters = c(
  "CD3_asinh > 1",
  "`FSC-H` > `FSC-A` * 0.85 & `FSC-H` < `FSC-A` * 1.15"
)
```

### Equal downsampling across samples

```r
balance_samples = TRUE
cells_per_sample = NULL
```

`NULL` uses the smallest sample size after filtering.

### Marker subset for clustering

Use all transformed/aligned markers:

```r
clustering_markers = NULL
```

Use selected markers:

```r
clustering_markers = c("CD3", "CD4", "CD8", "CD45RO")
```

## 8. Create a New Small Test Dataset

If you replace `data/` and `metadata/` with a new experiment and want to create a small test dataset from it, run:

```r
source("scripts/create_test_data.R")
```

By default this samples 500 cells per FCS file and writes:

```text
example_data/
  data/
  metadata/
```

To change the sample size, edit `cells_per_file` at the top of `scripts/create_test_data.R`.

## 9. Outputs

Default real-analysis outputs are written to:

```text
results/
  Output 1 - Data Prep/
  Output 2 - Batch Alignment/
  Output 3 - Clustering_k100/
```

Important files:

| Output | Meaning |
| --- | --- |
| `marker_mapping.csv` | Channel-to-marker matching report |
| `cell.dat_transformed.csv` | Merged metadata-added arcsinh-transformed data |
| `cell.dat_Clustered_k*.csv` | Full clustered cell table |
| `cell.dat_umap.csv` | UMAP plotting table |
| `Summary_fastPG_k*.csv` | Cluster summary table |
| `Proportions/*.csv` | Cluster proportions by sample/group/donor |
| `Proportions/*.png` | Proportion plots |
| `FCS files/` | Optional clustered FCS exports |

## 10. Troubleshooting

### RStudio cannot find packages

Run:

```r
source("scripts/setup_renv_core.R")
source("scripts/check_renv_core.R")
```

### `renv::restore()` fails with a Bioconductor or BiocVersion error

Use:

```r
source("scripts/restore_renv_core_safe.R")
```

This project intentionally avoids locking `BiocManager` and `BiocVersion` to a single R minor version.

### Metadata column is missing

Check that `sample.details.csv` contains:

```text
FileName, Sample, Group, Batch, Donor
```

If your file uses different column names, update `meta_columns` in `Spectre_wrapper.R`.

### Many marker matching warnings appear

Check that the first column of `ORIGINAL MARKERS.csv` matches the FCS channel names and that the second column contains clean marker names.

### The run is slow

For a quick test, use:

```r
umap_cells = 2000
do_marker_umaps = FALSE
do_fcs_export = FALSE
```

For the final run, turn those outputs back on if needed.

## 11. Development Notes

Current scripts live in `scripts/`. Historical scripts were moved to `legacy/` and are not used by the current workflow.

The real `data/`, `metadata/`, `results/`, and `example_results*/` folders are ignored by Git. The small bundled `example_data/` folder is tracked for testing and onboarding.
