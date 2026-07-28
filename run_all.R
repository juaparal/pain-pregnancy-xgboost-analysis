#!/usr/bin/env Rscript

# Run the complete reproducible workflow from the repository root.
# Optional usage:
#   Rscript run_all.R "/absolute/or/relative/path/to/data.xlsx"

args <- commandArgs(trailingOnly = TRUE)
data_file <- if (length(args) >= 1L) {
  args[[1L]]
} else {
  "data/pain-pregnancy_dataset.xlsx"
}

status_prepare <- system2(
  command = file.path(R.home("bin"), "Rscript"),
  args = c("R/01_prepare_data.R", shQuote(data_file))
)

if (status_prepare != 0L) {
  stop("Data-preparation step failed.", call. = FALSE)
}

status_statistics <- system2(
  command = file.path(R.home("bin"), "Rscript"),
  args = "R/02_statistical_analysis.R"
)

if (status_statistics != 0L) {
  stop("Statistical-analysis step failed.", call. = FALSE)
}

status_xgboost <- system2(
  command = file.path(R.home("bin"), "Rscript"),
  args = "R/03_xgboost_model.R"
)

if (status_xgboost != 0L) {
  stop("XGBoost step failed.", call. = FALSE)
}

message("All analyses completed successfully.")
