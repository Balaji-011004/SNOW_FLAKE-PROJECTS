CREATE WAREHOUSE SALES_WH
WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

use warehouse sales_wh;

create database customer_sales_db;
use database customer_sales_db;

create schema sales_schema;
use schema sales_schema;

CREATE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"';

create stage sales_stage
file_format = csv_format;

list @sales_stage;

CREATE TABLE CUSTOMERS (
    customer_id INTEGER,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(100)
);

CREATE TABLE FOODITEMS (
    food_id INTEGER,
    name VARCHAR(100),
    price NUMBER(10,2),
    category VARCHAR(50),
    availability VARCHAR(20)
);

CREATE TABLE ORDERS (
    order_id INTEGER,
    customer_id INTEGER,
    food_id INTEGER,
    quantity INTEGER,
    order_date TIMESTAMP,
    status VARCHAR(30),
    total_amount NUMBER(10,2)
);

COPY INTO CUSTOMERS
FROM @SALES_STAGE/customers.csv
FILE_FORMAT = CSV_FORMAT;

copy into FOODITEMS
from @sales_stage/fooditems.csv
file_format = csv_format;


copy into ORDERS
from @sales_stage/orders.csv
file_format = csv_format;

select * from CUSTOMERS;
select * from FOODITEMS;
select * from ORDERS;

SELECT
    c.customer_id,
    CONCAT(c.first_name,' ', c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_amount_spent
FROM CUSTOMERS c
INNER JOIN ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY total_amount_spent DESC;

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_spent
FROM CUSTOMERS c
INNER JOIN ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY total_spent DESC
LIMIT 1;

SELECT SUM(total_amount) AS total_revenue
FROM ORDERS;

SELECT
    f.category,
    SUM(o.total_amount) AS total_revenue
FROM FOODITEMS f
INNER JOIN ORDERS o
    ON f.food_id = o.food_id
GROUP BY f.category
ORDER BY total_revenue DESC;

SELECT
    status AS order_status,
    SUM(total_amount) AS total_revenue
FROM ORDERS
GROUP BY status
ORDER BY total_revenue DESC;

SELECT
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_spent
FROM CUSTOMERS c
INNER JOIN ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY total_spent DESC
LIMIT 3;

SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(o.order_id) AS orders_placed
FROM CUSTOMERS c
INNER JOIN ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY c.customer_id;

SELECT *
FROM ORDERS
WHERE status = 'Delivered';

SELECT
    o.order_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    o.order_date,
    o.status,
    o.total_amount
FROM ORDERS o
INNER JOIN CUSTOMERS c
    ON o.customer_id = c.customer_id
WHERE o.order_date >= '2026-07-13'
ORDER BY o.order_date;

CREATE VIEW CUSTOMER_SALES_REPORT AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(o.total_amount) AS total_amount_spent
FROM CUSTOMERS c
INNER JOIN ORDERS o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name;

SELECT *
FROM CUSTOMER_SALES_REPORT;

SELECT *
FROM CUSTOMER_SALES_REPORT
ORDER BY total_amount_spent DESC;
