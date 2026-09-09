-- Row Count Validation
SELECT (SELECT COUNT(*) FROM online_retail)             AS raw_rows,
       (SELECT COUNT(*) FROM online_retail_clean)       AS clean_rows,
       (SELECT COUNT(*) FROM online_retail)
           - (SELECT COUNT(*) FROM online_retail_clean) AS rows_removed;

-- Duplicate Validation
SELECT invoice_no,
       stock_code,
       description,
       quantity,
       invoice_date,
       unit_price,
       customer_id,
       country,
       COUNT(*) AS duplicate_count
FROM online_retail_clean
GROUP BY invoice_no,
         stock_code,
         description,
         quantity,
         invoice_date,
         unit_price,
         customer_id,
         country
HAVING COUNT(*) > 1;

-- Missing Critical Fields
SELECT SUM(CASE WHEN invoice_no IS NULL THEN 1 ELSE 0 END)   AS missing_invoice,
       SUM(CASE WHEN stock_code IS NULL THEN 1 ELSE 0 END)   AS missing_stock_code,
       SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END)     AS missing_quantity,
       SUM(CASE WHEN invoice_date IS NULL THEN 1 ELSE 0 END) AS missing_date,
       SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END)   AS missing_price
FROM online_retail_clean;

-- NULL CustomerID
SELECT COUNT(*) AS missing_customer_ids
FROM online_retail_clean
WHERE customer_id IS NULL;

-- Empty String Validation
SELECT SUM(CASE WHEN TRIM(invoice_no) = '' THEN 1 ELSE 0 END)  AS empty_invoice,
       SUM(CASE WHEN TRIM(stock_code) = '' THEN 1 ELSE 0 END)  AS empty_stock_code,
       SUM(CASE WHEN TRIM(description) = '' THEN 1 ELSE 0 END) AS empty_description,
       SUM(CASE WHEN TRIM(country) = '' THEN 1 ELSE 0 END)     AS empty_country
FROM online_retail_clean;

-- Quantity Validation
SELECT transaction_type,
       COUNT(*)      AS row_count,
       MIN(quantity) AS min_quantity,
       MAX(quantity) AS max_quantity
FROM online_retail_clean
GROUP BY transaction_type
ORDER BY row_count DESC;

-- Validate Transaction Classification
SELECT COUNT(*) AS incorrectly_classified_sales
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND (
    quantity <= 0
        OR unit_price <= 0
        OR invoice_no LIKE 'C%'
    );
-- we found only 1 we have to investigate
SELECT *
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND (
    quantity <= 0
        OR unit_price <= 0
        OR invoice_no LIKE 'C%'
    );
-- we found a special case where invoice_id start with C but quantity is not negative and stock_code = M we will have to drop it
DELETE FROM online_retail_clean
WHERE invoice_no = 'C496350' AND stock_code = 'M';


SELECT COUNT(*) AS incorrectly_classified_cancellations
FROM online_retail_clean
WHERE transaction_type = 'Cancellation'
  AND NOT (
    invoice_no LIKE 'C%'
        AND quantity < 0
    );

SELECT COUNT(*) AS incorrectly_classified_negative_quantity
FROM online_retail_clean
WHERE transaction_type = 'Negative Quantity'
  AND quantity >= 0;

SELECT COUNT(*) AS incorrectly_classified_zero_quantity
FROM online_retail_clean
WHERE transaction_type = 'Zero Quantity'
  AND quantity <> 0;

SELECT COUNT(*) AS incorrectly_classified_invalid_price
FROM online_retail_clean
WHERE transaction_type = 'Invalid Price'
  AND unit_price > 0;

-- Revenue Validation
SELECT COUNT(*) AS incorrect_revenue_rows
FROM online_retail_clean
WHERE line_revenue <> quantity * unit_price;

-- Nulls in revenue
SELECT COUNT(*) AS missing_revenue
FROM online_retail_clean
WHERE line_revenue IS NULL;

-- Date validation
-- NUlls count
SELECT COUNT(*) AS invalid_dates
FROM online_retail_clean
WHERE invoice_date IS NULL;

-- derived date fields agree with the original date
SELECT COUNT(*) AS incorrect_year
FROM online_retail_clean
WHERE invoice_year <> YEAR(invoice_date);

SELECT COUNT(*) AS incorrect_month
FROM online_retail_clean
WHERE invoice_month <> MONTH(invoice_date);

SELECT COUNT(*) AS incorrect_hour
FROM online_retail_clean
WHERE invoice_hour <> HOUR(invoice_date);

SELECT COUNT(*) AS incorrect_weekend_flag
FROM online_retail_clean
WHERE is_weekend <>
    CASE
        WHEN DAYOFWEEK(invoice_date) IN (1,7)
        THEN TRUE
        ELSE FALSE
    END;

-- StockCode / Description Validation not important

SELECT
    stock_code,
    COUNT(DISTINCT description) AS description_count
FROM online_retail_clean
WHERE stock_code IS NOT NULL
GROUP BY stock_code
HAVING COUNT(DISTINCT description) > 1
ORDER BY description_count DESC;

-- Summary
