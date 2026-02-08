{{
    config(
        materialized='table',
        tags=['intermediate', 'dimension']
    )
}}

/*
    Enhanced stage dimension with business logic.
*/

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key(['stage_id']) }} as stage_key,
    
    -- Natural key
    stage_id,
    stage_name,
    stage_order,
    stage_category,
    
    -- Business rules
    CASE WHEN stage_id <= 2 THEN true ELSE false END as is_early_funnel,
    CASE WHEN stage_id >= 7 THEN true ELSE false END as is_post_sale,
    CASE WHEN stage_id = 6 THEN true ELSE false END as is_closed_won

FROM {{ ref('stg_pipedrive__stages') }}