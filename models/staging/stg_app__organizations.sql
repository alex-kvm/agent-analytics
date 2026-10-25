with unioned as (
    {{ union_regions('app', 'organizations') }}
)

select
    organization_id,
    display_name,
    plan,
    -- apac's export has no is_personal column; personal organizations there are the ones named 'Personal',
    -- which is how is_personal reads in the regions that have it.
    coalesce(is_personal, display_name = 'Personal') as is_personal,
    is_personal is null as is_personal_derived,
    created_by_user_id,
    created_at,
    region
from unioned
