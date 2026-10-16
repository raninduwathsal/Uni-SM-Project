# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 3: Descriptive Analysis & Outlier Detection
# Script: 02_descriptive_stats.R
# Dataset: BladeGen Tech Restaurant Transactions
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(janitor)
})

cat("====================================================\n")
cat(" Task 3: Comprehensive Descriptive Statistics & EDA\n")
cat("====================================================\n\n")

# --- 1. LOAD CLEANED DATA ---
data_path <- "outputs/df_clean.csv"
if (!file.exists(data_path)) {
  data_path <- "R Scripts/outputs/df_clean.csv"
}

df <- read_csv(data_path, show_col_types = FALSE)
cat(sprintf("✔ Loaded dataset: %d rows × %d columns\n\n", nrow(df), ncol(df)))

# --- 2. NUMERIC SUMMARY WITH SKEWNESS & DISPERSION ---
cat("--- 2. Comprehensive Numeric Feature Summary ---\n")

calc_skewness <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x)
  if (n < 3) return(NA)
  m3 <- sum((x - mean(x))^3) / n
  s3 <- (sum((x - mean(x))^2) / n)^(3/2)
  m3 / s3
}

calc_kurtosis <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x)
  if (n < 4) return(NA)
  m4 <- sum((x - mean(x))^4) / n
  s4 <- (sum((x - mean(x))^2) / n)^2
  (m4 / s4) - 3
}

num_vars <- c("Qty1", "AdjustedRate", "Discount", "ServiceCharge", "Revenue", "Age")

numeric_summary <- df %>%
  select(all_of(num_vars)) %>%
  pivot_longer(everything(), names_to = "Variable", values_to = "Value") %>%
  group_by(Variable) %>%
  summarise(
    N_Valid = sum(!is.na(Value)),
    N_Missing = sum(is.na(Value)),
    Missing_Pct = round(sum(is.na(Value)) / n() * 100, 2),
    Mean = round(mean(Value, na.rm = TRUE), 2),
    SD = round(sd(Value, na.rm = TRUE), 2),
    Median = round(median(Value, na.rm = TRUE), 2),
    IQR = round(IQR(Value, na.rm = TRUE), 2),
    Min = round(min(Value, na.rm = TRUE), 2),
    Max = round(max(Value, na.rm = TRUE), 2),
    Skewness = round(calc_skewness(Value), 3),
    Kurtosis = round(calc_kurtosis(Value), 3),
    .groups = "drop"
  )

print(as.data.frame(numeric_summary))
write_csv(numeric_summary, "outputs/summary_numeric.csv")
cat("✔ Numeric summary saved to outputs/summary_numeric.csv\n\n")

# --- 3. OUTLIER DETECTION (IQR & Z-SCORE) ---
cat("--- 3. Outlier Detection Assessment ---\n")

outlier_list <- list()

for (col in num_vars) {
  vals <- df[[col]]
  vals_clean <- vals[!is.na(vals)]
  
  # IQR method
  q25 <- quantile(vals_clean, 0.25)
  q75 <- quantile(vals_clean, 0.75)
  iqr_val <- q75 - q25
  lower_bound <- q25 - 1.5 * iqr_val
  upper_bound <- q75 + 1.5 * iqr_val
  iqr_outliers <- sum(vals_clean < lower_bound | vals_clean > upper_bound)
  
  # Z-score method
  z_scores <- (vals_clean - mean(vals_clean)) / sd(vals_clean)
  z_outliers <- sum(abs(z_scores) > 3)
  
  outlier_list[[length(outlier_list) + 1]] <- data.frame(
    Variable = col,
    N_Evaluated = length(vals_clean),
    IQR_Lower_Threshold = round(lower_bound, 2),
    IQR_Upper_Threshold = round(upper_bound, 2),
    IQR_Outlier_Count = iqr_outliers,
    IQR_Outlier_Pct = round(iqr_outliers / length(vals_clean) * 100, 2),
    Z_Score_Outliers_AbsGt3 = z_outliers,
    Z_Score_Outlier_Pct = round(z_outliers / length(vals_clean) * 100, 2),
    stringsAsFactors = FALSE
  )
}

outlier_summary <- bind_rows(outlier_list)
print(as.data.frame(outlier_summary))
write_csv(outlier_summary, "outputs/outlier_summary.csv")
cat("✔ Outlier analysis saved to outputs/outlier_summary.csv\n\n")

# --- 4. CATEGORICAL BREAKDOWN ---
cat("--- 4. Categorical Distributions ---\n")

cat_vars <- c("MainCategory", "CustomerType", "PaymentMethod", "OrderType", "TimeOfTheDay", "Day", "Month", "IsLoyaltyMember")

cat_summary_list <- list()

for (cvar in cat_vars) {
  res <- df %>%
    count(.data[[cvar]], name = "Frequency") %>%
    mutate(
      Variable = cvar,
      Category = as.character(.data[[cvar]]),
      Percentage = round(Frequency / nrow(df) * 100, 2)
    ) %>%
    select(Variable, Category, Frequency, Percentage)
  cat_summary_list[[length(cat_summary_list) + 1]] <- res
}

summary_categorical <- bind_rows(cat_summary_list)
write_csv(summary_categorical, "outputs/summary_categorical.csv")
cat("✔ Categorical distributions saved to outputs/summary_categorical.csv\n\n")

# --- 5. GROUPED BUSINESS INSIGHTS ---
cat("--- 5. Key Grouped Revenue & Volume Insights ---\n")

# 5.1 Revenue by Main Category
cat("\n[Revenue & Volume by MainCategory]:\n")
cat_rev <- df %>%
  group_by(MainCategory) %>%
  summarise(
    Orders_Count = n(),
    Total_Revenue = round(sum(Revenue, na.rm = TRUE), 2),
    Mean_Revenue = round(mean(Revenue, na.rm = TRUE), 2),
    Revenue_Share_Pct = round(sum(Revenue, na.rm = TRUE) / sum(df$Revenue, na.rm = TRUE) * 100, 2),
    .groups = "drop"
  ) %>%
  arrange(desc(Total_Revenue))
print(as.data.frame(cat_rev))

# 5.2 Revenue by Customer Type
cat("\n[Revenue by Customer Type (Local vs. Foreign)]:\n")
cust_rev <- df %>%
  group_by(CustomerType) %>%
  summarise(
    Orders_Count = n(),
    Total_Revenue = round(sum(Revenue, na.rm = TRUE), 2),
    Mean_Revenue = round(mean(Revenue, na.rm = TRUE), 2),
    SD_Revenue = round(sd(Revenue, na.rm = TRUE), 2),
    Median_Revenue = round(median(Revenue, na.rm = TRUE), 2),
    .groups = "drop"
  )
print(as.data.frame(cust_rev))

# 5.3 Top 10 Outlets by Total Revenue
cat("\n[Top 10 Outlets by Total Sales Volume & Revenue]:\n")
outlet_rev <- df %>%
  group_by(Outlet) %>%
  summarise(
    Transactions = n(),
    Total_Revenue = round(sum(Revenue, na.rm = TRUE), 2),
    Mean_Revenue = round(mean(Revenue, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(Total_Revenue)) %>%
  slice_head(n = 10)
print(as.data.frame(outlet_rev))

# 5.4 Revenue by Time of Day
cat("\n[Performance by Time of the Day]:\n")
tod_rev <- df %>%
  group_by(TimeOfTheDay) %>%
  summarise(
    Item_Sales_Count = n(),
    Total_Revenue = round(sum(Revenue, na.rm = TRUE), 2),
    Mean_Revenue = round(mean(Revenue, na.rm = TRUE), 2),
    Avg_Discount = round(mean(Discount, na.rm = TRUE), 2),
    .groups = "drop"
  )
print(as.data.frame(tod_rev))

# Save grouped insights
write_csv(cat_rev, "outputs/grouped_category_revenue.csv")
write_csv(outlet_rev, "outputs/grouped_top10_outlets.csv")
write_csv(tod_rev, "outputs/grouped_time_of_day.csv")

cat("\n====================================================\n")
cat(" Descriptive Statistics Analysis Complete!\n")
cat("====================================================\n")
