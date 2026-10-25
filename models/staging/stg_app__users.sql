with unioned as (
    {{ union_regions('app', 'users') }}
)

select
    user_id,
    lower(trim(email)) as email,
    split_part(lower(trim(email)), '@', 2) as email_domain,
    split_part(lower(trim(email)), '@', 2) = '{{ var("internal_email_domain") }}' as is_internal,
    created_at,
    region
from unioned
