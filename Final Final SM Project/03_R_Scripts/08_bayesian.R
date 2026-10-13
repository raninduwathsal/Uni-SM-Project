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
cat("✔ Saved Bayesian tables to outputs/bayesian_priors.csv and bayesian_conditional_likelihoods.csv\n\n")

# --- 2. WRITTEN CRITICAL EVALUATION REPORT (TASK 8 REQUIREMENTS) ---
report_lines <- c(
  "================================================================================",
  " IT3081 STATISTICAL MODELLING - TASK 8: CRITICAL EVALUATION OF BAYESIAN METHODS",
  " Client: BladeGen Tech Consultancy | Probabilistic Analytics Evaluation",
  "================================================================================",
  "",
  "1. EXECUTIVE OVERVIEW:",
  "Bayesian statistical paradigms formulate inference through Bayes' Theorem: P(Theta | Data) propto P(Data | Theta) * P(Theta).",
  "This section critically evaluates the suitability of Naïve Bayes classifiers, Bayesian generalized linear",
  "regression, and Bayesian decision theory for retail and restaurant analytics.",
  "",
  "2. EMPIRICAL BAYESIAN CLASSIFICATION FINDINGS:",
  sprintf("  - Base Prior Probabilities: Beverage = %.2f%%, Food = %.2f%%, Deals = %.2f%%, Merchandizing = %.2f%%.",
          priors_df$Prior_Probability[1]*100, priors_df$Prior_Probability[2]*100,
          priors_df$Prior_Probability[3]*100, priors_df$Prior_Probability[4]*100),
  sprintf("  - Overall Predictive Accuracy on Test Set: %.2f%% (Cohen's Kappa = %.4f).", acc_nb, cm_nb$overall["Kappa"]),
  "  - Laplace Smoothing (alpha = 1) prevents zero-frequency conditional likelihood collapse for sparse category-outlet pairs.",
  "",
  "3. EVALUATION OF CORE BAYESIAN METHODS:",
  "  A. Naïve Bayes Classification:",
  "     - Mechanism: Assumes conditional independence between predictors given the class label.",
  "     - Viability: Computationally trivial (O(n * p)), supports incremental real-time updating at the POS terminal as new",
  "       transactions stream in.",
  "     - Limitation: Feature independence assumption is violated between Qty1 and Revenue (they are naturally correlated),",
  "       leading to overconfident posterior probability estimates.",
  "",
  "  B. Bayesian Generalized Linear Regression (MCMC):",
  "     - Mechanism: Estimates full posterior parameter distributions beta ~ Normal(mu, sigma) rather than fixed point estimates.",
  "     - Advantage: Quantifies epistemic parameter uncertainty, providing credible intervals for promotion price elasticity.",
  "     - Limitation: High computational overhead; Markov Chain Monte Carlo (MCMC / Gibbs sampling) requires significant CPU time.",
  "",
  "  C. Bayesian Decision Making (Loss-Function Optimization):",
  "     - Mechanism: Integrates posterior probabilities with an asymmetric business utility / loss matrix L(actual, predicted).",
  "     - High Value Application: In restaurant operations, misclassifying a Food item as a Beverage causes kitchen stockout",
  "       (costly: customer churn), whereas over-preparing coffee beans is relatively cheap. Bayesian loss minimization",
  "       adjusts classification decision thresholds to minimize expected monetary cost rather than raw misclassification error.",
  "",
  "4. COMPARISON: BAYESIAN VS. FREQUENTIST APPROACHES:",
  "  - Strengths of Bayesian Methods:",
  "    1. Prior Knowledge Integration: Historical sales distributions from past quarters can be formalized as informative priors.",
  "    2. Small Sample Robustness: In newly opened store outlets with sparse data, Bayesian priors prevent extreme parameter estimates.",
  "    3. Intuitive Probabilistic Interpretation: 'There is a 95% probability that revenue will exceed LKR 1,000' is mathematically",
  "       sound in Bayesian inference, unlike frequentist confidence intervals.",
  "  - Situations Where Bayesian Approaches Outperform Traditional Methods:",
  "    1. Cold-start problem for newly launched menu items or newly opened outlets.",
  "    2. Asymmetric financial cost scenarios where false positives and false negatives carry vastly different financial penalties.",
  "================================================================================"
)

writeLines(report_lines, "outputs/bayesian_methods_report.txt")
cat("✔ Comprehensive Bayesian evaluation report written to outputs/bayesian_methods_report.txt\n")

cat("\n====================================================\n")
cat(" Task 8 Bayesian Evaluation Complete!\n")
cat("====================================================\n")
