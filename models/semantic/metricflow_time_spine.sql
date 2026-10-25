-- One row per day; MetricFlow rolls days up to weeks, months and quarters from it.
select cast(range as date) as date_day
from range(date '2026-01-01', date '2027-01-01', interval 1 day)
