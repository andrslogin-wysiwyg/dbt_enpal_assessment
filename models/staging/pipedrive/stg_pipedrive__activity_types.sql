{{
    config(
        materialized='table',
        schema='staging',
        unique_key='activity_type_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with source as (

    select * from {{ source('pipedrive', 'activity_types') }}

),

deduplicated as (

    -- optional - placeholder if complexity of the table increases

    {{ dbt_utils.deduplicate(
        relation='source',
        partition_by='id',
        order_by='id'
    ) }}

)

select
    id                as activity_type_id,
    type              as activity_type_code,   -- join key to activity.type
    name              as activity_type_name,
    case
        when lower(active) = 'yes' then true
        when lower(active) = 'no'  then false
    end               as is_active
from deduplicated
