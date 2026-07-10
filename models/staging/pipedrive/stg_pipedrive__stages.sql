{{
    config(
        materialized='table',
        schema='staging',
        unique_key='stage_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

-- Stage reference built from BOTH sources of truth:
--   1. the `stages` table, and
--   2. the stage_id option list nested in the `fields` metadata JSON.
-- Unioned and deduplicated on stage_id, preferring the fields option label
-- (canonical casing, e.g. "Qualified Lead" vs the stages table's "Qualified lead").

with stages_table as (

    select
        stage_id,
        trim(stage_name) as stage_name,
        2                as _label_priority   -- lower priority wins in dedupe
    from {{ source('pipedrive', 'stages') }}

),

fields_source as (

    select field_value_options
    from {{ source('pipedrive', 'fields') }}
    where field_key = 'stage_id'

),

-- Unnest the stage options embedded in the fields metadata JSON.
stages_from_fields as (

    select
        cast(option ->> 'id' as integer) as stage_id,
        option ->> 'label'               as stage_name,
        1                                as _label_priority
    from fields_source,
         jsonb_array_elements(field_value_options) as option

),

unioned as (

    select * from stages_table
    union all
    select * from stages_from_fields

),

-- One row per stage_id; the fields label (priority 1) wins over the table label.
deduplicated as (

    {{ dbt_utils.deduplicate(
        relation='unioned',
        partition_by='stage_id',
        order_by='_label_priority asc'
    ) }}

)

select
    stage_id,
    stage_name
from deduplicated
