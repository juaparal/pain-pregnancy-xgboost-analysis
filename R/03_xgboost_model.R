#!/usr/bin/env Rscript

# ==============================================================================
# 03_xgboost_model.R
# XGBoost training, repeated cross-validation, evaluation, ROC, and importance
# ==============================================================================

SEED <- 123L
TRAIN_PROPORTION <- 0.80
POSITIVE_CLASS <- "YES"
DATA_FILE <- "results/xgboost_analysis_data.rds"

required_packages <- c(
  "caret",
  "dplyr",
  "ggplot2",
  "pROC",
  "tibble",
  "xgboost"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    "Missing required package(s): ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

if (!file.exists(DATA_FILE)) {
  stop(
    "Prepared data not found. Run R/01_prepare_data.R first.",
    call. = FALSE
  )
}

dir.create("results", recursive = TRUE, showWarnings = FALSE)
dir.create("figures", recursive = TRUE, showWarnings = FALSE)

analysis_data <- readRDS(DATA_FILE)

if (anyNA(analysis_data)) {
  stop("The XGBoost dataset contains missing values.", call. = FALSE)
}

class_counts <- table(analysis_data$pain_cat2)
if (length(class_counts) != 2L || any(class_counts == 0L)) {
  stop("The binary outcome must contain both YES and NO classes.", call. = FALSE)
}

# ---- Stratified train/test split ----------------------------------------------

set.seed(SEED)
train_index <- caret::createDataPartition(
  y = analysis_data$pain_cat2,
  p = TRAIN_PROPORTION,
  list = FALSE
)

train_data <- analysis_data[train_index, , drop = FALSE]
test_data <- analysis_data[-train_index, , drop = FALSE]

# ---- Repeated cross-validation and tuning grid --------------------------------

train_control <- caret::trainControl(
  method = "repeatedcv",
  number = 10,
  repeats = 3,
  savePredictions = "final",
  summaryFunction = caret::twoClassSummary,
  classProbs = TRUE,
  sampling = "down",
  verboseIter = TRUE,
  allowParallel = FALSE
)

xgb_grid <- expand.grid(
  nrounds = c(100, 200),
  max_depth = c(4, 6),
  eta = c(0.01, 0.1),
  gamma = c(0, 1),
  colsample_bytree = c(0.6, 0.8),
  min_child_weight = c(1, 2),
  subsample = c(0.6, 0.8)
)

# ---- Model fitting -------------------------------------------------------------

set.seed(SEED)
xgb_model <- caret::train(
  pain_cat2 ~ .,
  data = train_data,
  method = "xgbTree",
  metric = "ROC",
  preProcess = c("center", "scale", "nzv"),
  trControl = train_control,
  tuneGrid = xgb_grid,
  na.action = stats::na.fail
)

saveRDS(xgb_model, file = "results/xgboost_model.rds")

utils::write.csv(
  xgb_model$results,
  file = "results/xgboost_tuning_results.csv",
  row.names = FALSE
)

utils::write.csv(
  xgb_model$bestTune,
  file = "results/xgboost_best_hyperparameters.csv",
  row.names = FALSE
)

# ---- Held-out test-set evaluation ---------------------------------------------

predicted_class <- stats::predict(
  xgb_model,
  newdata = test_data,
  type = "raw"
)

predicted_probabilities <- stats::predict(
  xgb_model,
  newdata = test_data,
  type = "prob"
)

if (!POSITIVE_CLASS %in% names(predicted_probabilities)) {
  stop(
    "The predicted-probability table does not contain class '",
    POSITIVE_CLASS,
    "'.",
    call. = FALSE
  )
}

confusion <- caret::confusionMatrix(
  data = predicted_class,
  reference = test_data$pain_cat2,
  positive = POSITIVE_CLASS
)

capture.output(
  confusion,
  file = "results/xgboost_confusion_matrix.txt"
)

classification_metrics <- tibble::tibble(
  metric = c(
    "Accuracy",
    "Sensitivity",
    "Specificity",
    "Balanced accuracy"
  ),
  value = unname(c(
    confusion$overall[["Accuracy"]],
    confusion$byClass[["Sensitivity"]],
    confusion$byClass[["Specificity"]],
    confusion$byClass[["Balanced Accuracy"]]
  ))
)

utils::write.csv(
  classification_metrics,
  file = "results/xgboost_classification_metrics.csv",
  row.names = FALSE
)

prediction_output <- test_data |>
  dplyr::mutate(
    predicted_class = predicted_class,
    probability_YES = predicted_probabilities[[POSITIVE_CLASS]]
  )

utils::write.csv(
  prediction_output,
  file = "results/xgboost_test_set_predictions.csv",
  row.names = FALSE
)

# ---- ROC curve and AUC ---------------------------------------------------------

roc_curve <- pROC::roc(
  response = test_data$pain_cat2,
  predictor = predicted_probabilities[[POSITIVE_CLASS]],
  levels = c("NO", "YES"),
  direction = "<",
  quiet = TRUE
)

auc_value <- as.numeric(pROC::auc(roc_curve))
auc_ci <- as.numeric(pROC::ci.auc(roc_curve))

roc_summary <- tibble::tibble(
  auc = auc_value,
  ci_lower = auc_ci[1],
  ci_median = auc_ci[2],
  ci_upper = auc_ci[3],
  confidence_level = 0.95
)

utils::write.csv(
  roc_summary,
  file = "results/xgboost_roc_auc.csv",
  row.names = FALSE
)

roc_coordinates <- tibble::tibble(
  specificity = roc_curve$specificities,
  sensitivity = roc_curve$sensitivities,
  false_positive_rate = 1 - specificity
)

utils::write.csv(
  roc_coordinates,
  file = "results/xgboost_roc_coordinates.csv",
  row.names = FALSE
)

roc_plot <- ggplot2::ggplot(
  roc_coordinates,
  ggplot2::aes(x = false_positive_rate, y = sensitivity)
) +
  ggplot2::geom_line(linewidth = 1) +
  ggplot2::geom_abline(
    intercept = 0,
    slope = 1,
    linetype = "dashed"
  ) +
  ggplot2::coord_equal() +
  ggplot2::labs(
    x = "1 - Specificity",
    y = "Sensitivity",
    title = sprintf(
      "Receiver operating characteristic curve (AUC = %.3f)",
      auc_value
    )
  ) +
  ggplot2::theme_bw()

ggplot2::ggsave(
  filename = "figures/xgboost_roc_curve.png",
  plot = roc_plot,
  width = 7,
  height = 6,
  units = "in",
  dpi = 300,
  bg = "white"
)

ggplot2::ggsave(
  filename = "figures/xgboost_roc_curve.pdf",
  plot = roc_plot,
  width = 7,
  height = 6,
  units = "in"
)

# ---- Variable importance -------------------------------------------------------

variable_importance <- caret::varImp(
  xgb_model,
  scale = TRUE
)$importance |>
  as.data.frame() |>
  tibble::rownames_to_column("variable") |>
  dplyr::arrange(dplyr::desc(Overall)) |>
  dplyr::mutate(rank = dplyr::row_number(), .before = 1L)

utils::write.csv(
  variable_importance,
  file = "results/xgboost_variable_importance.csv",
  row.names = FALSE
)

importance_plot <- ggplot2::ggplot(
  variable_importance,
  ggplot2::aes(
    x = stats::reorder(variable, Overall),
    y = Overall
  )
) +
  ggplot2::geom_col() +
  ggplot2::coord_flip() +
  ggplot2::labs(
    x = NULL,
    y = "Scaled importance",
    title = "XGBoost variable importance"
  ) +
  ggplot2::theme_bw()

ggplot2::ggsave(
  filename = "figures/xgboost_variable_importance.png",
  plot = importance_plot,
  width = 8,
  height = 6,
  units = "in",
  dpi = 300,
  bg = "white"
)

ggplot2::ggsave(
  filename = "figures/xgboost_variable_importance.pdf",
  plot = importance_plot,
  width = 8,
  height = 6,
  units = "in"
)

capture.output(
  sessionInfo(),
  file = "results/03_xgboost_model_session_info.txt"
)

message("XGBoost analysis completed successfully.")
