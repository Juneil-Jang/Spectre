################################################################################
### Developer helper: regenerate config.xlsx with openxlsx
################################################################################

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required to create config.xlsx.", call. = FALSE)
}

settings_rows <- data.frame(
  Section = c(
    "Start here",
    rep("Files", 5),
    rep("Metadata columns", 4),
    rep("Analysis", 5),
    rep("Batch", 3),
    rep("Filtering", 2),
    rep("Downsampling", 2),
    "Clustering",
    rep("QC", 2),
    rep("Outputs", 7)
  ),
  Setting = c(
    "use_example_data",
    "data_dir",
    "metadata_dir",
    "output_dir",
    "metadata_file",
    "marker_file",
    "sample_column",
    "group_column",
    "batch_column",
    "donor_column",
    "phenok",
    "flow_type",
    "cofactor",
    "random_seed",
    "umap_cells",
    "batch_align",
    "batch_controls",
    "exclude_batch_controls_after_alignment",
    "pre_batch_filters",
    "analysis_filters",
    "balance_samples",
    "cells_per_sample",
    "clustering_markers",
    "plot_against",
    "qc_plot_pairs",
    "do_qc_plots",
    "do_marker_umaps",
    "do_proportion_plots",
    "do_pdf_plots",
    "do_summary",
    "do_fcs_export",
    "reuse_existing"
  ),
  Value = c(
    "TRUE",
    "data",
    "metadata",
    "results",
    "sample.details.csv",
    "ORIGINAL MARKERS.csv",
    "Sample",
    "Group",
    "Batch",
    "Donor",
    "100",
    "aurora",
    "2000",
    "42",
    "100000",
    "FALSE",
    "",
    "TRUE",
    "",
    "",
    "FALSE",
    "",
    "",
    "CD45RO_asinh",
    "SSC-A|FSC-A; FSC-H|FSC-A",
    "TRUE",
    "TRUE",
    "TRUE",
    "TRUE",
    "TRUE",
    "TRUE",
    "FALSE"
  ),
  Description = c(
    "TRUE runs the bundled small example. Change to FALSE for your own data.",
    "Folder with your .fcs files. Used when use_example_data is FALSE.",
    "Folder with sample.details.csv and ORIGINAL MARKERS.csv.",
    "Folder where analysis outputs will be written.",
    "Metadata CSV filename.",
    "Marker/channel CSV filename.",
    "Column in sample.details.csv containing sample names.",
    "Column containing experimental group names.",
    "Column containing batch/run IDs.",
    "Column containing donor/subject IDs.",
    "FastPG clustering resolution. Example mode caps this at 10.",
    "Use aurora, flow, or cytof.",
    "Typical values: aurora=2000, flow=200, cytof=5.",
    "Seed for reproducible subsampling/UMAP steps.",
    "Maximum cells used for UMAP plotting. Example mode caps this at 2000.",
    "TRUE enables CytoNorm batch alignment.",
    "Comma-separated Sample names for controls. Leave blank to align using all samples.",
    "Remove control samples after reference-control alignment.",
    "Optional filters before batch alignment. Separate filters with semicolons or new lines.",
    "Optional filters before clustering. Separate filters with semicolons or new lines.",
    "TRUE downsamples all samples to the same cell count after filtering.",
    "Optional target cells per sample. Leave blank to use the smallest sample.",
    "Optional comma-separated marker list. Leave blank to use all markers.",
    "Marker used for quick QC marker-vs-marker plots.",
    "Pairs for QC plots. Use X|Y and separate pairs with semicolons.",
    "TRUE writes quick QC plots.",
    "TRUE writes marker expression UMAPs.",
    "TRUE writes cluster proportion tables and plots.",
    "TRUE also saves PDF copies beside generated PNG plots.",
    "TRUE writes summary tables.",
    "TRUE writes clustered FCS exports. Example mode forces this to FALSE.",
    "TRUE reuses transformed/aligned CSV files if present."
  ),
  check.names = FALSE
)

guide_rows <- data.frame(
  Step = as.character(1:6),
  `What to do` = c(
    "Double-click SETUP_WINDOWS.bat or SETUP_MAC.command once after installing R.",
    "For a first test, keep use_example_data = TRUE and double-click RUN_WINDOWS.bat or RUN_MAC.command.",
    "For your own experiment, put .fcs files in data/ and metadata CSV files in metadata/.",
    "Set use_example_data = FALSE in Settings.",
    "Edit only the yellow Value cells in the Settings sheet.",
    "Double-click RUN again. Results will be written to the output_dir folder."
  ),
  check.names = FALSE
)

metadata_rows <- data.frame(
  FileName = c("Sample_01.fcs", "Sample_02.fcs"),
  Sample = c("Sample_01", "Sample_02"),
  Group = c("Control", "Treatment"),
  Batch = c("1", "1"),
  Donor = c("Donor_01", "Donor_02"),
  `Cells per sample` = c(50000, 50000),
  check.names = FALSE
)

marker_rows <- data.frame(
  `Channel name` = c("BUV395-A_CD3", "BUV661-A_CD4", "BV570-A_CD45RO"),
  markers = c("CD3", "CD4", "CD45RO"),
  check.names = FALSE
)

wb <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb, "Settings", gridLines = FALSE)
openxlsx::addWorksheet(wb, "Guide", gridLines = FALSE)
openxlsx::addWorksheet(wb, "Metadata_Template", gridLines = FALSE)
openxlsx::addWorksheet(wb, "Marker_Template", gridLines = FALSE)

openxlsx::writeData(wb, "Settings", settings_rows)
openxlsx::writeData(wb, "Guide", guide_rows)
openxlsx::writeData(wb, "Metadata_Template", metadata_rows)
openxlsx::writeData(wb, "Marker_Template", marker_rows)

header_style <- openxlsx::createStyle(
  fgFill = "#1F4E79",
  fontColour = "#FFFFFF",
  textDecoration = "bold",
  border = "Bottom",
  borderColour = "#D9E2F3"
)
green_header_style <- openxlsx::createStyle(
  fgFill = "#548235",
  fontColour = "#FFFFFF",
  textDecoration = "bold",
  border = "Bottom",
  borderColour = "#E2F0D9"
)
setting_style <- openxlsx::createStyle(
  fgFill = "#EAF2F8",
  textDecoration = "bold",
  border = "TopBottomLeftRight",
  borderColour = "#D9E2F3"
)
value_style <- openxlsx::createStyle(
  fgFill = "#FFF2CC",
  border = "TopBottomLeftRight",
  borderColour = "#D9E2F3"
)
body_style <- openxlsx::createStyle(
  border = "TopBottomLeftRight",
  borderColour = "#D9E2F3",
  wrapText = TRUE,
  valign = "top"
)
green_body_style <- openxlsx::createStyle(
  border = "TopBottomLeftRight",
  borderColour = "#E2F0D9"
)

openxlsx::addStyle(wb, "Settings", header_style, rows = 1, cols = 1:4, gridExpand = TRUE)
openxlsx::addStyle(wb, "Settings", body_style, rows = 2:(nrow(settings_rows) + 1), cols = 1:4, gridExpand = TRUE)
openxlsx::addStyle(wb, "Settings", setting_style, rows = 2:(nrow(settings_rows) + 1), cols = 2, gridExpand = TRUE)
openxlsx::addStyle(wb, "Settings", value_style, rows = 2:(nrow(settings_rows) + 1), cols = 3, gridExpand = TRUE)
openxlsx::setColWidths(wb, "Settings", cols = 1, widths = 18)
openxlsx::setColWidths(wb, "Settings", cols = 2, widths = 42)
openxlsx::setColWidths(wb, "Settings", cols = 3, widths = 28)
openxlsx::setColWidths(wb, "Settings", cols = 4, widths = 85)
openxlsx::freezePane(wb, "Settings", firstRow = TRUE)

openxlsx::addStyle(wb, "Guide", header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
openxlsx::addStyle(wb, "Guide", body_style, rows = 2:(nrow(guide_rows) + 1), cols = 1:2, gridExpand = TRUE)
openxlsx::setColWidths(wb, "Guide", cols = 1, widths = 10)
openxlsx::setColWidths(wb, "Guide", cols = 2, widths = 105)

openxlsx::addStyle(wb, "Metadata_Template", green_header_style, rows = 1, cols = 1:6, gridExpand = TRUE)
openxlsx::addStyle(wb, "Metadata_Template", green_body_style, rows = 2:(nrow(metadata_rows) + 1), cols = 1:6, gridExpand = TRUE)
openxlsx::setColWidths(wb, "Metadata_Template", cols = 1:6, widths = 20)
openxlsx::freezePane(wb, "Metadata_Template", firstRow = TRUE)

openxlsx::addStyle(wb, "Marker_Template", green_header_style, rows = 1, cols = 1:2, gridExpand = TRUE)
openxlsx::addStyle(wb, "Marker_Template", green_body_style, rows = 2:(nrow(marker_rows) + 1), cols = 1:2, gridExpand = TRUE)
openxlsx::setColWidths(wb, "Marker_Template", cols = 1:2, widths = 28)
openxlsx::freezePane(wb, "Marker_Template", firstRow = TRUE)

openxlsx::saveWorkbook(wb, file = "config.xlsx", overwrite = TRUE)
message("Wrote config.xlsx")
