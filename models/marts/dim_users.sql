with memberships as (
    select user_id, count(*) as workspace_memberships, count(distinct w.current_organization_id) as organizations
    from {{ ref('stg_app__workspace_memberships') }}
    inner join {{ ref('stg_app__workspaces') }} as w using (workspace_id)
    group by 1
)

select
    u.user_id,
    u.email_domain,
    u.is_internal,
    u.region,
    u.created_at,
    coalesce(m.workspace_memberships, 0) as workspace_memberships,
    coalesce(m.organizations, 0) as organizations
from {{ ref('stg_app__users') }} as u
left join memberships as m on m.user_id = u.user_id
