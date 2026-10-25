-- Customer facts must not contain internal organizations.
select f.organization_id
from {{ ref('fct_org_activity_monthly') }} as f
inner join {{ ref('dim_organizations') }} as d using (organization_id)
where d.is_internal
union all
select f.organization_id
from {{ ref('fct_user_activity_monthly') }} as f
inner join {{ ref('dim_organizations') }} as d using (organization_id)
where d.is_internal
