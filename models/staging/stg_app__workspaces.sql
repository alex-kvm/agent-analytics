with unioned as (
    {{ union_regions('app', 'workspaces') }}
)

select
    workspace_id,
    organization_id as current_organization_id,
    workspace_name,
    created_at,
    updated_at,
    region
from unioned
