{# The reporting period. var('activity_grain') (month by default) is the one place the window is set: both facts and
   the organization spine use these macros, so a weekly view is one edit in dbt_project.yml. #}
{% macro activity_period(ts) -%}
    cast(date_trunc('{{ var("activity_grain") }}', {{ ts }}) as date)
{%- endmacro %}

{% macro activity_interval() -%}
    interval 1 {{ var("activity_grain") }}
{%- endmacro %}
