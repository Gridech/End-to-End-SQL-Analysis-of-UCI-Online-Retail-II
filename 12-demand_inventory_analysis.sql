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