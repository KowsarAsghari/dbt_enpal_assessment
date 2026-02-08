{{
    config(
        materialized='table',
        tags=['staging', 'dimension', 'static']
    )
}}

/*
    Staging model for activity type definitions.
    
    Purpose:
        Clean lookup table for activity types.
        Maps activity codes to display names.
    
    Transformations:
        1. Rename columns for consistency
        2. Filter for active types only (optional - kept all for now)
        3. Add metadata
    
    Data Quality:
        - All 4 activity types present
        - No duplicates
        - Static reference data
    
    Performance:
        - 4 rows only (tiny lookup table)
        - Materialized as table for consistency
    
    Grain: One row per activity type
    
    Dependencies: {{ source('pipedrive', 'activity_types') }}
*/

with source as (

    select
        id,
        name,
        active,
        type
    from {{ source('pipedrive', 'activity_types') }}

),

renamed as (

    select
        id as activity_type_id,
        type as activity_type_code,
        name as activity_type_name,
        active as is_active,
        
        -- Audit metadata
        current_timestamp as _loaded_at,
        '{{ invocation_id }}' as _dbt_run_id
        
    from source

)

select * from renamed