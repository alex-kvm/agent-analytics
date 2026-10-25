-- Runs with their product area. The organization is the one on the run, the workspace's owner when it ran.
-- counts_as_activity follows var('active_run_sources'): customer-driven sources only, so onboarding sample data
-- and automated online evaluators never make an organization active by themselves.
with areas as (
    select * from {{ ref('product_areas') }} where signal_type = 'run'
)

select
    r.*,
    cast(r.started_at as date) as run_date,
    coalesce(a.product_area, 'unmapped') as product_area,
    r.run_source in (
        {%- for s in var('active_run_sources') %}'{{ s }}'{{ ", " if not loop.last }}{% endfor -%}
    ) as counts_as_activity
from {{ ref('stg_app__runs') }} as r
left join areas as a on a.signal_value = r.run_source
