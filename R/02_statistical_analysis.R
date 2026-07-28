#!/usr/bin/env Rscript

# ==============================================================================
# 02_statistical_analysis.R
# Descriptive statistics, non-parametric comparisons, and manuscript figures
# ==============================================================================

SEED <- 123L
P_ADJUST_METHOD <- "bonferroni"
CONFIDENCE_LEVEL <- 0.95
DATA_FILE <- "results/statistical_analysis_data.rds"

required_packages <- c(
  "dplyr",
  "tibble",
  "crosstable",
  "flextable",
  "officer",
  "ggplot2",
  "ggstatsplot",
  "rlang"
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

table_variables <- c(
  "AGE",
  "BMI",
  "LEVEL EDUCATION",
  "EMPLOYMENT",
  "PARITY",
  "BODY SURVEILLANCE",
  "FUNCTION_APPRECIATION",
  "HADS_ANXIETY",
  "HADS_DEPRESSION",
  "KINESIOPHOBIA (TSK)",
  "PAIN CATASTROPHIZING",
  "BIRTH_FEAR_CAT",
  "PAIN INTENSITY"
)

test_variables <- c(
  "BODY SURVEILLANCE",
  "PAIN CATASTROPHIZING",
  "KINESIOPHOBIA (TSK)"
)

missing_table_variables <- setdiff(
  c("PAIN_CAT", table_variables),
  names(analysis_data)
)

if (length(missing_table_variables) > 0L) {
  stop(
    "Prepared statistical dataset is missing: ",
    paste(missing_table_variables, collapse = ", "),
    call. = FALSE
  )
}

# ---- Descriptive table ---------------------------------------------------------

table_data <- analysis_data |>
  dplyr::select(dplyr::all_of(c("PAIN_CAT", table_variables)))

descriptive_table <- crosstable::crosstable(
  table_data,
  by = PAIN_CAT,
  total = "both",
  effect = TRUE,
  showNA = "ifany",
  test = TRUE,
  percent_pattern = "{n} ({p_col})"
)

formatted_table <- crosstable::as_flextable(
  descriptive_table,
  keep_id = FALSE
)
formatted_table <- flextable::autofit(formatted_table)

flextable::save_as_docx(
  "Descriptive statistics by pain category" = formatted_table,
  path = "results/descriptive_statistics_by_pain_group.docx"
)

utils::write.csv(
  as.data.frame(descriptive_table),
  file = "results/descriptive_statistics_by_pain_group.csv",
  row.names = FALSE,
  na = ""
)

# ---- Non-parametric analyses ---------------------------------------------------

run_nonparametric_tests <- function(data, variable) {
  test_data <- data |>
    dplyr::transmute(
      PAIN_CAT = PAIN_CAT,
      value = .data[[variable]]
    ) |>
    dplyr::filter(!is.na(PAIN_CAT), !is.na(value))

  if (!is.numeric(test_data$value)) {
    stop("Variable '", variable, "' must be numeric.", call. = FALSE)
  }

  if (dplyr::n_distinct(test_data$PAIN_CAT) < 2L) {
    stop(
      "Variable '", variable, "' has fewer than two non-empty pain groups.",
      call. = FALSE
    )
  }

  kw <- stats::kruskal.test(value ~ PAIN_CAT, data = test_data)

  pairwise <- stats::pairwise.wilcox.test(
    x = test_data$value,
    g = test_data$PAIN_CAT,
    p.adjust.method = P_ADJUST_METHOD,
    exact = FALSE
  )

  overall <- tibble::tibble(
    variable = variable,
    test = "Kruskal-Wallis rank-sum test",
    statistic = unname(kw$statistic),
    degrees_of_freedom = unname(kw$parameter),
    p_value = kw$p.value,
    n_complete = nrow(test_data)
  )

  pairwise_long <- as.data.frame(
    as.table(pairwise$p.value),
    stringsAsFactors = FALSE
  ) |>
    tibble::as_tibble() |>
    dplyr::rename(
      group_1 = Var1,
      group_2 = Var2,
      adjusted_p_value = Freq
    ) |>
    dplyr::filter(!is.na(adjusted_p_value)) |>
    dplyr::mutate(
      variable = variable,
      method = "Wilcoxon rank-sum test",
      p_adjust_method = P_ADJUST_METHOD,
      .before = 1L
    )

  list(overall = overall, pairwise = pairwise_long)
}

test_results <- lapply(
  test_variables,
  function(variable) run_nonparametric_tests(analysis_data, variable)
)

overall_tests <- dplyr::bind_rows(
  lapply(test_results, function(x) x$overall)
)

pairwise_tests <- dplyr::bind_rows(
  lapply(test_results, function(x) x$pairwise)
)

utils::write.csv(
  overall_tests,
  file = "results/kruskal_wallis_tests.csv",
  row.names = FALSE
)

utils::write.csv(
  pairwise_tests,
  file = "results/pairwise_wilcoxon_tests.csv",
  row.names = FALSE
)

# ---- Manuscript figures --------------------------------------------------------

create_group_plot <- function(data, outcome, y_label, output_stem) {
  set.seed(SEED)

  plot_object <- ggstatsplot::ggbetweenstats(
    data = data,
    x = PAIN_CAT,
    y = !!rlang::sym(outcome),
    type = "np",
    pairwise.display = "significant",
    p.adjust.method = P_ADJUST_METHOD,
    results.subtitle = FALSE,
    conf.level = CONFIDENCE_LEVEL,
    boxplot.args = list(width = 0),
    package = "ggsci",
    palette = "uniform_startrek"
  ) +
    ggplot2::labs(
      x = NULL,
      y = y_label
    ) +
    ggplot2::theme(
      text = ggplot2::element_text(size = 17),
      plot.title = ggplot2::element_blank()
    )

  ggplot2::ggsave(
    filename = file.path("figures", paste0(output_stem, ".png")),
    plot = plot_object,
    width = 8.5,
    height = 6.5,
    units = "in",
    dpi = 300,
    bg = "white"
  )

  ggplot2::ggsave(
    filename = file.path("figures", paste0(output_stem, ".pdf")),
    plot = plot_object,
    width = 8.5,
    height = 6.5,
    units = "in",
    device = grDevices::cairo_pdf
  )

  invisible(plot_object)
}

create_group_plot(
  data = analysis_data,
  outcome = "PAIN CATASTROPHIZING",
  y_label = "PAIN CATASTROPHIZING",
  output_stem = "figure_1_pain_catastrophizing_by_pain_group"
)

create_group_plot(
  data = analysis_data,
  outcome = "KINESIOPHOBIA (TSK)",
  y_label = "KINESIOPHOBIA (TSK)",
  output_stem = "figure_2_kinesiophobia_by_pain_group"
)

capture.output(
  sessionInfo(),
  file = "results/02_statistical_analysis_session_info.txt"
)

message("Statistical analyses and figures completed successfully.")
