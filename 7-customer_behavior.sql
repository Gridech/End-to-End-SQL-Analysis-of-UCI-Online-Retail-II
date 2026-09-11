-- 45. How many repeat customers are there? // 46. What is the repeat purchase rate?
WITH customer_orders AS (SELECT customer_id,
                                COUNT(DISTINCT invoice_no) AS nb_orders
                         FROM online_retail_clean
                         WHERE stock_code REGEXP '^[0-9]{5}'
                           AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                           AND transaction_type = 'Sale'
                           AND customer_id IS NOT NULL
                         GROUP BY customer_id)
SELECT SUM(CASE WHEN nb_orders > 1 THEN 1 ELSE 0 END)                              AS nb_repeat_customers,
       COUNT(*)                                                                    AS total_customers,
       ROUND((SUM(CASE WHEN nb_orders > 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS repeat_purchase_rate_pct
FROM customer_orders;

-- 47. How many new customers are acquired each month? // 48. What is the proportion of new vs returning customers?
WITH online_retail_s AS (SELECT customer_id,
                                invoice_date
                         FROM online_retail_clean
                         WHERE stock_code REGEXP '^[0-9]{5}'
                           AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                           AND transaction_type = 'Sale'
                           AND customer_id IS NOT NULL),
     customer_first_purchase AS (SELECT customer_id,
                                        DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS acquisition_month
                                 FROM online_retail_s
                                 GROUP BY customer_id),
     monthly_customer_types AS (SELECT DATE_FORMAT(r.invoice_date, '%Y-%m') AS current_month,
                                       r.customer_id,
                                       CASE
                                           WHEN DATE_FORMAT(r.invoice_date, '%Y-%m') = f.acquisition_month THEN 'New'
                                           ELSE 'Returning'
                                           END                              AS customer_type
                                FROM online_retail_s AS r
                                         INNER JOIN customer_first_purchase AS f ON r.customer_id = f.customer_id
                                GROUP BY current_month, r.customer_id, customer_type)
SELECT current_month,
       COUNT(*)                                                                             AS total_active_customers,
       COUNT(CASE WHEN customer_type = 'New' THEN 1 END)                                    AS nb_new_customers,
       COUNT(CASE WHEN customer_type = 'Returning' THEN 1 END)                              AS nb_returning_customers,
       ROUND((COUNT(CASE WHEN customer_type = 'New' THEN 1 END) / COUNT(*)) * 100, 2)       AS pct_new_customers,
       ROUND((COUNT(CASE WHEN customer_type = 'Returning' THEN 1 END) / COUNT(*)) * 100, 2) AS pct_returning_customers
FROM monthly_customer_types
GROUP BY current_month
ORDER BY current_month;

-- 49. Which customers have the highest average invoice value?
WITH invoice_totals AS (SELECT customer_id,
                               invoice_no,
                               SUM(line_revenue) AS invoice_revenue
                        FROM online_retail_clean
                        WHERE stock_code REGEXP '^[0-9]{5}'
                          AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                          AND transaction_type = 'Sale'
                          AND customer_id IS NOT NULL
                        GROUP BY customer_id, invoice_no)
SELECT customer_id,
       COUNT(invoice_no)              AS total_invoices,
       ROUND(SUM(invoice_revenue), 2) AS total_spent,
       ROUND(AVG(invoice_revenue), 2) AS average_invoice_value
FROM invoice_totals
GROUP BY customer_id
HAVING total_invoices >= 5
ORDER BY average_invoice_value DESC
LIMIT 10;

-- 50. Which customers generate the most lifetime revenue?
SELECT customer_id,
       COUNT(DISTINCT invoice_no)  AS total_orders,
       SUM(quantity)               AS total_items_purchased,
       ROUND(SUM(line_revenue), 2) AS lifetime_revenue
FROM online_retail_clean
WHERE stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
  AND transaction_type = 'Sale'
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY lifetime_revenue DESC
LIMIT 10;

-- 51. Which customers contribute 50% of revenue?
WITH customer_revenue AS (SELECT customer_id,
                                 SUM(line_revenue) AS customer_revenue
                          FROM online_retail_clean
                          WHERE transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                            AND stock_code REGEXP '^[0-9]{5}'
                          GROUP BY customer_id),
     ranked AS (SELECT customer_id,
                       customer_revenue,
                       SUM(customer_revenue) OVER (
                           ORDER BY customer_revenue DESC
                           )                         AS cumulative_revenue,
                       SUM(customer_revenue) OVER () AS total_revenue
                FROM customer_revenue)
SELECT customer_id,
       customer_revenue,
       ROUND(100.0 * cumulative_revenue / total_revenue, 2)
           AS cumulative_revenue_pct
FROM ranked
WHERE cumulative_revenue - customer_revenue < total_revenue * 0.50
ORDER BY customer_revenue DESC;

-- 52. Which customers belong to the top 5% by revenue?
WITH customer_revenue AS (SELECT customer_id,
                                 SUM(line_revenue)                                      AS customer_revenue,
                                 PERCENT_RANK() OVER (ORDER BY SUM(line_revenue) DESC ) AS rk
                          FROM online_retail_clean
                          WHERE stock_code REGEXP '^[0-9]{5}'
                            AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                            AND transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                          GROUP BY customer_id)
SELECT customer_id,
       customer_revenue
FROM customer_revenue
WHERE rk <= 0.05
ORDER BY customer_revenue DESC;

-- 53. How concentrated is revenue among customers?
WITH sales AS (SELECT customer_id,
                      line_revenue
               FROM online_retail_clean
               WHERE stock_code REGEXP '^[0-9]{5}'
                 AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                 AND transaction_type = 'Sale'
                 AND customer_id IS NOT NULL),
     totalglobal AS (SELECT SUM(line_revenue) AS global_revenue
                     FROM sales),
     top10clients AS (SELECT SUM(customer_revenue) AS top_10_revenue
                      FROM (SELECT SUM(line_revenue) AS customer_revenue
                            FROM sales
                            GROUP BY customer_id
                            ORDER BY customer_revenue DESC
                            LIMIT 10) AS sub)
SELECT top_10_revenue,
       global_revenue,
       ROUND((top_10_revenue / global_revenue) * 100, 2) AS pct_concentration_top_10
FROM top10clients
         CROSS JOIN totalglobal;

-- 54. What is each customer's first purchase date? // 55. What is each customer's last purchase date?
-- 56. What is each customer's observed lifetime?
SELECT customer_id,
       MIN(invoice_date) AS first_purchase_date,
       MAX(invoice_date) AS last_purchase_date,
       CONCAT(
               TIMESTAMPDIFF(YEAR, MIN(invoice_date), MAX(invoice_date)), ' ans, ',
               TIMESTAMPDIFF(MONTH, MIN(invoice_date), MAX(invoice_date)) % 12, ' mois, ',
               FLOOR(DATEDIFF(MAX(invoice_date), DATE_ADD(MIN(invoice_date), INTERVAL
                                                          TIMESTAMPDIFF(MONTH, MIN(invoice_date), MAX(invoice_date))
                                                          MONTH))), ' jours'
       )                 AS customer_lifetime
FROM online_retail_clean
WHERE stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
  AND transaction_type = 'Sale'
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY DATEDIFF(MAX(invoice_date), MIN(invoice_date)) DESC;

-- 57. What is each customer's purchase frequency?
SELECT customer_id,
       COUNT(DISTINCT invoice_no)                     AS total_orders,
       DATEDIFF(MAX(invoice_date), MIN(invoice_date)) AS active_days_span,
       CASE
           WHEN COUNT(DISTINCT invoice_no) <= 1 THEN 'One-time buyer'
           ELSE ROUND(DATEDIFF(MAX(invoice_date), MIN(invoice_date)) / (COUNT(DISTINCT invoice_no) - 1), 1)
           END                                        AS frequence_achat_jours
FROM online_retail_clean
WHERE stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
  AND transaction_type = 'Sale'
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY total_orders DESC;

-- 58. What is the average time between purchases?
WITH customer_invoices AS (SELECT customer_id,
                                  invoice_no,
                                  MIN(invoice_date) AS invoice_date
                           FROM online_retail_clean
                           WHERE transaction_type = 'Sale'
                             AND customer_id IS NOT NULL
                           GROUP BY customer_id, invoice_no),
     purchase_intervals AS (SELECT customer_id,
                                   invoice_date,
                                   LAG(invoice_date) OVER (
                                       PARTITION BY customer_id
                                       ORDER BY invoice_date
                                       ) AS previous_purchase_date
                            FROM customer_invoices)
SELECT customer_id,
       ROUND(
               AVG(DATEDIFF(invoice_date, previous_purchase_date)),
               2
       ) AS avg_days_between_purchases
FROM purchase_intervals
WHERE previous_purchase_date IS NOT NULL
GROUP BY customer_id
ORDER BY avg_days_between_purchases DESC;;

-- 59. What is the longest gap between purchases for each customer?
WITH customer_invoices AS (SELECT customer_id,
                                  invoice_no,
                                  MIN(invoice_date) AS invoice_date
                           FROM online_retail_clean
                           WHERE transaction_type = 'Sale'
                             AND customer_id IS NOT NULL
                           GROUP BY customer_id, invoice_no),
     purchase_intervals AS (SELECT customer_id,
                                   invoice_date,
                                   LAG(invoice_date) OVER (
                                       PARTITION BY customer_id
                                       ORDER BY invoice_date
                                       ) AS previous_purchase_date
                            FROM customer_invoices)
SELECT customer_id,
       ROUND(
               MAX(DATEDIFF(invoice_date, previous_purchase_date)),
               2
       ) AS max_days_between_purchases
FROM purchase_intervals
WHERE previous_purchase_date IS NOT NULL
GROUP BY customer_id
ORDER BY max_days_between_purchases DESC;

-- 60. Which customers have the longest purchase streak?
WITH uci_clean_purchases AS (SELECT DISTINCT customer_id,
                                             YEARWEEK(invoice_date, 3) AS purchase_week
                             FROM online_retail_clean
                             WHERE customer_id IS NOT NULL
                               AND transaction_type = 'Sale'),
     grouped_streaks AS (SELECT customer_id,
                                purchase_week,
                                (purchase_week -
                                 DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY purchase_week)) AS streak_group
                         FROM uci_clean_purchases),
     streak_lengths AS (SELECT customer_id,
                               COUNT(*) AS consecutive_weeks
                        FROM grouped_streaks
                        GROUP BY customer_id, streak_group)
SELECT customer_id,
       MAX(consecutive_weeks) AS longest_weekly_streak
FROM streak_lengths
GROUP BY customer_id
ORDER BY longest_weekly_streak DESC
LIMIT 10;

-- 63. Which customers purchase the widest variety of products?
SELECT customer_id,
       COUNT(DISTINCT stock_code) AS variete_produits_uniques,
       SUM(quantity)              AS volume_total_articles,
       COUNT(DISTINCT invoice_no) AS nombre_total_commandes
FROM online_retail_clean
WHERE customer_id IS NOT NULL
  AND transaction_type = 'Sale'
GROUP BY customer_id
ORDER BY variete_produits_uniques DESC;

