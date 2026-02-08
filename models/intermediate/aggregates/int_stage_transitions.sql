{{
    config(
        materialized='view',
        tags=['intermediate', 'aggregate']
    )
}}

/*
    Detailed stage transition patterns.
    Arrays include: deal_ids, timestamps, time_between, stage_names.
*/

WITH stage_changes AS (
    SELECT 
        dc.deal_id,
        dc.new_value::integer as stage_id,
        s.stage_name,
        dc.change_time::timestamp as changed_at,
        ROW_NUMBER() OVER (PARTITION BY dc.deal_id ORDER BY dc.change_time) as seq
    FROM {{ source('pipedrive', 'deal_changes') }} dc
    LEFT JOIN {{ ref('stg_pipedrive__stages') }} s ON dc.new_value::integer = s.stage_id
    WHERE dc.changed_field_key = 'stage_id'
),

transitions AS (
    SELECT 
        curr.deal_id,
        prev.stage_id as from_stage_id,
        prev.stage_name as from_stage_name,
        curr.stage_id as to_stage_id,
        curr.stage_name as to_stage_name,
        curr.changed_at as transition_time,
        curr.changed_at::date as transition_date,
        curr.changed_at - prev.changed_at as time_between,
        
        -- Classify transition type
        CASE 
            WHEN curr.stage_id > prev.stage_id THEN 'forward'
            WHEN curr.stage_id < prev.stage_id THEN 'backward'
            ELSE 'same'
        END as transition_type,
        
        curr.stage_id - prev.stage_id as stage_jump
        
    FROM stage_changes curr
    JOIN stage_changes prev 
        ON curr.deal_id = prev.deal_id 
        AND curr.seq = prev.seq + 1
),

transition_arrays AS (
    SELECT 
        from_stage_id,
        from_stage_name,
        to_stage_id,
        to_stage_name,
        transition_type,
        stage_jump,
        
        -- Arrays for drill-down
        array_agg(deal_id ORDER BY transition_time) as deal_ids,
        array_agg(transition_time ORDER BY transition_time) as transition_times,
        array_agg(transition_date ORDER BY transition_time) as transition_dates,
        array_agg(time_between ORDER BY transition_time) as time_between_stages,
        
        -- Aggregated metrics
        array_length(array_agg(deal_id), 1) as transition_count,
        
        AVG(EXTRACT(epoch FROM time_between)) / 86400.0 as avg_days_between,
        MIN(EXTRACT(epoch FROM time_between)) / 86400.0 as min_days_between,
        MAX(EXTRACT(epoch FROM time_between)) / 86400.0 as max_days_between
        
    FROM transitions
    GROUP BY 1,2,3,4,5,6
)

SELECT 
    from_stage_id,
    from_stage_name,
    to_stage_id,
    to_stage_name,
    transition_type,
    stage_jump,
    transition_count,
    deal_ids,
    transition_times,
    transition_dates,
    time_between_stages,
    ROUND(avg_days_between::numeric, 1) as avg_days_between,
    ROUND(min_days_between::numeric, 1) as min_days_between,
    ROUND(max_days_between::numeric, 1) as max_days_between
    
FROM transition_arrays
ORDER BY transition_count DESC