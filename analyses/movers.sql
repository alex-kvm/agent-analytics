-- What moved from April to September 2026, and which segment carries it. Run after dbt build:
--   duckdb -readonly analytics.duckdb < analyses/movers.sql
-- Complete months only, UTC. Customer organizations exclude internal ones; active users are distinct users.

-- 1. The headline metrics, April against September: absolute and relative change.
with org as (
    select activity_month, count(*) as customer_orgs, count(*) filter (where is_active) as active_orgs
    from fct_org_activity_monthly
    group by 1
),
usr as (
    select activity_month, count(distinct user_id) filter (where is_active_user) as active_users
    from fct_user_activity_monthly
    group by 1
),
m as (select * from org join usr using (activity_month))
-- The share is kept unrounded until the output, so its relative change is computed at full precision.
select
    metric, round(april, 1) as april, round(september, 1) as september, round(september - april, 1) as change,
    round(100.0 * (september - april) / april, 1) as pct_change
from (
    select 'customer_orgs' as metric, max(customer_orgs) filter (where activity_month = date '2026-04-01') as april,
           max(customer_orgs) filter (where activity_month = date '2026-09-01') as september from m
    union all
    select 'active_orgs', max(active_orgs) filter (where activity_month = date '2026-04-01'),
           max(active_orgs) filter (where activity_month = date '2026-09-01') from m
    union all
    select 'active_users', max(active_users) filter (where activity_month = date '2026-04-01'),
           max(active_users) filter (where activity_month = date '2026-09-01') from m
    union all
    select 'pct_active (points)', max(100.0 * active_orgs / customer_orgs) filter (where activity_month = date '2026-04-01'),
           max(100.0 * active_orgs / customer_orgs) filter (where activity_month = date '2026-09-01') from m
)
order by 1;

-- 2. Active organizations by plan and personal: which segment carries the growth (share of the +78).
with s as (
    select
        plan || case when is_personal then ', personal' else '' end as segment,
        count(*) filter (where is_active and activity_month = date '2026-04-01') as active_april,
        count(*) filter (where is_active and activity_month = date '2026-09-01') as active_september
    from fct_org_activity_monthly
    group by 1
)
select segment, active_april, active_september, active_september - active_april as change,
       round(100.0 * (active_september - active_april) / sum(active_september - active_april) over (), 1) as pct_of_change
from s
order by change desc;

-- 3. Active organizations by region (share of the +78).
with s as (
    select region,
           count(*) filter (where is_active and activity_month = date '2026-04-01') as active_april,
           count(*) filter (where is_active and activity_month = date '2026-09-01') as active_september
    from fct_org_activity_monthly
    group by 1
)
select region, active_april, active_september, active_september - active_april as change,
       round(100.0 * (active_september - active_april) / sum(active_september - active_april) over (), 1) as pct_of_change
from s
order by change desc;

-- 4. The active share by creation cohort, September: organizations created before April against those created in it.
select
    case when d.created_at < timestamp '2026-04-01' then 'created before April' else 'created April to September' end as cohort,
    count(*) as customer_orgs,
    count(*) filter (where f.is_active) as active_orgs,
    round(100.0 * count(*) filter (where f.is_active) / count(*), 1) as pct_active
from fct_org_activity_monthly as f
inner join dim_organizations as d using (organization_id)
where f.activity_month = date '2026-09-01'
group by 1
order by 1;

-- 5. The 70 organizations active in April and not in September, against the 168 still active: plan, region,
--    personal, and how many product areas they used in April.
with april as (
    select a.organization_id, a.plan, a.region, a.is_personal,
           length(a.product_areas) - length(replace(a.product_areas, ',', '')) + 1 as areas_april,
           s.is_active as active_september
    from fct_org_activity_monthly as a
    inner join fct_org_activity_monthly as s
        on s.organization_id = a.organization_id and s.activity_month = date '2026-09-01'
    where a.activity_month = date '2026-04-01' and a.is_active
)
select
    case when active_september then 'still active' else 'went quiet' end as group_name,
    count(*) as orgs,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as pct_of_april_active,
    round(100.0 * count(*) filter (where plan = 'free') / count(*), 1) as pct_free,
    round(100.0 * count(*) filter (where is_personal) / count(*), 1) as pct_personal,
    round(100.0 * count(*) filter (where plan = 'enterprise') / count(*), 1) as pct_enterprise,
    round(avg(areas_april), 2) as avg_areas_april,
    round(100.0 * count(*) filter (where areas_april = 1) / count(*), 1) as pct_one_area_april
from april
group by 1
order by 1;

-- 5b. The same 238 organizations by plan: the share of each plan's April-active organizations that went quiet.
with april as (
    select a.plan || case when a.is_personal then ', personal' else '' end as segment, s.is_active as active_september
    from fct_org_activity_monthly as a
    inner join fct_org_activity_monthly as s
        on s.organization_id = a.organization_id and s.activity_month = date '2026-09-01'
    where a.activity_month = date '2026-04-01' and a.is_active
)
select segment, count(*) as active_april, count(*) filter (where not active_september) as went_quiet,
       round(100.0 * count(*) filter (where not active_september) / count(*), 1) as pct_went_quiet
from april
group by 1
order by pct_went_quiet desc;

-- 6. Active-source runs by area, April against September, with the five organizations that add the most in each area.
--    All customer organizations: the 157 created after April have no April row in the spine, so their April runs are 0.
with r as (
    select organization_id, activity_month,
           tracing_runs, playground_runs, studio_runs, experiments_runs, online_evaluation_runs
    from fct_org_activity_monthly
    where activity_month in (date '2026-04-01', date '2026-09-01')
),
long as (
    unpivot r on tracing_runs, playground_runs, studio_runs, experiments_runs, online_evaluation_runs
    into name area value runs
),
by_org as (
    select area, organization_id,
           coalesce(sum(runs) filter (where activity_month = date '2026-09-01'), 0)
             - coalesce(sum(runs) filter (where activity_month = date '2026-04-01'), 0) as added
    from long
    group by 1, 2
),
top5 as (
    select area, sum(added) as top5_added
    from (select *, row_number() over (partition by area order by added desc) as rk from by_org)
    where rk <= 5
    group by 1
)
select
    l.area,
    sum(l.runs) filter (where l.activity_month = date '2026-04-01') as april,
    sum(l.runs) filter (where l.activity_month = date '2026-09-01') as september,
    sum(l.runs) filter (where l.activity_month = date '2026-09-01') - sum(l.runs) filter (where l.activity_month = date '2026-04-01') as change,
    round(100.0 * (sum(l.runs) filter (where l.activity_month = date '2026-09-01') - sum(l.runs) filter (where l.activity_month = date '2026-04-01'))
          / sum(l.runs) filter (where l.activity_month = date '2026-04-01'), 1) as pct_change,
    any_value(t.top5_added) as top5_orgs_added,
    round(100.0 * any_value(t.top5_added) / (sum(l.runs) filter (where l.activity_month = date '2026-09-01') - sum(l.runs) filter (where l.activity_month = date '2026-04-01')), 1) as pct_of_change_from_top5
from long as l
inner join top5 as t using (area)
group by 1
order by 1;

-- 7. Online evaluation: more organizations using it, or more runs per organization?
select
    activity_month,
    count(*) filter (where online_evaluation_runs > 0) as orgs_with_online_evaluation,
    sum(online_evaluation_runs) as online_evaluation_runs,
    round(sum(online_evaluation_runs) / nullif(count(*) filter (where online_evaluation_runs > 0), 0), 1) as runs_per_org
from fct_org_activity_monthly
where activity_month in (date '2026-04-01', date '2026-09-01')
group by 1
order by 1;

-- 8. Distinct active users by segment, April against September: which segment carries the +330. A user is placed in
--    the segment of every organization they were active in, so a user active in organizations of two segments counts
--    in each; the overlap row of each dimension is the segments' sum minus the distinct total, and the segments'
--    shares of the change overlap by that much.
with u as (
    select
        f.activity_month,
        f.user_id,
        d.plan || case when d.is_personal then ', personal' else '' end as plan_segment,
        d.region,
        case when d.created_at < timestamp '2026-04-01' then 'created before April' else 'created April to September' end as cohort
    from fct_user_activity_monthly as f
    inner join dim_organizations as d using (organization_id)
    where f.is_active_user and f.activity_month in (date '2026-04-01', date '2026-09-01')
),
long as (
    unpivot u on plan_segment, region, cohort into name dimension value segment
),
seg as (
    select dimension, segment,
           count(distinct user_id) filter (where activity_month = date '2026-04-01') as users_april,
           count(distinct user_id) filter (where activity_month = date '2026-09-01') as users_september
    from long
    group by 1, 2
),
tot as (
    select count(distinct user_id) filter (where activity_month = date '2026-04-01') as users_april,
           count(distinct user_id) filter (where activity_month = date '2026-09-01') as users_september
    from u
)
select dimension, segment, users_april, users_september, change, pct_change, pct_of_distinct_change
from (
    select s.dimension, s.segment, s.users_april, s.users_september,
           s.users_september - s.users_april as change,
           round(100.0 * (s.users_september - s.users_april) / nullif(s.users_april, 0), 1) as pct_change,
           round(100.0 * (s.users_september - s.users_april) / (t.users_september - t.users_april), 1) as pct_of_distinct_change,
           0 as overlap_row
    from seg as s cross join tot as t
    union all
    select s.dimension, 'overlap (in two or more segments)',
           sum(s.users_april) - any_value(t.users_april), sum(s.users_september) - any_value(t.users_september),
           (sum(s.users_september) - any_value(t.users_september)) - (sum(s.users_april) - any_value(t.users_april)),
           null, null, 1
    from seg as s cross join tot as t
    group by 1
    union all
    select 'all', 'distinct active users', t.users_april, t.users_september, t.users_september - t.users_april,
           round(100.0 * (t.users_september - t.users_april) / t.users_april, 1), 100.0, 2
    from tot as t
)
order by dimension, overlap_row, change desc;

-- 9. Month over month, August against September 2026 (the weekly business review's MoM): each region's change and its
--    share of the worldwide change, from rpt_weekly_business_review. Counts add across regions here (no user was active
--    in two regions); the share's change is in points and in relative terms, from the unrounded shares.
with m as (
    select region, region_order,
           max(customer_orgs) filter (where period_start = date '2026-08-01') as customers_aug,
           max(customer_orgs) filter (where period_start = date '2026-09-01') as customers_sep,
           max(active_orgs) filter (where period_start = date '2026-08-01') as active_aug,
           max(active_orgs) filter (where period_start = date '2026-09-01') as active_sep,
           max(pct_active) filter (where period_start = date '2026-08-01') as share_aug,
           max(pct_active) filter (where period_start = date '2026-09-01') as share_sep,
           max(active_users) filter (where period_start = date '2026-08-01') as users_aug,
           max(active_users) filter (where period_start = date '2026-09-01') as users_sep,
           max(active_source_runs) filter (where period_start = date '2026-08-01') as runs_aug,
           max(active_source_runs) filter (where period_start = date '2026-09-01') as runs_sep
    from rpt_weekly_business_review
    where period = 'month' and period_start in (date '2026-08-01', date '2026-09-01')
    group by 1, 2
),
w as (select * from m where region = 'worldwide')
select
    m.region,
    m.customers_aug, m.customers_sep, m.customers_sep - m.customers_aug as customers_change,
    m.active_aug, m.active_sep, m.active_sep - m.active_aug as active_change,
    round(m.share_aug, 1) as share_aug, round(m.share_sep, 1) as share_sep,
    round(100 * (m.share_sep - m.share_aug)) as share_change_bps, round(100.0 * (m.share_sep - m.share_aug) / m.share_aug, 1) as share_change_pct,
    m.users_aug, m.users_sep, m.users_sep - m.users_aug as users_change,
    round(100.0 * (m.users_sep - m.users_aug) / m.users_aug, 1) as users_change_pct,
    round(100.0 * (m.users_sep - m.users_aug) / (w.users_sep - w.users_aug), 1) as pct_of_users_change,
    m.runs_aug, m.runs_sep, m.runs_sep - m.runs_aug as runs_change,
    round(100.0 * (m.runs_sep - m.runs_aug) / m.runs_aug, 1) as runs_change_pct,
    round(100.0 * (m.runs_sep - m.runs_aug) / (w.runs_sep - w.runs_aug), 1) as pct_of_runs_change
from m cross join w
order by m.region_order;

-- 10. Runs by area, April against September, by region, plan and creation cohort: the segment that carries each
--     area's growth. All customer organizations, the 157 created after April with 0 April runs (as part 6).
with r as (
    select f.organization_id, f.activity_month, f.region,
           d.plan || case when d.is_personal then ', personal' else '' end as plan_segment,
           case when d.created_at < timestamp '2026-04-01' then 'created before April' else 'created April to September' end as cohort,
           f.tracing_runs, f.playground_runs, f.studio_runs, f.experiments_runs, f.online_evaluation_runs
    from fct_org_activity_monthly as f
    inner join dim_organizations as d using (organization_id)
    where f.activity_month in (date '2026-04-01', date '2026-09-01')
),
long as (
    unpivot (unpivot r on tracing_runs, playground_runs, studio_runs, experiments_runs, online_evaluation_runs
             into name area value runs)
    on region, plan_segment, cohort into name dimension value segment
),
seg as (
    select area, dimension, segment,
           coalesce(sum(runs) filter (where activity_month = date '2026-04-01'), 0) as april,
           coalesce(sum(runs) filter (where activity_month = date '2026-09-01'), 0) as september
    from long
    group by 1, 2, 3
)
select area, dimension, segment, april, september, september - april as change,
       round(100.0 * (september - april) / nullif(april, 0), 1) as pct_change,
       round(100.0 * (september - april) / sum(september - april) over (partition by area, dimension), 1) as pct_of_area_change
from seg
order by area, dimension, change desc;
