# Nigeria-2026-Budget-Analysis
Data analysis and visualization of Nigeria's 2026 Federal Appropriation Budget (₦58.47T). Extracted 274 budget line items from PDF, cleaned in Excel, analyzed with PostgreSQL, and visualized with Power BI.


# Nigeria 2026 Federal Appropriation Budget — Data Analysis Project

## Overview
A complete data analysis pipeline analyzing Nigeria's ₦58.47 trillion 2026 Federal Appropriation Budget. The project extracts structured data from a 10-page PDF appropriation bill, cleans and restructures 274 budget line items, and answers three critical analytical questions using SQL analytics and Power BI visualization.

**Commissioned by:** Top-tier Nigerian television station for a prime-time investigative data journalism report  
**Target audience:** Everyday Nigerians — market traders, teachers, civil servants, parents  
**Status:**  Complete — All 3 dashboard pages, technical documentation, and analytical story delivered

---

## Key Findings

### Question 1 — Deficit & Debt Burden
Nigeria earns ₦33.2T but spends ₦58.5T. The ₦25.3T deficit (76.1% of revenue) is financed 91.14% by borrowing. Debt service consumes **47.92% of revenue** — nearly double the IMF 30% benchmark.

### Question 2 — Capital Expenditure Illusion
Of the ₦23.2T capital budget:
- ₦2.24T (9.6%) = Legacy contractor debts from 2024
- ₦3.42T (14.7%) = Loan-funded projects (new debt)
- ₦17.6T (75.6%) = True new self-funded investment

The headline is real, but 24.3% of the "capital budget" is not new investment.

### Question 3 — Healthcare Compliance Test
Nigeria's budget is **compliant** at 6.39% health spending (vs. 6% legal minimum) — but only **0.39 percentage points above the floor**. Remove the NIA Hospital (₦208Bn) and compliance fails. One building is the difference between meeting the law and violating it.

---

## Project Architecture

### Data Pipeline
1. **Extraction** — Tabula: PDF table extraction from 10-page Appropriation Bill
2. **Cleaning** — Microsoft Excel: Removed 22+ sheets of raw data, corrected 15+ data quality issues, added 4 analyst-created classification columns
3. **Analysis** — PostgreSQL: Built 16 named views across 3 analytical questions
4. **Visualization** — Power BI: 3 dashboard pages, 15+ charts, 6 KPI cards, sensitivity analysis
5. **Documentation** — MS Word: Full technical report (data documentation + analytical story)

### Key Files
- **`data/processed/nigeria_budget_2026_clean.csv`** — Final analysis-ready dataset (274 rows × 12 columns)
- **`sql/nigeria_budget_2026_views.sql`** — All 16 PostgreSQL views (757 lines)
- **`analysis/analytical_questions.md`** — The 3 questions, methodology, and findings
- **`documentation/nigeria_budget_2026_full_report.docx`** — Complete technical + analytical report

---

## Tools & Technologies Used
- **Tabula** — PDF table extraction
- **Microsoft Excel** — Data cleaning and restructuring
- **PostgreSQL (PGAdmin4)** — SQL analysis, 16 named views, CTE optimization
- **Microsoft Power BI** — Dashboard design, DAX measures, 15+ visualizations
- **Microsoft Word** — Technical documentation
- **Microsoft PowerPoint** — Presentation-ready slides

---

## Dataset Overview

### Dimensions
- **Rows:** 274 unique budget line items
- **Columns:** 12 (8 original + 4 analyst-created)
- **Coverage:** Full 2026 budget (Parts A–Q of Appropriation Schedule)
- **Time period:** Fiscal year ending 31 December 2026

### Column Dictionary
| Column | Type | Description |
|--------|------|-------------|
| `budget_year` | INT | 2026 |
| `line_item` | TEXT | Full budget line name (cleaned) |
| `budget_part` | VARCHAR | Part A through Q |
| `expenditure_type` | VARCHAR | Revenue \| Recurrent \| Capital \| Debt Service \| Statutory \| Financing |
| `sector` | VARCHAR | Health, Security & Defence, Infrastructure, etc. (13 sectors) |
| `capital_nature` | VARCHAR | New Investment \| Carryover Obligation \| Loan-Funded (capital rows only) |
| `is_health_eligible` | BOOLEAN | TRUE for 15 lines counted toward Section 4 health compliance |
| `amount_ngn` | BIGINT | Naira amount (negative = deduction) |

---

## Data Quality & Cleaning Decisions

### Issues Encountered & Fixed
1. **Revenue Figure Correction** — Raw positive-sum returned ₦40.70T vs. official ₦33.20T. Root cause: GOE gross row (₦9.4T) was double-counted. Resolution: Hardcoded the official bill aggregate (₦33,199,317,039,550) directly into fiscal position view.

2. **Truncated Text in PDF** — Tabula truncated long line item names mid-word (e.g., "AGRICULTURE AND FOO SECURITY"). **Fix:** Completed all 15+ truncated names manually from PDF.

3. **Header Row Repetition** — "SCHEDULE / 2026 BUDGET PROPOSAL" headers extracted as data rows. **Fix:** Removed during cleaning.

4. **Floating Decimals** — INEC amount extracted as 1013778401602.079956. **Fix:** Rounded to integer naira.

5. **Negative Amounts** — 6 deduction rows carry negative signs. **Fix:** Preserved intentionally; excluded from revenue totals using `amount_ngn > 0` filters.

6. **Carriage Returns** — _x000D_ characters embedded in text. **Fix:** Stripped during Excel cleaning.

### Analyst-Created Columns (Classification Decisions)
- **`expenditure_type`** — Grouped all 274 rows into 6 categories (Revenue, Recurrent, Capital, Debt Service, Statutory, Financing)
- **`sector`** — Assigned each MDA to 1 of 13 policy sectors (Health, Security, Infrastructure, etc.)
- **`capital_nature`** — For 106 capital rows, classified as: New Investment (₦17.56T), Loan-Funded (₦3.42T), or Carryover Obligation (₦2.24T)
- **`is_health_eligible`** — Boolean flag for the 15 specific lines counted toward Section 4 legal health compliance test

All decisions are fully documented in the SQL views and Word report.

---

## Analytical Approach

### The 3 Questions Investigated

#### Q1 — How does Nigeria's debt obligation compare to its revenue?
**Method:** Fiscal position aggregation + ratio analysis  
**Views:** `vw_q1_fiscal_position`, `vw_q1_revenue_sources`, `vw_q1_expenditure_summary`, `vw_q1_debt_composition`, `vw_q1_financing_breakdown`, `vw_q1_kobo_per_naira`  
**Key Insight:** Every naira earned, Nigeria spends 1.76 naira. Debt service alone = 47.92% of revenue.

#### Q2 — How much of the ₦23.2T capital budget is genuinely new investment?
**Method:** Capital nature decomposition + legacy debt extraction  
**Views:** `vw_q4_capital_nature_summary`, `vw_q4_carryover_items`, `vw_q4_loan_funded_items`, `vw_q4_true_capital_summary`, `vw_q4_top_mda_new_investment`  
**Key Insight:** ₦2.24T is unpaid 2024 contractor bills. ₦3.42T is new loan-funded projects. Only ₦17.6T is true new self-funded investment.

#### Q3 — Does the budget meet its own health spending law?
**Method:** Section 4 compliance test + sensitivity scenario analysis  
**Views:** `vw_q5_compliance_test`, `vw_q5_health_line_items`, `vw_q5_health_by_type`, `vw_q5_sensitivity_scenarios`, `vw_q5_health_vs_security`  
**Key Insight:** Compliance at 6.39% — but removing one facility (NIA Hospital, ₦208Bn) drops it below 6%. Compliance margin is 0.39 percentage points.

---

## SQL Highlights

### Complex Queries Used
- **CTE-based aggregations** — Multi-stage calculations with common table expressions
- **Window functions** — Percentage calculations and cumulative totals
- **Conditional aggregation** — CASE-based filtering within SUM() operations
- **Cross-join fiscal constants** — Hardcoded official figures joined against line-item calculations

### Sample: Fiscal Position View
```sql
WITH revenue AS (
    SELECT 33199317039550::NUMERIC AS gross_revenue  -- Official bill figure
),
expenditure AS (
    SELECT SUM(amount_ngn) AS total_expenditure
    FROM budget_projections
    WHERE expenditure_type NOT IN ('Revenue', 'Financing')
),
debt AS (
    SELECT SUM(amount_ngn) AS debt_service
    FROM budget_projections
    WHERE expenditure_type = 'Debt Service'
)
SELECT
    r.gross_revenue,
    e.total_expenditure,
    (r.gross_revenue - e.total_expenditure) AS fiscal_deficit,
    ROUND(d.debt_service * 100.0 / r.gross_revenue, 2) AS debt_svc_pct_of_revenue,
    -- ... more calculations
FROM revenue r, expenditure e, debt d;
```

See full views in `sql/nigeria_budget_2026_views.sql` (757 lines, 16 views).

---

## Power BI Dashboard Pages

### Page 1 — Deficit & Debt Burden
- 6 KPI cards (revenue, expenditure, deficit, ratios)
- IMF debt service gauge (47.92% vs. 30% benchmark)
- Revenue source donut (Federation Account = 56.74%)
- Expenditure bar (Capital, Debt Service, Recurrent, Statutory)
- Debt composition bar (Domestic, Foreign, Sinking)
- Financing donut (91.14% borrowing)
- Kobo-per-naira bar (reference line at 100 kobo)

### Page 2 — Capital Expenditure Illusion
- 3 KPI cards (True New Investment ₦17.56T, Loan-Funded ₦3.42T, Carryover ₦2.24T)
- Capital nature donut (visual decomposition)
- Waterfall/decomposition bar (Total → Carryover → Loans → True New)
- Legacy debts bar (6 carryover items, ₦1.7T contractor liabilities)
- Loan-funded bar (12 multilateral/bilateral projects)
- Top MDAs bar (Ministry of Works dominates at ₦3.07T)

### Page 3 — Healthcare Compliance Test
- 6 KPI cards (total budget, debt service, net budget, health threshold, actual health, margin)
- Section 4 Verdict card (COMPLIANT — green)
- Compliance gauge (6.39% vs. 6% legal minimum)
- Health line items bar (15 items, green/red for uncontested/contested)
- Health by type donut (Recurrent 48.76%, Capital 43.33%, Statutory 7.90%)
- Sensitivity scenarios bar (Baseline 6.39% → -NIA Hospital 5.90% → Strictest 5.76%)
- Health vs Security bar (Security = 2.41× Health budget)


## Key Learnings & Challenges

### Challenge 1: Revenue Figure Mismatch
**Problem:** Summing all positive revenue rows returned ₦40.70T, not the official ₦33.20T.  
**Root cause:** GOE gross row (₦9.4T) was already netted via the GOE operating surplus, creating a double-count.  
**Resolution:** Used the official aggregate from the bill (₦33,199,317,039,550) as a hardcoded constant — the most accurate and defensible approach.  
**Lesson:** Never assume row-level sums match aggregates in official documents. Always investigate.

### Challenge 2: CTE Scope in UNION ALL
**Problem:** Sensitivity scenario view failed with "relation nb does not exist" — CTEs were not visible across UNION ALL branches.  
**Solution:** Inlined all CTE calculations directly into each UNION branch.  
**Lesson:** PostgreSQL CTEs have lexical scope — they don't propagate across UNION unless the entire UNION sits inside the CTE definition.

### Challenge 3: Non-Technical Audience Translation
**Problem:** Dashboard KPI cards showed raw numbers (58,472.6 billion); viewers found it dense.  
**Solution:** Paired all large numbers with contextual analogies ("For every ₦1 earned, Nigeria spends ₦1.76") in the written report.  
**Lesson:** Data visualization is 50% numbers, 50% narrative. The numbers are useless without the story.

---

## Metrics & Impact

| Metric | Value |
|--------|-------|
| Dataset size | 274 rows, 12 columns |
| SQL views | 16 named views (757 lines) |
| Dashboard pages | 3 complete pages |
| Charts/visuals | 15+ |
| Time to complete | ~80 hours (extraction, cleaning, analysis, documentation) |
| Data quality issues fixed | 22 |
| Analytical findings | 3 critical questions answered |
| Audience reach | Broadcast-ready for Nigerian prime-time television |

---

## Files Included in This Repository

### Data
- `data/raw/2026_Appropriation_Bill.pdf` — Source document (10 pages)
- `data/processed/nigeria_budget_2026_clean.csv` — Final analysis-ready dataset

### SQL
- `sql/nigerian_federal_budget.sql` — Original ad-hoc queries
- `sql/nigeria_budget_2026_views.sql` — 16 production views (757 lines)

### Analysis & Documentation
- `analysis/data_cleaning_notes.md` — Every cleaning decision with justification
- `analysis/analytical_questions.md` — The 3 questions, methodology, detailed findings
- `documentation/nigeria_budget_2026_full_report.docx` — Full technical report (16 pages)
- `documentation/data_dictionary.md` — Column-by-column reference
- `documentation/methodology.md` — Data extraction, cleaning, and analysis workflow

### Visualizations
- `visuals/page_1_deficit_debt_burden.png` — Dashboard page 1 screenshot
- `visuals/page_2_capital_expenditure.png` — Dashboard page 2 screenshot
- `visuals/page_3_healthcare_compliance.png` — Dashboard page 3 screenshot
- `power_bi/nigeria_budget_2026_dashboard.pbix` — Power BI dashboard file (if shareable)

### Reference
- `README.md` — This file
- `tools_used.md` — Full list of tools, versions, and setup notes

---

## How This Project Demonstrates Data Skills

 **Data Extraction** — Tabula, PDF parsing, structured data recovery  
 **Data Cleaning** — Handling truncation, formatting errors, deduplication, type coercion  
 **Data Transformation** — Creating analytical columns, classification schemes, feature engineering  
 **SQL Analytics** — CTEs, window functions, conditional aggregation, view design  
 **Statistical Analysis** — Ratio analysis, sensitivity testing, percentage calculations  
 **Data Visualization** — KPI design, multi-page dashboards, colour-coding by meaning, gauge and waterfall charts  
 **Communication** — Technical documentation + non-technical narrative, writing for a broadcast audience  
 **Problem-solving** — Debugging revenue mismatches, CTE scoping, data quality investigation  

---

