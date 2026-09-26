set.seed(2026)
options(stringsAsFactors = FALSE, scipen = 6)

csv_path <- getOption("espresso.csv_path", "V2postransactions.csv")
if (!file.exists(csv_path)) {
  if (interactive()) csv_path <- file.choose() else
    stop("Place V2postransactions.csv in the working directory.")
}
csv_path <- normalizePath(csv_path, mustWork = TRUE)
output_dir <- file.path(dirname(csv_path),
  paste0("Espresso_Results_", format(Sys.time(), "%Y%m%d_%H%M%S")))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

packages <- c("glmnet", "sandwich")
missing_packages <- packages[!vapply(packages, requireNamespace,
  logical(1), quietly = TRUE)]
if (length(missing_packages))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))

save_table <- function(x, name) {
  write.csv(x, file.path(output_dir, paste0(name, ".csv")), row.names = FALSE)
  print(utils::head(x, 10))
  invisible(x)
}

plot_file <- function(name, expression) {
  png(file.path(output_dir, paste0(name, ".png")),
      width = 1600, height = 1050, res = 150)
  on.exit(dev.off())
  par(mar = c(5, 5, 3, 2))
  force(expression)
}

wilson <- function(k, n, z = qnorm(.975)) {
  p <- k/n
  denominator <- 1 + z^2/n
  centre <- (p + z^2/(2*n))/denominator
  half <- z*sqrt(p*(1-p)/n + z^2/(4*n^2))/denominator
  cbind(lower = centre-half, upper = centre+half)
}

cat("Running Task 3: dataset understanding and descriptive analysis\n")

raw <- read.csv(csv_path, colClasses = "character", check.names = FALSE,
                na.strings = c("", "NA", "NULL"))
required_columns <- c("OrderNo", "Outlet", "OrderDate", "OrderTime", "ItemName",
                      "Qty1", "AdjustedRate", "Discount", "ServiceCharge",
                      "CustomerLoyaltyNumber", "MainCategory", "CoffeeOrNonCoffee")
stopifnot(all(required_columns %in% names(raw)))
original_columns <- names(raw)
raw[] <- lapply(raw, function(x) {
  x <- trimws(x); x[x == ""] <- NA_character_; x
})
save_table(data.frame(variable = names(raw),
  missing_n = colSums(is.na(raw)), missing_pct = 100*colMeans(is.na(raw))),
  "task03_missing_values")
save_table(data.frame(item_rows = nrow(raw), columns = ncol(raw),
  duplicate_rows_flagged_not_removed = sum(duplicated(raw))), "task03_raw_summary")

numeric_columns <- intersect(c("Qty1", "AdjustedRate", "Discount",
                              "ServiceCharge", "Age"), names(raw))
for (v in numeric_columns) {
  original <- raw[[v]]
  raw[[v]] <- suppressWarnings(as.numeric(original))
  if (any(!is.na(original) & is.na(raw[[v]]))) stop(paste("Invalid number in", v))
}
raw$order_date <- as.Date(raw$OrderDate, format = "%Y-%m-%d")
valid_clock <- grepl("^[0-9]{1,2}H [0-9]{1,2}M [0-9]{1,2}S$", raw$OrderTime)
if (any(!valid_clock | is.na(raw$OrderTime))) stop("Check invalid OrderTime values.")
raw$hour <- as.integer(sub("H.*", "", raw$OrderTime))
minute <- as.integer(sub(".*H ([0-9]+)M.*", "\\1", raw$OrderTime))
second <- as.integer(sub(".*M ([0-9]+)S", "\\1", raw$OrderTime))
if (anyNA(raw$order_date) || any(raw$hour > 23 | minute > 59 | second > 59)) {
  stop("Invalid date/time: fix the source before continuing.")
}
if (anyNA(raw$OrderNo) || anyNA(raw$Outlet)) stop("Missing order ID or outlet.")
raw$item <- tolower(gsub("[[:space:]]+", " ", raw$ItemName))
order_groups <- split(seq_len(nrow(raw)), raw$OrderNo)

metadata <- intersect(c("Outlet", "OrderDate", "OrderTime", "OrderType",
                        "CustomerLoyaltyNumber"), names(raw))
conflicts <- data.frame(variable = metadata, conflicting_orders = vapply(metadata,
  function(v) sum(vapply(order_groups, function(i)
    length(unique(raw[[v]][i])) > 1, logical(1))), integer(1)))
save_table(conflicts, "task03_order_key_audit")
if (any(conflicts$conflicting_orders > 0)) {
  stop("Conflicting order metadata. Investigate OrderNo reuse; do not blindly merge orders.")
}
make_time_band <- function(hour) {
  ifelse(hour >= 7 & hour < 12, "Morning",
    ifelse(hour >= 12 & hour < 17, "Afternoon",
      ifelse(hour >= 17 & hour < 21, "Evening", "Night")))
}
make_weekday <- function(date) {
  days <- c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
  days[as.POSIXlt(as.Date(date))$wday + 1L]
}
orders <- do.call(rbind, lapply(order_groups, function(i) {
  j <- i[1]

  y <- if (any(raw$item[i] == "espresso", na.rm = TRUE)) 1L else
    if (anyNA(raw$item[i])) NA_integer_ else 0L
  data.frame(order_id = raw$OrderNo[j], outlet = raw$Outlet[j],
    date = raw$order_date[j], hour = raw$hour[j], bought_espresso = y,
    item_rows = length(i), units = sum(raw$Qty1[i]),
    loyalty_id = raw$CustomerLoyaltyNumber[j])
}))
rownames(orders) <- NULL
orders$weekday <- make_weekday(orders$date)
orders$time_band <- make_time_band(orders$hour)
orders <- orders[order(orders$date, orders$hour, orders$order_id), ]
stopifnot(!anyDuplicated(orders$order_id))
save_table(data.frame(orders = nrow(orders),
  espresso_orders = sum(orders$bought_espresso, na.rm = TRUE),
  unknown_outcomes = sum(is.na(orders$bought_espresso)),
  espresso_rate = mean(orders$bought_espresso, na.rm = TRUE),
  first_date = min(orders$date), last_date = max(orders$date),
  outlets = length(unique(orders$outlet))), "task03_order_summary")
if (anyNA(orders$bought_espresso)) {
  warning("Unresolved outcomes excluded; report count and investigate missingness.")
  orders <- orders[!is.na(orders$bought_espresso), ]
}

write.csv(orders[setdiff(names(orders), "loyalty_id")],
          file.path(output_dir,"task03_orders.csv"), row.names = FALSE)
numeric_audit <- do.call(rbind, lapply(numeric_columns, function(v) {
  x <- raw[[v]]; q <- quantile(x, c(.25, .75), na.rm = TRUE)
  spread <- q[2]-q[1]
  data.frame(variable = v, n = sum(!is.na(x)), mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE), median = median(x, na.rm = TRUE),
    q1=unname(q[1]), q3=unname(q[2]), lower_fence=unname(q[1]-1.5*spread),
    upper_fence=unname(q[2]+1.5*spread),
    min = min(x, na.rm = TRUE), max = max(x, na.rm = TRUE),
    iqr_flagged = sum(x < q[1]-1.5*spread | x > q[2]+1.5*spread, na.rm = TRUE),
    zero_iqr = spread == 0)
}))
save_table(numeric_audit, "task03_numeric_and_outlier_audit")

category_audit <- unique(raw[c("item", "MainCategory", "CoffeeOrNonCoffee")])
save_table(category_audit, "task03_product_category_audit")
save_table(as.data.frame(table(raw$ItemName)), "task03_item_row_counts")
rate_table <- function(d, variable) {
  groups <- split(d$bought_espresso, d[[variable]])
  tab <- data.frame(group = names(groups), n = lengths(groups),
                    espresso_n = vapply(groups, sum, numeric(1)))
  tab$rate <- tab$espresso_n/tab$n
  cbind(tab, wilson(tab$espresso_n, tab$n))
}
for (v in c("outlet", "weekday", "time_band")) {
  save_table(rate_table(orders, v), paste0("task03_rates_", v))
}
plot_file("task03_missing", {
  miss <- sort(colMeans(is.na(raw[original_columns])), decreasing = TRUE)
  par(mar = c(11,5,3,2)); barplot(100*miss, las=2, cex.names=.65,
    col="#137C86", ylab="Missing (%)", main="Missingness in original variables")
})
plot_file("task03_purchase_rate", {
  z <- rate_table(orders, "time_band")
  b <- barplot(z$rate, names.arg=z$group, col="#137C86", ylim=c(0,max(z$upper)*1.2),
    ylab="Proportion of orders containing Espresso", main="Observed purchase rates")
  arrows(b, z$lower, b, z$upper, angle=90, code=3, length=.06)
  mtext("95% Wilson intervals assume independent orders", side=1, line=3)
})
plot_file("task03_outliers", {
  boxplot(raw$AdjustedRate, horizontal=TRUE, col="#A9D9D5",
          xlab="AdjustedRate (currency definition needs source confirmation)",
          main="Item price distribution: retain valid extremes")
})

variable_dictionary <- data.frame(
variable=c("Outlet",
    "OrderNo",
    "OrderDate",
    "OrderTime",
    "ItemName",
    "Qty1",
    "AdjustedRate",
    "Discount",
    "ServiceCharge",
    "OrderType",
    "CustomerLoyaltyNumber",
    "PaymentMethod",
    "CustomerType",
    "OutletType",
    "TimeRange",
    "Day",
    "Month",
    "TimeOfTheDay",
    "MainCategory",
    "SubCategory",
    "CoffeeOrNonCoffee",
    "SubMenu",
    "Name",
    "AddressLine1",
    "DOB",
    "Contact No",
    "Age",
    "Registered Outlet"),
  working_description=c("Outlet label",
    "Order identifier",
    "Order date YYYY-MM-DD",
    "Local order clock, e.g. 14H 57M 21S",
    "Recorded product name",
    "Recorded item quantity",
    "Recorded adjusted rate",
    "Recorded discount amount",
    "Recorded service charge",
    "Dine-In or Takeaway",
    "Loyalty identifier where available",
    "Recorded payment method",
    "Recorded customer category",
    "Outlet category",
    "Existing hourly label",
    "Existing weekday label",
    "Existing month label",
    "Existing time-band label",
    "Recorded main product category",
    "Recorded subcategory",
    "Recorded Y/N/0 flag",
    "Recorded submenu",
    "Customer name when available",
    "Address field",
    "Date-of-birth field in irregular format",
    "Contact-number field",
    "Recorded age",
    "Registration-outlet field"),
  role_and_caution=c("Categorical predictor; availability assumed before choice",
    "Grouping key; verify uniqueness and metadata consistency",
    "Chronological split and derived weekday",
    "Derived time band; confirm timestamp semantics",
    "Target construction only; never predictor",
    "Descriptive audit only; not a pre-purchase feature",
    "Descriptive audit; verify price/currency definition",
    "Post-purchase descriptor; no causal offer indicator",
    "Post-purchase descriptor",
    "Not used: chosen scope is outlet/time only",
    "Audit only; excluded from exports and model",
    "Post-purchase; excluded",
    "Not used; validate source definition",
    "Not used; potentially redundant with outlet",
    "Not used; recompute time features from OrderTime",
    "Not used; recompute weekday from OrderDate",
    "Not used; split by parsed OrderDate",
    "Not used; derive documented bands from clock",
    "Inconsistent for same ItemName; quality audit only",
    "Not used; validate coding",
    "Inconsistent; not the outcome or a predictor",
    "Not used; missingness audit",
    "Direct identifier; excluded",
    "Entirely missing in supplied extract; excluded",
    "Excluded; do not silently parse",
    "Entirely missing in supplied extract; excluded",
    "Descriptive audit only; excluded from model",
    "Entirely missing in supplied extract; excluded")
)
save_table(variable_dictionary, "task03_variable_dictionary")

quality_summary <- data.frame(
  check=c("Missing product names", "Nonpositive quantities", "Noninteger quantities",
    "Negative rates", "Negative discounts", "Negative service charges",
    "Existing weekday-label mismatches", "Existing time-band mismatches"),
  flagged_n=c(sum(is.na(raw$ItemName)), sum(raw$Qty1<=0,na.rm=TRUE),
    sum(raw$Qty1!=floor(raw$Qty1),na.rm=TRUE),sum(raw$AdjustedRate<0,na.rm=TRUE),
    sum(raw$Discount<0,na.rm=TRUE),sum(raw$ServiceCharge<0,na.rm=TRUE),
    if("Day" %in% names(raw)) sum(raw$Day!=make_weekday(raw$order_date),na.rm=TRUE) else NA,
    if("TimeOfTheDay" %in% names(raw))
      sum(raw$TimeOfTheDay!=make_time_band(raw$hour),na.rm=TRUE) else NA))
save_table(quality_summary,"task03_quality_checks")

safe_categories <- intersect(c("OrderType","PaymentMethod","CustomerType",
  "OutletType","MainCategory","CoffeeOrNonCoffee"), names(raw))
categorical_counts <- do.call(rbind,lapply(safe_categories,function(v) {
  z <- as.data.frame(table(raw[[v]],useNA="ifany"))
  data.frame(variable=v,category=as.character(z[[1]]),item_rows=z[[2]])
}))
save_table(categorical_counts,"task03_categorical_counts")
product_orders <- unique(raw[c("OrderNo","item")])
product_counts <- as.data.frame(table(product_orders$item))
names(product_counts) <- c("product","orders_containing_product")
product_counts <- product_counts[order(product_counts$orders_containing_product,decreasing=TRUE),]
save_table(product_counts,"task03_product_order_counts")

orders$month <- format(orders$date,"%Y-%m")
save_table(rate_table(orders,"month"),"task03_monthly_rates")
daily <- aggregate(cbind(orders=rep(1,nrow(orders)),
  espresso_orders=orders$bought_espresso),list(date=orders$date),sum)
daily <- merge(data.frame(date=seq(min(daily$date),max(daily$date),by="day")),
  daily,by="date",all.x=TRUE)
daily$rate <- daily$espresso_orders/daily$orders
save_table(daily,"task03_daily_descriptive_rates")
plot_file("task03_product_counts", {
  par(mar=c(9,5,3,2))
  barplot(product_counts$orders_containing_product,names.arg=product_counts$product,
    col="#137C86",las=2,cex.names=.85,ylab="Orders containing product",
    main="Product purchases across orders")
})
plot_file("task03_weekday_rates", {
  z <- rate_table(orders,"weekday")
  z <- z[match(c("Monday","Tuesday","Wednesday","Thursday","Friday",
                 "Saturday","Sunday"),z$group),]
  b <- barplot(z$rate,names.arg=z$group,col="#137C86",ylim=c(0,max(z$upper)*1.2),
    ylab="Share of orders containing Espresso",main="Purchase rate by weekday")
  arrows(b,z$lower,b,z$upper,angle=90,code=3,length=.06)
  mtext("95% Wilson intervals assume independent orders",side=1,line=3)
})
plot_file("task03_outlet_rates", {
  z <- rate_table(orders,"outlet")
  plot(z$n,z$rate,pch=19,col="#137C86",xlab="Number of orders at outlet",
    ylab="Espresso purchase rate",main="Outlet rates and sample size")
  abline(h=mean(orders$bought_espresso),lty=2)
})
plot_file("task03_daily_rates", {
  plot(daily$date,daily$rate,type="l",col="#137C86",lwd=2,
    xlab="Date",ylab="Espresso purchase rate",main="Daily descriptive purchase mix")
})

cat("Running Task 4: statistical inference\n")

development <- orders[orders$date < as.Date("2026-03-01"), ]
test <- orders[orders$date >= as.Date("2026-03-01"), ]
stopifnot(nrow(development)>0, nrow(test)>0,
  max(development$date)<min(test$date), length(unique(development$bought_espresso))==2)
save_table(data.frame(partition=c("Development: Jan-Feb", "Test: March"),
  n=c(nrow(development),nrow(test)),
  espresso_n=c(sum(development$bought_espresso),sum(test$bought_espresso))),
  "task04_partitions")

proportion_tests <- do.call(rbind, lapply(c("time_band", "outlet"), function(v) {
  tab <- table(development[[v]], development$bought_espresso)
  preliminary <- suppressWarnings(chisq.test(tab))
  simulated <- any(preliminary$expected < 5)
  fit <- if(simulated) chisq.test(tab, simulate.p.value=TRUE, B=9999) else preliminary
  data.frame(variable=v, statistic=unname(fit$statistic),
    df=(nrow(tab)-1)*(ncol(tab)-1),min_expected=min(preliminary$expected),
    H0=paste("Espresso proportions are equal across",v),
    H1=paste("At least one Espresso proportion differs across",v),
    p_value=fit$p.value, simulated_p=simulated,
    cramers_v=sqrt(unname(preliminary$statistic)/sum(tab)))
}))
proportion_tests$p_holm <- p.adjust(proportion_tests$p_value, "holm")
proportion_tests$conclusion <- ifelse(proportion_tests$p_holm<.05,
  "Reject equal-proportion H0 at 5% (exploratory)",
  "Insufficient evidence against equal proportions")
save_table(proportion_tests, "task04_unadjusted_proportion_tests")
for(v in c("time_band","outlet"))
  save_table(rate_table(development,v),paste0("task04_development_rates_",v))

predictor_names <- c("outlet", "weekday", "time_band")
for (v in predictor_names) development[[v]] <- factor(development[[v]])
formula_purchase <- bought_espresso ~ outlet + weekday + time_band
inference_model <- glm(formula_purchase, development, family=binomial())

robust_cov <- sandwich::vcovCL(inference_model,
  cluster=development[c("outlet","date")], type="HC1", fix=TRUE)
se <- sqrt(diag(robust_cov))
coef_table <- data.frame(term=names(coef(inference_model)),
  log_odds=coef(inference_model), cluster_se=se,
  odds_ratio=exp(coef(inference_model)),
  or_lower=exp(coef(inference_model)-qnorm(.975)*se),
  or_upper=exp(coef(inference_model)+qnorm(.975)*se))
save_table(coef_table, "task04_adjusted_odds_ratios")
idx <- grep("^time_band", names(coef(inference_model)))
b <- coef(inference_model)[idx]; V <- robust_cov[idx,idx,drop=FALSE]
W <- as.numeric(t(b) %*% solve(V,b))
save_table(data.frame(hypothesis="All adjusted time-band coefficients = 0",
  Wald_chisq=W, df=length(idx), p_value=pchisq(W,length(idx),lower.tail=FALSE)),
  "task04_primary_cluster_robust_test")

outlet_totals <- aggregate(cbind(k=development$bought_espresso,n=rep(1,nrow(development))),
  list(outlet=development$outlet), sum)
set.seed(2026)
boot_rates <- replicate(1000, {
  ii <- sample(seq_len(nrow(outlet_totals)), replace=TRUE)
  sum(outlet_totals$k[ii])/sum(outlet_totals$n[ii])
})
save_table(data.frame(rate=mean(development$bought_espresso),
  lower=unname(quantile(boot_rates,.025)), upper=unname(quantile(boot_rates,.975)),
  method="Outlet-cluster percentile bootstrap; 1000 resamples"),
  "task04_rate_interval")

save_table(data.frame(
  test=c("Chi-square proportions","Adjusted time-band Wald","Outlet bootstrap rate CI"),
  purpose=c("Compare binary purchase proportions by group",
    "Evaluate time-band association controlling for outlet and weekday",
    "Estimate uncertainty in the overall purchase rate"),
  assumption=c("Independent orders; Monte Carlo only addresses small expected counts",
    "Adequate outlet/date clusters; additive log odds; no causal identification",
    "Independent outlet clusters; does not fully capture cross-outlet customer dependence")),
  "task04_test_specifications")
save_table(data.frame(reference_predictor=predictor_names,
  reference_level=vapply(development[predictor_names],function(x) levels(x)[1],character(1))),
  "task04_reference_levels")

cat("Running Task 5: predictive statistical modelling\n")

fit_encoder <- function(d) {
  lapply(d[predictor_names], function(x) sort(unique(as.character(x))))
}
apply_encoder <- function(d, encoder) {
  out <- d; unknown <- rep(FALSE,nrow(d))
  for(v in names(encoder)) {
    x <- as.character(d[[v]]); bad <- is.na(x) | !x %in% encoder[[v]]
    unknown <- unknown | bad
    x[bad] <- encoder[[v]][1]
    out[[v]] <- factor(x, levels=encoder[[v]])
  }
  list(data=out, unknown=unknown)
}
design_matrix <- function(d) model.matrix(~ outlet+weekday+time_band,d)[,-1,drop=FALSE]
clip <- function(p) pmin(pmax(p,1e-10),1-1e-10)
log_loss <- function(y,p) mean(-y*log(clip(p))-(1-y)*log(1-clip(p)))
auc <- function(y,p) {
  n1 <- sum(y==1); n0 <- sum(y==0)
  if(n1*n0==0) return(NA_real_)
  (sum(rank(p,ties.method="average")[y==1])-n1*(n1+1)/2)/(n1*n0)
}

average_precision <- function(y,p) {
  z <- aggregate(cbind(pos=y,n=rep(1,length(y))),list(score=p),sum)
  z <- z[order(z$score,decreasing=TRUE),]
  if(sum(y)==0) return(NA_real_)
  sum((z$pos/sum(y))*(cumsum(z$pos)/cumsum(z$n)))
}
metrics <- function(y,p,threshold=.5) {
  pred <- as.integer(p>=threshold)
  tp <- sum(pred==1 & y==1); fp <- sum(pred==1 & y==0)
  tn <- sum(pred==0 & y==0); fn <- sum(pred==0 & y==1)
  precision <- if(tp+fp==0) NA_real_ else tp/(tp+fp)
  recall <- if(tp+fn==0) NA_real_ else tp/(tp+fn)
  specificity <- if(tn+fp==0) NA_real_ else tn/(tn+fp)
  data.frame(log_loss=log_loss(y,p), brier=mean((y-p)^2), roc_auc=auc(y,p),
    average_precision=average_precision(y,p), accuracy=mean(pred==y),
    precision=precision, recall=recall, specificity=specificity,
    balanced_accuracy=mean(c(recall,specificity)),
    f1=if(2*tp+fp+fn==0) NA_real_ else 2*tp/(2*tp+fp+fn),
    threshold=threshold, TP=tp,FP=fp,TN=tn,FN=fn)
}
penalty_alpha <- c(Ridge=0,LASSO=1,ElasticNet=.5)
lambda_grid <- 10^seq(0,-4,length.out=30)

cutoffs <- as.Date(c("2026-01-21","2026-02-04","2026-02-18"))
cv_rows <- list(); cv_n <- 0L
fold_definitions <- list()
for (fold in seq_along(cutoffs)) {
  cutoff <- cutoffs[fold]
  tr <- development[development$date<cutoff,]
  va <- development[development$date>=cutoff & development$date<cutoff+14,]
  stopifnot(max(tr$date)<min(va$date), nrow(va)>0)
  fold_definitions[[fold]] <- data.frame(fold=fold,
    training_start=min(tr$date),training_end=max(tr$date),training_n=nrow(tr),
    validation_start=min(va$date),validation_end=max(va$date),validation_n=nrow(va))
  enc <- fit_encoder(tr)
  tr <- apply_encoder(tr,enc)$data
  va_enc <- apply_encoder(va,enc)
  p0 <- mean(tr$bought_espresso)
  xtr <- design_matrix(tr); xva <- design_matrix(va_enc$data)
  glm_fit <- glm(formula_purchase,tr,family=binomial())
  pg <- as.numeric(predict(glm_fit,va_enc$data,type="response"))
  pg[va_enc$unknown | !is.finite(pg)] <- p0
  predictions <- list(Baseline=matrix(p0,nrow(va),1),Logistic=matrix(pg,ncol=1))
  for (kind in names(penalty_alpha)) {
    fit <- glmnet::glmnet(xtr,tr$bought_espresso,family="binomial",
      alpha=unname(penalty_alpha[kind]),lambda=lambda_grid,standardize=TRUE)
    pp <- as.matrix(predict(fit,xva,s=lambda_grid,type="response"))
    pp[va_enc$unknown,] <- p0
    predictions[[kind]] <- pp
  }
  for (kind in names(predictions)) {
    pp <- predictions[[kind]]
    for(j in seq_len(ncol(pp))) {
      cv_n <- cv_n+1L
      cv_rows[[cv_n]] <- data.frame(fold=fold,model=kind,
        lambda=if(kind %in% names(penalty_alpha)) lambda_grid[j] else NA_real_,
        n=nrow(va),unknown_groups=sum(va_enc$unknown),
        log_loss=log_loss(va$bought_espresso,pp[,j]))
    }
  }
}
save_table(do.call(rbind,fold_definitions),"task05_validation_windows")
cv <- do.call(rbind,cv_rows)
save_table(cv,"task05_rolling_validation_all")

cv$key <- paste(cv$model,ifelse(is.na(cv$lambda),"none",cv$lambda))
cv_summary <- do.call(rbind,lapply(split(cv,cv$key),function(z) {
  data.frame(model=z$model[1],lambda=z$lambda[1],
    validation_log_loss=weighted.mean(z$log_loss,z$n))
}))
cv_summary <- cv_summary[order(cv_summary$validation_log_loss),]
best <- cv_summary[!duplicated(cv_summary$model),]

if(best$validation_log_loss[best$model=="Baseline"] <=
   min(best$validation_log_loss)+1e-6) {
  best <- best[c(which(best$model=="Baseline"),which(best$model!="Baseline")),]
}
winner <- best$model[1]
save_table(best,"task05_validation_model_selection")
cat("Chosen using validation only:",winner,"\n")

encoder <- fit_encoder(development)
dev_encoded <- apply_encoder(development,encoder)$data
test_encoded <- apply_encoder(test,encoder)
xdev <- design_matrix(dev_encoded); xtest <- design_matrix(test_encoded$data)
base_rate <- mean(development$bought_espresso)
fits <- list(Baseline=base_rate,
  Logistic=glm(formula_purchase,dev_encoded,family=binomial()))
for(kind in names(penalty_alpha)) {
  fits[[kind]] <- glmnet::glmnet(xdev,development$bought_espresso,
    family="binomial", alpha=unname(penalty_alpha[kind]),
    lambda=lambda_grid,standardize=TRUE)
}
predict_model <- function(kind,d,unknown) {
  if(kind=="Baseline") return(rep(base_rate,nrow(d)))
  if(kind=="Logistic") p <- as.numeric(predict(fits[[kind]],d,type="response")) else {
    lam <- best$lambda[match(kind,best$model)]
    p <- as.numeric(predict(fits[[kind]],design_matrix(d),s=lam,type="response"))
  }
  p[unknown | !is.finite(p)] <- base_rate
  p
}
test_probabilities <- lapply(names(fits), function(kind)
  predict_model(kind,test_encoded$data,test_encoded$unknown))
names(test_probabilities) <- names(fits)
test_metrics <- do.call(rbind,lapply(names(fits),function(kind) {
  cbind(model=kind,selected_before_test=kind==winner,
        metrics(test$bought_espresso,test_probabilities[[kind]]))
}))
test_metrics$test_prevalence <- mean(test$bought_espresso)
test_metrics$predicted_positive_n <- test_metrics$TP+test_metrics$FP
save_table(test_metrics,"task05_test_metrics")
save_table(data.frame(order_id=test$order_id,date=test$date,actual=test$bought_espresso,
  as.data.frame(test_probabilities)),"task05_all_model_probabilities")
cat("Accuracy of always predicting no Espresso:",mean(test$bought_espresso==0),"\n")
chosen_p <- test_probabilities[[winner]]
save_table(data.frame(order_id=test$order_id,date=test$date,
  actual=test$bought_espresso,probability=chosen_p,
  fallback_to_base_rate=test_encoded$unknown),"task05_test_predictions")

cal <- data.frame(p=chosen_p,y=test$bought_espresso,
  bin=cut(chosen_p,seq(0,1,.025),include.lowest=TRUE))
calibration <- do.call(rbind,lapply(split(cal,cal$bin,drop=TRUE),function(z)
  data.frame(n=nrow(z),predicted=mean(z$p),observed=mean(z$y))))
save_table(calibration,"task05_calibration")
plot_file("task05_calibration", {
  lim <- c(0,max(.2,calibration$predicted,calibration$observed)*1.1)
  plot(calibration$predicted,calibration$observed,pch=19,col="#137C86",
    xlim=lim,ylim=lim,xlab="Mean predicted probability",ylab="Observed purchase rate",
    main=paste("March calibration:",winner),cex=pmax(.8,sqrt(calibration$n)/20))
  abline(0,1,lty=2,col="grey50")
})
plot_file("task05_roc", {
  plot(c(0,1),c(0,1),type="n",xlab="False positive rate",ylab="True positive rate",
    main="March ROC curves"); abline(0,1,lty=2,col="grey60")
  colours <- c("grey50","#137C86","#DB8434","#6358A0","#BC4860")
  for(j in seq_along(test_probabilities)) {
    z <- aggregate(cbind(pos=test$bought_espresso,neg=1-test$bought_espresso),
      list(score=test_probabilities[[j]]),sum)
    z <- z[order(z$score,decreasing=TRUE),]
    lines(c(0,cumsum(z$neg)/sum(z$neg)),c(0,cumsum(z$pos)/sum(z$pos)),col=colours[j])
  }
  legend("bottomright",names(fits),col=colours,lty=1,bty="n")
})

set.seed(2026)
day_groups <- split(seq_len(nrow(test)),test$date)
boot <- replicate(500, {
  i <- unlist(day_groups[sample(seq_along(day_groups),replace=TRUE)],use.names=FALSE)
  c(AUC=auc(test$bought_espresso[i],chosen_p[i]),
    Brier_improvement=mean((test$bought_espresso[i]-base_rate)^2)-
      mean((test$bought_espresso[i]-chosen_p[i])^2))
})
uncertainty <- data.frame(metric=rownames(boot),
  lower=apply(boot,1,quantile,.025,na.rm=TRUE),
  upper=apply(boot,1,quantile,.975,na.rm=TRUE))
save_table(uncertainty,"task05_day_bootstrap_intervals")

save_table(data.frame(model="Logistic",converged=fits$Logistic$converged,
  iterations=fits$Logistic$iter,rank=fits$Logistic$rank,
  model_columns=ncol(xdev)+1,aliased_coefficients=sum(is.na(coef(fits$Logistic))),
  development_events=sum(development$bought_espresso),
  test_unknown_groups=sum(test_encoded$unknown)),"task05_model_diagnostics")

coefficient_tables <- list(data.frame(model="Logistic",
  term=names(coef(fits$Logistic)),coefficient=as.numeric(coef(fits$Logistic))))
for(kind in names(penalty_alpha)) {
  cm <- as.matrix(coef(fits[[kind]],s=best$lambda[match(kind,best$model)]))
  coefficient_tables[[kind]] <- data.frame(model=kind,term=rownames(cm),coefficient=cm[,1])
}
save_table(do.call(rbind,coefficient_tables),"task05_model_coefficients")

plot_file("task05_precision_recall", {
  plot(c(0,1),c(0,1),type="n",xlab="Recall",ylab="Precision",
    main="March precision-recall curves")
  abline(h=mean(test$bought_espresso),lty=2,col="grey50")
  for(j in seq_along(test_probabilities)) {
    z <- aggregate(cbind(pos=test$bought_espresso,n=rep(1,nrow(test))),
      list(score=test_probabilities[[j]]),sum)
    z <- z[order(z$score,decreasing=TRUE),]
    lines(cumsum(z$pos)/sum(z$pos),cumsum(z$pos)/cumsum(z$n),col=colours[j],type="s")
  }
  legend("topright",names(fits),col=colours,lty=1,bty="n")
})

comparison <- test_metrics[c("model","selected_before_test","log_loss","brier",
  "roc_auc","average_precision")]
comparison$log_loss_improvement <- comparison$log_loss[comparison$model=="Baseline"]-
  comparison$log_loss
comparison$brier_improvement <- comparison$brier[comparison$model=="Baseline"]-
  comparison$brier
save_table(comparison,"task05_comparison_with_baseline")

bundle <- list(model=winner,fit=fits[[winner]],encoder=encoder,
  lambda=best$lambda[match(winner,best$model)],baseline=base_rate,
  training_end=max(development$date),observed_hours=range(development$hour),
  validation=best,test_metrics=test_metrics)
saveRDS(bundle,file.path(output_dir,"espresso_model.rds"))

predict_espresso <- function(outlet,date,hour) {
  if(length(outlet)!=1 || is.na(outlet) || !outlet %in% encoder$outlet)
    stop("Choose one outlet represented in training data.")
  if(length(date)!=1 || is.na(date)) stop("Supply one date as YYYY-MM-DD.")
  date <- as.Date(date,format="%Y-%m-%d")
  if(is.na(date)) stop("Invalid date.")
  if(length(hour)!=1 || !is.numeric(hour) || is.na(hour) ||
     hour!=floor(hour) || hour<min(development$hour) || hour>max(development$hour))
    stop("Supply an integer hour within the observed operating hours.")
  d <- data.frame(outlet=outlet,weekday=make_weekday(date),time_band=make_time_band(hour))
  e <- apply_encoder(d,encoder)
  p <- predict_model(winner,e$data,e$unknown)
  data.frame(outlet=outlet,date=date,hour=hour,model=winner,
    probability=p,expected_espresso_orders_per_100=100*p)
}
save_table(predict_espresso("Location 30","2026-04-01",10),"task05_example_prediction")

save_table(data.frame(field=c("Target","Predictors","Training period","Test period",
  "Selection rule","Assessment context","Classification threshold","Uncertainty method",
  "Dataset source","Target population"),
  value=c("Any normalized ItemName equals espresso within an order",
    "Outlet, weekday and time band; pre-purchase availability assumed",
    "January-February 2026","March 2026",
    "Expanding-window validation log loss; lambda tuned using development data only",
    "Retrospective holdout: March was examined in earlier project exploration",
    "0.5 for illustration; not a business-optimized threshold",
    "Day bootstrap for selected-model test metrics, conditional on fitted models",
    "Original public URL, licence and authenticity require verification",
    "Orders placed; not all visitors or unique customers")),"analysis_specification")
writeLines(capture.output(sessionInfo()),file.path(output_dir,"sessionInfo.txt"))
writeLines(capture.output(tools::md5sum(csv_path)),file.path(output_dir,"input_checksum.txt"))
writeLines(capture.output(citation(),citation("glmnet"),citation("sandwich")),
  file.path(output_dir,"software_citations.txt"))
source_path <- getOption("espresso.script_path", "Espresso_Analysis.R")
if(file.exists(source_path)) file.copy(source_path,file.path(output_dir,"Espresso_Analysis.R"),
  overwrite=TRUE)
make_archive <- function(folder) {
  if(!nzchar(Sys.which("zip"))) return(NA_character_)
  original_dir <- getwd()
  on.exit(setwd(original_dir))
  setwd(dirname(folder))
  path <- paste0(folder,".zip")
  status <- utils::zip(path,files=basename(folder),flags="-rq9X")
  if(!identical(as.integer(status),0L) || !file.exists(path)) return(NA_character_)
  path
}
archive <- make_archive(output_dir)
cat("\nSelected model:",winner,"\nResults folder:",output_dir,"\n")
if(!is.na(archive)) cat("Upload this results file:",archive,"\n") else
  cat("Compress the results folder and upload it.\n")
