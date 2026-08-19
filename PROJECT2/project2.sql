create warehouse if not exists retail_wh
with warehouse_size='xsmall'
auto_suspend=60
auto_resume=true;
use warehouse retail_wh;

create database if not exists retail_db;
use database retail_db;


create schema if not exists sales_schema;
use schema sales_schema;

create or replace file format csv_file_format
type='csv'
field_delimiter=','
skip_header=1
field_optionally_enclosed_by='"'
null_if=('null','NULL','');

create stage retail_stage
file_format = csv_file_format;
list @retail_stage;

show grants on stage retail_stage;


select current_warehouse();
create or replace table customers(customer_id number,customer_name varchar,city varchar,membership varchar);

create or replace table products(product_id number,product_name varchar,category varchar,price number(10,2));

create or replace table branches(branch_id number,branch_name varchar,city varchar);

create or replace table sales(sale_id number,customer_id number,product_id number,branch_id number,quantity number,sale_date date,total_amount number(12,2));

show tables;

COPY INTO CUSTOMERS
FROM @retail_stage/customers.csv
FILE_FORMAT =csv_file_format;

COPY INTO PRODUCTS
FROM @RETAIL_STAGE/products.csv
FILE_FORMAT = csv_file_format;

COPY INTO BRANCHES
FROM @RETAIL_STAGE/branches.csv
FILE_FORMAT = csv_file_format;

COPY INTO SALES
FROM @RETAIL_STAGE/sales.csv
FILE_FORMAT = (FORMAT_NAME = csv_file_format);

select * from customers;

select * from products;

select * from  branches;

select * from sales;

SELECT
    SUM(total_amount) AS total_revenue
FROM SALES;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_spending DESC;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_sales
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_sales DESC;

SELECT
    p.product_id,
    p.product_name,
    SUM(s.total_amount) AS total_revenue
FROM PRODUCTS p
INNER JOIN SALES s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC;

SELECT
    p.category,
    SUM(s.total_amount) AS total_revenue
FROM PRODUCTS p
INNER JOIN SALES s
    ON p.product_id = s.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_sales
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_sales DESC
LIMIT 1;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_spending DESC
LIMIT 1;

SELECT
    p.product_id,
    p.product_name,
    SUM(s.total_amount) AS total_revenue
FROM PRODUCTS p
INNER JOIN SALES s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_spending DESC
LIMIT 3;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending,
    RANK() OVER (
        ORDER BY SUM(s.total_amount) DESC
    ) AS customer_rank
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY customer_rank;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_sales,
    RANK() OVER (
        ORDER BY SUM(s.total_amount) DESC
    ) AS branch_rank
FROM BRANCHES b
INNER JOIN SALES s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY branch_rank;

SELECT
    category,
    product_name,
    total_revenue
FROM (
    SELECT
        p.category,
        p.product_name,
        SUM(s.total_amount) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.category
            ORDER BY SUM(s.total_amount) DESC
        ) AS row_num
    FROM PRODUCTS p
    INNER JOIN SALES s
        ON p.product_id = s.product_id
    GROUP BY
        p.category,
        p.product_name
)
WHERE row_num = 1;

SELECT
    sale_id,
    sale_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sales
FROM SALES
ORDER BY sale_date;

SELECT
    sale_id,
    sale_date,
    total_amount,
    AVG(total_amount) OVER () AS average_sale_amount
FROM SALES
ORDER BY sale_date;

WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS total_spending
    FROM CUSTOMERS c
    INNER JOIN SALES s
        ON c.customer_id = s.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
)
SELECT *
FROM customer_sales
ORDER BY total_spending DESC;

WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS total_spending
    FROM CUSTOMERS c
    INNER JOIN SALES s
        ON c.customer_id = s.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
),
average_sales AS (
    SELECT
        AVG(total_spending) AS average_spending
    FROM customer_sales
)SELECT
    cs.customer_id,
    cs.customer_name,
    cs.total_spending
FROM customer_sales cs
CROSS JOIN average_sales av
WHERE cs.total_spending > av.average_spending
ORDER BY cs.total_spending DESC;

CREATE OR REPLACE VIEW SALES_REPORT AS
SELECT
    s.sale_id,
    c.customer_name,
    p.product_name,
    p.category,
    b.branch_name,
    s.quantity,
    s.sale_date,
    s.total_amount
FROM SALES s
INNER JOIN CUSTOMERS c
    ON s.customer_id = c.customer_id
INNER JOIN PRODUCTS p
    ON s.product_id = p.product_id
INNER JOIN BRANCHES b
    ON s.branch_id = b.branch_id;

SELECT *
FROM SALES_REPORT;

CREATE OR REPLACE VIEW TOP_CUSTOMERS AS
SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM CUSTOMERS c
INNER JOIN SALES s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name;

SELECT *
FROM TOP_CUSTOMERS
ORDER BY total_spending DESC
LIMIT 3;