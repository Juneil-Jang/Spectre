################################################################################
### Standardized Spectre Analysis Pipeline (Refactored)
################################################################################
# ==============================================================================
# 1. User Settings (Adjustable Variables)
# ==============================================================================
PrimaryDirectory <- "~/Documents//Anjali/"  # 최상위 작업 폴더
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
# ref.ctrls        <- c("export_SEB+Pi F020_CD154, OX40+", "export_SEB+Pi F020_CD154,OX40+")

do.batchAlign = F
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

cell.sub = cell.dat %>% dplyr::filter(Donor == "1-0120") ####################################################### subset
cell.sub$Sample %>% table

which(names(cell.sub) == plot.against)

for(i in transf.cols){
  make.colour.plot(cell.sub, i, col.min.threshold = 0, plot.against, path = dir_out1, fast = T)
}

make.colour.plot(cell.sub, x.axis = "SSC-A", y.axis = "FSC-A", path = dir_out1, fast = T)
make.colour.plot(cell.sub, x.axis = "FSC-H", y.axis = "FSC-A", path = dir_out1, fast = T)
make.colour.plot(cell.sub, x.axis = "CD3_asinh", y.axis = "LIVE DEAD NIR-A_LiveDead_asinh", path = dir_out1, fast = T)

######################################################################################################### gating
# 2. 확인한 수치를 바탕으로 조건을 걸어 데이터(data.table)를 자릅니다.
# 예: CD4는 3 이상, CD8은 1 이하인 세포만 서브셋으로 추출
cell.sub2 <- cell.sub[CD3_asinh > 1.0 & `LIVE DEAD NIR-A_LiveDead_asinh` < 2.0, ]
make.colour.plot(cell.sub2, x.axis = "CD3_asinh", y.axis = "LIVE DEAD NIR-A_LiveDead_asinh", path = file.path(dir_out1, "corrected"), fast = T)

# 2. FSC-H가 FSC-A의 0.8배보다 크고, 1.2배보다 작은 세포만 살림
# (스캐터 플랏의 축 숫자를 보고 0.8, 1.2 같은 비율 숫자를 조절하세요)
cell.sub3 <- cell.sub2[`FSC-H` > (`FSC-A` * 0.85) & `FSC-H` < (`FSC-A` * 1.15), ]
make.colour.plot(cell.sub3, x.axis = "FSC-H", y.axis = "FSC-A", path = file.path(dir_out1, "corrected"), fast = T)

cell.sub4 <- cell.sub3[`FSC-A` > (`SSC-A` + 50000), ]
make.colour.plot(cell.sub4, x.axis = "SSC-A", y.axis = "FSC-A", path = file.path(dir_out1, "corrected"), fast = T)

make.colour.plot(cell.sub4, x.axis = "CD4_asinh", y.axis = "CD8_asinh", path = file.path(dir_out1), fast = T)
cell.sub5 <- cell.sub4[CD4_asinh > 2.0 & CD8_asinh < 1.5, ]

# ==============================================================================
# [추가] 가장 세포 수가 적은 샘플 기준으로 모두 균등하게 다운샘플링
# ==============================================================================
# 1. 각 샘플별 세포 수 계산 및 최솟값 찾기
sample_counts <- table(cell.sub5[[sample.col]])
min_cells <- min(sample_counts)

message(paste0(">>> 각 샘플의 최소 세포 수는 [ ", min_cells, " ] 개 입니다. 모든 샘플을 이 수치로 균등하게 다운샘플링합니다."))

# (안전장치) 만약 불량 샘플 때문에 100개 이하로 떨어지면 경고
if(min_cells < 500) {
  warning("⚠️ 가장 적은 샘플의 세포 수가 너무 적습니다! 전체 데이터 크기가 지나치게 쪼그라들 수 있으니, 불량 샘플을 아예 제외하는 것을 고려하세요.")
}

# 2. data.table 기능을 이용해 샘플별로 min_cells 개수만큼만 랜덤 추출
data.table::setDT(cell.sub5)
cell.sub5 <- cell.sub5[, .SD[sample(.N, min_cells)], by = sample.col]

message(">>> 균등 다운샘플링 완료!")

# 저장
fwrite(cell.sub5, file.path(dir_out1, paste0("cell.dat_filtered_equalized.csv")))

for(i in transf.cols){
  make.colour.plot(cell.sub5, i, col.min.threshold = 0, plot.against, path = file.path(dir_out1, "corrected"), fast = T)
}
make.colour.plot(cell.sub5, x.axis = "CD4_asinh", y.axis = "CD8_asinh", path = file.path(dir_out1, "corrected"), fast = T)

cell.sub = cell.sub5 ##################################################################################################################

fwrite(cell.sub, file.path(dir_out1, paste0("cell.dat_filtered.csv")))

clustering.cols =  clustering.cols[c(2,6:9,11:25)]#####################################################################################

# ==============================================================================
# 6. Clustering (FastPG)
# ==============================================================================
message(">>> Step 6: Clustering (FastPG)...")
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

# Heatmap
exp <- do.aggregate(as.data.table(cell.sub), clustering.cols, by = "fastPG_Clusters")
make.pheatmap(exp, "fastPG_Clusters", plot.cols = clustering.cols, normalise = TRUE, 
              standard.colours = "rev(RdBu)", path = dir_out3)

# Plots
make.colour.plot(cell.sub, "UMAP_X", "UMAP_Y", "fastPG_Clusters", col.type = 'factor', add.label = TRUE, path = dir_out3)
make.colour.plot(cell.sub, "UMAP_X", "UMAP_Y", group.col, col.type = 'factor', path = dir_out3)

group.names <- unique(cell.sub$Group)
for (j in 1:length(group.names)){
  Idx <-which(cell.sub$Group==group.names[j])
  cell.group <- cell.sub[Idx,]
  make.colour.plot(cell.group, "UMAP_X", "UMAP_Y","fastPG_Clusters",col.type = 'factor', path = dir_out3)
}

# Expression Plots
# [취약점 보완 4] 속도를 극단적으로 늦추던 ecdf 대신 quantile 사용
for(i in clustering.cols){
  marker <- as.numeric(unlist(cell.dat[[i]])) ### ??????
  percentile <- ecdf(marker)(0) ### ??????
  
  # thr <- quantile(cell.sub[[i]], probs = 0.01, na.rm = TRUE) # 하위 1% 노이즈 컷오프
  make.colour.plot(cell.sub, "UMAP_X", "UMAP_Y", i, col.min.threshold = percentile, path = dir_out3)
}

# ==============================================================================
# 8. Summary Export
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
