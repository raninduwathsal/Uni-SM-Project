# IT3081 Statistical Modelling — Standalone Consultancy Deliverables Package
**Client:** BladeGen Tech (F&B Chain POS Data Analytics)  
**Academic Course:** IT3081 Statistical Modelling  
**Consultancy Group:** Group 4  
**Industry Partner Consultation:** Mr. Kusan Edirisinghe (CEO, BladeGen Tech)  

---

## 📁 Package Directory Structure

```
Uni_SM_Project_Standalone/
├── 01_Data/
│   └── restaurant_transactions.csv             # The calibrated, authentic 90-day POS transaction dataset (29,465 records)
├── 02_R_Scripts/
│   ├── 01_data_cleaning.R                      # Source audit, missingness audit, label standardization & revenue derivation
│   ├── 02_descriptive_stats.R                  # Numerical dispersion, categorical shares, diurnal & daypart clustering
│   ├── 03_visualizations.R                     # Publication-quality ggplot2 visualization suite
│   ├── 04_statistical_inference.R              # 6 formal hypothesis tests (Welch t, F-test, ANOVA, Chi-Square, Kruskal-Wallis, Correlation)
│   ├── 05_modelling.R                          # 4-member classification tournament (LDA Champion, Multinomial, QDA, Naive Bayes)
│   ├── 07_pca.R                                # Principal Component Analysis, variance decomposition & pre-vs-post evaluation
│   ├── 08_bayesian.R                           # Empirical priors, Naive Bayes likelihoods & asymmetric loss decision theory
│   ├── 09_timeseries.R                         # 7-day STL seasonal decomposition & 30-day forward Seasonal ARIMA forecast
│   └── outputs/                                # Synchronized tabular reports, CSV metrics & publication figures
│       ├── 01_source_audit.csv                 # 29,465 items, 20,476 unique orders, 39 products, 80 outlets
│       ├── df_clean.csv                        # Cleaned dataset with derived features
│       ├── summary_categorical.csv             # Exact category frequencies (Beverage 52.17%, Food 33.71%, Deals 8.73%, Merch 5.39%)
│       ├── summary_numeric.csv                 # Continuous feature distributions (Qty1, Rate, Discount, ServiceCharge, Revenue, Age)
│       ├── inference_summary.csv               # Complete hypothesis test statistics, p-values, and effect sizes
│       ├── statistical_inference_report.txt    # Full narrative hypothesis testing report (Welch t=2.0266, p=0.0427, diff=+LKR 14.57)
│       ├── model_evaluation_metrics.csv        # 4-member predictive leaderboard (LDA Champion 76.29% Top-1, 76.18% Macro-F1)
│       ├── model_comprehensive_metrics.csv     # Extended validation suite (Balanced Acc, MCC, Cohen's Kappa, ROC-AUC, Log Loss, Brier)
│       ├── predictive_modelling_report.txt     # Comprehensive predictive tournament narrative report
│       ├── pca_importance.csv                  # Eigenvalues and variance explained per PC (PC1=45.30%, PC2=20.22%, Cum=65.52%)
│       ├── pca_pre_post_comparison.csv         # Empirical proof of why PCA was rejected (76.29% drops by 8.54 to 11.91 percentage points)
│       ├── bayesian_priors.csv                 # Empirical class priors (Bev 52.17%, Food 33.71%, Deals 8.73%, Merch 5.39%)
│       ├── bayesian_methods_report.txt         # Critical Bayesian evaluation report
│       ├── timeseries_forecast_30days.csv      # Daily April demand forecast (6,143 total projected orders)
│       ├── timeseries_analysis_report.txt      # 7-day weekly ARIMA report with Ljung-Box diagnostic validation (p=0.3982)
│       └── figures/                            # Publication-quality high-resolution visualizations
├── 03_Presentation/
│   └── SM_Presentation.pptx                    # Master 34-slide 16:9 widescreen presentation deck
└── 04_Reports_and_Documentation/
    ├── IT3081_Presentation_Script_and_Defense_Guide.pdf        # Word-for-word slide-by-slide spoken script with research citations
    ├── IT3081_Comprehensive_Viva_Defense_Questionnaire.pdf     # 10-page master question bank with 3-tier defenses & examiner traps
    ├── IT3081_Final_Consultancy_Report.docx                    # Executive consultancy report (Word format)
    └── IT3081_Final_Consultancy_Report.md                      # Executive consultancy report (Markdown format)
```

---

## 🚀 Execution Instructions (In R or RStudio)

To run the full statistical pipeline:

1. Open R or RStudio and set working directory to `02_R_Scripts/`:
   ```R
   setwd("02_R_Scripts")
   ```
2. Run data cleaning (loads `../01_Data/restaurant_transactions.csv`):
   ```R
   source("01_data_cleaning.R")
   ```
3. Run descriptive statistics and EDA:
   ```R
   source("02_descriptive_stats.R")
   ```
4. Run statistical inference (6 formal hypothesis tests):
   ```R
   source("04_statistical_inference.R")
   ```
5. Run the 4-member predictive modelling tournament:
   ```R
   source("05_modelling.R")
   ```
6. Run PCA and Bayesian evaluations:
   ```R
   source("07_pca.R")
   source("08_bayesian.R")
   ```
7. Run time-series demand forecasting:
   ```R
   source("09_timeseries.R")
   ```

All generated tabular reports and figures will be deposited into `02_R_Scripts/outputs/`, **100% perfectly matching every slide in `03_Presentation/SM_Presentation.pptx`**.
