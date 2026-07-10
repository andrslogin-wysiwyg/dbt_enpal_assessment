{{
    config(
        materialized='table',
        schema='staging',
        unique_key='activity_id',
        persist_docs={'relation': true, 'columns': true},
        indexes=[
            {'columns': ['activity_id'], 'unique': true},
            {'columns': ['deal_id'], 'type': 'btree'},
            {'columns': ['user_id'], 'type': 'btree'},
        ],
    )
}}

with source as (

    select * from {{ source('pipedrive', 'activity') }}

),

-- `activity_id` has duplicate values in source; keep the latest by due_to.
deduplicated as (

    {{ dbt_utils.deduplicate(
        relation='source',
        partition_by='activity_id',
        order_by='due_to desc'
    ) }}

)

select
    activity_id,
    type                       as activity_type_code,
    assigned_to_user           as user_id,
    deal_id                    as deal_id,
    done                       as is_done,
    cast(due_to as timestamp)  as due_at_timestamp
from deduplicated
