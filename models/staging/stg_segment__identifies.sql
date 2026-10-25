with unioned as (
    {{ union_regions('segment', 'identifies') }}
)

select event_id, user_id, anonymous_id, received_at as event_at, "timestamp" as client_timestamp, region
from unioned
qualify row_number() over (partition by event_id order by received_at) = 1
