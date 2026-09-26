# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 3: Data Understanding, Source Auditing & Cleaning Pipeline
# Script: 01_data_cleaning.R
# Dataset: BladeGen Tech - F&B Chain Transactions
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(janitor)
})

cat("====================================================\n")
cat(" BladeGen Tech Dataset - Loading, Auditing & Cleaning\n")
cat("====================================================\n\n")

# --- 1. LOAD DATA ---
synthetic_path <- "../Courseweb Documents/SampleDataset/synthetic_restaurant_transactions.csv"
raw_path <- "../Courseweb Documents/SampleDataset/temp_org_all_tables_rows.csv"
local_synth <- "Courseweb Documents/SampleDataset/synthetic_restaurant_transactions.csv"
local_raw <- "Courseweb Documents/SampleDataset/temp_org_all_tables_rows.csv"

data_path <- if (file.exists(synthetic_path)) {
  synthetic_path
} else if (file.exists(local_synth)) {
  local_synth
} else if (file.exists(raw_path)) {
  raw_path
} else {
  local_raw
}

df_raw <- read_csv(data_path, show_col_types = FALSE)
cat(sprintf("✔ Dataset successfully loaded: %d rows × %d columns\n\n", nrow(df_raw), ncol(df_raw)))

# --- 2. RIGOROUS SOURCE INTEGRITY & QUALITY AUDIT ---
cat("--- 2. Source Integrity & Data Quality Audit ---\n")

out_dir <- "outputs"
if (!dir.exists(out_dir)) out_dir <- "R Scripts/outputs"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# Check multi-line order consistency
order_conflicts <- df_raw %>%
  group_by(OrderNo) %>%
  summarise(
    distinct_dates = n_distinct(OrderDate),
    distinct_customers = n_distinct(CustomerLoyaltyNumber, na.rm = TRUE),
    distinct_order_types = n_distinct(OrderType, na.rm = TRUE),
    distinct_payments = n_distinct(PaymentMethod, na.rm = TRUE),
    .groups = "drop"
  )

audit_summary <- data.frame(
  Audit_Metric = c(
    "Total Purchased Item Lines",
    "Unique Transaction Orders",
    "Unique Identified Customers",
    "Distinct Products Recorded",
    "Orders with Date Consistency",
    "Orders with Multi-Payment Entries",
    "Orders with Multi-OrderType Entries",
    "Missing Customer Loyalty Numbers",
    "Missing Address / Contact Info"
  ),
  Value = c(
    as.character(nrow(df_raw)),
    as.character(n_distinct(df_raw$OrderNo)),
    as.character(n_distinct(df_raw$CustomerLoyaltyNumber, na.rm = TRUE)),
    as.character(n_distinct(df_raw$ItemName)),
    as.character(sum(order_conflicts$distinct_dates == 1)),
    as.character(sum(order_conflicts$distinct_payments > 1)),
    as.character(sum(order_conflicts$distinct_order_types > 1)),
    as.character(sum(is.na(df_raw$CustomerLoyaltyNumber))),
    as.character(if ("AddressLine1" %in% names(df_raw)) sum(is.na(df_raw$AddressLine1)) else nrow(df_raw))
  ),
  stringsAsFactors = FALSE
)

print(audit_summary)
write_csv(audit_summary, file.path(out_dir, "01_source_audit.csv"))
cat("✔ Source audit metrics saved to 01_source_audit.csv\n\n")

# --- 3. MISSING VALUE ANALYSIS ---
missing_summary <- df_raw %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "Column", values_to = "Missing_Count") %>%
  mutate(Missing_Pct = round(Missing_Count / nrow(df_raw) * 100, 2)) %>%
  arrange(desc(Missing_Count))

write_csv(missing_summary, file.path(out_dir, "missing_value_summary.csv"))
cat("✔ Missing value summary saved to missing_value_summary.csv\n\n")

# --- 4. ADVANCED DATA CLEANING & RECONCILIATION ---
cat("--- 4. Executing Cleaning & Feature Standardization ---\n")

df_clean <- df_raw %>%
  mutate(across(where(is.character), ~ na_if(., "NA"))) %>%
  mutate(across(where(is.character), ~ na_if(., ""))) %>%
  mutate(OrderDate = ymd(OrderDate)) %>%
  mutate(IsLoyaltyMember = ifelse(!is.na(CustomerLoyaltyNumber), "Yes", "No")) %>%
  mutate(Age = ifelse(Age == 0 | Age < 18 | Age > 100, NA, Age)) %>%
  mutate(Revenue = (AdjustedRate * Qty1) - Discount) %>%
  mutate(
    MainCategory = case_when(
      str_detect(str_to_lower(MainCategory), "bever") ~ "Beverage",
      str_detect(str_to_lower(MainCategory), "food") ~ "Food",
      str_detect(str_to_lower(MainCategory), "merch") ~ "Merchandizing",
      str_detect(str_to_lower(MainCategory), "deal") ~ "Deals",
      TRUE ~ str_to_title(str_trim(MainCategory))
    ),
    SubCategory   = str_to_title(str_trim(SubCategory)),
    CustomerType  = str_to_title(str_trim(CustomerType)),
    PaymentMethod = str_to_upper(str_trim(PaymentMethod)),
    OrderType     = case_when(
      OrderType %in% c("R", "D", "Dine-In", "Dine In") ~ "Dine-In",
      OrderType %in% c("T", "K", "Takeaway", "Take Away") ~ "Takeaway",
      TRUE ~ OrderType
    ),
    TimeOfTheDay  = factor(TimeOfTheDay, levels = c("Morning", "Afternoon", "Evening", "Night")),
    Day           = factor(Day, levels = c("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday")),
    Month         = factor(Month, levels = c("January","February","March","April","May","June","July","August","September","October","November","December"))
  ) %>%
  dplyr::select(-any_of(c("End", "AddressLine1", "Contact No", "Registered Outlet"))) %>%
  filter(!is.na(Revenue), Revenue >= 0)

cat(sprintf("✔ Cleaned dataset generated: %d observations × %d curated columns\n", nrow(df_clean), ncol(df_clean)))

# Save cleaned output
write_csv(df_clean, file.path(out_dir, "df_clean.csv"))
cat("✔ Clean dataset saved to df_clean.csv\n\n")

cat("==============================================\n")
cat(" Data Cleaning & Auditing Pipeline Complete!\n")
cat("==============================================\n")
