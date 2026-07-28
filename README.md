# Pain intensity analyses and XGBoost classification in pregnancy

This repository contains the R code used for the descriptive analyses, non-parametric group comparisons, manuscript figures, and XGBoost classification model associated with a **Scientific Reports** manuscript.

## Repository structure

```text
.
├── R/
│   ├── 01_prepare_data.R
│   ├── 02_statistical_analysis.R
│   └── 03_xgboost_model.R
├── data/
│   └── README.md
├── figures/
│   └── .gitkeep
├── results/
│   └── .gitkeep
├── install_packages.R
├── run_all.R
├── CITATION.cff
├── LICENSE
├── .gitignore
└── README.md
```

## Analysis workflow

1. `R/01_prepare_data.R` imports and validates the authorised Excel dataset, derives the pain categories, and creates the analysis-ready objects.
2. `R/02_statistical_analysis.R` produces the descriptive table, Kruskal-Wallis tests, Bonferroni-adjusted pairwise Wilcoxon tests, and manuscript figures.
3. `R/03_xgboost_model.R` performs the stratified train/test split, repeated cross-validation, hyperparameter tuning, held-out evaluation, ROC analysis, and variable-importance analysis.
4. `run_all.R` runs the complete workflow in the correct order.

## Data confidentiality

The participant-level dataset is **not included** in this repository because it may contain sensitive human-participant information.

Place an authorised copy of the Excel file in the `data/` directory using the following filename:

```text
pain-pregnancy_dataset.xlsx
```

The `.gitignore` file prevents Excel and CSV data files from being committed accidentally. Nevertheless, always inspect the files listed by Git before every commit.

## Software environment

The predictive analysis was reproduced with:

- R 4.4.3
- caret 7.0-1
- xgboost 1.7.8.1
- Matrix 1.7-2
- recipes 1.3.1
- dplyr 1.2.0
- pROC 1.19.0.1
- readxl 1.4.5

The scripts write a separate `sessionInfo()` file for every analysis stage.

## Installation

From the repository root, run:

```r
source("install_packages.R")
```

## Running the complete workflow

From RStudio:

```r
source("run_all.R")
```

From a terminal:

```bash
Rscript run_all.R
```

To use a dataset stored elsewhere:

```bash
Rscript run_all.R "/path/to/authorised_dataset.xlsx"
```

## Statistical methods

Pain intensity is categorised as:

- `Non-pain/mild`: pain intensity ≤ 3
- `Moderate`: pain intensity from 4 to 6
- `Severe`: pain intensity > 6

Overall differences among pain groups are tested using Kruskal-Wallis rank-sum tests. Pairwise comparisons use Wilcoxon rank-sum tests with Bonferroni adjustment.

The binary XGBoost outcome is defined as:

- `NO`: pain intensity ≤ 3
- `YES`: pain intensity > 3

The model uses a stratified 80/20 train/test split, 10-fold repeated cross-validation with three repeats, down-sampling within resampling, ROC as the optimisation metric, and the fixed random seed `123`.

## Main outputs

The workflow writes analysis products to `results/` and figures to `figures/`. These include:

- descriptive statistics in DOCX and CSV format;
- Kruskal-Wallis and pairwise Wilcoxon results;
- pain catastrophizing and kinesiophobia figures in PNG and PDF;
- the fitted XGBoost model;
- tuning results and selected hyperparameters;
- confusion-matrix metrics;
- ROC curve, AUC, and confidence interval;
- ranked variable importance;
- software-session information.

Generated results are excluded from version control by default. The exact outputs used in the article may be added manually to a tagged release when appropriate and after checking that they contain no participant-level information.

## Code availability statement

Suggested manuscript wording:

> **Code availability**  
> The R code used for data preparation, descriptive analyses, non-parametric group comparisons, figure generation, predictive modelling, model evaluation, ROC analysis, and variable-importance analysis is publicly available at [https://github.com/juaparal/pain-pregnancy-xgboost-analysis]. The version corresponding to the published article is permanently archived in Zenodo at [ZENODO DOI]. Participant-level data are not included because of privacy and ethical restrictions.

## Archiving with Zenodo

1. Complete the metadata placeholders in `CITATION.cff`.
2. Push the repository to GitHub.
3. Review all tracked files and confirm that no participant-level data are included.
4. Create a GitHub release, for example `v1.0.0`.
5. Connect the repository to Zenodo and archive the release.
6. Add the Zenodo DOI to this README, `CITATION.cff`, and the manuscript.

## Citation

Please cite both the associated article and the archived software release.

## License

The analysis code is distributed under the MIT License. See `LICENSE`.
