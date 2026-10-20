-- ============================================================
-- 05_business_insights.sql
-- RFM Customer Segmentation in Pure SQL (SQL Server / T-SQL)
-- Segment-level summaries from the final view.
-- Run after 04_customer_segmentation.sql (creates the view).
-- ============================================================

USE RFM_Customer_Analytics;
GO

-- Segment summary: size, value and contribution
SELECT
    CustomerSegment,
    COUNT(*) AS TotalCustomers,
    CAST(SUM(Monetary) AS DECIMAL(18,2)) AS TotalMonetary,
    CAST(AVG(Monetary) AS DECIMAL(18,2)) AS AvgMonetaryPerCustomer,
    CAST(
        100.0 * SUM(Monetary)
        / SUM(SUM(Monetary)) OVER ()
        AS DECIMAL(6,2)
    ) AS MonetaryContributionPercent
FROM dbo.vw_Customer_RFM_Segments
GROUP BY CustomerSegment
ORDER BY TotalMonetary DESC;

-- Overall metrics
SELECT
    COUNT(*) AS TotalCustomers,
    CAST(SUM(Monetary) AS DECIMAL(18,2))
        AS TotalGrossPurchaseValue,
    CAST(AVG(RecencyDays) AS DECIMAL(10,2))
        AS AvgRecencyDays,
    CAST(AVG(Frequency * 1.0) AS DECIMAL(10,2))
        AS AvgPurchaseFrequency
FROM dbo.vw_Customer_RFM_Segments;
