-- Grain: one row per customer organization and period of var('activity_grain') (a calendar month, UTC, by default),
-- from the period it was created to the last complete one, including periods with no activity, so inactive
-- organizations stay in the denominator. An organization is active in a period when it has at least
-- var('active_org_min_users') active users, or at least var('active_org_min_runs') customer-driven runs
-- (var('active_run_sources')). activity_month holds the period's first day at any grain.
with months as (
    select cast(range as date) as activity_month
    from range({{ activity_period("date '" ~ var('reporting_start') ~ "'") }}, cast('{{ var("reporting_end") }}' as date), {{ activity_interval() }})
),

orgs as (
    select * from {{ ref('int_organizations') }}
    where not is_internal{% if not var('include_personal_orgs') %} and not is_personal{% endif %}
),

spine as (
    select o.organization_id, m.activity_month
    from orgs as o
    inner join months as m on o.created_at < m.activity_month + {{ activity_interval() }}
),

users as (
    select
        organization_id,
        activity_month,
        count(*) filter (where is_active) as active_users,
        sum(tracing_events) as tracing_events,
        sum(playground_events) as playground_events,
        sum(studio_events) as studio_events,
        sum(datasets_events) as datasets_events,
        sum(experiments_events) as experiments_events
    from {{ ref('fct_user_activity_monthly') }}
    group by 1, 2
),

runs as (
    select
        organization_id,
        {{ activity_period('started_at') }} as activity_month,
        count(*) filter (where counts_as_activity) as active_runs,
        count(distinct trace_id) filter (where counts_as_activity) as active_traces,
        count(*) filter (where product_area = 'tracing') as tracing_runs,
        count(*) filter (where product_area = 'playground') as playground_runs,
        count(*) filter (where product_area = 'studio') as studio_runs,
        count(*) filter (where product_area = 'experiments') as experiments_runs,
        count(*) filter (where product_area = 'online_evaluation') as online_evaluation_runs,
        count(*) filter (where product_area = 'sample_data') as sample_data_runs,
        count(*) filter (where counts_as_activity and status = 'error') as active_error_runs,
        coalesce(sum(total_tokens) filter (where counts_as_activity), 0) as active_tokens
    from {{ ref('int_runs') }}
    where started_at >= cast('{{ var("reporting_start") }}' as timestamp)
      and started_at < cast('{{ var("reporting_end") }}' as timestamp)
    group by 1, 2
),

joined as (
    select
        s.organization_id,
        s.activity_month,
        coalesce(u.active_users, 0) as active_users,
        coalesce(u.tracing_events, 0) as tracing_events,
        coalesce(u.playground_events, 0) as playground_events,
        coalesce(u.studio_events, 0) as studio_events,
        coalesce(u.datasets_events, 0) as datasets_events,
        coalesce(u.experiments_events, 0) as experiments_events,
        coalesce(r.active_runs, 0) as active_runs,
        coalesce(r.active_traces, 0) as active_traces,
        coalesce(r.tracing_runs, 0) as tracing_runs,
        coalesce(r.playground_runs, 0) as playground_runs,
        coalesce(r.studio_runs, 0) as studio_runs,
        coalesce(r.experiments_runs, 0) as experiments_runs,
        coalesce(r.online_evaluation_runs, 0) as online_evaluation_runs,
        coalesce(r.sample_data_runs, 0) as sample_data_runs,
        coalesce(r.active_error_runs, 0) as active_error_runs,
        coalesce(r.active_tokens, 0) as active_tokens
    from spine as s
    left join users as u on u.organization_id = s.organization_id and u.activity_month = s.activity_month
    left join runs as r on r.organization_id = s.organization_id and r.activity_month = s.activity_month
)

select
    {{ dbt_utils.generate_surrogate_key(['j.organization_id', 'j.activity_month']) }} as org_month_id,
    j.*,
    j.active_users >= {{ var('active_org_min_users') }} as has_active_user,
    j.active_runs >= {{ var('active_org_min_runs') }} as has_active_runs,
    j.active_users >= {{ var('active_org_min_users') }} or j.active_runs >= {{ var('active_org_min_runs') }} as is_active,
    case
        when j.active_users >= {{ var('active_org_min_users') }} and j.active_runs >= {{ var('active_org_min_runs') }} then 'ui_and_runs'
        when j.active_users >= {{ var('active_org_min_users') }} then 'ui_only'
        when j.active_runs >= {{ var('active_org_min_runs') }} then 'runs_only'
        else 'inactive'
    end as activity_type,
    concat_ws(', ',
        case when j.tracing_events > 0 or j.tracing_runs > 0 then 'tracing' end,
        case when j.playground_events > 0 or j.playground_runs > 0 then 'playground' end,
        case when j.studio_events > 0 or j.studio_runs > 0 then 'studio' end,
        case when j.datasets_events > 0 then 'datasets' end,
        case when j.experiments_events > 0 or j.experiments_runs > 0 then 'experiments' end,
        case when j.online_evaluation_runs > 0 then 'online_evaluation' end
    ) as product_areas,
    o.plan,
    o.is_personal,
    o.region
from joined as j
inner join orgs as o on o.organization_id = j.organization_id
