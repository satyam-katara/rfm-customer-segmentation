-- ============================================================
-- STEP 1: SELECT THE DATABASE
-- ============================================================
USE RFM_Customer_Analytics;
GO


-- ============================================================
-- STEP 2: CUSTOMER TENURE
-- First eligible purchase date per customer (the final RFM view
-- has no FirstPurchaseDate, so it comes from the transaction
-- view). Saved into a temp table for the next steps.
-- ============================================================
IF OBJECT_ID('tempdb..#CustomerTenure') IS NOT NULL
    DROP TABLE #CustomerTenure;

SELECT
    Customer_ID,
    MIN(InvoiceDate) AS FirstPurchaseDate
INTO #CustomerTenure
FROM dbo.vw_OnlineRetail_All
WHERE
    Invoice NOT LIKE 'C%'
    AND Quantity > 0
    AND Price > 0
    AND Customer_ID IS NOT NULL
GROUP BY Customer_ID;

SELECT COUNT(*) AS CustomersWithTenure FROM #CustomerTenure;
GO


-- ============================================================
-- STEP 3: CLV PER CUSTOMER
-- Tenure, average purchase value, purchases per month, 12-month
-- CLV and the recently-active flag for every segmented customer.
-- Saved into a temp table for the next steps.
-- ============================================================
IF OBJECT_ID('tempdb..#CustomerCLV') IS NOT NULL
    DROP TABLE #CustomerCLV;

SELECT
    Customer_ID,
    CustomerSegment,
    RecencyDays,
    Frequency,
    Monetary,
    TenureMonths,
    Monetary * 1.0 / Frequency AS AvgPurchaseValue,
    Frequency * 1.0 / TenureMonths AS PurchasesPerMonth,
    -- CLV: observed value annualised at the customer's rate
    (Monetary * 1.0 / Frequency)
        * (Frequency * 1.0 / TenureMonths)
        * 12 AS CLV_12mo,
    CASE
        WHEN RecencyDays <= 180 THEN 1
        ELSE 0
    END AS RecentlyActive
INTO #CustomerCLV
FROM
(
    SELECT
        s.Customer_ID,
        s.CustomerSegment,
        s.RecencyDays,
        s.Frequency,
        s.Monetary,
        DATEDIFF(
            MONTH,
            t.FirstPurchaseDate,
            s.LastPurchaseDate
        ) + 1 AS TenureMonths
    FROM dbo.vw_Customer_RFM_Segments s
    INNER JOIN #CustomerTenure t
        ON t.Customer_ID = s.Customer_ID
) AS x;

-- Quick check: top 5 customers by CLV
SELECT TOP 5
    Customer_ID,
    CustomerSegment,
    TenureMonths,
    CAST(AvgPurchaseValue AS DECIMAL(18,2)) AS AvgPurchaseValue,
    CAST(PurchasesPerMonth AS DECIMAL(10,2)) AS PurchasesPerMonth,
    CAST(CLV_12mo AS DECIMAL(18,2)) AS CLV_12mo,
    RecentlyActive
FROM #CustomerCLV
ORDER BY CLV_12mo DESC;
GO


-- ============================================================
-- STEP 4: RETENTION RATE PER SEGMENT
-- Share of customers with a purchase in the last 180 days.
-- Used to adjust CLV in the summary (Step 5).
-- ============================================================
IF OBJECT_ID('tempdb..#SegmentRetention') IS NOT NULL
    DROP TABLE #SegmentRetention;

SELECT
    CustomerSegment,
    AVG(CAST(RecentlyActive AS FLOAT)) AS RetentionRate
INTO #SegmentRetention
FROM #CustomerCLV
GROUP BY CustomerSegment;

-- Quick check: 5 rows, one per segment
SELECT * FROM #SegmentRetention;
GO


-- ============================================================
-- STEP 5: SEGMENT CLV SUMMARY  (main result)
-- CLV per segment: simple 12-month CLV and retention-adjusted
-- CLV, with the CLV column added to the segment summary.
-- ============================================================
WITH SegmentMedian AS
(
    SELECT DISTINCT
        CustomerSegment,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CLV_12mo)
            OVER (PARTITION BY CustomerSegment) AS MedianCLV
    FROM #CustomerCLV
)
SELECT
    c.CustomerSegment,
    COUNT(*) AS TotalCustomers,
    CAST(SUM(c.Monetary) AS DECIMAL(18,2)) AS TotalMonetary,
    CAST(AVG(c.Monetary) AS DECIMAL(18,2))
        AS AvgMonetaryPerCustomer,
    CAST(AVG(c.AvgPurchaseValue) AS DECIMAL(18,2))
        AS AvgPurchaseValue,
    CAST(AVG(c.PurchasesPerMonth) AS DECIMAL(10,2))
        AS AvgPurchasesPerMonth,
    CAST(AVG(c.TenureMonths * 1.0) AS DECIMAL(10,2))
        AS AvgTenureMonths,
    CAST(AVG(c.RecencyDays * 1.0) AS DECIMAL(10,2))
        AS AvgRecencyDays,
    CAST(AVG(c.RecentlyActive * 1.0) AS DECIMAL(5,2))
        AS RecentlyActiveShare,
    CAST(AVG(c.CLV_12mo) AS DECIMAL(18,2))
        AS AvgCLVPerCustomer,
    CAST(m.MedianCLV AS DECIMAL(18,2))
        AS MedianCLVPerCustomer,
    CAST(SUM(c.CLV_12mo) AS DECIMAL(18,2)) AS TotalCLV,
    CAST(
        100.0 * SUM(c.CLV_12mo)
        / SUM(SUM(c.CLV_12mo)) OVER ()
        AS DECIMAL(6,2)
    ) AS CLVSharePercent,
    CAST(AVG(c.CLV_12mo * r.RetentionRate) AS DECIMAL(18,2))
        AS AvgCLVAdjPerCustomer,
    CAST(SUM(c.CLV_12mo * r.RetentionRate) AS DECIMAL(18,2))
        AS TotalCLVAdj,
    CAST(
        100.0 * SUM(c.CLV_12mo * r.RetentionRate)
        / SUM(SUM(c.CLV_12mo * r.RetentionRate)) OVER ()
        AS DECIMAL(6,2)
    ) AS CLVAdjSharePercent
FROM #CustomerCLV c
INNER JOIN #SegmentRetention r
    ON r.CustomerSegment = c.CustomerSegment
INNER JOIN SegmentMedian m
    ON m.CustomerSegment = c.CustomerSegment
GROUP BY
    c.CustomerSegment,
    m.MedianCLV
ORDER BY TotalCLVAdj DESC;
GO


-- ============================================================
-- STEP 6: OVERALL CLV TOTALS
-- One row: total and average CLV for the whole customer base.
-- ============================================================
SELECT
    COUNT(*) AS TotalCustomers,
    CAST(SUM(c.CLV_12mo) AS DECIMAL(18,2)) AS TotalCLV,
    CAST(AVG(c.CLV_12mo) AS DECIMAL(18,2))
        AS AvgCLVPerCustomer,
    CAST(SUM(c.CLV_12mo * r.RetentionRate) AS DECIMAL(18,2))
        AS TotalCLVAdj,
    CAST(AVG(c.CLV_12mo * r.RetentionRate) AS DECIMAL(18,2))
        AS AvgCLVAdjPerCustomer
FROM #CustomerCLV c
INNER JOIN #SegmentRetention r
    ON r.CustomerSegment = c.CustomerSegment;
GO


-- ============================================================
-- STEP 7: VALIDATION
-- Every segmented customer must have a tenure row and a CLV row.
-- MissingTenure and MissingCLV must both be 0.
-- ============================================================
SELECT
    COUNT(*) AS SegmentedCustomers,
    COUNT(t.Customer_ID) AS CustomersWithTenure,
    COUNT(*) - COUNT(t.Customer_ID) AS MissingTenure,
    COUNT(v.Customer_ID) AS CustomersWithCLV,
    COUNT(*) - COUNT(v.Customer_ID) AS MissingCLV
FROM dbo.vw_Customer_RFM_Segments s
LEFT JOIN #CustomerTenure t
    ON t.Customer_ID = s.Customer_ID
LEFT JOIN #CustomerCLV v
    ON v.Customer_ID = s.Customer_ID;
GO
