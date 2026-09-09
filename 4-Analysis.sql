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

-- 26. Which products sell the most units?
SELECT stock_code,
       description,
       SUM(quantity) AS total_units_sold
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
GROUP BY stock_code, description
ORDER BY total_units_sold DESC;

-- 27. Which products generate the most revenue?
SELECT stock_code,
       description,
       SUM(line_revenue) AS total_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
GROUP BY stock_code, description
ORDER BY total_revenue DESC;

-- 28. Which products generate the least revenue?
SELECT stock_code,
       description,
       SUM(line_revenue) AS total_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
GROUP BY stock_code, description
ORDER BY total_revenue;

-- 29. Which products have the highest selling price?
SELECT stock_code,
       description,
       MAX(unit_price) AS highest_selling_price
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
GROUP BY stock_code, description
ORDER BY highest_selling_price DESC
LIMIT 10;

-- 30. Which products contribute the most to total revenue?
SELECT stock_code,
       description,
       COUNT(DISTINCT invoice_no)  AS number_of_orders,
       SUM(quantity)               AS total_quantity_sold,
       ROUND(SUM(line_revenue), 2) AS total_product_revenue,
       ROUND(
               100.0 * SUM(line_revenue) / SUM(SUM(line_revenue)) OVER (), 2
       )                           AS pct_of_total_revenue
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
GROUP BY stock_code, description
ORDER BY total_product_revenue DESC
LIMIT 10;

-- 31. Which products have revenue above the product average?
WITH product_revenue AS (SELECT stock_code,
                                description,
                                SUM(line_revenue) AS total_revenue
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                           AND stock_code REGEXP '^[0-9]{5}'
                           AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                         GROUP BY stock_code, description)
SELECT stock_code,
       description,
       total_revenue                                              AS product_revenue,
       ROUND((SELECT AVG(total_revenue) FROM product_revenue), 2) AS global_average_revenue
FROM product_revenue
WHERE total_revenue > (SELECT AVG(total_revenue) FROM product_revenue)
ORDER BY total_revenue DESC;

-- 32. Which products are purchased by exactly one customer?
SELECT stock_code,
       description,
       COUNT(DISTINCT customer_id) AS unique_customers_count,
       COUNT(DISTINCT invoice_no)  AS total_orders,
       SUM(quantity)               AS total_quantity_purchased,
       ROUND(SUM(line_revenue), 2) AS total_revenue_generated
FROM online_retail_clean
WHERE transaction_type = 'Sale'
  AND stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
  AND customer_id IS NOT NULL
GROUP BY stock_code, description
HAVING COUNT(DISTINCT customer_id) = 1
ORDER BY total_revenue_generated DESC;

-- 33. Which products are purchased repeatedly?
WITH customer_product_orders AS (SELECT customer_id,
                                        stock_code,
                                        description,
                                        COUNT(DISTINCT invoice_no) AS times_purchased_by_this_customer
                                 FROM online_retail_clean
                                 WHERE transaction_type = 'Sale'
                                   AND stock_code REGEXP '^[0-9]{5}'
                                   AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                                   AND customer_id IS NOT NULL
                                 GROUP BY customer_id, stock_code, description),
     global_product_totals AS (SELECT stock_code,
                                      COUNT(DISTINCT invoice_no) AS total_distinct_invoices,
                                      SUM(quantity)              AS total_quantity_sold
                               FROM online_retail_clean
                               WHERE transaction_type = 'Sale'
                                 AND stock_code REGEXP '^[0-9]{5}'
                               GROUP BY stock_code)
SELECT cpo.stock_code,
       cpo.description,
       COUNT(DISTINCT cpo.customer_id)           AS total_loyal_customers,
       MAX(cpo.times_purchased_by_this_customer) AS max_repurchases_by_single_customer,
       gpt.total_distinct_invoices,
       gpt.total_quantity_sold
FROM customer_product_orders cpo
         INNER JOIN global_product_totals gpt ON cpo.stock_code = gpt.stock_code
WHERE cpo.times_purchased_by_this_customer > 1
GROUP BY cpo.stock_code, cpo.description, gpt.total_distinct_invoices, gpt.total_quantity_sold
ORDER BY total_loyal_customers DESC
LIMIT 10;

-- 34. Which products have the highest sales growth?
WITH quarterly_sales AS (SELECT stock_code,
                                description,
                                invoice_year      AS sales_year,
                                invoice_quarter   AS sales_quarter,
                                SUM(line_revenue) AS current_quarter_revenue
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                           AND stock_code REGEXP '^[0-9]{5}'
                           AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                         GROUP BY stock_code, description, invoice_year, invoice_quarter),
     growth_calculated AS (SELECT stock_code,
                                  description,
                                  sales_year,
                                  sales_quarter,
                                  ROUND(current_quarter_revenue, 2) AS current_revenue,
                                  ROUND(
                                          LAG(current_quarter_revenue) OVER (
                                              PARTITION BY stock_code
                                              ORDER BY sales_year, sales_quarter
                                              ), 2
                                  )                                 AS previous_revenue
                           FROM quarterly_sales)
SELECT stock_code,
       description,
       CONCAT(sales_year, ' - Q', sales_quarter)                                 AS period,
       current_revenue,
       previous_revenue,
       ROUND(current_revenue - previous_revenue, 2)                              AS quarterly_absolute_growth,
       ROUND(100.0 * (current_revenue - previous_revenue) / previous_revenue, 2) AS quarterly_growth_pct
FROM growth_calculated
WHERE previous_revenue >= 100
ORDER BY quarterly_absolute_growth DESC
LIMIT 15;

-- 35. Which products have declining sales?
WITH product_yearly_revenue AS (SELECT stock_code,
                                       description,
                                       SUM(CASE
                                               WHEN invoice_date >= '2009-12-01' AND invoice_date < '2011-01-01'
                                                   THEN line_revenue
                                               ELSE 0 END) AS revenue_period_1,
                                       SUM(CASE
                                               WHEN invoice_date >= '2011-01-01' AND invoice_date <= '2011-12-31'
                                                   THEN line_revenue
                                               ELSE 0 END) AS revenue_period_2
                                FROM online_retail_clean
                                WHERE transaction_type = 'Sale'
                                  AND stock_code REGEXP '^[0-9]{5}'
                                  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                                GROUP BY stock_code, description)
SELECT stock_code,
       description,
       ROUND(revenue_period_1, 2)                                                 AS sales_2010_legacy,
       ROUND(revenue_period_2, 2)                                                 AS sales_2011,
       ROUND(revenue_period_2 - revenue_period_1, 2)                              AS absolute_decline,
       ROUND(100.0 * (revenue_period_2 - revenue_period_1) / revenue_period_1, 2) AS decline_percentage
FROM product_yearly_revenue
WHERE revenue_period_1 >= 500
  AND revenue_period_2 < revenue_period_1
ORDER BY absolute_decline
LIMIT 10;

-- 36. Which products have the highest cancellation volume?
SELECT stock_code,
       description,
       -SUM(quantity)    AS volume_cancellations,
       SUM(line_revenue) AS revenue_loss
FROM online_retail_clean
WHERE transaction_type = 'Cancellation'
GROUP BY stock_code, description
ORDER BY volume_cancellations DESC;

-- 37. Which products have the highest cancellation rate?
WITH product_cancellations AS (SELECT stock_code,
                                      description,
                                      COUNT(*)                                                                       AS total_transactions,
                                      COUNT(CASE WHEN transaction_type = 'Cancellation' THEN 1 END)                  AS cancellation_count,
                                      ABS(SUM(CASE WHEN transaction_type = 'Cancellation' THEN quantity ELSE 0 END)) AS total_quantity_cancelled,
                                      SUM(CASE WHEN transaction_type = 'Sale' THEN line_revenue ELSE 0 END)          AS gross_revenue_sales
                               FROM online_retail_clean
                               WHERE stock_code REGEXP '^[0-9]{5}'
                                 AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                               GROUP BY stock_code, description)
SELECT stock_code,
       description,
       total_transactions,
       cancellation_count,
       total_quantity_cancelled,
       gross_revenue_sales                                       AS gross_revenue_sales,
       ROUND(100.0 * cancellation_count / total_transactions, 2) AS cancellation_rate_pct
FROM product_cancellations
WHERE total_transactions >= 50
ORDER BY cancellation_rate_pct DESC
LIMIT 10;

-- 38. Which countries generate the most revenue? // 39. Which countries have the most customers?
-- 40. Which countries have the most invoices? // 41. Which countries have the highest AOV?
SELECT country,
       SUM(line_revenue)                                                    AS revenue,
       ROUND((SUM(line_revenue) / SUM(SUM(line_revenue)) OVER ()) * 100, 2) AS pct_of_total_revenue,
       COUNT(DISTINCT customer_id)                                          AS nb_customers,
       COUNT(DISTINCT invoice_no)                                           AS nb_invoices,
       ROUND((SUM(line_revenue) / COUNT(DISTINCT invoice_no)), 2)           AS average_order_value
FROM online_retail_clean
WHERE stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
  AND transaction_type = 'Sale'
  AND customer_id IS NOT NULL
GROUP BY country
ORDER BY revenue DESC;

-- 43. Which countries have the fastest revenue growth?
WITH monthlycountryrevenue AS (SELECT country,
                                      invoice_year,
                                      invoice_month,
                                      SUM(line_revenue) AS revenue
                               FROM online_retail_clean
                               WHERE stock_code REGEXP '^[0-9]{5}'
                                 AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                                 AND transaction_type = 'Sale'
                                 AND customer_id IS NOT NULL
                               GROUP BY country, invoice_year, invoice_month),
     growthcalculation AS (SELECT country,
                                  invoice_year,
                                  invoice_month,
                                  revenue,
                                  LAG(revenue)
                                      OVER (PARTITION BY country ORDER BY invoice_year, invoice_month) AS previous_month_revenue
                           FROM monthlycountryrevenue)
SELECT country,
       invoice_year,
       invoice_month,
       ROUND(revenue, 2)                                                             AS current_revenue,
       ROUND(previous_month_revenue, 2)                                              AS previous_revenue,
       ROUND(((revenue - previous_month_revenue) / previous_month_revenue * 100), 2) AS growth_percentage
FROM growthcalculation
WHERE previous_month_revenue > 0
  AND previous_month_revenue > 500
ORDER BY growth_percentage DESC;

-- 44. Which countries have high customer counts but relatively low revenue?
WITH country_metrics AS (SELECT country,
                                COUNT(DISTINCT customer_id)                     AS nb_customers,
                                SUM(line_revenue)                               AS total_revenue,
                                SUM(line_revenue) / COUNT(DISTINCT customer_id) AS revenue_per_customer
                         FROM online_retail_clean
                         WHERE stock_code REGEXP '^[0-9]{5}'
                           AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                           AND transaction_type = 'Sale'
                           AND customer_id IS NOT NULL
                         GROUP BY country)
SELECT country,
       nb_customers,
       ROUND(total_revenue, 2)        AS total_revenue,
       ROUND(revenue_per_customer, 2) AS revenue_per_customer
FROM country_metrics
WHERE nb_customers > (SELECT AVG(nb_customers) FROM country_metrics)
  AND revenue_per_customer < (SELECT AVG(revenue_per_customer) FROM country_metrics)
ORDER BY revenue_per_customer;

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

-- 80. How many customers are acquired in each cohort?
WITH customer_acquisition AS (SELECT customer_id,
                                     DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS cohort_month
                              FROM online_retail_clean
                              WHERE customer_id IS NOT NULL
                                AND transaction_type = 'Sale'
                              GROUP BY customer_id)
SELECT cohort_month,
       COUNT(customer_id) AS customers_acquired
FROM customer_acquisition
GROUP BY cohort_month
ORDER BY cohort_month;

-- 81. What is the retention rate for each cohort?
WITH customer_cohorts AS (SELECT customer_id,
                                 DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS cohort_month
                          FROM online_retail_clean
                          GROUP BY customer_id),
     customer_activities AS (SELECT o.customer_id,
                                    cc.cohort_month,
                                    PERIOD_DIFF(
                                            DATE_FORMAT(o.invoice_date, '%Y%m'),
                                            REPLACE(cc.cohort_month, '-', '')
                                    ) AS month_number
                             FROM online_retail_clean o
                                      INNER JOIN customer_cohorts cc ON o.customer_id = cc.customer_id),
     cohort_sizes AS (SELECT cohort_month,
                             COUNT(customer_id) AS total_customers
                      FROM customer_cohorts
                      GROUP BY cohort_month)
SELECT a.cohort_month,
       s.total_customers                                                   AS cohort_size,
       a.month_number,
       COUNT(DISTINCT a.customer_id)                                       AS active_customers,
       ROUND(COUNT(DISTINCT a.customer_id) * 100.0 / s.total_customers, 2) AS retention_rate
FROM customer_activities a
         INNER JOIN cohort_sizes s ON a.cohort_month = s.cohort_month
GROUP BY a.cohort_month, s.total_customers, a.month_number
ORDER BY a.cohort_month, a.month_number;

-- 83. Which cohorts have the highest retention?
WITH customer_cohorts AS (SELECT customer_id,
                                 DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS cohort_month
                          FROM online_retail_clean
                          GROUP BY customer_id),
     customer_activities AS (SELECT o.customer_id,
                                    cc.cohort_month,
                                    PERIOD_DIFF(
                                            DATE_FORMAT(o.invoice_date, '%Y%m'),
                                            REPLACE(cc.cohort_month, '-', '')
                                    ) AS month_number
                             FROM online_retail_clean o
                                      INNER JOIN customer_cohorts cc ON o.customer_id = cc.customer_id),
     cohort_sizes AS (SELECT cohort_month, COUNT(DISTINCT customer_id) AS total_customers
                      FROM customer_cohorts
                      GROUP BY cohort_month),
     monthly_retention AS (SELECT a.cohort_month,
                                  s.total_customers,
                                  a.month_number,
                                  COUNT(DISTINCT a.customer_id) * 100.0 / s.total_customers AS retention_rate
                           FROM customer_activities a
                                    JOIN cohort_sizes s ON a.cohort_month = s.cohort_month
                           GROUP BY a.cohort_month, s.total_customers, a.month_number)
SELECT cohort_month,
       total_customers                                                               AS cohort_size,
       ROUND(AVG(CASE WHEN month_number BETWEEN 1 AND 4 THEN retention_rate END), 2) AS avg_early_retention
FROM monthly_retention
GROUP BY cohort_month, total_customers
ORDER BY avg_early_retention DESC;

-- 84. Which cohorts generate the most revenue?
WITH customer_cohorts AS (SELECT customer_id,
                                 DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS cohort_month
                          FROM online_retail_clean
                          GROUP BY customer_id)
SELECT cc.cohort_month,
       COUNT(DISTINCT o.customer_id)                                 AS cohort_size,
       SUM(o.line_revenue)                                           AS total_lifetime_revenue,
       ROUND(SUM(o.line_revenue) / COUNT(DISTINCT o.customer_id), 2) AS revenue_per_customer
FROM online_retail_clean o
         JOIN customer_cohorts cc ON o.customer_id = cc.customer_id
GROUP BY cc.cohort_month
ORDER BY total_lifetime_revenue DESC;

-- 85. How does customer lifetime behavior differ between cohorts?
WITH customer_cohorts AS (SELECT customer_id,
                                 DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS cohort_month
                          FROM online_retail_clean
                          GROUP BY customer_id),
     cohort_sizes AS (SELECT cohort_month, COUNT(DISTINCT customer_id) AS total_customers
                      FROM customer_cohorts
                      GROUP BY cohort_month),
     monthly_revenue AS (SELECT cc.cohort_month,
                                PERIOD_DIFF(
                                        DATE_FORMAT(o.invoice_date, '%Y%m'),
                                        REPLACE(cc.cohort_month, '-', '')
                                )                   AS month_number,
                                SUM(o.line_revenue) AS monthly_rev
                         FROM online_retail_clean o
                                  JOIN customer_cohorts cc ON o.customer_id = cc.customer_id
                         GROUP BY cc.cohort_month, month_number)
SELECT mr.cohort_month,
       mr.month_number,
       mr.monthly_rev,
       SUM(mr.monthly_rev) OVER (PARTITION BY mr.cohort_month ORDER BY mr.month_number) AS cumulative_revenue,
       ROUND(SUM(mr.monthly_rev) OVER (PARTITION BY mr.cohort_month ORDER BY mr.month_number) / s.total_customers,
             2)                                                                         AS cumulative_revenue_per_user
FROM monthly_revenue mr
         JOIN cohort_sizes s ON mr.cohort_month = s.cohort_month
ORDER BY mr.cohort_month, mr.month_number;

-- 86. Which customers are currently inactive?
WITH datasetmax AS (SELECT MAX(invoice_date) AS max_date
                    FROM online_retail_clean
                    WHERE stock_code REGEXP '^[0-9]{5}'
                      AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                      AND transaction_type = 'Sale'
                      AND customer_id IS NOT NULL)
SELECT customer_id,
       MAX(invoice_date)                                                       AS lastpurchasedate,
       EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) AS daysinactive
FROM online_retail_clean
WHERE stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
  AND transaction_type = 'Sale'
  AND customer_id IS NOT NULL
GROUP BY customer_id
HAVING EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) > 30
ORDER BY daysinactive DESC;

-- 87. Which customers meet the defined churn threshold?
WITH datasetmax AS (SELECT MAX(invoice_date) AS max_date
                    FROM online_retail_clean
                    WHERE stock_code REGEXP '^[0-9]{5}'
                      AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                      AND transaction_type = 'Sale'
                      AND customer_id IS NOT NULL)
SELECT customer_id,
       MAX(invoice_date)                                                       AS lastpurchasedate,
       EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) AS daysinactive
FROM online_retail_clean
WHERE stock_code REGEXP '^[0-9]{5}'
  AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
  AND transaction_type = 'Sale'
  AND customer_id IS NOT NULL
GROUP BY customer_id
HAVING EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) > 90
ORDER BY daysinactive DESC;

-- 88. What is the estimated churn rate?
WITH datasetmax AS (SELECT MAX(invoice_date) AS max_date
                    FROM online_retail_clean
                    WHERE stock_code REGEXP '^[0-9]{5}'
                      AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                      AND transaction_type = 'Sale'
                      AND customer_id IS NOT NULL),
     customerstatus AS (SELECT customer_id,
                               CASE
                                   WHEN EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) > 90
                                       THEN 1
                                   ELSE 0
                                   END AS ischurned
                        FROM online_retail_clean
                        WHERE stock_code REGEXP '^[0-9]{5}'
                          AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                          AND transaction_type = 'Sale'
                          AND customer_id IS NOT NULL
                        GROUP BY customer_id)
SELECT COUNT(*)                                    AS totalcustomers,
       SUM(ischurned)                              AS churnedcustomers,
       ROUND(SUM(ischurned) * 100.0 / COUNT(*), 2) AS churnratepercentage
FROM customerstatus;

-- 89. Which high-value customers are at risk?
WITH datasetmax AS (SELECT MAX(invoice_date) AS max_date
                    FROM online_retail_clean
                    WHERE stock_code REGEXP '^[0-9]{5}'
                      AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                      AND transaction_type = 'Sale'
                      AND customer_id IS NOT NULL),
     customermetrics AS (SELECT customer_id,
                                SUM(line_revenue)                                                       AS totalrevenue,
                                EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) AS daysinactive
                         FROM online_retail_clean
                         WHERE stock_code REGEXP '^[0-9]{5}'
                           AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                           AND transaction_type = 'Sale'
                           AND customer_id IS NOT NULL
                         GROUP BY customer_id)
SELECT customer_id, totalrevenue, daysinactive
FROM customermetrics
WHERE totalrevenue >= 5000
  AND daysinactive BETWEEN 60 AND 180
ORDER BY totalrevenue DESC;

-- 90. How much historical revenue is associated with potentially churned customers?
WITH datasetmax AS (SELECT MAX(invoice_date) AS max_date
                    FROM online_retail_clean
                    WHERE stock_code REGEXP '^[0-9]{5}'
                      AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                      AND transaction_type = 'Sale'
                      AND customer_id IS NOT NULL),
     churnedcustomers AS (SELECT customer_id
                          FROM online_retail_clean
                          WHERE stock_code REGEXP '^[0-9]{5}'
                            AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                            AND transaction_type = 'Sale'
                            AND customer_id IS NOT NULL
                          GROUP BY customer_id
                          HAVING EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) > 90)
SELECT ROUND(SUM(line_revenue), 2) AS totallostrevenue
FROM online_retail_clean
WHERE customer_id IN (SELECT customer_id FROM churnedcustomers);

-- 91. Which RFM segments contain the greatest churn risk?
WITH datasetmax AS (SELECT MAX(invoice_date) AS max_date
                    FROM online_retail_clean
                    WHERE stock_code REGEXP '^[0-9]{5}'
                      AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                      AND transaction_type = 'Sale'
                      AND customer_id IS NOT NULL)
        ,
     rfm_raw AS (SELECT customer_id,
                        EXTRACT(DAY FROM (SELECT max_date FROM datasetmax) - MAX(invoice_date)) AS recency,
                        COUNT(DISTINCT invoice_no)                                              AS frequency,
                        SUM(line_revenue)                                                       AS monetary
                 FROM online_retail_clean
                 WHERE stock_code REGEXP '^[0-9]{5}'
                   AND stock_code NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'D', 'CRUK', 'AMAZONFEE')
                   AND transaction_type = 'Sale'
                   AND customer_id IS NOT NULL
                 GROUP BY customer_id),
     rfm_scores AS (SELECT *,
                           NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
                           NTILE(5) OVER (ORDER BY frequency )   AS f_score,
                           NTILE(5) OVER (ORDER BY monetary )    AS m_score
                    FROM rfm_raw)
SELECT r_score,
       f_score,
       m_score,
       COUNT(*)                                                                   AS customercount,
       SUM(CASE WHEN recency > 90 THEN 1 ELSE 0 END)                              AS churnedcount,
       ROUND(SUM(CASE WHEN recency > 90 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS segmentchurnriskpct
FROM rfm_scores
GROUP BY r_score, f_score, m_score
ORDER BY segmentchurnriskpct DESC, customercount DESC;

-- 92. What is the cumulative revenue over time?
WITH daily_revenue AS (SELECT CAST(invoice_date AS DATE) AS revenue_date,
                              SUM(line_revenue)          AS daily_rev
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'
                       GROUP BY CAST(invoice_date AS DATE))
SELECT revenue_date,
       daily_rev,
       SUM(daily_rev) OVER (ORDER BY revenue_date) AS cumulative_revenue
FROM daily_revenue
ORDER BY revenue_date;

-- 93. What is the rolling 30-day revenue?
-- 93. What is the rolling 30-day revenue?

WITH RECURSIVE
    date_range AS (SELECT MIN(DATE(invoice_date)) AS min_date,
                          MAX(DATE(invoice_date)) AS max_date
                   FROM online_retail_clean
                   WHERE transaction_type = 'Sale'),

    calendar AS (SELECT min_date AS revenue_date
                 FROM date_range

                 UNION ALL

                 SELECT DATE_ADD(revenue_date, INTERVAL 1 DAY)
                 FROM calendar
                          CROSS JOIN date_range
                 WHERE revenue_date < max_date),

    daily_revenue AS (SELECT DATE(invoice_date) AS revenue_date,
                             SUM(line_revenue)  AS daily_rev
                      FROM online_retail_clean
                      WHERE transaction_type = 'Sale'
                      GROUP BY DATE(invoice_date)),

    complete_daily_revenue AS (SELECT c.revenue_date,
                                      COALESCE(d.daily_rev, 0) AS daily_rev
                               FROM calendar c
                                        LEFT JOIN daily_revenue d
                                                  ON c.revenue_date = d.revenue_date)

SELECT revenue_date,
       ROUND(daily_rev, 2) AS daily_rev,
       ROUND(
               SUM(daily_rev) OVER (
                   ORDER BY revenue_date
                   ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
                   ),
               2
       )                   AS rolling_30_day_revenue
FROM complete_daily_revenue
ORDER BY revenue_date;

-- 94. What is the 7-day moving average?
WITH RECURSIVE date_range AS (
    SELECT
        MIN(DATE(invoice_date)) AS min_date,
        MAX(DATE(invoice_date)) AS max_date
    FROM online_retail_clean
    WHERE transaction_type = 'Sale'
),

calendar AS (
    SELECT min_date AS revenue_date
    FROM date_range

    UNION ALL

    SELECT DATE_ADD(revenue_date, INTERVAL 1 DAY)
    FROM calendar
    CROSS JOIN date_range
    WHERE revenue_date < max_date
),

daily_revenue AS (
    SELECT
        DATE(invoice_date) AS revenue_date,
        SUM(line_revenue) AS daily_rev
    FROM online_retail_clean
    WHERE transaction_type = 'Sale'
    GROUP BY DATE(invoice_date)
),

complete_daily_revenue AS (
    SELECT
        c.revenue_date,
        COALESCE(d.daily_rev, 0) AS daily_rev
    FROM calendar c
    LEFT JOIN daily_revenue d
        ON c.revenue_date = d.revenue_date
)

SELECT
    revenue_date,
    ROUND(daily_rev, 2) AS daily_rev,
    ROUND(
        AVG(daily_rev) OVER (
            ORDER BY revenue_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_average_7_day
FROM complete_daily_revenue
ORDER BY revenue_date;

-- 95. How does daily revenue change relative to the previous day?
WITH daily_revenue AS (SELECT CAST(invoice_date AS DATE) AS revenue_date,
                              SUM(line_revenue)          AS daily_rev
                       FROM online_retail_clean
                       WHERE transaction_type = 'Sale'
                       GROUP BY CAST(invoice_date AS DATE)),
     daily_changes AS (SELECT revenue_date,
                              daily_rev,
                              LAG(daily_rev) OVER (ORDER BY revenue_date) AS prev_day_rev
                       FROM daily_revenue)
SELECT revenue_date,
       daily_rev,
       prev_day_rev,
       (daily_rev - prev_day_rev)                                  AS absolute_change,
       ROUND((daily_rev - prev_day_rev) * 100.0 / prev_day_rev, 2) AS percentage_change
FROM daily_changes
ORDER BY revenue_date;

-- 96. How does monthly revenue change relative to the previous month?
WITH monthly_revenue AS (SELECT invoice_year,
                                invoice_quarter,
                                COALESCE(DATE_FORMAT(invoice_date, '%Y-%m'), 'Unknown') AS revenue_month,
                                SUM(line_revenue)                                       AS monthly_rev
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                         GROUP BY invoice_year, invoice_quarter, DATE_FORMAT(invoice_date, '%Y-%m')),
     monthly_changes AS (SELECT revenue_month,
                                monthly_rev,
                                LAG(monthly_rev) OVER (ORDER BY revenue_month) AS prev_month_rev
                         FROM monthly_revenue)
SELECT revenue_month,
       monthly_rev,
       prev_month_rev,
       (monthly_rev - prev_month_rev)                                    AS absolute_change,
       ROUND((monthly_rev - prev_month_rev) * 100.0 / prev_month_rev, 2) AS percentage_change
FROM monthly_changes
ORDER BY revenue_month;

-- 97. How much revenue comes from new customers vs returning customers?
WITH customer_first_purchase AS (SELECT customer_id,
                                        MIN(CAST(invoice_date AS DATE)) AS first_purchase_date
                                 FROM online_retail_clean
                                 WHERE customer_id IS NOT NULL
                                   AND transaction_type = 'Sale'
                                 GROUP BY customer_id)
SELECT CAST(o.invoice_date AS DATE) AS revenue_date,
       SUM(CASE
               WHEN CAST(o.invoice_date AS DATE) = cfp.first_purchase_date THEN o.line_revenue
               ELSE 0 END)          AS new_customer_revenue,
       SUM(CASE
               WHEN CAST(o.invoice_date AS DATE) > cfp.first_purchase_date THEN o.line_revenue
               ELSE 0 END)          AS returning_customer_revenue
FROM online_retail_clean o
         INNER JOIN customer_first_purchase cfp ON o.customer_id = cfp.customer_id
WHERE o.transaction_type = 'Sale'
GROUP BY CAST(o.invoice_date AS DATE)
ORDER BY revenue_date;

-- 98. How concentrated is revenue across products?
WITH product_revenue AS (SELECT stock_code, -- change to product_id if applicable
                                SUM(line_revenue) AS total_product_revenue
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                         GROUP BY stock_code),
     total_revenue_pool AS (SELECT SUM(total_product_revenue) AS grand_total
                            FROM product_revenue),
     running_percentages AS (SELECT stock_code,
                                    total_product_revenue,
                                    SUM(total_product_revenue) OVER (ORDER BY total_product_revenue DESC) AS cumulative_revenue
                             FROM product_revenue)
SELECT rp.stock_code,
       rp.total_product_revenue,
       ROUND(rp.total_product_revenue * 100.0 / tr.grand_total, 2) AS revenue_share_pct,
       ROUND(rp.cumulative_revenue * 100.0 / tr.grand_total, 2)    AS cumulative_revenue_share_pct
FROM running_percentages rp
         CROSS JOIN total_revenue_pool tr
ORDER BY rp.total_product_revenue DESC;

-- 99. What is the total quantity sold per product?
SELECT stock_code,
       description,
       SUM(quantity) AS total_quantity_sold
FROM online_retail_clean
WHERE transaction_type = 'Sale'
GROUP BY stock_code, description
ORDER BY total_quantity_sold DESC;

-- 100. What is the average monthly demand per product?
WITH product_monthly_demand AS (SELECT stock_code,
                                       invoice_year,
                                       invoice_month,
                                       SUM(quantity) AS monthly_quantity
                                FROM online_retail_clean
                                WHERE transaction_type = 'Sale'
                                GROUP BY stock_code, invoice_year, invoice_month)
SELECT stock_code,
       ROUND(AVG(monthly_quantity), 2) AS avg_monthly_demand -- Average monthly demand during months when the product was sold.
FROM product_monthly_demand
GROUP BY stock_code
ORDER BY avg_monthly_demand DESC;

-- 101. Which products have consistently high demand?
WITH product_monthly_stats AS (SELECT stock_code,
                                      AVG(monthly_quantity)    AS avg_demand,
                                      STDDEV(monthly_quantity) AS stddev_demand
                               FROM (SELECT stock_code, invoice_year, invoice_month, SUM(quantity) AS monthly_quantity
                                     FROM online_retail_clean
                                     WHERE transaction_type = 'Sale'
                                     GROUP BY stock_code, invoice_year, invoice_month) t
                               GROUP BY stock_code)
SELECT stock_code,
       ROUND(avg_demand, 2)                 AS avg_monthly_demand,
       ROUND(stddev_demand / avg_demand, 2) AS coefficient_of_variation
FROM product_monthly_stats
WHERE avg_demand > 100
ORDER BY coefficient_of_variation, avg_demand DESC;

-- 102. Which products have increasing demand?
WITH product_halves AS (SELECT stock_code,
                               SUM(CASE
                                       WHEN invoice_year = (SELECT MIN(invoice_year) FROM online_retail_clean)
                                           THEN quantity
                                       ELSE 0 END) AS first_half_qty,
                               SUM(CASE
                                       WHEN invoice_year = (SELECT MAX(invoice_year) FROM online_retail_clean)
                                           THEN quantity
                                       ELSE 0 END) AS second_half_qty
                        FROM online_retail_clean
                        WHERE transaction_type = 'Sale'
                        GROUP BY stock_code)
SELECT stock_code,
       first_half_qty,
       second_half_qty,
       (second_half_qty - first_half_qty)                                                 AS net_increase,
       ROUND(((second_half_qty - first_half_qty) * 100.0) / NULLIF(first_half_qty, 0), 2) AS growth_percentage
FROM product_halves
WHERE second_half_qty > first_half_qty
ORDER BY net_increase DESC;

-- 103. Which products have declining demand?
WITH product_halves AS (SELECT stock_code,
                               SUM(CASE
                                       WHEN invoice_year = (SELECT MIN(invoice_year) FROM online_retail_clean)
                                           THEN quantity
                                       ELSE 0 END) AS first_half_qty,
                               SUM(CASE
                                       WHEN invoice_year = (SELECT MAX(invoice_year) FROM online_retail_clean)
                                           THEN quantity
                                       ELSE 0 END) AS second_half_qty
                        FROM online_retail_clean
                        WHERE transaction_type = 'Sale'
                        GROUP BY stock_code)
SELECT stock_code,
       first_half_qty,
       second_half_qty,
       (first_half_qty - second_half_qty)                                                 AS net_decline,
       ROUND(((second_half_qty - first_half_qty) * 100.0) / NULLIF(first_half_qty, 0), 2) AS decline_percentage
FROM product_halves
WHERE second_half_qty < first_half_qty
ORDER BY net_decline DESC;

-- 104. Which products have highly volatile demand?
WITH product_monthly_stats AS (SELECT stock_code,
                                      AVG(monthly_quantity)    AS avg_demand,
                                      STDDEV(monthly_quantity) AS stddev_demand
                               FROM (SELECT stock_code, invoice_year, invoice_month, SUM(quantity) AS monthly_quantity
                                     FROM online_retail_clean
                                     WHERE transaction_type = 'Sale'
                                     GROUP BY stock_code, invoice_year, invoice_month) t
                               GROUP BY stock_code)
SELECT stock_code,
       ROUND(avg_demand, 2)                            AS avg_monthly_demand,
       ROUND(stddev_demand, 2)                         AS demand_volatility,
       ROUND(stddev_demand / NULLIF(avg_demand, 0), 2) AS coefficient_of_variation
FROM product_monthly_stats
WHERE avg_demand > 10
ORDER BY coefficient_of_variation DESC;

-- 105. Which products show seasonal demand?
WITH quarterly_shares AS (SELECT stock_code,
                                 invoice_quarter,
                                 SUM(quantity)                                     AS quarter_qty,
                                 SUM(SUM(quantity)) OVER (PARTITION BY stock_code) AS total_year_qty
                          FROM online_retail_clean
                          WHERE transaction_type = 'Sale'
                          GROUP BY stock_code, invoice_quarter)
SELECT stock_code,
       invoice_quarter                                AS peak_quarter,
       quarter_qty,
       total_year_qty,
       ROUND((quarter_qty / total_year_qty) * 100, 2) AS quarter_quantity_share_pct
FROM quarterly_shares
WHERE (quarter_qty / total_year_qty) > 0.45
ORDER BY quarter_quantity_share_pct DESC;

-- 106. Which products experience unusual demand spikes?
WITH daily_demand AS (SELECT stock_code, DATE(invoice_date) AS order_date, SUM(quantity) AS daily_qty
                      FROM online_retail_clean
                      WHERE transaction_type = 'Sale'
                      GROUP BY stock_code, DATE(invoice_date)),
     product_stats AS (SELECT stock_code, AVG(daily_qty) AS avg_daily_qty, STDDEV(daily_qty) AS stddev_daily_qty
                       FROM daily_demand
                       GROUP BY stock_code)
SELECT d.stock_code,
       d.order_date,
       d.daily_qty                                                               AS spiked_quantity,
       ROUND(s.avg_daily_qty, 2)                                                 AS historical_avg_day,
       ROUND((d.daily_qty - s.avg_daily_qty) / NULLIF(s.stddev_daily_qty, 0), 2) AS z_score
FROM daily_demand d
         JOIN product_stats s ON d.stock_code = s.stock_code
WHERE d.daily_qty > (s.avg_daily_qty + (3 * s.stddev_daily_qty))
  AND s.avg_daily_qty > 5
ORDER BY z_score DESC;

-- 107. Which products have low and declining demand?
WITH product_halves AS (SELECT stock_code,
                               SUM(CASE
                                       WHEN invoice_year = (SELECT MIN(invoice_year) FROM online_retail_clean)
                                           THEN quantity
                                       ELSE 0 END) AS first_half_qty,
                               SUM(CASE
                                       WHEN invoice_year = (SELECT MAX(invoice_year) FROM online_retail_clean)
                                           THEN quantity
                                       ELSE 0 END) AS second_half_qty
                        FROM online_retail_clean
                        WHERE transaction_type = 'Sale'
                        GROUP BY stock_code)
SELECT stock_code,
       first_half_qty,
       second_half_qty,
       (second_half_qty - first_half_qty) AS trajectory
FROM product_halves
-- Faible volume global en fin de période ET trajectoire négative
WHERE second_half_qty < 20
  AND second_half_qty < first_half_qty
ORDER BY second_half_qty, trajectory;

-- 108. Which products belong to ABC classes A, B and C?
WITH product_revenue AS (SELECT stock_code, SUM(line_revenue) AS total_rev
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                         GROUP BY stock_code),
     cumulative_share AS (SELECT stock_code,
                                 total_rev,
                                 SUM(total_rev) OVER (ORDER BY total_rev DESC) AS running_total,
                                 SUM(total_rev) OVER ()                        AS total_pool
                          FROM product_revenue)
SELECT stock_code,
       total_rev,
       ROUND((total_rev * 100.0 / total_pool), 2) AS revenue_share_pct,
       CASE
           WHEN (running_total / total_pool) <= 0.80 THEN 'A'
           WHEN (running_total / total_pool) <= 0.95 THEN 'B'
           ELSE 'C'
           END                                    AS abc_class
FROM cumulative_share
ORDER BY total_rev DESC;

-- 109. Which products require the highest demand-monitoring priority?
WITH product_metrics AS (SELECT stock_code,
                                SUM(line_revenue) AS total_rev,
                                AVG(quantity)     AS avg_qty,
                                STDDEV(quantity)  AS stddev_qty
                         FROM online_retail_clean
                         WHERE transaction_type = 'Sale'
                         GROUP BY stock_code),
     abc_xyz_matrix AS (SELECT stock_code,
                               total_rev,
                               (stddev_qty / NULLIF(avg_qty, 0))                                      AS cv,
                               SUM(total_rev) OVER (ORDER BY total_rev DESC) / SUM(total_rev) OVER () AS running_pct
                        FROM product_metrics)
SELECT stock_code,
       total_rev,
       ROUND(cv, 2)                         AS volatility_score,
       'High Priority (A-Class & Volatile)' AS monitoring_status
FROM abc_xyz_matrix
WHERE running_pct <= 0.80 -- Classe A (80% du CA)
  AND cv > 1.00           -- Forte volatilité (Demande instable)
ORDER BY cv DESC, total_rev DESC;

-- # Phase 18 — Product Lifecycle

WITH global_dates AS (
    /* Get the latest transaction date in the dataset */
    SELECT MAX(invoice_date) AS max_date
    FROM online_retail_clean
    WHERE transaction_type = 'Sale'),
     quarterly_demand AS (
         /* Calculate total product demand for each quarter */
         SELECT stock_code,
                invoice_year,
                invoice_quarter,
                SUM(quantity) AS total_qty
         FROM online_retail_clean
         WHERE transaction_type = 'Sale'
         GROUP BY stock_code,
                  invoice_year,
                  invoice_quarter),
     quarterly_comparison AS (
         /* Compare each quarter with the previous quarter */
         SELECT stock_code,
                invoice_year,
                invoice_quarter,
                total_qty AS current_qty,
                LAG(total_qty) OVER (
                    PARTITION BY stock_code
                    ORDER BY invoice_year, invoice_quarter
                    )     AS previous_qty,

                ROW_NUMBER() OVER (
                    PARTITION BY stock_code
                    ORDER BY invoice_year DESC, invoice_quarter DESC
                    )     AS latest_quarter_rank
         FROM quarterly_demand),
     latest_product_trend AS (
         /* Keep only the most recent quarter for each product */
         SELECT stock_code,
                invoice_year,
                invoice_quarter,
                previous_qty,
                current_qty,
                current_qty - previous_qty AS volume_change,
                ROUND(
                        ((current_qty - previous_qty) * 100.0)
                            / NULLIF(previous_qty, 0),
                        2
                )                          AS growth_pct
         FROM quarterly_comparison
         WHERE latest_quarter_rank = 1),
     product_metrics AS (
         /* Calculate overall product history and demand metrics */
         SELECT stock_code,
                MIN(invoice_date) AS first_sale_date,
                MAX(invoice_date) AS last_sale_date,
                DATEDIFF(
                        MAX(invoice_date),
                        MIN(invoice_date)
                )                 AS active_selling_days,
                AVG(quantity)     AS avg_quantity,
                STDDEV(quantity)  AS stddev_quantity
         FROM online_retail_clean
         WHERE transaction_type = 'Sale'
         GROUP BY stock_code)
SELECT p.stock_code,
    /* Product History */
       DATE(p.first_sale_date) AS first_sale_date,
       DATE(p.last_sale_date)  AS last_sale_date,
       p.active_selling_days,
       DATEDIFF(
               g.max_date,
               p.last_sale_date
       )                       AS days_since_last_sale,
    /* Demand Trend Metrics */
       l.previous_qty,
       l.current_qty,
       l.volume_change,
       l.growth_pct,
    /* Product Stability */
       ROUND(
               p.avg_quantity,
               2
       )                       AS average_quantity,
       ROUND(
               p.stddev_quantity
                   / NULLIF(p.avg_quantity, 0),
               2
       )                       AS stability_index,
    /* =========================
       1. LIFECYCLE STAGE
       ========================= */
       CASE
           WHEN DATEDIFF(
                        g.max_date,
                        p.first_sale_date
                ) < 90
               THEN 'Newly Introduced'
           WHEN p.active_selling_days >= 180
               THEN 'Mature'
           ELSE 'Developing'
           END                 AS lifecycle_stage,
    /* =========================
       2. DEMAND TREND
       ========================= */
       CASE
           WHEN l.previous_qty IS NULL
               THEN 'Insufficient History'
           WHEN l.current_qty > l.previous_qty
               THEN 'Growing'
           WHEN l.current_qty < l.previous_qty
               THEN 'Declining'
           ELSE 'Stable'
           END                 AS demand_trend,
    /* =========================
       3. ACTIVITY STATUS
       ========================= */
       CASE
           WHEN p.last_sale_date <
                g.max_date - INTERVAL 90 DAY
               THEN 'Inactive'
           ELSE 'Active'
           END                 AS activity_status,
    /* =========================
       4. SELLING LONGEVITY
       ========================= */
       CASE
           WHEN p.active_selling_days < 90
               THEN 'Short-Term'
           WHEN p.active_selling_days BETWEEN 90 AND 364
               THEN 'Medium-Term'
           ELSE 'Long-Term'
           END                 AS selling_longevity
FROM product_metrics p
         LEFT JOIN latest_product_trend l
                   ON p.stock_code = l.stock_code
         CROSS JOIN global_dates g
ORDER BY p.active_selling_days DESC,
         l.growth_pct DESC;

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