{{
    config(
        materialized='table',
        tags=['intermediate', 'fact']
    )
}}

/*
    Fact table for sales activities.
    Filters: Only Sales Call 1 & 2, completed only.
    Grain: One row per completed sales call.
*/

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key(['activity_id', 'deal_id']) }} as activity_key,
    
    -- Foreign keys
    activity_id,
    deal_id,
    user_id,
    d.date_key,
    
    -- Degenerate dimensions
    activity_timestamp,
    activity_date,
    activity_month,
    activity_year,
    activity_type_code,
    activity_type_name,
    
    -- Business logic
    CASE 
        WHEN activity_type_code = 'meeting' THEN 'Step 2.1: Sales Call 1'
        WHEN activity_type_code = 'sc_2' THEN 'Step 3.1: Sales Call 2'
    END as funnel_step

FROM {{ ref('stg_pipedrive__activity') }} a
LEFT JOIN {{ ref('dim_dates') }} d ON a.activity_date = d.date_day
WHERE activity_type_code IN ('meeting', 'sc_2')
  AND is_completed = true