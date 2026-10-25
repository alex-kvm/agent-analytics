-- The answer to the product team. Run after dbt build:  duckdb -readonly analytics.duckdb < analyses/active_customers.sql

-- 1. Active organizations and active users by month (complete months, April to September 2026, UTC).
-- Active users are distinct users (is_active_user): fct_org_activity_monthly.active_users counts a user once per
-- organization and doesn't add across organizations.
with users as (
    select activity_month, count(distinct user_id) filter (where is_active_user) as active_users
    from fct_user_activity_monthly
    group by 1
)
select
    o.activity_month,
    count(*) as customer_orgs,
    count(*) filter (where o.is_active) as active_orgs,
    round(100.0 * count(*) filter (where o.is_active) / count(*), 1) as pct_active,
    count(*) filter (where o.activity_type = 'ui_and_runs') as ui_and_runs,
    count(*) filter (where o.activity_type = 'ui_only') as ui_only,
    count(*) filter (where o.activity_type = 'runs_only') as runs_only,
    any_value(u.active_users) as active_users
from fct_org_activity_monthly as o
left join users as u using (activity_month)
group by 1
order by 1;

-- 2. Which parts of the product active organizations use, September 2026 (count and share of active organizations).
with sep as (select * from fct_org_activity_monthly where activity_month = date '2026-09-01' and is_active)
select
    count(*) as active_orgs,
    count(*) filter (where product_areas like '%tracing%') as n_tracing,
    count(*) filter (where product_areas like '%playground%') as n_playground,
    count(*) filter (where product_areas like '%studio%') as n_studio,
    count(*) filter (where product_areas like '%experiments%') as n_experiments,
    count(*) filter (where product_areas like '%online_evaluation%') as n_online_evaluation,
    round(100.0 * count(*) filter (where product_areas like '%tracing%') / count(*), 1) as pct_tracing,
    round(100.0 * count(*) filter (where product_areas like '%playground%') / count(*), 1) as pct_playground,
    round(100.0 * count(*) filter (where product_areas like '%studio%') / count(*), 1) as pct_studio,
    round(100.0 * count(*) filter (where product_areas like '%datasets%') / count(*), 1) as pct_datasets,
    round(100.0 * count(*) filter (where product_areas like '%experiments%') / count(*), 1) as pct_experiments,
    round(100.0 * count(*) filter (where product_areas like '%online_evaluation%') / count(*), 1) as pct_online_evaluation
from sep;

-- 3. Active organizations in September 2026 by plan and personal.
select plan, is_personal, count(*) filter (where is_active) as active_orgs, count(*) as customer_orgs
from fct_org_activity_monthly
where activity_month = date '2026-09-01'
group by 1, 2
order by 1, 2;

-- 4. Active-source runs by product area and month.
select
    activity_month,
    sum(tracing_runs) as tracing,
    sum(playground_runs) as playground,
    sum(studio_runs) as studio,
    sum(experiments_runs) as experiments,
    sum(online_evaluation_runs) as online_evaluation
from fct_org_activity_monthly
group by 1
order by 1;

-- 4b. September over April, by area.
with m as (
    select
        activity_month,
        sum(tracing_runs) as tracing, sum(playground_runs) as playground, sum(studio_runs) as studio,
        sum(experiments_runs) as experiments, sum(online_evaluation_runs) as online_evaluation
    from fct_org_activity_monthly
    group by 1
)
select
    round(s.tracing / a.tracing, 1) as tracing_x,
    round(s.playground / a.playground, 1) as playground_x,
    round(s.studio / a.studio, 1) as studio_x,
    round(s.experiments / a.experiments, 1) as experiments_x,
    round(s.online_evaluation / a.online_evaluation, 1) as online_evaluation_x
from m as a, m as s
where a.activity_month = date '2026-04-01' and s.activity_month = date '2026-09-01';

-- 5. Breadth: how many product areas each active organization used, September 2026.
select
    length(product_areas) - length(replace(product_areas, ',', '')) + 1 as areas_used,
    count(*) as active_orgs
from fct_org_activity_monthly
where activity_month = date '2026-09-01' and is_active
group by 1
order by 1;

-- 6. Activation by creation month: organizations created April to September 2026, and how many were ever active.
select
    strftime(cast(date_trunc('month', d.created_at) as date), '%Y-%m') as created_month,
    count(distinct d.organization_id) as orgs_created,
    count(distinct f.organization_id) filter (where f.is_active) as ever_active,
    round(100.0 * count(distinct f.organization_id) filter (where f.is_active) / count(distinct d.organization_id), 1) as pct_ever_active
from dim_organizations as d
left join fct_org_activity_monthly as f using (organization_id)
where not d.is_internal and d.created_at >= timestamp '2026-04-01' and d.created_at < timestamp '2026-10-01'
group by 1
order by 1;

-- 7. Retention: organizations active in April 2026 that are still active in September 2026.
select
    count(*) as active_in_april,
    count(*) filter (where s.is_active) as still_active_in_september,
    round(100.0 * count(*) filter (where s.is_active) / count(*), 1) as pct_retained
from fct_org_activity_monthly as a
inner join fct_org_activity_monthly as s
    on s.organization_id = a.organization_id and s.activity_month = date '2026-09-01'
where a.activity_month = date '2026-04-01' and a.is_active;
