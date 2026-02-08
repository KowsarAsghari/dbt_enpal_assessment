{{
    config(
        materialized='table',
        tags=['intermediate', 'aggregate']
    )
}}

/*
    One row per deal with arrays for time-travel analysis.
    Optimized for single-deal queries.
*/

SELECT
    deal_id,
    
    -- Arrays for time travel
    array_agg(stage_id ORDER BY stage_change_timestamp) as stage_journey,
    array_agg(stage_change_timestamp ORDER BY stage_change_timestamp) as stage_timestamps,
    
    -- Metrics
    COUNT(*) as total_stage_changes,
    MIN(stage_change_date) as first_stage_date,
    MAX(stage_change_date) as last_stage_date,
    MAX(stage_change_timestamp) - MIN(stage_change_timestamp) as total_journey_duration

FROM {{ ref('fct_deal_stage_changes') }}
GROUP BY deal_id