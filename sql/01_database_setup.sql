-- ============================================================
-- 01_database_setup.sql
-- RFM Customer Segmentation in Pure SQL (SQL Server / T-SQL)
-- Creates the analysis database and combines the two Online
-- Retail II periods (2009-2010 and 2010-2011) into one view.
-- ============================================================

CREATE DATABASE RFM_Customer_Analytics;
GO

USE RFM_Customer_Analytics;
GO

CREATE VIEW dbo.vw_OnlineRetail_All AS

SELECT *
FROM dbo.[online_retail_II(2009-2010)]

UNION ALL

SELECT *
FROM dbo.[online_retail_II(2010-2011)];
GO

-- Verification: total combined records
SELECT COUNT(*) AS TotalRecords
FROM dbo.vw_OnlineRetail_All;
