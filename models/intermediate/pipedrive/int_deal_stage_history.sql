{{
    config(
        materialized='table',
        schema='intermediate',
        unique_key='deal_stage_id',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with deal_changes as (

    select * from {{ ref('stg_pipedrive__deal_changes') }}

),

-- Stage intervals: each stage_id event is valid until the next one for the deal.
stage_events as (

    select
        deal_id,
        cast(new_value as integer)  as stage_id,
        changed_at_timestamp        as valid_from_timestamp,
        lead(changed_at_timestamp) over (
            partition by deal_id
            order by changed_at_timestamp, deal_change_id
        )                           as next_changed_at_timestamp
    from deal_changes
    where changed_field_key = 'stage_id'

),

stages as (

    select * from {{ ref('stg_pipedrive__stages') }}

)

select
    {{ dbt_utils.generate_surrogate_key([
        'stage_events.deal_id',
        'stage_events.valid_from_timestamp',
        'stage_events.stage_id'
    ]) }}                                       as deal_stage_id,
    stage_events.deal_id,
    stage_events.stage_id,
    stages.stage_name,
    stage_events.valid_from_timestamp,
    -- Inclusive interval end: 1ms before the next event so ranges never overlap
    -- (BETWEEN-safe); open/current records default to a far-future sentinel.
    coalesce(
        stage_events.next_changed_at_timestamp - interval '1 millisecond',
        timestamp '9999-12-31 23:59:59'
    )                                           as valid_to_timestamp,
    (stage_events.next_changed_at_timestamp is null) as is_current_stage
from stage_events
left join stages
    on stage_events.stage_id = stages.stage_id
