{{
    config(
        materialized='table',
        schema='staging',
        unique_key='user_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with source as (

    select * from {{ source('pipedrive', 'users') }}

),

deduplicated as (

    {{ dbt_utils.deduplicate(
        relation='source',
        partition_by='id',
        order_by='modified desc'
    ) }}

)

select
    id                          as user_id,
    name                        as user_name,
    email                       as user_email,
    cast(modified as timestamp) as modified_at
from deduplicated
