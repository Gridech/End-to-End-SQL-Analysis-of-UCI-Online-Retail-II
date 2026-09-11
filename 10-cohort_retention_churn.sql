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
