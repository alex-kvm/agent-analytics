with unioned as (
    {{ union_regions('app', 'workspace_memberships') }}
)

select membership_id, workspace_id, user_id, role, created_at, region
from unioned
