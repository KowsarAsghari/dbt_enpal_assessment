{{
    config(
        materialized='table',
        tags=['intermediate', 'fact']
    )
}}

/*
    Fact table for deal stage changes.
    Grain: One row per stage change event.
*/

WITH base AS (
    SELECT
        change_id,
        deal_id,
        stage_id,
        stage_change_timestamp,
        stage_change_date,
        stage_change_month,
        stage_change_year
    FROM {{ ref('stg_pipedrive__deal_changes') }}
)

SELECT
    -- Surrogate key
    change_id as stage_change_key,
    
    -- Foreign keys
    deal_id,
    s.stage_id, 
    s.stage_key,
    d.date_key,
    
    -- Degenerate dimensions
    stage_change_timestamp,
    stage_change_date,
    stage_change_month,
    stage_change_year,
    
    -- Derived attributes
    s.stage_name,
    s.stage_category,
    s.is_early_funnel,
    s.is_closed_won

FROM base b
LEFT JOIN {{ ref('dim_stages') }} s ON b.stage_id = s.stage_id
LEFT JOIN {{ ref('dim_dates') }} d ON b.stage_change_date = d.date_day