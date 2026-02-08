{{
    config(
        materialized='table',
        tags=['staging', 'dimension', 'static']
    )
}}

/*
    Staging model for sales pipeline stages.
    
    Purpose:
        Clean dimension table for stage definitions.
        No complex transformations - this is reference data.
    
    Transformations:
        1. Rename columns for consistency
        2. Add stage_order for sorting
        3. Add stage_category for grouping analysis
        4. Add metadata fields
    
    Data Quality:
        - All 9 stages present (validated in source tests)
        - No duplicates (validated in source tests)
        - Static reference data (changes rarely)
    
    Performance:
        - Materialized as table (9 rows - tiny but frequently joined)
        - No incremental needed (static data)
    
    Grain: One row per pipeline stage
    
    Dependencies: {{ source('pipedrive', 'stages') }}
*/

with source as (

    select
        stage_id,
        stage_name
    from {{ source('pipedrive', 'stages') }}

),

renamed as (

    select
        -- Natural key
        stage_id,
        stage_name,
        
        -- Add stage_order for sorting (same as stage_id but explicit)
        stage_id as stage_order,
        
        -- Add stage grouping for analysis
        case
            when stage_id <= 3 then 'Early Stage'
            when stage_id <= 6 then 'Mid Stage'
            when stage_id <= 9 then 'Late Stage'
        end as stage_category,
        
        -- Audit metadata
        current_timestamp as _loaded_at,
        '{{ invocation_id }}' as _dbt_run_id
        
    from source

)

select * from renamed