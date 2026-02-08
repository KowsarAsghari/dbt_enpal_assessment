{{
    config(
        materialized='table',
        tags=['intermediate', 'aggregate']
    )
}}

/*
    Combined funnel events (stage changes + sales calls).
    Bridge table for unified funnel analysis.
    Grain: One row per funnel event.
*/

WITH stage_events AS (
    SELECT
        deal_id,
        stage_change_date as event_date,
        stage_change_month as event_month,
        stage_change_year as event_year,
        'Step ' || s.stage_id || ': ' || s.stage_name as kpi_name,
        s.stage_id as funnel_order
    FROM {{ ref('fct_deal_stage_changes') }} f
    JOIN {{ ref('dim_stages') }} s ON f.stage_key = s.stage_key
),

activity_events AS (
    SELECT
        deal_id,
        activity_date as event_date,
        activity_month as event_month,
        activity_year as event_year,
        funnel_step as kpi_name,
        CASE 
            WHEN activity_type_code = 'meeting' THEN 2.1
            WHEN activity_type_code = 'sc_2' THEN 3.1
        END as funnel_order
    FROM {{ ref('fct_deal_activities') }}
)

SELECT * FROM stage_events
UNION ALL
SELECT * FROM activity_events