-- 1. What is the total revenue?
SELECT SUM(line_revenue) AS total_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale';

-- 2. How many invoices are there?
SELECT COUNT(DISTINCT invoice_no) AS number_invoices
FROM online_retail_clean
WHERE transaction_type = 'Sale';

-- 3. How many unique customers are there?
SELECT COUNT(DISTINCT customer_id) AS unique_customers
FROM online_retail_clean
WHERE customer_id IS NOT NULL;

-- 4. How many unique products are there?
SELECT COUNT(DISTINCT stock_code) AS unique_products
FROM online_retail_clean
WHERE transaction_type = 'Sale';

-- 5. What is the average invoice value?
WITH invoice_total AS (SELECT invoice_no, SUM(line_revenue) AS invoice_total
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'
                       GROUP BY invoice_no)
SELECT AVG(invoice_total) AS avg_invoice_value
FROM invoice_total;

-- 6. How many products are sold per invoice on average?
WITH total_products AS (SELECT invoice_no, COUNT(*) AS total_products
                        FROM online_retail_clean
                        WHERE transaction_type = 'Sale'
                        GROUP BY invoice_no)
SELECT AVG(total_products) AS product_avg
FROM total_products;

-- 7. How many invoices does a customer make on average?
WITH customer_invoices AS (SELECT customer_id,
                                  COUNT(DISTINCT invoice_no) AS total_invoices
                           FROM online_retail_clean
                           WHERE transaction_type = 'Sale'
                             AND customer_id IS NOT NULL
                           GROUP BY customer_id)
SELECT ROUND(AVG(total_invoices), 2) AS avg_invoices_per_customer
FROM customer_invoices;

-- 8. What is the average revenue per customer?
WITH customer_revenue AS (SELECT customer_id,
                                 SUM(line_revenue) AS customer_revenue
                          FROM online_retail_clean
                          WHERE transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                          GROUP BY customer_id)
SELECT ROUND(AVG(customer_revenue), 2) AS avg_revenue_per_customer
FROM customer_revenue;

-- 9. What is daily revenue?
SELECT CAST(invoice_date AS DATE) AS revenue_date,
       SUM(line_revenue)          AS daily_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
GROUP BY CAST(invoice_date AS DATE)
ORDER BY daily_revenue;

-- What is avg daily revenue?
WITH daily_revenue AS (SELECT CAST(invoice_date AS DATE) AS revenue_date,
                              SUM(line_revenue)          AS daily_revenue
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'
                       GROUP BY CAST(invoice_date AS DATE)
                       ORDER BY daily_revenue)
SELECT AVG(daily_revenue) AS avg_daily_revenue
FROM daily_revenue;

-- 10. What is the weekly revenue?
SELECT invoice_year,
       invoice_week,
       SUM(line_revenue) AS weekly_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
GROUP BY invoice_year, invoice_week
ORDER BY invoice_year, invoice_week;

-- 11. What is monthly revenue?
SELECT invoice_year,
       invoice_month,
       SUM(line_revenue) AS monthly_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
GROUP BY invoice_year, invoice_month
ORDER BY invoice_year, invoice_month;

-- 12. What is the highest-revenue months?
SELECT invoice_year,
       invoice_month,
       SUM(line_revenue) AS monthly_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
GROUP BY invoice_year, invoice_month
ORDER BY monthly_revenue DESC
LIMIT 4;

-- 13. What is the highest-revenue day?
SELECT CAST(invoice_date AS DATE) AS revenue_date,
       SUM(line_revenue)          AS daily_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
GROUP BY CAST(invoice_date AS DATE)
ORDER BY daily_revenue DESC
LIMIT 1;

-- 14. What is the peak sales month for each year?
WITH monthly_sales AS (SELECT invoice_year,
                              invoice_month,
                              SUM(line_revenue) AS monthly_revenue
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'
                       GROUP BY invoice_year, invoice_month
                       ORDER BY invoice_year, invoice_month),
     ranked_sales AS (SELECT invoice_year,
                             invoice_month,
                             monthly_revenue,
                             RANK() OVER (PARTITION BY invoice_year ORDER BY monthly_revenue DESC) AS rk
                      FROM monthly_sales)
SELECT invoice_year,
       invoice_month,
       monthly_revenue AS peak_sales_amount
FROM ranked_sales
WHERE rk = 1
ORDER BY invoice_year;

-- 15. What is the busiest day of the week on average? (the day with the most invoices)
WITH invoice_count AS (SELECT invoice_year,
                              invoice_month,
                              invoice_week,
                              invoice_day_name           AS day,
                              COUNT(DISTINCT invoice_no) AS nb_invoices
                       FROM online_retail_clean
                       GROUP BY invoice_year, invoice_month, invoice_week, invoice_day_name
                       ORDER BY nb_invoices)
SELECT day,
       AVG(nb_invoices) AS avg_invoices,
       MAX(nb_invoices) AS max_invoices,
       MIN(nb_invoices) AS min_invoices
FROM invoice_count
GROUP BY day
ORDER BY avg_invoices DESC;

-- we have to investigate why sunday and saturday are the least busy days

-- 16. What is the peak ordering hour?
WITH invoice_count AS (SELECT invoice_year,
                              invoice_month,
                              invoice_day,
                              invoice_hour,
                              COUNT(DISTINCT invoice_no) AS nb_invoices
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'
                       GROUP BY invoice_year, invoice_month, invoice_day, invoice_hour
                       ORDER BY nb_invoices)
SELECT invoice_hour,
       AVG(nb_invoices) AS avg_invoices,
       MAX(nb_invoices) AS max_invoices,
       MIN(nb_invoices) AS min_invoices
FROM invoice_count
GROUP BY invoice_hour
ORDER BY invoice_hour;

-- 17. What is monthly revenue growth?
WITH monthly_revenue AS (SELECT invoice_year,
                                invoice_month,
                                SUM(line_revenue) AS total_revenue
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                         GROUP BY invoice_year, invoice_month),
     revenue_growth AS (SELECT invoice_year,
                               invoice_month,
                               total_revenue,
                               LAG(total_revenue) OVER (ORDER BY invoice_year, invoice_month) AS prev_month_revenue
                        FROM monthly_revenue)
SELECT invoice_year,
       invoice_month,
       total_revenue                             AS current_revenue,
       prev_month_revenue,
       ROUND(total_revenue - prev_month_revenue) AS mon_growth,
       ROUND(
               100.0 * (total_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0),
               2
       )                                         AS mon_growth_percentage

FROM revenue_growth;

-- 18. What is year-over-year revenue growth?
WITH monthly_revenue AS (SELECT invoice_year,
                                SUM(line_revenue) AS total_revenue
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                         GROUP BY invoice_year),
     revenue_growth AS (SELECT invoice_year,
                               total_revenue,
                               LAG(total_revenue) OVER (ORDER BY invoice_year) AS prev_year_revenue
                        FROM monthly_revenue)
SELECT invoice_year,
       total_revenue                            AS current_revenue,
       prev_year_revenue,
       ROUND(total_revenue - prev_year_revenue) AS year_growth,
       ROUND(
               100.0 * (total_revenue - prev_year_revenue) / NULLIF(prev_year_revenue, 0),
               2
       )                                        AS year_growth_percentage

FROM revenue_growth;

-- 19. Which invoices exceed a specified revenue threshold?
WITH invoice_revenue AS (SELECT invoice_no,
                                SUM(line_revenue) AS revenue
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                         GROUP BY invoice_no),
     ranked_revenue AS (SELECT invoice_no,
                               revenue,
                               PERCENT_RANK() OVER (ORDER BY revenue) AS pct_rank
                        FROM invoice_revenue)
SELECT invoice_no,
       revenue
FROM ranked_revenue
WHERE pct_rank > 0.99
ORDER BY revenue DESC;

-- 20. What is the highest-value invoice for each customer?
WITH customer_invoices AS (SELECT customer_id,
                                  invoice_no,
                                  SUM(line_revenue) AS total_invoice_value
                           FROM online_retail_clean
                           WHERE transaction_type = 'Sale'
                             AND customer_id IS NOT NULL
                           GROUP BY customer_id, invoice_no),
     ranked_invoices AS (SELECT customer_id,
                                invoice_no,
                                total_invoice_value,
                                ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_invoice_value DESC) AS rk
                         FROM customer_invoices)
SELECT customer_id,
       invoice_no,
       total_invoice_value AS highest_revenue
FROM ranked_invoices
WHERE rk = 1
ORDER BY highest_revenue DESC;

-- 21. How does invoice value vary over time?
WITH invoice_totals AS (SELECT invoice_no,
                               invoice_date,
                               SUM(line_revenue) AS total_invoice_value
                        FROM online_retail_clean
                        WHERE transaction_type = 'Sale'
                        GROUP BY invoice_no, invoice_date),
     monthly_metrics AS (SELECT DATE_FORMAT(invoice_date, '%Y-%m-01') AS invoice_month,
                                COUNT(DISTINCT invoice_no)            AS total_invoices,
                                SUM(total_invoice_value)              AS total_revenue,
                                AVG(total_invoice_value)              AS average_invoice_value
                         FROM invoice_totals
                         GROUP BY DATE_FORMAT(invoice_date, '%Y-%m-01'))
SELECT invoice_month,
       total_invoices,
       total_revenue         AS total_revenue,
       average_invoice_value AS average_invoice_value
FROM monthly_metrics
ORDER BY invoice_month;

-- 22. What is the distribution of invoice values?
WITH invoice_totals AS (SELECT invoice_no,
                               SUM(line_revenue) AS total_value
                        FROM online_retail_clean
                        WHERE transaction_type = 'Sale'
                        GROUP BY invoice_no),
     invoice_buckets AS (SELECT invoice_no,
                                total_value,
                                CASE
                                    WHEN total_value <= 150 THEN '01. Mini Baskets (0 £ - 150 £)'
                                    WHEN total_value <= 350 THEN '02. Standard Baskets (150 £ - 350 £)'
                                    WHEN total_value <= 700 THEN '03. Medium Baskets (350 £ - 700 £)'
                                    WHEN total_value <= 2000 THEN '04. Big Baskets (700 £ - 2000 £)'
                                    ELSE '05. Wholesale Orders (> 2000 £)'
                                    END AS invoice_segment
                         FROM invoice_totals)
SELECT invoice_segment,
       COUNT(DISTINCT invoice_no) AS count_invoices,
       ROUND(
               100.0 * COUNT(DISTINCT invoice_no) / SUM(COUNT(DISTINCT invoice_no)) OVER (), 2
       )                          AS pct_of_total_invoices,
       ROUND(SUM(total_value), 2) AS segment_revenue,
       ROUND(
               100.0 * SUM(total_value) / SUM(SUM(total_value)) OVER (), 2
       )                          AS pct_of_total_revenue
FROM invoice_buckets
GROUP BY invoice_segment
ORDER BY invoice_segment;

-- 23. What proportion of invoices are cancelled?
SELECT COUNT(DISTINCT CASE
                          WHEN transaction_type = 'Cancellation'
                              THEN invoice_no
    END)                          AS cancelled_invoices,
       COUNT(DISTINCT invoice_no) AS total_invoices,
       ROUND(
               100.0 *
               COUNT(DISTINCT CASE
                                  WHEN transaction_type = 'Cancellation'
                                      THEN invoice_no
                   END)
                   / COUNT(DISTINCT invoice_no),
               2
       )                          AS cancellation_invoice_rate_pct
FROM online_retail_clean;

-- 24. What is the average number of items per invoice?
WITH invoice_totals AS (SELECT invoice_no,
                               SUM(quantity) AS total_items_quantity
                        FROM online_retail_clean
                        WHERE transaction_type = 'Sale'
                        GROUP BY invoice_no)
SELECT ROUND(AVG(total_items_quantity), 1) AS avg_physical_items_per_invoice
FROM invoice_totals;

-- 25. Which invoices contain the highest quantities?
WITH invoice_quantities AS (SELECT invoice_no,
                                   SUM(quantity) AS total_quantity
                            FROM online_retail_clean
                            WHERE transaction_type = 'Sale'
                            GROUP BY invoice_no),
     invoice_segmentation AS (SELECT invoice_no,
                                     total_quantity,
                                     CASE
                                         WHEN total_quantity <= 50 THEN '01. Very small volume (0 - 50 art.)'
                                         WHEN total_quantity <= 200 THEN '02. Standard Volume (51 - 200 art.)'
                                         WHEN total_quantity <= 500 THEN '03. Average Volume (201 - 500 art.)'
                                         WHEN total_quantity <= 1000 THEN '04. Large Volume (501 - 1000 art.)'
                                         ELSE '05. Industrial Volume / Wholesaler (> 1000 art.)'
                                         END AS quantity_segment
                              FROM invoice_quantities)
SELECT quantity_segment,
       COUNT(DISTINCT invoice_no) AS count_invoices,
       ROUND(
               100.0 * COUNT(DISTINCT invoice_no) / SUM(COUNT(DISTINCT invoice_no)) OVER (), 2
       )                          AS pct_of_total_invoices,
       SUM(total_quantity)        AS total_items_sold,
       ROUND(
               100.0 * SUM(total_quantity) / SUM(SUM(total_quantity)) OVER (), 2
       )                          AS pct_of_total_items
FROM invoice_segmentation
GROUP BY quantity_segment
ORDER BY quantity_segment;