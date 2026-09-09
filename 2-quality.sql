-- Number of rows
SELECT COUNT(*) AS total_rows
FROM online_retail;

-- Basic dataset statistics
SELECT COUNT(*)                    AS total_rows,
       COUNT(DISTINCT invoice_no)  AS unique_invoices,
       COUNT(DISTINCT stock_code)  AS unique_products,
       COUNT(DISTINCT customer_id) AS unique_customers,
       COUNT(DISTINCT country)     AS unique_countries,
       MIN(invoice_date)           AS first_transaction,
       MAX(invoice_date)           AS last_transaction
FROM online_retail;

-- Missing values for every column AND Missing percentage
SELECT 'invoice_no'                                          AS column_name,
       SUM(IF(TRIM(invoice_no) = '', 1, 0))                  AS null_values,
       SUM(IF(TRIM(invoice_no) = '', 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail
UNION ALL
SELECT 'stock_code'                                          AS column_name,
       SUM(IF(TRIM(stock_code) = '', 1, 0))                  AS null_values,
       SUM(IF(TRIM(stock_code) = '', 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail
UNION ALL
SELECT 'description'                                          AS column_name,
       SUM(IF(TRIM(description) = '', 1, 0))                  AS null_values,
       SUM(IF(TRIM(description) = '', 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail
UNION ALL
SELECT 'quantity'                                          AS column_name,
       SUM(IF(TRIM(quantity) = '', 1, 0))                  AS null_values,
       SUM(IF(TRIM(quantity) = '', 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail
UNION ALL
SELECT 'invoice_date'                                             AS column_name,
       SUM(IF(TRIM(invoice_date) IS NULL, 1, 0))                  AS null_values,
       SUM(IF(TRIM(invoice_date) IS NULL, 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail
UNION ALL
SELECT 'unit_price'                                          AS column_name,
       SUM(IF(TRIM(unit_price) = '', 1, 0))                  AS null_values,
       SUM(IF(TRIM(unit_price) = '', 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail
UNION ALL
SELECT 'customer_id'                                          AS column_name,
       SUM(IF(TRIM(customer_id) = '', 1, 0))                  AS null_values,
       SUM(IF(TRIM(customer_id) = '', 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail
UNION ALL
SELECT 'country'                                          AS column_name,
       SUM(IF(TRIM(country) = '', 1, 0))                  AS null_values,
       SUM(IF(TRIM(country) = '', 1, 0)) / COUNT(*) * 100 AS null_percentage
FROM online_retail;

-- There are two different things we need to investigate:
-- 1) Exact duplicate rows

SELECT invoice_no,
       stock_code,
       description,
       quantity,
       invoice_date,
       unit_price,
       customer_id,
       country,
       COUNT(*) AS duplicate_count
FROM online_retail
GROUP BY invoice_no,
         stock_code,
         description,
         quantity,
         invoice_date,
         unit_price,
         customer_id,
         country
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Number of rows involved in exact duplicates

SELECT SUM(duplicate_count)     AS rows_in_duplicate_groups,
       SUM(duplicate_count - 1) AS excess_duplicate_rows
FROM (SELECT COUNT(*) AS duplicate_count
      FROM online_retail
      GROUP BY invoice_no,
               stock_code,
               description,
               quantity,
               invoice_date,
               unit_price,
               customer_id,
               country
      HAVING COUNT(*) > 1) AS d;

-- 2) Duplicate business transactions
SELECT invoice_no,
       stock_code,
       COUNT(*) AS line_count
FROM online_retail
GROUP BY invoice_no,
         stock_code
HAVING COUNT(*) > 1
ORDER BY line_count DESC;

-- StockCodes with multiple descriptions
SELECT stock_code,
       COUNT(DISTINCT description) AS description_count
FROM online_retail
WHERE stock_code IS NOT NULL
GROUP BY stock_code
HAVING COUNT(DISTINCT description) > 1
ORDER BY description_count DESC;
--

-- Show the inconsistent descriptions
SELECT stock_code,
       description,
       COUNT(*) AS occurrences
FROM online_retail
WHERE stock_code IN (SELECT stock_code
                     FROM online_retail
                     WHERE stock_code IS NOT NULL
                     GROUP BY stock_code
                     HAVING COUNT(DISTINCT description) > 1)
GROUP BY stock_code,
         description
ORDER BY stock_code, occurrences DESC;

-- Negative quantities
SELECT COUNT(*)           AS negative_quantity_rows,
       SUM(ABS(quantity)) AS total_negative_units
FROM online_retail
WHERE quantity < 0;

-- Negative quantity details
SELECT invoice_no,
       stock_code,
       description,
       quantity,
       invoice_date,
       unit_price,
       customer_id,
       country
FROM online_retail
WHERE Quantity < 0
ORDER BY invoice_date;

-- Zero Quantity
SELECT COUNT(*) AS zero_quantity_rows
FROM online_retail
WHERE quantity = 0;

SELECT *
FROM online_retail
WHERE quantity = 0
ORDER BY invoice_date;

-- Negative prices
SELECT COUNT(*)        AS negative_price_rows,
       MIN(unit_price) AS minimum_price
FROM online_retail
WHERE unit_price < 0;

-- Zero prices
SELECT COUNT(*) AS zero_price_rows
FROM online_retail
WHERE unit_price = 0;

-- Price distribution
SELECT MIN(unit_price) AS min_price,
       AVG(unit_price) AS avg_price,
       MAX(unit_price) AS max_price
FROM online_retail
WHERE unit_price IS NOT NULL;

-- Cancellation Analysis: A common indicator is an invoice number beginning with C
-- Cancellation count AND Cancellation percentage
SELECT COUNT(*)                            AS total_lines,

       SUM(IF(invoice_no LIKE 'C%', 1, 0)) AS cancelled_lines,

       ROUND(
               SUM(IF(invoice_no LIKE 'C%', 1, 0)) * 100.0 / COUNT(*),
               2
       )                                   AS cancellation_percentage

FROM online_retail;

-- Negative quantities associated with cancellations
SELECT COUNT(*) AS negative_cancellations_rows_count
FROM online_retail
WHERE quantity < 0
  AND invoice_no LIKE 'C%';

-- Negative quantities without cancellation invoice prefix
SELECT COUNT(*) AS negative_NoCancellations_row_count
FROM online_retail
WHERE quantity < 0
  AND invoice_no NOT LIKE 'C%';

-- Cancellation / Quantity Consistency
SELECT CASE
           WHEN invoice_no LIKE 'C%' AND Quantity < 0
               THEN 'Cancellation + Negative Quantity'

           WHEN invoice_no LIKE 'C%' AND Quantity >= 0
               THEN 'Cancellation + Non-negative Quantity'

           WHEN invoice_no NOT LIKE 'C%' AND Quantity < 0
               THEN 'Non-cancellation + Negative Quantity'

           ELSE 'Normal'
           END  AS transaction_type,
       COUNT(*) AS row_count
FROM online_retail
GROUP BY transaction_type
ORDER BY row_count DESC;

-- Countries Text Standardization
SELECT
    country,
    COUNT(*) AS row_count
FROM online_retail
GROUP BY country
ORDER BY country;

-- Description Quality
-- Description length anomalies
SELECT
    MIN(CHAR_LENGTH(description)) AS min_length,
    MAX(CHAR_LENGTH(description)) AS max_length,
    AVG(CHAR_LENGTH(description)) AS avg_length
FROM online_retail
WHERE description IS NOT NULL;

-- Suspicious descriptions
SELECT
    description,
    COUNT(*) AS occurrences
FROM online_retail
WHERE description IS NOT NULL
GROUP BY description
ORDER BY occurrences DESC;

-- Outlier Detection: Revenue
SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    unit_price,
    quantity * unit_price AS line_revenue
FROM online_retail
ORDER BY line_revenue DESC
LIMIT 50;

-- Quantity Outliers
WITH ranked_quantity AS (
    SELECT
        quantity,
        ROW_NUMBER() OVER (ORDER BY quantity) AS rn,
        COUNT(*) OVER () AS total_rows
    FROM online_retail
    WHERE quantity > 0
)
SELECT
    MIN(CASE
        WHEN rn >= total_rows * 0.25
        THEN quantity
    END) AS approximate_q1,

    MIN(CASE
        WHEN rn >= total_rows * 0.50
        THEN quantity
    END) AS approximate_median,

    MIN(CASE
        WHEN rn >= total_rows * 0.75
        THEN quantity
    END) AS approximate_q3

FROM ranked_quantity;

-- Price outliers
WITH ranked_prices AS (
    SELECT
        unit_price,
        ROW_NUMBER() OVER (ORDER BY unit_price) AS rn,
        COUNT(*) OVER () AS total_rows
    FROM online_retail
    WHERE unit_price > 0
)
SELECT
    MIN(CASE
        WHEN rn >= total_rows * 0.25
        THEN unit_price
    END) AS approximate_q1,

    MIN(CASE
        WHEN rn >= total_rows * 0.50
        THEN unit_price
    END) AS approximate_median,

    MIN(CASE
        WHEN rn >= total_rows * 0.75
        THEN unit_price
    END) AS approximate_q3

FROM ranked_prices;

-- Customer transaction distribution
SELECT
    customer_id,
    COUNT(DISTINCT invoice_no) AS invoice_count,
    COUNT(*) AS product_count,
    SUM(Quantity * unit_price) AS revenue
FROM online_retail
WHERE customer_id <> ''
GROUP BY customer_id
ORDER BY invoice_count DESC;

-- Referential Integrity / Business-Key Checks
-- StockCode associated with NULL description
SELECT
    stock_code,
    COUNT(*) AS occurrences
FROM online_retail
WHERE description IS NULL OR description = ''
GROUP BY stock_code
ORDER BY occurrences DESC;

-- Customer with multiple countries
SELECT
    customer_id,
    COUNT(DISTINCT country) AS country_count
FROM online_retail
WHERE customer_id IS NOT NULl AND customer_id <> ''
GROUP BY customer_id
HAVING COUNT(DISTINCT country) > 1
ORDER BY country_count DESC;


-- Build a Data Quality Scorecard
SELECT
    'Missing customer_id' AS issue,
    COUNT(*) AS affected_rows,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM online_retail), 2) AS affected_pct
FROM online_retail
WHERE customer_id IS NULL OR customer_id = ''

UNION ALL

SELECT
    'Missing Description',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM online_retail), 2)
FROM online_retail
WHERE description IS NULL OR description = ''

UNION ALL

SELECT
    'Negative Quantity',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM online_retail), 2)
FROM online_retail
WHERE quantity < 0

UNION ALL

SELECT
    'Zero Quantity',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM online_retail), 2)
FROM online_retail
WHERE quantity = 0

UNION ALL

SELECT
    'Zero UnitPrice',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM online_retail), 2)
FROM online_retail
WHERE unit_price = 0

UNION ALL

SELECT
    'Negative UnitPrice',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM online_retail), 2)
FROM online_retail
WHERE unit_price < 0

UNION ALL

SELECT
    'Cancellation Invoice',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM online_retail), 2)
FROM online_retail
WHERE invoice_no LIKE 'C%';


