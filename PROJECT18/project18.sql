use warehouse prj10_wh;
create or replace database cleanroom_shared_db;
create or replace schema cleanroom_shared_db.partner_telemetry;

use database cleanroom_shared_db;
use schema partner_telemetry;

-- 1. create bronze target tables
create or replace table bronze_retail_transactions (
    pos_id varchar(50),
    timestamp timestamp_ntz,
    hashed_email varchar(64),
    store_id varchar(50),
    cpg_brand varchar(100),
    basket_value number(10, 2),
    loyalty_tier varchar(20)
);

create or replace table bronze_ad_exposures (
    ad_id varchar(50),
    timestamp timestamp_ntz,
    hashed_email varchar(64),
    campaign_name varchar(100),
    channel varchar(50)
);

-- 2. define internal file format & named internal stage
create or replace file format csv_load_format
    type = 'csv'
    field_delimiter = ','
    parse_header = true
    field_optionally_enclosed_by = '"'
    trim_space = true
    null_if = ('', 'null', 'null');

create or replace stage ingestion_stage
    file_format = csv_load_format;

-- 3. load data from stage into tables
copy into bronze_retail_transactions
from @ingestion_stage/retail_transactions.csv
match_by_column_name = case_insensitive;

copy into bronze_ad_exposures
from @ingestion_stage/ad_exposures.csv
match_by_column_name = case_insensitive;

-- validation
select count(*) as total_retail_records from bronze_retail_transactions;

-- task 2: silver clean room overlap & aggregation layer
create or replace table silver_attribution_match as
select 
    pos.pos_id,
    pos.store_id,
    ad.campaign_name,
    ad.channel,
    pos.basket_value,
    datediff('hour', ad.timestamp, pos.timestamp) as conversion_hours
from bronze_retail_transactions pos
inner join bronze_ad_exposures ad
    on pos.hashed_email = ad.hashed_email;

-- validation
select * from silver_attribution_match;

-- task 3: aggregate-only differential privacy view
create or replace secure view secure_gold_campaign_attribution_performance as
select 
    campaign_name,
    max(channel) as channel,
    count(distinct pos_id) as converted_user_count,
    round(sum(basket_value), 2) as total_attributed_val,
    round(avg(basket_value), 2) as avg_basket_value
from silver_attribution_match
group by campaign_name
having count(distinct pos_id) >= 2;

-- validation
select * from secure_gold_campaign_attribution_performance;

-- task 4: secure data share creation & privilege assignment
create or replace share share_cpg_partner_analytics;

grant usage on database cleanroom_shared_db to share share_cpg_partner_analytics;
grant usage on schema cleanroom_shared_db.partner_telemetry to share share_cpg_partner_analytics;
grant select on view cleanroom_shared_db.partner_telemetry.secure_gold_campaign_attribution_performance 
to share share_cpg_partner_analytics;

-- validation
show shares like 'share_cpg_partner_analytics';

-- task 5: provisioning a reader account for non-snowflake partners
create managed account cpg_reader_acct_01
    admin_name = 'cpg_admin',
    admin_password = 'temporarypassword123!',
    type = reader
    comment = 'reader account for non-snowflake cpg partner telemetry';

alter share share_cpg_partner_analytics add accounts = cpg_reader_acct_01;

create or replace resource monitor rm_cpg_reader_acct
    credit_quota = 100
    frequency = monthly
    start_timestamp = immediately
    triggers 
        on 80 percent do notify
        on 100 percent do suspend;

-- validation
show managed accounts like 'cpg_reader_acct_01';

-- task 6: end-to-end clean room reconciliation & compliance check
with silver_metrics as (
    select round(sum(basket_value), 2) as silver_val 
    from silver_attribution_match
),
gold_metrics as (
    select round(sum(total_attributed_val), 2) as gold_val 
    from secure_gold_campaign_attribution_performance
),
pii_audit as (
    select count(*) as exposed_pii_cols
    from information_schema.columns
    where table_schema = 'partner_telemetry'
      and table_name = 'secure_gold_campaign_attribution_performance'
      and column_name ilike any ('%email%', '%phone%', '%name%', '%address%', '%pos_id%')
)
select 
    s.silver_val as silver_match_val,
    g.gold_val as gold_shared_val,
    iff(p.exposed_pii_cols > 0, true, false) as pii_exposure_flag,
    iff(s.silver_val = g.gold_val and p.exposed_pii_cols = 0, true, false) as reconciled_flag
from silver_metrics s
cross join gold_metrics g
cross join pii_audit p;