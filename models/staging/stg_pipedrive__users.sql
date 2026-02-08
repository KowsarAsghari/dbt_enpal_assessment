{{
    config(
        materialized='table',
        tags=['staging', 'dimension', 'daily']
    )
}}

/*
    Staging model for sales team users.
    
    Purpose:
        Clean user dimension table.
        Currently Type 1 SCD (latest values only).
        Architecture supports future Type 2 implementation if needed.
    
    Transformations:
        1. Rename columns for consistency
        2. Add metadata for change tracking
    
    SCD Consideration:
        Current: Type 1 (overwrite on change)
        Future: modified timestamp enables Type 2 implementation
    
    Data Quality:
        - 1,787 users
        - All users have unique IDs
    
    Performance:
        - Small dimension (1,787 rows)
        - Frequently joined in analysis
    
    Grain: One row per user (current state)
    
    Dependencies: {{ source('pipedrive', 'users') }}
*/

with source as (

    select
        id,
        name,
        email,
        modified
    from {{ source('pipedrive', 'users') }}

),

renamed as (

    select
        id as user_id,
        name as user_name,
        email as user_email,
        modified::timestamp as last_modified_at,
        
        -- Flag test/internal users for exclusion from reports
        case
            when email ilike '%test%' then true
            when email ilike '%demo%' then true
            when email like '%@example.com' then true
            when email like '%@example.org' then true
            when email like '%@example.net' then true
            else false
        end as is_test_user,
        
        -- Audit metadata
        current_timestamp as _loaded_at,
        '{{ invocation_id }}' as _dbt_run_id
        
    from source

)

select * from renamed