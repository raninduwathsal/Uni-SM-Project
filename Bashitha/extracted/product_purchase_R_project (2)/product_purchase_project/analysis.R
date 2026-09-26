#!/usr/bin/env Rscript
# IT3081 Statistical Modelling: Product purchase prediction
# Terminal: Rscript analysis.R path/to/percustomertraindata.csv path/to/results
# RStudio: set working directory to the project folder, then Source this file.
# Uses base R only. Each row of the source is a purchased product line.
# Prediction unit: a customer's NEXT ORDER. Each order has up to 15 binary
# product outcomes. All predictive features come from EARLIER orders only.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  if (interactive()) {
    local_csv <- file.path(getwd(), "percustomertraindata.csv")
    args <- c(if (file.exists(local_csv)) local_csv else file.choose(), "results")
  } else {
    stop("Usage: Rscript analysis.R INPUT.csv [OUTPUT_DIRECTORY]", call. = FALSE)
  }
}
input_path <- args[[1L]]
output_dir <- if (length(args) >= 2L) args[[2L]] else "results"
if (!file.exists(input_path)) stop("CSV file not found: ", input_path, call. = FALSE)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
options(stringsAsFactors = FALSE)

save_csv <- function(x, name) {
  write.csv(x, file.path(output_dir, name), row.names = FALSE, na = "")
}
log_line <- function(...) cat(..., "\n", file = file.path(output_dir, "analysis_log.txt"), append = TRUE)
if (file.exists(file.path(output_dir, "analysis_log.txt"))) {
  file.remove(file.path(output_dir, "analysis_log.txt"))
}

# MEMBER 2 — source audit, preparation, descriptive analysis and inference.
raw <- read.csv(input_path, check.names = FALSE, na.strings = c("", "NA"))
required <- c("OrderNo", "OrderDate", "OrderTime", "CustomerLoyaltyNumber",
              "ItemName", "Qty1", "AdjustedRate", "Discount", "OrderType",
              "PaymentMethod", "Age", "MainCategory", "SubCategory")
missing_columns <- setdiff(required, names(raw))
if (length(missing_columns)) stop("Missing columns: ", paste(missing_columns, collapse = ", "))

raw$OrderNo <- trimws(as.character(raw$OrderNo))
raw$ItemName <- trimws(as.character(raw$ItemName))
raw$customer <- sub("\\.0$", "", as.character(raw$CustomerLoyaltyNumber))
raw$date <- as.Date(raw$OrderDate)
if (anyNA(raw$date) || anyNA(raw$customer) || anyNA(raw$OrderNo) ||
    anyNA(raw$ItemName) || any(raw$ItemName == "")) {
  stop("Order date, number, customer or item is invalid/missing. Inspect the source.")
}
if (anyNA(raw$Qty1) || any(raw$Qty1 <= 0)) stop("Qty1 must be positive and nonmissing")
products <- sort(unique(raw$ItemName))
customers <- sort(unique(raw$customer))
if (length(products) < 2L) stop("At least two distinct products are needed")

# Check whether supposed order-level fields actually remain constant per order.
order_rows <- split(seq_len(nrow(raw)), raw$OrderNo)
order_ids <- names(order_rows)
none_or_one <- function(x) length(unique(x[!is.na(x)])) <= 1L
conflict_count <- function(column) sum(!vapply(order_rows, function(i) none_or_one(raw[[column]][i]), logical(1)))
source_audit <- data.frame(
  measure = c("item_lines", "orders", "customers", "products", "first_date", "last_date",
              "exact_duplicate_rows", "orders_with_multiple_dates",
              "orders_with_multiple_customers", "orders_with_multiple_order_types",
              "orders_with_multiple_payment_methods", "missing_address",
              "missing_contact", "missing_registered_outlet"),
  value = as.character(c(nrow(raw), length(order_rows), length(customers),
                         length(products), min(raw$date), max(raw$date),
                         sum(duplicated(raw[, setdiff(names(raw), c("customer", "date"))])),
                         conflict_count("OrderDate"), conflict_count("customer"),
                         conflict_count("OrderType"), conflict_count("PaymentMethod"),
                         if ("AddressLine1" %in% names(raw)) sum(is.na(raw$AddressLine1)) else NA,
                         if ("Contact No" %in% names(raw)) sum(is.na(raw[["Contact No"]])) else NA,
                         if ("Registered Outlet" %in% names(raw)) sum(is.na(raw[["Registered Outlet"]])) else NA))
)
save_csv(source_audit, "01_source_audit.csv")
save_csv(data.frame(column = names(raw), missing_count = colSums(is.na(raw))),
         "01_missing_values.csv")
item_category <- unique(raw[, c("ItemName", "MainCategory", "SubCategory")])
save_csv(item_category[order(item_category$ItemName), ], "01_item_category_mapping_check.csv")

if (conflict_count("OrderDate") || conflict_count("customer")) {
  stop("An OrderNo spans multiple dates/customers: cannot build reliable baskets")
}

# Parse the recorded clock time solely to sort previous orders. We never use
# the FUTURE order's time, date, payment method, or type as a model feature.
parse_seconds <- function(x) {
  h <- suppressWarnings(as.integer(sub("H.*$", "", x)))
  m <- suppressWarnings(as.integer(sub("^.*H +([0-9]+)M.*$", "\\1", x)))
  s <- suppressWarnings(as.integer(sub("^.*M +([0-9]+)S$", "\\1", x)))
  out <- h * 3600 + m * 60 + s
  out[is.na(out)] <- 0L
  out
}

order_info <- data.frame(
  order_id = order_ids,
  customer = vapply(order_rows, function(i) raw$customer[i[1L]], character(1)),
  date = as.Date(vapply(order_rows, function(i) as.character(raw$date[i[1L]]), character(1))),
  seconds = vapply(order_rows, function(i) parse_seconds(raw$OrderTime[i[1L]]), numeric(1)),
  basket_size = vapply(order_rows, function(i) length(unique(raw$ItemName[i])), integer(1)),
  item_lines = lengths(order_rows),
  order_type = vapply(order_rows, function(i) {
    x <- unique(na.omit(raw$OrderType[i])); if (length(x) == 1L) x else NA_character_
  }, character(1)),
  age = vapply(order_rows, function(i) as.numeric(raw$Age[i[1L]]), numeric(1))
)
order_info <- order_info[order(order_info$date, order_info$seconds, order_info$order_id), ]
row.names(order_info) <- NULL
order_info$order_index <- seq_len(nrow(order_info))
items_by_order <- lapply(order_info$order_id, function(id) {
  match(unique(raw$ItemName[order_rows[[id]]]), products)
})
save_csv(order_info[, c("date", "order_id", "customer", "basket_size", "item_lines", "order_type")],
         "02_order_summary.csv")

product_summary <- data.frame(
  product = products,
  purchased_lines = as.integer(table(factor(raw$ItemName, levels = products))),
  orders_containing_product = tabulate(unlist(items_by_order), nbins = length(products))
)
product_summary <- product_summary[order(-product_summary$orders_containing_product), ]
save_csv(product_summary, "02_product_summary.csv")
monthly_summary <- aggregate(order_id ~ format(date, "%Y-%m"), data = order_info, FUN = length)
names(monthly_summary) <- c("month", "orders")
save_csv(monthly_summary, "02_monthly_orders.csv")

png(file.path(output_dir, "02_product_orders.png"), width = 1200, height = 800, res = 150)
par(mar = c(5, 12, 3, 2))
barplot(rev(product_summary$orders_containing_product), names.arg = rev(product_summary$product),
        horiz = TRUE, las = 1, col = "#2E6998", xlab = "Orders containing product",
        main = "Observed product purchases")
dev.off()
png(file.path(output_dir, "02_monthly_orders.png"), width = 1100, height = 650, res = 150)
plot(seq_len(nrow(monthly_summary)), monthly_summary$orders, type = "b", pch = 19,
     col = "#2E6998", axes = FALSE, xlab = "2025", ylab = "Number of orders",
     main = "Orders by month (one observed year)")
axis(1, at = seq_len(nrow(monthly_summary)), labels = monthly_summary$month, las = 2, cex.axis = 0.75)
axis(2); box(); dev.off()

# Customer-level analysis avoids treating one person's repeated orders as
# independent people. These tests are exploratory and show association only.
customer_order_idx <- split(seq_len(nrow(order_info)), order_info$customer)
paired <- do.call(rbind, lapply(customer_order_idx, function(i) {
  a <- order_info[i, ]
  d <- a$basket_size[!is.na(a$order_type) & a$order_type == "Dine-In"]
  t <- a$basket_size[!is.na(a$order_type) & a$order_type == "Takeaway"]
  if (!length(d) || !length(t)) return(NULL)
  data.frame(customer = a$customer[1L], dine_in_mean = mean(d),
             takeaway_mean = mean(t), difference = mean(d) - mean(t))
}))
save_csv(paired, "03_customer_paired_basket_size.csv")
if (!is.null(paired) && nrow(paired) >= 3L &&
    all(is.finite(paired$difference)) && sd(paired$difference) > 0) {
  tt <- t.test(paired$dine_in_mean, paired$takeaway_mean, paired = TRUE)
  paired_result <- data.frame(test = "Paired t-test: customer mean distinct products/order",
                              n_customers = nrow(paired), mean_difference = mean(paired$difference),
                              statistic = unname(tt$statistic), p_value = tt$p.value,
                              ci_low = tt$conf.int[1], ci_high = tt$conf.int[2])
  save_csv(paired_result, "03_paired_test.csv")
}

# Comparison of proportions: each customer contributes ONE binary outcome.
# Target is whether they purchased the most common product in Oct-Dec.
early_counts <- table(factor(raw$ItemName[raw$date < as.Date("2025-10-01")],
                             levels = products))
top_product <- products[which.max(as.integer(early_counts))]
q4 <- which(order_info$date >= as.Date("2025-10-01"))
customer_age <- vapply(customer_order_idx, function(i) order_info$age[i[1L]], numeric(1))
ever_q4 <- vapply(customer_order_idx, function(i) {
  j <- intersect(i, q4)
  any(vapply(items_by_order[j], function(items) match(top_product, products) %in% items, logical(1)))
}, logical(1))
age_band <- ifelse(customer_age < 40, "Under 40", "40 or older")
valid <- !is.na(customer_age) & customer_age >= 18 & customer_age <= 100
prop_table <- table(factor(age_band[valid], levels = c("Under 40", "40 or older")),
                    factor(ever_q4[valid], levels = c(FALSE, TRUE)))
save_csv(data.frame(age_band = rownames(prop_table), n = rowSums(prop_table),
                    purchased_top_product = prop_table[, "TRUE"],
                    purchase_proportion = prop_table[, "TRUE"] / rowSums(prop_table),
                    product = top_product), "03_customer_proportions.csv")
if (all(rowSums(prop_table) > 0) && all(colSums(prop_table) > 0)) {
  test_prop <- if (any(chisq.test(prop_table)$expected < 5)) fisher.test(prop_table) else
    prop.test(x = prop_table[, "TRUE"], n = rowSums(prop_table), correct = TRUE)
  save_csv(data.frame(test = class(test_prop)[1L], product = top_product,
                      p_value = test_prop$p.value), "03_proportion_test.csv")
}

# ANOVA and Brown-Forsythe variance test on one aggregate observation/customer.
age_group <- cut(customer_age, breaks = c(17, 29, 44, 59, 100),
                 labels = c("18-29", "30-44", "45-59", "60+"))
average_basket <- vapply(customer_order_idx, function(i) mean(order_info$basket_size[i]), numeric(1))
group_data <- data.frame(customer = names(customer_order_idx), age_group = age_group,
                         average_basket = average_basket)
group_data <- group_data[complete.cases(group_data), ]
save_csv(group_data, "03_customer_age_basket_summary.csv")
if (length(unique(group_data$age_group)) >= 2L) {
  model_aov <- aov(average_basket ~ age_group, data = group_data)
  aa <- summary(model_aov)[[1L]]
  save_csv(data.frame(test = "ANOVA of customer mean basket size by age group",
                      statistic = aa[1, "F value"], p_value = aa[1, "Pr(>F)"]), "03_anova.csv")
  if (aa[1, "Pr(>F)"] < 0.05) {
    tk <- TukeyHSD(model_aov)$age_group
    save_csv(data.frame(comparison = rownames(tk), tk, row.names = NULL), "03_anova_posthoc.csv")
  }
  group_data$absolute_median_deviation <- abs(group_data$average_basket -
    ave(group_data$average_basket, group_data$age_group, FUN = median))
  bf <- summary(aov(absolute_median_deviation ~ age_group, data = group_data))[[1L]]
  save_csv(data.frame(test = "Brown-Forsythe approximate test across age groups",
                      statistic = bf[1, "F value"], p_value = bf[1, "Pr(>F)"]),
           "03_brown_forsythe.csv")
}

# MEMBER 3 — build one product candidate per (customer, next order).
# A customer's previous baskets are updated only AFTER labels are recorded.
n_orders <- nrow(order_info); n_products <- length(products)
features <- matrix(NA_real_, n_orders * n_products, 8L)
colnames(features) <- c("prior_orders", "item_order_count", "item_share",
                        "recent5_rate", "in_last_order", "orders_since_item",
                        "distinct_items_before", "mean_previous_basket")
y <- integer(n_orders * n_products)
prior_count <- matrix(0L, length(customers), n_products)
last_item_order <- matrix(0L, length(customers), n_products)
prior_n <- integer(length(customers)); prior_basket_sum <- integer(length(customers))
recent_baskets <- vector("list", length(customers))
customer_ix <- match(order_info$customer, customers)
candidate_product <- rep(seq_len(n_products), times = n_orders)

for (k in seq_len(n_orders)) {
  ci <- customer_ix[k]
  rows <- ((k - 1L) * n_products + 1L):(k * n_products)
  count <- prior_count[ci, ]; num <- prior_n[ci]
  history <- recent_baskets[[ci]]
  recent <- integer(n_products)
  if (length(history)) for (items in history) recent[items] <- recent[items] + 1L
  in_last <- integer(n_products)
  if (length(history)) in_last[history[[length(history)]]] <- 1L
  since <- ifelse(last_item_order[ci, ] == 0L, num + 1L,
                  num - last_item_order[ci, ] + 1L)
  features[rows, ] <- cbind(rep(num, n_products), count,
                             count / max(1L, num), recent / max(1L, length(history)),
                             in_last, since, rep(sum(count > 0), n_products),
                             rep(prior_basket_sum[ci] / max(1L, num), n_products))
  bought <- items_by_order[[k]]
  y[rows[bought]] <- 1L
  prior_n[ci] <- num + 1L
  prior_basket_sum[ci] <- prior_basket_sum[ci] + length(bought)
  prior_count[ci, bought] <- count[bought] + 1L
  last_item_order[ci, bought] <- num + 1L
  recent_baskets[[ci]] <- tail(c(history, list(bought)), 5L)
}

candidate <- data.frame(order_index = rep(seq_len(n_orders), each = n_products),
                        product = factor(products[candidate_product], levels = products),
                        features, purchased = y)
eligible_order <- which(candidate$prior_orders[seq(1L, nrow(candidate), by = n_products)] > 0L)
train_orders <- eligible_order[order_info$date[eligible_order] < as.Date("2025-10-01")]
valid_orders <- eligible_order[order_info$date[eligible_order] >= as.Date("2025-10-01") &
                                order_info$date[eligible_order] < as.Date("2025-11-01")]
test_orders <- eligible_order[order_info$date[eligible_order] >= as.Date("2025-11-01")]
if (min(length(train_orders), length(valid_orders), length(test_orders)) < 20L) {
  stop("Need at least 20 eligible train, validation, and test orders in date splits")
}
row_index <- function(orders) as.vector(t(outer(orders - 1L, seq_len(n_products),
                                                 function(o, p) o * n_products + p)))
train <- candidate[row_index(train_orders), ]
valid <- candidate[row_index(valid_orders), ]
test <- candidate[row_index(test_orders), ]
save_csv(data.frame(split = c("train Jan-Sep", "validation Oct", "test Nov-Dec"),
                    orders = c(length(train_orders), length(valid_orders), length(test_orders))),
         "04_chronological_split.csv")

# Pooled binomial logistic GLMs are statistical models. The first is a simple
# interpretable model; the second adds recent purchase behaviour. These
# candidate probabilities need not sum to 1 because a basket can hold >1 item.
formulas <- list(
  simple = purchased ~ product + prior_orders + item_share,
  history = purchased ~ product + prior_orders + item_share + recent5_rate +
    in_last_order + orders_since_item + distinct_items_before + mean_previous_basket
)
fits <- lapply(formulas, function(f) glm(f, family = binomial(), data = train,
                                        control = glm.control(maxit = 40)))
if (any(!vapply(fits, function(f) f$converged, logical(1)))) {
  warning("At least one logistic GLM did not converge; inspect coefficients")
}

rank_scores <- function(score, truth) {
  # score/truth are orders x products; column order equals `products`.
  ranked <- t(apply(score, 1L, order, decreasing = TRUE))
  if (is.null(dim(ranked))) ranked <- matrix(ranked, nrow = 1L)
  top1 <- truth[cbind(seq_len(nrow(truth)), ranked[, 1L])]
  k <- min(3L, ncol(truth))
  hits <- rowSums(matrix(truth[cbind(rep(seq_len(nrow(truth)), each = k),
                                  as.vector(t(ranked[, seq_len(k), drop = FALSE])))],
                         ncol = k, byrow = TRUE))
  c(top1_hit = mean(top1), top3_any_hit = mean(hits > 0),
    recall_at_3 = sum(hits) / sum(truth), precision_at_3 = sum(hits) / (k * nrow(truth)))
}

evaluate <- function(part, order_numbers, fit_list) {
  truth <- matrix(part$purchased, nrow = length(order_numbers), ncol = n_products, byrow = TRUE)
  # A customer-favourite baseline uses ONLY purchase counts before each order.
  baseline <- matrix(part$item_order_count, nrow = length(order_numbers), byrow = TRUE)
  # Global popularity calculated from training data ONLY.
  train_counts <- colSums(matrix(train$purchased, ncol = n_products, byrow = TRUE))
  baseline <- sweep(baseline, 2L, train_counts / max(train_counts) * 1e-5, "+")
  scores <- list(customer_favourite = baseline,
                 global_popularity = matrix(rep(train_counts, each = length(order_numbers)),
                                            nrow = length(order_numbers)))
  for (name in names(fit_list)) {
    v <- predict(fit_list[[name]], newdata = part, type = "response")
    scores[[name]] <- matrix(v, nrow = length(order_numbers), byrow = TRUE)
  }
  tab <- do.call(rbind, lapply(names(scores), function(name) {
    data.frame(model = name, t(rank_scores(scores[[name]], truth)),
               n_orders = length(order_numbers))
  }))
  row.names(tab) <- NULL
  list(metrics = tab, scores = scores, truth = truth)
}

val_out <- evaluate(valid, valid_orders, fits)
save_csv(val_out$metrics, "04_validation_model_comparison.csv")
model_names <- names(fits)
chosen_name <- model_names[which.max(val_out$metrics$recall_at_3[match(model_names,
                                                                    val_out$metrics$model)])]
chosen_fit <- fits[[chosen_name]]
test_out <- evaluate(test, test_orders, list(selected_glm = chosen_fit))
save_csv(test_out$metrics, "04_final_test_comparison.csv")

# The test split is touched only after selecting the model on October data.
# Coefficients describe conditional associations, not causal effects.
co <- summary(chosen_fit)$coefficients
save_csv(data.frame(term = rownames(co), estimate_log_odds = co[, 1L],
                    odds_ratio = exp(pmin(co[, 1L], 700)), standard_error = co[, 2L],
                    naive_p_value = co[, 4L]), "04_selected_model_coefficients.csv")
log_line("Selected GLM using October validation recall@3: ", chosen_name)
log_line("Note: GLM coefficient p-values assume independent rows; candidate rows and orders")
log_line("repeat by customer. Treat these p-values as exploratory; inference uses customer aggregates.")

# A customer-level bootstrap samples CUSTOMERS, retaining all their test
# orders. It quantifies uncertainty around improvement over the baseline.
set.seed(3081)
selected_scores <- test_out$scores$selected_glm
baseline_scores <- test_out$scores$customer_favourite
test_cust <- order_info$customer[test_orders]
cust_ids <- unique(test_cust)
bootstrap_delta <- replicate(300L, {
  sampled <- sample(cust_ids, length(cust_ids), replace = TRUE)
  rows <- unlist(lapply(sampled, function(c) which(test_cust == c)), use.names = FALSE)
  rank_scores(selected_scores[rows, , drop = FALSE], test_out$truth[rows, , drop = FALSE])["recall_at_3"] -
    rank_scores(baseline_scores[rows, , drop = FALSE], test_out$truth[rows, , drop = FALSE])["recall_at_3"]
})
save_csv(data.frame(metric = "Test recall@3 minus customer favourite; cluster bootstrap",
                    difference = test_out$metrics$recall_at_3[test_out$metrics$model == "selected_glm"] -
                      test_out$metrics$recall_at_3[test_out$metrics$model == "customer_favourite"],
                    low_95 = unname(quantile(bootstrap_delta, .025)),
                    high_95 = unname(quantile(bootstrap_delta, .975))),
         "04_customer_bootstrap_improvement.csv")

# PCA is an EVALUATION of dimensionality reduction: fit on Jan-Sep history,
# never use future purchase labels to construct the PCA input.
train_end <- which(order_info$date < as.Date("2025-10-01"))
shares <- matrix(0, length(customers), n_products,
                 dimnames = list(customers, products))
for (i in train_end) shares[customer_ix[i], items_by_order[[i]]] <-
  shares[customer_ix[i], items_by_order[[i]]] + 1
den <- rowSums(shares)
shares <- shares / pmax(1, den)
nonconstant <- apply(shares, 2L, sd) > 0
if (sum(nonconstant) >= 2L) {
  pca <- prcomp(shares[, nonconstant, drop = FALSE], center = TRUE, scale. = TRUE)
  cumulative <- cumsum(pca$sdev^2) / sum(pca$sdev^2)
  save_csv(data.frame(component = seq_along(cumulative),
                      variance_explained = pca$sdev^2 / sum(pca$sdev^2),
                      cumulative_variance = cumulative), "05_pca_variance.csv")
  save_csv(data.frame(product = rownames(pca$rotation), pca$rotation, row.names = NULL),
           "05_pca_loadings.csv")
  png(file.path(output_dir, "05_pca_variance.png"), width = 1000, height = 650, res = 150)
  plot(cumulative, type = "b", pch = 19, col = "#2E6998", ylim = c(0, 1),
       xlab = "Number of components", ylab = "Cumulative variance explained",
       main = "PCA of historical product shares (Jan-Sep only)")
  abline(h = .8, lty = 2, col = "#B44641"); dev.off()
}

# MEMBER 4 — export a conceptual decision-support example. We refit the
# selected structure on ALL 2025 orders after the held-out evaluation, then
# score the CURRENT history of each observed customer for their next order.
all_eligible <- candidate[row_index(eligible_order), ]
deployment_fit <- glm(formulas[[chosen_name]], family = binomial(), data = all_eligible,
                      control = glm.control(maxit = 40))
if (!deployment_fit$converged) warning("Deployment GLM did not converge")
current <- matrix(NA_real_, length(customers) * n_products, ncol(features))
colnames(current) <- colnames(features)
for (ci in seq_along(customers)) {
  rows <- ((ci - 1L) * n_products + 1L):(ci * n_products)
  history <- recent_baskets[[ci]]; recent <- integer(n_products)
  if (length(history)) for (items in history) recent[items] <- recent[items] + 1L
  last <- integer(n_products)
  if (length(history)) last[history[[length(history)]]] <- 1L
  num <- prior_n[ci]
  count <- prior_count[ci, ]
  since <- ifelse(last_item_order[ci, ] == 0L, num + 1L,
                  num - last_item_order[ci, ] + 1L)
  current[rows, ] <- cbind(rep(num, n_products), count, count / max(1, num),
                           recent / max(1, length(history)), last, since,
                           rep(sum(count > 0), n_products),
                           rep(prior_basket_sum[ci] / max(1, num), n_products))
}
scoring <- data.frame(customer = rep(customers, each = n_products),
                      product = factor(rep(products, length(customers)), levels = products),
                      current)
scoring$purchase_probability <- predict(deployment_fit, newdata = scoring, type = "response")
scoring$prior_product_orders <- scoring$item_order_count
recommendations <- do.call(rbind, lapply(split(scoring, scoring$customer), function(g) {
  g <- g[order(-g$purchase_probability), ]
  data.frame(customer = g$customer[1L], rank = seq_len(min(3L, nrow(g))),
             product = head(as.character(g$product), 3L),
             estimated_probability = head(g$purchase_probability, 3L),
             prior_product_orders = head(g$prior_product_orders, 3L))
}))
row.names(recommendations) <- NULL
save_csv(recommendations, "06_example_next_order_recommendations.csv")

log_line("Observed rows: ", nrow(raw), "; orders: ", n_orders,
         "; customers: ", length(customers), "; products: ", n_products)
log_line("Outcome: whether each product appears in the NEXT observed order")
log_line("Time split: Jan-Sep train, October validation, Nov-Dec final test")
log_line("Recommendations for future next orders: historical customers and existing items only")
log_line("Source provenance/public availability and category mapping require manual verification")
log_line("This file has purchases only: it cannot identify visitors who chose not to buy")
log_line("Sections on literature, CRD/RCBD, Bayesian methods, ARIMA, expert evidence")
log_line("and management recommendations require written work and documented feedback")
print(val_out$metrics)
print(test_out$metrics)
cat("Selected model:", chosen_name, "\nOutputs:", normalizePath(output_dir), "\n")
