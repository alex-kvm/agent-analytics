with unioned as (
    {{ union_regions('segment', 'pages') }}
),

deduped as (
    {{ dedup_events('unioned') }}
)

select
    event_id,
    user_id,
    anonymous_id,
    -- Client timestamps run from 1970 to 2034 (bad device clocks); received_at is the server's clock.
    received_at as event_at,
    "timestamp" as client_timestamp,
    context_page_path as page_path,
    nullif(regexp_extract(context_page_path, '^/o/([^/?#]+)', 1), '') as organization_id,
    nullif(regexp_extract(context_page_path, '^/o/[^/]+/w/([^/?#]+)', 1), '') as workspace_id,
    case
        when context_page_path like '/login%' then 'login'
        when regexp_matches(context_page_path, '^/o/[^/]+/w/[^/]+/datasets/[^/]+/compare') then 'experiments'
        else coalesce(nullif(regexp_extract(context_page_path, '^/o/[^/]+/w/[^/]+/([^/?#]+)', 1), ''), 'workspace_home')
    end as page_area,
    region
from deduped
