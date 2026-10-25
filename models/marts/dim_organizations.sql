with orgs as (
    select * from {{ ref('int_organizations') }}
),

workspaces as (
    select current_organization_id as organization_id, count(*) as workspaces
    from {{ ref('stg_app__workspaces') }}
    group by 1
)

select
    o.organization_id,
    o.display_name,
    o.plan,
    o.is_personal,
    o.is_personal_derived,
    o.is_internal,
    o.is_internal_listed,
    o.is_internal_derived,
    o.region,
    o.created_at,
    o.created_by_user_id,
    coalesce(w.workspaces, 0) as workspaces,
    o.members,
    o.internal_members
from orgs as o
left join workspaces as w on w.organization_id = o.organization_id
