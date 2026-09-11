-- 65. What is the CLV of each customer?
WITH customer_metrics AS (SELECT customer_id,
                                 COUNT(DISTINCT invoice_no) AS total_orders,
                                 SUM(line_revenue)          AS lifetime_revenue,
                                 MIN(invoice_date)          AS first_purchase_date,
                                 MAX(invoice_date)          AS last_purchase_date,
                                 DATEDIFF(
                                         MAX(invoice_date),
                                         MIN(invoice_date)
                                 )                          AS observed_lifetime_days
                          FROM online_retail_clean
                          WHERE transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                            AND stock_code REGEXP '^[0-9]{5}'
                            AND stock_code NOT IN (
                                                   'POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE'
                              )
                          GROUP BY customer_id),
     expected_lifespan AS (SELECT AVG(observed_lifetime_days) / 365.0 AS expected_lifetime_years
                           FROM customer_metrics
                           WHERE total_orders > 1)
SELECT cm.customer_id,
       cm.total_orders,
       ROUND(
               cm.lifetime_revenue / cm.total_orders,
               2
       )                                    AS average_order_value,
       ROUND(
               CASE
                   WHEN cm.observed_lifetime_days > 0
                       THEN cm.total_orders / (cm.observed_lifetime_days / 365.0)
                   END,
               2
       )                                    AS annual_purchase_frequency,
       ROUND(el.expected_lifetime_years, 2) AS expected_lifetime_years,
       ROUND(
               (
                   cm.lifetime_revenue / cm.total_orders
                   )
                   *
               (
                   CASE
                       WHEN cm.observed_lifetime_days > 0
                           THEN cm.total_orders / (cm.observed_lifetime_days / 365.0)
                       END
                   )
                   *
               el.expected_lifetime_years,
               2
       )                                    AS estimated_clv
FROM customer_metrics AS cm
         CROSS JOIN expected_lifespan AS el
ORDER BY estimated_clv DESC;

-- 67. How is CLV distributed across customers?
WITH customer_metrics AS (SELECT customer_id,
                                 COUNT(DISTINCT invoice_no) AS total_orders,
                                 SUM(line_revenue)          AS lifetime_revenue,
                                 DATEDIFF(
                                         MAX(invoice_date),
                                         MIN(invoice_date)
                                 )                          AS observed_lifetime_days
                          FROM online_retail_clean
                          WHERE transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                            AND stock_code REGEXP '^[0-9]{5}'
                            AND stock_code NOT IN (
                                                   'POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE'
                              )
                          GROUP BY customer_id),
     expected_lifespan AS (SELECT AVG(observed_lifetime_days) / 365.0 AS expected_lifetime_years
                           FROM customer_metrics
                           WHERE total_orders > 1),
     customer_clv AS (SELECT cm.customer_id,
                             (
                                 cm.lifetime_revenue / cm.total_orders
                                 )
                                 *
                             (
                                 CASE
                                     WHEN cm.observed_lifetime_days > 0
                                         THEN cm.total_orders / (cm.observed_lifetime_days / 365.0)
                                     END
                                 )
                                 *
                             el.expected_lifetime_years AS estimated_clv
                      FROM customer_metrics cm
                               CROSS JOIN expected_lifespan el),
     clv_segments AS (SELECT customer_id,
                             estimated_clv,
                             NTILE(5) OVER (ORDER BY estimated_clv) AS clv_quintile
                      FROM customer_clv
                      WHERE estimated_clv IS NOT NULL)
SELECT clv_quintile,
       COUNT(*)                     AS customers,
       ROUND(MIN(estimated_clv), 2) AS min_clv,
       ROUND(MAX(estimated_clv), 2) AS max_clv,
       ROUND(AVG(estimated_clv), 2) AS avg_clv
FROM clv_segments
GROUP BY clv_quintile
ORDER BY clv_quintile;

-- 68. What percentage of revenue comes from high-CLV customers? High CLV = top 20% of customers by estimated CLV.
WITH customer_metrics AS (SELECT customer_id,
                                 COUNT(DISTINCT invoice_no) AS total_orders,
                                 SUM(line_revenue)          AS lifetime_revenue,
                                 DATEDIFF(
                                         MAX(invoice_date),
                                         MIN(invoice_date)
                                 )                          AS observed_lifetime_days
                          FROM online_retail_clean
                          WHERE transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                            AND stock_code REGEXP '^[0-9]{5}'
                            AND stock_code NOT IN (
                                                   'POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE'
                              )
                          GROUP BY customer_id),
     expected_lifespan AS (SELECT AVG(observed_lifetime_days) / 365.0 AS expected_lifetime_years
                           FROM customer_metrics
                           WHERE total_orders > 1),
     customer_clv AS (SELECT customer_id,
                             lifetime_revenue,
                             (
                                 lifetime_revenue / total_orders
                                 )
                                 *
                             (
                                 CASE
                                     WHEN observed_lifetime_days > 0
                                         THEN total_orders / (observed_lifetime_days / 365.0)
                                     END
                                 )
                                 *
                             el.expected_lifetime_years AS estimated_clv
                      FROM customer_metrics
                               CROSS JOIN expected_lifespan el),
     ranked_customers AS (SELECT *,
                                 NTILE(5) OVER (ORDER BY estimated_clv DESC) AS clv_quintile
                          FROM customer_clv
                          WHERE estimated_clv IS NOT NULL)
SELECT ROUND(
               100.0 *
               SUM(
                       CASE
                           WHEN clv_quintile = 1 THEN lifetime_revenue
                           ELSE 0
                           END
               )
                   / SUM(lifetime_revenue),
               2
       ) AS revenue_from_high_clv_customers_pct
FROM ranked_customers;

-- 69. Which countries have the highest average CLV?
WITH customer_metrics AS (SELECT customer_id,
                                 MAX(country)               AS country,
                                 COUNT(DISTINCT invoice_no) AS total_orders,
                                 SUM(line_revenue)          AS lifetime_revenue,
                                 DATEDIFF(
                                         MAX(invoice_date),
                                         MIN(invoice_date)
                                 )                          AS observed_lifetime_days
                          FROM online_retail_clean
                          WHERE transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                            AND country IS NOT NULL
                            AND stock_code REGEXP '^[0-9]{5}'
                            AND stock_code NOT IN (
                                                   'POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE'
                              )
                          GROUP BY customer_id),
     expected_lifespan AS (SELECT AVG(observed_lifetime_days) / 365.0 AS expected_lifetime_years
                           FROM customer_metrics
                           WHERE total_orders > 1),
     customer_clv AS (SELECT customer_id,
                             country,
                             (
                                 lifetime_revenue / total_orders
                                 )
                                 *
                             (
                                 CASE
                                     WHEN observed_lifetime_days > 0
                                         THEN total_orders / (observed_lifetime_days / 365.0)
                                     END
                                 )
                                 *
                             el.expected_lifetime_years AS estimated_clv
                      FROM customer_metrics
                               CROSS JOIN expected_lifespan el)
SELECT country,
       COUNT(*)                     AS customers,
       ROUND(AVG(estimated_clv), 2) AS average_clv
FROM customer_clv
WHERE estimated_clv IS NOT NULL
GROUP BY country
HAVING COUNT(*) >= 10
ORDER BY average_clv DESC;

