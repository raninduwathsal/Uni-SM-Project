# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 8: Critical Evaluation of Bayesian Statistical Methods
# Script: 08_bayesian.R
# Outputs: Prior vs posterior distributions & critical evaluation
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(e1071)
  library(caret)
})

cat("====================================================\n")
cat(" Task 8: Bayesian Statistical Methods Evaluation\n")
cat("====================================================\n\n")

# --- 1. LOAD DATA & TRAIN NAÏVE BAYES ---
data_path <- "outputs/df_clean.csv"
if (!file.exists(data_path)) {
  data_path <- "R Scripts/outputs/df_clean.csv"
}

df <- read_csv(data_path, show_col_types = FALSE)

model_df <- df %>%
  select(MainCategory, TimeOfTheDay, Day, CustomerType, OrderType, PaymentMethod, IsLoyaltyMember, Qty1, AdjustedRate) %>%
  mutate(across(where(is.character), as.factor), MainCategory = as.factor(MainCategory)) %>%
  drop_na()

set.seed(42)
train_idx <- createDataPartition(model_df$MainCategory, p = 0.80, list = FALSE)
train_set <- model_df[train_idx, ]
test_set  <- model_df[-train_idx, ]

# Fit Naïve Bayes
nb_fit <- naiveBayes(MainCategory ~ ., data = train_set, laplace = 1)

# Prior Probabilities P(Y)
priors <- nb_fit$apriori / sum(nb_fit$apriori)
priors_df <- data.frame(
  MainCategory = names(priors),
  Class_Count = as.numeric(nb_fit$apriori),
  Prior_Probability = round(as.numeric(priors), 4),
  stringsAsFactors = FALSE
)

cat("--- 1. Empirical Prior Probabilities P(Y) ---\n")
print(priors_df)
cat("\n")

# Extract conditional tables for TimeOfTheDay: P(TimeOfTheDay | MainCategory)
cond_tod <- as.data.frame(round(nb_fit$tables$TimeOfTheDay, 4))
cat("--- 2. Conditional Likelihoods P(TimeOfTheDay | MainCategory) ---\n")
print(cond_tod)
cat("\n")

# Predict on test set
nb_preds <- predict(nb_fit, newdata = test_set)
nb_probs <- predict(nb_fit, newdata = test_set, type = "raw")
cm_nb <- confusionMatrix(nb_preds, test_set$MainCategory)

acc_nb <- round(as.numeric(cm_nb$overall["Accuracy"]) * 100, 2)
cat(sprintf("Naïve Bayes Test Accuracy: %.2f%% | Kappa: %.4f\n\n", acc_nb, cm_nb$overall["Kappa"]))

# Save Prior & Likelihood Tables
write_csv(priors_df, "outputs/bayesian_priors.csv")
write.csv(cond_tod, "outputs/bayesian_conditional_likelihoods.csv")
cat("✔ Saved Bayesian classification tables to outputs/bayesian_priors.csv and bayesian_conditional_likelihoods.csv\n\n")

# --- 2. BAYESIAN LINEAR REGRESSION (SPEND MODELLING & CREDIBLE INTERVALS) ---
cat("--- 3. Estimating Bayesian Linear Regression for Customer Spend ---\n")
# Contextual spend predictors: Qty1, CustomerType, OrderType, TimeOfTheDay, IsLoyaltyMember
X_df <- model_df %>%
  select(Qty1, CustomerType, OrderType, TimeOfTheDay, IsLoyaltyMember)
X_mat <- model.matrix(~ Qty1 + CustomerType + OrderType + TimeOfTheDay + IsLoyaltyMember, data = X_df)
y_vec <- df$Revenue[1:nrow(X_mat)]

# Normal-Inverse-Gamma Conjugate Prior setup
p_dim <- ncol(X_mat)
n_obs <- length(y_vec)
XtX <- t(X_mat) %*% X_mat
Xty <- t(X_mat) %*% y_vec

mu0 <- rep(0, p_dim)
Lambda0 <- diag(1e-3, p_dim)
a0 <- 2.0
b0 <- 100.0

Lambda_n <- XtX + Lambda0
mu_n <- solve(Lambda_n, Xty + Lambda0 %*% mu0)
an <- a0 + n_obs / 2.0
bn <- b0 + 0.5 * (as.numeric(t(y_vec) %*% y_vec) + as.numeric(t(mu0) %*% Lambda0 %*% mu0) - as.numeric(t(mu_n) %*% Lambda_n %*% mu_n))

sigma2_posterior_mean <- bn / (an - 1)
cov_beta <- sigma2_posterior_mean * solve(Lambda_n)
beta_se <- sqrt(diag(cov_beta))

# 95% Bayesian Credible Intervals (Student-t with 2*an df)
t_crit <- qt(0.975, df = 2 * an)
ci_lower <- mu_n - t_crit * beta_se
ci_upper <- mu_n + t_crit * beta_se

bayes_reg_df <- data.frame(
  Predictor = colnames(X_mat),
  Posterior_Mean = round(as.numeric(mu_n), 2),
  Posterior_SD = round(as.numeric(beta_se), 2),
  Credible_Lower_95pct = round(as.numeric(ci_lower), 2),
  Credible_Upper_95pct = round(as.numeric(ci_upper), 2),
  stringsAsFactors = FALSE
)

cat("Posterior Estimates & 95% Credible Intervals for Spend Regression:\n")
print(bayes_reg_df)
write_csv(bayes_reg_df, "outputs/bayesian_regression_parameters.csv")
cat("✔ Saved Bayesian regression parameters to outputs/bayesian_regression_parameters.csv\n\n")

# --- 3. WRITTEN CRITICAL EVALUATION REPORT (TASK 8 REQUIREMENTS) ---
report_lines <- c(
  "================================================================================",
  " IT3081 STATISTICAL MODELLING - TASK 8: CRITICAL EVALUATION OF BAYESIAN METHODS",
  " Client: BladeGen Tech Consultancy | Probabilistic Analytics & Regression",
  "================================================================================",
  "",
  "1. EXECUTIVE OVERVIEW:",
  "Bayesian statistical paradigms formulate inference through Bayes' Theorem: P(Theta | Data) propto P(Data | Theta) * P(Theta).",
  "This investigation evaluates both Bayesian Classification (Naïve Bayes) and Bayesian Linear Regression for spend prediction,",
  "contrasting their probabilistic properties against classical frequentist estimators.",
  "",
  "2. EMPIRICAL BAYESIAN CLASSIFICATION FINDINGS:",
  sprintf("  - Base Prior Probabilities: Beverage = %.2f%%, Food = %.2f%%, Deals = %.2f%%, Merchandizing = %.2f%%.",
          priors_df$Prior_Probability[1]*100, priors_df$Prior_Probability[2]*100,
          priors_df$Prior_Probability[3]*100, priors_df$Prior_Probability[4]*100),
  sprintf("  - Overall Predictive Accuracy on Test Set: %.2f%% (Cohen's Kappa = %.4f).", acc_nb, cm_nb$overall["Kappa"]),
  "  - Laplace Smoothing (alpha = 1) prevents zero-frequency conditional collapse for sparse category-outlet pairs.",
  "",
  "3. EMPIRICAL BAYESIAN LINEAR REGRESSION FINDINGS (CUSTOMER SPEND):",
  "  - Parameter Estimation: Formulated via Normal-Inverse-Gamma conjugate prior to predict transaction spend.",
  sprintf("  - Posterior Mean for Item Quantity (Qty1): LKR %.2f per unit (95%% Credible Interval: [%.2f, %.2f]).",
          bayes_reg_df$Posterior_Mean[2], bayes_reg_df$Credible_Lower_95pct[2], bayes_reg_df$Credible_Upper_95pct[2]),
  sprintf("  - Posterior Mean for Takeaway Orders: LKR %.2f relative to Dine-In (95%% Credible Interval: [%.2f, %.2f]).",
          bayes_reg_df$Posterior_Mean[4], bayes_reg_df$Credible_Lower_95pct[4], bayes_reg_df$Credible_Upper_95pct[4]),
  "  - Credible Intervals vs. Confidence Intervals: Unlike frequentist 95% confidence intervals (which state that 95% of hypothetical",
  "    resampled intervals contain the fixed parameter), Bayesian credible intervals provide a direct posterior probability:",
  "    'There is a 95% probability that the true parameter lies within the calculated interval given the observed transaction data.'",
  "",
  "4. CRITICAL COMPARISON: ADVANTAGES AND LIMITATIONS OF BAYESIAN REGRESSION:",
  "  A. Advantages in Retail & Demand Modelling:",
  "     - Epistemic Uncertainty Quantification: Produces full probability distributions for elasticity parameters rather than single-point OLS estimates.",
  "     - Small-Sample Regularization: In newly opened store locations or low-volume specialty items, informative priors prevent extreme parameter drift.",
  "     - Seamless Sequential Learning: The posterior distribution from Q1 seamlessly serves as the prior distribution for Q2 transactions.",
  "  B. Practical Limitations:",
  "     - Computational Complexity: While conjugate priors admit closed-form solutions, non-conjugate hierarchical models require MCMC / Gibbs sampling,",
  "       introducing significant latency that cannot execute in real-time on edge POS cash registers.",
  "     - Prior Sensitivity: Subjective or poorly specified priors can bias revenue projections if sample sizes are modest.",
  "================================================================================"
)
)

writeLines(report_lines, "outputs/bayesian_methods_report.txt")
cat("✔ Comprehensive Bayesian evaluation report written to outputs/bayesian_methods_report.txt\n")

cat("\n====================================================\n")
cat(" Task 8 Bayesian Evaluation Complete!\n")
cat("====================================================\n")
