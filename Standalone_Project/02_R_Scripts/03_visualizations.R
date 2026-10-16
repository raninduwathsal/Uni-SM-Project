# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Task 3: Visual Exploratory Data Analysis
# Script: 03_visualizations.R
# Outputs: Presentation-ready figures in outputs/figures/
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(scales)
})

cat("====================================================\n")
cat(" Task 3: Generating High-Resolution Visualizations\n")
cat("====================================================\n\n")

# --- 1. LOAD DATA ---
data_path <- "outputs/df_clean.csv"
if (!file.exists(data_path)) {
  data_path <- "R Scripts/outputs/df_clean.csv"
}

df <- read_csv(data_path, show_col_types = FALSE)

fig_dir <- "outputs/figures"
if (!dir.exists(fig_dir)) {
  dir.create(fig_dir, recursive = TRUE)
}

# Define modern corporate theme
theme_modern <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14, color = "#1a202c", margin = margin(b = 6)),
      plot.subtitle = element_text(size = 11, color = "#4a5568", margin = margin(b = 10)),
      plot.caption = element_text(size = 9, color = "#718096", margin = margin(t = 8)),
      axis.title = element_text(face = "bold", size = 10, color = "#2d3748"),
      axis.text = element_text(color = "#4a5568"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#e2e8f0", linewidth = 0.5),
      legend.position = "bottom",
      legend.title = element_text(face = "bold", size = 10),
      plot.background = element_rect(fill = "#ffffff", color = NA),
      panel.background = element_rect(fill = "#ffffff", color = NA)
    )
}

# --- FIG 1: CATEGORY REVENUE & VOLUME BREAKDOWN ---
cat("Generating Fig 1: Category Revenue Breakdown...\n")
p1_data <- df %>%
  group_by(MainCategory) %>%
  summarise(
    Total_Revenue = sum(Revenue, na.rm = TRUE) / 1e6, # in Millions
    Total_Count = n(),
    .groups = "drop"
  )

p1 <- ggplot(p1_data, aes(x = reorder(MainCategory, Total_Revenue), y = Total_Revenue, fill = MainCategory)) +
  geom_col(width = 0.65, alpha = 0.9, show.legend = FALSE) +
  geom_text(aes(label = sprintf("LKR %.2fM\n(%s orders)", Total_Revenue, comma(Total_Count))),
            hjust = -0.1, size = 3.8, fontface = "bold", color = "#2d3748") +
  coord_flip() +
  scale_y_continuous(labels = dollar_format(prefix = "LKR ", suffix = "M"), limits = c(0, max(p1_data$Total_Revenue) * 1.35)) +
  scale_fill_manual(values = c("Beverage" = "#2b6cb0", "Food" = "#dd6b20", "Merchandizing" = "#38a169", "Deals" = "#805ad5")) +
  labs(
    title = "Total Sales Revenue by Menu Category",
    subtitle = "Beverages generate over 54% of overall revenue, followed closely by Food items",
    x = "Menu Category",
    y = "Total Revenue (LKR Millions)",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 3 EDA"
  ) +
  theme_modern()

ggsave(file.path(fig_dir, "fig1_category_revenue.png"), p1, width = 9, height = 5.5, dpi = 300)

# --- FIG 2: TOP 12 OUTLETS BY REVENUE ---
cat("Generating Fig 2: Outlet Performance...\n")
p2_data <- df %>%
  group_by(Outlet) %>%
  summarise(
    Total_Revenue = sum(Revenue, na.rm = TRUE) / 1e3, # in Thousands
    Mean_Spend = mean(Revenue, na.rm = TRUE),
    Transactions = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(Total_Revenue)) %>%
  slice_head(n = 12)

p2 <- ggplot(p2_data, aes(x = reorder(Outlet, Total_Revenue), y = Total_Revenue)) +
  geom_col(fill = "#3182ce", width = 0.7, alpha = 0.85) +
  geom_point(aes(y = Mean_Spend), color = "#e53e3e", size = 2.5) +
  geom_line(aes(y = Mean_Spend, group = 1), color = "#e53e3e", linetype = "dashed", linewidth = 0.8) +
  coord_flip() +
  scale_y_continuous(
    name = "Total Revenue (LKR '000s)",
    labels = comma,
    sec.axis = sec_axis(~ ., name = "Mean Revenue per Item (LKR)", labels = comma)
  ) +
  labs(
    title = "Top 12 Performing Outlets: Total Revenue vs. Average Item Spend",
    subtitle = "Blue bars show total revenue (LKR '000s); red points and dashed line indicate mean transaction spend",
    x = "Store Outlet",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 3 EDA"
  ) +
  theme_modern()

ggsave(file.path(fig_dir, "fig2_outlet_performance.png"), p2, width = 10, height = 6.5, dpi = 300)

# --- FIG 3: HOURLY & WEEKLY TRANSACTION DENSITY ---
cat("Generating Fig 3: Hourly Traffic & Seasonality...\n")
# Extract integer hour from OrderTime
df_hour <- df %>%
  mutate(
    Hour = as.numeric(str_extract(OrderTime, "^[0-9]+")),
    DayType = ifelse(Day %in% c("Saturday", "Sunday"), "Weekend", "Weekday")
  ) %>%
  filter(!is.na(Hour))

p3 <- ggplot(df_hour, aes(x = Hour, fill = DayType)) +
  geom_density(alpha = 0.45, adjust = 1.2) +
  scale_x_continuous(breaks = seq(7, 23, by = 2), labels = function(x) paste0(x, ":00")) +
  scale_fill_manual(values = c("Weekday" = "#3182ce", "Weekend" = "#d69e2e")) +
  labs(
    title = "Customer Transaction Density Across the Day",
    subtitle = "Distinct morning coffee peak (8:00–10:00 AM) and secondary afternoon/evening surge",
    x = "Hour of Day (24-Hour Format)",
    y = "Transaction Density",
    fill = "Day Type",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 3 EDA"
  ) +
  theme_modern()

ggsave(file.path(fig_dir, "fig3_hourly_weekly_traffic.png"), p3, width = 9, height = 5.5, dpi = 300)

# --- FIG 4: LOCAL VS FOREIGN CUSTOMER SPEND ---
cat("Generating Fig 4: Customer Spend Distribution...\n")
p4 <- ggplot(df, aes(x = CustomerType, y = Revenue, fill = CustomerType)) +
  geom_violin(alpha = 0.4, trim = FALSE, draw_quantiles = c(0.25, 0.5, 0.75)) +
  geom_boxplot(width = 0.18, color = "#2d3748", alpha = 0.8, outlier.shape = 21, outlier.size = 1.2) +
  scale_fill_manual(values = c("Foreign" = "#9f7aea", "Local" = "#48bb78")) +
  scale_y_continuous(labels = dollar_format(prefix = "LKR ", suffix = ""), limits = c(500, 2900)) +
  labs(
    title = "Transaction Spend Distribution: Local vs. Foreign Customers",
    subtitle = "Foreign tourists exhibit wider dispersion and higher mean ticket sizes across outlets",
    x = "Customer Type",
    y = "Item Revenue (LKR)",
    fill = "Customer Type",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 3 EDA"
  ) +
  theme_modern() +
  theme(legend.position = "none")

ggsave(file.path(fig_dir, "fig4_customer_type_spend.png"), p4, width = 8, height = 5.5, dpi = 300)

# --- FIG 5: PAYMENT METHOD PROPORTIONS ---
cat("Generating Fig 5: Payment Method Proportions...\n")
p5_data <- df %>%
  group_by(TimeOfTheDay, PaymentMethod) %>%
  summarise(Count = n(), .groups = "drop") %>%
  group_by(TimeOfTheDay) %>%
  mutate(Proportion = Count / sum(Count))

p5 <- ggplot(p5_data, aes(x = TimeOfTheDay, y = Proportion, fill = PaymentMethod)) +
  geom_col(position = "fill", width = 0.65, color = "white", linewidth = 0.3) +
  scale_y_continuous(labels = percent_format()) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Payment Method Share by Time of Day",
    subtitle = "VISA and Cash dominate across all periods, with Uber Eats surging during late afternoon and evening",
    x = "Time of Day",
    y = "Share of Transactions",
    fill = "Payment Method",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 3 EDA"
  ) +
  theme_modern()

ggsave(file.path(fig_dir, "fig5_payment_method_share.png"), p5, width = 9.5, height = 6, dpi = 300)

# --- FIG 6: LOYALTY CLUB IMPACT ---
cat("Generating Fig 6: Loyalty Club Comparison...\n")
p6_data <- df %>%
  group_by(IsLoyaltyMember, MainCategory) %>%
  summarise(
    Mean_Spend = mean(Revenue, na.rm = TRUE),
    Total_Orders = n(),
    .groups = "drop"
  )

p6 <- ggplot(p6_data, aes(x = MainCategory, y = Mean_Spend, fill = IsLoyaltyMember)) +
  geom_col(position = position_dodge(0.7), width = 0.6) +
  geom_text(aes(label = sprintf("LKR %.0f", Mean_Spend)),
            position = position_dodge(0.7), vjust = -0.4, size = 3.4, fontface = "bold") +
  scale_fill_manual(values = c("No" = "#a0aec0", "Yes" = "#3182ce")) +
  scale_y_continuous(labels = comma, limits = c(0, 1300)) +
  labs(
    title = "Average Spend by Category: Loyalty Members vs. Non-Members",
    subtitle = "Loyalty club members maintain consistent basket spend despite receiving loyalty discounts",
    x = "Menu Category",
    y = "Average Revenue per Item (LKR)",
    fill = "Loyalty Club Member?",
    caption = "BladeGen Tech F&B Analytics Pipeline | Task 3 EDA"
  ) +
  theme_modern()

ggsave(file.path(fig_dir, "fig6_loyalty_impact.png"), p6, width = 9, height = 5.5, dpi = 300)

cat("\n====================================================\n")
cat(" All 6 Figures Successfully Exported to outputs/figures/\n")
cat("====================================================\n")
