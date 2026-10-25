# Write-up: active customers and what they use

## The short answer

In September 2026 (UTC), **316 of 438 customer organizations were active (72.1%), with 1,046 active users.** Active users are distinct people: a user active in two organizations counts once.

| Product area | Active organizations using it, Sep 2026 (of 316) |
|---|---|
| Tracing | 315 (99.7%) |
| Playground | 173 (54.7%) |
| Experiments | 130 (41.1%) |
| Studio | 121 (38.3%) |
| Online evaluation | 41 (13.0%) |

September 2026, UTC. Rows: one per product area; an organization can use several. Dropped: internal organizations (ISSUES.md #2) and October 2026 (#7). Datasets has no row: its pages count as experiments (D13).

- **Active organizations grew every month to August, then held,** from 238 of 281 customer organizations in April to 317 of 417 in August and 316 of 438 in September (one fewer). Distinct active users grew from 716 to 1,046.
- **The active *share* fell,** from 84.7% to 72.1%. The organizations created since April are 89.2% active in September (173 of 194); those created before April are 58.6% active (143 of 244). Only **168 of the 238 organizations active in April (70.6%) were still active in September.** That's the question I'd push the product team toward (below).

Every number here comes from `analyses/active_customers.sql`, `analyses/movers.sql`, `analyses/sensitivity.sql` or `analyses/weekly_business_review.sql`, run against the built project. Customer organizations exclude the internal ones; October 2026 (three days of events) is left out.

```bash
uv sync && uv run dbt deps && uv run dbt build
duckdb -readonly analytics.duckdb < analyses/active_customers.sql
duckdb -readonly analytics.duckdb < analyses/movers.sql
duckdb -readonly analytics.duckdb < analyses/sensitivity.sql
duckdb -readonly -markdown analytics.duckdb < analyses/weekly_business_review.sql
```

The same answer by metric name (MetricFlow, D14) and as a board (dbt Charts, D15):

```bash
uv run mf query --metrics active_organizations,active_users --group-by metric_time__month
uv run mf query --metrics active_organizations,active_users --group-by metric_time__week
uvx --from dbt-charts==0.10.0 dct --no-send-anonymous-usage-stats render charts/active_customers.yml --no-cache --format html -o target/charts/active_customers.html
```

## Weekly business review

The same definitions as a standing weekly report, in the format of a weekly business review: numbered metrics, the four latest complete weeks and months with their change, and the regions as row blocks after worldwide.

```
type -> report
id -> weekly-business-review
scope -> customer organizations and users, all regions, UTC; weeks Monday to Sunday
owner:business -> the product team (the decisions it drives)
owner:finance -> FP&A (planning targets)
owner:data -> analytics (this project: models/reports)
refresh -> uv run dbt build, then duckdb -readonly -markdown analytics.duckdb < analyses/weekly_business_review.sql
```

<!-- wbr:table:start -->
| # |                Metric                | Wk 1  |  Wk 2  |  Wk 3  |  Wk 4  |    WoW    |   Mo 1   |   Mo 2   |   Mo 3   |   Mo 4   |    MoM    |
|---|--------------------------------------|-------|--------|--------|--------|-----------|----------|----------|----------|----------|-----------|
|   | Period ending (UTC)                  | 6 Sep | 13 Sep | 20 Sep | 27 Sep | WoW       | Jun 2026 | Jul 2026 | Aug 2026 | Sep 2026 | MoM       |
|   | Worldwide                            |       |        |        |        |           |          |          |          |          |           |
| 1 | Customer organizations               | 425   | 432    | 438    | 438    | 0.0%      | 349      | 385      | 417      | 438      | 5.0%      |
| 2 | Active organizations                 | 271   | 265    | 269    | 267    | (0.7%)    | 279      | 294      | 317      | 316      | (0.3%)    |
| 3 | Active share, %                      | 63.8% | 61.3%  | 61.4%  | 61.0%  | (46 bps)  | 79.9%    | 76.4%    | 76.0%    | 72.1%    | (387 bps) |
| 4 | Distinct active users                | 611   | 650    | 620    | 612    | (1.3%)    | 821      | 926      | 1,019    | 1,046    | 2.6%      |
| 5 | Active users per active organization | 2.25  | 2.45   | 2.30   | 2.29   | (0.6%)    | 2.94     | 3.15     | 3.21     | 3.31     | 3.0%      |
| 6 | Active-source runs, 000s             | 9.7   | 9.7    | 10.4   | 11.1   | 7.3%      | 26.3     | 31.9     | 34.7     | 44.4     | 27.8%     |
| 7 | Online-evaluation runs               | 430   | 494    | 471    | 461    | (2.1%)    | 1,004    | 1,119    | 1,255    | 2,031    | 61.8%     |
|   | US                                   |       |        |        |        |           |          |          |          |          |           |
| 1 | Customer organizations               | 250   | 255    | 258    | 258    | 0.0%      | 207      | 231      | 246      | 258      | 4.9%      |
| 2 | Active organizations                 | 149   | 144    | 144    | 147    | 2.1%      | 161      | 174      | 182      | 178      | (2.2%)    |
| 3 | Active share, %                      | 59.6% | 56.5%  | 55.8%  | 57.0%  | 116 bps   | 77.8%    | 75.3%    | 74.0%    | 69.0%    | (499 bps) |
| 4 | Distinct active users                | 310   | 318    | 295    | 304    | 3.1%      | 474      | 545      | 559      | 579      | 3.6%      |
| 5 | Active users per active organization | 2.08  | 2.21   | 2.05   | 2.07   | 0.9%      | 2.94     | 3.13     | 3.07     | 3.25     | 5.9%      |
| 6 | Active-source runs, 000s             | 5.0   | 4.3    | 4.9    | 5.6    | 12.7%     | 16.0     | 18.7     | 18.7     | 21.8     | 16.3%     |
| 7 | Online-evaluation runs               | 135   | 174    | 130    | 154    | 18.5%     | 528      | 646      | 521      | 646      | 24.0%     |
|   | EU                                   |       |        |        |        |           |          |          |          |          |           |
| 1 | Customer organizations               | 111   | 111    | 112    | 112    | 0.0%      | 86       | 96       | 107      | 112      | 4.7%      |
| 2 | Active organizations                 | 80    | 82     | 83     | 82     | (1.2%)    | 73       | 78       | 90       | 89       | (1.1%)    |
| 3 | Active share, %                      | 72.1% | 73.9%  | 74.1%  | 73.2%  | (89 bps)  | 84.9%    | 81.2%    | 84.1%    | 79.5%    | (465 bps) |
| 4 | Distinct active users                | 194   | 221    | 210    | 204    | (2.9%)    | 205      | 217      | 292      | 306      | 4.8%      |
| 5 | Active users per active organization | 2.42  | 2.70   | 2.53   | 2.49   | (1.7%)    | 2.81     | 2.78     | 3.24     | 3.44     | 6.0%      |
| 6 | Active-source runs, 000s             | 3.2   | 3.4    | 3.6    | 3.6    | 1.3%      | 5.8      | 7.2      | 10.0     | 14.8     | 48.0%     |
| 7 | Online-evaluation runs               | 246   | 237    | 265    | 190    | (28.3%)   | 241      | 220      | 480      | 1,021    | 112.7%    |
|   | APAC                                 |       |        |        |        |           |          |          |          |          |           |
| 1 | Customer organizations               | 64    | 66     | 68     | 68     | 0.0%      | 56       | 58       | 64       | 68       | 6.3%      |
| 2 | Active organizations                 | 42    | 39     | 42     | 38     | (9.5%)    | 45       | 42       | 45       | 49       | 8.9%      |
| 3 | Active share, %                      | 65.6% | 59.1%  | 61.8%  | 55.9%  | (588 bps) | 80.4%    | 72.4%    | 70.3%    | 72.1%    | 175 bps   |
| 4 | Distinct active users                | 107   | 111    | 115    | 104    | (9.6%)    | 142      | 164      | 168      | 161      | (4.2%)    |
| 5 | Active users per active organization | 2.55  | 2.85   | 2.74   | 2.74   | 0.0%      | 3.16     | 3.90     | 3.73     | 3.29     | (12.0%)   |
| 6 | Active-source runs, 000s             | 1.5   | 2.0    | 1.8    | 1.9    | 4.7%      | 4.5      | 5.9      | 6.0      | 7.9      | 30.4%     |
| 7 | Online-evaluation runs               | 49    | 83     | 76     | 117    | 53.9%     | 235      | 253      | 254      | 364      | 43.3%     |
<!-- wbr:table:end -->

Every cell comes from `models/reports/rpt_weekly_business_review_table`, which reads the data tab `rpt_weekly_business_review`: day, week and month counts by region, one union with `period` and `period_end_date`, on the facts' rules and vars. Its counts equal the marts' for every complete month and week (D18). WoW compares the latest week with the one before, and MoM September with August. Changes are % for counts, ratios and runs, and basis points for the share; negatives are in parentheses. Footnotes, by metric number:

1. **Customer organizations:** organizations that are neither on the internal list nor caught by the derived rule (ISSUES.md #2), counted from the period they were created in. Personal organizations are included (`include_personal_orgs`).
2. **Active organizations:** at least `active_org_min_users` (1) active user or `active_org_min_runs` (1) active-source run in the period, as defined above.
3. **Active share:** row 2 ÷ row 1, from the counts and never averaged across rows. Its change is in basis points.
4. **Distinct active users:** product activity on at least `active_user_min_days` (1) day in the period, counted once however many organizations the user was in. Internal users are excluded. No user was active in two regions in these months, so the regions add up to worldwide; in other data they needn't.
5. **Active users per active organization:** row 4 ÷ row 2, from the counts.
6. **Active-source runs:** runs from `sdk`, `experiment`, `playground` and `studio`, in thousands. Sample-data runs (#3) and online-evaluator runs (#6) are excluded.
7. **Online-evaluation runs:** automated runs from online evaluators (#6). They count toward the evaluation area but don't make an organization active.

Weeks and months are complete ones, UTC. The week of 28 September has three days before October, which is left out (#7), and the week of 30 March starts before April. The model keeps both with blank metrics rather than show a drop (D19). Rows: one block per region, the same seven metrics in each. Dropped: internal organizations and users (#2), sample-data runs (#3), October 2026 (#7) and anonymous login views (#11).

Weekly counts sit below monthly ones: an organization active in September needn't be active every week. In the week to 27 September, 267 of 438 customer organizations were active (61.0%), with 612 distinct users. Month over month, August against September (`analyses/movers.sql` part 9, by region):

- **The active share fell from 76.0% to 72.1% (−387 basis points, −5.1%):** customer organizations grew by 21 while active ones fell by 1. us carries it: 12 of the 21 new customer organizations and 4 fewer active ones, its own share down 499 basis points (−6.7%) to 69.0%.
- **Distinct active users rose from 1,019 to 1,046 (+27, +2.6%).** us carries 20 of the 27 (74.1%); apac fell by 7.
- **Active-source runs rose from 34,731 to 44,397 (+9,666, +27.8%).** eu carries 4,789 of them (49.5%), up 48.0%.

## Model structure, and why

```
sources (3 regions x app + Segment)
  └─ staging      stg_app__*, stg_segment__*   one model per source table; the 3 regions unioned by name
  │                                            (union_regions); renamed, typed, deduplicated, flags derived
  └─ intermediate int_organizations            internal and personal flags, member counts
  │               int_user_events              pages + tracks as one stream, tagged with a product area
  │               int_runs                     runs tagged with a product area and counts_as_activity
  └─ marts        dim_organizations, dim_users
                  fct_user_activity_monthly    grain: user x organization x period
                  fct_org_activity_monthly     grain: organization x period, zero periods included
  └─ semantic     sem_activity_daily, sem_runs MetricFlow semantic models and metrics on a daily time spine
  └─ reports      rpt_weekly_business_review   the weekly business review's data tab: day, week and month by region
                  rpt_weekly_business_review_table  the review in its report layout, every cell computed
seeds             internal_organizations, product_areas (page area / track event / run source -> area)
macros            union_regions, dedup_events, activity_period (the period both facts and the spine use),
                  wbr_format (the review's cell formats)
```

This is the usual dbt layering (staging, then intermediate, then marts) with Kimball-style facts and dimensions at the marts. It was chosen for the product team's actual complaint: one-off queries whose answers don't agree.

- **Each fix happens once.** Deduplication, the timestamp choice, the region union and the internal flags all live in staging or intermediate. Every downstream number inherits them, so nobody re-fixes them in their own query.
- **Each definition lives in one place.** The thresholds, the run sources, the personal-organization cut and the period are dbt `vars` in `dbt_project.yml`, and the product-area mapping is a seed. Changing what "active" means, or looking at weeks instead of months, is one edit and a `dbt build`, and every answer moves together.
- **The facts have a stated grain, and the organization fact has a spine.** Every organization has a row for every period it existed, including inactive ones. "How many are active", "what share" and "who went quiet" are then group-bys on one table, rather than joins that silently drop the inactive.
- **Measures say whether they add up.** A user can be active in two organizations, so `fct_org_activity_monthly.active_users` doesn't add across organizations; its description says so, and platform-wide active users are `count(distinct user_id)` on the user fact. Runs do add.
- **Metrics have names.** `active_organizations`, `active_users` (distinct) and `runs` by area are MetricFlow metrics on daily activity, so a question at another grain is a query, not a new model, and returns the marts' numbers (D14). A dbt Charts board reads the marts for the people who'd rather look than query (D15).
- **Dimensions keep the flags.** Internal and personal organizations stay in `dim_organizations`, flagged, so a different cut is a filter, not a rebuild.
- **Tests encode the assumptions:**
  - unique and not-null primary keys across regions
  - relationships on every foreign key, from staging to the facts
  - accepted values for areas and sources
  - no internal organization in the facts
  - no double-fired page views left
  - every signal mapped to an area.

## The definitions

**Active user (in a period; a calendar month by default).** A non-internal user who, on at least `active_user_min_days` (1) distinct days in the period, viewed or did something in a product area inside a customer organization. The days are counted across all the user's customer organizations, and the user counts once. The product areas are tracing (projects and traces), playground, studio, datasets and experiments. Logging in, settings and the workspace home page don't count, because they're not using the product.

**Whose event it is.** An event belongs to a user by `user_id` only. Anonymous ids aren't stitched to users through identify calls: every anonymous page view is on the login page (19,451 after deduplication), which isn't activity, so stitching can't change who is active (ISSUES.md #11, D11).

**Active organization (in a period).** A customer organization, that is, not internal by the list or by the derived rule, that either:

- had at least `active_org_min_users` (1) active users, or
- had at least `active_org_min_runs` (1) customer-driven runs: `sdk`, `experiment`, `playground` or `studio`.

Why both: usage is measured in runs, and 48 organizations in September used the platform *only* through runs. Their code sends traces through the SDK, and no one opened the app. They are clearly customers using the product. Sample-data runs (onboarding fixtures) and online-evaluator runs (automated) don't make an organization active on their own.

**Which parts of the product.** The `product_areas` seed maps each signal to an area (D13):

| Signal | Area |
|---|---|
| page path `projects/…` (including traces) | tracing |
| `playground` | playground |
| `studio` | studio |
| `datasets/…/compare` | experiments |
| run source `sdk` | tracing |
| run source `experiment` | experiments |
| run sources `playground` and `studio` | their own areas |
| run source `online_evaluator` | online evaluation |
| track events | the area their name says |

A track event's name wins over the page it fired on: `playground_submit` also fires on dataset pages, when a row is opened in the playground.

## The answer, with the SQL

Active organizations and distinct active users by month (part 1 of `analyses/active_customers.sql`):

```sql
with users as (
    select activity_month, count(distinct user_id) filter (where is_active_user) as active_users
    from fct_user_activity_monthly
    group by 1
)
select o.activity_month,
       count(*)                                                        as customer_orgs,
       count(*) filter (where o.is_active)                             as active_orgs,
       round(100.0 * count(*) filter (where o.is_active) / count(*), 1) as pct_active,
       count(*) filter (where o.activity_type = 'ui_and_runs')         as ui_and_runs,
       count(*) filter (where o.activity_type = 'ui_only')             as ui_only,
       count(*) filter (where o.activity_type = 'runs_only')           as runs_only,
       any_value(u.active_users)                                       as active_users
from fct_org_activity_monthly as o
left join users as u using (activity_month)
group by 1 order by 1;
```

| Month (UTC) | Customer orgs | Active | % active | UI and runs | UI only | Runs only | Active users (distinct) |
|---|---|---|---|---|---|---|---|
| 2026-04 | 281 | 238 | 84.7 | 196 | 4 | 38 | 716 |
| 2026-05 | 316 | 262 | 82.9 | 213 | 7 | 42 | 771 |
| 2026-06 | 349 | 279 | 79.9 | 233 | 4 | 42 | 821 |
| 2026-07 | 385 | 294 | 76.4 | 244 | 6 | 44 | 926 |
| 2026-08 | 417 | 317 | 76.0 | 264 | 5 | 48 | 1,019 |
| 2026-09 | 438 | 316 | 72.1 | 265 | 3 | 48 | 1,046 |

Rows: one per complete month. Dropped: internal organizations and internal users (ISSUES.md #2), October 2026 (three days of events, #7), and anonymous login views (#11). Organizations count from the month they were created, so the customer count grows.

Product areas among the 316 active organizations in September: tracing 315 (99.7%), playground 173 (54.7%), experiments 130 (41.1%), studio 121 (38.3%), online evaluation 41 (13.0%). The query is part 2 of `analyses/active_customers.sql`. Breadth, of the same 316: 74 used one area, 87 two, 100 three, 43 four and 12 five (part 5).

By segment in September (part 3):

| Plan | Active of customer orgs, Sep 2026 |
|---|---|
| Enterprise | 21 of 31 |
| Plus | 99 of 124 |
| Free, company | 121 of 174 |
| Free, personal | 75 of 109 |

September 2026, UTC. Rows: one per plan, with personal organizations as their own row. Dropped: internal organizations (ISSUES.md #2) and October 2026 (#7).

Runs from customer-driven sources, plus online evaluation, April against September (`analyses/movers.sql` part 6):

| Area | April | September | Change | Change, % |
|---|---|---|---|---|
| Tracing | 13,878 | 30,109 | +16,231 | +117.0% |
| Experiments | 3,102 | 6,541 | +3,439 | +110.9% |
| Playground | 1,973 | 4,335 | +2,362 | +119.7% |
| Studio | 1,793 | 3,412 | +1,619 | +90.3% |
| Online evaluation | 643 | 2,031 | +1,388 | +215.9% |

April and September 2026, UTC. Rows: one per product area. All customer organizations; the 157 created after April count with 0 April runs. Dropped: internal organizations (ISSUES.md #2), sample-data runs (#3) and October 2026 (#7).

## Assumptions

1. **Periods are calendar months on the server's receive time (UTC),** set by `var('activity_grain')`. April to September 2026 are complete; October has three days of events and is left out.
2. **Usage belongs to the organization that owned the workspace at the time.** For runs that's `runs.organization_id`; for page views, the organization in the URL. It isn't the workspace's current owner: 15 workspaces changed owner (ISSUES.md #1). No run is missing its workspace.
3. **Internal organizations** are the hand-maintained list plus any organization created by internal staff whose members are all internal (4 more, ISSUES.md #2). Internal users (`@internal.example`) never count as active users.
4. **Personal organizations are customers,** flagged as `is_personal`. In apac, where the column is missing, they're derived from the name. `var('include_personal_orgs')` leaves them out in one edit.
5. **Sample-data runs and online-evaluator runs aren't activity** (ISSUES.md #3, #6).
6. **Page views that fired twice within one second are one view,** and repeated `event_id`s are dropped (ISSUES.md #8, #10).
7. **One active day a month makes a user active.** This is a reach measure (MAU). Stricter thresholds give, for September: 2 days 836 distinct active users, 4 days 502, 8 days 193 (`analyses/sensitivity.sql` part A). The threshold is `var('active_user_min_days')`.
8. **A dataset's compare page counts as experiments** (D13). Counting it as datasets instead moves datasets from 0.0% to 31.3% of September's active organizations and experiments from 41.1% to 40.5% (`analyses/sensitivity.sql` part K).

## Pushing back on the question

"Which customers are active" is a count that grew from April to August and then held. The more useful question for planning is **"which customers stopped being active, and why?"**: 70 of April's 238 active organizations weren't active in September. Two more things I'd raise:

- **"Active" needs a purpose.** For a reach number (how many use us), one day a month is right. For a health number (who relies on us), a weekly or multi-day threshold is. The model takes either; the product team should pick per use.
- **Personal organizations are a quarter of customers** (109 of 438). Planning numbers should probably split them out, or count them as users rather than customers.

## Questions for the product team

1. What decision will this drive? A target for next quarter, a churn list for customer success, or prioritizing product areas? The answer sets the threshold and the grain (monthly or weekly).
2. Should an organization that only sends traces through the SDK, with no one logging in, count as active? I count it.
3. Are personal organizations customers for planning purposes?
4. Is the internal list maintained? It's missing 4 organizations, one on the enterprise plan, that look like internal demos.
5. Should online evaluators count as usage of evaluation on their own? Automated, but configured by the customer.
6. Is there a better product-area taxonomy? For example, is the workspace home or settings meaningful, and should datasets be separate from experiments? Today every dataset page is a compare page.
7. Can runs carry a user? Today usage can't be attributed to people, only to organizations.

## Task 3: what I'd do next

**What I found.** April against September 2026, UTC (`analyses/movers.sql`). Nothing below comes from an experiment, so every "why" is a candidate cause with a confidence, not a cause.

- **Active organizations: 238 → 316 (+78, +32.8%).** Free company organizations carry 38 of the 78 (48.7%) and plus 28 (35.9%); personal organizations add 8 and enterprise 4 (part 2). By region, us carries 39 (50.0%), eu 26 and apac 13 (part 3).
  - *Candidate cause (medium confidence: timing and segment, no experiment):* new sign-ups. Customer organizations grew 281 → 438 (+157, +55.9%), and the organizations created since April are 89.2% active in September (173 of 194; part 4).
- **Distinct active users: 716 → 1,046 (+330, +46.1%),** faster than active organizations, so active organizations have more active people each (part 1).
  - The organizations created since April carry it: their active users went from 68 to 530 (+462), while those of organizations created before April fell from 649 to 531 (−118, −18.2%) (part 8).
  - By plan, plus carries 180 of the 330 (+65.2%, 276 → 456); by region, eu carries 172 (+128.4%, 134 → 306).
  - A user active in organizations of two segments counts in each, so these shares overlap: in September, 15 users were active in organizations of both cohorts and 13 in organizations of two plans. No user was active in two regions.
  - *Candidate cause (medium confidence: timing and segment, no experiment):* new sign-ups bringing new people, while older organizations lose active people.
- **The active share: 84.7% → 72.1% (−12.6 points, −14.8%).** It sits in the organizations created before April: 58.6% of them are active in September (143 of 244), against 89.2% of the newer ones (part 4).
  - *Candidate cause (medium confidence: timing and segment, no experiment):* older customers going quiet. 70 of the 238 April-active organizations (29.4%) weren't active in September.
- **The 70 that went quiet, against the 168 still active** (parts 5 and 5b):
  - Enterprise organizations went quiet most often: 7 of 17 (41.2%). Personal organizations went quiet at 32.8% (22 of 67), free company ones at 28.9% (24 of 83) and plus at 23.9% (17 of 71).
  - In April, they used fewer areas: 2.11 on average against 2.3, and 32.9% used only one area against 26.2%.
  - *Candidate cause (low confidence: a small gap in small groups, no experiment):* shallow adoption. A one-area April goes with going quiet, but the gap is small and the groups are small. Seven enterprise organizations is the segment worth a look by name.
- **Runs roughly doubled in every area, and online evaluation tripled: 643 → 2,031 (+1,388, +215.9%)** (part 6).
  - A few customers carry online evaluation's growth: the five organizations that added the most account for 77.6% of its increase (1,077 of 1,388). In the other areas the top five carry 37.8% (tracing) to 51.3% (playground). These counts include organizations created after April, with 0 April runs.
  - Organizations running online evaluators went from 26 to 41, and their runs per organization from 24.7 to 49.5 (part 7).
  - In every area, the organizations created since April carry most of the growth (part 10): tracing +12,544 of +16,231 (77.3%), playground +2,065 of +2,362 (87.4%), studio +1,553 of +1,619 (95.9%), online evaluation +1,024 of +1,388 (73.8%), and all of experiments' +3,439 (100.3%; those created before April ran 11 fewer). By region, eu carries the largest share in every area but experiments, where apac does (36.3%).
  - *Candidate cause (medium confidence: timing and segment, no experiment):* new organizations ramping up, plus broader adoption and heavier use of online evaluation. Telling a launch from organic growth needs the release history, which these exports don't have.
- **The data has real traps,** listed in ISSUES.md. Workspace ownership transfers, an incomplete internal list and sample-data runs each change who counts as active. A July and August double-fire and an August login monitor would inflate any traffic metric.

**Questions this raises:**

- Who are the 70 organizations that went quiet, and the 7 enterprise ones among them by name? Did they stop at once, or fade?
- Does adopting a second area (experiments, studio) predict retention, once plan and age are held fixed?
- Did online evaluation grow from a launch, or from customers finding it? Five organizations added 1,077 of its 1,388 new runs: who are they, and what did they set up?

**Where I'd take the model next:**

1. **A rolling 28-day active flag** next to the monthly one. The weekly grain is already one edit (`var('activity_grain')`); a rolling window is the next health measure.
2. **An organization lifecycle model:** new, activated, retained, dormant and resurrected per period, so churn is a column, not an analysis.
3. **More of the semantic layer.** `active_organizations`, `active_users` and `runs` are MetricFlow metrics now (D14), at thresholds of 1. A multi-day threshold or a rolling window needs a cumulative or derived metric, and the board could read metrics once dbt Charts can query them.
4. **dbt snapshots of `workspaces`,** so ownership history exists directly, instead of being inferred from runs.
5. **Source tests on the raw data** (freshness, accepted values, row counts per region), so the next double-fire or schema drift fails the build instead of the numbers.

**Analyses I'd run:**

- dormancy drivers (plan, region, areas, first-week behaviour), with the organization's age held fixed
- the relationship between area breadth and retention
- a cohort retention curve by creation month
- the share of usage that comes from a small number of organizations.

**What I'd suggest to the business:**

- Make "active organization (monthly)" and "active user (monthly, distinct)" the official definitions, with the thresholds owned in one place.
- Build a dormancy alert for customer success: active last month, not this month.
- Treat the playground and experiments as the bridge from tracing to deeper use, and measure whether it works.
- Ask engineering to fix the event pipeline: the double-fires, the login monitors, and the missing internal-list entries.
