# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 3: Data Understanding & Cleaning
# Script: 01_data_cleaning.R
# Dataset: BladeGen Tech - F&B Chain Transactions
# ============================================================

# --- Install required packages if not already installed ---
required_packages <- c("tidyverse", "lubridate", "janitor")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages, repos = "https://cloud.r-project.org")

library(tidyverse)
library(lubridate)
library(janitor)

cat("==============================================\n")
cat(" BladeGen Tech Dataset - Loading & Cleaning\n")
cat("==============================================\n\n")

# --- 1. LOAD DATA ---
data_path <- "../Courseweb Documents/SampleDataset/temp_org_all_tables_rows.csv"

df_raw <- read_csv(data_path, show_col_types = FALSE)

cat(sprintf("✔ Dataset loaded: %d rows × %d columns\n\n", nrow(df_raw), ncol(df_raw)))

# --- 2. INITIAL OVERVIEW ---
cat("--- Column Names ---\n")
print(names(df_raw))

cat("\n--- Data Types ---\n")
print(glimpse(df_raw))

# --- 3. MISSING VALUE ANALYSIS ---
cat("\n--- Missing Values per Column ---\n")
missing_summary <- df_raw %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "Column", values_to = "Missing_Count") %>%
  mutate(Missing_Pct = round(Missing_Count / nrow(df_raw) * 100, 2)) %>%
  arrange(desc(Missing_Count))

print(missing_summary)

# Save missing value summary
write_csv(missing_summary, "outputs/missing_value_summary.csv")
cat("\n✔ Missing value summary saved to outputs/missing_value_summary.csv\n")

# --- 4. CLEAN DATA ---
df_clean <- df_raw %>%
  # Standardise NA strings
  mutate(across(where(is.character), ~ na_if(., "NA"))) %>%
  mutate(across(where(is.character), ~ na_if(., ""))) %>%

  # Fix OrderDate to proper Date type
  mutate(OrderDate = ymd(OrderDate)) %>%

  # Fix OrderTime to proper time (HH:MM:SS)
  mutate(OrderTime = hms(OrderTime)) %>%

  # Create a flag: is customer loyalty member?
  mutate(IsLoyaltyMember = ifelse(!is.na(CustomerLoyaltyNumber), "Yes", "No")) %>%

  # Clean Age: replace 0 with NA (likely missing/unknown)
  mutate(Age = ifelse(Age == 0, NA, Age)) %>%

  # Create Revenue column: (AdjustedRate * Qty1) - Discount
  mutate(Revenue = (AdjustedRate * Qty1) - Discount) %>%

  # Standardise categorical columns
  mutate(
    MainCategory   = str_to_title(str_trim(MainCategory)),
    SubCategory    = str_to_title(str_trim(SubCategory)),
    CustomerType   = str_to_title(str_trim(CustomerType)),
    PaymentMethod  = str_to_upper(str_trim(PaymentMethod)),
    OrderType      = case_when(
      OrderType == "R" ~ "Dine-In",
      OrderType == "T" ~ "Takeaway",
      TRUE ~ OrderType
    ),
    TimeOfTheDay   = factor(TimeOfTheDay,
                            levels = c("Morning", "Afternoon", "Evening", "Night")),
    Day            = factor(Day,
                            levels = c("Monday","Tuesday","Wednesday","Thursday",
                                       "Friday","Saturday","Sunday")),
    Month          = factor(Month,
                            levels = c("January","February","March","April","May",
                                       "June","July","August","September","October",
                                       "November","December"))
  ) %>%

  # Remove the trailing 'End' column (empty)
  select(-any_of("End"))

cat(sprintf("\n✔ Cleaned dataset: %d rows × %d columns\n", nrow(df_clean), ncol(df_clean)))

# --- 5. SUMMARY STATISTICS ---
cat("\n--- Summary Statistics ---\n")
numeric_summary <- df_clean %>%
  select(Qty1, AdjustedRate, Discount, ServiceCharge, Revenue, Age) %>%
  summary()
print(numeric_summary)

cat("\n--- Category Distribution (MainCategory) ---\n")
print(df_clean %>% count(MainCategory, sort = TRUE))

cat("\n--- Customer Type Distribution ---\n")
print(df_clean %>% count(CustomerType, sort = TRUE))

cat("\n--- Payment Method Distribution ---\n")
print(df_clean %>% count(PaymentMethod, sort = TRUE))

cat("\n--- Order Type Distribution ---\n")
print(df_clean %>% count(OrderType, sort = TRUE))

cat("\n--- Loyalty Member Distribution ---\n")
print(df_clean %>% count(IsLoyaltyMember, sort = TRUE))

cat("\n--- Outlet Distribution ---\n")
print(df_clean %>% count(Outlet, sort = TRUE))

# --- 6. SAVE CLEAN DATA ---
write_csv(df_clean, "outputs/df_clean.csv")
cat("\n✔ Clean dataset saved to outputs/df_clean.csv\n")

cat("\n==============================================\n")
cat(" Data Cleaning Complete!\n")
cat("==============================================\n")
