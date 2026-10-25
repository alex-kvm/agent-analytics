-- Page views and track calls as one stream of user events, each tagged with the product area it belongs to.
-- The organization comes from the page path (/o/<org>/w/<workspace>/...), so it is the owner at the time of the
-- event, not the workspace's current owner. A track event's name decides its area over the page it fired on
-- (playground_submit also fires on dataset pages, when a dataset row is opened in the playground).
with areas as (
    select * from {{ ref('product_areas') }}
),

pages as (
    select
        event_id, user_id, anonymous_id, event_at, organization_id, workspace_id, region,
        'page' as signal_type,
        page_area as signal_value
    from {{ ref('stg_segment__pages') }}
),

tracks as (
    select
        event_id, user_id, anonymous_id, event_at, organization_id, workspace_id, region,
        'track' as signal_type,
        event_name as signal_value
    from {{ ref('stg_segment__tracks') }}
),

events as (
    select * from pages
    union all
    select * from tracks
)

select
    e.*,
    cast(e.event_at as date) as event_date,
    coalesce(a.product_area, 'unmapped') as product_area,
    coalesce(a.is_activity, false) as is_activity
from events as e
left join areas as a
    on a.signal_type = e.signal_type
   and a.signal_value = e.signal_value
