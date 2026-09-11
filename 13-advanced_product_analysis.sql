-- 116. Which products are most frequently purchased together?
SELECT a.stock_code                 AS product_a,
       b.stock_code                 AS product_b,
       COUNT(DISTINCT a.invoice_no) AS times_purchased_together
FROM online_retail_clean a
         JOIN online_retail_clean b
              ON a.invoice_no = b.invoice_no
                  AND a.stock_code < b.stock_code
WHERE a.transaction_type = 'Sale'
  AND b.transaction_type = 'Sale'
GROUP BY a.stock_code,
         b.stock_code
ORDER BY times_purchased_together DESC;

-- 117. Which product pairs have the highest support?
WITH total_baskets AS (SELECT COUNT(DISTINCT invoice_no) AS total_baskets
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'),

     product_pairs AS (SELECT a.stock_code                 AS product_a,
                              b.stock_code                 AS product_b,
                              COUNT(DISTINCT a.invoice_no) AS pair_baskets
                       FROM online_retail_clean a
                                JOIN online_retail_clean b
                                     ON a.invoice_no = b.invoice_no
                                         AND a.stock_code < b.stock_code
                       WHERE a.transaction_type = 'Sale'
                         AND b.transaction_type = 'Sale'
                       GROUP BY a.stock_code,
                                b.stock_code)

SELECT p.product_a,
       p.product_b,
       p.pair_baskets,

       ROUND(
               p.pair_baskets / t.total_baskets,
               4
       ) AS support,

       ROUND(
               p.pair_baskets * 100.0 / t.total_baskets,
               2
       ) AS support_pct

FROM product_pairs p
         CROSS JOIN total_baskets t
ORDER BY support DESC;

-- 118. Which product combinations have the highest confidence?
WITH basket_products AS (SELECT DISTINCT invoice_no,
                                         stock_code
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'),

     product_counts AS (SELECT stock_code,
                               COUNT(DISTINCT invoice_no) AS product_baskets
                        FROM basket_products
                        GROUP BY stock_code),

     product_pairs AS (SELECT a.stock_code                 AS product_a,
                              b.stock_code                 AS product_b,
                              COUNT(DISTINCT a.invoice_no) AS pair_baskets
                       FROM basket_products a
                                JOIN basket_products b
                                     ON a.invoice_no = b.invoice_no
                                         AND a.stock_code < b.stock_code
                       GROUP BY a.stock_code,
                                b.stock_code)

SELECT p.product_a,
       p.product_b,
       p.pair_baskets,

       ROUND(
               p.pair_baskets
                   / NULLIF(a.product_baskets, 0),
               4
       ) AS confidence_a_to_b,

       ROUND(
               p.pair_baskets
                   / NULLIF(b.product_baskets, 0),
               4
       ) AS confidence_b_to_a

FROM product_pairs p

         JOIN product_counts a
              ON p.product_a = a.stock_code

         JOIN product_counts b
              ON p.product_b = b.stock_code

ORDER BY GREATEST(
                 p.pair_baskets / NULLIF(a.product_baskets, 0),
                 p.pair_baskets / NULLIF(b.product_baskets, 0)
         ) DESC;

-- 119. Which product combinations have the strongest lift?
WITH total_baskets AS (SELECT COUNT(DISTINCT invoice_no) AS total_baskets
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'),

     basket_products AS (SELECT DISTINCT invoice_no,
                                         stock_code
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'),

     product_counts AS (SELECT stock_code,
                               COUNT(DISTINCT invoice_no) AS product_baskets
                        FROM basket_products
                        GROUP BY stock_code),

     product_pairs AS (SELECT a.stock_code                 AS product_a,
                              b.stock_code                 AS product_b,
                              COUNT(DISTINCT a.invoice_no) AS pair_baskets
                       FROM basket_products a
                                JOIN basket_products b
                                     ON a.invoice_no = b.invoice_no
                                         AND a.stock_code < b.stock_code
                       GROUP BY a.stock_code,
                                b.stock_code)

SELECT p.product_a,
       p.product_b,
       p.pair_baskets,

       ROUND(
               p.pair_baskets * 1.0 / t.total_baskets,
               4
       ) AS pair_support,

       ROUND(
               (
                   p.pair_baskets / t.total_baskets
                   )
                   /
               (
                   (a.product_baskets / t.total_baskets)
                       *
                   (b.product_baskets / t.total_baskets)
                   ),
               4
       ) AS lift

FROM product_pairs p

         JOIN product_counts a
              ON p.product_a = a.stock_code

         JOIN product_counts b
              ON p.product_b = b.stock_code

         CROSS JOIN total_baskets t

ORDER BY lift DESC;

-- 120. Which product combinations vary by country?
WITH basket_products AS (SELECT DISTINCT invoice_no,
                                         stock_code,
                                         country
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                           AND country IS NOT NULL),

     country_pairs AS (SELECT a.country,
                              a.stock_code                 AS product_a,
                              b.stock_code                 AS product_b,
                              COUNT(DISTINCT a.invoice_no) AS pair_baskets
                       FROM basket_products a
                                JOIN basket_products b
                                     ON a.invoice_no = b.invoice_no
                                         AND a.country = b.country
                                         AND a.stock_code < b.stock_code
                       GROUP BY a.country,
                                a.stock_code,
                                b.stock_code),

     country_total_baskets AS (SELECT country,
                                      COUNT(DISTINCT invoice_no) AS total_baskets
                               FROM basket_products
                               GROUP BY country)

SELECT cp.country,
       cp.product_a,
       cp.product_b,

       cp.pair_baskets AS times_purchased_together,

       ROUND(
               cp.pair_baskets
                   / NULLIF(ct.total_baskets, 0),
               4
       )               AS country_support,

       ROUND(
               cp.pair_baskets * 100.0
                   / NULLIF(ct.total_baskets, 0),
               2
       )               AS country_support_pct

FROM country_pairs cp

         JOIN country_total_baskets ct
              ON cp.country = ct.country

ORDER BY cp.country,
         country_support DESC;

-- 121. What percentage of transactions are cancellations?
SELECT COUNT(*) AS total_transactions,
       SUM(
               CASE
                   WHEN transaction_type = 'Cancellation' THEN 1
                   ELSE 0
                   END
       )        AS cancellation_transactions,
       ROUND(
               SUM(
                       CASE
                           WHEN transaction_type = 'Cancellation' THEN 1
                           ELSE 0
                           END
               ) * 100.0 / COUNT(*),
               2
       )        AS cancellation_rate_pct
FROM online_retail_clean
ORDER BY cancellation_rate_pct DESC;

-- 122. Which products have the highest cancellation rate?
SELECT stock_code,
       description,
       COUNT(*) AS total_transactions,
       SUM(
               CASE
                   WHEN transaction_type = 'Cancellation' THEN 1
                   ELSE 0
                   END
       )        AS cancellation_transactions,
       ROUND(
               SUM(
                       CASE
                           WHEN transaction_type = 'Cancellation' THEN 1
                           ELSE 0
                           END
               ) * 100.0 / COUNT(*),
               2
       )        AS cancellation_rate_pct
FROM online_retail_clean
WHERE stock_code IS NOT NULL
  AND stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
GROUP BY stock_code, description
HAVING COUNT(*) >= 10
ORDER BY cancellation_rate_pct DESC;

-- 123. Which customers have unusually high cancellation activity?
SELECT customer_id,
       COUNT(*) AS total_transactions,
       SUM(
               CASE
                   WHEN transaction_type = 'Cancellation' THEN 1
                   ELSE 0
                   END
       )        AS cancellation_transactions,
       ROUND(
               SUM(
                       CASE
                           WHEN transaction_type = 'Cancellation' THEN 1
                           ELSE 0
                           END
               ) * 100.0 / COUNT(*),
               2
       )        AS cancellation_rate_pct
FROM online_retail_clean
WHERE customer_id IS NOT NULL
GROUP BY customer_id
HAVING COUNT(*) >= 10
   AND SUM(
               CASE
                   WHEN transaction_type = 'Cancellation' THEN 1
                   ELSE 0
                   END
       ) >= 2
ORDER BY cancellation_rate_pct DESC;

-- 124. Which countries have the highest cancellation rates?
SELECT country,
       COUNT(*) AS total_transactions,
       SUM(
               CASE
                   WHEN transaction_type = 'Cancellation' THEN 1
                   ELSE 0
                   END
       )        AS cancellation_transactions,
       ROUND(
               SUM(
                       CASE
                           WHEN transaction_type = 'Cancellation' THEN 1
                           ELSE 0
                           END
               ) * 100.0 / COUNT(*),
               2
       )        AS cancellation_rate_pct
FROM online_retail_clean
WHERE country IS NOT NULL
GROUP BY country
HAVING COUNT(*) >= 50
ORDER BY cancellation_rate_pct DESC;

-- 125. How has cancellation activity changed over time?
SELECT invoice_year,
       invoice_month,
       invoice_month_name,
       COUNT(*) AS total_transactions,
       SUM(
               CASE
                   WHEN transaction_type = 'Cancellation' THEN 1
                   ELSE 0
                   END
       )        AS cancellation_transactions,
       ROUND(
               SUM(
                       CASE
                           WHEN transaction_type = 'Cancellation' THEN 1
                           ELSE 0
                           END
               ) * 100.0 / COUNT(*),
               2
       )        AS cancellation_rate_pct
FROM online_retail_clean
GROUP BY invoice_year,
         invoice_month,
         invoice_month_name
ORDER BY invoice_year,
         invoice_month;

-- 126. How much transaction value is associated with cancellations?
SELECT ROUND(
               SUM(line_revenue),
               2
       ) AS total_transaction_value,
       ROUND(
               SUM(
                       CASE
                           WHEN transaction_type = 'Cancellation'
                               THEN line_revenue
                           ELSE 0
                           END
               ),
               2
       ) AS cancellation_value,
       ROUND(
               SUM(
                       CASE
                           WHEN transaction_type = 'Cancellation'
                               THEN line_revenue
                           ELSE 0
                           END
               ) * 100.0
                   / NULLIF(SUM(line_revenue), 0),
               2
       ) AS cancellation_value_pct
FROM online_retail_clean;