SET GLOBAL local_infile = 1;

CREATE TABLE online_retail
(
    invoice_no   VARCHAR(20) ,
    stock_code   VARCHAR(20)  ,
    description  VARCHAR(255) ,
    quantity     INT          ,
    invoice_date DATETIME     ,
    unit_price   DECIMAL(10, 2),
    customer_id  VARCHAR(20),
    country      VARCHAR(100)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE 'C:/Users/hp/DataGripProjects/UCI_Online_Retail/dataset/online_retail_II.csv'
    INTO TABLE online_retail
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    ESCAPED BY ''
    LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
