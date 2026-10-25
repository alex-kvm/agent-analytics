-- Weekly business review, the data tab: the facts' counts by period and region, for the golden example's table
-- (rpt_weekly_business_review_table reads it; the write-up and the board show that).
-- Grain: one row per period type (day, week, month), period start and region, with a worldwide row for each period.
-- The counts follow the facts' rules and vars: active_user_min_days, active_org_min_users, active_org_min_runs,
-- active_run_sources and include_personal_orgs. It doesn't read var('activity_grain'): every grain is computed here, so
-- a build at another grain can check it against the marts.
-- Weeks run Monday to Sunday, UTC. A period that isn't wholly inside the reporting window (reporting_start to
-- reporting_end) has null metrics, so a part-week reads as blank, never as a drop: the week of 30 March starts before
-- April, and the week of 28 September has three days before October, which is left out.

with params as (
    select
        cast('{{ var("reporting_start") }}' as timestamp) as window_start
        , cast('{{ var("reporting_end") }}' as timestamp) as window_end   -- exclusive: October has three days of events
),

grains as (
    -- One row per period type; step is one period, so period_end_date = period_start + step - 1 day.
    select *
    from (values ('day', interval 1 day), ('week', interval 7 day), ('month', interval 1 month)) as t(period, step)
),

periods as (
    select
        g.period
        , cast(p.period_start as date) as period_start
        , cast(p.period_start + g.step - interval 1 day as date) as period_end_date
        , p.period_start >= x.window_start and p.period_start + g.step <= x.window_end as is_complete
    from grains as g
    cross join params as x
    cross join lateral (
        select unnest(generate_series(cast(date_trunc(g.period, x.window_start) as timestamp), x.window_end - interval 1 day, g.step)) as period_start
    ) as p
),

orgs as (
    -- Customer organizations: the facts' filter.
    select organization_id, region, created_at
    from {{ ref('int_organizations') }}
    where not is_internal{% if not var('include_personal_orgs') %} and not is_personal{% endif %}
),

events as (
    -- Customer users' product activity in customer organizations, inside the window: the user fact's events.
    select e.user_id, e.organization_id, e.event_at, e.event_date
    from {{ ref('int_user_events') }} as e
    inner join {{ ref('stg_app__users') }} as u on u.user_id = e.user_id and not u.is_internal
    inner join orgs as o on o.organization_id = e.organization_id
    cross join params as x
    where e.is_activity and e.user_id is not null
      and e.event_at >= x.window_start and e.event_at < x.window_end
),

runs as (
    -- Runs in customer organizations inside the window: the organization fact's runs.
    select r.organization_id, r.started_at, r.counts_as_activity, r.product_area
    from {{ ref('int_runs') }} as r
    inner join orgs as o on o.organization_id = r.organization_id
    cross join params as x
    where r.started_at >= x.window_start and r.started_at < x.window_end
),

user_org_periods as (
    -- One row per user, organization and period with activity: days in this organization and across all of them.
    select
        g.period
        , cast(date_trunc(g.period, e.event_at) as date) as period_start
        , e.user_id
        , e.organization_id
        , count(distinct e.event_date) as active_days
    from events as e
    cross join grains as g
    group by all
),

user_periods as (
    select
        g.period
        , cast(date_trunc(g.period, e.event_at) as date) as period_start
        , e.user_id
        , count(distinct e.event_date) >= {{ var('active_user_min_days') }} as is_active_user
    from events as e
    cross join grains as g
    group by all
),

org_periods as (
    -- The organization spine: every customer organization in every period from the one it was created in, so inactive
    -- organizations stay in the denominator (as fct_org_activity_monthly).
    select p.period, p.period_start, o.organization_id, o.region
    from periods as p
    inner join grains as g using (period)
    inner join orgs as o on o.created_at < p.period_start + g.step
),

org_users as (
    select period, period_start, organization_id, count(*) filter (where active_days >= {{ var('active_user_min_days') }}) as active_users
    from user_org_periods
    group by all
),

org_runs as (
    select
        g.period
        , cast(date_trunc(g.period, r.started_at) as date) as period_start
        , r.organization_id
        , count(*) filter (where r.counts_as_activity) as active_source_runs
        , count(*) filter (where r.product_area = 'online_evaluation') as online_evaluation_runs
    from runs as r
    cross join grains as g
    group by all
),

org_activity as (
    select
        s.period
        , s.period_start
        , s.organization_id
        , s.region
        , coalesce(u.active_users, 0) >= {{ var('active_org_min_users') }}
            or coalesce(r.active_source_runs, 0) >= {{ var('active_org_min_runs') }} as is_active
        , coalesce(r.active_source_runs, 0) as active_source_runs
        , coalesce(r.online_evaluation_runs, 0) as online_evaluation_runs
    from org_periods as s
    left join org_users as u using (period, period_start, organization_id)
    left join org_runs as r using (period, period_start, organization_id)
),

org_totals as (
    -- Organizations and runs add across regions; grouping sets give each region and the worldwide total.
    select
        period
        , period_start
        , coalesce(region, 'worldwide') as region
        , count(*) as customer_orgs
        , count(*) filter (where is_active) as active_orgs
        , sum(active_source_runs) as active_source_runs
        , sum(online_evaluation_runs) as online_evaluation_runs
    from org_activity
    group by grouping sets ((period, period_start, region), (period, period_start))
),

user_totals as (
    -- Distinct active users: a user is counted once per region and once worldwide, however many organizations they
    -- were active in. Users don't add across regions in general; in this data no user is active in two.
    select
        uo.period
        , uo.period_start
        , coalesce(o.region, 'worldwide') as region
        , count(distinct uo.user_id) as active_users
    from user_org_periods as uo
    inner join user_periods as up using (period, period_start, user_id)
    inner join orgs as o on o.organization_id = uo.organization_id
    where up.is_active_user
    group by grouping sets ((uo.period, uo.period_start, o.region), (uo.period, uo.period_start))
)

select
    p.period || ':' || strftime(p.period_start, '%Y-%m-%d') || ':' || t.region as wbr_row_id
    , p.period
    , p.period_start
    , p.period_end_date
    , p.is_complete
    , t.region
    , case t.region when 'worldwide' then 0 when 'us' then 1 when 'eu' then 2 when 'apac' then 3 end as region_order
    , case when p.is_complete then t.customer_orgs end as customer_orgs
    , case when p.is_complete then t.active_orgs end as active_orgs
    , case when p.is_complete then 100.0 * t.active_orgs / nullif(t.customer_orgs, 0) end as pct_active
    , case when p.is_complete then coalesce(u.active_users, 0) end as active_users
    , case when p.is_complete then 1.0 * coalesce(u.active_users, 0) / nullif(t.active_orgs, 0) end as users_per_active_org
    , case when p.is_complete then t.active_source_runs end as active_source_runs
    , case when p.is_complete then t.online_evaluation_runs end as online_evaluation_runs
from periods as p
inner join org_totals as t using (period, period_start)
left join user_totals as u using (period, period_start, region)
