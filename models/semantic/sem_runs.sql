-- Grain: one row per run in a customer organization, April to September 2026, with its product area. The same
-- customer-organization filter as sem_activity_daily and the facts, so var('include_personal_orgs') reaches the runs metric.
select r.run_id, r.run_date, r.organization_id, r.product_area, r.counts_as_activity
from {{ ref('int_runs') }} as r
inner join {{ ref('int_organizations') }} as o
    on o.organization_id = r.organization_id and not o.is_internal{% if not var('include_personal_orgs') %} and not o.is_personal{% endif %}
where r.started_at >= cast('{{ var("reporting_start") }}' as timestamp) and r.started_at < cast('{{ var("reporting_end") }}' as timestamp)
