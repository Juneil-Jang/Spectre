# Spectre Cytometry Analysis Pipeline

Wet-lab users do **not** need to edit R code for routine analyses.

The simplest workflow is:

1. Install R.
2. Double-click the setup file once.
3. Edit `config.xlsx`.
4. Double-click the run file.

## Quick Start

### Windows

1. Install R 4.x from <https://cloud.r-project.org/>.
2. If package installation asks for compilers, install Rtools from <https://cran.r-project.org/bin/windows/Rtools/>.
3. Double-click `SETUP_WINDOWS.bat`.
4. Open `config.xlsx` in Excel.
5. Keep `use_example_data = TRUE` for the first test run.
6. Double-click `RUN_WINDOWS.bat`.

### macOS

1. Install R 4.x from <https://cloud.r-project.org/>.
2. Install Apple Command Line Tools:

```bash
xcode-select --install
```

3. If package compilation fails, install the CRAN-recommended macOS toolchain from <https://mac.r-project.org/tools/>.
4. Double-click `SETUP_MAC.command`.
5. Open `config.xlsx` in Excel, Numbers, or LibreOffice.
6. Keep `use_example_data = TRUE` for the first test run.
7. Double-click `RUN_MAC.command`.

If macOS blocks the `.command` files, right-click the file and choose **Open**. If it still refuses to run, open Terminal in this folder and run:

```bash
chmod +x SETUP_MAC.command RUN_MAC.command
```

## Main Files

| File or folder | Purpose |
| --- | --- |
| `config.xlsx` | Main user settings file. Edit the yellow `Value` cells. |
| `SETUP_WINDOWS.bat` | One-time Windows setup. |
| `RUN_WINDOWS.bat` | Windows double-click analysis runner. |
| `SETUP_MAC.command` | One-time macOS setup. |
| `RUN_MAC.command` | macOS double-click analysis runner. |
| `example_data/` | Small random-sampled FCS test dataset. |
| `data/` | Put your real `.fcs` files here. Ignored by Git. |
| `metadata/` | Put your real metadata CSV files here. Ignored by Git. |
| `results/` | Default output folder for real analyses. Ignored by Git. |
| `scripts/` | Active pipeline scripts. |
| `legacy/` | Archived old scripts for reference only. |

`Spectre_wrapper.R` is still provided for RStudio users, but it simply reads `config.xlsx`. You should not need to edit it.

## First Test Run

The included `config.xlsx` starts with:

```text
use_example_data = TRUE
```

This runs the bundled small dataset in `example_data/` and writes output to:

```text
example_results/
```

This is the recommended first test after setup.

## Running Your Own Experiment

Create this structure:

```text
Spectre/
  data/
    Sample_01.fcs
    Sample_02.fcs
  metadata/
    sample.details.csv
    ORIGINAL MARKERS.csv
```

Then open `config.xlsx` and change:

```text
use_example_data = FALSE
data_dir = data
metadata_dir = metadata
output_dir = results
```

Double-click the run file for your operating system.

## Required Metadata Files

### `sample.details.csv`

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

If your columns use different names, edit these fields in `config.xlsx`:

```text
sample_column
group_column
batch_column
donor_column
```

### `ORIGINAL MARKERS.csv`

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

The recommended location is `metadata/ORIGINAL MARKERS.csv`. For backward compatibility, the pipeline also looks in `data/`.

## Important `config.xlsx` Settings

Edit only the yellow `Value` cells in the `Settings` sheet.

### Data selection

| Setting | Typical value |
| --- | --- |
| `use_example_data` | `TRUE` for the bundled example, `FALSE` for your own data |
| `data_dir` | `data` |
| `metadata_dir` | `metadata` |
| `output_dir` | `results` |

### Analysis

| Setting | Typical value |
| --- | --- |
| `phenok` | `100` for real analyses, capped at `10` in example mode |
| `flow_type` | `aurora`, `flow`, or `cytof` |
| `cofactor` | `2000` for Aurora, `200` for flow, `5` for CyTOF |
| `random_seed` | `42` |
| `umap_cells` | `100000` for real analyses |

### Batch alignment

No batch alignment:

```text
batch_align = FALSE
batch_controls =
```

Batch alignment with control samples:

```text
batch_align = TRUE
batch_controls = BatchCtrl_1, BatchCtrl_2
```

Batch alignment without controls, using all samples:

```text
batch_align = TRUE
batch_controls =
```

### Optional filters

Use exact transformed column names. Separate multiple filters with semicolons or line breaks.

Example:

```text
analysis_filters = CD3_asinh > 1; `FSC-H` > `FSC-A` * 0.85 & `FSC-H` < `FSC-A` * 1.15
```

### Clustering marker subset

Use all markers:

```text
clustering_markers =
```

Use selected markers:

```text
clustering_markers = CD3, CD4, CD8, CD45RO
```

## Outputs

Real-analysis outputs are written to `results/` by default:

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

## Creating a New Small Test Dataset

After setup, replace `data/` and `metadata/` with a new experiment and run:

```r
source("scripts/create_test_data.R")
```

This samples 500 cells per FCS file and writes:

```text
example_data/
  data/
  metadata/
```

Advanced users can edit `cells_per_file` at the top of `scripts/create_test_data.R`.

## RStudio Is Optional

RStudio is helpful for troubleshooting but is not required for routine runs.

If you do use RStudio:

1. Open `JJ_R_Env.Rproj`.
2. Edit `config.xlsx`.
3. Source `Spectre_wrapper.R`.

Do not edit `Spectre_wrapper.R` unless you are developing the pipeline.

## R Environment Policy

The project supports R 4.0 through R 4.5 by pinning only the core analysis packages and letting each R minor version use compatible CRAN/Bioconductor repositories.

Core pinned packages:

| Package | GitHub SHA |
| --- | --- |
| Spectre | `159dc9f6d700b0dbd9fed8677cd94521c661691e` |
| FastPG | `44c9282fdd3de97e8e98a7c9165b7cc67d130e1a` |
| CytoNorm | `b1046ac76d4873acdcc82e92003e8eb919ebdd01` |

The setup scripts install packages into the project-local renv library. They do not clean or prune your normal user R library.

For manual setup in R:

```r
source("scripts/setup_renv_core.R")
source("scripts/check_renv_core.R")
```

For manual safe restore:

```r
source("scripts/restore_renv_core_safe.R")
```

## Troubleshooting

### The run file says Rscript was not found

Install R 4.x from <https://cloud.r-project.org/>. On Windows, restart after installing R if the runner still cannot find it.

### `config.xlsx` cannot be read

Run the setup file once. The setup installs `openxlsx`, which is used to read the Excel config.

### Preflight check failed

Read the listed item(s). The preflight checker usually catches:

- Missing `data/` or `metadata/` folder.
- No `.fcs` files.
- Missing `sample.details.csv`.
- Missing required metadata columns.
- FCS filenames in metadata that do not match files in `data/`.
- Batch control sample names that are not present in metadata.

### Package installation fails

Windows users may need Rtools. macOS users may need Apple Command Line Tools and the CRAN Fortran toolchain. After installing system tools, run the setup file again.

### The analysis is slow

For a quick test, set:

```text
umap_cells = 2000
do_marker_umaps = FALSE
do_fcs_export = FALSE
```

Turn those outputs back on for the final run if needed.
