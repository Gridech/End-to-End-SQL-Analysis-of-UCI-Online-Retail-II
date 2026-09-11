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

