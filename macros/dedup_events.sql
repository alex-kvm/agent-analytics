{#- Keep one row per event. First drop repeated event_ids. Then drop double-fired events: a repeat from the same
    sender on the same page path (and, for tracks, the same event) within var('double_fire_window_ms') of the
    previous one. The client fired these twice with new event_ids, mostly in July and August 2026; the gaps are
    under 100 ms, while real repeat views are seconds apart. -#}
{% macro dedup_events(relation, extra_partition='') -%}
    with by_id as (
        select * from {{ relation }}
        qualify row_number() over (partition by event_id order by received_at) = 1
    ),

    ordered as (
        select
            *,
            lag("timestamp") over (
                partition by coalesce(user_id, anonymous_id), context_page_path{{ extra_partition }}
                order by "timestamp", received_at, event_id
            ) as previous_client_timestamp
        from by_id
    )

    select * exclude (previous_client_timestamp)
    from ordered
    where previous_client_timestamp is null
       or date_diff('millisecond', previous_client_timestamp, "timestamp") >= {{ var('double_fire_window_ms') }}
{%- endmacro %}
