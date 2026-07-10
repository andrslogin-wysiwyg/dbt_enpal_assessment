{{
    config(
        materialized='table',
        schema='staging',
        unique_key='deal_change_id',
        persist_docs={'relation': true, 'columns': true},
        indexes=[
            {'columns': ['deal_change_id'], 'unique': true},
            {'columns': ['deal_id'], 'type': 'btree'},
            {'columns': ['changed_at_timestamp'], 'type': 'btree'},
        ],
    )
}}

with source as (

    select * from {{ source('pipedrive', 'deal_changes') }}

),

-- Dedupe on the natural key. dbt_utils.deduplicate compiles to a Postgres
-- DISTINCT ON (no QUALIFY on this adapter), an explicit, portable dedupe.
deduplicated as (

    {{ dbt_utils.deduplicate(
        relation='source',
        partition_by='deal_id, change_time, changed_field_key, new_value',
        order_by='change_time'
    ) }}

)

select
    {{ dbt_utils.generate_surrogate_key([
        'deal_id', 
        'change_time', 
        'changed_field_key', 
        'new_value'
    ]) }}                           as deal_change_id,
    deal_id                         as deal_id,
    changed_field_key               as changed_field_key,
    new_value                       as new_value,
    cast(change_time as timestamp)  as changed_at_timestamp
    
from deduplicated
