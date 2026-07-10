{{
    config(
        materialized='table',
        schema='intermediate',
        unique_key='deal_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with 
deal_changes as (

    select * 

    from {{ ref('stg_pipedrive__deal_changes') }}
),

lost_reasons as (

    select * 

    from {{ ref('stg_pipedrive__lost_reasons') }}
),

-- One creation timestamp per deal (earliest add_time if several exist).
created as (

    select
        deal_id,
        min(cast(new_value as timestamp)) as deal_creation_timestamp

    from 
        deal_changes

    where 
        changed_field_key = 'add_time'
    group by 
        deal_id
),

-- Latest lost_reason event per deal.
lost as (

    select distinct on (deal_id)
        deal_id                     as deal_id,
        changed_at_timestamp        as deal_lost_timestamp,
        cast(new_value as integer)  as lost_reason_id

    from 
        deal_changes
        
    where 
        changed_field_key = 'lost_reason'
        
    order by 
        deal_id, 
        changed_at_timestamp desc
),
final as (

    select
        created.deal_id,
        created.deal_creation_timestamp,
        lost.deal_lost_timestamp,
        lost.lost_reason_id,
        lost_reasons.lost_reason_name
    
    from 
        created
        
    left join 
        lost
        on created.deal_id = lost.deal_id
        
    left join 
        lost_reasons
        on lost.lost_reason_id = lost_reasons.lost_reason_id
)

select * from final