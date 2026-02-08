{{
    config(
        materialized='table',
        tags=['staging', 'daily']
    )
}}

/*
    Staging model for sales activities.
    
    Purpose:
        Clean activity transaction table and fix schema design issue.
        Converts VARCHAR foreign key (type) to INTEGER FK (activity_type_id).
    
    Data Quality Issue - Source Duplicates:
        Source contains perfect duplicates (9,158 rows → 4,579 unique).
        All columns identical across duplicates.
        Deduplication applied using SELECT DISTINCT before metadata addition.
    
    Schema Design Fix:
        Source uses VARCHAR FK: activity.type → activity_types.type
        We convert to INTEGER FK: activity_type_id → activity_types.id
        Performance improvement: Integer joins ~10x faster than string joins
    
    Transformations:
        1. DEDUPLICATE source data (remove perfect duplicates)
        2. Join activity_types ONCE to get activity_type_id (fix VARCHAR FK)
        3. Type cast timestamps and derive date fields
        4. DEDUPLICATE again after transformations (before metadata)
        5. Add metadata fields last
    
    Business Logic:
        Only completed activities (done=true) count toward funnel metrics.
        This filtering happens in intermediate layer, not here.
    
    Performance:
        - Deduplicate early (reduce data volume before JOIN)
        - Join activity_types once (avoid repeated string joins downstream)
        - Pre-compute date fields
        - Final row count: 4,579 unique activities
    
    Grain: One row per activity (deduplicated)
    
    Dependencies:
        - {{ source('pipedrive', 'activity') }}
        - {{ source('pipedrive', 'activity_types') }}
*/

with activity_source as (

    select
        activity_id,
        type,
        assigned_to_user,
        deal_id,
        done,
        due_to
    from {{ source('pipedrive', 'activity') }}

),

-- STEP 1: Deduplicate source data FIRST
deduplicated_source as (

    select distinct
        activity_id,
        type,
        assigned_to_user,
        deal_id,
        done,
        due_to
    from activity_source

),

activity_types_source as (

    select
        id as activity_type_id,
        type,
        name as activity_type_name
    from {{ source('pipedrive', 'activity_types') }}

),

-- STEP 2: Join to get INTEGER FK
joined as (

    select
        a.activity_id,
        a.deal_id,
        a.assigned_to_user as user_id,
        at.activity_type_id,
        a.type as activity_type_code,
        at.activity_type_name,
        a.done as is_completed,
        a.due_to
        
    from deduplicated_source a
    left join activity_types_source at
        on a.type = at.type

),

-- STEP 3: Type casting and derived fields
transformed as (

    select
        activity_id,
        deal_id,
        user_id,
        activity_type_id,
        activity_type_code,
        activity_type_name,
        is_completed,
        due_to::timestamp as activity_timestamp,
        due_to::date as activity_date,
        date_trunc('month', due_to)::date as activity_month,
        date_trunc('week', due_to)::date as activity_week,
        date_trunc('quarter', due_to)::date as activity_quarter,
        extract(year from due_to) as activity_year
        
    from joined

),

-- STEP 4: Final deduplication (in case JOIN or transformations created duplicates)
deduplicated_final as (

    select distinct * from transformed

),

-- STEP 5: Add metadata AFTER deduplication
final as (

    select
        *,
        current_timestamp as _loaded_at,
        '{{ invocation_id }}' as _dbt_run_id
        
    from deduplicated_final

)

select * from final