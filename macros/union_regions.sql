{#- Union one table across the regional sources (app_us, app_eu, app_apac, ...) by column name, with a region
    column. By name, because the regions' schemas drift: apac's organizations have no is_personal column. -#}
{% macro union_regions(source_prefix, table_name) -%}
    {%- for region in var('regions') %}
    select *, '{{ region }}' as region
    from {{ source(source_prefix ~ '_' ~ region, table_name) }}
    {%- if not loop.last %}
    union all by name
    {%- endif %}
    {%- endfor %}
{%- endmacro %}
