-- What each modeling choice does to September 2026's headline. Run after dbt build:
--   duckdb -readonly analytics.duckdb < analyses/sensitivity.sql
-- Rebuilding with --vars changes the marts the same way, e.g. dbt build --vars '{active_user_min_days: 2}'.

-- A. The active-user threshold: distinct users active on at least N distinct days, across their organizations.
select n as min_active_days, count(distinct user_id) filter (where user_active_days >= n) as active_users_sep
from fct_user_activity_monthly, (values (1), (2), (4), (8)) as t(n)
where activity_month = date '2026-09-01'
group by 1
order by 1;

-- B. Counting sample-data runs as usage: organizations that would turn active in September.
select count(*) as orgs_active_only_by_sample_data_sep
from fct_org_activity_monthly
where activity_month = date '2026-09-01' and not is_active and sample_data_runs > 0;

-- C. Counting online-evaluator runs as activity: organizations that would turn active in September.
select count(*) as orgs_active_only_by_online_evaluators_sep
from fct_org_activity_monthly
where activity_month = date '2026-09-01' and not is_active and online_evaluation_runs > 0;

-- D. Not excluding internal staff: internal users' product events inside customer organizations, April to September.
select count(*) as internal_user_events_in_customer_orgs, count(distinct e.organization_id) as customer_orgs_touched
from int_user_events as e
inner join stg_app__users as u on u.user_id = e.user_id and u.is_internal
inner join dim_organizations as o on o.organization_id = e.organization_id and not o.is_internal
where e.is_activity and e.event_at >= timestamp '2026-04-01' and e.event_at < timestamp '2026-10-01';

-- E. The internal list alone: organizations the derived flag adds (part G gives the months they would count as active).
select display_name, plan, members, internal_members
from dim_organizations
where is_internal and not is_internal_listed
order by display_name;

-- F. Attributing runs through the workspace's current owner instead of the run's organization.
select count(*) as runs_moved, count(distinct r.workspace_id) as workspaces
from stg_app__runs as r
inner join stg_app__workspaces as w using (workspace_id)
where r.organization_id <> w.current_organization_id;

-- G. The four organizations only the derived internal flag catches: months they would count as active customers.
select strftime(cast(date_trunc('month', r.started_at) as date), '%Y-%m') as month, count(distinct r.organization_id) as would_be_active_orgs
from int_runs as r
inner join dim_organizations as o on o.organization_id = r.organization_id and o.is_internal and not o.is_internal_listed
where r.counts_as_activity and r.started_at >= timestamp '2026-04-01' and r.started_at < timestamp '2026-10-01'
group by 1
order by 1;

-- H. Attributing runs through the workspace's current owner: organization-months whose active flag would flip.
with by_current_owner as (
    select w.current_organization_id as organization_id, cast(date_trunc('month', r.started_at) as date) as activity_month,
           count(*) filter (where r.counts_as_activity) as active_runs
    from int_runs as r
    inner join stg_app__workspaces as w using (workspace_id)
    where r.started_at >= timestamp '2026-04-01' and r.started_at < timestamp '2026-10-01'
    group by 1, 2
)
select
    count(*) filter (where f.is_active and not (f.has_active_user or coalesce(c.active_runs, 0) >= 1)) as active_to_inactive,
    count(*) filter (where not f.is_active and coalesce(c.active_runs, 0) >= 1) as inactive_to_active
from fct_org_activity_monthly as f
left join by_current_owner as c using (organization_id, activity_month);

-- I. Page views removed by deduplication: repeated event_ids and double-fired views, by month of received_at.
with raw as (select received_at from read_parquet('data/segment_*/pages.parquet'))
select strftime(r.month, '%Y-%m') as month, r.raw_views, coalesce(s.kept_views, 0) as kept_views, r.raw_views - coalesce(s.kept_views, 0) as removed
from (select date_trunc('month', received_at) as month, count(*) as raw_views from raw group by 1) as r
left join (select date_trunc('month', event_at) as month, count(*) as kept_views from stg_segment__pages group by 1) as s using (month)
order by 1;

-- J. Active organizations by active users alone (without runs), September 2026.
select count(*) filter (where is_active) as active_orgs, count(*) filter (where has_active_user) as active_by_users_only
from fct_org_activity_monthly
where activity_month = date '2026-09-01';

-- K. The product-area mapping (D13): a dataset's compare page counts as experiments. Shares of September's active
-- organizations today, and if compare pages counted as datasets instead.
with active as (
    select organization_id from fct_org_activity_monthly where activity_month = date '2026-09-01' and is_active
),
signals as (
    select organization_id, signal_type, signal_value, product_area
    from int_user_events
    where is_activity and event_at >= timestamp '2026-09-01' and event_at < timestamp '2026-10-01'
    union all
    select organization_id, 'run', run_source, product_area
    from int_runs
    where counts_as_activity and started_at >= timestamp '2026-09-01' and started_at < timestamp '2026-10-01'
),
remapped as (
    select organization_id, product_area as area_today,
           case when signal_type = 'page' and signal_value = 'experiments' then 'datasets' else product_area end as area_alternative
    from signals
)
select
    (select count(*) from active) as active_orgs,
    round(100.0 * count(distinct organization_id) filter (where area_today = 'experiments') / (select count(*) from active), 1) as pct_experiments_today,
    round(100.0 * count(distinct organization_id) filter (where area_today = 'datasets') / (select count(*) from active), 1) as pct_datasets_today,
    round(100.0 * count(distinct organization_id) filter (where area_alternative = 'experiments') / (select count(*) from active), 1) as pct_experiments_alternative,
    round(100.0 * count(distinct organization_id) filter (where area_alternative = 'datasets') / (select count(*) from active), 1) as pct_datasets_alternative
from remapped
where organization_id in (select organization_id from active);

-- L. A track event's area if the page it fired on decided it (D10's alternative). The page's area follows the page
-- views' own mapping (D13), so playground_submit on a dataset's compare page would count as experiments. September
-- organizations by area, of the active organizations, today and if the page decided; and the submits that would move,
-- in September and in all months (after deduplication, and in the raw files).
with active as (
    select organization_id from fct_org_activity_monthly where activity_month = date '2026-09-01' and is_active
),
track_pages as (
    select
        t.event_id,
        coalesce(a.product_area, 'unmapped') as page_area,
        coalesce(a.is_activity, false) as page_is_activity
    from stg_segment__tracks as t
    left join product_areas as a
        on a.signal_type = 'page'
       and a.signal_value = case
            when t.page_path like '/login%' then 'login'
            when regexp_matches(t.page_path, '^/o/[^/]+/w/[^/]+/datasets/[^/]+/compare') then 'experiments'
            else coalesce(nullif(regexp_extract(t.page_path, '^/o/[^/]+/w/[^/]+/([^/?#]+)', 1), ''), 'workspace_home')
        end
),
signals as (
    select
        e.organization_id,
        e.product_area as area_today,
        e.is_activity as counts_today,
        coalesce(p.page_area, e.product_area) as area_page_decides,
        coalesce(p.page_is_activity, e.is_activity) as counts_page_decides,
        e.signal_value = 'playground_submit' and p.page_area = 'experiments' as submit_on_compare
    from int_user_events as e
    left join track_pages as p using (event_id)
    where e.event_at >= timestamp '2026-09-01' and e.event_at < timestamp '2026-10-01'
    union all
    select organization_id, product_area, true, product_area, true, false
    from int_runs
    where counts_as_activity and started_at >= timestamp '2026-09-01' and started_at < timestamp '2026-10-01'
)
select
    (select count(*) from active) as active_orgs,
    count(distinct organization_id) filter (where counts_today and area_today = 'playground') as playground_today,
    count(distinct organization_id) filter (where counts_page_decides and area_page_decides = 'playground') as playground_page_decides,
    count(distinct organization_id) filter (where counts_today and area_today = 'experiments') as experiments_today,
    count(distinct organization_id) filter (where counts_page_decides and area_page_decides = 'experiments') as experiments_page_decides,
    count(*) filter (where submit_on_compare) as september_submits_moved,
    (select count(*) from stg_segment__tracks
     where event_name = 'playground_submit' and regexp_matches(page_path, '^/o/[^/]+/w/[^/]+/datasets/[^/]+/compare')) as submits_moved,
    (select count(*) from read_parquet('data/segment_*/tracks.parquet')
     where event_name = 'playground_submit' and regexp_matches(context_page_path, '^/o/[^/]+/w/[^/]+/datasets/[^/]+/compare')) as submits_moved_raw
from signals
where organization_id in (select organization_id from active);
