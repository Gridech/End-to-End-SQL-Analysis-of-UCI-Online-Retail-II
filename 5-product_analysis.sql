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
