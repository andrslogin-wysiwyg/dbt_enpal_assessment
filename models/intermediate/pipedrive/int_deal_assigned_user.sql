{{
    config(
        materialized='table',
        schema='intermediate',
        unique_key='deal_assigned_user_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with 
-- Imports
deal_changes as (

    select * 

    from {{ ref('stg_pipedrive__deal_changes') }}

),

users as (

    select * 

    from {{ ref('stg_pipedrive__users') }}

),

-- Ownership intervals: each user_id event is valid until the next one for the deal.
owner_events as (

    select
        
        deal_id,
        cast(new_value as integer)  as user_id,
        changed_at_timestamp        as valid_from_timestamp,
        lead(changed_at_timestamp) over (
            partition by 
                deal_id
            order by 
                changed_at_timestamp, 
                deal_change_id
        )                           as next_changed_at_timestamp

    from 
        deal_changes
        
    where 
        changed_field_key = 'user_id'

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'owner_events.deal_id',
            'owner_events.valid_from_timestamp',
            'owner_events.user_id'
        ]) }}                                            as deal_assigned_user_id,
        owner_events.deal_id                             as deal_id,
        owner_events.user_id                             as user_id,
        users.user_name                                  as user_name,
        users.user_email                                 as user_email,
        owner_events.valid_from_timestamp                as valid_from_timestamp,
        -- Inclusive interval end: 1ms before the next event so ranges never overlap
        -- (BETWEEN-safe); open/current records default to a far-future sentinel.
        coalesce(
            owner_events.next_changed_at_timestamp 
                - interval '1 millisecond',
            timestamp '9999-12-31 23:59:59')             as valid_to_timestamp,
        (owner_events.next_changed_at_timestamp is null) as is_current_assignment
    
    from 
        owner_events
        
    left join 
        users
        on owner_events.user_id = users.user_id
)

select * from final
