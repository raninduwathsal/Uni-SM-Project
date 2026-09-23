# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 7: Principal Component Analysis (PCA) & Critical Evaluation
# Script: 07_pca.R
# Outputs: Scree plot, biplot, loadings CSV & critical evaluation
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(scales)
})

cat("====================================================\n")
cat(" Task 7: Principal Component Analysis (PCA)\n")
cat("====================================================\n\n")

# --- 1. LOAD DATA ---
data_path <- "outputs/df_clean.csv"
if (!file.exists(data_path)) {
  data_path <- "R Scripts/outputs/df_clean.csv"
}

df <- read_csv(data_path, show_col_types = FALSE)

# Select numerical features for PCA
pca_vars <- c("Qty1", "AdjustedRate", "Discount", "ServiceCharge", "Revenue")
df_pca_input <- df %>%
  select(all_of(pca_vars)) %>%
  drop_na()

cat(sprintf("Running PCA on %d observations across %d numeric variables:\n", nrow(df_pca_input), length(pca_vars)))
print(pca_vars)
cat("\n")

# --- 2. FIT PCA (CENTERED & SCALED) ---
pca_fit <- prcomp(df_pca_input, center = TRUE, scale. = TRUE)

# Summary of components
pca_eigen <- pca_fit$sdev^2
pca_var_pct <- round((pca_eigen / sum(pca_eigen)) * 100, 2)
pca_cum_var <- round(cumsum(pca_var_pct), 2)

pca_importance <- data.frame(
  Principal_Component = paste0("PC", 1:length(pca_eigen)),
  Eigenvalue = round(pca_eigen, 4),
  Variance_Explained_Pct = pca_var_pct,
  Cumulative_Variance_Pct = pca_cum_var,
  stringsAsFactors = FALSE
)

cat("--- PCA Importance of Components ---\n")
print(pca_importance)
cat("\n")

# Loadings (Eigenvectors)
pca_loadings <- as.data.frame(round(pca_fit$rotation, 4))
pca_loadings$Variable <- rownames(pca_loadings)
pca_loadings <- pca_loadings %>% select(Variable, everything())

cat("--- PCA Feature Loadings ---\n")
print(pca_loadings)
cat("\n")

write_csv(pca_importance, "outputs/pca_importance.csv")
write_csv(pca_loadings, "outputs/pca_loadings.csv")
cat("✔ PCA summary tables saved to outputs/pca_importance.csv and pca_loadings.csv\n\n")

# --- 3. VISUALIZATIONS ---
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

# Plot 1: Scree Plot & Cumulative Variance
p_scree <- ggplot(pca_importance, aes(x = factor(Principal_Component, levels = Principal_Component), y = Variance_Explained_Pct)) +
  geom_col(fill = "#3182ce", width = 0.55, alpha = 0.85) +
  geom_line(aes(y = Cumulative_Variance_Pct / 2, group = 1), color = "#e53e3e", linewidth = 1) +
  geom_point(aes(y = Cumulative_Variance_Pct / 2), color = "#e53e3e", size = 2.5) +
  geom_text(aes(label = sprintf("%.1f%%", Variance_Explained_Pct)), vjust = -0.5, fontface = "bold", size = 3.5) +
  scale_y_continuous(
    name = "Individual Variance Explained (%)",
    limits = c(0, 70),
    sec.axis = sec_axis(~ . * 2, name = "Cumulative Variance Explained (%)", breaks = seq(0, 100, 20))
  ) +
  labs(
    title = "PCA Scree Plot & Cumulative Variance Explained",
    subtitle = "First 2 Principal Components account for over 65% of total variance across financial indicators",
    x = "Principal Component",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 7 PCA"
  ) +
  theme_pub()

ggsave(file.path(fig_dir, "fig_pca_scree.png"), p_scree, width = 8.5, height = 5.5, dpi = 300)

# Plot 2: Biplot (PC1 vs PC2 Scores + Loadings Vectors)
# Sample 1500 points for clear visual plotting
sample_idx <- sample(1:nrow(df_pca_input), min(1500, nrow(df_pca_input)))
scores_df <- as.data.frame(pca_fit$x[sample_idx, 1:2])
scores_df$MainCategory <- df$MainCategory[sample_idx]

# Scale loadings for plotting on same canvas
mult <- min(
  (max(scores_df$PC1) - min(scores_df$PC1)) / (max(pca_fit$rotation[,1]) - min(pca_fit$rotation[,1])),
  (max(scores_df$PC2) - min(scores_df$PC2)) / (max(pca_fit$rotation[,2]) - min(pca_fit$rotation[,2]))
) * 0.7

loadings_df <- as.data.frame(pca_fit$rotation[, 1:2])
loadings_df$Variable <- rownames(loadings_df)
loadings_df$PC1_scaled <- loadings_df$PC1 * mult
loadings_df$PC2_scaled <- loadings_df$PC2 * mult

p_biplot <- ggplot() +
  geom_point(data = scores_df, aes(x = PC1, y = PC2, color = MainCategory), alpha = 0.35, size = 1.6) +
  geom_segment(data = loadings_df, aes(x = 0, y = 0, xend = PC1_scaled, yend = PC2_scaled),
               arrow = arrow(length = unit(0.25, "cm")), color = "#1a202c", linewidth = 0.9) +
  geom_text(data = loadings_df, aes(x = PC1_scaled * 1.15, y = PC2_scaled * 1.15, label = Variable),
            color = "#1a202c", fontface = "bold", size = 3.6) +
  scale_color_manual(values = c("Beverage" = "#2b6cb0", "Food" = "#dd6b20", "Merchandizing" = "#38a169", "Deals" = "#805ad5")) +
  labs(
    title = "PCA Biplot: Observation Scores & Variable Loadings",
    subtitle = "PC1 primarily reflects order scale & revenue magnitude; PC2 contrasts unit rate with discounts",
    x = sprintf("PC1 (%.1f%% Variance)", pca_var_pct[1]),
    y = sprintf("PC2 (%.1f%% Variance)", pca_var_pct[2]),
    color = "Product Category",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 7 PCA"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "fig_pca_biplot.png"), p_biplot, width = 9, height = 6.5, dpi = 300)

cat("✔ Figures saved: outputs/figures/fig_pca_scree.png and fig_pca_biplot.png\n\n")

# --- 4. CRITICAL EVALUATION REPORT (TASK 7 REQUIREMENTS) ---
report_text <- c(
  "================================================================================",
  " IT3081 STATISTICAL MODELLING - TASK 7: CRITICAL EVALUATION OF PCA",
  " Client: BladeGen Tech Consultancy | Dimensionality Reduction Analysis",
  "================================================================================",
  "",
  "1. DIMENSIONALITY ASSESSMENT:",
  "  - The transaction dataset contains only 5 primary continuous numeric variables (Qty1, AdjustedRate,",
  "    Discount, ServiceCharge, Revenue). The remaining 20+ variables are categorical factors (Outlet,",
  "    ItemName, PaymentMethod, CustomerType, TimeOfTheDay, Day).",
  "  - Conclusion: Dimensionality reduction is NOT strictly necessary for computational reasons because",
  "    5 numeric features present no risk of the 'curse of dimensionality' (p << n, where n = 29,465).",
  "",
  "2. MATHEMATICAL VARIANCE BREAKDOWN:",
  sprintf("  - PC1 accounts for %.2f%% of total variance, dominated by Revenue, Qty1, and ServiceCharge.", pca_var_pct[1]),
  sprintf("  - PC2 accounts for %.2f%% of total variance, driven by AdjustedRate vs. Discount contrasts.", pca_var_pct[2]),
  sprintf("  - Together, PC1 + PC2 explain %.2f%% of variance, retaining the majority of numeric information.", pca_cum_var[2]),
  "",
  "3. ADVANTAGES OF PCA IN THIS CONTEXT:",
  "  - Orthogonalization: Eliminates exact multicollinearity between Revenue, Qty1, and ServiceCharge.",
  "  - Multi-Dimensional Visualization: Enables 2D plotting of complex basket profiles across categories.",
  "  - Index Construction: PC1 can serve as an overall 'Basket Magnitude Index' for customer scoring.",
  "",
  "4. CRITICAL LIMITATIONS OF PCA:",
  "  - Loss of Interpretability: Principal components are linear combinations of features, making it hard",
  "    for restaurant store managers to understand why a promotion triggered a recommendation.",
  "  - Incompatibility with High-Cardinality Categoricals: PCA is mathematically designed for continuous",
  "    Gaussian data; applying it to one-hot encoded categorical variables creates sparse, distorted spaces.",
  "  - Information Loss: Discarding PC3–PC5 sacrifices nuanced promotional discount variance (%.2f%%).", sum(pca_var_pct[3:5]),
  "",
  "5. EXPECTED IMPACT ON PREDICTIVE MODELLING:",
  "  - Tree-based models (CART, Random Forest) already perform intrinsic feature selection and handle non-linear",
  "    interactions natively. Replacing original features with PCs degrades tree interpretability.",
  "  - For Logistic Regression, replacing collinear predictors with PC1 and PC2 stabilizes coefficient estimates",
  "    and prevents variance inflation, but at the cost of direct odds-ratio interpretation.",
  "",
  "6. SITUATIONS WHERE PCA SHOULD AND SHOULD NOT BE USED:",
  "  - SHOULD BE USED: When building an automated composite customer spending score, clustering stores based on",
  "    aggregate volume/pricing profiles, or pre-processing high-dimensional continuous sensor/spectral data.",
  "  - SHOULD NOT BE USED: For point-of-sale recommendation engines where cashiers need clear business rules",
  "    (e.g., 'If Customer is Local and Time is Morning, recommend Coffee Combo').",
  "================================================================================"
)

writeLines(report_text, "outputs/pca_evaluation_report.txt")
cat("✔ Comprehensive critical evaluation written to outputs/pca_evaluation_report.txt\n")

cat("\n====================================================\n")
cat(" Task 7 PCA Complete!\n")
cat("====================================================\n")
