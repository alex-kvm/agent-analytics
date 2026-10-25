-- Grain: one row per day, customer organization and customer user with product activity, plus one row per day and
-- customer organization with an active-source run (user_id null). The same signals and filters as the facts, so with
-- the default thresholds of 1 a distinct count at any grain is the marts'
-- active organizations and active users at that grain.
with orgs as (
    select organization_id from {{ ref('int_organizations') }}
    where not is_internal{% if not var('include_personal_orgs') %} and not is_personal{% endif %}
),

user_days as (
    select e.event_date as activity_date, e.organization_id, e.user_id, 'user_activity' as signal
    from {{ ref('int_user_events') }} as e
    inner join {{ ref('stg_app__users') }} as u on u.user_id = e.user_id and not u.is_internal
    inner join orgs as o on o.organization_id = e.organization_id
    where e.is_activity and e.user_id is not null
      and e.event_at >= cast('{{ var("reporting_start") }}' as timestamp) and e.event_at < cast('{{ var("reporting_end") }}' as timestamp)
    group by all
),

run_days as (
    select r.run_date as activity_date, r.organization_id, cast(null as varchar) as user_id, 'active_run' as signal
    from {{ ref('int_runs') }} as r
    inner join orgs as o on o.organization_id = r.organization_id
    where r.counts_as_activity
      and r.started_at >= cast('{{ var("reporting_start") }}' as timestamp) and r.started_at < cast('{{ var("reporting_end") }}' as timestamp)
    group by all
)

select row_number() over (order by activity_date, organization_id, user_id) as activity_row_id, *
from (select * from user_days union all select * from run_days)
