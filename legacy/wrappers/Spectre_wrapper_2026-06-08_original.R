################################################################################
### Standardized Spectre Analysis Pipeline (Refactored)
################################################################################
# ==============================================================================
# 1. User Settings (Adjustable Variables)
# ==============================================================================
PrimaryDirectory <- "/media/user/3c228b31-7bfb-4492-8124-3f264724ee0a/D/Metformin/New/CD4_export/"  # 최상위 작업 폴더
InputFolder      <- "data"                  # FCS 파일 폴더
MetaFolder       <- "metadata"              # 메타데이터 폴더

phenok           <- 100                     # 클러스터링 세밀도 (보통 30~100 권장)
coFactor         <- 2000                    # Aurora 장비용 Asinh 변환 계수
flowType         <- "aurora"
subsample_size   <- 100000                  # UMAP 시각화용 샘플링 크기 (메모리 폭발 방지)

metaFile         <- "sample.details.csv"
markerFile       <- "ORIGINAL MARKERS.csv"
meta_col         <- c('Sample', 'Group', 'Batch', 'Donor')
plot.against     <- "CD45RO_asinh"  # 초기 QC 플롯 기준 마커

# Batch Alignment Reference Samples
do.batchAlign = F
ref.ctrls     = NULL

# ==============================================================================
# 2. Environment Setup & Directory Mapping (No more setwd() abuse)
# ==============================================================================
message(">>> Step 2: Environment Setup...")
library(Spectre)
library(dplyr)
library(FastPG)
library(CytoNorm)
library(openxlsx)
library(data.table)
library(ggplot2)

# Thread optimization
threads <- getDTthreads()
message(paste0("Using ", threads, " threads for data.table."))

setwd(PrimaryDirectory)

# Directory Paths
dir_data   <- file.path(PrimaryDirectory, InputFolder)
dir_meta   <- file.path(PrimaryDirectory, MetaFolder)
dir_out1   <- file.path(PrimaryDirectory, "Output 1 - Data Prep")
dir_out2   <- file.path(PrimaryDirectory, "Output 2 - Batch Alignment")
dir_out3   <- file.path(PrimaryDirectory, paste0("Output 3 - Clustering_k", phenok))

# Create directories safely
lapply(c(dir_out1, dir_out2, dir_out3), dir.create, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 3. Data Import & Metadata Integration
# ==============================================================================
message(">>> Step 3: Data Import...")
data.list <- read.cytofFiles.custom(file.loc = dir_data, file.type = ".fcs", do.embed.file.names = TRUE)
cell.dat  <- Spectre::do.merge.files(dat = data.list)
rm(data.list); gc() # 메모리 확보

# Read Metadata
meta.dat <- read.csv(file.path(dir_meta, metaFile), sep = ",")
cell.dat <- do.add.cols(cell.dat, "FileName", meta.dat, "FileName", rmv.ext = TRUE)

sample.col <- meta_col[1]
group.col  <- meta_col[2]
batch.col  <- meta_col[3]  
donor.col  <- meta_col[4]

# ==============================================================================
# 4. Data Transformation & Cleaning (Robust Marker Matching)
# ==============================================================================
message(">>> Step 4: Arcsinh Transformation & Robust Marker Matching...")

# 1. ORIGINAL MARKERS.csv 불러오기
markers_info <- data.table::fread(file.path(dir_data, markerFile))
col_channel <- names(markers_info)[1] # 첫 번째 열 (기기 채널명)
col_marker  <- names(markers_info)[2] # 두 번째 열 (생물학적 마커명)

# 2. 텍스트 정규화 함수 (웻랩 기상천외 문자열 방어용)
# 기능: 대문자 변환 -> 'COMP' 단어 제거 -> 알파벳과 숫자 빼고 전부 삭제 (공백, 특수문자, 깨진문자 제거)
clean_string <- function(x) {
  x <- toupper(as.character(x))
  x <- gsub("COMP[-_ ]?", "", x)  # Comp-, Comp_ 등 제거
  x <- gsub("[^A-Z0-9]", "", x)   # 오직 알파벳과 숫자만 남김
  return(x)
}

# 3. 채널명 매칭 준비
csv_channels_clean <- clean_string(markers_info[[col_channel]])
dat_channels_clean <- clean_string(names(cell.dat))

# 4. 매칭되는 컬럼 찾기 및 치환
raw.marker.cols <- c() # 분석에 사용할 마커들의 최종 이름 목록

for (i in seq_len(nrow(markers_info))) {
  target_clean <- csv_channels_clean[i]
  bio_marker   <- markers_info[[col_marker]][i]
  
  # 생물학적 마커 이름도 숨겨진 특수문자(Mac 찌꺼기) 제거 및 공백 다듬기
  bio_marker <- stringr::str_replace_all(bio_marker, "[^[:print:]]", "")
  bio_marker <- stringr::str_trim(bio_marker)
  
  # cell.dat의 열 이름 중 정규화된 이름이 일치하는 인덱스 찾기
  match_idx <- which(dat_channels_clean == target_clean)
  
  if (length(match_idx) > 0) {
    old_name <- names(cell.dat)[match_idx[1]]
    
    # 새로운 이름 생성: "채널명_마커명" (예: BV510-A_CCR5)
    # (만약 생물학적 마커명으로만 아예 덮어씌우려면 new_name <- bio_marker 로 변경하세요)
    new_name <- bio_marker
    
    # 데이터테이블 컬럼 이름 치환
    data.table::setnames(cell.dat, old_name, new_name)
    
    # 마커 리스트에 추가
    raw.marker.cols <- c(raw.marker.cols, new_name)
  } else {
    warning(paste0("⚠️ [매칭 실패] CSV의 '", markers_info[[col_channel]][i], "' 채널을 FCS 데이터에서 찾을 수 없어 건너뜁니다."))
  }
}

# 5. 매칭된 마커들만 Arcsinh 변환
message(paste0("Total ", length(raw.marker.cols), " markers perfectly matched and renamed!"))
cell.dat <- do.asinh(cell.dat, use.cols = raw.marker.cols, cofactor = coFactor)
cell.dat <- do.asinh(cell.dat, use.cols = 'LIVE DEAD NIR-A_LiveDead', cofactor = coFactor)

transf.cols <- paste0(raw.marker.cols, "_asinh")

# Save Transformed Data
fwrite(cell.dat, file.path(dir_out1, "cell.dat_transformed.csv"))

clustering.cols <- transf.cols

cell.sub = cell.dat
cell.sub$Sample %>% table

print(paste(names(cell.sub)[which(names(cell.sub) == plot.against)], "Exist!"))

for(i in transf.cols){
  make.colour.plot(cell.sub, i, col.min.threshold = 0, plot.against, path = dir_out1, fast = T)
}

make.colour.plot(cell.sub, x.axis = "SSC-A", y.axis = "FSC-A", path = dir_out1, fast = T)
make.colour.plot(cell.sub, x.axis = "FSC-H", y.axis = "FSC-A", path = dir_out1, fast = T)
make.colour.plot(cell.sub, x.axis = "CD3_asinh", y.axis = "LIVE DEAD NIR-A_LiveDead_asinh", path = dir_out1, fast = T)

# ==============================================================================
# 6. Clustering (FastPG)
# ==============================================================================
message(">>> Step 6: Clustering (FastPG)...")

clustering.cols =  clustering.cols[c(2,6:9,11:25)] #####################################################################################
clustering.cols = clustering.cols[-7] ##################################################################################################

data_fastPG <- as.matrix(cell.sub %>% dplyr::select(clustering.cols))

data_fastPG <- as.matrix(cell.sub %>% dplyr::select(all_of(clustering.cols)))
output_fastPG <- FastPG::fastCluster(data = data_fastPG, k = phenok, num_threads = threads)
cell.sub$fastPG_Clusters <- output_fastPG[[2]]

fwrite(cell.sub, file.path(dir_out3, paste0("cell.dat_Clustered_k", phenok, ".csv")))

# ==============================================================================
# 7. Dimensionality Reduction (UMAP) & Visualization
# ==============================================================================
message(">>> Step 7: UMAP & Visualization...")

# [취약점 보완 3] UMAP 구동 전 메모리 폭발 방지를 위한 서브샘플링 도입
if(nrow(cell.sub) > subsample_size) {
  message(paste0("Subsampling ", subsample_size, " cells for UMAP visualization..."))
  cell.sub <- do.subsample(cell.sub, subsample_size)
} else {
  cell.sub <- cell.sub
}

cell.sub <- run.umap(cell.sub, use.cols = clustering.cols)
fwrite(cell.sub, file.path(dir_out3, paste0("cell.dat_Clustered_k", phenok, "_UMAP.csv")))

# Heatmap
exp <- do.aggregate(as.data.table(cell.sub), clustering.cols, by = "fastPG_Clusters")
make.pheatmap(exp, "fastPG_Clusters", plot.cols = clustering.cols, normalise = TRUE, 
              standard.colours = "rev(RdBu)", path = dir_out3)

# Plots
# ==============================================================================
# 7b. Organized Plot Export -- Spectre-compatible version
# ==============================================================================
message(">>> Step 7b: Organized plot export...")

cluster_col <- "fastPG_Clusters"

# 모든 그림을 dir_out3/Plots 아래에 종류별로 분리 저장
dir_plots      <- file.path(dir_out3, "Plots")
dir_umap       <- file.path(dir_plots, "01_UMAP_overview")
dir_split      <- file.path(dir_plots, "02_UMAP_split_by_metadata")
dir_expr       <- file.path(dir_plots, "03_UMAP_marker_expression")
dir_multi      <- file.path(dir_plots, "04_Multi_plots")
dir_multi_expr <- file.path(dir_multi, "Marker_by_Sample")
dir_prop       <- file.path(dir_plots, "05_Proportions")

lapply(
  c(dir_plots, dir_umap, dir_split, dir_expr, dir_multi, dir_multi_expr, dir_prop),
  dir.create,
  showWarnings = FALSE,
  recursive = TRUE
)

safe_name <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x <- gsub("[^A-Za-z0-9가-힣_.-]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  ifelse(is.na(x) | x == "", "NA", x)
}

sort_levels <- function(x) {
  ux <- unique(as.character(x))
  ux <- ux[!is.na(ux)]
  nx <- suppressWarnings(as.numeric(ux))
  if (length(ux) > 0 && all(!is.na(nx))) {
    ux[order(nx)]
  } else {
    sort(ux)
  }
}

check_cols <- function(dat, cols, context = "plot") {
  missing <- setdiff(cols, names(dat))
  if (length(missing) > 0) {
    warning(
      paste0(
        "[", context, "] Missing columns skipped: ",
        paste(missing, collapse = ", ")
      )
    )
  }
  intersect(cols, names(dat))
}

required.plot.cols <- check_cols(
  cell.sub,
  c("UMAP_X", "UMAP_Y", cluster_col),
  context = "UMAP"
)
if (length(required.plot.cols) < 3) {
  stop("UMAP_X, UMAP_Y, or fastPG_Clusters is missing. Cannot generate UMAP plots.")
}

# ------------------------------------------------------------------------------
# 1) UMAP overview: cluster / group / donor / sample
# ------------------------------------------------------------------------------
overview.cols <- check_cols(
  cell.sub,
  c(cluster_col, group.col, donor.col, sample.col),
  context = "UMAP overview"
)

for (plot_col in overview.cols) {
  make.colour.plot(
    cell.sub,
    "UMAP_X",
    "UMAP_Y",
    plot_col,
    col.type  = "factor",
    add.label = identical(plot_col, cluster_col),
    path      = dir_umap,
    filename  = paste0("UMAP_", safe_name(plot_col), ".png"),
    fast      = TRUE
  )
}

# ------------------------------------------------------------------------------
# 2) Split UMAP: Group / Donor / Sample별 cluster UMAP 저장
# ------------------------------------------------------------------------------
plot_cluster_by_level <- function(dat, split_col, out_dir) {
  if (!split_col %in% names(dat)) {
    warning(paste0("[Split UMAP] Column not found: ", split_col))
    return(invisible(NULL))
  }
  
  split_dir <- file.path(out_dir, safe_name(split_col))
  dir.create(split_dir, showWarnings = FALSE, recursive = TRUE)
  
  levs <- sort_levels(dat[[split_col]])
  
  for (lev in levs) {
    idx <- !is.na(dat[[split_col]]) & as.character(dat[[split_col]]) == lev
    dat.sub <- dat[idx, ]
    
    if (nrow(dat.sub) == 0) next
    
    make.colour.plot(
      dat.sub,
      "UMAP_X",
      "UMAP_Y",
      cluster_col,
      col.type  = "factor",
      add.label = TRUE,
      path      = split_dir,
      filename  = paste0("UMAP_", safe_name(split_col), "_", safe_name(lev), ".png"),
      fast      = TRUE
    )
  }
  
  invisible(NULL)
}

for (split_col in check_cols(cell.sub, c(group.col, donor.col, sample.col), context = "Split UMAP")) {
  plot_cluster_by_level(cell.sub, split_col, dir_split)
}

# ------------------------------------------------------------------------------
# 3) Marker expression UMAP
# ------------------------------------------------------------------------------
expr.cols <- check_cols(cell.sub, clustering.cols, context = "Marker expression")

for (marker_col in expr.cols) {
  marker.vals <- suppressWarnings(as.numeric(cell.sub[[marker_col]]))
  marker.vals <- marker.vals[is.finite(marker.vals)]
  
  if (length(marker.vals) == 0) {
    warning(paste0("[Marker expression] No finite values: ", marker_col))
    next
  }
  
  # Spectre::make.colour.plot() expects col.min.threshold as a quantile
  # probability in [0, 1], not as an actual marker-expression value.
  # 0.01 means: clip the lowest 1% of values for colour scaling.
  make.colour.plot(
    cell.sub,
    "UMAP_X",
    "UMAP_Y",
    marker_col,
    col.min.threshold = 0.01,
    path              = dir_expr,
    filename          = paste0("UMAP_expr_", safe_name(marker_col), ".png"),
    fast              = TRUE
  )
}

# ------------------------------------------------------------------------------
# 4) Multi plots: faceted UMAP
#    현재 Spectre 함수 호환성을 위해 색칠 column은 4번째 positional argument로 전달.
#    make.multi.plot()에는 filename 인자를 넣지 않음.
# ------------------------------------------------------------------------------
if (donor.col %in% names(cell.sub)) {
  make.multi.plot( 
    dat = cell.sub,
    x.axis ="UMAP_X",
    y.axis = "UMAP_Y",
    cluster_col,
    divide.by    = donor.col,
    col.type     = "factor",
    figure.title = "fastPG clusters by donor",
    path         = dir_multi
  )
}

if (sample.col %in% names(cell.sub)) {
  for (marker_col in expr.cols) {
    make.multi.plot(
      cell.sub,
      "UMAP_X",
      "UMAP_Y",
      marker_col,
      divide.by    = sample.col,
      figure.title = marker_col,
      path         = dir_multi_expr
    )
  }
}

# ------------------------------------------------------------------------------
# 5) Cluster proportion plots
#    CSV/PNG 모두 dir_out3/Plots/05_Proportions에 저장.
# ------------------------------------------------------------------------------
make_prop_plot <- function(dat,
                           x_col,
                           fill_col,
                           denom_col,
                           prefix,
                           title,
                           x_lab,
                           fill_lab,
                           hline = NULL,
                           plot_width = 8) {
  needed <- c(x_col, fill_col, denom_col)
  if (!all(needed %in% names(dat))) {
    warning(
      paste0(
        "[Proportion] Skipped ", prefix,
        ". Missing: ", paste(setdiff(needed, names(dat)), collapse = ", ")
      )
    )
    return(invisible(NULL))
  }
  
  df_summary <- dat %>%
    dplyr::group_by(.data[[x_col]], .data[[fill_col]]) %>%
    dplyr::summarise(n = dplyr::n(), .groups = "drop_last") %>%
    dplyr::group_by(.data[[denom_col]]) %>%
    dplyr::mutate(percent = n / sum(n) * 100) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(.data[[x_col]], .data[[fill_col]])
  
  out_csv <- file.path(dir_prop, paste0(prefix, ".csv"))
  data.table::fwrite(df_summary, out_csv)
  
  p <- ggplot(
    df_summary,
    aes(
      x    = as.factor(.data[[x_col]]),
      y    = percent,
      fill = as.factor(.data[[fill_col]])
    )
  ) +
    geom_col(width = 0.85) +
    labs(
      title = title,
      x     = x_lab,
      y     = "Percentage (%)",
      fill  = fill_lab
    ) +
    theme_bw(base_size = 12) +
    theme(
      axis.text.x     = element_text(angle = 45, hjust = 1, vjust = 1),
      panel.grid.major.x = element_blank(),
      plot.title      = element_text(face = "bold")
    )
  
  if (!is.null(hline)) {
    p <- p + geom_hline(yintercept = hline, linetype = "dashed")
  }
  
  ggsave(
    filename = file.path(dir_prop, paste0(prefix, ".png")),
    plot     = p,
    width    = plot_width,
    height   = 5.5,
    dpi      = 300
  )
  
  print(p)
  invisible(df_summary)
}

# Sample 안에서 각 cluster 비율: 각 Sample의 합이 100%
make_prop_plot(
  dat       = cell.sub,
  x_col     = sample.col,
  fill_col  = cluster_col,
  denom_col = sample.col,
  prefix    = "sample_proportion",
  title     = "Proportion of fastPG clusters per sample",
  x_lab     = "Sample",
  fill_lab  = "Cluster",
  plot_width = max(8, length(unique(cell.sub[[sample.col]])) * 0.35)
)

# Cluster 안에서 Sample 구성: 각 cluster의 합이 100%
make_prop_plot(
  dat       = cell.sub,
  x_col     = cluster_col,
  fill_col  = sample.col,
  denom_col = cluster_col,
  prefix    = "cluster_proportion_by_sample",
  title     = "Sample composition per fastPG cluster",
  x_lab     = "fastPG cluster",
  fill_lab  = "Sample",
  plot_width = max(8, length(unique(cell.sub[[cluster_col]])) * 0.25)
)

# Cluster 안에서 Group 구성: 각 cluster의 합이 100%
if (group.col %in% names(cell.sub)) {
  make_prop_plot(
    dat       = cell.sub,
    x_col     = cluster_col,
    fill_col  = group.col,
    denom_col = cluster_col,
    prefix    = "cluster_proportion_by_group",
    title     = "Group composition per fastPG cluster",
    x_lab     = "fastPG cluster",
    fill_lab  = "Group",
    hline     = 50,
    plot_width = max(8, length(unique(cell.sub[[cluster_col]])) * 0.25)
  )
}

# Cluster 안에서 Donor 구성: 각 cluster의 합이 100%
if (donor.col %in% names(cell.sub)) {
  make_prop_plot(
    dat       = cell.sub,
    x_col     = cluster_col,
    fill_col  = donor.col,
    denom_col = cluster_col,
    prefix    = "cluster_proportion_by_donor",
    title     = "Donor composition per fastPG cluster",
    x_lab     = "fastPG cluster",
    fill_lab  = "Donor",
    hline     = 75,
    plot_width = max(8, length(unique(cell.sub[[cluster_col]])) * 0.25)
  )
}

message(">>> Step 7b: Organized plot export completed.")


# ==============================================================================

message(">>> Step 8: Generating Summary Tables...")
counts <- meta.dat[, c(sample.col, 'Cells.per.sample')]
sum.dat <- create.sumtable(dat = cell.sub, 
                           sample.col = sample.col, 
                           pop.col = "fastPG_Clusters", 
                           use.cols = clustering.cols, 
                           annot.cols = c(group.col), 
                           counts = counts)
fwrite(sum.dat, file.path(dir_out3, paste0("Summary_fastPG_k", phenok, ".csv")))

# ==============================================================================
# 9. FCS Export
# ==============================================================================
message(">>> Step 9: Exporting FCS files...")
dir_fcs <- file.path(dir_out3, "FCS_Files")
dir.create(dir_fcs, showWarnings = FALSE)

write.files(cell.sub, file.prefix = paste0(dir_fcs,"/Clustered"), divide.by = group.col, write.fcs = TRUE)


save.image(file.path(dir_out3, paste0("Analysis_Completed_k", phenok, ".RData")))
message(">>> Pipeline Completed Successfully! \U0001F389")
