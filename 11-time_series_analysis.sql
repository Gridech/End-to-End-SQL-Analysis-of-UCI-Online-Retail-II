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
