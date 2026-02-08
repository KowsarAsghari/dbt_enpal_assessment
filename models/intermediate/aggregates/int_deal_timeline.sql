{{
    config(
        materialized='table',
        tags=['intermediate', 'aggregate']
    )
}}

/*
    Complete deal timeline - pure arrays for time-travel.
    Each array paired with timestamps for point-in-time analysis.
    
    Arrays ONLY - no aggregated counts (derive those in marts).
    
    Grain: One row per deal
*/

WITH stage_changes AS (
    SELECT 
        deal_id,
        change_time::timestamp as event_time,
        new_value::integer as stage_id
    FROM {{ source('pipedrive', 'deal_changes') }}
    WHERE changed_field_key = 'stage_id'
),

activities AS (
    SELECT 
        deal_id,
        due_to::timestamp as event_time,
        type as activity_type
    FROM {{ source('pipedrive', 'activity') }}
    WHERE done = true
      AND type IN ('meeting', 'sc_2')
),

owner_changes AS (
    SELECT 
        deal_id,
        change_time::timestamp as event_time,
        new_value::integer as user_id
    FROM {{ source('pipedrive', 'deal_changes') }}
    WHERE changed_field_key = 'user_id'
),

deal_created AS (
    SELECT 
        deal_id,
        new_value::timestamp as created_at
    FROM {{ source('pipedrive', 'deal_changes') }}
    WHERE changed_field_key = 'add_time'
),

deal_lost AS (
    SELECT 
        deal_id,
        change_time::timestamp as lost_at,
        new_value::integer as lost_reason_code
    FROM {{ source('pipedrive', 'deal_changes') }}
    WHERE changed_field_key = 'lost_reason'
),

-- Aggregate arrays per deal
stage_arrays AS (
    SELECT 
        deal_id,
        array_agg(stage_id ORDER BY event_time) as stage_ids,
        array_agg(event_time ORDER BY event_time) as stage_change_times
    FROM stage_changes
    GROUP BY deal_id
),

activity_arrays AS (
    SELECT 
        deal_id,
        array_agg(activity_type ORDER BY event_time) as activity_types,
        array_agg(event_time ORDER BY event_time) as activity_times
    FROM activities
    GROUP BY deal_id
),

owner_arrays AS (
    SELECT 
        deal_id,
        array_agg(user_id ORDER BY event_time) as owner_user_ids,
        array_agg(event_time ORDER BY event_time) as owner_change_times
    FROM owner_changes
    GROUP BY deal_id
),

lost_info AS (
    SELECT 
        deal_id,
        lost_at,
        lost_reason_code
    FROM deal_lost
),

created_info AS (
    SELECT 
        deal_id,
        created_at
    FROM deal_created
),

-- Get ALL unique deals
all_deals AS (
    SELECT DISTINCT deal_id 
    FROM {{ source('pipedrive', 'deal_changes') }}
)

-- Join everything
SELECT 
    d.deal_id,
    
    -- Creation (scalar)
    c.created_at,
    
    -- Stage journey (arrays)
    s.stage_ids,
    s.stage_change_times,
    
    -- Activities (arrays)
    a.activity_types,
    a.activity_times,
    
    -- Owner changes (arrays)
    o.owner_user_ids,
    o.owner_change_times,
    
    -- Lost info (scalar)
    l.lost_at,
    l.lost_reason_code

FROM all_deals d
LEFT JOIN created_info c ON d.deal_id = c.deal_id
LEFT JOIN stage_arrays s ON d.deal_id = s.deal_id
LEFT JOIN activity_arrays a ON d.deal_id = a.deal_id
LEFT JOIN owner_arrays o ON d.deal_id = o.deal_id
LEFT JOIN lost_info l ON d.deal_id = l.deal_id
