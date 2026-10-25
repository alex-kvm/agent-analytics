-- The headline for the last complete period, at whatever var('activity_grain') the project was built with.
-- Run after dbt build:  duckdb -readonly analytics.duckdb < analyses/headline.sql
with last_period as (select max(activity_month) as activity_month from fct_org_activity_monthly)
select
    p.activity_month as period_start,
    (select count(*) filter (where is_active) from fct_org_activity_monthly as o where o.activity_month = p.activity_month) as active_orgs,
    (select count(*) from fct_org_activity_monthly as o where o.activity_month = p.activity_month) as customer_orgs,
    (select count(distinct user_id) filter (where is_active_user) from fct_user_activity_monthly as u where u.activity_month = p.activity_month) as active_users
from last_period as p;
