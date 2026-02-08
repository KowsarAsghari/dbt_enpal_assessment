{{
    config(
        materialized='view',
        tags=['mart', 'report']
    )
}}

/*
    Lost reason analysis with labels from fields table.
*/

WITH lost_deals AS (
    SELECT 
        deal_id,
        new_value::integer as lost_reason_code,
        change_time::timestamp as lost_at,
        change_time::date as lost_date
    FROM {{ source('pipedrive', 'deal_changes') }}
    WHERE changed_field_key = 'lost_reason'
),

-- Parse JSON from fields table
reason_labels AS (
    SELECT 
        jsonb_array_elements(field_value_options::jsonb) ->> 'id' as reason_code,
        jsonb_array_elements(field_value_options::jsonb) ->> 'label' as reason_label
    FROM {{ source('pipedrive', 'fields') }}
    WHERE field_key = 'lost_reason'
),

reason_arrays AS (
    SELECT 
        lost_reason_code,
        array_agg(deal_id ORDER BY lost_at) as deal_ids,
        array_agg(lost_at ORDER BY lost_at) as lost_times,
        array_agg(lost_date ORDER BY lost_at) as lost_dates
    FROM lost_deals
    GROUP BY lost_reason_code
)

SELECT 
    ra.lost_reason_code,
    rl.reason_label,
    ra.deal_ids,
    ra.lost_times,
    ra.lost_dates,
    array_length(ra.deal_ids, 1) as total_deals_lost
FROM reason_arrays ra
LEFT JOIN reason_labels rl 
    ON ra.lost_reason_code::text = rl.reason_code
ORDER BY total_deals_lost DESC