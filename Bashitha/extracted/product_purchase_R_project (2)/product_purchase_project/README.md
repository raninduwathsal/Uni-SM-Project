# IT3081 Product Purchase Prediction: R analysis project

## Project question

**Which of the products already sold by this café is a returning customer likely to buy in their next order?** The analytical output is a ranked list of three products for each customer. The target is whether a product appears in the customer's next observed order. An order can contain several distinct products.

The supplied CSV contains 64,059 purchased item rows from 40,009 orders, 500 customers and 15 products between January and December 2025. It has no website visits or customers who did not purchase. It therefore cannot answer whether an arbitrary visitor will buy or forecast demand for products absent from the dataset.

## Run

Install R (version 4.1 or later is recommended). The script uses **base R only** and does not install packages. Put `analysis.R` and the supplied `percustomertraindata.csv` in the same folder. From a terminal in that folder run:

```sh
Rscript analysis.R percustomertraindata.csv results
```

On Windows, you can run the same command from RStudio's Terminal after changing to that folder. The script may take several minutes because it constructs 15 candidate products for every historical order and fits logistic regressions. A fresh `results` directory is recommended so old output files do not remain alongside new ones.

**Using RStudio's Source button:** Open `analysis.R`, set the working directory to the folder containing `percustomertraindata.csv`, then click **Source**. The script automatically uses that CSV and writes to a `results` folder. If the CSV is elsewhere, a file chooser opens. Pasting only the first few lines into the Console will not run the analysis; source the whole script.

The script prints the October validation and November–December test comparison. All tables and figures are saved in `results/`. Keep the source CSV unchanged. Do not use the example recommendation probabilities as proven business results until you have examined the held-out test performance.

## Division among the four members

| Member | Assignment tasks | Code outputs to explain | Written work still required |
|---|---|---|---|
| 1 | 1–2 | Dataset facts in `01_source_audit.csv` | Café industry problem, organisational context, objectives, critical literature review with at least 15 peer-reviewed papers, including at least 10 journals and five from the last five years; verify dataset source and lecturer approval. |
| 2 | 3–4 | `01_*.csv`, `02_*.csv`, `02_*.png`, `03_*.csv` | Data-quality decisions, plots and the meaning, assumptions and practical meaning of each inferential result. |
| 3 | 5 and 7 | `04_*.csv`, `05_*.csv`, `05_pca_variance.png` | Model justification, statistical interpretation, advantages and limits of PCA for this dataset. |
| 4 | 6 and 8–11 | `06_example_next_order_recommendations.csv` | CRD and RCBD proposals, critical review of Naïve Bayes, Bayesian regression and decision-making, potential trend/seasonality/ARIMA uses, conceptual innovation framework, and genuine expert interview evidence. |
| Everyone | 12, presentation, viva | All results | Recommendations supported by statistical evidence, published research and industry expert feedback; 15-minute presentation and 10-minute viva. |

## Analysis design

1. `01_*` audits the raw file. Check order-level disagreements (e.g. an order with multiple payment methods or order types) and the item-to-category mapping. The model uses `ItemName` as its product label; suspicious categories are kept for documentation rather than silently repaired.
2. `02_*` aggregates rows to orders, counts the 15 products and plots observed monthly orders. A single year is insufficient to validate a repeating seasonal pattern.
3. `03_*` contains exploratory inference with **one observation per customer** to address repeated orders. It compares the customer's average basket size for Dine-In versus Takeaway with a paired t-test, compares independent customers under/over age 40 on whether they purchased the most common product in October–December, and uses customer mean basket size in age-group ANOVA and Brown–Forsythe variance comparison. The script omits an unsuitable test if the data requirements fail. These comparisons are observational, with no causal claim. The age split and chosen product are exploratory; review their business relevance before presenting them.
4. `04_*` evaluates next-order product recommendations. The feature rows for an order use only **earlier** orders from that customer. Training orders are in January–September, October selects between two binomial logistic models, and November–December is the final untouched test. Both models are compared against a customer-favourite baseline and a globally popular product baseline calculated from training purchases. The selected model estimates a separate probability for each candidate product in a multi-product basket. Probabilities do not have to add up to 100%.
5. `04_final_test_comparison.csv` reports `top1_hit`, `top3_any_hit`, `recall_at_3`, and `precision_at_3`. `recall_at_3` is the fraction of actual purchased product types covered by the three recommendations; `top3_any_hit` is the fraction of orders where at least one recommendation matched. `04_customer_bootstrap_improvement.csv` gives a customer-resampled interval for the difference in recall@3 compared with the customer-favourite baseline.
6. `05_*` fits PCA to **January–September historical product shares**, for discussion of dimensionality reduction. PCA is not required for the prediction model, and unexplained components can make recommendations hard for management to interpret.
7. `06_*` is an example of the proposed customer recommendation system. After the test is completed, the selected model structure is fitted again using all 2025 historical orders and produces three product suggestions per observed customer for a later order. Predictions have not been tested on 2026 purchases.

## Data concerns to address before submission

- `ItemName` describes coffee products but some corresponding `MainCategory` and `SubCategory` fields describe unrelated food or merchandise. Verify the source and correct mapping with the data owner if possible. Avoid category-level conclusions until then.
- Some orders have conflicting `OrderType` and `PaymentMethod` values across their purchased lines. The paired Dine-In/Takeaway comparison excludes those orders. Do not use payment method as a fixed order attribute without resolving the conflict.
- `AddressLine1`, `Contact No`, and `Registered Outlet` are empty in this copy. They provide no analysis value.
- Customers are pseudonymised as `Customer 0001`, etc. Do not infer that this is an actual business or claim expert validation from the data alone.
- The assignment asks for a publicly accessible and properly referenced dataset and lecturer approval. Your group must locate and document the original source and verify it meets those conditions. The CSV itself does not establish public provenance.
- The script reports ordinary GLM coefficient estimates for description, but candidate rows and customer orders are correlated. The printed coefficient p-values are **not valid independent-row confirmatory tests**. Use customer-level inference and the customer bootstrap for defensible uncertainty, and discuss limitations.
- An observed future purchase does not prove that sending a recommendation would increase sales. A proposed randomised experiment is needed to test that intervention.

## Sections to write without inventing evidence

**Experimental design:** Propose a completely randomised test assigning eligible customers to recommendation versus usual service. For RCBD, block customers by their prior order frequency or outlet, then randomise treatment within each block. Specify the outcome (for example, a purchase of a recommended product within a defined period), consent/privacy, cost, operational feasibility and analysis plan. These are proposals; no experiment has been run.

**Bayesian analysis:** Compare Naïve Bayes and Bayesian logistic regression for predicting products, including correlated past-purchase predictors, priors and uncertainty. For Bayesian decision-making, describe a rule that compares expected gross benefit from a recommendation against the cost of offering it. Do not assume an uplift from the observational file.

**Time series:** Explain trend, seasonality, forecasting and ARIMA if more time-dependent data become available. The file covers only twelve calendar months, so avoid claiming evidence of a recurring annual seasonality or validated long-term forecast.

**Innovation:** Draw a conceptual framework with customer transaction history → validated product features → model probabilities → ranked recommendations → café manager review → trial campaign outcomes and monitoring. This is a proposed design, not a deployed system.

**Expert validation:** Interview at least one relevant café, retail or marketing professional, preserve real meeting or written-feedback evidence, and say specifically what feedback changed. Ask the lecturer about confidentiality and the permitted evidence format.

**Recommendations:** Pair each proposed action with the actual test result, a verified research source and real expert feedback. If the model does not beat the customer-favourite baseline by a useful amount, recommend the simpler rule or more reliable source data instead.

## Responsible use

Review and understand the code and results before presenting. Cite the dataset, the papers you actually read, and any software or generative AI assistance as required by the assignment. The report, oral explanation, references and expert evidence remain your group's work.
