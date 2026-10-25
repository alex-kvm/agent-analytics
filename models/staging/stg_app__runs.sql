with unioned as (
    {{ union_regions('app', 'runs') }}
)

select
    run_id,
    trace_id,
    parent_run_id,
    parent_run_id is null as is_root_run,
    thread_id,
    workspace_id,
    -- The organization that owned the workspace when the run happened. workspaces.organization_id is the current
    -- owner, which is wrong for runs from before a workspace changed hands.
    organization_id,
    run_type,
    run_source,
    status,
    started_at,
    ended_at,
    total_tokens,
    region
from unioned
