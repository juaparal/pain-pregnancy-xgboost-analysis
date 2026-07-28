#!/usr/bin/env Rscript

# ==============================================================================
# 01_prepare_data.R
# Data import, validation, variable recoding, and creation of analysis datasets
# ==============================================================================

SEED <- 123L
DEFAULT_DATA_FILE <- "data/pain-pregnancy_dataset.xlsx"

required_packages <- c("readxl", "dplyr", "tibble")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    "Missing required package(s): ",
    paste(missing_packages, collapse = ", "),
    ". Run install.packages() before continuing.",
    call. = FALSE
  )
}

args <- commandArgs(trailingOnly = TRUE)
data_file <- if (length(args) >= 1L) args[[1L]] else DEFAULT_DATA_FILE

if (!file.exists(data_file)) {
  stop(
    "Data file not found: ", normalizePath(data_file, mustWork = FALSE), "\n",
    "Place an authorised copy in the data/ directory or pass its path as the ",
    "first command-line argument.",
    call. = FALSE
  )
}

dir.create("results", recursive = TRUE, showWarnings = FALSE)

message("Reading data: ", normalizePath(data_file, mustWork = TRUE))
data_raw <- readxl::read_excel(data_file)
names(data_raw) <- trimws(names(data_raw))

required_columns <- c(
  "PAIN INTENSITY",
  "BODY SURVEILLANCE",
  "FUNCTION_APPRECIATION",
  "AGE",
  "BMI",
  "LEVEL EDUCATION",
  "EMPLOYMENT",
  "HADS_ANXIETY",
  "HADS_DEPRESSION",
  "PARITY",
  "KINESIOPHOBIA (TSK)",
  "PAIN CATASTROPHIZING",
  "BIRTH_FEAR"
)

missing_columns <- setdiff(required_columns, names(data_raw))
if (length(missing_columns) > 0L) {
  stop(
    "The dataset is missing the following required column(s): ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

analysis_data <- data_raw |>
  dplyr::mutate(
    `LEVEL EDUCATION` = factor(`LEVEL EDUCATION`),
    EMPLOYMENT = factor(EMPLOYMENT),
    PARITY = factor(PARITY),
    BIRTH_FEAR_CAT = dplyr::case_when(
      BIRTH_FEAR <= 37 ~ "Low",
      BIRTH_FEAR <= 65 ~ "Moderate",
      BIRTH_FEAR <= 84 ~ "High",
      TRUE ~ "Severe"
    ),
    BIRTH_FEAR_CAT = factor(
      BIRTH_FEAR_CAT,
      levels = c("Low", "Moderate", "High", "Severe")
    ),
    PAIN_CAT = dplyr::case_when(
      `PAIN INTENSITY` <= 3 ~ "Non-pain/mild",
      `PAIN INTENSITY` <= 6 ~ "Moderate",
      TRUE ~ "Severe"
    ),
    PAIN_CAT = factor(
      PAIN_CAT,
      levels = c("Non-pain/mild", "Moderate", "Severe")
    ),
    pain_cat2 = dplyr::if_else(`PAIN INTENSITY` <= 3, "NO", "YES"),
    pain_cat2 = factor(pain_cat2, levels = c("YES", "NO"))
  )

statistical_data <- analysis_data |>
  dplyr::select(
    PAIN_CAT,
    BIRTH_FEAR_CAT,
    `PAIN INTENSITY`,
    AGE,
    BMI,
    `LEVEL EDUCATION`,
    EMPLOYMENT,
    PARITY,
    `BODY SURVEILLANCE`,
    FUNCTION_APPRECIATION,
    HADS_ANXIETY,
    HADS_DEPRESSION,
    `KINESIOPHOBIA (TSK)`,
    `PAIN CATASTROPHIZING`
  )

xgboost_data <- analysis_data |>
  dplyr::select(
    pain_cat2,
    `BODY SURVEILLANCE`,
    FUNCTION_APPRECIATION,
    AGE,
    BMI,
    `LEVEL EDUCATION`,
    EMPLOYMENT,
    HADS_ANXIETY,
    HADS_DEPRESSION,
    PARITY,
    `KINESIOPHOBIA (TSK)`,
    `PAIN CATASTROPHIZING`
  )

if (anyNA(xgboost_data)) {
  missing_counts <- colSums(is.na(xgboost_data))
  missing_counts <- missing_counts[missing_counts > 0L]
  stop(
    "Missing values detected in the XGBoost dataset: ",
    paste(names(missing_counts), missing_counts, sep = "=", collapse = ", "),
    call. = FALSE
  )
}

pain_counts <- as.data.frame(table(statistical_data$PAIN_CAT), stringsAsFactors = FALSE)
names(pain_counts) <- c("pain_category", "n")

binary_counts <- as.data.frame(table(xgboost_data$pain_cat2), stringsAsFactors = FALSE)
names(binary_counts) <- c("class", "n")

saveRDS(statistical_data, file = "results/statistical_analysis_data.rds")
saveRDS(xgboost_data, file = "results/xgboost_analysis_data.rds")

utils::write.csv(
  pain_counts,
  file = "results/pain_group_distribution.csv",
  row.names = FALSE
)
utils::write.csv(
  binary_counts,
  file = "results/binary_class_distribution.csv",
  row.names = FALSE
)

capture.output(
  sessionInfo(),
  file = "results/01_prepare_data_session_info.txt"
)

message("Data preparation completed successfully.")
