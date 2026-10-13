# IT3081 Statistical Modelling — Final Submission Package

## Project Information
* **Module:** IT3081 – Statistical Modelling
* **Assignment:** Group Assignment (100% Final Submission)
* **Topic:** Product Purchase Prediction & Demand Intelligence: From Data to Strategic Decisions
* **Client Organization:** BladeGen Tech Consultancy (Multi-Outlet F&B Chain)
* **Group:** Group 4
* **Submission Date:** September 2026

---

## 📁 Directory Structure & Deliverables

```
Final Final SM Project/
├── 01_Reports_and_Documentation/
│   ├── IT3081_Final_Consultancy_Report.docx    # Official Formatted Word Report (Ready for submission)
│   ├── IT3081_Final_Consultancy_Report.md      # Full Technical Markdown Report
│   ├── Ranindu_Project Approval_20.09.2026.docx.pdf # Official Client Approval Letter
│   └── Group Assignment brief.pdf             # SLIIT Coursework Brief & Rubric
│
├── 02_Presentation/
│   └── Final_Consultancy_Presentation_BladeGen_Tech.pptx  # 26-Slide Presentation Deck with Speaker Notes
│
├── 03_R_Scripts/
│   ├── 01_data_cleaning.R                     # 8-Point source integrity audit & missing data resolution
│   ├── 02_descriptive_stats.R                 # Descriptive statistics, skewness, kurtosis, outlier analysis
│   ├── 03_visualizations.R                    # 6 Publication-quality ggplot2 visualization figures
│   ├── 04_statistical_inference.R             # 6 Classical hypothesis tests strictly aligned with Note 01
│   ├── 05_modelling.R                         # 4-Member tournament: Multinomial Logit, LDA, QDA, Naive Bayes
│   ├── 07_pca.R                               # Principal Component Analysis (Scree plot & Biplot)
│   ├── 08_bayesian.R                          # Bayesian priors, conditional likelihoods & loss evaluation
│   └── 09_timeseries.R                        # STL seasonal decomposition & Seasonal ARIMA(0,0,0)(0,1,1)[7]
│
├── 04_Data/
│   ├── restaurant_transactions.csv            # Clean base POS transaction dataset (29,465 line items)
│   └── restaurant_transactions_enhanced.csv   # Enhanced multi-outlet dataset (80 outlets)
│
├── 05_Outputs_and_Figures/
│   ├── figures/                               # 13 High-resolution (300 DPI) publication figures
│   │   ├── fig1_category_revenue.png
│   │   ├── fig2_outlet_performance.png
│   │   ├── fig3_hourly_weekly_traffic.png
│   │   ├── fig4_customer_type_spend.png
│   │   ├── fig5_payment_method_share.png
│   │   ├── fig6_loyalty_impact.png
│   │   ├── fig_confusion_matrix.png
│   │   ├── fig_model_comparison.png
│   │   ├── fig_pca_scree.png
│   │   ├── fig_pca_biplot.png
│   │   ├── fig_timeseries_decomposition.png
│   │   ├── fig_timeseries_acf.png
│   │   └── fig_timeseries_forecast.png
│   └── reports_and_tables/                    # Summary CSVs and statistical test outputs
│       ├── model_evaluation_metrics.csv
│       ├── statistical_inference_report.txt
│       ├── source_integrity_audit.csv
│       └── ...
│
└── README.md                                  # This master submission guide
```

---

## 🎯 Syllabus Alignment Overview (IT3081 Notes 01–09)

| Task | Syllabus Topic | Implementation & Script | Deliverables / Metrics |
| :--- | :--- | :--- | :--- |
| **Task 1** | Industry Problem & Context | Section 1 of Report & Slide 3–4 | 80-outlet F&B operation, perishability & rush bottlenecks |
| **Task 2** | Literature Review | Section 2 of Report & Slide 5–6 | 16-Paper systematic review matrix (10 journals, 6 conferences) |
| **Task 3** | Data Quality & Audit | `01_data_cleaning.R`, `02_descriptive_stats.R`, `03_visualizations.R` | 8-Point integrity audit, zero order conflicts, 6 ggplot2 figures |
| **Task 4** | Statistical Inference | `04_statistical_inference.R` (Strictly **Note 01**) | Welch t-test, Fisher F-test, One-Way ANOVA (no Tukey), Chi-Square, Kruskal-Wallis, Correlation |
| **Task 5** | 4-Member Modelling | `05_modelling.R` (**Notes 03, 05, 06, 07, 09**) | M1: Multinomial Logit 🏆 (Top-2: **93.36%**, Top-1: 56.36%), M2: LDA (92.52%), M3: QDA (91.85%), M4: Naive Bayes (91.73%); Ridge & LASSO ($R^2 > 99\%$) |
| **Task 6** | Experimental Design | Section 6 of Report & Slide 18 | Critical evaluation: CRD vs. RCBD (Store blocking formula) |
| **Task 7** | PCA Evaluation | `07_pca.R` & Section 7 of Report | 5 features, 85.4% var in 3 PCs, evaluation of limits for retail POS |
| **Task 8** | Bayesian Methods | `08_bayesian.R` & Section 8 of Report | Empirical priors, dynamic likelihood updating, loss-aware decision rule |
| **Task 9** | Time Series Analysis | `09_timeseries.R` & Section 9 of Report | STL 7-day decomposition, Seasonal ARIMA(0,0,0)(0,1,1)[7] with drift, 30-day demand forecast |
| **Task 10** | Innovation Proposal | Section 10 of Report & Slide 23 | Customer Intelligence Framework (CIF) with Edge POS engine |
| **Task 11** | Expert Validation | Section 11 of Report & Slide 24 | Consultation with Dr. Kasun Dissanayake (Head of Retail BI) |
| **Task 12** | Consultancy Roadmap | Section 12 of Report & Slide 25–26 | 3-Phase operational rollout, risk management & ethical governance |

---

## 🚀 How to Execute the Analysis

To re-run the entire pipeline from scratch, open RStudio or an R terminal in the project root:

```r
# Step 1: Run data cleaning and integrity audit
source("03_R_Scripts/01_data_cleaning.R")

# Step 2: Compute descriptive statistics
source("03_R_Scripts/02_descriptive_stats.R")

# Step 3: Generate publication figures
source("03_R_Scripts/03_visualizations.R")

# Step 4: Run the 6 Note 01 hypothesis tests
source("03_R_Scripts/04_statistical_inference.R")

# Step 5: Execute 4-member predictive modelling tournament
source("03_R_Scripts/05_modelling.R")

# Step 6: Perform PCA
source("03_R_Scripts/07_pca.R")

# Step 7: Perform Bayesian analysis
source("03_R_Scripts/08_bayesian.R")

# Step 8: Run Time Series STL decomposition & Seasonal ARIMA forecast
source("03_R_Scripts/09_timeseries.R")
```
