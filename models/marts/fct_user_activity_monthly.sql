-- Grain: one row per customer user, customer organization and period of var('activity_grain') (a calendar month, UTC,
-- by default) in which the user did anything in a product area. Internal users and internal organizations are left
-- out. Two flags apply the definition, product activity on at least var('active_user_min_days') distinct days:
--   is_active       counts the days in this organization (an active user of the organization)
--   is_active_user  counts the days across all the user's customer organizations (an active user of the platform)
-- Count platform-wide active users as count(distinct user_id) filter (where is_active_user); a user active in two
-- organizations has two rows.
with events as (
    select *
    from {{ ref('int_user_events') }}
    where is_activity
      and user_id is not null
      and event_at >= cast('{{ var("reporting_start") }}' as timestamp)
      and event_at < cast('{{ var("reporting_end") }}' as timestamp)
),

customer_events as (
    select e.*, {{ activity_period('e.event_at') }} as activity_month
    from events as e
    inner join {{ ref('stg_app__users') }} as u on u.user_id = e.user_id and not u.is_internal
    inner join {{ ref('int_organizations') }} as o on o.organization_id = e.organization_id and not o.is_internal
        {%- if not var('include_personal_orgs') %} and not o.is_personal{% endif %}
),

user_days as (
    select user_id, activity_month, count(distinct event_date) as user_active_days
    from customer_events
    group by 1, 2
),

user_orgs as (
    select
        {{ dbt_utils.generate_surrogate_key(['user_id', 'organization_id', 'activity_month']) }} as user_org_month_id,
        activity_month,
        user_id,
        organization_id,
        count(distinct event_date) as active_days,
        count(*) as product_events,
        count(*) filter (where product_area = 'tracing') as tracing_events,
        count(*) filter (where product_area = 'playground') as playground_events,
        count(*) filter (where product_area = 'studio') as studio_events,
        count(*) filter (where product_area = 'datasets') as datasets_events,
        count(*) filter (where product_area = 'experiments') as experiments_events,
        string_agg(distinct product_area, ', ' order by product_area) as product_areas,
        count(distinct event_date) >= {{ var('active_user_min_days') }} as is_active
    from customer_events
    group by all
)

select
    o.*,
    d.user_active_days,
    d.user_active_days >= {{ var('active_user_min_days') }} as is_active_user
from user_orgs as o
inner join user_days as d using (user_id, activity_month)
