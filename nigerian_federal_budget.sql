CREATE TABLE budget_projections (
id SERIAL PRIMARY KEY,
budget_year INT NOT NULL, -- e.g., 2026
currency VARCHAR(10) DEFAULT 'NGN', -- e.g., NGN, USD
head_no VARCHAR(50), -- Numeric or alphanumeric code
line_item TEXT NOT NULL, -- Specific item description
budget_part VARCHAR(50), -- e.g., Part A, Part 1
part_label TEXT, -- Label for the budget part
expenditure_type VARCHAR(50), -- e.g., Personnel, Overhead
sector VARCHAR(100), -- e.g., Education, Health
sub_sector VARCHAR(100), -- e.g., Primary Health Care
capital_nature VARCHAR(50), -- e.g., Capital, Recurrent
is_health_eligible BOOLEAN DEFAULT FALSE, -- True/False flag
amount_ngn NUMERIC(20, 2) -- High precision for large figures
);



SELECT
column_name,
data_type,
is_nullable,
column_default,
character_maximum_length
FROM
information_schema.columns
WHERE
table_name = 'budget_projections'
ORDER BY
ordinal_position;


-- Q2.1: Master summary of all budget components
SELECT
    expenditure_type,
    COUNT(*)                             AS line_items,
    SUM(amount_ngn)                      AS total_amount_ngn,
    ROUND(SUM(amount_ngn)::NUMERIC
          / 1e12, 2)                     AS amount_trillion,
    ROUND(SUM(amount_ngn) * 100.0
          / SUM(SUM(amount_ngn)) OVER (), 2) AS pct_of_all_flows
FROM budget_projections
GROUP BY expenditure_type
ORDER BY total_amount_ngn DESC;



-- Q2.2: Total allocation per sector (expenditure rows only)
SELECT
    sector,
    COUNT(*)                              AS line_items,
    SUM(amount_ngn)                       AS total_ngn,
    ROUND(SUM(amount_ngn)::NUMERIC/1e9,1) AS amount_billion,
    ROUND(SUM(amount_ngn) * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE expenditure_type NOT IN ('Revenue','Financing')
    ), 2)                                  AS pct_of_expenditure
FROM budget_projections
WHERE expenditure_type NOT IN ('Revenue','Financing')
GROUP BY sector
ORDER BY total_ngn DESC;



-- Q2.3: Capital expenditure classified by investment nature
SELECT
    capital_nature,
    COUNT(*)                              AS line_items,
    SUM(amount_ngn)                       AS total_ngn,
    ROUND(SUM(amount_ngn)::NUMERIC/1e9,1) AS amount_billion,
    ROUND(SUM(amount_ngn) * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE expenditure_type = 'Capital'
    ), 2)                                  AS pct_of_capital
FROM budget_projections
WHERE expenditure_type = 'Capital'
GROUP BY capital_nature
ORDER BY total_ngn DESC;


-- Q2.4: The ten biggest individual allocations in the budget
SELECT
    head_no,
    line_item,
    expenditure_type,
    sector,
    ROUND(amount_ngn::NUMERIC/1e9,2) AS amount_billion
FROM budget_projections
WHERE expenditure_type NOT IN ('Revenue','Financing')
  AND amount_ngn > 0
ORDER BY amount_ngn DESC
LIMIT 10;



-- Q3.1: Compute the full fiscal position — revenue, expenditure, deficit
SELECT
    SUM(CASE WHEN expenditure_type = 'Revenue'
             AND amount_ngn > 0 THEN amount_ngn ELSE 0 END)
                               AS gross_revenue,
    SUM(CASE WHEN expenditure_type NOT IN ('Revenue','Financing')
             THEN amount_ngn ELSE 0 END)
                               AS total_expenditure,
    SUM(CASE WHEN expenditure_type = 'Revenue'
             AND amount_ngn > 0 THEN amount_ngn ELSE 0 END)
    - SUM(CASE WHEN expenditure_type NOT IN ('Revenue','Financing')
               THEN amount_ngn ELSE 0 END)
                               AS fiscal_deficit,
    ROUND(
        ABS(SUM(CASE WHEN expenditure_type = 'Revenue'
                     AND amount_ngn > 0 THEN amount_ngn ELSE 0 END)
            - SUM(CASE WHEN expenditure_type NOT IN ('Revenue','Financing')
                       THEN amount_ngn ELSE 0 END))
        * 100.0
        / SUM(CASE WHEN expenditure_type = 'Revenue'
                   AND amount_ngn > 0 THEN amount_ngn ELSE 0 END)
    , 2)                       AS deficit_pct_of_revenue
FROM budget_projections;



-- Q3.2: Debt service as a share of revenue and total budget
SELECT
    SUM(CASE WHEN expenditure_type = 'Debt Service'
             THEN amount_ngn ELSE 0 END)   AS total_debt_service,
    SUM(CASE WHEN expenditure_type = 'Revenue'
             AND amount_ngn > 0
             THEN amount_ngn ELSE 0 END)   AS total_revenue,
    ROUND(
        SUM(CASE WHEN expenditure_type = 'Debt Service'
                 THEN amount_ngn ELSE 0 END) * 100.0
        / SUM(CASE WHEN expenditure_type = 'Revenue'
                   AND amount_ngn > 0
                   THEN amount_ngn ELSE 0 END)
    , 2)                                    AS debt_pct_of_revenue,
    ROUND(
        SUM(CASE WHEN expenditure_type = 'Debt Service'
                 THEN amount_ngn ELSE 0 END) * 100.0
        / 58472628944759
    , 2)                                    AS debt_pct_of_total_budget
FROM budget_projections;

-- Also break down domestic vs foreign debt
SELECT sub_sector, amount_ngn,
    ROUND(amount_ngn * 100.0 / 15909361631657, 2) AS pct_of_debt_service
FROM budget_projections
WHERE expenditure_type = 'Debt Service'
ORDER BY amount_ngn DESC;



-- Q3.3: Compare total spend across critical sectors (recurrent + capital)
SELECT
    sector,
    SUM(CASE WHEN expenditure_type = 'Recurrent'
             THEN amount_ngn ELSE 0 END)   AS recurrent_ngn,
    SUM(CASE WHEN expenditure_type = 'Capital'
             THEN amount_ngn ELSE 0 END)   AS capital_ngn,
    SUM(CASE WHEN expenditure_type IN ('Recurrent','Capital')
             THEN amount_ngn ELSE 0 END)   AS combined_ngn,
    ROUND(
        SUM(CASE WHEN expenditure_type IN ('Recurrent','Capital')
                 THEN amount_ngn ELSE 0 END) * 100.0
        / 58472628944759
    , 2)                                    AS pct_of_total_budget
FROM budget_projections
WHERE sector IN (
    'Security & Defence','Health','Education',
    'Social Development','Infrastructure')
  AND expenditure_type IN ('Recurrent','Capital')
GROUP BY sector
ORDER BY combined_ngn DESC;



-- Q3.4: Identify all arrears and backlog items in the budget
SELECT
    head_no,
    line_item,
    expenditure_type,
    ROUND(amount_ngn::NUMERIC/1e9,2) AS amount_billion
FROM budget_projections
WHERE LOWER(line_item) LIKE '%arrear%'
   OR LOWER(line_item) LIKE '%outstanding%'
   OR LOWER(line_item) LIKE '%liability%'
   OR LOWER(line_item) LIKE '%backlog%'
   OR LOWER(line_item) LIKE '%shortfall%'
ORDER BY amount_ngn DESC;

-- Aggregate total arrears burden
SELECT
    COUNT(*)                              AS arrears_lines,
    ROUND(SUM(amount_ngn)::NUMERIC/1e9,2) AS total_arrears_billion
FROM budget_projections
WHERE LOWER(line_item) LIKE '%arrear%'
   OR LOWER(line_item) LIKE '%outstanding%'
   OR LOWER(line_item) LIKE '%liability%'
   OR LOWER(line_item) LIKE '%backlog%'
   OR LOWER(line_item) LIKE '%shortfall%';



-- Full revenue vs expenditure vs deficit with financing breakdown
WITH revenue_summary AS (
    SELECT
        SUM(CASE WHEN amount_ngn > 0 THEN amount_ngn ELSE 0 END) AS gross_revenue,
        SUM(CASE WHEN sub_sector LIKE '%Main Pool%'
                 OR sub_sector LIKE '%VAT Pool%'
                 OR sub_sector LIKE '%Stamp Duty%'
             THEN amount_ngn ELSE 0 END)   AS federation_account,
        SUM(CASE WHEN sub_sector LIKE '%Independent%'
             THEN amount_ngn ELSE 0 END)   AS independent_revenue,
        SUM(CASE WHEN sub_sector = 'Aid & Grants'
             THEN amount_ngn ELSE 0 END)   AS aid_grants
    FROM budget_projections WHERE expenditure_type = 'Revenue'
),
expenditure_summary AS (
    SELECT
        SUM(amount_ngn)                             AS total_expenditure,
        SUM(CASE WHEN expenditure_type = 'Debt Service'
                 THEN amount_ngn ELSE 0 END)        AS debt_service,
        SUM(CASE WHEN expenditure_type = 'Recurrent'
                 THEN amount_ngn ELSE 0 END)        AS recurrent,
        SUM(CASE WHEN expenditure_type = 'Capital'
                 THEN amount_ngn ELSE 0 END)        AS capital,
        SUM(CASE WHEN expenditure_type = 'Statutory Transfer'
                 THEN amount_ngn ELSE 0 END)        AS statutory_transfers
    FROM budget_projections
    WHERE expenditure_type NOT IN ('Revenue','Financing')
),
financing AS (
    SELECT
        SUM(amount_ngn)                             AS total_financing,
        SUM(CASE WHEN sub_sector = 'Debt Financing'
                 THEN amount_ngn ELSE 0 END)        AS debt_financing,
        SUM(CASE WHEN sub_sector = 'Asset Sales'
                 THEN amount_ngn ELSE 0 END)        AS asset_sales,
        SUM(CASE WHEN sub_sector LIKE '%Loan%'
                 THEN amount_ngn ELSE 0 END)        AS project_loans
    FROM budget_projections WHERE expenditure_type = 'Financing'
)
SELECT
    r.gross_revenue,
    e.total_expenditure,
    (r.gross_revenue - e.total_expenditure)       AS fiscal_deficit,
    ROUND((r.gross_revenue - e.total_expenditure)
          * 100.0 / r.gross_revenue, 2)           AS deficit_pct_revenue,
    e.debt_service,
    ROUND(e.debt_service * 100.0
          / r.gross_revenue, 2)                   AS debt_svc_pct_revenue,
    f.total_financing,
    f.debt_financing,
    ROUND(f.debt_financing * 100.0
          / f.total_financing, 2)                 AS borrowing_pct_financing
FROM revenue_summary r, expenditure_summary e, financing f;


-- Revenue breakdown: what percentage each source contributes
SELECT
    part_label                            AS revenue_source,
	    COUNT(*)                              AS items,
    SUM(amount_ngn)                       AS amount_ngn,
    ROUND(SUM(amount_ngn)::NUMERIC/1e9,2) AS amount_billion,
    ROUND(SUM(amount_ngn) * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE expenditure_type = 'Revenue' AND amount_ngn > 0
    ), 2)                                  AS pct_of_revenue
FROM budget_projections
WHERE expenditure_type = 'Revenue' AND amount_ngn > 0
GROUP BY part_label
ORDER BY amount_ngn DESC;


-- For every ₦1 of revenue, how many kobo go to each expenditure type?
SELECT
    expenditure_type,
    SUM(amount_ngn)                         AS amount_ngn,
    ROUND(SUM(amount_ngn) * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE expenditure_type = 'Revenue' AND amount_ngn > 0
    ), 2)                                    AS kobo_per_naira,
    ROUND(SUM(amount_ngn)::NUMERIC / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE expenditure_type = 'Revenue' AND amount_ngn > 0
    ), 4)                                    AS ratio_to_revenue
FROM budget_projections
WHERE expenditure_type NOT IN ('Revenue','Financing')
GROUP BY expenditure_type
ORDER BY amount_ngn DESC;


-- How the ₦25.3 trillion deficit is being financed
SELECT
    line_item                             AS financing_source,
    amount_ngn,
    ROUND(amount_ngn::NUMERIC/1e9,2)      AS amount_billion,
    ROUND(amount_ngn * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE expenditure_type = 'Financing'
    ), 2)                                  AS pct_of_total_financing
FROM budget_projections
WHERE expenditure_type = 'Financing'
ORDER BY amount_ngn DESC;


-- Master breakdown: new investment vs. inherited obligations vs. loan-funded
SELECT
    capital_nature,
    COUNT(*)                               AS line_items,
    SUM(amount_ngn)                        AS total_ngn,
    ROUND(SUM(amount_ngn)::NUMERIC/1e9,2)  AS amount_billion,
    ROUND(SUM(amount_ngn) * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE expenditure_type = 'Capital'
    ), 2)                                   AS pct_of_capital_budget
FROM budget_projections
WHERE expenditure_type = 'Capital'
GROUP BY capital_nature
ORDER BY total_ngn DESC;


-- Every capital line item classified as a carryover obligation
SELECT
    head_no,
    line_item,
    sector,
    ROUND(amount_ngn::NUMERIC/1e9,2)  AS amount_billion,
    ROUND(amount_ngn * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE capital_nature = 'Carryover Obligation'
    ), 2)                              AS pct_of_carryover
FROM budget_projections
WHERE capital_nature = 'Carryover Obligation'
ORDER BY amount_ngn DESC;



-- All multilateral/bilateral loan-funded capital projects and their sectors
SELECT
    head_no,
    line_item,
    sector,
    ROUND(amount_ngn::NUMERIC/1e9,2)   AS amount_billion,
    ROUND(amount_ngn * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE capital_nature = 'Loan-Funded'
    ), 2)                               AS pct_of_loan_funded
FROM budget_projections
WHERE capital_nature = 'Loan-Funded'
ORDER BY amount_ngn DESC;



-- Net true capital investment = total capital MINUS carryovers MINUS loan-funded
SELECT
    SUM(amount_ngn)                         AS total_capital,
    SUM(CASE WHEN capital_nature = 'Carryover Obligation'
             THEN amount_ngn ELSE 0 END)     AS carryover_obligations,
    SUM(CASE WHEN capital_nature = 'Loan-Funded'
             THEN amount_ngn ELSE 0 END)     AS loan_funded,
    SUM(CASE WHEN capital_nature = 'New Investment'
             THEN amount_ngn ELSE 0 END)     AS new_investment,
    ROUND(
        SUM(CASE WHEN capital_nature = 'New Investment'
                 THEN amount_ngn ELSE 0 END) * 100.0
        / SUM(amount_ngn)
    , 2)                                     AS new_investment_pct
FROM budget_projections
WHERE expenditure_type = 'Capital';


-- Which MDAs receive the largest genuine new capital allocations?
SELECT
    line_item                              AS ministry,
    sector,
    ROUND(amount_ngn::NUMERIC/1e9,2)       AS new_capital_billion,
    ROUND(amount_ngn * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE capital_nature = 'New Investment'
    ), 2)                                   AS pct_of_new_investment
FROM budget_projections
WHERE capital_nature = 'New Investment'
  AND expenditure_type = 'Capital'
  AND amount_ngn > 100000000000   -- Above ₦100bn threshold
ORDER BY amount_ngn DESC
LIMIT 10;


-- SECTION 4 COMPLIANCE: 6% health spend vs. budget net of debt service
WITH parameters AS (
    SELECT
        58472628944759                        AS total_budget,
        15909361631657                        AS debt_service,
        (58472628944759 - 15909361631657)     AS net_budget,
        (58472628944759 - 15909361631657)
        * 0.06                                AS legal_threshold_6pct
),
actual_health AS (
    SELECT SUM(amount_ngn) AS health_spend
    FROM budget_projections
    WHERE is_health_eligible = TRUE
)
SELECT
    p.total_budget,
    p.debt_service,
    p.net_budget,
    ROUND(p.legal_threshold_6pct)             AS legal_threshold,
    h.health_spend                            AS actual_health_spend,
    (h.health_spend - p.legal_threshold_6pct) AS surplus_shortfall,
    ROUND(h.health_spend * 100.0
          / p.net_budget, 2)                  AS actual_health_pct,
    CASE WHEN h.health_spend >= p.legal_threshold_6pct
         THEN 'COMPLIANT'
         ELSE 'NON-COMPLIANT — LEGAL VIOLATION'
    END                                       AS compliance_status
FROM parameters p, actual_health h;



-- Every line item that qualifies as health spending under Section 4
SELECT
    head_no,
    line_item,
    expenditure_type,
    part_label,
    ROUND(amount_ngn::NUMERIC/1e9,3)   AS amount_billion,
    ROUND(amount_ngn * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE is_health_eligible = TRUE
    ), 2)                               AS pct_of_health_total
FROM budget_projections
WHERE is_health_eligible = TRUE
ORDER BY amount_ngn DESC;


-- Health budget composition: how is it split across spending types?
SELECT
    expenditure_type,
    COUNT(*)                               AS line_items,
    SUM(amount_ngn)                        AS total_ngn,
    ROUND(SUM(amount_ngn)::NUMERIC/1e9,2)  AS amount_billion,
    ROUND(SUM(amount_ngn) * 100.0 / (
        SELECT SUM(amount_ngn) FROM budget_projections
        WHERE is_health_eligible = TRUE
    ), 2)                                   AS pct_of_health_budget
FROM budget_projections
WHERE is_health_eligible = TRUE
GROUP BY expenditure_type
ORDER BY total_ngn DESC;


-- Sensitivity test: compliance with and without disputed items
WITH net_budget AS (
    SELECT (58472628944759 - 15909361631657) AS nb
),
full_health AS (
    SELECT SUM(amount_ngn) AS total
    FROM budget_projections WHERE is_health_eligible = TRUE
),
without_nia AS (
    SELECT SUM(amount_ngn) AS total
    FROM budget_projections
    WHERE is_health_eligible = TRUE
    AND line_item NOT LIKE '%INTELLIGENCE AGENCY%HOSPITAL%'
),
without_nia_mdas AS (
    SELECT SUM(amount_ngn) AS total
    FROM budget_projections
    WHERE is_health_eligible = TRUE
    AND line_item NOT LIKE '%INTELLIGENCE AGENCY%HOSPITAL%'
    AND line_item NOT LIKE '%NEW MDAs TAKE-OFF%'
)
SELECT
    'Full Inclusion (Baseline)'          AS scenario,
    f.total                              AS health_spend,
    ROUND(f.total * 100.0 / nb.nb, 2)   AS pct_of_net_budget,
    CASE WHEN f.total >= nb.nb * 0.06
         THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END AS status
FROM full_health f, net_budget nb
UNION ALL
SELECT
    'Exclude NIA Hospital'               AS scenario,
    n.total,
    ROUND(n.total * 100.0 / nb.nb, 2),
    CASE WHEN n.total >= nb.nb * 0.06
         THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END
FROM without_nia n, net_budget nb
UNION ALL
SELECT
    'Exclude NIA + New MDA Grants'        AS scenario,
    m.total,
    ROUND(m.total * 100.0 / nb.nb, 2),
    CASE WHEN m.total >= nb.nb * 0.06
         THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END
FROM without_nia_mdas m, net_budget nb
ORDER BY health_spend DESC;



-- Compare total health investment to total security & defence spend
SELECT
    sector,
    SUM(CASE WHEN expenditure_type = 'Recurrent'
             THEN amount_ngn ELSE 0 END)    AS recurrent_ngn,
    SUM(CASE WHEN expenditure_type = 'Capital'
             THEN amount_ngn ELSE 0 END)    AS capital_ngn,
    SUM(CASE WHEN expenditure_type IN ('Recurrent','Capital','Statutory Transfer')
             THEN amount_ngn ELSE 0 END)    AS total_ngn,
    ROUND(
        SUM(CASE WHEN expenditure_type IN ('Recurrent','Capital','Statutory Transfer')
                 THEN amount_ngn ELSE 0 END) * 100.0
        / 58472628944759
    , 2)                                     AS pct_of_total_budget
FROM budget_projections
WHERE sector IN ('Health','Security & Defence')
  AND expenditure_type NOT IN ('Revenue','Financing')
GROUP BY sector

UNION ALL

SELECT
    'Health (is_health_eligible=TRUE)' AS sector,
    SUM(CASE WHEN expenditure_type = 'Recurrent'
             THEN amount_ngn ELSE 0 END),
    SUM(CASE WHEN expenditure_type = 'Capital'
             THEN amount_ngn ELSE 0 END),
    SUM(amount_ngn),
    ROUND(SUM(amount_ngn) * 100.0 / 58472628944759, 2)
FROM budget_projections
WHERE is_health_eligible = TRUE
ORDER BY total_ngn DESC;









-- =============================================================================
-- NIGERIA 2026 FEDERAL APPROPRIATION BUDGET
-- POSTGRESQL VIEWS FOR POWER BI
-- Table: budget_projections
-- Total Views: 16 (6 for Q1 | 5 for Q4 | 5 for Q5)
-- =============================================================================
-- HOW TO USE:
--   1. Run this entire script once in your PostgreSQL database.
--   2. In Power BI Desktop: Get Data → PostgreSQL → connect to your DB.
--   3. Each view appears as a selectable table. Import the ones for each page.
--   4. Build visuals directly on the imported view tables.
-- =============================================================================


-- =============================================================================
-- PAGE 1: QUESTION 1 — DEFICIT & DEBT BURDEN
-- "How does Nigeria's debt obligation compare to its revenue, and what does
--  it mean that the government is borrowing ₦25.27 trillion to fund this budget?"
--
-- Views:  vw_q1_fiscal_position       → KPI cards (Revenue, Expenditure, Deficit)
--         vw_q1_revenue_sources       → Donut / bar: where revenue comes from
--         vw_q1_expenditure_summary   → Stacked bar: expenditure type breakdown
--         vw_q1_debt_composition      → Bar: domestic vs foreign vs sinking fund
--         vw_q1_financing_breakdown   → Donut: how the deficit is financed
--         vw_q1_kobo_per_naira        → Bar: cost of each expenditure per ₦1 earned
-- =============================================================================


-- -----------------------------------------------------------------------------
-- VIEW 1 OF 6 — vw_q1_fiscal_position
-- PURPOSE : Single-row KPI table for all headline fiscal cards on the dashboard.
--           Powers: Revenue card, Expenditure card, Deficit card,
--                   Debt-service-to-revenue % gauge, Borrowing % card.
-- VISUALS : Card, KPI, Gauge
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q1_fiscal_position AS
WITH revenue AS (
    SELECT SUM(amount_ngn) AS gross_revenue
    FROM   budget_projections
    WHERE  expenditure_type = 'Revenue'
    AND    amount_ngn > 0
),
expenditure AS (
    SELECT SUM(amount_ngn) AS total_expenditure
    FROM   budget_projections
    WHERE  expenditure_type NOT IN ('Revenue', 'Financing')
),
debt AS (
    SELECT SUM(amount_ngn) AS debt_service
    FROM   budget_projections
    WHERE  expenditure_type = 'Debt Service'
),
financing AS (
    SELECT SUM(amount_ngn)                                             AS total_financing,
           SUM(CASE WHEN sub_sector = 'Debt Financing'
                    THEN amount_ngn ELSE 0 END)                        AS debt_financing
    FROM   budget_projections
    WHERE  expenditure_type = 'Financing'
)
SELECT
    -- Core fiscal figures (raw NGN for card visuals)
    r.gross_revenue                                                        AS gross_revenue_ngn,
    e.total_expenditure                                                    AS total_expenditure_ngn,
    (r.gross_revenue - e.total_expenditure)                                AS fiscal_deficit_ngn,

    -- Trillions (for clean label display)
    ROUND(r.gross_revenue      / 1e12, 2)                                  AS revenue_trillion,
    ROUND(e.total_expenditure  / 1e12, 2)                                  AS expenditure_trillion,
    ROUND(ABS(r.gross_revenue - e.total_expenditure) / 1e12, 2)            AS deficit_trillion,

    -- Ratios (for gauges and KPI targets)
    ROUND(ABS(r.gross_revenue - e.total_expenditure)
          * 100.0 / r.gross_revenue, 2)                                    AS deficit_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / r.gross_revenue, 2)                    AS debt_svc_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / e.total_expenditure, 2)                AS debt_svc_pct_of_expenditure,
    ROUND(f.debt_financing * 100.0 / f.total_financing, 2)                AS borrowing_pct_of_financing,

    -- Reference constants for gauge targets in Power BI
    30.00                                                                  AS imf_debt_threshold_pct,
    6.00                                                                   AS health_legal_threshold_pct
FROM revenue r, expenditure e, debt d, financing f;


-- -----------------------------------------------------------------------------
-- VIEW 2 OF 6 — vw_q1_revenue_sources
-- PURPOSE : One row per revenue part. Shows composition of the ₦33.2T revenue.
-- VISUALS : Donut chart, Stacked bar, Treemap
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q1_revenue_sources AS
SELECT
    part_label                                                             AS revenue_source,
    COUNT(*)                                                               AS line_items,
    SUM(amount_ngn)                                                        AS amount_ngn,
    ROUND(SUM(amount_ngn) / 1e9, 2)                                        AS amount_billion,
    ROUND(SUM(amount_ngn) / 1e12, 3)                                       AS amount_trillion,
    ROUND(
        SUM(amount_ngn) * 100.0
        / (SELECT SUM(amount_ngn)
           FROM   budget_projections
           WHERE  expenditure_type = 'Revenue'
           AND    amount_ngn > 0)
    , 2)                                                                   AS pct_of_revenue
FROM   budget_projections
WHERE  expenditure_type = 'Revenue'
AND    amount_ngn > 0
GROUP  BY part_label
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 3 OF 6 — vw_q1_expenditure_summary
-- PURPOSE : One row per expenditure type. Powers the main breakdown bar chart
--           showing how the ₦58.5T is split across all spending categories.
-- VISUALS : Stacked bar, Clustered bar, 100% stacked bar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q1_expenditure_summary AS
SELECT
    expenditure_type,
    COUNT(*)                                                               AS line_items,
    SUM(amount_ngn)                                                        AS amount_ngn,
    ROUND(SUM(amount_ngn) / 1e9,  2)                                       AS amount_billion,
    ROUND(SUM(amount_ngn) / 1e12, 3)                                       AS amount_trillion,
    ROUND(
        SUM(amount_ngn) * 100.0 / 58472628944759
    , 2)                                                                   AS pct_of_total_budget,
    ROUND(
        SUM(amount_ngn) * 100.0
        / (SELECT SUM(amount_ngn)
           FROM   budget_projections
           WHERE  expenditure_type = 'Revenue'
           AND    amount_ngn > 0)
    , 2)                                                                   AS pct_of_revenue,
    -- sort_order lets Power BI sort the bars in a logical sequence
    CASE expenditure_type
        WHEN 'Debt Service'        THEN 1
        WHEN 'Recurrent'           THEN 2
        WHEN 'Capital'             THEN 3
        WHEN 'Statutory Transfer'  THEN 4
        WHEN 'Revenue'             THEN 5
        WHEN 'Financing'           THEN 6
        ELSE 7
    END                                                                    AS sort_order
FROM   budget_projections
WHERE  expenditure_type NOT IN ('Revenue', 'Financing')
GROUP  BY expenditure_type
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 4 OF 6 — vw_q1_debt_composition
-- PURPOSE : Breaks debt service into domestic, foreign, and sinking fund.
--           Also includes debt vs revenue for the ratio bar.
-- VISUALS : Clustered bar, Donut, 100% stacked bar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q1_debt_composition AS
SELECT
    sub_sector                                                             AS debt_component,
    amount_ngn,
    ROUND(amount_ngn / 1e9,  2)                                            AS amount_billion,
    ROUND(amount_ngn / 1e12, 3)                                            AS amount_trillion,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  expenditure_type = 'Debt Service'
        )
    , 2)                                                                   AS pct_of_debt_service,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  expenditure_type = 'Revenue'
            AND    amount_ngn > 0
        )
    , 2)                                                                   AS pct_of_revenue
FROM   budget_projections
WHERE  expenditure_type = 'Debt Service'
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 5 OF 6 — vw_q1_financing_breakdown
-- PURPOSE : Shows the three financing items that plug the ₦25.3T deficit.
-- VISUALS : Donut chart, Waterfall chart
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q1_financing_breakdown AS
SELECT
    line_item                                                              AS financing_source,
    sub_sector,
    amount_ngn,
    ROUND(amount_ngn / 1e9,  2)                                            AS amount_billion,
    ROUND(amount_ngn / 1e12, 3)                                            AS amount_trillion,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  expenditure_type = 'Financing'
        )
    , 2)                                                                   AS pct_of_total_financing,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  expenditure_type = 'Revenue'
            AND    amount_ngn > 0
        )
    , 2)                                                                   AS pct_of_revenue
FROM   budget_projections
WHERE  expenditure_type = 'Financing'
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 6 OF 6 — vw_q1_kobo_per_naira
-- PURPOSE : For every ₦1 of revenue earned, how many kobo go to each
--           expenditure type? Makes the deficit tangible for a general audience.
-- VISUALS : Bar chart, Bullet chart, Clustered bar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q1_kobo_per_naira AS
WITH revenue_total AS (
    SELECT SUM(amount_ngn) AS rev
    FROM   budget_projections
    WHERE  expenditure_type = 'Revenue'
    AND    amount_ngn > 0
)
SELECT
    expenditure_type,
    SUM(b.amount_ngn)                                                      AS amount_ngn,
    ROUND(SUM(b.amount_ngn) / 1e9, 2)                                      AS amount_billion,
    ROUND(SUM(b.amount_ngn) * 100.0 / r.rev, 2)                           AS kobo_per_naira,
    ROUND(SUM(b.amount_ngn) / r.rev, 4)                                    AS ratio_to_revenue,
    -- flag: does this exceed the revenue it draws from?
    CASE WHEN SUM(b.amount_ngn) > r.rev THEN 'Exceeds Revenue' ELSE 'Within Revenue' END
                                                                           AS revenue_status
FROM   budget_projections b, revenue_total r
WHERE  b.expenditure_type NOT IN ('Revenue', 'Financing')
GROUP  BY b.expenditure_type, r.rev
ORDER  BY kobo_per_naira DESC;


-- =============================================================================
-- PAGE 2: QUESTION 4 — THE CAPITAL EXPENDITURE ILLUSION
-- "Nigeria allocates ₦23.2 trillion to capital expenditure — but how much of
--  that is genuinely new investment versus outstanding contractor liabilities,
--  loan repayments, and pre-existing obligations dressed up as capital spending?"
--
-- Views:  vw_q4_capital_nature_summary   → Donut: 3-way capital split (KPI cards)
--         vw_q4_carryover_items          → Bar: all 6 carryover line items
--         vw_q4_loan_funded_items        → Bar: all 12 loan-funded projects
--         vw_q4_true_capital_summary     → Waterfall: total → deductions → true new
--         vw_q4_top_mda_new_investment   → Bar: top MDAs by genuine new capital
-- =============================================================================


-- -----------------------------------------------------------------------------
-- VIEW 1 OF 5 — vw_q4_capital_nature_summary
-- PURPOSE : Aggregates capital budget into 3 categories plus KPI-level totals.
--           One row per capital_nature. Also includes a totals row for cards.
-- VISUALS : Donut chart, KPI cards (via DAX on this view), Clustered bar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q4_capital_nature_summary AS
SELECT
    COALESCE(capital_nature, 'Uncategorised')                             AS capital_nature,
    COUNT(*)                                                               AS line_items,
    SUM(amount_ngn)                                                        AS amount_ngn,
    ROUND(SUM(amount_ngn) / 1e9,  2)                                       AS amount_billion,
    ROUND(SUM(amount_ngn) / 1e12, 3)                                       AS amount_trillion,
    ROUND(
        SUM(amount_ngn) * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  expenditure_type = 'Capital'
        )
    , 2)                                                                   AS pct_of_capital_budget,
    ROUND(
        SUM(amount_ngn) * 100.0 / 58472628944759
    , 2)                                                                   AS pct_of_total_budget,
    -- sort for consistent donut/bar ordering
    CASE capital_nature
        WHEN 'New Investment'      THEN 1
        WHEN 'Loan-Funded'         THEN 2
        WHEN 'Carryover Obligation'THEN 3
        ELSE 4
    END                                                                    AS sort_order
FROM   budget_projections
WHERE  expenditure_type = 'Capital'
GROUP  BY capital_nature
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 2 OF 5 — vw_q4_carryover_items
-- PURPOSE : Every individual line item tagged as a Carryover Obligation.
--           Shows the legacy debts packaged inside the capital budget.
-- VISUALS : Horizontal bar chart, Table visual
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q4_carryover_items AS
SELECT
    head_no,
    line_item,
    sector,
    sub_sector,
    amount_ngn,
    ROUND(amount_ngn / 1e9, 2)                                             AS amount_billion,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  capital_nature = 'Carryover Obligation'
        )
    , 2)                                                                   AS pct_of_carryover_total,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  expenditure_type = 'Capital'
        )
    , 2)                                                                   AS pct_of_capital_budget
FROM   budget_projections
WHERE  capital_nature = 'Carryover Obligation'
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 3 OF 5 — vw_q4_loan_funded_items
-- PURPOSE : All multilateral/bilateral loan-funded capital projects.
--           Each is new spending but financed by new borrowing —
--           they expand future debt service, not just the current deficit.
-- VISUALS : Horizontal bar chart, Table visual, Treemap
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q4_loan_funded_items AS
SELECT
    head_no,
    line_item,
    sector,
    sub_sector,
    amount_ngn,
    ROUND(amount_ngn / 1e9, 2)                                             AS amount_billion,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  capital_nature = 'Loan-Funded'
        )
    , 2)                                                                   AS pct_of_loan_funded_total,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  expenditure_type = 'Capital'
        )
    , 2)                                                                   AS pct_of_capital_budget
FROM   budget_projections
WHERE  capital_nature = 'Loan-Funded'
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 4 OF 5 — vw_q4_true_capital_summary
-- PURPOSE : Single-row + labelled-rows table for a waterfall chart and cards.
--           Deconstructs ₦23.2T → minus carryover → minus loan-funded → true new.
-- VISUALS : Waterfall chart, KPI card row
-- NOTE    : For Power BI waterfall, each row is one bar segment. The 'step' column
--           controls the left-to-right sequence. 'is_subtraction' flags negative bars.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q4_true_capital_summary AS
WITH capital_base AS (
    SELECT
        SUM(amount_ngn)                                                      AS total_capital,
        SUM(CASE WHEN capital_nature = 'Carryover Obligation'
                 THEN amount_ngn ELSE 0 END)                                 AS carryover,
        SUM(CASE WHEN capital_nature = 'Loan-Funded'
                 THEN amount_ngn ELSE 0 END)                                 AS loan_funded,
        SUM(CASE WHEN capital_nature = 'New Investment'
                 THEN amount_ngn ELSE 0 END)                                 AS new_investment
    FROM budget_projections
    WHERE expenditure_type = 'Capital'
)
SELECT
    step,
    category_label,
    amount_ngn,
    ROUND(amount_ngn / 1e9,  2)                                            AS amount_billion,
    ROUND(amount_ngn / 1e12, 3)                                            AS amount_trillion,
    is_subtraction,
    is_total,
    ROUND(amount_ngn * 100.0 / (SELECT total_capital FROM capital_base), 2) AS pct_of_capital
FROM (
    SELECT 1 AS step, 'Total Capital Budget'     AS category_label,
           total_capital   AS amount_ngn, FALSE  AS is_subtraction, FALSE AS is_total FROM capital_base
    UNION ALL
    SELECT 2, 'Less: Carryover Obligations',
           -carryover,                     TRUE,  FALSE FROM capital_base
    UNION ALL
    SELECT 3, 'Less: Loan-Funded Projects',
           -loan_funded,                   TRUE,  FALSE FROM capital_base
    UNION ALL
    SELECT 4, 'TRUE New Investment',
           new_investment,                 FALSE, TRUE  FROM capital_base
) waterfall_rows
ORDER BY step;


-- -----------------------------------------------------------------------------
-- VIEW 5 OF 5 — vw_q4_top_mda_new_investment
-- PURPOSE : Top MDAs by genuine new capital investment (above ₦50Bn).
--           Reveals which ministries command the real development budget.
-- VISUALS : Horizontal bar chart, Treemap, Table
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q4_top_mda_new_investment AS
SELECT
    line_item                                                              AS ministry,
    sector,
    sub_sector,
    amount_ngn,
    ROUND(amount_ngn / 1e9, 2)                                             AS amount_billion,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  capital_nature = 'New Investment'
        )
    , 2)                                                                   AS pct_of_new_investment,
    ROUND(
        amount_ngn * 100.0 / 58472628944759
    , 2)                                                                   AS pct_of_total_budget
FROM   budget_projections
WHERE  capital_nature = 'New Investment'
AND    expenditure_type = 'Capital'
AND    amount_ngn >= 50000000000          -- ₦50Bn minimum for meaningful bars
ORDER  BY amount_ngn DESC;


-- =============================================================================
-- PAGE 3: QUESTION 5 — THE HEALTHCARE COMPLIANCE TEST
-- "Section 4 of the Appropriation Bill legally mandates that healthcare
--  investment must not be less than 6% of total budget net of debt service —
--  does the 2026 budget actually meet this constitutional obligation?"
--
-- Views:  vw_q5_compliance_test        → KPI cards + gauge: pass/fail test
--         vw_q5_health_line_items      → Bar: all 15 health-eligible lines
--         vw_q5_health_by_type         → Donut: recurrent vs capital vs statutory
--         vw_q5_sensitivity_scenarios  → Bar: 3-scenario compliance test
--         vw_q5_health_vs_security     → Clustered bar: health vs defence comparison
-- =============================================================================


-- -----------------------------------------------------------------------------
-- VIEW 1 OF 5 — vw_q5_compliance_test
-- PURPOSE : Single-row compliance result. Powers all KPI cards on the page
--           (total budget, debt, net budget, threshold, actual spend, margin)
--           and the gauge/compliance status banner.
-- VISUALS : Card, KPI, Gauge, Conditional formatting on status field
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q5_compliance_test AS
WITH parameters AS (
    SELECT
        58472628944759::NUMERIC                                            AS total_budget,
        15909361631657::NUMERIC                                            AS debt_service,
        (58472628944759 - 15909361631657)::NUMERIC                         AS net_budget,
        (58472628944759 - 15909361631657) * 0.06                           AS legal_threshold
),
actual AS (
    SELECT SUM(amount_ngn) AS health_spend
    FROM   budget_projections
    WHERE  is_health_eligible = TRUE
)
SELECT
    -- Raw values (NGN) for cards
    p.total_budget,
    p.debt_service,
    p.net_budget,
    ROUND(p.legal_threshold, 0)                                            AS legal_threshold_ngn,
    a.health_spend                                                         AS actual_health_ngn,
    (a.health_spend - p.legal_threshold)                                   AS compliance_margin_ngn,

    -- Billions for cleaner display
    ROUND(p.total_budget   / 1e9, 2)                                       AS total_budget_billion,
    ROUND(p.debt_service   / 1e9, 2)                                       AS debt_service_billion,
    ROUND(p.net_budget     / 1e9, 2)                                       AS net_budget_billion,
    ROUND(p.legal_threshold/ 1e9, 2)                                       AS threshold_billion,
    ROUND(a.health_spend   / 1e9, 2)                                       AS actual_health_billion,
    ROUND((a.health_spend - p.legal_threshold) / 1e9, 2)                  AS margin_billion,

    -- Percentages for gauge
    ROUND(a.health_spend * 100.0 / p.net_budget, 2)                       AS actual_health_pct,
    6.00                                                                   AS legal_minimum_pct,
    ROUND((a.health_spend * 100.0 / p.net_budget) - 6.00, 2)              AS pct_above_minimum,

    -- Compliance verdict (use this field for conditional card colour in Power BI)
    CASE
        WHEN a.health_spend >= p.legal_threshold THEN 'COMPLIANT'
        ELSE 'NON-COMPLIANT'
    END                                                                    AS compliance_status,

    -- Binary flag for gauge fill and conditional formatting
    CASE WHEN a.health_spend >= p.legal_threshold THEN 1 ELSE 0 END       AS is_compliant
FROM parameters p, actual a;


-- -----------------------------------------------------------------------------
-- VIEW 2 OF 5 — vw_q5_health_line_items
-- PURPOSE : All 15 individual health-eligible line items ranked by size.
--           Allows drilling into what makes up the health total.
-- VISUALS : Horizontal bar chart, Table visual with conditional bars
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q5_health_line_items AS
SELECT
    head_no,
    line_item,
    expenditure_type,
    part_label,
    sector,
    sub_sector,
    amount_ngn,
    ROUND(amount_ngn / 1e9, 3)                                             AS amount_billion,
    ROUND(
        amount_ngn * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  is_health_eligible = TRUE
        )
    , 2)                                                                   AS pct_of_health_total,
    ROUND(
        amount_ngn * 100.0 / 58472628944759
    , 2)                                                                   AS pct_of_total_budget,
    -- flag controversial inclusions for colour-coding in Power BI
    CASE
        WHEN line_item LIKE '%INTELLIGENCE AGENCY%HOSPITAL%' THEN 'Contested'
        WHEN line_item LIKE '%NEW MDAs TAKE-OFF%'            THEN 'Contested'
        ELSE 'Uncontested'
    END                                                                    AS inclusion_status
FROM   budget_projections
WHERE  is_health_eligible = TRUE
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 3 OF 5 — vw_q5_health_by_type
-- PURPOSE : Aggregates health spend by expenditure type (Recurrent / Capital /
--           Statutory Transfer). Shows structural balance of health investment.
-- VISUALS : Donut chart, 100% stacked bar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q5_health_by_type AS
SELECT
    expenditure_type,
    COUNT(*)                                                               AS line_items,
    SUM(amount_ngn)                                                        AS amount_ngn,
    ROUND(SUM(amount_ngn) / 1e9, 2)                                        AS amount_billion,
    ROUND(
        SUM(amount_ngn) * 100.0 / (
            SELECT SUM(amount_ngn)
            FROM   budget_projections
            WHERE  is_health_eligible = TRUE
        )
    , 2)                                                                   AS pct_of_health_budget,
    -- sort for consistent donut slice order
    CASE expenditure_type
        WHEN 'Recurrent'           THEN 1
        WHEN 'Capital'             THEN 2
        WHEN 'Statutory Transfer'  THEN 3
        ELSE 4
    END                                                                    AS sort_order
FROM   budget_projections
WHERE  is_health_eligible = TRUE
GROUP  BY expenditure_type
ORDER  BY amount_ngn DESC;


-- -----------------------------------------------------------------------------
-- VIEW 4 OF 5 — vw_q5_sensitivity_scenarios
-- PURPOSE : Three compliance scenarios tested side by side:
--           (1) Full inclusion  (2) Exclude NIA Hospital  (3) Exclude NIA + MDA Grants
--           Reveals how fragile compliance is under stricter definitions.
-- VISUALS : Clustered bar chart, Table with conditional colour on status column
-- NOTE    : The 'scenario_order' column controls bar sequence in Power BI.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q5_sensitivity_scenarios AS
SELECT
    1                                                                   AS scenario_order,
    'Full Inclusion (Baseline)'                                         AS scenario_label,
    SUM(amount_ngn)                                                     AS health_spend_ngn,
    ROUND(SUM(amount_ngn) / 1e9, 2)                                     AS health_spend_billion,
    ROUND(SUM(amount_ngn) * 100.0
          / (58472628944759 - 15909361631657), 2)                       AS actual_pct,
    6.00                                                                AS threshold_pct,
    ROUND((SUM(amount_ngn) * 100.0
          / (58472628944759 - 15909361631657)) - 6, 2)                  AS margin_pct,
    ROUND((58472628944759 - 15909361631657) * 0.06 / 1e9, 2)           AS threshold_billion,
    CASE WHEN SUM(amount_ngn) >= (58472628944759 - 15909361631657) * 0.06
         THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END                     AS compliance_status,
    CASE WHEN SUM(amount_ngn) >= (58472628944759 - 15909361631657) * 0.06
         THEN 1 ELSE 0 END                                             AS is_compliant
FROM budget_projections
WHERE is_health_eligible = TRUE

UNION ALL

SELECT
    2,
    'Exclude NIA Hospital',
    SUM(amount_ngn),
    ROUND(SUM(amount_ngn) / 1e9, 2),
    ROUND(SUM(amount_ngn) * 100.0
          / (58472628944759 - 15909361631657), 2),
    6.00,
    ROUND((SUM(amount_ngn) * 100.0
          / (58472628944759 - 15909361631657)) - 6, 2),
    ROUND((58472628944759 - 15909361631657) * 0.06 / 1e9, 2),
    CASE WHEN SUM(amount_ngn) >= (58472628944759 - 15909361631657) * 0.06
         THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END,
    CASE WHEN SUM(amount_ngn) >= (58472628944759 - 15909361631657) * 0.06
         THEN 1 ELSE 0 END
FROM budget_projections
WHERE is_health_eligible = TRUE
AND   line_item NOT LIKE '%INTELLIGENCE AGENCY%HOSPITAL%'

UNION ALL

SELECT
    3,
    'Exclude NIA + New MDA Grants',
    SUM(amount_ngn),
    ROUND(SUM(amount_ngn) / 1e9, 2),
    ROUND(SUM(amount_ngn) * 100.0
          / (58472628944759 - 15909361631657), 2),
    6.00,
    ROUND((SUM(amount_ngn) * 100.0
          / (58472628944759 - 15909361631657)) - 6, 2),
    ROUND((58472628944759 - 15909361631657) * 0.06 / 1e9, 2),
    CASE WHEN SUM(amount_ngn) >= (58472628944759 - 15909361631657) * 0.06
         THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END,
    CASE WHEN SUM(amount_ngn) >= (58472628944759 - 15909361631657) * 0.06
         THEN 1 ELSE 0 END
FROM budget_projections
WHERE is_health_eligible = TRUE
AND   line_item NOT LIKE '%INTELLIGENCE AGENCY%HOSPITAL%'
AND   line_item NOT LIKE '%NEW MDAs TAKE-OFF%'

ORDER BY scenario_order;


-- -----------------------------------------------------------------------------
-- VIEW 5 OF 5 — vw_q5_health_vs_security
-- PURPOSE : Direct comparison of health-eligible spend vs Security & Defence.
--           Includes recurrent, capital, and combined figures for both sectors
--           so Power BI can build a side-by-side clustered bar.
-- VISUALS : Clustered bar chart, 100% stacked bar
-- NOTE    : Returns one row per sector per spending_type so it can be used
--           directly in a matrix or unpivoted for a grouped bar.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_q5_health_vs_security AS
-- Security & Defence from sector classification
SELECT
    'Security & Defence'                                                   AS sector_label,
    expenditure_type                                                       AS spending_type,
    SUM(amount_ngn)                                                        AS amount_ngn,
    ROUND(SUM(amount_ngn) / 1e9, 2)                                        AS amount_billion,
    ROUND(SUM(amount_ngn) * 100.0 / 58472628944759, 2)                    AS pct_of_budget,
    CASE expenditure_type WHEN 'Recurrent' THEN 1 WHEN 'Capital' THEN 2 ELSE 3 END AS sort_order
FROM   budget_projections
WHERE  sector = 'Security & Defence'
AND    expenditure_type IN ('Recurrent', 'Capital')
GROUP  BY expenditure_type

UNION ALL

-- Health (using is_health_eligible flag — the compliance-relevant definition)
SELECT
    'Health (Section 4 Eligible)'                                          AS sector_label,
    expenditure_type                                                       AS spending_type,
    SUM(amount_ngn),
    ROUND(SUM(amount_ngn) / 1e9, 2),
    ROUND(SUM(amount_ngn) * 100.0 / 58472628944759, 2),
    CASE expenditure_type WHEN 'Recurrent' THEN 1 WHEN 'Capital' THEN 2 ELSE 3 END
FROM   budget_projections
WHERE  is_health_eligible = TRUE
AND    expenditure_type IN ('Recurrent', 'Capital', 'Statutory Transfer')
GROUP  BY expenditure_type

UNION ALL

-- Totals row for each sector (for KPI cards and summary bar)
SELECT
    'Security & Defence'                                                   AS sector_label,
    'Total'                                                                AS spending_type,
    SUM(amount_ngn),
    ROUND(SUM(amount_ngn) / 1e9, 2),
    ROUND(SUM(amount_ngn) * 100.0 / 58472628944759, 2),
    0                                                                      AS sort_order
FROM   budget_projections
WHERE  sector = 'Security & Defence'
AND    expenditure_type IN ('Recurrent', 'Capital')

UNION ALL

SELECT
    'Health (Section 4 Eligible)'                                          AS sector_label,
    'Total'                                                                AS spending_type,
    SUM(amount_ngn),
    ROUND(SUM(amount_ngn) / 1e9, 2),
    ROUND(SUM(amount_ngn) * 100.0 / 58472628944759, 2),
    0
FROM   budget_projections
WHERE  is_health_eligible = TRUE
AND    expenditure_type NOT IN ('Revenue', 'Financing')

ORDER BY sector_label, sort_order;


-- Check what the view is actually returning
SELECT * FROM vw_q1_fiscal_position;

-- Then check the raw revenue rows to find the issue
SELECT
    head_no,
    line_item,
    part_label,
    amount_ngn,
    ROUND(amount_ngn / 1e12, 3) AS amount_trillion
FROM budget_projections
WHERE expenditure_type = 'Revenue'
ORDER BY amount_ngn DESC;



CREATE OR REPLACE VIEW vw_q1_fiscal_position AS
WITH revenue AS (
    SELECT SUM(amount_ngn) AS gross_revenue
    FROM   budget_projections
    WHERE  expenditure_type = 'Revenue'
    AND    amount_ngn > 0
    -- Exclude the GOE gross row to prevent double-count
    -- with the net GOE figure already captured elsewhere
    AND    sub_sector NOT IN (
               'GOEs - Gross',
               'GOEs - Operating Surplus Deduction'
           )
),
expenditure AS (
    SELECT SUM(amount_ngn) AS total_expenditure
    FROM   budget_projections
    WHERE  expenditure_type NOT IN ('Revenue', 'Financing')
),
debt AS (
    SELECT SUM(amount_ngn) AS debt_service
    FROM   budget_projections
    WHERE  expenditure_type = 'Debt Service'
),
financing AS (
    SELECT
        SUM(amount_ngn)                                          AS total_financing,
        SUM(CASE WHEN sub_sector = 'Debt Financing'
                 THEN amount_ngn ELSE 0 END)                     AS debt_financing
    FROM budget_projections
    WHERE expenditure_type = 'Financing'
)
SELECT
    r.gross_revenue                                              AS gross_revenue_ngn,
    e.total_expenditure                                          AS total_expenditure_ngn,
    (r.gross_revenue - e.total_expenditure)                      AS fiscal_deficit_ngn,

    ROUND(r.gross_revenue      / 1e12, 2)                        AS revenue_trillion,
    ROUND(e.total_expenditure  / 1e12, 2)                        AS expenditure_trillion,
    ROUND(ABS(r.gross_revenue
              - e.total_expenditure) / 1e12, 2)                  AS deficit_trillion,

    ROUND(ABS(r.gross_revenue - e.total_expenditure)
          * 100.0 / r.gross_revenue, 2)                          AS deficit_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / r.gross_revenue, 2)           AS debt_svc_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / e.total_expenditure, 2)       AS debt_svc_pct_of_expenditure,
    ROUND(f.debt_financing * 100.0 / f.total_financing, 2)       AS borrowing_pct_of_financing,

    30.00                                                        AS imf_debt_threshold_pct,
    6.00                                                         AS health_legal_threshold_pct
FROM revenue r, expenditure e, debt d, financing f;




SELECT
    revenue_trillion,
    expenditure_trillion,
    deficit_trillion,
    debt_svc_pct_of_revenue,
    borrowing_pct_of_financing
FROM vw_q1_fiscal_position;




-- See every revenue row and its amount
SELECT
    head_no,
    line_item,
    sub_sector,
    part_label,
    amount_ngn,
    ROUND(amount_ngn / 1e12, 4) AS amount_trillion
FROM budget_projections
WHERE expenditure_type = 'Revenue'
ORDER BY amount_ngn DESC;


SELECT
    sub_sector,
    amount_ngn,
    ROUND(amount_ngn / 1e12, 4) AS trillion
FROM budget_projections
WHERE expenditure_type = 'Revenue'
AND   amount_ngn > 0
ORDER BY amount_ngn DESC;




CREATE OR REPLACE VIEW vw_q1_fiscal_position AS
WITH revenue AS (
    SELECT SUM(amount_ngn) AS gross_revenue
    FROM   budget_projections
    WHERE  expenditure_type = 'Revenue'
    AND    amount_ngn > 0
    -- Exclude GOE gross figure: it is already netted via
    -- the Operating Surplus row captured in Independent Revenue
    AND    sub_sector != 'GOEs - Gross'
),
expenditure AS (
    SELECT SUM(amount_ngn) AS total_expenditure
    FROM   budget_projections
    WHERE  expenditure_type NOT IN ('Revenue', 'Financing')
),
debt AS (
    SELECT SUM(amount_ngn) AS debt_service
    FROM   budget_projections
    WHERE  expenditure_type = 'Debt Service'
),
financing AS (
    SELECT
        SUM(amount_ngn)                                           AS total_financing,
        SUM(CASE WHEN sub_sector = 'Debt Financing'
                 THEN amount_ngn ELSE 0 END)                      AS debt_financing
    FROM budget_projections
    WHERE expenditure_type = 'Financing'
)
SELECT
    r.gross_revenue                                               AS gross_revenue_ngn,
    e.total_expenditure                                           AS total_expenditure_ngn,
    (r.gross_revenue - e.total_expenditure)                       AS fiscal_deficit_ngn,

    ROUND(r.gross_revenue      / 1e12, 2)                         AS revenue_trillion,
    ROUND(e.total_expenditure  / 1e12, 2)                         AS expenditure_trillion,
    ROUND(ABS(r.gross_revenue
              - e.total_expenditure) / 1e12, 2)                   AS deficit_trillion,

    ROUND(ABS(r.gross_revenue - e.total_expenditure)
          * 100.0 / r.gross_revenue, 2)                           AS deficit_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / r.gross_revenue, 2)            AS debt_svc_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / e.total_expenditure, 2)        AS debt_svc_pct_of_expenditure,
    ROUND(f.debt_financing * 100.0 / f.total_financing, 2)        AS borrowing_pct_of_financing,

    30.00                                                         AS imf_debt_threshold_pct,
    6.00                                                          AS health_legal_threshold_pct
FROM revenue r, expenditure e, debt d, financing f;


SELECT
    revenue_trillion,
    expenditure_trillion,
    deficit_trillion,
    debt_svc_pct_of_revenue,
    borrowing_pct_of_financing
FROM vw_q1_fiscal_position;


-- Get the EXACT sub_sector text and amount for every 
-- positive revenue row so we can see what is being summed
SELECT
    sub_sector,
    ROUND(amount_ngn / 1e12, 4) AS trillion,
    amount_ngn
FROM budget_projections
WHERE expenditure_type = 'Revenue'
AND   amount_ngn > 0
ORDER BY amount_ngn DESC;


-- What is the sum without any exclusions?
SELECT
    ROUND(SUM(amount_ngn) / 1e12, 4) AS total_positive_revenue_trillion
FROM budget_projections
WHERE expenditure_type = 'Revenue'
AND   amount_ngn > 0;

-- What is the GOE gross row exact amount?
SELECT
    sub_sector,
    amount_ngn,
    ROUND(amount_ngn / 1e12, 4) AS trillion
FROM budget_projections
WHERE expenditure_type = 'Revenue'
AND   amount_ngn > 0
AND   line_item LIKE '%GOVERNMENT-OWNED ENTERPRISES%';


-- The appropriation bill computes aggregate revenue as:
-- Part C (FGN Net Federation Revenues) + Part D + Part E + Part F + Part G + Part H(net) + Part I
-- NOT as a simple sum of Part A minus Part B
-- Let us compute it the bill's way using part_label

SELECT
    part_label,
    SUM(amount_ngn)                        AS amount_ngn,
    ROUND(SUM(amount_ngn) / 1e12, 4)       AS trillion
FROM budget_projections
WHERE expenditure_type = 'Revenue'
GROUP BY part_label
ORDER BY amount_ngn DESC;



CREATE OR REPLACE VIEW vw_q1_fiscal_position AS
WITH revenue AS (
    -- Use the exact aggregate revenue figure stated in the
    -- 2026 Appropriation Bill Schedule (Page 2)
    SELECT 33199317039550::NUMERIC AS gross_revenue
),
expenditure AS (
    SELECT SUM(amount_ngn) AS total_expenditure
    FROM   budget_projections
    WHERE  expenditure_type NOT IN ('Revenue', 'Financing')
),
debt AS (
    SELECT SUM(amount_ngn) AS debt_service
    FROM   budget_projections
    WHERE  expenditure_type = 'Debt Service'
),
financing AS (
    SELECT
        SUM(amount_ngn)                                           AS total_financing,
        SUM(CASE WHEN sub_sector = 'Debt Financing'
                 THEN amount_ngn ELSE 0 END)                      AS debt_financing
    FROM budget_projections
    WHERE expenditure_type = 'Financing'
)
SELECT
    r.gross_revenue                                               AS gross_revenue_ngn,
    e.total_expenditure                                           AS total_expenditure_ngn,
    (r.gross_revenue - e.total_expenditure)                       AS fiscal_deficit_ngn,

    ROUND(r.gross_revenue      / 1e12, 2)                         AS revenue_trillion,
    ROUND(e.total_expenditure  / 1e12, 2)                         AS expenditure_trillion,
    ROUND(ABS(r.gross_revenue
              - e.total_expenditure) / 1e12, 2)                   AS deficit_trillion,

    ROUND(ABS(r.gross_revenue - e.total_expenditure)
          * 100.0 / r.gross_revenue, 2)                           AS deficit_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / r.gross_revenue, 2)            AS debt_svc_pct_of_revenue,
    ROUND(d.debt_service * 100.0 / e.total_expenditure, 2)        AS debt_svc_pct_of_expenditure,
    ROUND(f.debt_financing * 100.0 / f.total_financing, 2)        AS borrowing_pct_of_financing,

    30.00                                                         AS imf_debt_threshold_pct,
    6.00                                                          AS health_legal_threshold_pct
FROM revenue r, expenditure e, debt d, financing f;



SELECT
    revenue_trillion,
    expenditure_trillion,
    deficit_trillion,
    debt_svc_pct_of_revenue,
    borrowing_pct_of_financing
FROM vw_q1_fiscal_position;


SELECT DISTINCT sector_label, spending_type 
FROM vw_q5_health_vs_security 
ORDER BY sector_label;

-- =============================================================================
-- QUICK VERIFICATION — run these after creating all views to confirm outputs
-- =============================================================================

-- Check all 16 views were created
SELECT viewname
FROM   pg_views
WHERE  schemaname = 'public'
AND    viewname LIKE 'vw_q%'
ORDER  BY viewname;

-- Q1 spot checks
SELECT revenue_trillion, expenditure_trillion, deficit_trillion,
       debt_svc_pct_of_revenue, borrowing_pct_of_financing
FROM   vw_q1_fiscal_position;
-- Expected: 33.20 | 58.47 | 25.27 | 47.92 | 91.10

SELECT COUNT(*) FROM vw_q1_revenue_sources;   -- Expected: 7 rows
SELECT COUNT(*) FROM vw_q1_debt_composition;  -- Expected: 3 rows
SELECT COUNT(*) FROM vw_q1_financing_breakdown;-- Expected: 3 rows
SELECT COUNT(*) FROM vw_q1_kobo_per_naira;    -- Expected: 4 rows

-- Q4 spot checks
SELECT capital_nature, amount_trillion, pct_of_capital_budget
FROM   vw_q4_capital_nature_summary ORDER BY sort_order;
-- Expected: New Investment 17.56T 75.65% | Loan-Funded 3.42T 14.72% | Carryover 2.24T 9.64%

SELECT COUNT(*) FROM vw_q4_carryover_items;       -- Expected: 6 rows
SELECT COUNT(*) FROM vw_q4_loan_funded_items;     -- Expected: 12 rows
SELECT amount_billion FROM vw_q4_true_capital_summary WHERE is_total = TRUE;
-- Expected: 17561.23 (true new investment)

-- Q5 spot checks
SELECT actual_health_pct, compliance_status, margin_billion
FROM   vw_q5_compliance_test;
-- Expected: 6.39 | COMPLIANT | 165.50 (approx)

SELECT COUNT(*) FROM vw_q5_health_line_items;          -- Expected: 15 rows
SELECT COUNT(*) FROM vw_q5_sensitivity_scenarios;      -- Expected: 3 rows
SELECT scenario_label, actual_pct, compliance_status
FROM   vw_q5_sensitivity_scenarios ORDER BY scenario_order;
-- Expected:
-- Full Inclusion      6.39%  COMPLIANT
-- Exclude NIA         5.90%  NON-COMPLIANT
-- Exclude NIA + MDAs  5.76%  NON-COMPLIANT