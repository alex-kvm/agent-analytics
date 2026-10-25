-- The weekly business review table (intent v3 Q6), as the write-up shows it. Run after dbt build:
--   duckdb -readonly -markdown analytics.duckdb < analyses/weekly_business_review.sql
-- Every cell comes from models/reports/rpt_weekly_business_review_table, which reads rpt_weekly_business_review.
select * exclude (sort_key)
from rpt_weekly_business_review_table
order by sort_key;
