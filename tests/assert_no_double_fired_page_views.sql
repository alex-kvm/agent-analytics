-- No two page views from one sender on one path within the double-fire window survive staging.
with ordered as (
    select
        client_timestamp,
        lag(client_timestamp) over (
            partition by coalesce(user_id, anonymous_id), page_path order by client_timestamp, event_at, event_id
        ) as previous_client_timestamp
    from {{ ref('stg_segment__pages') }}
)
select *
from ordered
where date_diff('millisecond', previous_client_timestamp, client_timestamp) < {{ var('double_fire_window_ms') }}
