# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 5: Predictive Statistical Modelling (4 Member Models)
# Script: 05_modelling.R
# Outputs: Model comparison metrics & confusion matrix plot
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(caret)
  library(nnet)
  library(rpart)
  library(randomForest)
  library(e1071)
})

set.seed(42)

cat("====================================================\n")
cat(" Task 5: Predictive Statistical Modelling\n")
cat(" Comparing 4 Member Models for Product Prediction\n")
cat("====================================================\n\n")

# --- 1. LOAD DATA & PREPARE MODELLING DATASET ---
data_path <- "outputs/df_clean.csv"
if (!file.exists(data_path)) {
  data_path <- "R Scripts/outputs/df_clean.csv"
}

df <- read_csv(data_path, show_col_types = FALSE)

# Prepare modelling features
model_df <- df %>%
  select(
    MainCategory,
    TimeOfTheDay,
    Day,
    CustomerType,
    OrderType,
    PaymentMethod,
    IsLoyaltyMember,
    Qty1,
    AdjustedRate
  ) %>%
  mutate(
    MainCategory = factor(MainCategory),
    TimeOfTheDay = factor(TimeOfTheDay),
    Day = factor(Day),
    CustomerType = factor(CustomerType),
    OrderType = factor(OrderType),
    PaymentMethod = factor(PaymentMethod),
    IsLoyaltyMember = factor(IsLoyaltyMember)
  ) %>%
  drop_na()

cat(sprintf("Prepared modelling dataset: %d observations\n", nrow(model_df)))
cat("Target classes distribution:\n")
print(table(model_df$MainCategory))
cat("\n")

# --- 2. STRATIFIED TRAIN / TEST SPLIT (80% / 20%) ---
train_idx <- createDataPartition(model_df$MainCategory, p = 0.80, list = FALSE)
train_set <- model_df[train_idx, ]
test_set  <- model_df[-train_idx, ]

cat(sprintf("Training Set: %d rows (80%%) | Test Set: %d rows (20%%)\n\n", nrow(train_set), nrow(test_set)))

formula_model <- MainCategory ~ TimeOfTheDay + Day + CustomerType + OrderType + PaymentMethod + IsLoyaltyMember + Qty1 + AdjustedRate

# Metrics helper function
evaluate_predictions <- function(y_true, y_pred, model_name, member_name) {
  cm <- confusionMatrix(y_pred, y_true)
  acc <- as.numeric(cm$overall["Accuracy"])
  kappa <- as.numeric(cm$overall["Kappa"])
  
  # Macro-averaged metrics
  by_class <- as.data.frame(cm$byClass)
  precision <- mean(by_class[, "Precision"], na.rm = TRUE)
  recall <- mean(by_class[, "Recall"], na.rm = TRUE)
  f1 <- mean(by_class[, "F1"], na.rm = TRUE)
  
  data.frame(
    Member = member_name,
    Model = model_name,
    Accuracy = round(acc * 100, 2),
    Macro_Precision = round(precision * 100, 2),
    Macro_Recall = round(recall * 100, 2),
    Macro_F1 = round(f1 * 100, 2),
    Kappa = round(kappa, 4),
    stringsAsFactors = FALSE
  )
}

# --- MEMBER 1: MULTINOMIAL LOGISTIC REGRESSION (GLM) ---
cat("--- Training Member 1 Model: Multinomial Logistic Regression (nnet) ---\n")
t0 <- Sys.time()
m1_multinom <- multinom(formula_model, data = train_set, trace = FALSE, MaxNWts = 2000)
pred_m1 <- predict(m1_multinom, newdata = test_set)
time_m1 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
eval_m1 <- evaluate_predictions(test_set$MainCategory, pred_m1, "Multinomial Logistic Regression", "Member 1")
eval_m1$Training_Time_Sec <- time_m1
cat(sprintf("✔ Member 1 Model complete (Time: %.2fs) | Accuracy: %.2f%%\n\n", time_m1, eval_m1$Accuracy))

# --- MEMBER 2: DECISION TREE (CART / rpart) ---
cat("--- Training Member 2 Model: Decision Tree (rpart) ---\n")
t0 <- Sys.time()
m2_tree <- rpart(formula_model, data = train_set, method = "class", cp = 0.002)
pred_m2 <- predict(m2_tree, newdata = test_set, type = "class")
time_m2 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
eval_m2 <- evaluate_predictions(test_set$MainCategory, pred_m2, "Decision Tree (CART)", "Member 2")
eval_m2$Training_Time_Sec <- time_m2
cat(sprintf("✔ Member 2 Model complete (Time: %.2fs) | Accuracy: %.2f%%\n\n", time_m2, eval_m2$Accuracy))

# --- MEMBER 3: RANDOM FOREST (randomForest) ---
cat("--- Training Member 3 Model: Random Forest (100 Trees) ---\n")
t0 <- Sys.time()
# Downsample train set slightly if needed for ultra-fast execution
rf_train <- if (nrow(train_set) > 15000) train_set[sample(1:nrow(train_set), 15000), ] else train_set
m3_rf <- randomForest(formula_model, data = rf_train, ntree = 100, mtry = 3, importance = TRUE)
pred_m3 <- predict(m3_rf, newdata = test_set)
time_m3 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
eval_m3 <- evaluate_predictions(test_set$MainCategory, pred_m3, "Random Forest (Ensemble)", "Member 3")
eval_m3$Training_Time_Sec <- time_m3
cat(sprintf("✔ Member 3 Model complete (Time: %.2fs) | Accuracy: %.2f%%\n\n", time_m3, eval_m3$Accuracy))

# --- MEMBER 4: NAÏVE BAYES CLASSIFIER (e1071) ---
cat("--- Training Member 4 Model: Naïve Bayes Classifier (e1071) ---\n")
t0 <- Sys.time()
m4_nb <- naiveBayes(formula_model, data = train_set, laplace = 1)
pred_m4 <- predict(m4_nb, newdata = test_set)
time_m4 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
eval_m4 <- evaluate_predictions(test_set$MainCategory, pred_m4, "Naïve Bayes Classifier", "Member 4")
eval_m4$Training_Time_Sec <- time_m4
cat(sprintf("✔ Member 4 Model complete (Time: %.2fs) | Accuracy: %.2f%%\n\n", time_m4, eval_m4$Accuracy))

# --- 3. MODEL COMPARISON & CHAMPION SELECTION ---
model_comparison <- bind_rows(eval_m1, eval_m2, eval_m3, eval_m4) %>%
  arrange(desc(Accuracy))

cat("================================================================================\n")
cat(" 4-MEMBER MODEL EVALUATION LEADERBOARD\n")
cat("================================================================================\n")
print(as.data.frame(model_comparison))
cat("\n")

champion_model_name <- model_comparison$Model[1]
champion_member <- model_comparison$Member[1]
champion_acc <- model_comparison$Accuracy[1]

cat(sprintf("🏆 Champion Model Selected: %s (%s) with %.2f%% Accuracy\n\n",
            champion_model_name, champion_member, champion_acc))

write_csv(model_comparison, "outputs/model_evaluation_metrics.csv")
cat("✔ Model metrics saved to outputs/model_evaluation_metrics.csv\n")

# --- 4. VISUALIZATIONS: COMPARISON BARPLOT & CONFUSION MATRIX ---
fig_dir <- "outputs/figures"
if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE)

theme_pub <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 13, color = "#1a202c"),
      plot.subtitle = element_text(size = 10.5, color = "#4a5568"),
      axis.title = element_text(face = "bold", size = 10),
      panel.grid.minor = element_blank(),
      plot.background = element_rect(fill = "#ffffff", color = NA)
    )
}

# Plot 1: Model Comparison Barplot
p_comp <- ggplot(model_comparison, aes(x = reorder(Model, Accuracy), y = Accuracy, fill = Member)) +
  geom_col(width = 0.6, alpha = 0.9) +
  geom_text(aes(label = sprintf("%.2f%% (F1: %.1f%%)", Accuracy, Macro_F1)),
            hjust = -0.1, size = 3.6, fontface = "bold") +
  coord_flip() +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
  scale_fill_brewer(palette = "Set1") +
  labs(
    title = "Comparison of 4 Group Member Machine Learning Models",
    subtitle = "Evaluating accuracy and macro-F1 across 4 distinct statistical architectures",
    x = "Model Architecture",
    y = "Overall Test Accuracy (%)",
    fill = "Assigned Group Member",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 5 Predictive Modelling"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "fig_model_comparison.png"), p_comp, width = 9.5, height = 5.5, dpi = 300)

# Plot 2: Best Model Confusion Matrix Heatmap
best_preds <- switch(
  champion_model_name,
  "Multinomial Logistic Regression" = pred_m1,
  "Decision Tree (CART)" = pred_m2,
  "Random Forest (Ensemble)" = pred_m3,
  "Naïve Bayes Classifier" = pred_m4
)

cm_best <- confusionMatrix(best_preds, test_set$MainCategory)
cm_df <- as.data.frame(cm_best$table)

p_cm <- ggplot(cm_df, aes(x = Reference, y = Prediction, fill = Freq)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = scales::comma(Freq)), fontface = "bold", size = 4.2) +
  scale_fill_gradient(low = "#edf2f7", high = "#3182ce") +
  labs(
    title = sprintf("Confusion Matrix: %s (%s)", champion_model_name, champion_member),
    subtitle = sprintf("Overall Accuracy: %.2f%% | Kappa: %.4f on Unseen Test Partition", champion_acc, cm_best$overall["Kappa"]),
    x = "Actual Ground Truth Category",
    y = "Predicted Category",
    fill = "Transactions",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 5 Predictive Modelling"
  ) +
  theme_pub()

ggsave(file.path(fig_dir, "fig_confusion_matrix.png"), p_cm, width = 8, height = 6, dpi = 300)

cat("✔ Figures saved: outputs/figures/fig_model_comparison.png and fig_confusion_matrix.png\n\n")

# Save detailed model summary report
mod_report <- c(
  "================================================================================",
  " IT3081 STATISTICAL MODELLING - TASK 5: PREDICTIVE MODELLING REPORT",
  " Multi-Model Evaluation & Group Member Assignment",
  "================================================================================",
  "",
  "1. EXECUTIVE OVERVIEW:",
  "Four distinct statistical and machine learning algorithms were trained to predict customer",
  "purchasing category (MainCategory: Beverage, Food, Merchandizing, Deals).",
  "Each algorithm was assigned to one group member to evaluate architectural trade-offs.",
  "",
  "2. GROUP MEMBER ASSIGNMENTS & ARCHITECTURES:",
  "  - Member 1: Multinomial Logistic Regression (Generalized Linear Model / Log-odds)",
  "  - Member 2: Decision Tree / CART (Interpretable Hierarchical Decision Splits)",
  "  - Member 3: Random Forest (Bagging Ensemble of 100 De-correlated Decision Trees)",
  "  - Member 4: Naïve Bayes Classifier (Probabilistic Bayesian Prior-Likelihood Estimator)",
  "",
  "3. EVALUATION RESULTS SUMMARY:",
  capture.output(print(as.data.frame(model_comparison))),
  "",
  sprintf("4. CHAMPION MODEL SELECTION:"),
  sprintf("  The highest performing model is '%s' (%s) with an accuracy of %.2f%% and Macro-F1 of %.2f%%.",
          champion_model_name, champion_member, champion_acc, model_comparison$Macro_F1[1]),
  "  Decision rationale: Provides superior discrimination on multi-class boundary with robust generalization.",
  "================================================================================"
)

writeLines(mod_report, "outputs/predictive_modelling_report.txt")
cat("✔ Detailed report saved to outputs/predictive_modelling_report.txt\n")

cat("\n====================================================\n")
cat(" Task 5 Predictive Modelling Complete!\n")
cat("====================================================\n")
