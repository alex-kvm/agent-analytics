-- One row per organization with the flags the marts filter on. The internal list is hand-maintained and misses
-- organizations that internal staff created and are the only members of, so is_internal also derives them.
with orgs as (
    select * from {{ ref('stg_app__organizations') }}
),

users as (
    select * from {{ ref('stg_app__users') }}
),

members as (
    select
        w.current_organization_id as organization_id,
        count(distinct m.user_id) as members,
        count(distinct m.user_id) filter (where u.is_internal) as internal_members
    from {{ ref('stg_app__workspace_memberships') }} as m
    inner join {{ ref('stg_app__workspaces') }} as w on w.workspace_id = m.workspace_id
    inner join users as u on u.user_id = m.user_id
    group by 1
),

listed as (
    select organization_id from {{ ref('internal_organizations') }}
)

select
    o.*,
    coalesce(mb.members, 0) as members,
    coalesce(mb.internal_members, 0) as internal_members,
    o.organization_id in (select organization_id from listed) as is_internal_listed,
    coalesce(creator.is_internal, false)
        and coalesce(mb.members, 0) > 0
        and mb.internal_members = mb.members as is_internal_derived,
    o.organization_id in (select organization_id from listed)
        or coalesce(creator.is_internal and mb.members > 0 and mb.internal_members = mb.members, false) as is_internal
from orgs as o
left join members as mb on mb.organization_id = o.organization_id
left join users as creator on creator.user_id = o.created_by_user_id
