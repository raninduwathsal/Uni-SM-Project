# ============================================================
# IT3081 STATISTICAL MODELLING
# STROKE RISK IDENTIFICATION
# FINAL CLEAN CODE
# ============================================================


# ============================================================
# 1. WORKING DIRECTORY
# ============================================================

setwd("C:/Users/rasin/Downloads/SM Project")
getwd()


# ============================================================
# 2. PACKAGES
# ============================================================

# Run ONLY ONCE if a package is not installed:
# install.packages("tidyverse")
# install.packages("caret")
# install.packages("pROC")
# install.packages("PRROC")
# install.packages("naivebayes")
#install.packages("randomForest")
#install.packages("xgboost")
# install.packages("recipes")
# install.packages("themis")

library(tidyverse)
library(caret)
library(pROC)
library(PRROC)
library(naivebayes)
library(randomForest)
library(xgboost)
library(splines)
library(recipes)
library(themis)


# ============================================================
# 3. LOAD DATA
# ============================================================

stroke_raw <- read.csv(
  "healthcare-dataset-stroke-data.csv"
)

dim(stroke_raw)
names(stroke_raw)
str(stroke_raw)
summary(stroke_raw)


# ============================================================
# 4. MISSING VALUES
# ============================================================

stroke_raw$bmi <- trimws(
  as.character(stroke_raw$bmi)
)

stroke_raw$bmi[
  stroke_raw$bmi %in% c("", "N/A", "NA", "?")
] <- NA

stroke_raw$bmi <- as.numeric(
  stroke_raw$bmi
)


missing_summary <- data.frame(
  
  Variable = names(stroke_raw),
  
  Missing = colSums(
    is.na(stroke_raw)
  )
  
) %>%
  
  mutate(
    
    Percentage = round(
      Missing / nrow(stroke_raw) * 100,
      2
    )
  )


missing_summary


# ============================================================
# 5. TARGET DISTRIBUTION
# ============================================================

stroke_raw %>%
  
  count(stroke) %>%
  
  mutate(
    
    Percentage = round(
      n / sum(n) * 100,
      2
    )
  )


# ============================================================
# 6. OUTLIER CHECKING
# ============================================================

boxplot(
  stroke_raw$age,
  main = "Age"
)

boxplot(
  stroke_raw$avg_glucose_level,
  main = "Average Glucose Level"
)

boxplot(
  stroke_raw$bmi,
  main = "BMI Distribution",
  ylab = "BMI"
)


# ------------------------------------------------------------
# IQR OUTLIER FUNCTION
# ------------------------------------------------------------

outlier_summary <- function(x) {
  
  Q1 <- quantile(
    x,
    0.25,
    na.rm = TRUE
  )
  
  Q3 <- quantile(
    x,
    0.75,
    na.rm = TRUE
  )
  
  IQR_value <- IQR(
    x,
    na.rm = TRUE
  )
  
  lower <- Q1 - 1.5 * IQR_value
  upper <- Q3 + 1.5 * IQR_value
  
  data.frame(
    
    Q1 = Q1,
    
    Q3 = Q3,
    
    Lower_Bound = lower,
    
    Upper_Bound = upper,
    
    Number_Outliers = sum(
      x < lower |
        x > upper,
      na.rm = TRUE
    )
  )
}


outlier_summary(
  stroke_raw$age
)

outlier_summary(
  stroke_raw$avg_glucose_level
)

outlier_summary(
  stroke_raw$bmi
)


# ------------------------------------------------------------
# EXAMINE GLUCOSE OUTLIERS
# ------------------------------------------------------------

Q1 <- quantile(
  stroke_raw$avg_glucose_level,
  0.25,
  na.rm = TRUE
)

Q3 <- quantile(
  stroke_raw$avg_glucose_level,
  0.75,
  na.rm = TRUE
)

IQR_value <- IQR(
  stroke_raw$avg_glucose_level,
  na.rm = TRUE
)

lower <- Q1 - 1.5 * IQR_value
upper <- Q3 + 1.5 * IQR_value


stroke_raw$avg_glucose_level[
  stroke_raw$avg_glucose_level < lower |
    stroke_raw$avg_glucose_level > upper
]


# Outliers are retained because extreme observations may
# represent plausible patient values and may contain
# clinically meaningful information.


# ============================================================
# 7. DATA PREPARATION
# ============================================================

stroke <- stroke_raw %>%
  
  select(-id) %>%
  
  mutate(
    
    gender = factor(gender),
    
    hypertension = factor(
      hypertension,
      levels = c(0, 1),
      labels = c("No", "Yes")
    ),
    
    heart_disease = factor(
      heart_disease,
      levels = c(0, 1),
      labels = c("No", "Yes")
    ),
    
    ever_married = factor(
      ever_married
    ),
    
    work_type = factor(
      work_type
    ),
    
    Residence_type = factor(
      Residence_type
    ),
    
    smoking_status = factor(
      smoking_status
    ),
    
    stroke = factor(
      stroke,
      levels = c(0, 1),
      labels = c(
        "No Stroke",
        "Stroke"
      )
    )
  )


str(stroke)


# ============================================================
# 8. STRATIFIED TRAIN-TEST SPLIT
# ============================================================

set.seed(123)

train_index <- createDataPartition(
  stroke$stroke,
  p = 0.80,
  list = FALSE
)


train <- stroke[
  train_index,
]

test <- stroke[
  -train_index,
]


dim(train)
dim(test)

table(train$stroke)
table(test$stroke)

prop.table(
  table(train$stroke)
) * 100

prop.table(
  table(test$stroke)
) * 100


# ============================================================
# 9. BMI IMPUTATION
# Learn median ONLY from training data
# ============================================================

train_bmi_median <- median(
  train$bmi,
  na.rm = TRUE
)

train_bmi_median


train$bmi[
  is.na(train$bmi)
] <- train_bmi_median


test$bmi[
  is.na(test$bmi)
] <- train_bmi_median


sum(is.na(train$bmi))
sum(is.na(test$bmi))


# ============================================================
# 10. DESCRIPTIVE ANALYSIS
# ============================================================

eda_data <- stroke_raw %>%
  
  mutate(
    
    Stroke_Status = factor(
      stroke,
      levels = c(0, 1),
      labels = c(
        "No Stroke",
        "Stroke"
      )
    )
  )





#STATS TABLE

# ============================================================
# DESCRIPTIVE STATISTICS FOR CONTINUOUS VARIABLES
# ============================================================
continuous_vars <- c(
  "age",
  "avg_glucose_level",
  "bmi"
)

descriptive_stats <- data.frame(
  
  Variable = continuous_vars,
  
  Mean = sapply(
    eda_data[continuous_vars],
    function(x) mean(x, na.rm = TRUE)
  ),
  
  Median = sapply(
    eda_data[continuous_vars],
    function(x) median(x, na.rm = TRUE)
  ),
  
  SD = sapply(
    eda_data[continuous_vars],
    function(x) sd(x, na.rm = TRUE)
  ),
  
  IQR = sapply(
    eda_data[continuous_vars],
    function(x) IQR(x, na.rm = TRUE)
  ),
  
  Minimum = sapply(
    eda_data[continuous_vars],
    function(x) min(x, na.rm = TRUE)
  ),
  
  Maximum = sapply(
    eda_data[continuous_vars],
    function(x) max(x, na.rm = TRUE)
  )
)

# Round numerical values to 2 decimal places
descriptive_stats[, -1] <- round(
  descriptive_stats[, -1],
  2
)

descriptive_stats






# ------------------------------------------------------------
# STROKE DISTRIBUTION
# ------------------------------------------------------------

class_plot_data <- eda_data %>%
  
  count(Stroke_Status) %>%
  
  mutate(
    
    Percentage =
      n / sum(n) * 100
  )


class_plot_data


ggplot(
  class_plot_data,
  aes(
    x = Stroke_Status,
    y = Percentage,
    fill = Stroke_Status
  )
) +
  
  geom_col(
    width = 0.6
  ) +
  
  geom_text(
    
    aes(
      label = paste0(
        n,
        "\n",
        round(
          Percentage,
          2
        ),
        "%"
      )
    ),
    
    vjust = -0.3
  ) +
  
  labs(
    title = "Distribution of Stroke Outcomes",
    x = NULL,
    y = "Percentage (%)"
  ) +
  
  theme_minimal() +
  
  theme(
    legend.position = "none"
  )


# ------------------------------------------------------------
# AGE VS STROKE
# ------------------------------------------------------------

ggplot(
  eda_data,
  aes(
    x = Stroke_Status,
    y = age,
    fill = Stroke_Status
  )
) +
  
  geom_boxplot() +
  
  labs(
    title = "Age Distribution by Stroke Status",
    x = NULL,
    y = "Age"
  ) +
  
  theme_minimal() +
  
  theme(
    legend.position = "none"
  )


# ------------------------------------------------------------
# GLUCOSE VS STROKE
# ------------------------------------------------------------

ggplot(
  eda_data,
  aes(
    x = Stroke_Status,
    y = avg_glucose_level,
    fill = Stroke_Status
  )
) +
  
  geom_boxplot() +
  
  labs(
    title = "Glucose Level by Stroke Status",
    x = NULL,
    y = "Average Glucose Level"
  ) +
  
  theme_minimal() +
  
  theme(
    legend.position = "none"
  )


# ------------------------------------------------------------
# HYPERTENSION VS STROKE
# ------------------------------------------------------------

hypertension_summary <- eda_data %>%
  
  group_by(
    hypertension
  ) %>%
  
  summarise(
    
    Total = n(),
    
    Stroke_Cases =
      sum(stroke == 1),
    
    Stroke_Rate =
      Stroke_Cases /
      Total *
      100
  )


hypertension_summary


ggplot(
  hypertension_summary,
  aes(
    x = factor(hypertension),
    y = Stroke_Rate,
    fill = factor(hypertension)
  )
) +
  
  geom_col(
    width = 0.6
  ) +
  
  geom_text(
    
    aes(
      label = paste0(
        round(
          Stroke_Rate,
          1
        ),
        "%"
      )
    ),
    
    vjust = -0.3
  ) +
  
  labs(
    title = "Stroke Rate by Hypertension Status",
    x = "Hypertension",
    y = "Stroke Rate (%)"
  ) +
  
  theme_minimal() +
  
  theme(
    legend.position = "none"
  )


# ------------------------------------------------------------
# HEART DISEASE VS STROKE
# ------------------------------------------------------------

heart_summary <- eda_data %>%
  
  group_by(
    heart_disease
  ) %>%
  
  summarise(
    
    Total = n(),
    
    Stroke_Cases =
      sum(stroke == 1),
    
    Stroke_Rate =
      Stroke_Cases /
      Total *
      100
  )


heart_summary


ggplot(
  heart_summary,
  aes(
    x = factor(heart_disease),
    y = Stroke_Rate,
    fill = factor(heart_disease)
  )
) +
  
  geom_col(
    width = 0.6
  ) +
  
  geom_text(
    
    aes(
      label = paste0(
        round(
          Stroke_Rate,
          1
        ),
        "%"
      )
    ),
    
    vjust = -0.3
  ) +
  
  labs(
    title = "Stroke Rate by Heart Disease Status",
    x = "Heart Disease",
    y = "Stroke Rate (%)"
  ) +
  
  theme_minimal() +
  
  theme(
    legend.position = "none"
  )


# ------------------------------------------------------------
# BMI VS STROKE
# ------------------------------------------------------------

ggplot(
  eda_data,
  aes(
    x = Stroke_Status,
    y = bmi,
    fill = Stroke_Status
  )
) +
  
  geom_boxplot(
    na.rm = TRUE
  ) +
  
  labs(
    title = "BMI Distribution by Stroke Status",
    x = NULL,
    y = "BMI"
  ) +
  
  theme_minimal() +
  
  theme(
    legend.position = "none"
  )

# Normality check
by(
  eda_data$bmi,
  eda_data$Stroke_Status,
  shapiro.test
)




# ============================================================
# 11. DISTRIBUTION CHECKS
# ============================================================

ggplot(
  eda_data,
  aes(
    x = avg_glucose_level
  )
) +
  
  geom_histogram(
    bins = 30
  ) +
  
  facet_wrap(
    ~ Stroke_Status
  ) +
  
  labs(
    title = "Glucose Distribution by Stroke Status",
    x = "Average Glucose Level",
    y = "Frequency"
  ) +
  
  theme_minimal()


ggplot(
  eda_data,
  aes(
    x = age
  )
) +
  
  geom_histogram(
    bins = 30
  ) +
  
  facet_wrap(
    ~ Stroke_Status
  ) +
  
  labs(
    title = "Age Distribution by Stroke Status",
    x = "Age",
    y = "Frequency"
  ) +
  
  theme_minimal()


# ============================================================
# 12. NORMALITY CHECKS
# ============================================================

by(
  eda_data$age,
  eda_data$Stroke_Status,
  shapiro.test
)


by(
  eda_data$avg_glucose_level,
  eda_data$Stroke_Status,
  shapiro.test
)


# ============================================================
# 13. STATISTICAL INFERENCE
# ============================================================


# ------------------------------------------------------------
# AGE VS STROKE
#
# H0: Age distributions do not differ.
# H1: Age distributions differ.
# ------------------------------------------------------------

age_test <- wilcox.test(
  age ~ Stroke_Status,
  data = eda_data,
  exact = FALSE
)

age_test


# ------------------------------------------------------------
# GLUCOSE VS STROKE
#
# H0: Glucose distributions do not differ.
# H1: Glucose distributions differ.
# ------------------------------------------------------------

glucose_test <- wilcox.test(
  avg_glucose_level ~ Stroke_Status,
  data = eda_data,
  exact = FALSE
)

glucose_test


#
#======================================
#BMI VS STROKE
#======================================
# ------------------------------------------------------------
# BMI VS STROKE
#
# H0: BMI distributions do not differ between stroke groups.
# H1: BMI distributions differ between stroke groups.
# ------------------------------------------------------------

bmi_test <- wilcox.test(
  bmi ~ Stroke_Status,
  data = eda_data,
  exact = FALSE,
  na.action = na.omit
)

bmi_test



# ------------------------------------------------------------
# HYPERTENSION VS STROKE
#
# H0: Hypertension and stroke are independent.
# H1: Hypertension and stroke are associated.
# ------------------------------------------------------------

hypertension_table <- table(
  eda_data$hypertension,
  eda_data$Stroke_Status
)

hypertension_table


hypertension_test <- chisq.test(
  hypertension_table
)

hypertension_test
hypertension_test$expected


# ------------------------------------------------------------
# HEART DISEASE VS STROKE
#
# H0: Heart disease and stroke are independent.
# H1: Heart disease and stroke are associated.
# ------------------------------------------------------------

heart_table <- table(
  eda_data$heart_disease,
  eda_data$Stroke_Status
)

heart_table


heart_test <- chisq.test(
  heart_table
)

heart_test
heart_test$expected



#we will test 5 -ever married and stroke
#H₀: Marital status and stroke status are independent.
#H₁: Marital status and stroke status are associated.
married_table <- table(
  stroke$ever_married,
  stroke$stroke
)

married_table

married_chi <- chisq.test(
  married_table
)

married_chi

married_chi$expected



#we are testing 6 - work type and stroke
#H₀: Work type and stroke status are independent.
#H₁: Work type and stroke status are associated.


work_table <- table(
  stroke$work_type,
  stroke$stroke
)

work_table

work_chi <- chisq.test(
  work_table
)

work_chi

work_chi$expected


#the chi squared test above won't give a proper estimate because never worked+stroke representative is very small
#so the error comes up saying that don't fully rely on my p value do another test for it, that is what we have done below

# ============================================================
# WORK TYPE VS STROKE
# Fisher's Exact Test with Monte Carlo simulation
# ============================================================

set.seed(123)

work_fisher <- fisher.test(
  work_table,
  simulate.p.value = TRUE,
  B = 100000
)

work_fisher




#we are test 7- residence type and stroke
#H₀: Residence type and stroke status are independent.
#H₁: Residence type and stroke status are associated.

residence_table <- table(
  stroke$Residence_type,
  stroke$stroke
)

residence_table

residence_chi <- chisq.test(
  residence_table
)

residence_chi

residence_chi$expected


#we are testing 8 - smoking status vs stroke
#H₀: Smoking status and stroke status are independent.
#H₁: Smoking status and stroke status are associated.

smoking_table <- table(
  stroke$smoking_status,
  stroke$stroke
)

smoking_table

smoking_chi <- chisq.test(
  smoking_table
)

smoking_chi

smoking_chi$expected



# ============================================================
# INFERENCE SUMMARY
# ============================================================


inference_results <- data.frame(
  
  Relationship = c(
    "Age vs Stroke",
    "Glucose vs Stroke",
    "BMI vs Stroke",
    "Hypertension vs Stroke",
    "Heart Disease vs Stroke",
    "Ever Married vs Stroke",
    "Work Type vs Stroke",
    "Residence Type vs Stroke",
    "Smoking Status vs Stroke"
  ),
  
  Test = c(
    "Wilcoxon Rank-Sum",
    "Wilcoxon Rank-Sum",
    "Wilcoxon Rank-Sum",
    "Chi-Square",
    "Chi-Square",
    "Chi-Square",
    "Fisher Exact (Monte Carlo)",
    "Chi-Square",
    "Chi-Square"
  ),
  
  P_Value = c(
    age_test$p.value,
    glucose_test$p.value,
    bmi_test$p.value,
    hypertension_test$p.value,
    heart_test$p.value,
    married_chi$p.value,
    work_fisher$p.value,
    residence_chi$p.value,
    smoking_chi$p.value
  )
)

inference_results <- inference_results %>%
  mutate(
    Decision = ifelse(
      P_Value < 0.05,
      "Reject H0",
      "Fail to Reject H0"
    )
  )

inference_results


# ============================================================
# 14. PREDICTIVE MODELLING PREPARATION
# ============================================================

train_x <- train %>%
  select(-stroke)

test_x <- test %>%
  select(-stroke)


# ------------------------------------------------------------
# DUMMY ENCODING
# Learn encoder from TRAINING DATA ONLY
# ------------------------------------------------------------

dummy_encoder <- dummyVars(
  ~ .,
  data = train_x,
  fullRank = TRUE
)


x_train <- predict(
  dummy_encoder,
  newdata = train_x
)

x_train <- as.matrix(
  x_train
)


x_test <- predict(
  dummy_encoder,
  newdata = test_x
)

x_test <- as.matrix(
  x_test
)


# Binary targets

y_train <- ifelse(
  train$stroke == "Stroke",
  1,
  0
)

y_test <- ifelse(
  test$stroke == "Stroke",
  1,
  0
)


dim(x_train)
dim(x_test)

table(y_train)
table(y_test)


# ============================================================
# 15. COMMON 10-FOLD CROSS-VALIDATION SPLIT
# ============================================================

set.seed(123)

foldid <- createFolds(
  y_train,
  k = 10,
  list = FALSE
)

table(foldid)


# ============================================================
# 16. MODEL 1 - STANDARD LOGISTIC REGRESSION
# ============================================================

log_model <- glm(
  stroke ~ .,
  data = train,
  family = binomial
)

summary(log_model)


# Test probabilities

log_prob <- predict(
  log_model,
  newdata = test,
  type = "response"
)

summary(log_prob)


# ------------------------------------------------------------
# 16A. MULTICOLLINEARITY CHECK
# ------------------------------------------------------------

vif_results <- car::vif(
  log_model
)

vif_results





# ------------------------------------------------------------
# 16B. LINEARITY OF THE LOGIT CHECK
# Continuous predictors: age, glucose and BMI
# ------------------------------------------------------------

linearity_data <- train %>%
  mutate(
    age_bt = (age + 1) * log(age + 1),
    glucose_bt =
      avg_glucose_level * log(avg_glucose_level),
    bmi_bt =
      bmi * log(bmi)
  )


linearity_model <- glm(
  stroke ~
    gender +
    age +
    hypertension +
    heart_disease +
    ever_married +
    work_type +
    Residence_type +
    avg_glucose_level +
    bmi +
    smoking_status +
    age_bt +
    glucose_bt +
    bmi_bt,
  data = linearity_data,
  family = binomial()
)


linearity_results <-
  summary(linearity_model)$coefficients[
    c(
      "age_bt",
      "glucose_bt",
      "bmi_bt"
    ),
    ,
    drop = FALSE
  ]

linearity_results

#All three diagnostic terms had p-values greater than 0.05, so there was no 
#evidence of violation of the linearity-of-the-logit assumption.


#p>0.05 means linear logit

#we check this because in logistic regression probability should be between
#0 and 1, but a linear eqn could give a value like 1.2/-0.3 so log odds translates
#that to between 0 and 1

#Predictors → linear equation → log-odds → probability between 0 and 1



# ============================================================
# 16C. LOGISTIC REGRESSION INTERPRETATION
# Odds Ratios, 95% Confidence Intervals and P-values
# ============================================================


#If CI does not contain 1 -> there is evidence to say that age(predictor) is associated
#with stroke


#When p<0.05 there is evidence to say that the predictor and stroke has an 
#association



OR <- exp(
  coef(log_model)
)


CI <- exp(
  confint.default(log_model)
)


p_values <-
  summary(log_model)$coefficients[, 4]


odds_ratio_results <- data.frame(
  
  Predictor = names(OR),
  
  Odds_Ratio = round(
    OR,
    3
  ),
  
  CI_Lower = round(
    CI[, 1],
    3
  ),
  
  CI_Upper = round(
    CI[, 2],
    3
  ),
  
  P_Value = round(
    p_values,
    4
  )
)


odds_ratio_results



# ============================================================
# 17. MODEL 2 - NAIVE BAYES
# ============================================================

set.seed(123)

nb_model <- naive_bayes(
  stroke ~ .,
  data = train,
  usekernel = TRUE
)

nb_model


nb_prob <- predict(
  nb_model,
  newdata = test,
  type = "prob"
)[, "Stroke"]


summary(nb_prob)


# ============================================================
# 18. OOF PREDICTIONS - LOGISTIC REGRESSION
# ============================================================

log_oof_prob <- numeric(
  nrow(train)
)


for(
  fold in sort(unique(foldid))
) {
  
  validation_index <- which(
    foldid == fold
  )
  
  training_index <- which(
    foldid != fold
  )
  
  
  x_fold_train <- x_train[
    training_index,
    ,
    drop = FALSE
  ]
  
  x_fold_valid <- x_train[
    validation_index,
    ,
    drop = FALSE
  ]
  
  
  # Remove predictors with no variation
  # within this training fold.
  
  keep_columns <- apply(
    x_fold_train,
    2,
    function(x)
      length(unique(x)) > 1
  )
  
  
  x_fold_train <- x_fold_train[
    ,
    keep_columns,
    drop = FALSE
  ]
  
  x_fold_valid <- x_fold_valid[
    ,
    keep_columns,
    drop = FALSE
  ]
  
  
  temp_train <- data.frame(
    y = y_train[
      training_index
    ],
    x_fold_train
  )
  
  
  temp_valid <- data.frame(
    x_fold_valid
  )
  
  
  temp_model <- glm(
    y ~ .,
    data = temp_train,
    family = binomial
  )
  
  
  log_oof_prob[
    validation_index
  ] <- predict(
    temp_model,
    newdata = temp_valid,
    type = "response"
  )
}


length(log_oof_prob)
sum(is.na(log_oof_prob))
range(log_oof_prob)


# ============================================================
# 19. OOF PREDICTIONS - NAIVE BAYES
# ============================================================

nb_oof_prob <- numeric(
  nrow(train)
)


for(
  fold in sort(unique(foldid))
) {
  
  validation_index <- which(
    foldid == fold
  )
  
  training_index <- which(
    foldid != fold
  )
  
  
  fold_train <- train[
    training_index,
    ,
    drop = FALSE
  ]
  
  
  fold_valid <- train[
    validation_index,
    ,
    drop = FALSE
  ]
  
  
  nb_fold_model <- naive_bayes(
    stroke ~ .,
    data = fold_train,
    usekernel = TRUE
  )
  
  
  nb_oof_prob[
    validation_index
  ] <- predict(
    nb_fold_model,
    newdata = fold_valid,
    type = "prob"
  )[, "Stroke"]
}


length(nb_oof_prob)
sum(is.na(nb_oof_prob))
range(nb_oof_prob)


# ============================================================
# 20. MODEL 3 - WEIGHTED LOGISTIC REGRESSION
# Class weight based ONLY on training-set class imbalance
# ============================================================
# Purpose:
# Give the minority Stroke class greater influence during model fitting.
# The Stroke weight is calculated from the training data as:
#   Number of No-Stroke cases / Number of Stroke cases
# No manual candidate-weight tuning is performed.
# ============================================================

# Create spline bases for Age and BMI from training data
age_spline_train <- ns(train$age, df = 3)
bmi_spline_train <- ns(train$bmi, df = 3)
age_spline_test <- predict(age_spline_train, newx = test$age)
bmi_spline_test <- predict(bmi_spline_train, newx = test$bmi)

colnames(age_spline_train) <- c("age_spline1", "age_spline2", "age_spline3")
colnames(age_spline_test)  <- c("age_spline1", "age_spline2", "age_spline3")
colnames(bmi_spline_train) <- c("bmi_spline1", "bmi_spline2", "bmi_spline3")
colnames(bmi_spline_test)  <- c("bmi_spline1", "bmi_spline2", "bmi_spline3")

weighted_x_train <- x_train[, !colnames(x_train) %in% c("age", "bmi"), drop = FALSE]
weighted_x_test  <- x_test[, !colnames(x_test) %in% c("age", "bmi"), drop = FALSE]
weighted_x_train <- cbind(weighted_x_train, age_spline_train, bmi_spline_train)
weighted_x_test  <- cbind(weighted_x_test, age_spline_test, bmi_spline_test)

stopifnot(identical(colnames(weighted_x_train), colnames(weighted_x_test)))

# ------------------------------------------------------------
# Calculate class-imbalance weight from TRAINING DATA ONLY
# ------------------------------------------------------------

stroke_weight <- sum(y_train == 0) / sum(y_train == 1)

cat("No-Stroke training cases:", sum(y_train == 0), "\n")
cat("Stroke training cases:", sum(y_train == 1), "\n")
cat("Stroke class weight:", round(stroke_weight, 3), "\n")

# ------------------------------------------------------------
# OOF predictions for Weighted Logistic Regression
# IMPORTANT: within each fold, calculate the class weight from
# that fold's training portion only.
# ------------------------------------------------------------

weighted_oof_prob <- rep(NA_real_, nrow(train))

for (fold in sort(unique(foldid))) {

  validation_index <- which(foldid == fold)
  training_index <- which(foldid != fold)

  x_fold_train <- weighted_x_train[training_index, , drop = FALSE]
  x_fold_valid <- weighted_x_train[validation_index, , drop = FALSE]

  # Remove predictors with no variation inside this training fold
  keep_columns <- apply(
    x_fold_train,
    2,
    function(x) length(unique(x)) > 1
  )

  x_fold_train <- x_fold_train[, keep_columns, drop = FALSE]
  x_fold_valid <- x_fold_valid[, keep_columns, drop = FALSE]

  fold_y <- y_train[training_index]

  # Calculate imbalance ratio using ONLY this fold's training data
  fold_stroke_weight <- sum(fold_y == 0) / sum(fold_y == 1)
  fold_weights <- ifelse(fold_y == 1, fold_stroke_weight, 1)

  temp_train <- data.frame(
    y = fold_y,
    x_fold_train,
    check.names = FALSE
  )

  temp_valid <- data.frame(
    x_fold_valid,
    check.names = FALSE
  )

  weighted_fold_model <- glm(
    y ~ .,
    data = temp_train,
    family = binomial(),
    weights = fold_weights
  )

  weighted_oof_prob[validation_index] <- predict(
    weighted_fold_model,
    newdata = temp_valid,
    type = "response"
  )
}

length(weighted_oof_prob)
sum(is.na(weighted_oof_prob))
range(weighted_oof_prob)

# ------------------------------------------------------------
# Fit FINAL Weighted Logistic model on ALL training data
# ------------------------------------------------------------

final_train_weights <- ifelse(y_train == 1, stroke_weight, 1)

weighted_final_data <- data.frame(
  y = y_train,
  weighted_x_train,
  check.names = FALSE
)

weighted_test_data <- data.frame(
  weighted_x_test,
  check.names = FALSE
)

set.seed(123)

weighted_model <- glm(
  y ~ .,
  data = weighted_final_data,
  family = binomial(),
  weights = final_train_weights
)

summary(weighted_model)

# Final untouched-test probabilities
weighted_prob <- predict(
  weighted_model,
  newdata = weighted_test_data,
  type = "response"
)

summary(weighted_prob)
range(weighted_prob)
sum(is.na(weighted_prob))

# GVIF/VIF on final numeric design model
weighted_vif_results <- car::vif(weighted_model)
weighted_vif_results

# Age and BMI are represented with natural cubic splines, so their spline
# coefficients should not be interpreted as simple per-unit odds ratios.


# ============================================================
# 20B. MODEL 4 - SMOTE LOGISTIC REGRESSION
# ============================================================
# Purpose:
# Compare a third imbalance strategy against:
#   1) Standard Logistic Regression (no imbalance treatment)
#   2) Weighted Logistic Regression (class weighting)
#   3) SMOTE Logistic Regression (synthetic minority oversampling)
#
# IMPORTANT:
# SMOTE is applied ONLY to each CV training fold.
# The held-out validation fold is NEVER SMOTEd.
# The final test set is NEVER SMOTEd.
# ============================================================

# OOF probabilities for SMOTE Logistic
smote_oof_prob <- rep(NA_real_, nrow(train))

for (fold in sort(unique(foldid))) {
  
  validation_index <- which(foldid == fold)
  training_index <- which(foldid != fold)
  
  fold_train <- train[training_index, , drop = FALSE]
  fold_valid <- train[validation_index, , drop = FALSE]
  
  # Build preprocessing recipe ONLY from this fold's training data.
  # step_novel safely handles a category that may appear only in validation.
  # step_smotenc performs SMOTE for mixed numeric + categorical predictors.
  # over_ratio = 1 makes the minority class approximately as frequent as
  # the majority class within the resampled TRAINING fold.
  smote_recipe_fold <- recipe(
    stroke ~ .,
    data = fold_train
  ) %>%
    step_novel(all_nominal_predictors()) %>%
    step_smotenc(
      stroke,
      over_ratio = 1,
      neighbors = 5
    ) %>%
    step_dummy(
      all_nominal_predictors(),
      one_hot = FALSE
    ) %>%
    step_zv(all_predictors())
  
  set.seed(123 + fold)
  smote_prep_fold <- prep(
    smote_recipe_fold,
    training = fold_train,
    retain = TRUE
  )
  
  # juice() returns the resampled training data (SMOTE applied).
  smote_fold_train <- juice(smote_prep_fold)
  
  # bake() on new validation data does NOT apply SMOTE because
  # the SMOTE recipe step is skipped for new data.
  smote_fold_valid <- bake(
    smote_prep_fold,
    new_data = fold_valid
  )
  
  smote_fold_model <- glm(
    stroke ~ .,
    data = smote_fold_train,
    family = binomial()
  )
  
  smote_oof_prob[validation_index] <- predict(
    smote_fold_model,
    newdata = smote_fold_valid,
    type = "response"
  )
}

# Check OOF predictions
length(smote_oof_prob)
sum(is.na(smote_oof_prob))
range(smote_oof_prob)

# ------------------------------------------------------------
# Fit FINAL SMOTE Logistic model on ALL training data
# ------------------------------------------------------------

smote_recipe_final <- recipe(
  stroke ~ .,
  data = train
) %>%
  step_novel(all_nominal_predictors()) %>%
  step_smotenc(
    stroke,
    over_ratio = 1,
    neighbors = 5
  ) %>%
  step_dummy(
    all_nominal_predictors(),
    one_hot = FALSE
  ) %>%
  step_zv(all_predictors())

set.seed(123)
smote_prep_final <- prep(
  smote_recipe_final,
  training = train,
  retain = TRUE
)

# Resampled training data
smote_train_final <- juice(smote_prep_final)

# Untouched test observations transformed using the training recipe.
# SMOTE is NOT applied to the test set.
smote_test_final <- bake(
  smote_prep_final,
  new_data = test
)

# Show class distribution before and after SMOTE
table(train$stroke)
table(smote_train_final$stroke)

smote_model <- glm(
  stroke ~ .,
  data = smote_train_final,
  family = binomial()
)

summary(smote_model)

# Final untouched-test probabilities
smote_prob <- predict(
  smote_model,
  newdata = smote_test_final,
  type = "response"
)

summary(smote_prob)
range(smote_prob)
sum(is.na(smote_prob))

# ============================================================
# 21. MODEL 5 - RANDOM FOREST
# ============================================================

set.seed(123)


rf_model <- randomForest(
  
  x = x_train,
  
  y = factor(
    y_train,
    levels = c(0, 1),
    labels = c(
      "No Stroke",
      "Stroke"
    )
  ),
  
  ntree = 500,
  
  importance = TRUE
)


rf_model


rf_prob <- predict(
  rf_model,
  newdata = x_test,
  type = "prob"
)[, "Stroke"]


summary(rf_prob)


# Variable importance

importance(
  rf_model
)


# ------------------------------------------------------------
# OOF - RANDOM FOREST
# ------------------------------------------------------------

rf_oof_prob <- numeric(
  nrow(train)
)


for(
  fold in sort(unique(foldid))
) {
  
  validation_index <- which(
    foldid == fold
  )
  
  training_index <- which(
    foldid != fold
  )
  
  
  x_fold_train <- x_train[
    training_index,
    ,
    drop = FALSE
  ]
  
  
  x_fold_valid <- x_train[
    validation_index,
    ,
    drop = FALSE
  ]
  
  
  keep_columns <- apply(
    x_fold_train,
    2,
    function(x)
      length(unique(x)) > 1
  )
  
  
  x_fold_train <- x_fold_train[
    ,
    keep_columns,
    drop = FALSE
  ]
  
  x_fold_valid <- x_fold_valid[
    ,
    keep_columns,
    drop = FALSE
  ]
  
  
  fold_y <- factor(
    
    y_train[
      training_index
    ],
    
    levels = c(0, 1),
    
    labels = c(
      "No Stroke",
      "Stroke"
    )
  )
  
  
  set.seed(
    123 + fold
  )
  
  
  rf_fold_model <- randomForest(
    
    x = x_fold_train,
    
    y = fold_y,
    
    ntree = 500
  )
  
  
  rf_oof_prob[
    validation_index
  ] <- predict(
    
    rf_fold_model,
    
    newdata = x_fold_valid,
    
    type = "prob"
    
  )[, "Stroke"]
}


length(rf_oof_prob)
sum(is.na(rf_oof_prob))
range(rf_oof_prob)


# ============================================================
# 22. MODEL 6 - XGBOOST
# ============================================================

# ------------------------------------------------------------
# Calculate class imbalance weight
# ------------------------------------------------------------

xgb_scale_pos_weight <-
  sum(y_train == 0) /
  sum(y_train == 1)

xgb_scale_pos_weight


# ------------------------------------------------------------
# Create XGBoost DMatrix objects
# ------------------------------------------------------------

dtrain <- xgb.DMatrix(
  data = x_train,
  label = y_train
)

dtest <- xgb.DMatrix(
  data = x_test,
  label = y_test
)


# ------------------------------------------------------------
# XGBoost parameters
# ------------------------------------------------------------

xgb_params <- list(
  
  objective = "binary:logistic",
  
  eval_metric = "auc",
  
  max_depth = 3,
  
  learning_rate = 0.05,
  
  subsample = 0.8,
  
  colsample_bytree = 0.8,
  
  scale_pos_weight =
    xgb_scale_pos_weight
)


# ------------------------------------------------------------
# Train final XGBoost model
# ------------------------------------------------------------

set.seed(123)

xgb_model <- xgb.train(
  
  params = xgb_params,
  
  data = dtrain,
  
  nrounds = 200,
  
  verbose = 0
)


# ------------------------------------------------------------
# Predict probabilities on test data
# ------------------------------------------------------------

xgb_prob <- predict(
  xgb_model,
  dtest
)


summary(xgb_prob)

range(xgb_prob)

# ============================================================
# XGBOOST OOF PREDICTIONS
# ============================================================

xgb_oof_prob <- numeric(
  nrow(train)
)


for(
  fold in sort(unique(foldid))
) {
  
  # ----------------------------------------------------------
  # Identify training and validation observations
  # ----------------------------------------------------------
  
  validation_index <- which(
    foldid == fold
  )
  
  training_index <- which(
    foldid != fold
  )
  
  
  # ----------------------------------------------------------
  # Split predictors
  # ----------------------------------------------------------
  
  x_fold_train <- x_train[
    training_index,
    ,
    drop = FALSE
  ]
  
  x_fold_valid <- x_train[
    validation_index,
    ,
    drop = FALSE
  ]
  
  
  # ----------------------------------------------------------
  # Split target
  # ----------------------------------------------------------
  
  fold_y_train <- y_train[
    training_index
  ]
  
  
  # ----------------------------------------------------------
  # Calculate class weight ONLY from fold training data
  # ----------------------------------------------------------
  
  fold_scale_pos_weight <-
    sum(fold_y_train == 0) /
    sum(fold_y_train == 1)
  
  
  # ----------------------------------------------------------
  # Create DMatrix objects
  # ----------------------------------------------------------
  
  dtrain_fold <- xgb.DMatrix(
    data = x_fold_train,
    label = fold_y_train
  )
  
  
  dvalid_fold <- xgb.DMatrix(
    data = x_fold_valid
  )
  
  
  # ----------------------------------------------------------
  # Parameters for this fold
  # ----------------------------------------------------------
  
  fold_params <- list(
    
    objective = "binary:logistic",
    
    eval_metric = "auc",
    
    max_depth = 3,
    
    learning_rate = 0.05,
    
    subsample = 0.8,
    
    colsample_bytree = 0.8,
    
    scale_pos_weight =
      fold_scale_pos_weight
  )
  
  
  # ----------------------------------------------------------
  # Train model
  # ----------------------------------------------------------
  
  set.seed(
    123 + fold
  )
  
  
  xgb_fold_model <- xgb.train(
    
    params = fold_params,
    
    data = dtrain_fold,
    
    nrounds = 200,
    
    verbose = 0
  )
  
  
  # ----------------------------------------------------------
  # Predict held-out fold
  # ----------------------------------------------------------
  
  xgb_oof_prob[
    validation_index
  ] <- predict(
    xgb_fold_model,
    dvalid_fold
  )
}


# ------------------------------------------------------------
# Check OOF predictions
# ------------------------------------------------------------

length(xgb_oof_prob)

sum(
  is.na(xgb_oof_prob)
)

range(
  xgb_oof_prob
)




# ============================================================
# 23. THRESHOLD EVALUATION FUNCTION
# ============================================================

evaluate_thresholds <- function(
    probabilities,
    actual
) {
  
  thresholds <- seq(
    0.01,
    0.99,
    by = 0.01
  )
  
  
  results <- data.frame()
  
  
  for(t in thresholds) {
    
    predicted <- ifelse(
      probabilities >= t,
      1,
      0
    )
    
    
    TP <- sum(
      predicted == 1 &
        actual == 1
    )
    
    TN <- sum(
      predicted == 0 &
        actual == 0
    )
    
    FP <- sum(
      predicted == 1 &
        actual == 0
    )
    
    FN <- sum(
      predicted == 0 &
        actual == 1
    )
    
    
    sensitivity <- ifelse(
      TP + FN == 0,
      NA,
      TP / (TP + FN)
    )
    
    
    specificity <- ifelse(
      TN + FP == 0,
      NA,
      TN / (TN + FP)
    )
    
    
    precision <- ifelse(
      TP + FP == 0,
      NA,
      TP / (TP + FP)
    )
    
    
    f1 <- ifelse(
      
      is.na(precision) |
        is.na(sensitivity) |
        precision + sensitivity == 0,
      
      NA,
      
      2 *
        precision *
        sensitivity /
        (
          precision +
            sensitivity
        )
    )
    
    
    balanced_accuracy <- (
      sensitivity +
        specificity
    ) / 2
    
    
    youden_j <-
      sensitivity +
      specificity -
      1
    
    
    results <- rbind(
      
      results,
      
      data.frame(
        
        Threshold = t,
        
        Sensitivity =
          sensitivity,
        
        Specificity =
          specificity,
        
        Precision =
          precision,
        
        F1 = f1,
        
        Balanced_Accuracy =
          balanced_accuracy,
        
        Youden_J =
          youden_j
      )
    )
  }
  
  
  return(
    results
  )
}


# ============================================================
# 24. THRESHOLD SELECTION USING OOF PREDICTIONS
# ============================================================

threshold_log <- evaluate_thresholds(
  log_oof_prob,
  y_train
)


threshold_nb <- evaluate_thresholds(
  nb_oof_prob,
  y_train
)


threshold_weighted <- evaluate_thresholds(
  weighted_oof_prob,
  y_train
)


threshold_smote <- evaluate_thresholds(
  smote_oof_prob,
  y_train
)


threshold_rf <- evaluate_thresholds(
  rf_oof_prob,
  y_train
)


threshold_xgb <- evaluate_thresholds(
  xgb_oof_prob,
  y_train
)


# ------------------------------------------------------------
# Select threshold with maximum Youden's J
# ------------------------------------------------------------

best_threshold_log <- threshold_log$Threshold[
  which.max(
    threshold_log$Youden_J
  )
]


best_threshold_nb <- threshold_nb$Threshold[
  which.max(
    threshold_nb$Youden_J
  )
]


best_threshold_weighted <- threshold_weighted$Threshold[
  which.max(
    threshold_weighted$Youden_J
  )
]


best_threshold_smote <- threshold_smote$Threshold[
  which.max(
    threshold_smote$Youden_J
  )
]


best_threshold_rf <- threshold_rf$Threshold[
  which.max(
    threshold_rf$Youden_J
  )
]


best_threshold_xgb <- threshold_xgb$Threshold[
  which.max(
    threshold_xgb$Youden_J
  )
]


selected_thresholds <- data.frame(
  
  Model = c(
    "Logistic Regression",
    "Naive Bayes",
    "Weighted Logistic",
    "SMOTE Logistic",
    "Random Forest",
    "XGBoost"
  ),
  
  Threshold = c(
    best_threshold_log,
    best_threshold_nb,
    best_threshold_weighted,
    best_threshold_smote,
    best_threshold_rf,
    best_threshold_xgb
  )
)


selected_thresholds


# ============================================================
# 25. APPLY LOCKED THRESHOLDS TO TEST SET
# ============================================================

log_pred <- ifelse(
  log_prob >= best_threshold_log,
  "Stroke",
  "No Stroke"
)


nb_pred <- ifelse(
  nb_prob >= best_threshold_nb,
  "Stroke",
  "No Stroke"
)


weighted_pred <- ifelse(
  weighted_prob >= best_threshold_weighted,
  "Stroke",
  "No Stroke"
)
# Convert predictions to factor with SAME levels as actual outcome
weighted_pred <- factor(
  weighted_pred,
  levels = c(
    "No Stroke",
    "Stroke"
  )
)


levels(weighted_pred)
levels(test$stroke)


smote_pred <- ifelse(
  smote_prob >= best_threshold_smote,
  "Stroke",
  "No Stroke"
)


rf_pred <- ifelse(
  rf_prob >= best_threshold_rf,
  "Stroke",
  "No Stroke"
)


xgb_pred <- ifelse(
  xgb_prob >= best_threshold_xgb,
  "Stroke",
  "No Stroke"
)


prediction_levels <- c(
  "No Stroke",
  "Stroke"
)


log_pred <- factor(
  log_pred,
  levels = prediction_levels
)


nb_pred <- factor(
  nb_pred,
  levels = prediction_levels
)


weighted_pred <- factor(
  weighted_pred,
  levels = prediction_levels
)


smote_pred <- factor(
  smote_pred,
  levels = prediction_levels
)


rf_pred <- factor(
  rf_pred,
  levels = prediction_levels
)


xgb_pred <- factor(
  xgb_pred,
  levels = prediction_levels
)


# ============================================================
# 26. CONFUSION MATRICES
# ============================================================

log_cm <- confusionMatrix(
  log_pred,
  test$stroke,
  positive = "Stroke"
)


nb_cm <- confusionMatrix(
  nb_pred,
  test$stroke,
  positive = "Stroke"
)


weighted_cm <- confusionMatrix(
  weighted_pred,
  test$stroke,
  positive = "Stroke"
)

weighted_cm


smote_cm <- confusionMatrix(
  smote_pred,
  test$stroke,
  positive = "Stroke"
)


rf_cm <- confusionMatrix(
  rf_pred,
  test$stroke,
  positive = "Stroke"
)


xgb_cm <- confusionMatrix(
  xgb_pred,
  test$stroke,
  positive = "Stroke"
)


log_cm
nb_cm
weighted_cm
smote_cm
rf_cm
xgb_cm


# ============================================================
# 27. ROC-AUC
# ============================================================

roc_log <- roc(
  y_test,
  log_prob,
  quiet = TRUE
)


roc_nb <- roc(
  y_test,
  nb_prob,
  quiet = TRUE
)


roc_weighted <- roc(
  y_test,
  weighted_prob,
  quiet = TRUE
)


roc_smote <- roc(
  y_test,
  smote_prob,
  quiet = TRUE
)


roc_rf <- roc(
  y_test,
  rf_prob,
  quiet = TRUE
)


roc_xgb <- roc(
  y_test,
  xgb_prob,
  quiet = TRUE
)


auc(roc_log)
auc(roc_nb)
auc(roc_weighted)
auc(roc_smote)
auc(roc_rf)
auc(roc_xgb)


# ============================================================
# 28. PR-AUC FUNCTION
# ============================================================

calculate_pr_auc <- function(
    probabilities,
    actual
) {
  
  result <- pr.curve(
    
    scores.class0 =
      probabilities[
        actual == 1
      ],
    
    scores.class1 =
      probabilities[
        actual == 0
      ],
    
    curve = TRUE
  )
  
  
  return(
    result$auc.integral
  )
}


# ============================================================
# 29. TEST PR-AUC
# ============================================================

pr_log <- calculate_pr_auc(
  log_prob,
  y_test
)


pr_nb <- calculate_pr_auc(
  nb_prob,
  y_test
)


pr_weighted <- calculate_pr_auc(
  weighted_prob,
  y_test
)


pr_smote <- calculate_pr_auc(
  smote_prob,
  y_test
)


pr_rf <- calculate_pr_auc(
  rf_prob,
  y_test
)


pr_xgb <- calculate_pr_auc(
  xgb_prob,
  y_test
)


pr_log
pr_nb
pr_weighted
pr_smote
pr_rf
pr_xgb


# ============================================================
# 30. METRIC EXTRACTION FUNCTION
# ============================================================

extract_metrics <- function(
    cm,
    roc_result,
    pr_auc
) {
  
  data.frame(
    
    Sensitivity = as.numeric(
      cm$byClass[
        "Sensitivity"
      ]
    ),
    
    Specificity = as.numeric(
      cm$byClass[
        "Specificity"
      ]
    ),
    
    Precision = as.numeric(
      cm$byClass[
        "Pos Pred Value"
      ]
    ),
    
    F1 = as.numeric(
      cm$byClass[
        "F1"
      ]
    ),
    
    ROC_AUC = as.numeric(
      auc(
        roc_result
      )
    ),
    
    PR_AUC = as.numeric(
      pr_auc
    )
  )
}


# ============================================================
# 31. FINAL TEST-SET MODEL COMPARISON
# ============================================================

model_comparison <- bind_rows(
  
  Logistic_Regression =
    extract_metrics(
      log_cm,
      roc_log,
      pr_log
    ),
  
  Naive_Bayes =
    extract_metrics(
      nb_cm,
      roc_nb,
      pr_nb
    ),
  
  Weighted_Logistic =
    extract_metrics(
      weighted_cm,
      roc_weighted,
      pr_weighted
    ),
  
  SMOTE_Logistic =
    extract_metrics(
      smote_cm,
      roc_smote,
      pr_smote
    ),
  
  Random_Forest =
    extract_metrics(
      rf_cm,
      roc_rf,
      pr_rf
    ),
  
  XGBoost =
    extract_metrics(
      xgb_cm,
      roc_xgb,
      pr_xgb
    ),
  
  .id = "Model"
)


model_comparison$Threshold <- c(
  best_threshold_log,
  best_threshold_nb,
  best_threshold_weighted,
  best_threshold_smote,
  best_threshold_rf,
  best_threshold_xgb
)


model_comparison <- model_comparison %>%
  
  select(
    Model,
    Threshold,
    Sensitivity,
    Specificity,
    Precision,
    F1,
    ROC_AUC,
    PR_AUC
  ) %>%
  
  mutate(
    
    across(
      where(is.numeric),
      ~ round(
        .x,
        3
      )
    )
  )


model_comparison


# ============================================================
# 32. OOF ROC-AUC FOR ALL MODELS
# ============================================================

oof_log_roc <- as.numeric(
  auc(
    roc(
      y_train,
      log_oof_prob,
      quiet = TRUE
    )
  )
)


oof_nb_roc <- as.numeric(
  auc(
    roc(
      y_train,
      nb_oof_prob,
      quiet = TRUE
    )
  )
)


oof_weighted_roc <- as.numeric(
  auc(
    roc(
      y_train,
      weighted_oof_prob,
      quiet = TRUE
    )
  )
)


oof_smote_roc <- as.numeric(
  auc(
    roc(
      y_train,
      smote_oof_prob,
      quiet = TRUE
    )
  )
)


oof_rf_roc <- as.numeric(
  auc(
    roc(
      y_train,
      rf_oof_prob,
      quiet = TRUE
    )
  )
)


oof_xgb_roc <- as.numeric(
  auc(
    roc(
      y_train,
      xgb_oof_prob,
      quiet = TRUE
    )
  )
)


# ============================================================
# 33. OOF PR-AUC FOR ALL MODELS
# ============================================================

oof_log_pr <- calculate_pr_auc(
  log_oof_prob,
  y_train
)


oof_nb_pr <- calculate_pr_auc(
  nb_oof_prob,
  y_train
)


oof_weighted_pr <- calculate_pr_auc(
  weighted_oof_prob,
  y_train
)


oof_smote_pr <- calculate_pr_auc(
  smote_oof_prob,
  y_train
)


oof_rf_pr <- calculate_pr_auc(
  rf_oof_prob,
  y_train
)


oof_xgb_pr <- calculate_pr_auc(
  xgb_oof_prob,
  y_train
)


# ============================================================
# 34. GENERALIZATION COMPARISON
# ============================================================

generalization_comparison <- data.frame(
  
  Model = c(
    "Logistic Regression",
    "Naive Bayes",
    "Weighted Logistic",
    "SMOTE Logistic",
    "Random Forest",
    "XGBoost"
  ),
  
  OOF_ROC_AUC = c(
    oof_log_roc,
    oof_nb_roc,
    oof_weighted_roc,
    oof_smote_roc,
    oof_rf_roc,
    oof_xgb_roc
  ),
  
  Test_ROC_AUC = c(
    as.numeric(
      auc(roc_log)
    ),
    as.numeric(
      auc(roc_nb)
    ),
    as.numeric(
      auc(roc_weighted)
    ),
    as.numeric(
      auc(roc_smote)
    ),
    as.numeric(
      auc(roc_rf)
    ),
    as.numeric(
      auc(roc_xgb)
    )
  ),
  
  OOF_PR_AUC = c(
    oof_log_pr,
    oof_nb_pr,
    oof_weighted_pr,
    oof_smote_pr,
    oof_rf_pr,
    oof_xgb_pr
  ),
  
  Test_PR_AUC = c(
    pr_log,
    pr_nb,
    pr_weighted,
    pr_smote,
    pr_rf,
    pr_xgb
  )
)


generalization_comparison <-
  generalization_comparison %>%
  
  mutate(
    
    ROC_Gap =
      OOF_ROC_AUC -
      Test_ROC_AUC,
    
    PR_Gap =
      OOF_PR_AUC -
      Test_PR_AUC
  ) %>%
  
  mutate(
    
    across(
      where(is.numeric),
      ~ round(
        .x,
        3
      )
    )
  )


generalization_comparison


# ============================================================
# 35. FINAL OUTPUTS
# ============================================================

cat(
  "\n============================================\n"
)

cat(
  "SELECTED THRESHOLDS\n"
)

cat(
  "============================================\n"
)

print(
  selected_thresholds
)


cat(
  "\n============================================\n"
)

cat(
  "FINAL TEST-SET MODEL COMPARISON\n"
)

cat(
  "============================================\n"
)

print(
  model_comparison
)


cat(
  "\n============================================\n"
)

cat(
  "OOF VS TEST GENERALIZATION CHECK\n"
)

cat(
  "============================================\n"
)

print(
  generalization_comparison
)
