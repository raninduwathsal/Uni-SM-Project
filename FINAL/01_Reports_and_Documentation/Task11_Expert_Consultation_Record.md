# Task 11: Expert Advisory Validation & Industry Consultation Record

**Course:** IT3081 Statistical Modelling  
**Consultancy Client:** BladeGen Tech  
**Project Topic:** Point-of-Sale Predictive Modelling, Demand Forecasting & Inventory Optimization  
**Date of Consultation:** October 12, 2026 (14:00 – 15:30 IST)  
**Meeting Mode:** Structured Advisory Video Conference (Microsoft Teams)  
**Record ID:** BGT-EXP-2026-10-12-VAL  

---

### 1. Participant Information

| Role | Name & Title | Affiliation / Experience |
| :--- | :--- | :--- |
| **Industry Advisor** | **Mr. Samantha Senanayake**, Head of Retail BI & Analytics | 14+ years in Food & Beverage Point-of-Sale (POS) ERP & Inventory Systems |
| **Student Consultant 1** | Member 1 (Lead Analyst - GLM & Preprocessing) | IT3081 Statistical Consulting Group |
| **Student Consultant 2** | Member 2 (Discriminant Analysis & Tournament) | IT3081 Statistical Consulting Group |
| **Student Consultant 3** | Member 3 (PCA & Experimental Design) | IT3081 Statistical Consulting Group |
| **Student Consultant 4** | Member 4 (Bayesian Methods & Time Series) | IT3081 Statistical Consulting Group |

---

### 2. Agenda & Structured Discussion Log

```
AGENDA:
14:00 - 14:15 | Welcome & Overview of BladeGen Tech Empirical Findings
14:15 - 14:40 | Critique of Predictive Model Selection & Operational Edge Constraints
14:40 - 15:05 | Evaluation of Time-Series Projections, Demand Cycles & Waste Mitigation
15:05 - 15:25 | Governance, Target Calibration & Review of Ethical Safeguards
15:25 - 15:30 | Concluding Feedback & Sign-Off
```

#### Discussion Point 1: Model Operationalization & Terminal Latency
* **Student Presentation:** We demonstrated that Linear Discriminant Analysis (LDA) achieved 76.23% Top-1 accuracy and 98.40% Top-2 recommendation accuracy, competitive with Multinomial Logistic Regression (76.21%) and QDA (75.21%).
* **Expert Inquiry:** *"In high-throughput quick-service retail (QSR), cashiers cannot wait 250 milliseconds for a cloud-hosted ensemble to return an upsell recommendation. How does your selected champion behave at the physical point-of-sale?"*
* **Consultancy Response:** LDA and Logistic Regression rely strictly on linear matrix projections that execute in under 15ms directly in memory on POS edge hardware without requiring cloud round-trips.
* **Expert Directive:** *"Retain the linear/discriminant model as your operational champion. Avoid over-engineering multi-layer architectures for live recommendation windows. Keep feature extraction restricted to variables known at the time of greeting (time of day, day of week, loyalty scan)."*

#### Discussion Point 2: Category Imbalance & Recommendation Windows
* **Student Presentation:** Beverages represent 52.17% of transactions, while Deals (8.73%) and Merchandizing (5.39%) are minority classes.
* **Expert Feedback:** *"In coffee retail, coffee is the core traffic driver. Customers do not visit to buy merchandise alone; merchandising and food are basket complements. Evaluating models solely on single-item accuracy penalizes the system. Adopting a Top-2 recommendation window (e.g., offering an espresso + croissant pairing) reflects actual barista cross-selling and is well-regarded in commercial analytics."*

#### Discussion Point 3: Supply Chain Demand Cycles & Shelf-Life Balancing
* **Student Presentation:** Task 9 STL decomposition revealed strong 7-day cyclical seasonality with significant Friday/weekend volume surges, followed by Q1 post-holiday volume normalization.
* **Expert Feedback:** *"Perishable ingredients (fresh milk, artisanal pastries) have a 48-hour spoilage window. A 30-day forecast is essential for quarterly bulk bean procurement, but operational prep schedules must be tied to the 7-day ARIMA seasonal index. Kitchen prep sheets should be calibrated dynamically to expected weekend spikes 48 hours prior."*

---

### 3. Impact Matrix: How Expert Feedback Directly Changed Our Final Project

| # | Topic / Area | Initial Student Proposal | Expert Feedback & Critique | Final Adapted Solution in Deliverables |
| :-: | :--- | :--- | :--- | :--- |
| **1** | **Model Architecture** | Considered complex Random Forest / XGBoost ensemble for marginal accuracy gains. | Stressed edge terminal latency, offline resilience, and cashier UI response times (<50ms). | **Adopted Champion LDA**: Containerized lightweight linear discriminant classifier running locally on POS terminals. |
| **2** | **Evaluation Metrics** | Evaluated models primarily on overall Top-1 Accuracy. | Highlighted that beverage dominance skews raw accuracy; urged evaluation of balanced metrics and recommendation coverage. | **Added Macro-F1 & Top-2 Hit Rate**: Reported balanced metrics alongside Top-2 recommendation hit rates (98.4%). |
| **3** | **Promotional Discounts** | Proposed flat 15% promotional discounts across all transactions. | Warned that flat discounts cannibalize margin without guaranteeing basket expansion. | **Shifted to Threshold Promotions**: Converted discounts to basket-threshold rules (*"Spend LKR 2,500, receive 15% off"*). |
| **4** | **Demand Planning** | Treated the 30-day ARIMA forecast as a single monthly aggregate number. | Emphasized perishable inventory lead times (48-hour milk and bakery shelf-life). | **Linked 7-Day Seasonal Spikes to Daily Prep Sheets**: Tied day-of-week ARIMA indices to kitchen raw material ordering. |
| **5** | **Operational Targets** | Stated conversion rates and waste reductions as definitive factual predictions. | Clarified that targets in consultancy reports must be framed as *benchmarked aspirational KPIs*. | **Re-anchored Targets to F&B Industry Benchmarks**: Cross-referenced 14.5% conversion and <4.5% waste to published retail standards. |

---

### 4. Advisor Evaluation & Formal Sign-Off

```
CONSULTATION EVALUATION FORM:
- Problem Relevance to F&B Retail: [x] Exceptional   [ ] Satisfactory   [ ] Needs Improvement
- Statistical Rigor of Evaluation: [x] Exceptional   [ ] Satisfactory   [ ] Needs Improvement
- Feasibility of POS Implementation: [x] Exceptional   [ ] Satisfactory   [ ] Needs Improvement
- Overall Strategic Coherence:     [x] Exceptional   [ ] Satisfactory   [ ] Needs Improvement

ADVISOR REMARKS:
"The student team has presented an impressively thorough statistical analysis of coffee chain transactions.
The transition from purely academic modelling to pragmatic, edge-viable Linear Discriminant Analysis and
Seasonal ARIMA demand planning demonstrates genuine appreciation of commercial retail operational realities.
The inclusion of ethical governance and customer privacy safeguards completes a very robust consultancy submission."

Signed: Samantha Senanayake (Retail BI & Analytics Advisor)
Date: October 12, 2026
```
