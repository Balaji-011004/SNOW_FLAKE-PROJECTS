CREATE WAREHOUSE ENTERPRISE_WH
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

CREATE DATABASE ENTERPRISE_DB;

CREATE SCHEMA ENTERPRISE_DB.SALES_SCHEMA;

USE WAREHOUSE ENTERPRISE_WH;

USE DATABASE ENTERPRISE_DB;

USE SCHEMA SALES_SCHEMA;

CREATE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
field_optionally_enclosed_by='"'
null_if=('null','NULL','');

CREATE STAGE ENTERPRISE_STAGE
FILE_FORMAT = CSV_FORMAT;

LIST @ENTERPRISE_STAGE;

CREATE TABLE CUSTOMERS (
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    membership VARCHAR(20)
);

CREATE TABLE PRODUCTS (
    product_id NUMBER,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price NUMBER(10,2)
);

CREATE TABLE BRANCHES (
    branch_id NUMBER,
    branch_name VARCHAR(100),
    state VARCHAR(50)
);

CREATE OR REPLACE TABLE SALES (
    sale_id NUMBER,
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    quantity NUMBER,
    sale_date DATE,
    total_amount NUMBER(10,2)
);

CREATE TABLE NEW_SALES_STAGING (
    sale_id NUMBER,
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    quantity NUMBER,
    sale_date DATE,
    total_amount NUMBER(10,2)
);

COPY INTO CUSTOMERS
FROM @ENTERPRISE_STAGE/customers.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO PRODUCTS
FROM @ENTERPRISE_STAGE/products.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO BRANCHES
FROM @ENTERPRISE_STAGE/branches.csv
FILE_FORMAT = CSV_FORMAT;

COPY INTO SALES
FROM @ENTERPRISE_STAGE/sales_history.csv
FILE_FORMAT = CSV_FORMAT;

SELECT * FROM SALES
ORDER BY sale_id;

SELECT COUNT(*) AS customer_count
FROM CUSTOMERS;

SELECT COUNT(*) AS product_count
FROM PRODUCTS;

SELECT COUNT(*) AS branch_count
FROM BRANCHES;

SELECT COUNT(*) AS sales_count
FROM SALES;

CREATE OR REPLACE STREAM SALES_STREAM
ON TABLE SALES;

COPY INTO NEW_SALES_STAGING
FROM @ENTERPRISE_STAGE/new_sales.csv
FILE_FORMAT = CSV_FORMAT;

SELECT *
FROM NEW_SALES_STAGING
ORDER BY sale_id;

SELECT *
FROM SALES_STREAM
ORDER BY sale_id;

MERGE INTO SALES AS TARGET
USING NEW_SALES_STAGING AS SOURCE
ON TARGET.sale_id = SOURCE.sale_id

WHEN MATCHED THEN
    UPDATE SET
        TARGET.customer_id = SOURCE.customer_id,
        TARGET.product_id = SOURCE.product_id,
        TARGET.branch_id = SOURCE.branch_id,
        TARGET.quantity = SOURCE.quantity,
        TARGET.sale_date = SOURCE.sale_date,
        TARGET.total_amount = SOURCE.total_amount

WHEN NOT MATCHED THEN
    INSERT (
        sale_id,
        customer_id,
        product_id,
        branch_id,
        quantity,
        sale_date,
        total_amount
    )
    VALUES (
        SOURCE.sale_id,
        SOURCE.customer_id,
        SOURCE.product_id,
        SOURCE.branch_id,
        SOURCE.quantity,
        SOURCE.sale_date,
        SOURCE.total_amount
    );

SELECT *FROM SALES ORDER BY sale_id;

SELECT COUNT(*) AS sales_count FROM SALES;

SELECT
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount,
    METADATA$ACTION,
    METADATA$ISUPDATE
FROM SALES_STREAM
WHERE METADATA$ACTION = 'INSERT'
ORDER BY sale_id;

SELECT
    sale_id,
    COUNT(*) AS record_count
FROM SALES
GROUP BY sale_id
HAVING COUNT(*) > 1
ORDER BY sale_id;

SELECT
    S.sale_id,
    S.customer_id
FROM SALES S
LEFT JOIN CUSTOMERS C
    ON S.customer_id = C.customer_id
WHERE C.customer_id IS NULL
ORDER BY S.sale_id;

SELECT
    S.sale_id,
    S.product_id
FROM SALES S
LEFT JOIN PRODUCTS P
    ON S.product_id = P.product_id
WHERE P.product_id IS NULL
ORDER BY S.sale_id;

SELECT COUNT(*) AS new_records
FROM SALES_STREAM
WHERE METADATA$ACTION = 'INSERT';

INSERT INTO SALES (
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount
)
SELECT
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount
FROM NEW_SALES_STAGING
WHERE sale_id = 10;

SELECT *
FROM SALES
WHERE sale_id = 10;

DELETE FROM SALES
WHERE sale_id = 10;


SET DELETE_QUERY_ID = LAST_QUERY_ID();

SELECT *
FROM SALES
BEFORE (STATEMENT => $DELETE_QUERY_ID)
WHERE sale_id = 10;

INSERT INTO SALES (
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount
)
SELECT
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount
FROM SALES
BEFORE (STATEMENT => $DELETE_QUERY_ID)
WHERE sale_id = 10;

SELECT *
FROM SALES
WHERE sale_id = 10;

CREATE OR REPLACE TABLE SALES_TEST
CLONE SALES;

SELECT *
FROM SALES_TEST
ORDER BY sale_id;

INSERT INTO SALES_TEST (
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount
)
VALUES (
    999,
    1,
    101,
    1,
    1,
    '2026-07-15',
    60000
);

SELECT *
FROM SALES_TEST
WHERE sale_id = 999;

SELECT *
FROM SALES
WHERE sale_id = 999;


CREATE OR REPLACE TASK DAILY_SALES_LOAD_TASK
    WAREHOUSE = ENTERPRISE_WH
    SCHEDULE = 'USING CRON 0 1 * * * UTC'
AS
MERGE INTO SALES AS TARGET
USING NEW_SALES_STAGING AS SOURCE
ON TARGET.sale_id = SOURCE.sale_id

WHEN MATCHED THEN
    UPDATE SET
        TARGET.customer_id = SOURCE.customer_id,
        TARGET.product_id = SOURCE.product_id,
        TARGET.branch_id = SOURCE.branch_id,
        TARGET.quantity = SOURCE.quantity,
        TARGET.sale_date = SOURCE.sale_date,
        TARGET.total_amount = SOURCE.total_amount

WHEN NOT MATCHED THEN
    INSERT (
        sale_id,
        customer_id,
        product_id,
        branch_id,
        quantity,
        sale_date,
        total_amount
    )
    VALUES (
        SOURCE.sale_id,
        SOURCE.customer_id,
        SOURCE.product_id,
        SOURCE.branch_id,
        SOURCE.quantity,
        SOURCE.sale_date,
        SOURCE.total_amount
    );

ALTER TASK DAILY_SALES_LOAD_TASK
RESUME;

SHOW TASKS LIKE 'DAILY_SALES_LOAD_TASK';

SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'DAILY_SALES_LOAD_TASK'
ORDER BY SCHEDULED_TIME DESC;

EXECUTE TASK DAILY_SALES_LOAD_TASK;

SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'DAILY_SALES_LOAD_TASK'
ORDER BY SCHEDULED_TIME DESC;

SELECT
    C.customer_id,
    C.customer_name,
    C.membership,
    SUM(S.total_amount) AS total_revenue
FROM CUSTOMERS C
JOIN SALES S
    ON C.customer_id = S.customer_id
GROUP BY
    C.customer_id,
    C.customer_name,
    C.membership
ORDER BY total_revenue DESC;

SELECT
    B.branch_id,
    B.branch_name,
    B.state,
    SUM(S.total_amount) AS total_revenue
FROM BRANCHES B
JOIN SALES S
    ON B.branch_id = S.branch_id
GROUP BY
    B.branch_id,
    B.branch_name,
    B.state
ORDER BY total_revenue DESC;

SELECT
    P.product_id,
    P.product_name,
    P.category,
    SUM(S.quantity) AS total_quantity_sold,
    SUM(S.total_amount) AS total_revenue
FROM PRODUCTS P
JOIN SALES S
    ON P.product_id = S.product_id
GROUP BY
    P.product_id,
    P.product_name,
    P.category
ORDER BY total_revenue DESC;

SELECT
    DATE_TRUNC('MONTH', sale_date) AS sales_month,
    SUM(total_amount) AS monthly_revenue
FROM SALES
GROUP BY DATE_TRUNC('MONTH', sale_date)
ORDER BY sales_month;

SELECT
    C.customer_id,
    C.customer_name,
    SUM(S.total_amount) AS total_revenue
FROM CUSTOMERS C
JOIN SALES S
    ON C.customer_id = S.customer_id
GROUP BY
    C.customer_id,
    C.customer_name
ORDER BY total_revenue DESC
LIMIT 1;

SELECT
    B.branch_id,
    B.branch_name,
    SUM(S.total_amount) AS total_revenue
FROM BRANCHES B
JOIN SALES S
    ON B.branch_id = S.branch_id
GROUP BY
    B.branch_id,
    B.branch_name
ORDER BY total_revenue DESC
LIMIT 1;

SELECT
    P.product_id,
    P.product_name,
    SUM(S.quantity) AS quantity_sold,
    SUM(S.total_amount) AS revenue
FROM PRODUCTS P
JOIN SALES S
    ON P.product_id = S.product_id
GROUP BY
    P.product_id,
    P.product_name
ORDER BY revenue DESC
LIMIT 5;

SELECT
    C.customer_id,
    C.customer_name,
    COUNT(S.sale_id) AS purchase_frequency
FROM CUSTOMERS C
LEFT JOIN SALES S
    ON C.customer_id = S.customer_id
GROUP BY
    C.customer_id,
    C.customer_name
ORDER BY purchase_frequency DESC;

SELECT
    sale_id,
    sale_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY sale_date, sale_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM SALES
ORDER BY sale_date, sale_id;

WITH CUSTOMER_REVENUE AS (
    SELECT
        C.customer_id,
        C.customer_name,
        SUM(S.total_amount) AS total_revenue
    FROM CUSTOMERS C
    JOIN SALES S
        ON C.customer_id = S.customer_id
    GROUP BY
        C.customer_id,
        C.customer_name
)
SELECT
    customer_id,
    customer_name,
    total_revenue,
    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS customer_rank
FROM CUSTOMER_REVENUE
ORDER BY customer_rank;

CREATE OR REPLACE VIEW CUSTOMER_REVENUE AS
SELECT
    C.customer_id,
    C.customer_name,
    C.membership,
    SUM(S.total_amount) AS total_revenue
FROM CUSTOMERS C
JOIN SALES S
    ON C.customer_id = S.customer_id
GROUP BY
    C.customer_id,
    C.customer_name,
    C.membership;

CREATE OR REPLACE VIEW BRANCH_REVENUE AS
SELECT
    B.branch_id,
    B.branch_name,
    B.state,
    SUM(S.total_amount) AS total_revenue
FROM BRANCHES B
JOIN SALES S
    ON B.branch_id = S.branch_id
GROUP BY
    B.branch_id,
    B.branch_name,
    B.state;

SELECT *
FROM CUSTOMER_REVENUE
ORDER BY total_revenue DESC;



SELECT *
FROM BRANCH_REVENUE
ORDER BY total_revenue DESC;