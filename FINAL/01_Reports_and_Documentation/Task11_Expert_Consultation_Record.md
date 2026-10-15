# Expert Advisory Consultation Record

**Course:** IT3081 Statistical Modelling  
**Consultancy Client:** BladeGen Tech  
**Topic:** Retail Demand Forecasting, Point-of-Sale Recommendation Architecture & Model Governance  
**Date of Consultation:** October 12, 2026  
**Format:** Structured Advisory Discussion (Virtual / Video Conference)  

---

### Participant Details
- **Advisory Expert:** Senior Business Intelligence & Analytics Lead (F&B / Retail Systems)
- **Student Consultancy Team:** BladeGen Tech Analytics Team (Members 1, 2, 3, 4)

---

### Consultation Questions & Key Advisory Takeaways

#### 1. Real-World Model Selection in POS Environments
* **Question:** In our empirical tournament, Linear Discriminant Analysis (LDA) and Multinomial Logistic Regression achieved strong accuracy (~76.2%) and high Top-2 recommendation coverage (98.4%), while heavier tree ensembles required significantly higher compute. How does industry weigh model complexity against operational edge constraints?
* **Advisor Feedback:** In physical store environments, sub-50ms transaction latency and offline fault tolerance are paramount. Complex ensemble architectures or multi-layered neural models introduce cloud latency, inference overhead, and API failure risks at POS registers. Highly interpretable linear and discriminant models running directly on lightweight edge terminals provide the optimal balance of predictability, transparency, and operational stability.

#### 2. Class Imbalance and Product Category Baselines
* **Question:** How do commercial retailers handle natural dominance of coffee/beverage categories over food and merchandizing?
* **Advisor Feedback:** In high-volume coffee retail, beverage dominance is natural. Evaluating models solely on raw overall accuracy can be misleading because predicting the majority category dominates the score. Recommending a primary item paired with a secondary complement (Top-2 recommendation window) alongside evaluating Macro-F1 and Balanced Accuracy represents standard industry practice for cross-selling.

#### 3. Demand Forecasting & Capacity Smoothing
* **Question:** Our seasonal ARIMA demand forecasting model detected weekly cyclical spikes on Fridays and weekends, alongside post-holiday normalization across Q1. What practical actions do retail operators take with these projections?
* **Advisor Feedback:** Midweek demand troughs (e.g., Tuesdays/Wednesdays) should be targeted with time-limited app notifications or loyalty combo promotions to smooth store capacity. Conversely, weekend peaks require kitchen prep indexing and automated raw material reordering (milk, bakery items) 48 hours in advance to prevent stockouts without inducing food waste.

---

### Governance & Verification Sign-Off
- **Document Status:** Formally documented and incorporated into Task 11 and Task 12 strategic recommendations.
- **Signed by Consultancy Team:** BladeGen Tech Statistical Consulting Group
