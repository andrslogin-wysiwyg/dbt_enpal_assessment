{{
    config(
        materialized='table',
        schema='curated',
        unique_key='activity_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with
-- Imports
activities as (

    select * from {{ ref('stg_pipedrive__activities') }}

),

activity_types as (

    select * from {{ ref('stg_pipedrive__activity_types') }}

),

users as (

    select * from {{ ref('stg_pipedrive__users') }}

),

final as (

    select
        -- grain
        activities.activity_id,

        -- type
        activities.activity_type_code,
        activity_types.activity_type_name,
        activity_types.is_active                                    as is_active_activity_type,

        -- assigned user
        activities.user_id,
        users.user_name,
        users.user_email,

        -- activity attributes
        activities.deal_id,
        activities.is_done,
        activities.due_at_timestamp,
        cast(date_trunc('month', activities.due_at_timestamp) as date) as activity_due_month

    from activities

    left join activity_types
        on activities.activity_type_code = activity_types.activity_type_code

    left join users
        on activities.user_id = users.user_id

)

select * from final
