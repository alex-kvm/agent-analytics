-- Every page area, track event and run source maps to a product area in the seed.
select 'event' as kind, product_area from {{ ref('int_user_events') }} where product_area = 'unmapped'
union all
select 'run', product_area from {{ ref('int_runs') }} where product_area = 'unmapped'
