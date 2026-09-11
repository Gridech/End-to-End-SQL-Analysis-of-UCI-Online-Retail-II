-- 70. What is each customer's Recency?
WITH referance_date AS (SELECT MAX(DATE(invoice_date)) + INTERVAL 1 DAY AS ref_day
                        FROM online_retail_clean)
SELECT customer_id,
       COUNT(DISTINCT invoice_no)                                              AS number_orders,
       MAX(DATE(invoice_date))                                                 AS last_purchase_date,
       DATEDIFF((SELECT ref_day FROM referance_date), MAX(DATE(invoice_date))) AS recency_days
FROM online_retail_clean
WHERE customer_id IS NOT NULL
  AND transaction_type = 'Sale'
GROUP BY customer_id
HAVING COUNT(DISTINCT invoice_no) > 1
ORDER BY recency_days DESC;

-- 71. What is each customer's Frequency?
SELECT customer_id,
       COUNT(DISTINCT invoice_no) AS frequency,
       MIN(DATE(invoice_no))      AS firdt_order,
       MAX(DATE(invoice_no))      AS last_order,
       ROUND(DATEDIFF(MAX(DATE(invoice_no)), MIN(DATE(invoice_no))) / NULLIF(COUNT(DISTINCT invoice_no) - 1, 0),
             1)                   AS average_interval_days
FROM online_retail_clean
WHERE customer_id IS NOT NULL
  AND transaction_type = 'Sale'
ORDER BY frequency DESC;

-- 72. What is each customer's Monetary value?
WITH revenue_per_invoice AS (SELECT customer_id,
                                    invoice_no,
                                    line_revenue,
                                    AVG(line_revenue) OVER (PARTITION BY invoice_no) AS avg_invoice_revenue
                             FROM online_retail_clean
                             WHERE stock_code REGEXP '^[0-9]{5}'
                               AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                               AND transaction_type = 'Sale'
                               AND customer_id IS NOT NULL)
SELECT customer_id,
       SUM(line_revenue)        AS monetary_value,
       COUNT(invoice_no)        AS number_of_invoices,
       AVG(avg_invoice_revenue) AS avg_revenue_per_invoice
FROM revenue_per_invoice
GROUP BY customer_id
ORDER BY monetary_value DESC;

-- 73. What is each customer's RFM score?
WITH rfm_raw AS (SELECT customer_id,
                        DATEDIFF(
                                (SELECT MAX(DATE(invoice_date)) + INTERVAL 1 DAY FROM online_retail_clean),
                                MAX(DATE(invoice_date))
                        )                          AS recency_days,
                        COUNT(DISTINCT invoice_no) AS frequency,
                        SUM(line_revenue)          AS monetary_value
                 FROM online_retail_clean
                 WHERE stock_code REGEXP '^[0-9]{5}'
                   AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                   AND transaction_type = 'Sale'
                   AND customer_id IS NOT NULL
                 GROUP BY customer_id),
     rfm_tiles AS (SELECT *,
                          NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
                          NTILE(5) OVER (ORDER BY frequency)         AS f_score,
                          NTILE(5) OVER (ORDER BY monetary_value)    AS m_score
                   FROM rfm_raw)
SELECT *,
       CONCAT(r_score, f_score, m_score) AS rfm_combined_score
FROM rfm_tiles
ORDER BY monetary_value DESC;

-- 74. Which customers are Champions? // 75. Which customers are Loyal? // 76. Which customers are Potential Loyalists?
-- 77. Which customers are At Risk? // 78. Which customers are Hibernating?
WITH rfm_raw AS (SELECT customer_id,
                        DATEDIFF((SELECT MAX(DATE(invoice_date)) + INTERVAL 1 DAY FROM online_retail_clean),
                                 MAX(DATE(invoice_date))) AS recency_days,
                        COUNT(DISTINCT invoice_no)        AS frequency,
                        SUM(line_revenue)                 AS monetary_value
                 FROM online_retail_clean
                 WHERE stock_code REGEXP '^[0-9]{5}'
                   AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                   AND transaction_type = 'Sale'
                   AND customer_id IS NOT NULL
                 GROUP BY customer_id),
     rfm_scores AS (SELECT *,
                           NTILE(5) OVER (ORDER BY recency_days DESC) AS r,
                           NTILE(5) OVER (ORDER BY frequency )        AS f,
                           NTILE(5) OVER (ORDER BY monetary_value )   AS m
                    FROM rfm_raw)
SELECT *,
       CASE
           WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Champions'
           WHEN r >= 3 AND f >= 3 AND m >= 3 THEN 'Loyal'
           WHEN r >= 3 AND f >= 1 AND f <= 3 AND m >= 1 THEN 'Potential Loyalists'
           WHEN r <= 2 AND f >= 3 AND m >= 3 THEN 'At Risk'
           WHEN r <= 2 AND f <= 2 AND m <= 2 THEN 'Hibernating'
           ELSE 'Other'
           END AS rfm_segment
FROM rfm_scores;

-- 79. How much revenue does each RFM segment generate?
WITH rfm_raw AS (SELECT customer_id,
                        DATEDIFF((SELECT MAX(DATE(invoice_date)) + INTERVAL 1 DAY FROM online_retail_clean),
                                 MAX(DATE(invoice_date))) AS recency_days,
                        COUNT(DISTINCT invoice_no)        AS frequency,
                        SUM(line_revenue)                 AS monetary_value
                 FROM online_retail_clean
                 WHERE stock_code REGEXP '^[0-9]{5}'
                   AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                   AND transaction_type = 'Sale'
                   AND customer_id IS NOT NULL
                 GROUP BY customer_id),
     rfm_scores AS (SELECT *,
                           NTILE(5) OVER (ORDER BY recency_days DESC) AS r,
                           NTILE(5) OVER (ORDER BY frequency )        AS f,
                           NTILE(5) OVER (ORDER BY monetary_value )   AS m
                    FROM rfm_raw),
     rfm_segmented AS (SELECT *,
                              CASE
                                  WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Champions'
                                  WHEN r >= 3 AND f >= 3 AND m >= 3 THEN 'Loyal'
                                  WHEN r >= 3 AND f >= 1 AND f <= 3 AND m >= 1 THEN 'Potential Loyalists'
                                  WHEN r <= 2 AND f >= 3 AND m >= 3 THEN 'At Risk'
                                  WHEN r <= 2 AND f <= 2 AND m <= 2 THEN 'Hibernating'
                                  ELSE 'Other'
                                  END AS rfm_segment
                       FROM rfm_scores)
SELECT rfm_segment,
       COUNT(customer_id)                                                    AS number_of_customers,
       SUM(monetary_value)                                                   AS total_revenue,
       ROUND(AVG(monetary_value), 2)                                         AS average_revenue_per_customer,
       ROUND(SUM(monetary_value) * 100 / (SELECT SUM(line_revenue)
                                          FROM online_retail_clean
                                          WHERE stock_code REGEXP '^[0-9]{5}'
                                            AND transaction_type = 'Sale'
                                            AND customer_id IS NOT NULL), 2) AS revenue_percentage
FROM rfm_segmented
GROUP BY rfm_segment
ORDER BY total_revenue DESC;
