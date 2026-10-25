# agent_analytics

A dbt project for our product analytics. It runs locally on DuckDB, so you don't need a cloud account.

Start with [INSTRUCTIONS.md](INSTRUCTIONS.md).

## Setup

You need [uv](https://docs.astral.sh/uv/getting-started/installation/). It installs the right Python version for you.

```bash
uv sync
uv run dbt deps
uv run dbt build
```

`dbt build` writes everything to `analytics.duckdb` in this folder. Until you add models, it only loads the seed.

## Looking at the data

```bash
uv run dbt show --inline "select * from {{ source('app_us', 'organizations') }}" --limit 10
```

Or open `analytics.duckdb` with any DuckDB client. The raw files are Parquet under `data/`:

| Folder | What it is |
|---|---|
| `data/app_us`, `data/app_eu`, `data/app_apac` | app database per region: organizations, users, workspaces, workspace_memberships, runs |
| `data/segment_us`, `data/segment_eu`, `data/segment_apac` | product events per region: pages, tracks, identifies |

All data is synthetic.

## Layout

- `models/sources`: source definitions for the raw files. There are no models yet
- `seeds`: hand-maintained lists
