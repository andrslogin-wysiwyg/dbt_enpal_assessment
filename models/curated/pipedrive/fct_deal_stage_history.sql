{{
    config(
        materialized='table',
        schema='curated',
        unique_key='deal_stage_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with
-- Imports
stage_history as (

    select * 

    from {{ ref('int_deal_stage_history') }}
),

deal_owners as (

    select * 

    from {{ ref('int_deal_assigned_user') }}
),

deal_lifecycle as (

    select * 

    from {{ ref('int_deal_lifecycle') }}
),

final as (

    select
        -- grain
        stage_history.deal_stage_id,
        stage_history.deal_id,

        -- stage
        stage_history.stage_id,
        stage_history.stage_name,
        stage_history.valid_from_timestamp,
        stage_history.valid_to_timestamp,
        stage_history.is_current_stage,

        -- measures
        case
            when stage_history.is_current_stage then null
            else round(extract(epoch from (
                stage_history.valid_to_timestamp - stage_history.valid_from_timestamp
            )))::bigint
        end                                                     as stage_duration_seconds,
        cast(date_trunc('month', stage_history.valid_from_timestamp) as date)
                                                                as stage_entered_month,

        -- owner at stage entry (one owner per stage row; see docs)
        deal_owners.user_id,
        deal_owners.user_name,
        deal_owners.user_email,

        -- deal-level lifecycle context (denormalised onto every stage row)
        deal_lifecycle.deal_creation_timestamp,
        deal_lifecycle.deal_lost_timestamp,
        deal_lifecycle.lost_reason_id,
        deal_lifecycle.lost_reason_name,
        (deal_lifecycle.deal_lost_timestamp
            between stage_history.valid_from_timestamp
                and stage_history.valid_to_timestamp)           as is_deal_lost_in_stage

    from 
        stage_history

    -- Owner active at the moment the deal entered this stage.
    left join 
        deal_owners
        on  
            deal_owners.deal_id = stage_history.deal_id
        and stage_history.valid_from_timestamp
                between deal_owners.valid_from_timestamp
                    and deal_owners.valid_to_timestamp

    left join 
        deal_lifecycle
        on 
            deal_lifecycle.deal_id = stage_history.deal_id
)

select * from final
