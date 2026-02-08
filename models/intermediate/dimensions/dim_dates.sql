{{
    config(
        materialized='table',
        tags=['intermediate', 'dimension']
    )
}}

/*
    Date dimension (spine) for time intelligence.
    
    Generates complete date range from first to last event.
    Adds calendar attributes for filtering and grouping.
    
    Grain: One row per calendar date
*/

WITH date_range AS (
    SELECT
        MIN(stage_change_date) as min_date,
        MAX(stage_change_date) as max_date
    FROM {{ ref('stg_pipedrive__deal_changes') }}
),

date_spine AS (
    SELECT
        generate_series(
            (SELECT min_date FROM date_range),
            (SELECT max_date FROM date_range),
            '1 day'::interval
        )::date as date_day
),

final AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['date_day']) }} as date_key,
        
        -- Date
        date_day,
        
        -- Calendar attributes
        EXTRACT(year FROM date_day) as year,
        EXTRACT(quarter FROM date_day) as quarter,
        EXTRACT(month FROM date_day) as month,
        EXTRACT(week FROM date_day) as week,
        EXTRACT(dow FROM date_day) as day_of_week,
        TO_CHAR(date_day, 'Month') as month_name,
        TO_CHAR(date_day, 'Day') as day_name,
        
        -- Business attributes
        CASE WHEN EXTRACT(dow FROM date_day) IN (0, 6) THEN true ELSE false END as is_weekend,
        DATE_TRUNC('month', date_day)::date as first_day_of_month,
        DATE_TRUNC('quarter', date_day)::date as first_day_of_quarter,
        DATE_TRUNC('year', date_day)::date as first_day_of_year
        
    FROM date_spine
)

SELECT * FROM final