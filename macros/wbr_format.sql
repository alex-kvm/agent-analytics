{# Cell formats for the weekly business review table (the golden example's rules): counts with thousands separators,
   rates as % to one decimal, ratios to two decimals, runs in thousands to one decimal. Changes are % for counts,
   ratios and amounts, and basis points for rates; negatives in parentheses. A null value stays blank. #}
{% macro wbr_value(v, kind) -%}
    case {{ kind }}
        when 'count' then format('{:,}', cast({{ v }} as bigint))
        when 'rate' then format('{:.1f}%', {{ v }})
        when 'ratio' then format('{:.2f}', {{ v }})
        when 'thousands' then format('{:,.1f}', {{ v }} / 1000.0)
    end
{%- endmacro %}

{# x is rounded to what the format shows before its sign is read, so a change that rounds to zero isn't negative. #}
{% macro wbr_signed(x, fmt, places) -%}
    case when round({{ x }}, {{ places }}) < 0 then '(' || format('{{ fmt }}', -round({{ x }}, {{ places }})) || ')'
         else format('{{ fmt }}', abs(round({{ x }}, {{ places }}))) end
{%- endmacro %}

{% macro wbr_change(cur, prev, kind) -%}
    case
        when {{ cur }} is null or {{ prev }} is null then null
        when {{ kind }} = 'rate' then {{ wbr_signed('100 * (' ~ cur ~ ' - ' ~ prev ~ ')', '{:,.0f} bps', 0) }}
        when {{ prev }} = 0 then null
        else {{ wbr_signed('100.0 * (' ~ cur ~ ' - ' ~ prev ~ ') / ' ~ prev, '{:.1f}%', 1) }}
    end
{%- endmacro %}
