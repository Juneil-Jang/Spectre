# Spectre Cytometry Analysis Pipeline

Wet-lab users do **not** need to edit R code for routine analyses.

The simplest workflow is:

1. Install R.
2. Double-click the setup file once.
3. Run the bundled example once.
4. Create one portable folder per experiment.
5. Put data and metadata in that experiment folder.
6. Double-click the experiment run file.

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
chmod +x SETUP_MAC.command RUN_MAC.command CREATE_EXPERIMENT_MAC.command
```

## Main Files

| File or folder | Purpose |
| --- | --- |
| `config.xlsx` | Main user settings file. Edit the yellow `Value` cells. |
| `SETUP_WINDOWS.bat` | One-time Windows setup. |
| `RUN_WINDOWS.bat` | Windows double-click analysis runner. |
| `CREATE_EXPERIMENT_WINDOWS.bat` | Creates a separate portable Windows experiment folder. |
| `SETUP_MAC.command` | One-time macOS setup. |
| `RUN_MAC.command` | macOS double-click analysis runner. |
| `CREATE_EXPERIMENT_MAC.command` | Creates a separate portable macOS experiment folder. |
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

### Recommended: one portable folder per experiment

Keep the downloaded `Spectre/` folder as the central pipeline folder. It contains the code, R environment, setup files, and bundled example data. Then create a separate folder for each real experiment.

```text
Documents/
  Spectre/                         central pipeline folder
    SETUP_WINDOWS.bat
    CREATE_EXPERIMENT_WINDOWS.bat
    scripts/
    renv/

  Experiment_01/                   portable experiment folder
    config.xlsx
    RUN_SPECTRE_WINDOWS.bat
    RUN_SPECTRE_MAC.command
    spectre_pipeline_path.txt
    data/
      Sample_01.fcs
      Sample_02.fcs
    metadata/
      sample.details.csv
      ORIGINAL MARKERS.csv
    results/
```

Windows:

1. In the central `Spectre/` folder, double-click `SETUP_WINDOWS.bat` once.
2. In the central `Spectre/` folder, double-click `CREATE_EXPERIMENT_WINDOWS.bat`.
3. Paste or type the full path for the new experiment folder, for example:

```text
C:\Users\YourName\Documents\Experiment_01
```

4. Put all `.fcs` files into `Experiment_01/data/`.
5. Put `sample.details.csv` and `ORIGINAL MARKERS.csv` into `Experiment_01/metadata/`.
6. Open `Experiment_01/config.xlsx` and edit the yellow `Value` cells.
7. Double-click `Experiment_01/RUN_SPECTRE_WINDOWS.bat`.

macOS:

1. In the central `Spectre/` folder, double-click `SETUP_MAC.command` once.
2. In the central `Spectre/` folder, double-click `CREATE_EXPERIMENT_MAC.command`.
3. Paste or type the full path for the new experiment folder, for example:

```text
/Users/YourName/Documents/Experiment_01
```

4. Put all `.fcs` files into `Experiment_01/data/`.
5. Put `sample.details.csv` and `ORIGINAL MARKERS.csv` into `Experiment_01/metadata/`.
6. Open `Experiment_01/config.xlsx` and edit the yellow `Value` cells.
7. Double-click `Experiment_01/RUN_SPECTRE_MAC.command`.

If macOS blocks the generated experiment runner, right-click `RUN_SPECTRE_MAC.command` and choose **Open**. If needed, open Terminal inside the experiment folder and run:

```bash
chmod +x RUN_SPECTRE_MAC.command
```

### What gets copied into the experiment folder

The experiment creator writes these files:

| File or folder | Purpose |
| --- | --- |
| `config.xlsx` | Experiment-specific settings. |
| `data/` | Put this experiment's `.fcs` files here. |
| `metadata/` | Put this experiment's metadata CSV files here. |
| `results/` | Outputs are written here. |
| `RUN_SPECTRE_WINDOWS.bat` | Windows runner for this experiment folder. |
| `RUN_SPECTRE_MAC.command` | macOS runner for this experiment folder. |
| `spectre_pipeline_path.txt` | Stores the path to the central `Spectre/` pipeline folder. |
| `README_EXPERIMENT.md` | Short reminder for the experiment folder. |

### Important folder rules

Do **not** copy only `RUN_WINDOWS.bat` or `RUN_MAC.command` into another folder. Those files are for the central `Spectre/` folder and expect `scripts/`, `renv/`, and `config.xlsx` to be beside them.

Use the generated `RUN_SPECTRE_WINDOWS.bat` or `RUN_SPECTRE_MAC.command` inside each experiment folder instead. These portable runners know where the central pipeline folder is because they read `spectre_pipeline_path.txt`.

You can move an experiment folder after it is created. Its `config.xlsx`, `data/`, `metadata/`, and `results/` stay relative to the experiment folder.

Do not move the central `Spectre/` pipeline folder after creating experiments. If you do move it, either edit `spectre_pipeline_path.txt` in each experiment folder or run `CREATE_EXPERIMENT_*` again to create fresh runners.

Updating the central `Spectre/` folder updates the code used by all experiment folders. Each experiment still keeps its own `config.xlsx` and `results/`.

### Alternative: run inside the central Spectre folder

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
| `*.pdf` beside `*.png` | PDF copies of generated plots when `do_pdf_plots = TRUE` |
| `FCS files/` | Optional clustered FCS exports |

Set `do_pdf_plots = FALSE` in `config.xlsx` if you only want PNG plot files.

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

The setup scripts install a minimal direct package set into the project-local renv library:

```text
Spectre, FastPG, CytoNorm, ggplot2, dplyr, data.table, openxlsx, png
```

R will still install required dependency packages automatically. Those dependencies are not pinned in `renv.lock`; each R 4.x minor version uses its compatible CRAN/Bioconductor repositories. `BiocManager` and `BiocVersion` are not installed or pinned by the setup script.

The setup scripts do not clean or prune your normal user R library.

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

Run the setup file once. The setup installs the minimal direct package set, including `openxlsx`, which is used to read the Excel config.

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
