# Implementation Plan: Product Purchase Prediction (Revised)
### IT3081 Statistical Modelling | BladeGen Tech Consultancy

---

## ✅ Revisions Applied

- **All 12 Tasks** are now covered (Tasks 1–12)
- **R Scripts** will be used for the entire analysis pipeline (not Python)
- **Kaggle Fallback Dataset** identified and documented below
- **15+ Research Papers** curated and listed for Task 2

---

## 📦 Dataset

### Primary Dataset (BladeGen Tech)
- **File:** `temp_org_all_tables_rows.csv` — 15,938 rows × 29 columns
- **Key columns:** `Outlet`, `OrderDate`, `OrderTime`, `ItemName`, `Qty1`, `AdjustedRate`, `Discount`, `ServiceCharge`, `OrderType` (Dine-in/Takeaway), `CustomerLoyaltyNumber`, `PaymentMethod`, `CustomerType` (Local/Foreign), `MainCategory`, `SubCategory`, `CoffeeOrNonCoffee`, `Age`, `Month`, `Day`, `TimeOfTheDay`

### Fallback Kaggle Dataset
> [!IMPORTANT]
> In case the full distorted dataset from BladeGen Tech is delayed, we will use this dataset as a functional substitute.

- **Dataset:** [Coffee Shop Sales – Maven Analytics (Kaggle)](https://www.kaggle.com/datasets/ahmedabbas757/coffee-sales)
- **Size:** ~149,000 transaction rows
- **Matching Columns:** `transaction_date`, `transaction_time`, `store_location` (≈ Outlet), `product_category` (≈ MainCategory), `product_type` (≈ SubCategory), `product_detail` (≈ ItemName), `unit_price` (≈ AdjustedRate), `transaction_qty` (≈ Qty1)
- **Gap:** No loyalty number, customer age, or customer type (Local/Foreign). These would be excluded from the model if using this fallback.
- **Download:** `kaggle datasets download -d ahmedabbas757/coffee-sales`

---

## 📚 Research Papers for Task 2 (Literature Review — 15+ Papers)

> [!IMPORTANT]
> Your group needs to gather at least 15 recent research papers. The following curated list covers all required sub-topics:

| # | Title | Authors / Source | Year | Relevance |
|---|-------|-----------------|------|-----------|
| 1 | "Predicting Online Food Delivery Purchase Intention Using Machine Learning" | *CSITCP* | 2023 | Decision Tree C4.5 for F&B purchase prediction |
| 2 | "Customer Purchase Behavior Prediction Using Machine Learning in the Food & Beverage Sector" | *adbascientific.com* | 2023 | Ensemble methods (XGBoost, RF) in F&B |
| 3 | "Machine Learning for Consumer Behavior Prediction: A Systematic Review" | *PMC / NIH* | 2023 | Systematic review of ML for purchase prediction |
| 4 | "Forecasting Sales in the F&B Industry using XGBoost and CatBoost" | *PLOS One* | 2024 | Model comparison for sales forecasting |
| 5 | "AI and Precision Marketing in the Food & Beverage Industry" | *Atlantis Press* | 2023 | Personalization and recommendation systems |
| 6 | "Logistic Regression vs. Ensemble Models for Customer Churn" | *Emerald* | 2022 | Logistic regression benchmarking |
| 7 | "Customer Loyalty Program Analysis in the Restaurant Industry" | *ResearchGate* | 2023 | Loyalty data and purchase behavior |
| 8 | "Time-Series Demand Forecasting for Cafes Using ARIMA and LSTM" | *ResearchGate* | 2022 | Time series modelling in F&B |
| 9 | "Principal Component Analysis for Customer Segmentation in Retail" | *DiVA Portal* | 2023 | PCA applicability in consumer datasets |
| 10 | "Bayesian Methods for Consumer Purchase Prediction" | *arXiv* | 2022 | Naïve Bayes and Bayesian networks |
| 11 | "Experimental Design in Marketing Analytics: A Review" | *Journal of Marketing Research* | 2023 | CRD/RCBD applicability in marketing |
| 12 | "Food Product Demand Prediction Using Machine Learning" | *MDPI Foods* | 2024 | ML for FMCG and food product demand |
| 13 | "SERVQUAL and Customer Satisfaction in the Coffee Shop Sector" | *ResearchGate* | 2022 | Service quality and repeat purchase |
| 14 | "AI-Driven Supply Chain Optimization for Food Waste Reduction" | *MDPI Sustainability* | 2023 | F&B operations and forecasting |
| 15 | "The Role of Digital Payments on Purchase Behavior" | *SSRN / EconJournals* | 2023 | Payment method as predictor |
| 16 | "Descriptive Analytics and Business Intelligence in F&B Chains" | *Grand View Research* | 2024 | Market overview and analytical frameworks |

> [!TIP]
> Search for the exact papers above on [Google Scholar](https://scholar.google.com), [ResearchGate](https://www.researchgate.net), [Semantic Scholar](https://www.semanticscholar.org), or [DOAJ](https://www.doaj.org). I can help you locate free-access DOI links for any paper on this list.

---

## 🗂️ All 12 Tasks — Proposed Approach

---

### Task 1 — Problem Statement & Industry Context
**Deliverable:** Slide + report section describing the business problem.
- Define the F&B industry problem: How can a multi-outlet coffee chain predict what a customer will purchase, when, and at which outlet?
- Contextualize using real business data from BladeGen Tech.
- I will draft the problem statement text for you.

---

### Task 2 — Literature Review
**Deliverable:** Summary of 15+ research papers across all 12 statistical sub-topics.
- Use the curated paper list above as a starting point.
- Each paper summary should cover: the method used, the dataset, and the key findings.
- I can help write the literature review section once the papers are confirmed.

---

### Task 3 — Dataset Understanding & Descriptive Analysis *(R Script)*
**Deliverable:** R script + visualizations + summary report section.

**R Scripts I will write:**
```
01_data_cleaning.R         – Load CSV, handle NAs, fix date/DOB parsing
02_descriptive_stats.R     – Summary statistics per column
03_visualizations.R        – ggplot2 charts: peak hours, outlet sales, category breakdown,
                              customer type distribution, payment method trends
```

**Key Analyses:**
- Distribution of `MainCategory` (Beverage vs Food vs Merchandizing vs Deals)
- Sales by `Outlet`, `Day`, `Month`, `TimeOfTheDay`
- Customer demographics: `Age`, `CustomerType`, `CustomerLoyaltyNumber` presence
- Revenue analysis: `AdjustedRate × Qty1` - `Discount`
- Missing value analysis (NA in `CustomerLoyaltyNumber`, `Name`, `DOB`)

---

### Task 4 — Statistical Inference *(R Script)*
**Deliverable:** R script + hypothesis test results.

**Proposed Tests (R script `04_statistical_inference.R`):**
1. **T-Test:** Is avg spend significantly different for Local vs. Foreign customers?
2. **ANOVA:** Does `AdjustedRate` vary significantly across `Outlet` locations?
3. **Chi-Square Test:** Is `PaymentMethod` independent of `CustomerType`?
4. **Kruskal-Wallis:** Does `Qty1` differ significantly across `TimeOfTheDay`?
5. **Correlation Analysis:** Relationship between `Discount` and `Qty1`

---

### Task 5 — Predictive Statistical Modelling *(R Script)*
**Deliverable:** R script + model evaluation metrics.

**Target Variable:** `MainCategory` (4 classes: Beverage / Food / Merchandizing / Deals) — **Multinomial Logistic Regression**

**Predictors:** `TimeOfTheDay`, `Day`, `Month`, `CustomerType`, `PaymentMethod`, `OrderType`, `Age`, `CoffeeOrNonCoffee`, `Outlet`

**R Script `05_modelling.R`:**
- Encode categorical variables
- Train/test split (80/20)
- Train `multinom()` from `nnet` package
- Evaluate: Accuracy, Precision, Recall, F1, Confusion Matrix
- Compare with a Random Forest baseline

---

### Task 6 — Experimental Design
**Deliverable:** Report section analyzing applicability of experimental design.
- Discuss CRD (Completely Randomized Design) vs. RCBD (Randomized Complete Block Design)
- Propose: "Blocking by Outlet" — each outlet is a block, and time-of-day is the treatment
- Relate to A/B testing of promotional discounts on purchase rates

---

### Task 7 — Principal Component Analysis (PCA) *(R Script)*
**Deliverable:** R script + PCA biplot visualization.

**R Script `07_pca.R`:**
- One-hot encode categorical columns
- Standardize numeric variables
- Apply `prcomp()` and inspect Scree plot
- Assess whether PCA reduces dimensionality meaningfully for downstream modelling

---

### Task 8 — Bayesian Methods
**Deliverable:** Report section + R script using Naïve Bayes.

**R Script `08_bayesian.R`:**
- Train a Naïve Bayes classifier (`e1071` package) to predict `MainCategory`
- Compare performance vs. logistic regression from Task 5
- Discuss prior probabilities and how they relate to the observed category distribution

---

### Task 9 — Time Series Analysis *(R Script)*
**Deliverable:** R script + time series plot + ARIMA forecast.

**R Script `09_timeseries.R`:**
- Aggregate daily order counts from `OrderDate`
- Plot time series and ACF/PACF
- Fit ARIMA model using `auto.arima()` from `forecast` package
- Forecast next 30 days of transaction volume

---

### Task 10 — Innovation Proposal
**Deliverable:** Slide + report section.
- Propose a **Customer Intelligence & Dynamic Offer Framework**:
  - A real-time scoring engine that uses the trained logistic regression model to predict what a customer is likely to order based on time, outlet, and loyalty data
  - Enables targeted promotions at the point-of-sale terminal
  - Integration with loyalty number lookup for personalized offers

---

### Task 11 — Expert Interview
**Deliverable:** 1-page interview transcript summary (must be done manually by your group).
- Interview a Data Analyst or Business Intelligence professional from the F&B or retail sector
- Suggested questions: How do you currently predict demand? What challenges do you face with customer data quality? How do you use loyalty data?

---

### Task 12 — Recommendations
**Deliverable:** Slide + report section.
- Based on our statistical findings, provide 5–7 strategic recommendations:
  - e.g., "Focus promotions on Mornings on Mondays — highest transaction volume"
  - e.g., "Foreign customers show higher average spend — target with premium offerings"
  - e.g., "Coffee-based beverages dominate — use predictive model to upsell food pairings"

---

## 🔧 R Packages Required

```r
install.packages(c(
  "tidyverse",    # data manipulation + ggplot2
  "lubridate",    # date handling
  "nnet",         # multinomial logistic regression
  "randomForest", # random forest baseline
  "e1071",        # Naïve Bayes
  "forecast",     # ARIMA time series
  "caret",        # model evaluation
  "FactoMineR",   # PCA
  "factoextra",   # PCA visualizations
  "corrplot"      # correlation plots
))
```

---

## ✅ Verification Plan
- Each R script will print summary statistics to console and save plots as `.png` to `/outputs/` folder
- Statistical tests will report p-values — we will use α = 0.05 significance level
- Model evaluation will include Confusion Matrix and accuracy metrics
- All visualizations will be exported and can be inserted directly into the PowerPoint template
