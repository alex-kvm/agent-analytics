-- Weekly business review, the report: the golden example's layout over rpt_weekly_business_review, so every cell is
-- computed from the data tab and a refresh is a rebuild.
-- Rows: a period-ending row, then one block per region (worldwide first, then us, eu, apac), each with the same
-- numbered metrics. Columns: the four latest complete weeks and week-over-week change, then the four latest complete
-- months and month-over-month change. Footnotes, keyed by the metric number, are in WRITEUP.md and the board's notes.

with metrics as (
    -- The metric list: number, label with its unit, and the kind that sets its format and its change.
    select *
    from (values
        (1, 'Customer organizations', 'count', 'customer_orgs')
        , (2, 'Active organizations', 'count', 'active_orgs')
        , (3, 'Active share, %', 'rate', 'pct_active')
        , (4, 'Distinct active users', 'count', 'active_users')
        , (5, 'Active users per active organization', 'ratio', 'users_per_active_org')
        , (6, 'Active-source runs, 000s', 'thousands', 'active_source_runs')
        , (7, 'Online-evaluation runs', 'count', 'online_evaluation_runs')
    ) as t(metric_no, metric, kind, metric_key)
),

latest as (
    -- The trailing four complete weeks and months; slot 4 is the latest.
    select *, 5 - row_number() over (partition by period, region order by period_start desc) as slot
    from {{ ref('rpt_weekly_business_review') }}
    where is_complete and period in ('week', 'month')
    qualify slot >= 1
),

long as (
    unpivot (
        select period, slot, period_end_date, region, region_order
            , cast(customer_orgs as double) as customer_orgs
            , cast(active_orgs as double) as active_orgs
            , pct_active
            , cast(active_users as double) as active_users
            , users_per_active_org
            , cast(active_source_runs as double) as active_source_runs
            , cast(online_evaluation_runs as double) as online_evaluation_runs
        from latest
    )
    on customer_orgs, active_orgs, pct_active, active_users, users_per_active_org, active_source_runs, online_evaluation_runs
    into name metric_key value v
),

wide as (
    select
        l.region
        , any_value(l.region_order) as region_order
        , m.metric_no
        , m.metric
        , m.kind
        {%- for s in [1, 2, 3, 4] %}
        , max(l.v) filter (where l.period = 'week' and l.slot = {{ s }}) as wk_{{ s }}
        {%- endfor %}
        {%- for s in [1, 2, 3, 4] %}
        , max(l.v) filter (where l.period = 'month' and l.slot = {{ s }}) as mo_{{ s }}
        {%- endfor %}
    from long as l
    inner join metrics as m using (metric_key)
    group by l.region, m.metric_no, m.metric, m.kind
),

ending as (
    -- The column headings' dates: the last day of each week, the month of each month.
    select
        {%- for s in [1, 2, 3, 4] %}
        {{ ', ' if not loop.first }}max(strftime(period_end_date, '%-d %b')) filter (where period = 'week' and slot = {{ s }}) as wk_{{ s }}
        {%- endfor %}
        {%- for s in [1, 2, 3, 4] %}
        , max(strftime(period_end_date, '%b %Y')) filter (where period = 'month' and slot = {{ s }}) as mo_{{ s }}
        {%- endfor %}
    from latest
    where region = 'worldwide'
)

select 0 as sort_key, '' as "#", 'Period ending (UTC)' as "Metric"
    , wk_1 as "Wk 1", wk_2 as "Wk 2", wk_3 as "Wk 3", wk_4 as "Wk 4", 'WoW' as "WoW"
    , mo_1 as "Mo 1", mo_2 as "Mo 2", mo_3 as "Mo 3", mo_4 as "Mo 4", 'MoM' as "MoM"
from ending

union all

select distinct 100 * (region_order + 1) as sort_key, '', case region when 'worldwide' then 'Worldwide' else upper(region) end
    , '', '', '', '', '', '', '', '', '', ''
from wide

union all

select
    100 * (region_order + 1) + metric_no
    , cast(metric_no as varchar)
    , metric
    {%- for s in [1, 2, 3, 4] %}
    , coalesce({{ wbr_value('wk_' ~ s, 'kind') }}, '')
    {%- endfor %}
    , coalesce({{ wbr_change('wk_4', 'wk_3', 'kind') }}, '')
    {%- for s in [1, 2, 3, 4] %}
    , coalesce({{ wbr_value('mo_' ~ s, 'kind') }}, '')
    {%- endfor %}
    , coalesce({{ wbr_change('mo_4', 'mo_3', 'kind') }}, '')
from wide
