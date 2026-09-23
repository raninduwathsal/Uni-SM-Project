# ============================================================
# IT3081 Statistical Modelling - Group Assignment
# Script: 00_generate_synthetic_data.R
# Purpose: Generate realistic 90-day multi-period transaction data
#          preserving BladeGen Tech empirical distributions (Vectorized)
# ============================================================

set.seed(42)

cat("====================================================\n")
cat(" Generating 90-Day Synthetic Restaurant Dataset\n")
cat("====================================================\n\n")

# Load reference raw dataset to extract empirical item catalogue and rates
raw_path <- "../Courseweb Documents/SampleDataset/temp_org_all_tables_rows.csv"
if (!file.exists(raw_path)) {
  raw_path <- "Courseweb Documents/SampleDataset/temp_org_all_tables_rows.csv"
}

df_ref <- read.csv(raw_path, stringsAsFactors = FALSE)

# Empirical item profiles
item_profiles <- unique(df_ref[, c("ItemName", "MainCategory", "SubCategory", "CoffeeOrNonCoffee", "SubMenu")])
item_profiles <- item_profiles[item_profiles$ItemName != "" & !is.na(item_profiles$ItemName), ]
rates_summary <- aggregate(AdjustedRate ~ ItemName, data = df_ref, FUN = function(x) median(x, na.rm = TRUE))
item_profiles <- merge(item_profiles, rates_summary, by = "ItemName", all.x = TRUE)
item_profiles$AdjustedRate[is.na(item_profiles$AdjustedRate)] <- 1200

# Top outlets and empirical probabilities
outlet_counts <- table(df_ref$Outlet)
outlets <- names(outlet_counts)
outlet_probs <- as.numeric(outlet_counts) / sum(outlet_counts)

# Simulation parameters: 90 days (2026-01-01 to 2026-03-31)
date_seq <- seq(as.Date("2026-01-01"), as.Date("2026-03-31"), by = "day")

# Estimate total orders: ~200 orders per day * 90 days = ~18,000 orders (~35,000 items)
orders_per_day <- sapply(date_seq, function(d) {
  day_name <- weekdays(d)
  mult <- if (day_name %in% c("Saturday", "Sunday")) 1.35 else if (day_name == "Friday") 1.20 else 1.0
  round(runif(1, 160, 240) * mult)
})

total_orders <- sum(orders_per_day)
cat(sprintf("Simulating %d orders across %d days...\n", total_orders, length(date_seq)))

# Repeat dates for each order
order_dates <- rep(date_seq, times = orders_per_day)
order_days <- weekdays(order_dates)
order_months <- months(order_dates)
order_ids <- sprintf("ORD-%06d", 10000 + (1:total_orders))

# Order outlets
order_outlets <- sample(outlets, total_orders, replace = TRUE, prob = outlet_probs)

# Foreign vs Local
is_foreign <- runif(total_orders) < 0.15
order_cust_types <- ifelse(is_foreign, "Foreign", "Local")

# Loyalty pool
loyalty_pool <- paste0("9", sample(10000000:99999999, 1500, replace = FALSE))
cust_names_map <- paste("Customer", sprintf("%04d", 1:1500))

# Loyalty status (locals can be loyalty members)
has_loyalty <- (!is_foreign) & (runif(total_orders) < 0.45)
assigned_loyalty_idx <- sample(1:length(loyalty_pool), total_orders, replace = TRUE)
order_loyalty_num <- ifelse(has_loyalty, loyalty_pool[assigned_loyalty_idx], "NA")
order_cust_name <- ifelse(has_loyalty, cust_names_map[assigned_loyalty_idx], "NA")
order_age <- rep(NA_integer_, total_orders)
order_age[has_loyalty] <- sample(18:68, sum(has_loyalty), replace = TRUE)
non_loy_has_age <- (!has_loyalty) & (runif(total_orders) < 0.25)
order_age[non_loy_has_age] <- sample(20:65, sum(non_loy_has_age), replace = TRUE)

order_dob <- rep("NA", total_orders)
has_age_idx <- which(!is.na(order_age))
order_dob[has_age_idx] <- sprintf("%04d 0:00-%02d-%02d", 
                                  2026 - order_age[has_age_idx], 
                                  sample(1:12, length(has_age_idx), replace = TRUE),
                                  sample(1:28, length(has_age_idx), replace = TRUE))

# Time of day
tods <- sample(c("Morning", "Afternoon", "Evening", "Night"), total_orders, replace = TRUE, prob = c(0.35, 0.30, 0.25, 0.10))

hours <- rep(8, total_orders)
morn_idx <- which(tods == "Morning")
aft_idx <- which(tods == "Afternoon")
eve_idx <- which(tods == "Evening")
nig_idx <- which(tods == "Night")

hours[morn_idx] <- sample(7:11, length(morn_idx), replace = TRUE)
hours[aft_idx] <- sample(12:16, length(aft_idx), replace = TRUE)
hours[eve_idx] <- sample(17:20, length(eve_idx), replace = TRUE)
hours[nig_idx] <- sample(21:23, length(nig_idx), replace = TRUE)

mins <- sample(0:59, total_orders, replace = TRUE)
secs <- sample(0:59, total_orders, replace = TRUE)
order_times <- sprintf("%dH %dM %dS", hours, mins, secs)

# Time ranges
time_ranges <- ifelse(hours < 12, 
                      sprintf("%dAM - %dAM", hours, hours + 1),
                      ifelse(hours == 12, "12PM - 1PM", sprintf("%dPM - %dPM", hours - 12, hours - 11)))

# Order types
order_types <- rep("Dine-In", total_orders)
order_types[morn_idx] <- sample(c("Dine-In", "Takeaway"), length(morn_idx), replace = TRUE, prob = c(0.4, 0.6))
order_types[-morn_idx] <- sample(c("Dine-In", "Takeaway"), total_orders - length(morn_idx), replace = TRUE, prob = c(0.7, 0.3))

# Payment methods
pay_methods <- rep("VISA", total_orders)
for_idx <- which(is_foreign)
loc_idx <- which(!is_foreign)

pay_methods[for_idx] <- sample(c("VISA", "MASTER", "AMEX", "CASH"), length(for_idx), replace = TRUE, prob = c(0.50, 0.30, 0.15, 0.05))
pay_methods[loc_idx] <- sample(c("VISA", "CASH", "MASTER", "UBER EATS", "PICK ME", "MINTPAY", "AMEX"), length(loc_idx), replace = TRUE, prob = c(0.42, 0.26, 0.13, 0.10, 0.04, 0.03, 0.02))

# Number of items per order (1, 2, or 3)
items_per_order <- sample(1:3, total_orders, replace = TRUE, prob = c(0.65, 0.25, 0.10))
total_rows <- sum(items_per_order)

cat(sprintf("Expanding to %d item rows...\n", total_rows))

# Expand order-level variables to item level
exp_order_ids <- rep(order_ids, times = items_per_order)
exp_order_dates <- rep(as.character(order_dates), times = items_per_order)
exp_order_times <- rep(order_times, times = items_per_order)
exp_order_outlets <- rep(order_outlets, times = items_per_order)
exp_order_types <- rep(order_types, times = items_per_order)
exp_order_cust_types <- rep(order_cust_types, times = items_per_order)
exp_order_loyalty <- rep(order_loyalty_num, times = items_per_order)
exp_order_pay_methods <- rep(pay_methods, times = items_per_order)
exp_order_days <- rep(order_days, times = items_per_order)
exp_order_months <- rep(order_months, times = items_per_order)
exp_order_tods <- rep(tods, times = items_per_order)
exp_order_timeranges <- rep(time_ranges, times = items_per_order)
exp_order_names <- rep(order_cust_name, times = items_per_order)
exp_order_ages <- rep(order_age, times = items_per_order)
exp_order_dobs <- rep(order_dob, times = items_per_order)
exp_has_loyalty <- rep(has_loyalty, times = items_per_order)

# Sample menu items conditioned on TOD
morn_rows <- which(exp_order_tods == "Morning")
aft_rows <- which(exp_order_tods == "Afternoon")
eve_rows <- which(exp_order_tods == "Evening")
nig_rows <- which(exp_order_tods == "Night")

cats <- rep("Beverage", total_rows)
cats[morn_rows] <- sample(c("Beverage", "Food", "Merchandizing", "Deals"), length(morn_rows), replace = TRUE, prob = c(0.65, 0.28, 0.04, 0.03))
cats[aft_rows] <- sample(c("Beverage", "Food", "Merchandizing", "Deals"), length(aft_rows), replace = TRUE, prob = c(0.45, 0.45, 0.05, 0.05))
cats[eve_rows] <- sample(c("Beverage", "Food", "Merchandizing", "Deals"), length(eve_rows), replace = TRUE, prob = c(0.50, 0.40, 0.04, 0.06))
cats[nig_rows] <- sample(c("Beverage", "Food", "Merchandizing", "Deals"), length(nig_rows), replace = TRUE, prob = c(0.55, 0.35, 0.05, 0.05))

# Pick item profile matching category
bev_pool <- item_profiles[item_profiles$MainCategory == "Beverage", ]
food_pool <- item_profiles[item_profiles$MainCategory == "Food", ]
merch_pool <- item_profiles[item_profiles$MainCategory == "Merchandizing", ]
deal_pool <- item_profiles[item_profiles$MainCategory == "Deals", ]
if (nrow(deal_pool) == 0) deal_pool <- food_pool

item_indices <- rep(1, total_rows)
bev_idx <- which(cats == "Beverage")
food_idx <- which(cats == "Food")
merch_idx <- which(cats == "Merchandizing")
deal_idx <- which(cats == "Deals")

# Map selected item
res_itemname <- character(total_rows)
res_subcat <- character(total_rows)
res_coffee <- character(total_rows)
res_submenu <- character(total_rows)
res_rate <- numeric(total_rows)

set_items <- function(rows, pool) {
  pick <- sample(1:nrow(pool), length(rows), replace = TRUE)
  res_itemname[rows] <<- pool$ItemName[pick]
  res_subcat[rows] <<- pool$SubCategory[pick]
  res_coffee[rows] <<- pool$CoffeeOrNonCoffee[pick]
  res_submenu[rows] <<- pool$SubMenu[pick]
  res_rate[rows] <<- pool$AdjustedRate[pick]
}

set_items(bev_idx, bev_pool)
set_items(food_idx, food_pool)
set_items(merch_idx, merch_pool)
set_items(deal_idx, deal_pool)

# Add realistic variance to prices
adj_rates <- round(res_rate * rnorm(total_rows, mean = 1.0, sd = 0.03), 2)
qtys <- sample(1:3, total_rows, replace = TRUE, prob = c(0.80, 0.16, 0.04))

# Discounts
has_disc <- (exp_has_loyalty & (runif(total_rows) < 0.25)) | (cats == "Deals")
discounts <- round(ifelse(has_disc, adj_rates * qtys * runif(total_rows, 0.08, 0.18), 0), 2)

# Service charge (Dine-in only)
svc_charges <- round(ifelse(exp_order_types == "Dine-In", (adj_rates * qtys - discounts) * 0.10, 0), 2)

df_synthetic <- data.frame(
  Outlet = exp_order_outlets,
  OrderNo = exp_order_ids,
  OrderDate = exp_order_dates,
  OrderTime = exp_order_times,
  ItemName = res_itemname,
  Qty1 = qtys,
  AdjustedRate = adj_rates,
  Discount = discounts,
  ServiceCharge = svc_charges,
  OrderType = exp_order_types,
  CustomerLoyaltyNumber = exp_order_loyalty,
  PaymentMethod = exp_order_pay_methods,
  CustomerType = exp_order_cust_types,
  OutletType = "Regular",
  TimeRange = exp_order_timeranges,
  Day = exp_order_days,
  Month = exp_order_months,
  TimeOfTheDay = exp_order_tods,
  MainCategory = cats,
  SubCategory = res_subcat,
  CoffeeOrNonCoffee = res_coffee,
  SubMenu = res_submenu,
  Name = exp_order_names,
  AddressLine1 = "NA",
  DOB = exp_order_dobs,
  `Contact No` = NA,
  Age = exp_order_ages,
  `Registered Outlet` = NA,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

out_file <- "../Courseweb Documents/SampleDataset/synthetic_restaurant_transactions.csv"
if (!dir.exists("../Courseweb Documents/SampleDataset")) {
  out_file <- "Courseweb Documents/SampleDataset/synthetic_restaurant_transactions.csv"
}

write.csv(df_synthetic, out_file, row.names = FALSE, na = "NA")

cat(sprintf("✔ Successfully generated %d rows across %d days (%s to %s)\n",
            nrow(df_synthetic), length(date_seq), min(date_seq), max(date_seq)))
cat(sprintf("✔ Output saved to %s\n", out_file))
