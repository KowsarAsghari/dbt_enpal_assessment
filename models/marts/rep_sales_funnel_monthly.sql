{{
    config(
        materialized='table',
        tags=['mart', 'report']
    )
}}

/*
    Monthly sales funnel report.
    Shows deal count entering each funnel step per month.
    
    Output columns: month, kpi_name, funnel_step, deals_count
*/

SELECT
    event_month as month,
    kpi_name,
    kpi_name as funnel_step,
    COUNT(DISTINCT deal_id) as deals_count

FROM {{ ref('int_funnel_events') }}
GROUP BY 1, 2, 3, funnel_order
ORDER BY 1, funnel_order