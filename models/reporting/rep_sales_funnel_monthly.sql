{{
    config(
        materialized='table',
        schema='reporting',
        persist_docs={'relation': true, 'columns': true},
    )
}}

with
-- Imports
deal_stage_history as (

    select * 

    from {{ ref('fct_deal_stage_history') }}
),

activities as (

    select *

    from {{ ref('fct_activities') }}
),

funnel_step_mapping as (

    select *

    from {{ ref('seed_activity_type_funnel_step') }}
),

-- Steps 1-9: distinct deals that entered each pipeline stage in the month.
stage_steps as (

    select
        stage_entered_month          as month,
        stage_name                   as kpi_name,
        cast(stage_id as varchar)    as funnel_step,
        count(distinct deal_id)      as deals_count
    from 
        deal_stage_history
    group by 
        1, 2, 3

),

-- Activity sub-steps: counted as activities (not deals) — activity.deal_id does not
-- reliably link to deals in this export. The activity-type -> funnel-step mapping is
-- declarative (seed) so nothing is silently dropped; only in-scope steps (the
-- assignment's 2.1 / 3.1) are emitted. Completed calls only (is_done), to mirror the
-- "actually happened" semantics of the stage steps.
activity_steps as (

    select
        activities.activity_due_month       as month,
        mapping.kpi_name                    as kpi_name,
        mapping.funnel_step                 as funnel_step,
        count(*)                            as deals_count
    from activities
    inner join funnel_step_mapping as mapping
        on activities.activity_type_code = mapping.activity_type_code
    where mapping.include_in_funnel_report
      and activities.is_done
    group by 1, 2, 3

)

select month, kpi_name, funnel_step, deals_count from stage_steps
union all
select month, kpi_name, funnel_step, deals_count from activity_steps
