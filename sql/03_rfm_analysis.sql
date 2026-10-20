-- ============================================================
-- 03_rfm_analysis.sql
-- RFM Customer Segmentation in Pure SQL (SQL Server / T-SQL)
-- Customer-level Recency, Frequency and Monetary metrics,
-- plus quintile (NTILE 5) RFM scores.
-- Eligibility: non-cancellation invoice, Quantity > 0,
-- Price > 0, Customer_ID present.
-- ============================================================

USE RFM_Customer_Analytics;
GO

-- Exploratory: line value per row
SELECT Invoice, StockCode, Quantity, Price, (Quantity * Price) AS LineValue
FROM dbo.vw_OnlineRetail_All;

-- Exploratory: total purchase value per customer (eligible rows only)
SELECT Customer_ID, SUM(Quantity * Price) AS TotalPurchaseValue
FROM dbo.vw_OnlineRetail_All
WHERE Invoice NOT LIKE 'C%'
  AND Quantity > 0
  AND Price > 0
  AND Customer_ID IS NOT NULL
GROUP BY Customer_ID;

-- Recency per customer (days since last purchase, vs day after dataset max date)
SELECT
    Customer_ID,
    MAX(InvoiceDate) AS LastPurchaseDate,
    DATEDIFF(
        DAY,
        MAX(InvoiceDate),
        (SELECT DATEADD(DAY, 1, MAX(InvoiceDate))
         FROM dbo.vw_OnlineRetail_All)
    ) AS RecencyDays
FROM dbo.vw_OnlineRetail_All
WHERE
    Invoice NOT LIKE 'C%'
    AND Quantity > 0
    AND Price > 0
    AND Customer_ID IS NOT NULL
GROUP BY Customer_ID;

-- Frequency per customer
SELECT Customer_ID, COUNT(DISTINCT Invoice) AS Frequency
FROM dbo.vw_OnlineRetail_All
WHERE Invoice NOT LIKE 'C%'
  AND Quantity > 0
  AND Price > 0
  AND Customer_ID IS NOT NULL
GROUP BY Customer_ID;

-- Monetary per customer
SELECT
    Customer_ID,
    SUM(Quantity * Price) AS Monetary
FROM dbo.vw_OnlineRetail_All
WHERE
    Invoice NOT LIKE 'C%'
    AND Quantity > 0
    AND Price > 0
    AND Customer_ID IS NOT NULL
GROUP BY Customer_ID
ORDER BY Customer_ID;

-- Combined RFM metrics per customer
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
)
SELECT
    Customer_ID,
    LastPurchaseDate,
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
ORDER BY Customer_ID;

-- RFM scores with NTILE(5)
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
        LastPurchaseDate,
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
)
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
ORDER BY Customer_ID;
