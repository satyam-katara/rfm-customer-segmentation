-- ============================================================
-- 04_customer_segmentation.sql
-- RFM Customer Segmentation in Pure SQL (SQL Server / T-SQL)
-- Rule-based segments from RFM scores, the reusable final
-- view vw_Customer_RFM_Segments, and validation checks.
-- Segment rules:
--   Champions        : R >= 4 AND F >= 4 AND M >= 4
--   Loyal Customers  : R >= 3 AND F >= 4
--   At Risk          : R <= 2 AND F >= 3
--   Hibernating      : R <= 2 AND F <= 2
--   Other Customers  : everything else
-- ============================================================

USE RFM_Customer_Analytics;
GO

-- Segmentation (ad-hoc query)
WITH CustomerRFM AS
(
    SELECT
        Customer_ID,
        MAX(InvoiceDate) AS LastPurchaseDate,
        COUNT(DISTINCT Invoice) AS Frequency,
        SUM(Quantity * Price) AS Monetary
    FROM dbo.vw_OnlineRetail_All
    WHERE
        Invoice NOT LIKE 'C%'
        AND Quantity > 0
        AND Price > 0
        AND Customer_ID IS NOT NULL
    GROUP BY Customer_ID
),
RFM AS
(
    SELECT
        Customer_ID,
        DATEDIFF(
            DAY,
            LastPurchaseDate,
            DATEADD(
                DAY,
                1,
                (SELECT MAX(InvoiceDate)
                 FROM dbo.vw_OnlineRetail_All)
            )
        ) AS RecencyDays,
        Frequency,
        Monetary
    FROM CustomerRFM
),
RFMScoring AS
(
    SELECT
        Customer_ID,
        RecencyDays,
        Frequency,
        Monetary,
        NTILE(5) OVER (
            ORDER BY RecencyDays DESC
        ) AS R_Score,
        NTILE(5) OVER (
            ORDER BY Frequency ASC
        ) AS F_Score,
        NTILE(5) OVER (
            ORDER BY Monetary ASC
        ) AS M_Score
    FROM RFM
)
SELECT
    Customer_ID,
    RecencyDays,
    Frequency,
    Monetary,
    R_Score,
    F_Score,
    M_Score,
    CONCAT(R_Score, F_Score, M_Score) AS RFM_Score,
    CASE
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4
            THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 4
            THEN 'Loyal Customers'
        WHEN R_Score <= 2 AND F_Score >= 3
            THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score <= 2
            THEN 'Hibernating'
        ELSE 'Other Customers'
    END AS CustomerSegment
FROM RFMScoring
ORDER BY Customer_ID;

-- Segment summary (ad-hoc)
WITH CustomerRFM AS
(
    SELECT
        Customer_ID,
        MAX(InvoiceDate) AS LastPurchaseDate,
        COUNT(DISTINCT Invoice) AS Frequency,
        SUM(Quantity * Price) AS Monetary
    FROM dbo.vw_OnlineRetail_All
    WHERE
        Invoice NOT LIKE 'C%'
        AND Quantity > 0
        AND Price > 0
        AND Customer_ID IS NOT NULL
    GROUP BY Customer_ID
),
RFM AS
(
    SELECT
        Customer_ID,
        DATEDIFF(
            DAY,
            LastPurchaseDate,
            DATEADD(
                DAY,
                1,
                (SELECT MAX(InvoiceDate)
                 FROM dbo.vw_OnlineRetail_All)
            )
        ) AS RecencyDays,
        Frequency,
        Monetary
    FROM CustomerRFM
),
RFMScoring AS
(
    SELECT
        Customer_ID,
        RecencyDays,
        Frequency,
        Monetary,
        NTILE(5) OVER (
            ORDER BY RecencyDays DESC
        ) AS R_Score,
        NTILE(5) OVER (
            ORDER BY Frequency ASC
        ) AS F_Score,
        NTILE(5) OVER (
            ORDER BY Monetary ASC
        ) AS M_Score
    FROM RFM
),
CustomerSegments AS
(
    SELECT
        Customer_ID,
        Monetary,
        CASE
            WHEN R_Score >= 4
                 AND F_Score >= 4
                 AND M_Score >= 4
                THEN 'Champions'
            WHEN R_Score >= 3
                 AND F_Score >= 4
                THEN 'Loyal Customers'
            WHEN R_Score <= 2
                 AND F_Score >= 3
                THEN 'At Risk'
            WHEN R_Score <= 2
                 AND F_Score <= 2
                THEN 'Hibernating'
            ELSE 'Other Customers'
        END AS CustomerSegment
    FROM RFMScoring
)
SELECT
    CustomerSegment,
    COUNT(*) AS TotalCustomers,
    SUM(Monetary) AS TotalMonetary,
    CAST(
        100.0 * SUM(Monetary)
        / SUM(SUM(Monetary)) OVER ()
        AS DECIMAL(6,2)
    ) AS MonetaryContributionPercent
FROM CustomerSegments
GROUP BY CustomerSegment
ORDER BY TotalMonetary DESC;

-- Validation: eligible customer count from the source view
SELECT
    COUNT(DISTINCT Customer_ID) AS EligibleCustomers
FROM dbo.vw_OnlineRetail_All
WHERE
    Invoice NOT LIKE 'C%'
    AND Quantity > 0
    AND Price > 0
    AND Customer_ID IS NOT NULL;

-- Validation: no duplicate customers after segmentation
WITH CustomerRFM AS
(
    SELECT
        Customer_ID,
        MAX(InvoiceDate) AS LastPurchaseDate,
        COUNT(DISTINCT Invoice) AS Frequency,
        SUM(Quantity * Price) AS Monetary
    FROM dbo.vw_OnlineRetail_All
    WHERE Invoice NOT LIKE 'C%'
      AND Quantity > 0
      AND Price > 0
      AND Customer_ID IS NOT NULL
    GROUP BY Customer_ID
),
RFMScoring AS
(
    SELECT
        Customer_ID,
        NTILE(5) OVER (
            ORDER BY DATEDIFF(
                DAY,
                LastPurchaseDate,
                DATEADD(
                    DAY, 1,
                    (SELECT MAX(InvoiceDate)
                     FROM dbo.vw_OnlineRetail_All)
                )
            ) DESC
        ) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM CustomerRFM
),
CustomerSegments AS
(
    SELECT
        Customer_ID,
        CASE
            WHEN R_Score >= 4 AND F_Score >= 4
                 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 4
                 THEN 'Loyal Customers'
            WHEN R_Score <= 2 AND F_Score >= 3
                 THEN 'At Risk'
            WHEN R_Score <= 2 AND F_Score <= 2
                 THEN 'Hibernating'
            ELSE 'Other Customers'
        END AS CustomerSegment
    FROM RFMScoring
)
SELECT
    COUNT(*) AS TotalSegmentRecords,
    COUNT(DISTINCT Customer_ID) AS UniqueSegmentedCustomers,
    COUNT(*) - COUNT(DISTINCT Customer_ID) AS DuplicateRecords
FROM CustomerSegments;
GO

-- ============================================================
-- Final reusable view
-- ============================================================
CREATE OR ALTER VIEW dbo.vw_Customer_RFM_Segments
AS
WITH CustomerRFM AS
(
    SELECT
        Customer_ID,
        MAX(InvoiceDate) AS LastPurchaseDate,
        COUNT(DISTINCT Invoice) AS Frequency,
        SUM(Quantity * Price) AS Monetary
    FROM dbo.vw_OnlineRetail_All
    WHERE Invoice NOT LIKE 'C%'
      AND Quantity > 0
      AND Price > 0
      AND Customer_ID IS NOT NULL
    GROUP BY Customer_ID
),
RFM AS
(
    SELECT
        Customer_ID,
        LastPurchaseDate,
        DATEDIFF(
            DAY,
            LastPurchaseDate,
            DATEADD(
                DAY, 1,
                (SELECT MAX(InvoiceDate)
                 FROM dbo.vw_OnlineRetail_All)
            )
        ) AS RecencyDays,
        Frequency,
        Monetary
    FROM CustomerRFM
),
RFMScoring AS
(
    SELECT
        Customer_ID,
        LastPurchaseDate,
        RecencyDays,
        Frequency,
        Monetary,
        NTILE(5) OVER (
            ORDER BY RecencyDays DESC
        ) AS R_Score,
        NTILE(5) OVER (
            ORDER BY Frequency ASC
        ) AS F_Score,
        NTILE(5) OVER (
            ORDER BY Monetary ASC
        ) AS M_Score
    FROM RFM
)
SELECT
    Customer_ID,
    LastPurchaseDate,
    RecencyDays,
    Frequency,
    Monetary,
    R_Score,
    F_Score,
    M_Score,
    CONCAT(R_Score, F_Score, M_Score) AS RFM_Score,
    CASE
        WHEN R_Score >= 4 AND F_Score >= 4
             AND M_Score >= 4
            THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 4
            THEN 'Loyal Customers'
        WHEN R_Score <= 2 AND F_Score >= 3
            THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score <= 2
            THEN 'Hibernating'
        ELSE 'Other Customers'
    END AS CustomerSegment
FROM RFMScoring;
GO
