-- Create the cleaned table
CREATE TABLE online_retail_clean AS
SELECT *
FROM online_retail;

-- Standardize Text
UPDATE online_retail_clean
SET country = TRIM(country);

UPDATE online_retail_clean
SET description = TRIM(description);

UPDATE online_retail_clean
SET stock_code = TRIM(stock_code);

-- Standardize Empty Strings
UPDATE online_retail_clean
SET description = NULL
WHERE TRIM(description) = '';

UPDATE online_retail_clean
SET stock_code = NULL
WHERE TRIM(stock_code) = '';

UPDATE online_retail_clean
SET country = NULL
WHERE TRIM(country) = '';

UPDATE online_retail_clean
SET customer_id = NULL
WHERE TRIM(customer_id) = '';

ALTER TABLE online_retail_clean
    MODIFY COLUMN customer_id INT;

-- Handle Exact Duplicate Rows
CREATE TABLE online_retail_clean_dedup AS
SELECT DISTINCT invoice_no,
                stock_code,
                description,
                quantity,
                invoice_date,
                unit_price,
                customer_id,
                country
FROM online_retail_clean;

SELECT (SELECT COUNT(*) FROM online_retail_clean)       AS before_rows,
       (SELECT COUNT(*) FROM online_retail_clean_dedup) AS after_rows;

DROP TABLE online_retail_clean;

RENAME TABLE online_retail_clean_dedup
    TO online_retail_clean;

-- Create Revenue
ALTER TABLE online_retail_clean
    ADD COLUMN line_revenue DECIMAL(14, 2);

UPDATE online_retail_clean
SET line_revenue = quantity * unit_price;

-- Create Date Attributes
ALTER TABLE online_retail_clean
    ADD COLUMN invoice_year       INT,
    ADD COLUMN invoice_month      INT,
    ADD COLUMN invoice_month_name VARCHAR(20),
    ADD COLUMN invoice_quarter    INT,
    ADD COLUMN invoice_week       INT,
    ADD COLUMN invoice_day        INT,
    ADD COLUMN invoice_day_name   VARCHAR(20),
    ADD COLUMN invoice_hour       INT,
    ADD COLUMN is_weekend         BOOLEAN;


UPDATE online_retail_clean
SET invoice_year       = YEAR(invoice_date),

    invoice_month      = MONTH(invoice_date),

    invoice_month_name = MONTHNAME(invoice_date),

    invoice_quarter    = QUARTER(invoice_date),

    invoice_week       = WEEK(invoice_date),

    invoice_day        = DAY(invoice_date),

    invoice_day_name   = DAYNAME(invoice_date),

    invoice_hour       = HOUR(invoice_date),

    is_weekend          =
        CASE
            WHEN DAYOFWEEK(invoice_date) IN (1, 7)
                THEN TRUE
            ELSE FALSE
            END;

-- Create Transaction Type
ALTER TABLE online_retail_clean
ADD COLUMN transaction_type VARCHAR(30);

UPDATE online_retail_clean
SET transaction_type =
    CASE
        WHEN invoice_no LIKE 'C%'
             AND quantity < 0
            THEN 'Cancellation'

        WHEN quantity < 0
            THEN 'Negative Quantity'

        WHEN quantity = 0
            THEN 'Zero Quantity'

        WHEN unit_price <= 0
            THEN 'Invalid Price'

        ELSE 'Sale'
    END;



