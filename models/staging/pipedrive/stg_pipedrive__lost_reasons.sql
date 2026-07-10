{{
    config(
        materialized='table',
        schema='staging',
        unique_key='lost_reason_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

-- The lost_reason codes stored in deal_changes have no dedicated reference
-- table; their only decode is the JSON option list on the `lost_reason` field
-- in `fields`. Unnest it into a tidy lookup.
with source as (

    select * from {{ source('pipedrive', 'fields') }}

),

lost_reason_field as (

    select field_value_options
    from source
    where field_key = 'lost_reason'

),

unnested as (

    select
        cast(option ->> 'id' as integer) as lost_reason_id,
        option ->> 'label'               as lost_reason_name
    from lost_reason_field,
         jsonb_array_elements(field_value_options) as option

),

deduplicated as (

    {{ dbt_utils.deduplicate(
        relation='unnested',
        partition_by='lost_reason_id',
        order_by='lost_reason_name'
    ) }}

)

select * from deduplicated
