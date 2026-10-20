-- ============================================================
-- 02_data_quality_checks.sql
-- RFM Customer Segmentation in Pure SQL (SQL Server / T-SQL)
-- Data profiling and exploratory checks on the combined view.
-- ============================================================

USE RFM_Customer_Analytics;
GO

-- Missing customer IDs
SELECT COUNT(*) AS MissingCustomerIDs
FROM dbo.vw_OnlineRetail_All
WHERE Customer_ID IS NULL;

-- Missing descriptions
SELECT COUNT(*) AS MissingDescriptions
FROM dbo.vw_OnlineRetail_All
WHERE Description IS NULL;

-- Non-positive quantities
SELECT COUNT(*) AS NonPositiveQuantities
FROM dbo.vw_OnlineRetail_All
WHERE Quantity <= 0;

-- Negative prices
SELECT COUNT(*) AS NegativePrices
FROM dbo.vw_OnlineRetail_All
WHERE Price < 0;

-- Cancellation rows (invoice numbers starting with 'C')
SELECT COUNT(*) AS CancellationRows
FROM dbo.vw_OnlineRetail_All
WHERE Invoice LIKE 'C%';

-- Quantity breakdown
SELECT
    CASE
        WHEN Quantity < 0 THEN 'Negative Quantity'
        WHEN Quantity = 0 THEN 'Zero Quantity'
        ELSE 'Positive Quantity'
    END AS QuantityCategory,
    COUNT(*) AS TotalRecords
FROM dbo.vw_OnlineRetail_All
GROUP BY
    CASE
        WHEN Quantity < 0 THEN 'Negative Quantity'
        WHEN Quantity = 0 THEN 'Zero Quantity'
        ELSE 'Positive Quantity'
    END
ORDER BY TotalRecords DESC;

-- Negative quantities split by cancellation vs non-cancellation
SELECT
    CASE
        WHEN Invoice LIKE 'C%' THEN 'Cancellation'
        ELSE 'Non-Cancellation'
    END AS Category,
    COUNT(*) AS TotalRecords
FROM dbo.vw_OnlineRetail_All
WHERE Quantity < 0
GROUP BY
    CASE
        WHEN Invoice LIKE 'C%' THEN 'Cancellation'
        ELSE 'Non-Cancellation'
    END
ORDER BY TotalRecords DESC;

-- Unique cancellation invoices
SELECT
    COUNT(DISTINCT Invoice) AS UniqueCancellationInvoices
FROM dbo.vw_OnlineRetail_All
WHERE Invoice LIKE 'C%';

-- Rows that qualify as genuine purchases
SELECT
    COUNT(*) AS EligiblePurchaseRows
FROM dbo.vw_OnlineRetail_All
WHERE
    Invoice NOT LIKE 'C%'
    AND Quantity > 0
    AND Price > 0
    AND Customer_ID IS NOT NULL;

-- Unique identified customers
SELECT COUNT(DISTINCT Customer_ID) AS UniqueCustomers
FROM dbo.vw_OnlineRetail_All
WHERE Customer_ID IS NOT NULL;

-- Transaction date range
SELECT MIN(InvoiceDate) AS FirstTransactionDate,
       MAX(InvoiceDate) AS LastTransactionDate
FROM dbo.vw_OnlineRetail_All;

-- Unique invoices
SELECT COUNT(DISTINCT Invoice) AS UniqueInvoices
FROM dbo.vw_OnlineRetail_All;

-- Customers by country
SELECT Country, COUNT(DISTINCT Customer_ID) AS UniqueCustomers
FROM dbo.vw_OnlineRetail_All
WHERE Customer_ID IS NOT NULL
GROUP BY Country
ORDER BY COUNT(DISTINCT Customer_ID) DESC;

-- Invoices with the most product rows
SELECT TOP 10 Invoice, COUNT(*) AS ProductRows
FROM dbo.vw_OnlineRetail_All
GROUP BY Invoice
ORDER BY ProductRows DESC;
