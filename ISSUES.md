# Issues in the data

Ranked by how much each one would change the answer to the product team (who is active, which product areas they use, and the segments). Issues 1 to 7 would change it if handled the other way; issues 8 to 11 change only traffic and event counts, never who is active; 12 lists smaller ones. Each issue has:

- why it matters
- a query that shows it in the raw files (run it from this folder with `duckdb < query`)
- what I did, and why.

Where I fixed an issue, a second query against the built models (`duckdb -readonly analytics.duckdb`, after `uv run dbt build`) shows the fix holds.

## 1. Workspaces change owner, and the workspace table only knows the current one

- **Why it matters:** usage can't be attributed through `workspaces.organization_id`. It is the current owner, and 15 workspaces changed hands mid-period. Attributing through it moves 2,823 runs, and the page views that name the workspace, to the new owner. It also flips 4 organization-months from active to inactive.
- **Fixed:** runs carry the organization that owned the workspace when they ran, and page paths name the organization at view time (`/o/<org>/w/<workspace>/...`). The models attribute through those, so no ownership history is needed.

```sql
select count(*) as runs, count(distinct r.workspace_id) as workspaces
from read_parquet('data/app_*/runs.parquet') r
join read_parquet('data/app_*/workspaces.parquet') w using (workspace_id)
where r.organization_id <> w.organization_id;
```

No run is missing its workspace, so none is dropped or attributed by a fallback:

```sql
select count(*) as runs_without_workspace
from read_parquet('data/app_*/runs.parquet')
where workspace_id is null or workspace_id not in (select workspace_id from read_parquet('data/app_*/workspaces.parquet'));
```

Check (built): `fct_org_activity_monthly` takes runs from `int_runs.organization_id`, not the workspace; `analyses/sensitivity.sql` part H counts the flips the other way.

## 2. The internal-organization list is incomplete

- **Why it matters:** 4 organizations that aren't on the hand-maintained list were created by internal staff and have only internal members. One of them is on the enterprise plan, with 30 members, all internal, and sample-data runs (the query's `members`, `internal_members` and `sample_data_runs`), which looks like a demo organization. Counted as customers, 1 or 2 of them are active in every month (`analyses/sensitivity.sql` part G).
- **Fixed:** `int_organizations.is_internal` is the list *or* an organization created by an internal user whose members are all internal. Both flags stay on `dim_organizations`, so the list's owners can see which ones to add.

```sql
with u as (select * from read_parquet('data/app_*/users.parquet')),
m as (select w.organization_id, bool_and(u.email like '%@internal.example') as all_internal,
             count(distinct wm.user_id) as members,
             count(distinct wm.user_id) filter (where u.email like '%@internal.example') as internal_members
      from read_parquet('data/app_*/workspace_memberships.parquet') wm
      join read_parquet('data/app_*/workspaces.parquet') w using (workspace_id)
      join u using (user_id) group by 1),
s as (select organization_id, count(*) as sample_data_runs
      from read_parquet('data/app_*/runs.parquet') where run_source = 'sample_data' group by 1)
select o.display_name, o.plan, m.members, m.internal_members, coalesce(s.sample_data_runs, 0) as sample_data_runs
from read_parquet('data/app_*/organizations.parquet', union_by_name = true) o
join m using (organization_id)
left join s using (organization_id)
join u on u.user_id = o.created_by_user_id
where m.all_internal and u.email like '%@internal.example'
  and o.organization_id not in (select organization_id from read_csv('seeds/internal_organizations.csv'));
```

Check (built): `select count(*) from fct_org_activity_monthly join dim_organizations d using (organization_id) where d.is_internal;` returns 0. The singular test `assert_no_internal_organizations_in_facts` enforces it.

## 3. Sample-data runs look like usage

- **Why it matters:** `run_source = 'sample_data'` marks runs on the product's sample data, not a customer's own work: 10,900 runs across 78 organizations. 2 organizations have no other runs at all (the query's `orgs_with_only_sample_data`). Counted as usage, these runs would make 2 other organizations active in September: both were active in earlier months (one in June and July, one from April to August) and had no other activity in September.
- **Fixed:** only runs from `var('active_run_sources')` (sdk, experiment, playground, studio) count as activity. Sample-data runs are kept in `fct_org_activity_monthly.sample_data_runs` for visibility.

```sql
select count(*) as runs, count(distinct organization_id) as orgs,
       (select count(*) from (select organization_id from read_parquet('data/app_*/runs.parquet')
                              group by 1 having bool_and(run_source = 'sample_data'))) as orgs_with_only_sample_data
from read_parquet('data/app_*/runs.parquet') where run_source = 'sample_data';
```

Check (built): `analyses/sensitivity.sql` part B gives 2 organizations that would turn active in September. The query below lists their active months; neither is one of the 2 with only sample-data runs:

```sql
with t as (select distinct f.organization_id from fct_org_activity_monthly f join int_runs r using (organization_id)
           where f.activity_month = date '2026-09-01' and not f.is_active and r.run_source = 'sample_data'
             and r.started_at >= timestamp '2026-09-01' and r.started_at < timestamp '2026-10-01')
select string_agg(strftime(f.activity_month, '%Y-%m'), ', ' order by f.activity_month) as active_months,
       t.organization_id in (select organization_id from int_runs group by 1 having bool_and(run_source = 'sample_data')) as only_sample_data_runs
from t join fct_org_activity_monthly f using (organization_id)
where f.is_active
group by t.organization_id order by 1;
```

## 4. Client timestamps are unreliable

- **Why it matters:** `timestamp` comes from the user's device. Pages run from 1970 to 2034: 87 page views are dated before 2020, 213 are more than an hour ahead of `received_at`, and 597 are more than a day behind it. Months built on `timestamp` would put activity in the wrong month, or in no month at all.
- **Fixed:** `event_at` is `received_at`, the server's clock. The client timestamp is kept as `client_timestamp`, used only for the double-fire gap, where a constant clock offset cancels out.

```sql
select count(*) filter (where "timestamp" < '2020-01-01') as before_2020,
       count(*) filter (where "timestamp" > received_at + interval 1 hour) as ahead_of_server,
       count(*) filter (where "timestamp" < received_at - interval 1 day) as day_behind_server,
       min("timestamp"), max("timestamp")
from read_parquet('data/segment_*/pages.parquet');
```

## 5. The regions' schemas differ: apac's organizations have no is_personal

- **Why it matters:** a positional union fails or misaligns columns. A by-name union leaves `is_personal` null for all 68 apac organizations, so 17 personal organizations would count as companies.
- **Fixed:** the `union_regions` macro unions by name. `is_personal` falls back to `display_name = 'Personal'`, which matches the flag exactly in the two regions that have it: all 94 flagged organizations are named Personal, and no other organization is. `is_personal_derived` marks the 68 apac rows whose flag is derived, 17 of them personal.

```sql
select regexp_extract(filename, 'app_(\w+)/', 1) as region, count(*) as orgs,
       count(*) filter (where display_name = 'Personal') as named_personal,
       count(*) filter (where is_personal) as flagged_personal,
       count(*) filter (where (display_name = 'Personal') <> is_personal) as name_and_flag_differ
from read_parquet('data/app_*/organizations.parquet', filename = true, union_by_name = true)
group by 1 order by 1;
```

Check (built):

```sql
select region, count(*) as orgs, count(*) filter (where is_personal) as personal,
       count(*) filter (where is_personal_derived) as derived, count(*) filter (where is_personal_derived and is_personal) as derived_personal
from stg_app__organizations group by 1 order by 1;
```

## 6. Online-evaluator runs are automated

- **Why it matters:** 6,747 runs come from evaluators that run on a customer's traces with no person involved. Counted as activity, they could keep an organization "active" with no one using the product.
- **Handled:** they count toward the online-evaluation product area but don't make an organization active on their own. In September no organization depends on them: `analyses/sensitivity.sql` part C gives 0.

```sql
select count(*) as runs, count(distinct organization_id) as orgs
from read_parquet('data/app_*/runs.parquet') where run_source = 'online_evaluator';
```

## 7. October is a partial month

- **Why it matters:** events run to 3 October, but runs stop on 30 September. A monthly series would show October collapsing.
- **Handled:** `var('reporting_start')` and `var('reporting_end')` limit the facts to April to September 2026.

```sql
select max(received_at) as last_event, (select max(started_at) from read_parquet('data/app_*/runs.parquet')) as last_run
from read_parquet('data/segment_*/pages.parquet');
```

## 8. Page views were double-fired in July and August

- **Why it matters:** in July and August, page views arrived twice: a second copy from the same user on the same path, with a new `event_id`, under 100 ms after the first by the client clock. The query below buckets the gap between same-path repeats among identified users: 9,205 in July and 1,471 in August are under 100 ms apart, 9,125 and 1,402 of them with a new `event_id`. The other months have 47 to 116 (October's three days have none), and none of those has a new `event_id`: they are repeated `event_id`s (#10). None falls between 100 ms and 1 s, and only 39 in all fall between 1 and 5 s, against 72,517 that are 5 s or more apart, which is how real repeat views look. Counting every copy removed, including repeated `event_id`s (#10) and anonymous views, deduplication removes 9,870 views in July and 1,650 in August: `analyses/sensitivity.sql` part I, after the build. Left in, they would read as a jump in engagement and skew any by-volume area share.
- **Fixed:** the `dedup_events` macro drops a repeat from the same sender on the same path within `var('double_fire_window_ms')` (1,000 ms).

```sql
with x as (select *, lag("timestamp") over w as prev, lag(event_id) over w as prev_event_id
           from read_parquet('data/segment_*/pages.parquet') where user_id is not null
           window w as (partition by user_id, context_page_path order by "timestamp", event_id)),
g as (select strftime(received_at, '%Y-%m') as month, date_diff('millisecond', prev, "timestamp") as gap_ms, event_id <> prev_event_id as new_event_id
      from x where prev is not null)
select coalesce(month, 'all') as month,
       count(*) filter (where gap_ms < 100) as under_100ms,
       count(*) filter (where gap_ms < 100 and new_event_id) as under_100ms_new_event_id,
       count(*) filter (where gap_ms >= 100 and gap_ms < 1000) as from_100ms_to_1s,
       count(*) filter (where gap_ms >= 1000 and gap_ms < 5000) as from_1s_to_5s,
       count(*) filter (where gap_ms >= 5000) as five_s_or_more
from g
group by rollup (month) order by month nulls last;
```

Check (built): the singular test `assert_no_double_fired_page_views` returns no rows. `analyses/sensitivity.sql` part I shows what was removed each month.

## 9. Synthetic traffic on the login page, 10 August to 1 September

- **Why it matters:** 5 anonymous clients load `/login` for three weeks, a median of 8.3 to 10.1 minutes apart each, 11,971 views in all (the first query's five rows; the second query's `from_the_five` for all months), and are never identified. They're why August's login views are 6.8 times July's (`times_previous_month`): 13,554 against 1,984 in the raw files, 11,967 of August's from these five (the second query). It looks like uptime monitors. A traffic or sessions metric would be badly inflated.
- **Left, flagged:** these clients have no user, and login isn't product activity, so they can't change who is active. Engineering should filter monitors at the source (user agent or IP), which these exports don't carry.

```sql
with v as (
    select anonymous_id, received_at,
           epoch(received_at - lag(received_at) over (partition by anonymous_id order by received_at)) / 60.0 as gap_min
    from read_parquet('data/segment_*/pages.parquet')
    where context_page_path like '/login%'
)
select anonymous_id, count(*) as login_views, min(received_at) as first_view, max(received_at) as last_view,
       round(median(gap_min), 1) as median_gap_min,
       bool_or(anonymous_id in (select anonymous_id from read_parquet('data/segment_*/identifies.parquet'))) as ever_identified
from v
group by 1 having count(*) > 100 order by 2 desc;
```

```sql
with monitors as (
    select anonymous_id from read_parquet('data/segment_*/pages.parquet')
    where context_page_path like '/login%' group by 1 having count(*) > 100
)
, m as (
    select strftime(received_at, '%Y-%m') as month, count(*) as login_views,
           count(*) filter (where anonymous_id in (select anonymous_id from monitors)) as from_the_five
    from read_parquet('data/segment_*/pages.parquet')
    where context_page_path like '/login%'
    group by rollup (1)
)
select coalesce(month, 'all') as month, login_views, from_the_five,
       case when month is not null then round(login_views / lag(login_views) over (order by month), 1) end as times_previous_month
from m order by month nulls last;
```

## 10. Repeated event_ids

- **Why it matters:** these are the same event delivered twice (Segment retries): 512 page views, 116 track calls and 73 identifies. They would inflate counts.
- **Fixed:** staging keeps the first row per `event_id`; `unique` tests on every `event_id`.

```sql
select 'pages' as t, count(*) - count(distinct event_id) as repeats from read_parquet('data/segment_*/pages.parquet')
union all select 'tracks', count(*) - count(distinct event_id) from read_parquet('data/segment_*/tracks.parquet')
union all select 'identifies', count(*) - count(distinct event_id) from read_parquet('data/segment_*/identifies.parquet');
```

## 11. Page views with no user

- **Why it matters:** a page view with no `user_id` can't count toward an active user. After deduplication, 19,451 page views have none (20,318 in the raw files). All of them are on the login page. 7,453 of them carry an `anonymous_id` that an identify call ties to a user, so they could be stitched to that user; for 7,131 the identify comes at or after the view, for the other 322 only before it. No track call lacks a user (the query's `tracks_without_user`).
- **Handled:** the rule is `user_id` only; these views are left out as non-activity. Stitching would add login views, which aren't product activity, so no one's active status could change (D11).

```sql
select count(*) filter (where user_id is null) as views_without_user,
       count(*) filter (where user_id is null and context_page_path like '/login%') as on_login,
       count(*) filter (where user_id is null and anonymous_id in (
           select anonymous_id from read_parquet('data/segment_*/identifies.parquet') where user_id is not null)) as with_identified_anonymous_id,
       (select count(*) filter (where user_id is null) from read_parquet('data/segment_*/tracks.parquet')) as tracks_without_user
from read_parquet('data/segment_*/pages.parquet');
```

Check (built), after deduplication:

```sql
select *, with_identified_anonymous_id - identified_at_or_after_the_view as identified_only_before_the_view
from (
select count(*) filter (where user_id is null) as views_without_user,
       count(*) filter (where user_id is null and page_path like '/login%') as on_login,
       count(*) filter (where user_id is null and anonymous_id in (
           select anonymous_id from stg_segment__identifies where user_id is not null)) as with_identified_anonymous_id,
       count(*) filter (where user_id is null and exists (
           select 1 from stg_segment__identifies i where i.user_id is not null and i.anonymous_id = p.anonymous_id and i.event_at >= p.event_at)) as identified_at_or_after_the_view
from stg_segment__pages p
);
```

## 12. Smaller issues, left as they are

None of these changes who is active.

- **`users.created_at` is later than the user's first page view** for 232 users, by a median of 8 days and up to 116. A signup or new-user metric shouldn't trust it.

  ```sql
  with f as (select user_id, min(received_at) as first_view from read_parquet('data/segment_*/pages.parquet') where user_id is not null group by 1)
  select count(*) as users, median(date_diff('day', f.first_view, u.created_at)) as median_days_late, max(date_diff('day', f.first_view, u.created_at)) as max_days_late
  from read_parquet('data/app_*/users.parquet') u join f using (user_id) where f.first_view < u.created_at - interval 1 day;
  ```

- **Runs start seconds to hours before their workspace (562) or organization (205) was created,** always on the same day. It looks like the record's creation time is written after the first run; it doesn't affect months.

  ```sql
  select count(*) as runs_before_workspace_created, count(*) filter (where cast(r.started_at as date) <> cast(w.created_at as date)) as on_another_day,
         min(w.created_at - r.started_at) as shortest, max(w.created_at - r.started_at) as longest
  from read_parquet('data/app_*/runs.parquet') r join read_parquet('data/app_*/workspaces.parquet') w using (workspace_id)
  where r.started_at < w.created_at;
  ```

  ```sql
  select count(*) as runs_before_organization_created, count(*) filter (where cast(r.started_at as date) <> cast(o.created_at as date)) as on_another_day,
         min(o.created_at - r.started_at) as shortest, max(o.created_at - r.started_at) as longest
  from read_parquet('data/app_*/runs.parquet') r join read_parquet('data/app_*/organizations.parquet', union_by_name = true) o using (organization_id)
  where r.started_at < o.created_at;
  ```

- **Every dataset page view is a dataset's compare page,** which the glossary calls Experiments. So the datasets area has no signal of its own (D13).

  ```sql
  select count(*) filter (where context_page_path like '%/datasets/%/compare%') as compare, count(*) filter (where context_page_path like '%/datasets/%') as all_dataset_pages
  from read_parquet('data/segment_*/pages.parquet');
  ```

- **Internal staff are members of customer organizations** (51 users) but have no product events there. Excluding them changes nothing today; the rule stays for when they do (`analyses/sensitivity.sql` part D counts their events in customer organizations).

  ```sql
  select count(distinct u.user_id) as internal_users_in_customer_orgs
  from read_parquet('data/app_*/workspace_memberships.parquet') m
  join read_parquet('data/app_*/workspaces.parquet') w using (workspace_id)
  join read_parquet('data/app_*/users.parquet') u using (user_id)
  where u.email like '%@internal.example'
    and w.organization_id not in (select organization_id from read_csv('seeds/internal_organizations.csv'));
  ```

- **Runs carry no user,** so usage can't be split by person, and an internal user's runs inside a customer organization can't be excluded. The runs table has no user column:

  ```sql
  select count(*) as user_columns_on_runs
  from (describe select * from read_parquet('data/app_*/runs.parquet'))
  where column_name like '%user%';
  ```

- **`total_tokens` is null for every non-LLM run (143,950).** That's expected: only LLM runs consume tokens, and no LLM run lacks it.

  ```sql
  select count(*) filter (where total_tokens is null) as null_tokens,
         count(*) filter (where total_tokens is null and run_type <> 'llm') as null_non_llm,
         count(*) filter (where total_tokens is null and run_type = 'llm') as null_llm
  from read_parquet('data/app_*/runs.parquet');
  ```

- **3 anonymous ids identify as more than one user** (shared machines). Anonymous views are all login pages, so this doesn't matter here.

  ```sql
  select count(*) as anonymous_ids_with_several_users
  from (select anonymous_id from read_parquet('data/segment_*/identifies.parquet') where user_id is not null
        group by 1 having count(distinct user_id) > 1);
  ```
