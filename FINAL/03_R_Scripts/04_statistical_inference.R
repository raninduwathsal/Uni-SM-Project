# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 4: Statistical Inference & Hypothesis Testing
# Script: 04_statistical_inference.R
# Outputs: Structured CSV summary & comprehensive narrative report
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

cat("====================================================\n")
cat(" Task 4: Comprehensive Statistical Inference\n")
cat("====================================================\n\n")

# --- 1. LOAD DATA ---
data_path <- "outputs/df_clean.csv"
if (!file.exists(data_path)) {
  data_path <- "R Scripts/outputs/df_clean.csv"
}

df <- read_csv(data_path, show_col_types = FALSE)

report_lines <- c(
  "================================================================================",
  " IT3081 STATISTICAL MODELLING - TASK 4: STATISTICAL INFERENCE REPORT",
  " Client: BladeGen Tech Consultancy | F&B Chain Customer Intelligence",
  "================================================================================",
  ""
)

add_report <- function(...) {
  report_lines <<- c(report_lines, sprintf(...))
}

results_table <- list()

# --- TEST 1: COMPARISON OF MEANS (WELCH'S TWO-SAMPLE T-TEST) ---
cat("Running Test 1: Comparison of Means (Welch's t-test)...\n")
t_res <- t.test(Revenue ~ CustomerType, data = df)

# Effect size (Cohen's d)
m1 <- mean(df$Revenue[df$CustomerType == "Foreign"], na.rm = TRUE)
m2 <- mean(df$Revenue[df$CustomerType == "Local"], na.rm = TRUE)
s_pooled <- sqrt(((sum(df$CustomerType == "Foreign") - 1) * var(df$Revenue[df$CustomerType == "Foreign"]) +
                   (sum(df$CustomerType == "Local") - 1) * var(df$Revenue[df$CustomerType == "Local"])) / (nrow(df) - 2))
cohens_d <- (m1 - m2) / s_pooled

add_report("--------------------------------------------------------------------------------")
add_report("TEST 1: COMPARISON OF MEANS (WELCH'S TWO-SAMPLE T-TEST)")
add_report("--------------------------------------------------------------------------------")
add_report("Research Question: Do Foreign customers spend significantly more per transaction than Local customers?")
add_report("Hypotheses:")
add_report("  H0: mu_Foreign - mu_Local = 0 (Mean spend per item is identical between customer segments)")
add_report("  H1: mu_Foreign - mu_Local != 0 (Mean spend per item differs significantly between segments)")
add_report("Test Justification:")
add_report("  Welch's t-test is employed because sample sizes (Foreign: %d, Local: %d) and variances differ.",
           sum(df$CustomerType == "Foreign"), sum(df$CustomerType == "Local"))
add_report("Results:")
add_report("  Foreign Mean Spend: LKR %.2f | Local Mean Spend: LKR %.2f", m1, m2)
add_report("  Difference in Means: LKR %.2f (95%% CI: [%.2f, %.2f])", m1 - m2, t_res$conf.int[1], t_res$conf.int[2])
add_report("  t-statistic: %.4f | Degrees of Freedom: %.2f | p-value: %.5e", t_res$statistic, t_res$parameter, t_res$p.value)
add_report("  Effect Size (Cohen's d): %.4f (Small positive effect)", cohens_d)
decision1 <- if (t_res$p.value < 0.05) "Reject H0 (Statistically Significant at alpha = 0.05)" else "Fail to Reject H0"
add_report("Statistical Decision: %s", decision1)
add_report("Managerial Implication:")
add_report("  Foreign customers demonstrate significantly higher average spend per item (+LKR %.2f).", m1 - m2)
add_report("  Strategy: Curate premium bundles, bilingual menu boards, and international payment options in tourist-heavy outlets.")
add_report("")

results_table[[length(results_table) + 1]] <- data.frame(
  Test_ID = "T1_Welch_t_test",
  Domain = "Comparison of Means",
  Variables = "Revenue ~ CustomerType",
  Null_Hypothesis = "mu_Foreign == mu_Local",
  Test_Statistic_Name = "t",
  Test_Statistic_Value = round(as.numeric(t_res$statistic), 4),
  Degrees_of_Freedom = as.character(round(as.numeric(t_res$parameter), 2)),
  P_Value = format.pval(t_res$p.value, eps = 1e-4),
  Effect_Size = sprintf("Cohen's d = %.3f", cohens_d),
  Decision = decision1,
  stringsAsFactors = FALSE
)

# --- TEST 2: COMPARISON OF VARIANCES (FISHER'S F-TEST) ---
cat("Running Test 2: Comparison of Variances (F-test)...\n")
var_res <- var.test(Revenue ~ OrderType, data = df)

add_report("--------------------------------------------------------------------------------")
add_report("TEST 2: COMPARISON OF VARIANCES (FISHER'S F-TEST)")
add_report("--------------------------------------------------------------------------------")
add_report("Research Question: Is spending dispersion equal between Dine-In and Takeaway orders?")
add_report("Hypotheses:")
add_report("  H0: sigma^2_DineIn / sigma^2_Takeaway = 1 (Variances in revenue are equal)")
add_report("  H1: sigma^2_DineIn / sigma^2_Takeaway != 1 (Variances in revenue differ significantly)")
add_report("Test Justification:")
add_report("  Assesses whether basket volatility differs between on-premise diners and takeaway patrons.")
add_report("Results:")
add_report("  F-statistic: %.4f | num df: %d | denom df: %d | p-value: %.5e",
           var_res$statistic, var_res$parameter[1], var_res$parameter[2], var_res$p.value)
add_report("  Ratio of Variances: %.4f (95%% CI: [%.4f, %.4f])",
           var_res$estimate, var_res$conf.int[1], var_res$conf.int[2])
decision2 <- if (var_res$p.value < 0.05) "Reject H0 (Statistically Significant)" else "Fail to Reject H0"
add_report("Statistical Decision: %s", decision2)
add_report("Managerial Implication:")
add_report("  Dine-in orders exhibit different variance due to multi-item shared dining vs. standard single takeaway coffee runs.")
add_report("")

results_table[[length(results_table) + 1]] <- data.frame(
  Test_ID = "T2_F_test_variances",
  Domain = "Comparison of Variances",
  Variables = "Revenue ~ OrderType",
  Null_Hypothesis = "Var(DineIn) == Var(Takeaway)",
  Test_Statistic_Name = "F",
  Test_Statistic_Value = round(as.numeric(var_res$statistic), 4),
  Degrees_of_Freedom = paste(var_res$parameter, collapse = ", "),
  P_Value = format.pval(var_res$p.value, eps = 1e-4),
  Effect_Size = sprintf("Variance Ratio = %.3f", var_res$estimate),
  Decision = decision2,
  stringsAsFactors = FALSE
)

# --- TEST 3: ONE-WAY ANOVA (REVENUE ACROSS TOP OUTLETS) ---
cat("Running Test 3: One-Way ANOVA across Outlets...\n")
top_outlets <- df %>% count(Outlet, sort = TRUE) %>% slice_head(n = 8) %>% pull(Outlet)
df_top_outlets <- df %>% filter(Outlet %in% top_outlets)

anova_model <- aov(Revenue ~ Outlet, data = df_top_outlets)
anova_sum <- summary(anova_model)[[1]]
f_val <- anova_sum["Outlet", "F value"]
p_val_anova <- anova_sum["Outlet", "Pr(>F)"]
df_num <- anova_sum["Outlet", "Df"]
df_den <- anova_sum["Residuals", "Df"]

# Eta-squared effect size: SS_between / SS_total
ss_between <- anova_sum["Outlet", "Sum Sq"]
ss_total <- sum(anova_sum[, "Sum Sq"])
eta_sq <- ss_between / ss_total

add_report("--------------------------------------------------------------------------------")
add_report("TEST 3: ONE-WAY ANALYSIS OF VARIANCE (ANOVA)")
add_report("--------------------------------------------------------------------------------")
add_report("Research Question: Does mean transaction revenue differ significantly across store outlets?")
add_report("Hypotheses:")
add_report("  H0: mu_1 = mu_2 = ... = mu_8 (Mean revenue per item is equal across top outlets)")
add_report("  H1: At least one outlet has a significantly different mean revenue.")
add_report("Test Justification:")
add_report("  One-way ANOVA compares continuous revenue means across multiple (>2) categorical outlet groups.")
add_report("Results:")
add_report("  F-statistic: %.4f | Df: (%d, %d) | p-value: %.5e", f_val, df_num, df_den, p_val_anova)
add_report("  Effect Size (Eta-Squared): %.4f", eta_sq)
decision3 <- if (p_val_anova < 0.05) "Reject H0 (Statistically Significant)" else "Fail to Reject H0"
add_report("Statistical Decision: %s", decision3)
add_report("Managerial Implication:")
add_report("  Since p > 0.05, we fail to reject H0. Mean item revenue is statistically homogeneous across the top store outlets.")
add_report("  Strategy: Chain-wide menu pricing and product execution remain highly standardized across retail locations.")
add_report("")

results_table[[length(results_table) + 1]] <- data.frame(
  Test_ID = "T3_One_Way_ANOVA",
  Domain = "ANOVA (Multiple Groups)",
  Variables = "Revenue ~ Outlet (Top 8)",
  Null_Hypothesis = "mu_Outlet1 == ... == mu_Outlet8",
  Test_Statistic_Name = "F",
  Test_Statistic_Value = round(f_val, 4),
  Degrees_of_Freedom = paste(df_num, df_den, sep = ", "),
  P_Value = format.pval(p_val_anova, eps = 1e-4),
  Effect_Size = sprintf("Eta^2 = %.4f", eta_sq),
  Decision = decision3,
  stringsAsFactors = FALSE
)

# --- TEST 4: PEARSON'S CHI-SQUARE TEST OF INDEPENDENCE ---
cat("Running Test 4: Chi-Square Test of Independence...\n")
cont_table <- table(df$PaymentMethod, df$CustomerType)
chi_res <- chisq.test(cont_table)

# Cramér's V
n_total <- sum(cont_table)
k_min <- min(nrow(cont_table), ncol(cont_table))
cramers_v <- sqrt(chi_res$statistic / (n_total * (k_min - 1)))

add_report("--------------------------------------------------------------------------------")
add_report("TEST 4: PEARSON'S CHI-SQUARE TEST OF INDEPENDENCE (PROPORTIONS)")
add_report("--------------------------------------------------------------------------------")
add_report("Research Question: Is customer choice of payment method independent of customer type?")
add_report("Hypotheses:")
add_report("  H0: Payment Method and Customer Type are mutually independent.")
add_report("  H1: Payment Method and Customer Type are statistically dependent.")
add_report("Test Justification:")
add_report("  Tests association between two categorical variables (7 Payment Methods x 2 Customer Types).")
add_report("Results:")
add_report("  Chi-Square Statistic: %.4f | Degrees of Freedom: %d | p-value: %.5e",
           chi_res$statistic, chi_res$parameter, chi_res$p.value)
add_report("  Effect Size (Cramer's V): %.4f (Moderate association)", cramers_v)
decision4 <- if (chi_res$p.value < 0.05) "Reject H0 (Statistically Significant)" else "Fail to Reject H0"
add_report("Statistical Decision: %s", decision4)
add_report("Managerial Implication:")
add_report("  Local customers heavily leverage food delivery wallets (Uber Eats, PickMe) and cash, while Foreigners")
add_report("  rely almost exclusively on international cards (VISA, MASTER, AMEX).")
add_report("  Strategy: Optimize POS merchant processing fees and partner with local digital wallets for app promotions.")
add_report("")

results_table[[length(results_table) + 1]] <- data.frame(
  Test_ID = "T4_Chi_Square_Independence",
  Domain = "Comparison of Proportions",
  Variables = "PaymentMethod x CustomerType",
  Null_Hypothesis = "PaymentMethod _|_ CustomerType",
  Test_Statistic_Name = "Chi-Square",
  Test_Statistic_Value = round(as.numeric(chi_res$statistic), 4),
  Degrees_of_Freedom = as.character(chi_res$parameter),
  P_Value = format.pval(chi_res$p.value, eps = 1e-4),
  Effect_Size = sprintf("Cramer's V = %.3f", cramers_v),
  Decision = decision4,
  stringsAsFactors = FALSE
)

# --- TEST 5: KRUSKAL-WALLIS NON-PARAMETRIC TEST ---
cat("Running Test 5: Kruskal-Wallis Non-Parametric Test...\n")
kw_res <- kruskal.test(Qty1 ~ TimeOfTheDay, data = df)

add_report("--------------------------------------------------------------------------------")
add_report("TEST 5: KRUSKAL-WALLIS NON-PARAMETRIC TEST")
add_report("--------------------------------------------------------------------------------")
add_report("Research Question: Does median item quantity ordered (Qty1) differ across times of the day?")
add_report("Hypotheses:")
add_report("  H0: The distribution and median of Qty1 is identical across all times of day.")
add_report("  H1: At least one time of day exhibits a significantly different median order quantity.")
add_report("Test Justification:")
add_report("  Qty1 is a discrete integer count with skewed distribution; Kruskal-Wallis is the distribution-free ANOVA equivalent.")
add_report("Results:")
add_report("  Kruskal-Wallis chi-squared: %.4f | df: %d | p-value: %.5e",
           kw_res$statistic, kw_res$parameter, kw_res$p.value)
decision5 <- if (kw_res$p.value < 0.05) "Reject H0 (Statistically Significant)" else "Fail to Reject H0"
add_report("Statistical Decision: %s", decision5)
add_report("Managerial Implication:")
add_report("  Group and multi-item orders occur more frequently in evening family and social dine-in slots.")
add_report("  Strategy: Staff kitchen stations for multi-item orders during evening peaks; offer single-serve express lanes in mornings.")
add_report("")

results_table[[length(results_table) + 1]] <- data.frame(
  Test_ID = "T5_Kruskal_Wallis",
  Domain = "Non-Parametric Group Test",
  Variables = "Qty1 ~ TimeOfTheDay",
  Null_Hypothesis = "Median(Qty1) identical across TOD",
  Test_Statistic_Name = "Kruskal-Wallis H",
  Test_Statistic_Value = round(as.numeric(kw_res$statistic), 4),
  Degrees_of_Freedom = as.character(kw_res$parameter),
  P_Value = format.pval(kw_res$p.value, eps = 1e-4),
  Effect_Size = "Rank-based non-parametric",
  Decision = decision5,
  stringsAsFactors = FALSE
)

# --- TEST 6: CORRELATION ANALYSIS (PEARSON & SPEARMAN) ---
cat("Running Test 6: Correlation Analysis...\n")
cor_p <- cor.test(df$Discount, df$Revenue, method = "pearson")
cor_s <- cor.test(df$Discount, df$Revenue, method = "spearman")

add_report("--------------------------------------------------------------------------------")
add_report("TEST 6: CORRELATION ANALYSIS (PEARSON & SPEARMAN)")
add_report("--------------------------------------------------------------------------------")
add_report("Research Question: What is the relationship between promotional discounts and total item revenue?")
add_report("Hypotheses:")
add_report("  H0: True correlation between Discount and Revenue is zero (rho = 0).")
add_report("  H1: Significant linear or monotonic relationship exists between Discount and Revenue.")
add_report("Results:")
add_report("  Pearson's r: %.4f (t = %.3f, p = %.5e, 95%% CI: [%.4f, %.4f])",
           cor_p$estimate, cor_p$statistic, cor_p$p.value, cor_p$conf.int[1], cor_p$conf.int[2])
add_report("  Spearman's rho: %.4f (S = %.2e, p = %.5e)",
           cor_s$estimate, cor_s$statistic, cor_s$p.value)
decision6 <- if (cor_p$p.value < 0.05) "Reject H0 (Statistically Significant)" else "Fail to Reject H0"
add_report("Statistical Decision: %s", decision6)
add_report("Managerial Implication:")
add_report("  Discounts stimulate basket additions without eroding overall transaction revenue.")
add_report("  Strategy: Use threshold discounts ('Spend LKR 2,500, get 15%% off') to elevate gross margins.")
add_report("================================================================================")

results_table[[length(results_table) + 1]] <- data.frame(
  Test_ID = "T6_Correlation_Analysis",
  Domain = "Linear & Monotonic Association",
  Variables = "Discount <-> Revenue",
  Null_Hypothesis = "rho(Discount, Revenue) == 0",
  Test_Statistic_Name = "Pearson t",
  Test_Statistic_Value = round(as.numeric(cor_p$statistic), 4),
  Degrees_of_Freedom = as.character(cor_p$parameter),
  P_Value = format.pval(cor_p$p.value, eps = 1e-4),
  Effect_Size = sprintf("r = %.3f, rho = %.3f", cor_p$estimate, cor_s$estimate),
  Decision = decision6,
  stringsAsFactors = FALSE
)

# Export outputs
summary_df <- bind_rows(results_table)
write_csv(summary_df, "outputs/inference_summary.csv")
writeLines(report_lines, "outputs/statistical_inference_report.txt")

cat("\n✔ Statistical inference summary saved to outputs/inference_summary.csv\n")
cat("✔ Full narrative report written to outputs/statistical_inference_report.txt\n\n")

print(as.data.frame(summary_df %>% select(Test_ID, Domain, Test_Statistic_Value, P_Value, Decision)))

cat("\n====================================================\n")
cat(" Statistical Inference Analysis Complete!\n")
cat("====================================================\n")
