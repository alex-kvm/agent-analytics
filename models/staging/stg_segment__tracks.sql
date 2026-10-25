with unioned as (
    {{ union_regions('segment', 'tracks') }}
),

deduped as (
    {{ dedup_events('unioned', ', event_name') }}
)

select
    event_id,
    user_id,
    anonymous_id,
    event_name,
    received_at as event_at,
    "timestamp" as client_timestamp,
    context_page_path as page_path,
    nullif(regexp_extract(context_page_path, '^/o/([^/?#]+)', 1), '') as organization_id,
    nullif(regexp_extract(context_page_path, '^/o/[^/]+/w/([^/?#]+)', 1), '') as workspace_id,
    region
from deduped
