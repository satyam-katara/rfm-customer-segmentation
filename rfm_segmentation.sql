-- ============================================================
-- #4 RFM Customer Segmentation in Pure SQL
-- Dataset: UCI Online Retail II  (table: retail, loaded by bootstrap.py)
-- Run:  sqlite3 retail.db < rfm_segmentation.sql
-- ============================================================

-- STEP 1: clean BEFORE scoring anything.
-- Drop: guest checkouts (no CustomerID), cancelled invoices (start with 'C'),
--       returns/negative quantities, zero/negative prices.
DROP VIEW IF EXISTS rfm_clean;
CREATE VIEW rfm_clean AS
SELECT
    CustomerID,
    InvoiceNo,
    InvoiceDate,                       -- ISO 'YYYY-MM-DD', set by bootstrap.py
    Quantity,
    UnitPrice,
    Quantity * UnitPrice AS LineTotal
FROM retail
WHERE CustomerID IS NOT NULL
  AND substr(InvoiceNo, 1, 1) != 'C'
  AND Quantity  > 0
  AND UnitPrice > 0;

-- STEP 2: RFM base per customer, via CTEs.
-- Recency = days since last purchase, measured against the latest
-- invoice date in the data (the "snapshot date").
DROP VIEW IF EXISTS rfm_base;
CREATE VIEW rfm_base AS
WITH snapshot AS (
    SELECT date(max(InvoiceDate)) AS snap_date FROM rfm_clean
)
SELECT
    c.CustomerID,
    CAST(julianday((SELECT snap_date FROM snapshot))
         - julianday(date(max(c.InvoiceDate))) AS INTEGER) AS recency_days,
    COUNT(DISTINCT c.InvoiceNo) AS frequency,
    ROUND(SUM(c.LineTotal), 2) AS monetary
FROM rfm_clean c
GROUP BY c.CustomerID;

-- STEP 3: score each dimension 1-5 with NTILE, concatenate the RFM code.
-- Higher score = better on all three axes:
--   r_score: NTILE over recency DESC  -> 5 = bought most recently
--   f_score: NTILE over frequency ASC  -> 5 = buys most often
--   m_score: NTILE over monetary ASC   -> 5 = spends the most
DROP VIEW IF EXISTS rfm_scored;
CREATE VIEW rfm_scored AS
SELECT
    CustomerID,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC)    AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC)     AS m_score
FROM rfm_base;

-- STEP 4: map the 125 possible codes into 8 named segments.
-- Every (r,f) combination is covered exactly once; m_score is kept
-- for revenue-share math, not for the segment name.
DROP VIEW IF EXISTS rfm_segments;
CREATE VIEW rfm_segments AS
SELECT
    s.*,
    (CAST(r_score AS TEXT) || CAST(f_score AS TEXT) || CAST(m_score AS TEXT)) AS rfm_code,
    CASE
        WHEN r_score >= 4 AND f_score >= 4      THEN 'Champions'
        WHEN r_score >=  3 AND f_score >= 4      THEN 'Loyal Customers'
        WHEN r_score >=  4 AND f_score >= 2      THEN 'Potential Loyalists'
        WHEN r_score  =  5 AND f_score  = 1      THEN 'New Customers'
        WHEN r_score >=  3 AND f_score  = 1      THEN 'Promising'
        WHEN r_score  =  3 AND f_score IN (2,3)  THEN 'Need Attention'
        WHEN r_score <=  2 AND f_score >= 3      THEN 'At Risk'
        ELSE 'Hibernating'
    END AS segment
FROM rfm_scored s;

-- ============ DELIVERABLE 1: segment sizes + revenue share ============
SELECT
    segment,
    COUNT(*)                                              AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)     AS pct_customers,
    ROUND(SUM(monetary), 2)                               AS revenue,
    ROUND(100.0 * SUM(monetary)
          / SUM(SUM(monetary)) OVER (), 1)                AS pct_revenue,
    ROUND(AVG(monetary), 2)                               AS avg_revenue_per_customer
FROM rfm_segments
GROUP BY segment
ORDER BY revenue DESC;

-- ============ DELIVERABLE 2: the reusable segmentation view ============
-- rfm_segments is the view: CustomerID | recency_days | frequency |
-- monetary | r_score | f_score | m_score | rfm_code | segment
-- Peek at the top of each end of the spectrum:
-- SELECT * FROM rfm_segments WHERE segment = 'Champions' ORDER BY monetary DESC LIMIT 20;
-- SELECT * FROM rfm_segments WHERE segment = 'At Risk'  ORDER BY recency_days DESC LIMIT 20;

-- ============ SANITY CHECK: codes stay within the 125 grid ============
-- SELECT COUNT(DISTINCT rfm_code) AS distinct_codes FROM rfm_segments;  -- expect <= 125
