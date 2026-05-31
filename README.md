# Spectre Cytometry Analysis Pipeline

이 repository는 FCS 기반 cytometry 데이터를 Spectre, FastPG, CytoNorm으로 분석하기 위한 R pipeline입니다. Wetlab 사용자는 `Spectre_wrapper_Anjali2.R`의 `SETTINGS` 블록만 수정한 뒤 실행하면 됩니다.

지원하는 분석 방식은 세 가지입니다.

- Batch control이 있는 경우: 지정한 control sample로 CytoNorm model을 학습합니다.
- Batch control이 없는 경우: 전체 sample을 이용해 CytoNorm alignment를 수행합니다.
- Batch alignment를 하지 않는 경우: arcsinh-transformed marker를 바로 clustering합니다.

R 환경은 R 4.0부터 R 4.5까지 사용할 수 있도록 구성했습니다. 전체 dependency tree를 하나의 R minor version에 고정하지 않고, 핵심 분석 package인 `Spectre`, `FastPG`, `CytoNorm`만 GitHub SHA로 고정합니다.

## Quick Start

1. RStudio에서 `JJ_R_Env.Rproj`를 엽니다.
2. FCS 파일을 `data/` 폴더에 넣습니다.
3. Metadata 파일을 `metadata/` 폴더에 넣습니다.
4. `Spectre_wrapper_Anjali2.R`의 `SETTINGS` 블록만 수정합니다.
5. R console에서 아래 순서대로 실행합니다.

```r
source("scripts/setup_renv_core.R")
source("scripts/check_renv_core.R")
source("Spectre_wrapper_Anjali2.R")
```

이미 package 설치가 되어 있고 project library만 복원하고 싶다면 raw `renv::restore()` 대신 아래 wrapper를 사용하세요.

```r
source("scripts/restore_renv_core_safe.R")
```

이 safe restore wrapper는 이 project 안의 `renv/library/...`에만 restore합니다. `clean = FALSE`를 사용하므로 사용자의 원래 R user library를 삭제하거나 prune하지 않습니다.

## Input 파일 준비

아래 구조로 파일을 준비합니다.

```text
Spectre/
  data/
    sample_001.fcs
    sample_002.fcs
    ORIGINAL MARKERS.csv
  metadata/
    sample.details.csv
```

`sample.details.csv`에는 최소한 아래 column이 있어야 합니다.

- `FileName`: `.fcs` 확장자를 제외한 FCS filename 또는 Spectre가 읽는 embedded filename.
- `Sample`: sample ID.
- `Group`: experimental group.
- `Batch`: batch/run ID.
- `Donor`: donor ID.

`ORIGINAL MARKERS.csv`에는 최소한 두 column이 있어야 합니다.

- 첫 번째 column: instrument/channel name.
- 두 번째 column: 분석에 사용할 marker name.

분석 결과는 `Output 1 - Data Prep`, `Output 2 - Batch Alignment`, `Output 3 - Clustering_k...` 폴더에 저장됩니다. 이 결과 폴더들은 GitHub에 올리지 않습니다.

## Wrapper 설정법

`Spectre_wrapper_Anjali2.R`를 열고 `settings <- list(...)` 부분만 수정합니다.

기본 분석 설정:

```r
phenok = 100
flow_type = "aurora"   # cytof, aurora, or flow
cofactor = 2000
umap_cells = 100000
```

Batch alignment를 하지 않을 때:

```r
batch_align = FALSE
batch_controls = character(0)
```

Batch control sample이 있을 때:

```r
batch_align = TRUE
batch_controls = c("control_sample_1", "control_sample_2")
```

Batch control sample은 없지만 전체 sample로 CytoNorm alignment를 하고 싶을 때:

```r
batch_align = TRUE
batch_controls = character(0)
```

Optional gating/filtering:

```r
analysis_filters = c(
  "CD3_asinh > 1.0",
  "`LIVE DEAD NIR-A_LiveDead_asinh` < 2.0",
  "`FSC-H` > `FSC-A` * 0.85 & `FSC-H` < `FSC-A` * 1.15"
)
```

Sample별 cell 수를 맞춰 downsampling하고 싶을 때:

```r
balance_samples = TRUE
cells_per_sample = NULL  # 가장 cell 수가 적은 sample 기준으로 맞춤
```

Clustering에 사용할 marker를 제한하고 싶을 때:

```r
clustering_markers = NULL

# 또는 marker name / transformed column name 지정
clustering_markers = c("CD3", "CD4", "CD8")
```

## R 4.x renv 정책

기존 full `renv.lock`은 R 4.4.1과 Bioconductor 3.19에 묶여 있어서, 다른 R 4.x minor version에서 `BiocVersion`/`BiocManager` 충돌로 `renv::restore()`가 실패할 수 있었습니다.

새 구조는 R minor version에 맞는 Bioconductor repository를 자동으로 선택합니다.

| R version | Bioconductor repositories |
| --- | --- |
| R 4.0.x | BioC 3.12 |
| R 4.1.x | BioC 3.14 |
| R 4.2.x | BioC 3.16 |
| R 4.3.x | BioC 3.18 |
| R 4.4.x | BioC 3.20 |
| R 4.5.x | BioC 3.22 |

정확히 고정되는 core packages:

| Package | Version | GitHub SHA |
| --- | --- | --- |
| Spectre | 1.3.0 | `159dc9f6d700b0dbd9fed8677cd94521c661691e` |
| FastPG | 0.0.8 | `44c9282fdd3de97e8e98a7c9165b7cc67d130e1a` |
| CytoNorm | 2.0.9 | `b1046ac76d4873acdcc82e92003e8eb919ebdd01` |

## 주요 파일

- `Spectre_wrapper_Anjali2.R`: 사용자용 wrapper. 이 파일의 `SETTINGS`만 수정합니다.
- `scripts/run_spectre_unified.R`: batch control 있음/없음 모두 처리하는 통합 pipeline.
- `scripts/help_functions.R`: pipeline에서 사용하는 helper functions.
- `scripts/setup_renv_core.R`: R 4.x 호환 project-local environment bootstrap.
- `scripts/restore_renv_core_safe.R`: 원래 R 환경을 해치지 않는 safe restore wrapper.
- `scripts/check_renv_core.R`: core pinned package SHA 검증.
- `scripts/renv_core_repos.R`: R 4.x / Bioconductor repository helper.
- `renv.lock`: core package만 포함한 minimal lockfile.
- `renv.lock.full.R-4.4.1.backup`: 예전 full lockfile reference backup.

`scripts/`와 `scripts_noref/`의 legacy files는 비교용으로 보존했습니다. 새 분석은 `Spectre_wrapper_Anjali2.R`를 사용하세요.

## GitHub 업로드 체크리스트

GitHub에 올릴 파일:

```text
.Rprofile
.gitignore
README.md
JJ_R_Env.Rproj
Spectre_wrapper_Anjali2.R
renv.lock
renv.lock.full.R-4.4.1.backup
renv/activate.R
renv/settings.json
scripts/
scripts_noref/
```

GitHub에 올리지 않을 파일:

```text
data/
metadata/
Output*/
output/
renv/library/
renv/staging/
*.fcs
*.FCS
*.RData
*.csv
*.rds
*.png
*.pdf
```

처음 GitHub에 올릴 때 사용할 수 있는 command:

```bash
git init
git add .Rprofile .gitignore README.md JJ_R_Env.Rproj Spectre_wrapper_Anjali2.R
git add renv.lock renv.lock.full.R-4.4.1.backup renv/activate.R renv/settings.json
git add scripts scripts_noref
git commit -m "Prepare Spectre pipeline for R 4.x renv setup"
```

GitHub repository를 만든 뒤에는 GitHub가 안내하는 remote add / push command를 이어서 실행하면 됩니다.

## Troubleshooting

`check_renv_core.R`에서 package가 없다고 나오면:

```r
source("scripts/setup_renv_core.R")
source("scripts/check_renv_core.R")
```

Restore가 필요하면 raw `renv::restore()` 대신 아래 명령을 권장합니다.

```r
source("scripts/restore_renv_core_safe.R")
```

Metadata column이 없다는 error가 나오면 `Spectre_wrapper_Anjali2.R`의 `meta_columns` 설정과 `sample.details.csv`의 column name이 정확히 일치하는지 확인하세요.

Marker matching warning이 많이 나오면 `ORIGINAL MARKERS.csv`의 첫 두 column이 channel name과 marker name인지 확인하세요.

R 4.0 또는 R 4.1에서 dependency 설치가 실패할 수 있습니다. 이 경우 core package SHA는 유지되지만, 오래된 R에서 최신 dependency가 지원되지 않는 것이 원인일 수 있습니다. 가능하면 R 4.2 이상을 권장합니다.
