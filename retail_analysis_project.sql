-- --------------------------------------------------------------------------------------
-- USE DATABASE
-- --------------------------------------------------------------------------------------
USE retail_analysis;

-- --------------------------------------------------------------------------------------
-- INITIAL EXPLORATION OF TABLES
-- --------------------------------------------------------------------------------------
SELECT * FROM customer_profiles;
SELECT * FROM product_inventory;
SELECT * FROM sales_transaction;

-- --------------------------------------------------------------------------------------
-- FIXING ENCODING ISSUES IN COLUMN NAMES
-- --------------------------------------------------------------------------------------
ALTER TABLE sales_transaction
RENAME COLUMN `ï»¿TransactionID` TO `TransactionID`;

ALTER TABLE product_inventory
RENAME COLUMN `ï»¿ProductID` TO `ProductID`;

ALTER TABLE customer_profiles
RENAME COLUMN `ï»¿CustomerID` TO `CustomerID`;

-- --------------------------------------------------------------------------------------
-- CLEANING SALES_TRANSACTION TABLE
-- --------------------------------------------------------------------------------------

-- Check table structure
DESCRIBE sales_transaction;

-- Check for duplicate TransactionID
SELECT TransactionID, COUNT(*)
FROM sales_transaction
GROUP BY TransactionID
HAVING COUNT(*) > 1;

-- Check details of duplicate transactions
SELECT * FROM sales_transaction
WHERE TransactionID IN (4999, 5000);

SET SQL_SAFE_UPDATES = 0;

-- Delete only 1 row from duplicates
DELETE FROM sales_transaction
WHERE TransactionID IN (4999, 5000)
LIMIT 1;

-- Check NULL values
SELECT *
FROM sales_transaction
WHERE TransactionID IS NULL
   OR CustomerID IS NULL
   OR ProductID IS NULL
   OR QuantityPurchased IS NULL
   OR TransactionDate IS NULL
   OR Price IS NULL;

-- Check price mismatch between sales_transaction & product_inventory
SELECT st.ProductID, st.Price AS sales_price, pi.Price AS official_price
FROM sales_transaction st
JOIN product_inventory pi ON st.ProductID = pi.ProductID
WHERE st.Price <> pi.Price;

-- Fix incorrect prices in sales table
UPDATE sales_transaction st
JOIN product_inventory pi ON st.ProductID = pi.ProductID
SET st.Price = pi.Price
WHERE st.Price <> pi.Price;

-- Standardize TransactionDate format
UPDATE sales_transaction
SET TransactionDate = STR_TO_DATE(TransactionDate, '%d/%m/%Y');

-- --------------------------------------------------------------------------------------
-- CLEANING PRODUCT_INVENTORY TABLE
-- --------------------------------------------------------------------------------------

-- Check duplicates
SELECT ProductID, COUNT(*)
FROM product_inventory
GROUP BY ProductID
HAVING COUNT(*) > 1;

-- Check NULL values
SELECT *
FROM product_inventory
WHERE ProductName IS NULL
   OR Category IS NULL
   OR StockLevel IS NULL
   OR Price IS NULL;

-- Check for invalid stock or price values
SELECT *
FROM product_inventory
WHERE StockLevel < 0 
   OR Price <= 0;

-- --------------------------------------------------------------------------------------
-- CLEANING CUSTOMER_PROFILES TABLE
-- --------------------------------------------------------------------------------------

-- Check duplicates
SELECT CustomerID, COUNT(*)
FROM customer_profiles
GROUP BY CustomerID
HAVING COUNT(*) > 1;

-- Check NULL or empty string values
SELECT *
FROM customer_profiles
WHERE CustomerID IS NULL
   OR Age IS NULL
   OR Gender IS NULL OR Gender = ''
   OR Location IS NULL OR Location = ''
   OR JoinDate IS NULL;

-- Fix empty locations
UPDATE customer_profiles
SET Location = 'NA'
WHERE Location = '';

-- Standardize date format
UPDATE customer_profiles
SET JoinDate = STR_TO_DATE(JoinDate, '%d/%m/%Y');

-- Detect unrealistic ages
SELECT *
FROM customer_profiles
WHERE Age < 10 OR Age > 100;

-- Remove invalid age record (example)
DELETE FROM customer_profiles
WHERE CustomerID = 668;

-- Check future JoinDates
SELECT *
FROM customer_profiles
WHERE JoinDate > CURDATE();

-- --------------------------------------------------------------------------------------
-- EXPLORATORY DATA ANALYSIS (EDA)
-- --------------------------------------------------------------------------------------

-- 1. Product performance (quantity & sales)
SELECT st.ProductID, pi.ProductName, pi.Category,
       SUM(st.QuantityPurchased) AS TotalQuantity,
       SUM(st.QuantityPurchased * st.Price) AS TotalSales
FROM sales_transaction st
JOIN product_inventory pi ON st.ProductID = pi.ProductID
GROUP BY st.ProductID, pi.ProductName, pi.Category
ORDER BY TotalQuantity DESC;

-- Category-wise performance
SELECT pi.Category, pi.ProductName,
       SUM(st.QuantityPurchased) AS TotalQuantity,
       SUM(st.QuantityPurchased * st.Price) AS TotalSales
FROM sales_transaction st
JOIN product_inventory pi ON st.ProductID = pi.ProductID
GROUP BY pi.ProductName, pi.Category
ORDER BY pi.Category ASC, TotalQuantity DESC;

-- 2. Customer purchase frequency
SELECT cp.CustomerID, cp.Age, cp.Location,
       COUNT(st.TransactionDate) AS TotalPurchase,
       CASE 
           WHEN COUNT(st.TransactionDate) = 0 THEN 'No Orders'
           WHEN COUNT(st.TransactionDate) BETWEEN 1 AND 10 THEN 'Low Orders'
           WHEN COUNT(st.TransactionDate) BETWEEN 11 AND 30 THEN 'Medium Orders'
           ELSE 'High Orders'
       END AS Customer_Purchase_Level
FROM customer_profiles cp
JOIN sales_transaction st ON cp.CustomerID = st.CustomerID
GROUP BY cp.CustomerID, cp.Age, cp.Location
ORDER BY TotalPurchase DESC;

-- 3. Category-level sales performance
SELECT pi.Category,
       COUNT(st.TransactionDate) AS TotalTransactions,
       SUM(st.QuantityPurchased) AS TotalQuantitySold,
       SUM(st.QuantityPurchased * st.Price) AS TotalSales
FROM product_inventory pi
JOIN sales_transaction st ON pi.ProductID = st.ProductID
GROUP BY pi.Category
ORDER BY TotalQuantitySold DESC;

-- 4. Month-wise sales trend (peak month)
SELECT YEAR(TransactionDate) AS Year,
       DATE_FORMAT(TransactionDate, '%M') AS Month,
       SUM(QuantityPurchased) AS TotalQuantitySold,
       SUM(QuantityPurchased * Price) AS TotalSales
FROM sales_transaction
GROUP BY YEAR(TransactionDate), MONTH(TransactionDate)
ORDER BY TotalSales DESC;

-- --------------------------------------------------------------------------------------
-- PRACTICE QUESTIONS
-- --------------------------------------------------------------------------------------

-- Q1: Total sales by category
SELECT pi.Category,
       SUM(st.Price * st.QuantityPurchased) AS Total_Sales
FROM sales_transaction st
JOIN product_inventory pi ON st.ProductID = pi.ProductID
GROUP BY pi.Category
ORDER BY Total_Sales DESC;

-- Q2: Average purchase value per category
SELECT pi.Category,
       AVG(st.Price * st.QuantityPurchased) AS Avg_Purchase_Value
FROM sales_transaction st
JOIN product_inventory pi ON st.ProductID = pi.ProductID
GROUP BY pi.Category;

-- Q3: Top 5 highest-spending customers
SELECT CustomerID,
       SUM(QuantityPurchased * Price) AS TotalSpend
FROM sales_transaction
GROUP BY CustomerID
ORDER BY TotalSpend DESC
LIMIT 5;

-- Q4: Customer loyalty (duration between first & last purchase)
SELECT CustomerID,
       MAX(TransactionDate) AS RecentPurchase,
       MIN(TransactionDate) AS FirstPurchase,
       DATEDIFF(MAX(TransactionDate), MIN(TransactionDate)) AS DaysBetween
FROM sales_transaction
GROUP BY CustomerID
ORDER BY DaysBetween DESC;

-- Q5: Purchases by each customer for each product (only >2 purchases)
SELECT st.CustomerID, pi.ProductName,
       COUNT(*) AS TotalPurchases
FROM sales_transaction st
JOIN product_inventory pi ON st.ProductID = pi.ProductID
GROUP BY st.CustomerID, pi.ProductName
HAVING TotalPurchases > 2
ORDER BY st.CustomerID;
