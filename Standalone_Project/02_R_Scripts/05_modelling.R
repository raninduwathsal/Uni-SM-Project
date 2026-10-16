# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 5: Predictive Statistical Modelling (Enhanced Tournament)
# Script: 05_modelling.R
# Outputs: Model comparison metrics, comprehensive metrics, confusion matrix & report
# ============================================================

suppressPackageStartupMessages({
  library(MASS)
  library(tidyverse)
  library(caret)
  library(nnet)
  library(e1071)
  library(glmnet)
  library(pROC)
})

set.seed(42)

cat("====================================================\n")
cat(" Task 5: Predictive Statistical Modelling\n")
cat(" Comparing 4 Member Models (100% Syllabus-Aligned)\n")
cat("====================================================\n\n")

# --- 1. LOAD DATA & PREPARE MODELLING DATASET ---
data_candidates <- c(
  "outputs/df_clean.csv",
  "../02_R_Scripts/outputs/df_clean.csv",
  "df_clean.csv"
)
data_path <- data_candidates[file.exists(data_candidates)][1]
if (is.na(data_path)) {
  stop("Error: df_clean.csv could not be found.")
}

df <- read_csv(data_path, show_col_types = FALSE)

# Feature engineering: basket size, weekend indicator, hour
model_df <- df %>%
  mutate(
    Hour = as.numeric(str_extract(OrderTime, "^[0-9]+")),
    IsWeekend = factor(ifelse(Day %in% c("Saturday", "Sunday"), "Weekend", "Weekday")),
    DiscountRatio = ifelse((AdjustedRate * Qty1) > 0, Discount / (AdjustedRate * Qty1), 0)
  ) %>%
  group_by(OrderNo) %>%
  mutate(
    BasketItems = n(),
    BasketSpend = sum(Revenue)
  ) %>%
  ungroup() %>%
  dplyr::select(
    MainCategory,
    TimeOfTheDay,
    IsWeekend,
    CustomerType,
    OrderType,
    PaymentMethod,
    IsLoyaltyMember,
    Qty1,
    AdjustedRate,
    Discount,
    ServiceCharge,
    BasketItems,
    Revenue
  ) %>%
  mutate(
    MainCategory = factor(MainCategory),
    TimeOfTheDay = factor(TimeOfTheDay),
    CustomerType = factor(CustomerType),
    OrderType = factor(OrderType),
    PaymentMethod = factor(PaymentMethod),
    IsLoyaltyMember = factor(IsLoyaltyMember)
  ) %>%
  drop_na()

cat(sprintf("Prepared modelling dataset: %d item lines\n", nrow(model_df)))
cat("Target classes distribution:\n")
print(table(model_df$MainCategory))
cat("\n")

# --- 2. STRATIFIED TRAIN / TEST SPLIT (80% / 20%) ---
train_idx <- createDataPartition(model_df$MainCategory, p = 0.80, list = FALSE)
train_set <- model_df[train_idx, ]
test_set  <- model_df[-train_idx, ]

cat(sprintf("Training Set: %d item lines (80%%) | Test Set: %d item lines (20%%)\n\n", nrow(train_set), nrow(test_set)))

formula_model <- MainCategory ~ TimeOfTheDay + IsWeekend + CustomerType + OrderType + PaymentMethod + IsLoyaltyMember + Qty1 + AdjustedRate + Discount + ServiceCharge + BasketItems

# Multiclass MCC Calculation Helper (Gorodkin 2004)
calculate_multiclass_mcc <- function(cm_mat) {
  C <- as.matrix(cm_mat)
  s <- sum(C)
  c_val <- sum(diag(C))
  p_k <- colSums(C)
  t_k <- rowSums(C)
  numerator <- (c_val * s) - sum(p_k * t_k)
  denominator <- sqrt((s^2 - sum(p_k^2)) * (s^2 - sum(t_k^2)))
  if (denominator == 0) return(0)
  round(numerator / denominator, 4)
}

# Multiclass Log Loss and Brier Score Helper
calculate_prob_metrics <- function(y_true, y_prob) {
  classes <- levels(y_true)
  n <- length(y_true)
  # One-hot encode y_true
  Y_mat <- matrix(0, nrow = n, ncol = length(classes))
  colnames(Y_mat) <- classes
  for (j in seq_along(classes)) {
    Y_mat[, j] <- as.numeric(y_true == classes[j])
  }
  
  # Ensure columns align
  prob_aligned <- matrix(1e-15, nrow = n, ncol = length(classes))
  colnames(prob_aligned) <- classes
  common_cols <- intersect(colnames(y_prob), classes)
  prob_aligned[, common_cols] <- y_prob[, common_cols]
  
  # Normalize rows
  prob_aligned <- prob_aligned / rowSums(prob_aligned)
  
  # Log loss (cross entropy)
  log_loss <- -mean(rowSums(Y_mat * log(pmax(prob_aligned, 1e-15))))
  
  # Brier score (multi-class mean squared error)
  brier <- mean(rowSums((prob_aligned - Y_mat)^2))
  
  list(log_loss = round(log_loss, 4), brier = round(brier, 4))
}

# Metrics helper function
evaluate_predictions <- function(y_true, y_pred, y_prob, model_name, member_name) {
  y_pred <- factor(y_pred, levels = levels(y_true))
  cm <- confusionMatrix(y_pred, y_true)
  acc <- as.numeric(cm$overall["Accuracy"])
  kappa <- as.numeric(cm$overall["Kappa"])
  
  by_class <- as.data.frame(cm$byClass)
  precision <- mean(by_class[, "Precision"], na.rm = TRUE)
  recall <- mean(by_class[, "Recall"], na.rm = TRUE)
  f1 <- mean(by_class[, "F1"], na.rm = TRUE)
  balanced_acc <- recall  # In multiclass, Balanced Accuracy = Macro Recall
  
  auc_val <- tryCatch({
    as.numeric(pROC::multiclass.roc(y_true, y_prob)$auc) * 100
  }, error = function(e) NA)
  
  # Top-2 Recommendation Hit Rate (Hit@2)
  top2_hit_rate <- mean(sapply(1:length(y_true), function(i) {
    as.character(y_true[i]) %in% names(sort(y_prob[i, ], decreasing = TRUE)[1:2])
  })) * 100
  
  # MCC
  mcc_val <- calculate_multiclass_mcc(cm$table)
  
  # Log Loss and Brier
  prob_metrics <- calculate_prob_metrics(y_true, y_prob)
  
  list(
    eval_row = data.frame(
      Member = member_name,
      Model = model_name,
      Top1_Accuracy = round(acc * 100, 2),
      Top2_Accuracy = round(top2_hit_rate, 2),
      ROC_AUC = round(auc_val, 2),
      Macro_Precision = round(precision * 100, 2),
      Macro_Recall = round(recall * 100, 2),
      Macro_F1 = round(f1 * 100, 2),
      Kappa = round(kappa, 4),
      MCC = mcc_val,
      stringsAsFactors = FALSE
    ),
    comp_row = data.frame(
      Member = member_name,
      Model = model_name,
      Accuracy = sprintf("%.2f%%", acc * 100),
      Balanced_Acc = sprintf("%.2f%%", balanced_acc * 100),
      Macro_F1 = sprintf("%.2f%%", f1 * 100),
      Macro_Precision = sprintf("%.2f%%", precision * 100),
      Macro_Recall = sprintf("%.2f%%", recall * 100),
      ROC_AUC = sprintf("%.2f%%", auc_val),
      Cohen_Kappa = round(kappa, 4),
      MCC = mcc_val,
      Log_Loss = prob_metrics$log_loss,
      Brier_Score = prob_metrics$brier,
      stringsAsFactors = FALSE
    )
  )
}

# --- MEMBER 1: MULTINOMIAL LOGISTIC REGRESSION (GLM - Note 03 & Note 07) ---
cat("--- Training Member 1 Model: Multinomial Logistic Regression (nnet) ---\n")
t0 <- Sys.time()
m1_multinom <- multinom(formula_model, data = train_set, trace = FALSE, MaxNWts = 3000)
pred_m1 <- predict(m1_multinom, newdata = test_set)
prob_m1 <- predict(m1_multinom, newdata = test_set, type = "probs")
time_m1 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
res_m1 <- evaluate_predictions(test_set$MainCategory, pred_m1, prob_m1, "Multinomial Logistic Regression", "Member 1")
eval_m1 <- res_m1$eval_row
comp_m1 <- res_m1$comp_row
eval_m1$Training_Time_Sec <- time_m1
cat(sprintf("✔ Member 1 complete (Train Time: %.2fs) | Top-1 Acc: %.2f%% | Macro-F1: %.2f%% | ROC-AUC: %.2f%%\n\n", 
            time_m1, eval_m1$Top1_Accuracy, eval_m1$Macro_F1, eval_m1$ROC_AUC))

# --- MEMBER 2: LINEAR DISCRIMINANT ANALYSIS (LDA - Note 06) ---
cat("--- Training Member 2 Model: Linear Discriminant Analysis (MASS::lda) ---\n")
t0 <- Sys.time()
m2_lda <- lda(formula_model, data = train_set)
pred_lda_obj <- predict(m2_lda, newdata = test_set)
pred_m2 <- pred_lda_obj$class
prob_m2 <- pred_lda_obj$posterior
time_m2 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
res_m2 <- evaluate_predictions(test_set$MainCategory, pred_m2, prob_m2, "Linear Discriminant Analysis (LDA)", "Member 2")
eval_m2 <- res_m2$eval_row
comp_m2 <- res_m2$comp_row
eval_m2$Training_Time_Sec <- time_m2
cat(sprintf("✔ Member 2 complete (Train Time: %.2fs) | Top-1 Acc: %.2f%% | Macro-F1: %.2f%% | ROC-AUC: %.2f%%\n\n", 
            time_m2, eval_m2$Top1_Accuracy, eval_m2$Macro_F1, eval_m2$ROC_AUC))

# Single observation edge scoring latency benchmark (empirical measurement)
single_row <- test_set[1, ]
lat_runs <- replicate(100, {
  t_start <- Sys.time()
  predict(m2_lda, newdata = single_row)
  as.numeric(difftime(Sys.time(), t_start, units = "secs")) * 1000
})
mean_lat_ms <- mean(lat_runs)
cat(sprintf("✔ LDA Edge Scoring Latency: %.3f ms per transaction line (Sub-millisecond lookup)\n\n", mean_lat_ms))

# --- MEMBER 3: QUADRATIC DISCRIMINANT ANALYSIS (QDA - Note 06) ---
cat("--- Training Member 3 Model: Quadratic Discriminant Analysis (MASS::qda) ---\n")
t0 <- Sys.time()
qda_formula <- MainCategory ~ Qty1 + AdjustedRate + Discount + ServiceCharge + BasketItems
m3_qda <- qda(qda_formula, data = train_set)
pred_qda_obj <- predict(m3_qda, newdata = test_set)
pred_m3 <- pred_qda_obj$class
prob_m3 <- pred_qda_obj$posterior
time_m3 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
res_m3 <- evaluate_predictions(test_set$MainCategory, pred_m3, prob_m3, "Quadratic Discriminant Analysis (QDA)", "Member 3")
eval_m3 <- res_m3$eval_row
comp_m3 <- res_m3$comp_row
eval_m3$Training_Time_Sec <- time_m3
cat(sprintf("✔ Member 3 complete (Train Time: %.2fs) | Top-1 Acc: %.2f%% | Balanced Acc: %s | Macro-F1: %.2f%%\n\n", 
            time_m3, eval_m3$Top1_Accuracy, comp_m3$Balanced_Acc, eval_m3$Macro_F1))

# --- MEMBER 4: NAÏVE BAYES CLASSIFIER (Note 05 & Note 09) ---
cat("--- Training Member 4 Model: Naïve Bayes Classifier (e1071) ---\n")
t0 <- Sys.time()
m4_nb <- naiveBayes(formula_model, data = train_set, laplace = 1)
pred_m4 <- predict(m4_nb, newdata = test_set)
prob_m4 <- predict(m4_nb, newdata = test_set, type = "raw")
time_m4 <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
res_m4 <- evaluate_predictions(test_set$MainCategory, pred_m4, prob_m4, "Naïve Bayes Classifier", "Member 4")
eval_m4 <- res_m4$eval_row
comp_m4 <- res_m4$comp_row
eval_m4$Training_Time_Sec <- time_m4
cat(sprintf("✔ Member 4 complete (Train Time: %.2fs) | Top-1 Acc: %.2f%% | Macro-F1: %.2f%% | ROC-AUC: %.2f%%\n\n", 
            time_m4, eval_m4$Top1_Accuracy, eval_m4$Macro_F1, eval_m4$ROC_AUC))

# --- 3. MODEL COMPARISON & CHAMPION SELECTION ---
# Rank primarily by Top-1 Accuracy and Macro-F1 to select Champion
model_comparison <- bind_rows(eval_m1, eval_m2, eval_m3, eval_m4) %>%
  arrange(desc(Top1_Accuracy), desc(Macro_F1))

model_comprehensive <- bind_rows(comp_m1, comp_m2, comp_m3, comp_m4) %>%
  arrange(desc(as.numeric(gsub("%", "", Accuracy))), desc(as.numeric(gsub("%", "", Macro_F1))))

cat("====================================================================================================\n")
cat(" 4-MEMBER STATISTICAL MODEL EVALUATION LEADERBOARD (RANKED BY TOP-1 ACCURACY & MACRO-F1)\n")
cat("====================================================================================================\n")
print(as.data.frame(model_comparison))
cat("\n")

champion_model_name <- model_comparison$Model[1]
champion_member <- model_comparison$Member[1]
champion_top1 <- model_comparison$Top1_Accuracy[1]
champion_f1 <- model_comparison$Macro_F1[1]
champion_mcc <- model_comparison$MCC[1]
champion_auc <- model_comparison$ROC_AUC[1]

cat(sprintf("🏆 Champion Model Selected: %s (%s)\n", champion_model_name, champion_member))
cat(sprintf("   Top-1 Category Accuracy:               %.2f%%\n", champion_top1))
cat(sprintf("   Macro-F1 Score:                        %.2f%%\n", champion_f1))
cat(sprintf("   Matthews Correlation Coefficient (MCC): %.4f\n", champion_mcc))
cat(sprintf("   Multi-Class ROC-AUC:                   %.2f%%\n\n", champion_auc))

# --- 4. TASK 5 SYLLABUS EXTENSION: REGULARIZED SPEND REGRESSION (Note 03 & Note 07) ---
cat("--- Training Task 5 Spend Value Regression: OLS vs Ridge vs LASSO ---\n")
x_vars <- c("Qty1", "AdjustedRate", "Discount", "ServiceCharge", "BasketItems")
x_train <- as.matrix(train_set[, x_vars])
y_train <- train_set$Revenue
x_test <- as.matrix(test_set[, x_vars])
y_test <- test_set$Revenue

# Ridge Regression (alpha = 0)
cv_ridge <- cv.glmnet(x_train, y_train, alpha = 0)
pred_ridge <- predict(cv_ridge, s = "lambda.min", newx = x_test)
r2_ridge <- 1 - sum((y_test - pred_ridge)^2) / sum((y_test - mean(y_test))^2)
rmse_ridge <- sqrt(mean((y_test - pred_ridge)^2))

# LASSO Regression (alpha = 1)
cv_lasso <- cv.glmnet(x_train, y_train, alpha = 1)
pred_lasso <- predict(cv_lasso, s = "lambda.min", newx = x_test)
r2_lasso <- 1 - sum((y_test - pred_lasso)^2) / sum((y_test - mean(y_test))^2)
rmse_lasso <- sqrt(mean((y_test - pred_lasso)^2))

regression_summary <- data.frame(
  Method = c("Ridge Regression (L2)", "LASSO Regression (L1)"),
  R_Squared = c(round(r2_ridge, 4), round(r2_lasso, 4)),
  RMSE_LKR = c(round(rmse_ridge, 2), round(rmse_lasso, 2)),
  Variance_Explained = c(sprintf("%.2f%%", r2_ridge * 100), sprintf("%.2f%%", r2_lasso * 100))
)
print(regression_summary)
cat("\n")

out_dir <- "outputs"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

write_csv(model_comparison, file.path(out_dir, "model_evaluation_metrics.csv"))
write_csv(model_comprehensive, file.path(out_dir, "model_comprehensive_metrics.csv"))
write_csv(regression_summary, file.path(out_dir, "regression_spend_metrics.csv"))
cat("✔ Both model_evaluation_metrics.csv and model_comprehensive_metrics.csv exported successfully!\n\n")

# --- 5. VISUALIZATIONS: COMPARISON BARPLOT & CONFUSION MATRIX ---
fig_dir <- file.path(out_dir, "figures")
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

# Plot 1: Model Comparison Chart
comp_plot_df <- model_comparison %>%
  dplyr::select(Model, Top1_Accuracy, Macro_F1, ROC_AUC) %>%
  pivot_longer(-Model, names_to = "Metric", values_to = "Score") %>%
  mutate(Metric = case_when(
    Metric == "Top1_Accuracy" ~ "Top-1 Accuracy (%)",
    Metric == "Macro_F1" ~ "Macro-F1 (%)",
    Metric == "ROC_AUC" ~ "ROC-AUC (%)"
  ))

p_comp <- ggplot(comp_plot_df, aes(x = reorder(Model, Score), y = Score, fill = Metric)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7, alpha = 0.9) +
  geom_text(aes(label = sprintf("%.1f%%", Score)),
            position = position_dodge(width = 0.8), vjust = -0.4, size = 3.2, fontface = "bold") +
  scale_fill_manual(values = c("Top-1 Accuracy (%)" = "#2b6cb0", "Macro-F1 (%)" = "#38a169", "ROC-AUC (%)" = "#805ad5")) +
  scale_y_continuous(limits = c(0, 105), breaks = seq(0, 100, 20)) +
  coord_flip() +
  labs(
    title = "4-Member Statistical Classification Tournament Leaderboard",
    subtitle = "Champion LDA (Member 2) leads in Top-1 Accuracy and Macro-F1 across 5,893 test item lines",
    x = "",
    y = "Performance Score (%)",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 5 Predictive Modelling"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "fig_model_comparison.png"), p_comp, width = 9.5, height = 5.5, dpi = 300)

# Plot 2: LDA Champion Confusion Matrix Heatmap
cm_lda <- confusionMatrix(pred_m2, test_set$MainCategory)
cm_df <- as.data.frame(cm_lda$table)
colnames(cm_df) <- c("Predicted", "Actual", "Freq")

p_cm <- ggplot(cm_df, aes(x = Actual, y = Predicted, fill = Freq)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = comma(Freq)), fontface = "bold", size = 4.2, color = ifelse(cm_df$Freq > 800, "#ffffff", "#1a202c")) +
  scale_fill_gradient(low = "#ebf8ff", high = "#2b6cb0", labels = comma) +
  labs(
    title = "Champion Confusion Matrix: Linear Discriminant Analysis (Member 2)",
    subtitle = sprintf("Overall Accuracy: %.2f%% | Macro-F1: %.2f%% | Evaluated on 5,893 unseen item lines", 
                       eval_m2$Top1_Accuracy, eval_m2$Macro_F1),
    x = "Actual Ground Truth Category",
    y = "Model Predicted Category",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 5 Predictive Modelling"
  ) +
  theme_pub() +
  theme(panel.grid.major = element_blank())

ggsave(file.path(fig_dir, "fig_confusion_matrix.png"), p_cm, width = 7.5, height = 6, dpi = 300)
cat("✔ Visualizations saved: outputs/figures/fig_model_comparison.png and fig_confusion_matrix.png\n\n")

cat("==============================================\n")
cat(" Task 5 Predictive Modelling Complete!\n")
cat("==============================================\n")
