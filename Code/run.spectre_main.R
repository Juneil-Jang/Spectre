################################################################################
### scripts/run.spectre_main.R
### Description: 통합 Spectre 파이프라인 (Batch Correction 3단계 분기 적용 + 메모리 최적화)
################################################################################

run.spectre_main <- function(phenok = 30, 
                             metaFile, 
                             markerFile, 
                             meta_col = c('Sample', 'Group', 'Batch', "Donor"),
                             ref.ctrls = NULL, 
                             flowType = "aurora",
                             coFactor = 7000, 
                             subsample_size = 100000, 
                             output_slug = "Result") {
  
  # [RNG Fix] 버전 간 결과 일관성 유지
  suppressWarnings(RNGkind(kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection"))
  
  # 필수 패키지 로드
  library(Spectre)
  library(data.table)
  library(dplyr)
  library(FastPG)
  library(FNN)
  
  # --- [Step 0: 경로 및 환경 설정] ---
  base_dir <- getwd()
  
  # 출력 폴더 정의
  dirs <- list(
    data = file.path(base_dir, "data"),
    meta = file.path(base_dir, "metadata"),
    out  = file.path(base_dir, paste0("Output_", output_slug))
  )
  
  # 하위 폴더 트리 구조 정의
  out_paths <- list(
    prep    = file.path(dirs$out, "1_Prep"),
    align   = file.path(dirs$out, "2_Alignment"),
    pre_plt = file.path(dirs$out, "2_Alignment", "2.1_Pre_Align_Plots"),
    fine    = file.path(dirs$out, "2_Alignment", "2.2_Fine_Alignment"),
    cluster = file.path(dirs$out, "3_Clustering"),
    viz     = file.path(dirs$out, "3_Clustering", "Plots")
  )
  
  lapply(out_paths, dir.create, showWarnings = FALSE, recursive = TRUE)
  
  # --- [Step 1: 데이터 임포트 및 병합] ---
  message("\n=== Step 1: Importing and Merging data ===")
  
  data.list <- read.cytofFiles(file.loc = dirs$data, file.type = ".fcs", do.embed.file.names = TRUE)
  
  markers <- read.csv(file.path(dirs$meta, markerFile))
  data.list <- lapply(data.list, rename_columns, markers)
  
  cell.dat <- Spectre::do.merge.files(dat = data.list)
  
  meta.dat <- fread(file.path(dirs$meta, metaFile))
  cell.dat <- do.add.cols(cell.dat, "FileName", meta.dat, "FileName", rmv.ext = TRUE)
  
  sample_col <- meta_col[1]; group_col <- meta_col[2]
  batch_col  <- meta_col[3]; donor_col <- meta_col[4]
  marker_names <- markers[[2]]
  
  # --- [Step 2: Arcsinh 변환] ---
  message("\n=== Step 2: Performing Arcsinh transformation ===")
  cell.dat <- do.asinh(cell.dat, use.cols = marker_names, cofactor = coFactor)
  transf.cols <- paste0(marker_names, "_asinh")
  
  # --- [Step 3: Batch Correction (3-Way Logic)] ---
  message("\n=== Step 3: Batch Correction Logic ===")
  
  unique_batches <- unique(cell.dat[[batch_col]])
  num_batches <- length(unique_batches)
  
  # [논리 분기]
  if (num_batches == 1) {
    # [Case 1] 단일 배치 -> 정렬 스킵
    message("   > Condition: Single Batch detected.")
    message("   > Action: Skipping Batch Alignment.")
    cluster_cols <- transf.cols
    
  } else {
    # 다중 배치인 경우
    if (is.null(ref.ctrls)) {
      # [Case 2] 다중 배치 + Reference 없음
      message("   > Condition: Multiple Batches but NO Reference Controls.")
      message("   > Action: Using Representative Subsample for CytoNorm training (Self-Alignment).")
      
      # ### FIX 1: 전체 데이터 대신 Subsampling으로 학습 데이터 생성 (메모리 폭발 방지) ###
      set.seed(42)
      # 전체 데이터가 20만 개 넘으면 20만 개만 추출해서 학습 (Batch 비율 유지)
      if (nrow(cell.dat) > 200000) {
        message("   > Data is too large for training. Subsampling 200k cells for model training...")
        train_dat <- do.subsample(cell.dat, 200000) 
      } else {
        train_dat <- cell.dat
      }
      
    } else {
      # [Case 3] 다중 배치 + Reference 있음
      message("   > Condition: Multiple Batches WITH Reference Controls.")
      message("   > Action: Using Reference samples for CytoNorm training.")
      
      train_dat <- cell.dat[cell.dat[[sample_col]] %in% ref.ctrls, ]
      
      if(nrow(train_dat) == 0) stop("Error: Reference samples not found. Check 'ref.ctrls'.")
    }
    
    # --- CytoNorm 공통 실행 (Case 2 & 3) ---
    
    # 1. Pre-alignment Plots
    message("   > Generating Pre-alignment plots...")
    set.seed(42)
    # 시각화용 10만개 샘플링
    if(nrow(cell.dat) > 100000) {
      plot_sub <- cell.dat[sample(nrow(cell.dat), 100000), ]
    } else {
      plot_sub <- cell.dat
    }
    
    # Reference 그룹 제외 (Case 3일 때만)
    if(!is.null(ref.ctrls)){
      name_ref_group <- unique(cell.dat[cell.dat[[sample_col]] %in% ref.ctrls, ][[group_col]])
      plot_sub <- plot_sub[plot_sub[[group_col]] != name_ref_group, ]
    }
    
    plot_sub <- run.umap(plot_sub, use.cols = transf.cols)
    
    tryCatch({
      make.colour.plot(plot_sub, "UMAP_X", "UMAP_Y", batch_col, col.type = 'factor', 
                       filename = file.path(out_paths$pre_plt, "Pre_Batches.png"))
      make.colour.plot(plot_sub, "UMAP_X", "UMAP_Y", group_col, col.type = 'factor', 
                       filename = file.path(out_paths$pre_plt, "Pre_Groups.png"))
    }, error = function(e) message("   ! Warning: Failed to create pre-align plots."))
    
    rm(plot_sub); gc() 
    
    # 2. CytoNorm Training
    message("   > Training CytoNorm model...")
    
    # Fallback 로직 (train_dat 사용)
    cytnrm <- run_with_fallback(
      expr_primary = quote(prep.cytonorm(dat = train_dat, 
                                         cellular.cols = transf.cols, 
                                         cluster.cols = transf.cols,
                                         batch.col = batch_col, 
                                         sample.col = sample_col, 
                                         xdim = 10, ydim = 10, meta.k = 5)),
      expr_fallback = quote(amshaw(dat = train_dat, 
                                   cellular.cols = transf.cols, 
                                   cluster.cols = transf.cols,
                                   batch.col = batch_col, 
                                   sample.col = sample_col, 
                                   xdim = 10, ydim = 10, meta.k = 5))
    )
    
    cytnrm <- train.cytonorm(model = cytnrm, align.cols = transf.cols)
    saveRDS(cytnrm, file.path(out_paths$fine, "CytoNorm_Model.rds"))
    
    # 3. Apply CytoNorm
    message("   > Applying CytoNorm to all data...")
    cell.dat <- run.cytonorm(dat = cell.dat, model = cytnrm, batch.col = batch_col)
    
    cluster_cols <- paste0(transf.cols, "_aligned")
    
    # 4. Post-alignment Plots
    message("   > Generating Post-alignment plots...")
    if(nrow(cell.dat) > 100000) {
      plot_sub <- cell.dat[sample(nrow(cell.dat), 100000), ]
    } else {
      plot_sub <- cell.dat
    }
    
    plot_sub <- run.umap(plot_sub, use.cols = cluster_cols)
    
    tryCatch({
      make.colour.plot(plot_sub, "UMAP_X", "UMAP_Y", batch_col, col.type = 'factor', 
                       filename = file.path(out_paths$fine, "Post_Batches.png"))
    }, error = function(e) message("   ! Warning: Failed to create post-align plots."))
    
    rm(plot_sub); gc()
    
    # Case 3: Reference 샘플 제거 (분석용 아님)
    if(!is.null(ref.ctrls)){
      cell.dat <- cell.dat[cell.dat[[group_col]] != name_ref_group, ]
    }
  }
  
  # --- [Step 4: Clustering] ---
  message(paste0("\n=== Step 4: Clustering with FastPG (k=", phenok, ") ==="))
  
  data_mat <- as.matrix(cell.dat[, ..cluster_cols])
  
  # ### FIX 2: 변수명 일치 (subsample_size -> subset_size) ###
  # help_functions.R에 정의된 인자 이름인 subset_size를 써야 합니다.
  cell.dat$fastPG_Clusters <- run_fastpg_robust(
    data_mat = data_mat, k = phenok, 
    subset_size = subsample_size, # <- 여기 수정됨
    seed = 42
  )
  
  fwrite(cell.dat, file.path(out_paths$cluster, "Final_Clustered_Data.csv"))
  
  # --- [Step 5: Visualization] ---
  message("\n=== Step 5: Visualization (Refined) ===")
  
  # 5.1 Heatmap
  tryCatch({
    exp <- do.aggregate(cell.dat, cluster_cols, by = "fastPG_Clusters")
    make.pheatmap(exp, "fastPG_Clusters", cluster_cols, normalise = TRUE, 
                  filename = file.path(out_paths$viz, "Heatmap_Znorm.png"))
  }, error = function(e) message("   ! Heatmap Error: ", e$message))
  
  # 5.2 UMAP (Subsampled)
  message("   > Generating final UMAPs (Subsampled)...")
  set.seed(42)
  
  if(nrow(cell.dat) > 100000) {
    viz_sub <- cell.dat[sample(nrow(cell.dat), 100000), ]
  } else {
    viz_sub <- cell.dat
  }
  
  viz_sub <- run.umap(viz_sub, use.cols = cluster_cols)
  
  # Individual Marker Plots
  for(col in cluster_cols) {
    thr <- get_gate_threshold(viz_sub[[col]], probs = 0.02)
    
    tryCatch({
      make.colour.plot(viz_sub, "UMAP_X", "UMAP_Y", col, 
                       col.min.threshold = thr,
                       main = paste(col, "(Thr:", round(thr, 2), ")"),
                       filename = file.path(out_paths$viz, paste0("UMAP_", col, ".png")))
    }, error = function(e) message(paste("   ! Plot Error:", col)))
  }
  
  # Cluster Plot
  make.colour.plot(viz_sub, "UMAP_X", "UMAP_Y", "fastPG_Clusters", col.type = "factor", 
                   add.label = TRUE, filename = file.path(out_paths$viz, "UMAP_Clusters.png"))
  
  # 5.3 Multiplot (Safe Execution)
  message("   > Generating Multiplot...")
  tryCatch({
    current_wd <- getwd()
    setwd(out_paths$viz) # 잠시 이동 (Spectre 호환성)
    
    make.multi.plot(viz_sub, "UMAP_X", "UMAP_Y", cluster_cols, 
                    figure.title = "Overview_Markers", 
                    col.type = 'continuous')
    
    setwd(current_wd) # 원상 복귀
    
  }, error = function(e) message("   ! Warning: Multiplot generation failed. (Skipping)"))
  
  # --- [Step 6: Log] ---
  message("\n=== Step 6: Finalizing Log ===")
  log_content <- c(
    "Spectre Analysis Log",
    paste0("Date: ", Sys.time()),
    paste0("User: ", Sys.info()[["user"]]),
    paste0("R Version: ", R.version.string),
    "--- Configuration ---",
    paste0("k-value: ", phenok),
    paste0("CoFactor: ", coFactor),
    paste0("Batch Correction Mode: ", 
           if(num_batches == 1) "None (Single Batch)" 
           else if(is.null(ref.ctrls)) "Self-Alignment (No Refs)" 
           else "Reference-Based"),
    "--- Results ---",
    paste0("Total Cells Analyzed: ", nrow(cell.dat)),
    paste0("Clusters Identified: ", length(unique(cell.dat$fastPG_Clusters)))
  )
  writeLines(log_content, file.path(dirs$out, "analysis_log.txt"))
  
  message("Analysis Complete. Check output at: ", dirs$out)
}