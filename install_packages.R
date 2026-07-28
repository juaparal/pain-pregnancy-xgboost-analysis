#!/usr/bin/env Rscript

cran_packages <- c(
  "caret",
  "crosstable",
  "dplyr",
  "flextable",
  "ggplot2",
  "ggstatsplot",
  "officer",
  "pROC",
  "readxl",
  "remotes",
  "rlang",
  "tibble"
)

missing <- cran_packages[
  !vapply(cran_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing) > 0L) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

if (
  !requireNamespace("xgboost", quietly = TRUE) ||
  as.character(utils::packageVersion("xgboost")) != "1.7.8.1"
) {
  remotes::install_version(
    "xgboost",
    version = "1.7.8.1",
    repos = "https://cloud.r-project.org",
    upgrade = "never"
  )
}

message("Required packages are installed.")
