{# Reusable doc blocks for the Pipedrive staging layer.
   Reference from any model/source yml with: description: '{{ doc("pd_deal_id") }}' #}

{% docs pd_deal_id %}
Identifier of the Pipedrive **deal** the row relates to. Note: `deal_id` is a random
6-digit value and is **not guaranteed unique per deal lifecycle** in this export — a
small number of ids collide across two distinct deals (see docs/data_understanding.md).
{% enddocs %}

{% docs pd_deal_change_id %}
Surrogate key of a single deal change event, hashed from
(`deal_id`, `changed_at`, `changed_field_key`, `new_value`). Unique per event.
{% enddocs %}

{% docs pd_changed_field_key %}
Which deal field changed. Only four Pipedrive standard fields are tracked in this
export: `add_time`, `user_id`, `stage_id`, `lost_reason`.
{% enddocs %}

{% docs pd_new_value %}
New value of the changed field, stored as **text** because its type is polymorphic
(timestamp for `add_time`, user id for `user_id`, stage code for `stage_id`,
lost-reason code for `lost_reason`). Cast per field in the intermediate layer.
{% enddocs %}

{% docs pd_changed_at_timestamp %}
Timestamp at which the change was recorded in Pipedrive (timezone-naive).
{% enddocs %}

{% docs pd_activity_id %}
Unique identifier of a Pipedrive **activity** (call, meeting, follow-up).
{% enddocs %}

{% docs pd_activity_type_code %}
Activity type code — the join key to `activity_types` (e.g. `meeting`, `sc_2`,
`follow_up`, `after_close_call`).
{% enddocs %}

{% docs pd_activity_deal_id %}
Deal the activity is linked to. ⚠️ In this export only 8 of these match a deal in
`deal_changes`; activities are effectively **not joinable** to deals. Do not inner-join.
{% enddocs %}

{% docs pd_user_id %}
Pipedrive **user** (sales rep). Owner of a deal, or assignee of an activity.
{% enddocs %}

{% docs pd_is_done %}
Whether the activity has been completed.
{% enddocs %}

{% docs due_at_timestamp %}
When the activity is/was due. This is a **due date**, not an ingestion/modification
timestamp — do not use it as an incremental watermark.
{% enddocs %}

{% docs pd_stage_id %}
Pipeline stage id (1-9). Maps to the sales funnel steps Lead Generation … Renewal.
{% enddocs %}

{% docs pd_stage_name %}
Human-readable stage name. Kept faithful to source; canonical label standardisation
happens in the dim layer.
{% enddocs %}

{% docs pd_activity_type_id %}
Surrogate/primary id of the activity type.
{% enddocs %}

{% docs pd_activity_type_name %}
Display name of the activity type (e.g. "Sales Call 1", "Sales Call 2").
{% enddocs %}

{% docs pd_is_active %}
Whether the activity type is currently active in Pipedrive (derived from the source
Yes/No flag).
{% enddocs %}

{% docs pd_user_name %}
Full name of the user.
{% enddocs %}

{% docs pd_user_email %}
Email of the user. Note: 4 emails are duplicated across distinct user ids.
{% enddocs %}

{% docs pd_modified_at %}
Timestamp the user record was last modified.
{% enddocs %}

{% docs pd_lost_reason_id %}
Lost-reason code (1-5). Decoded from the `lost_reason` field option list in `fields`.
{% enddocs %}

{% docs pd_lost_reason_name %}
Human-readable lost reason (e.g. "Pricing Issues"). ⚠️ Present on every deal in this
export and therefore **not** a reliable signal that a deal was actually lost.
{% enddocs %}

{# ---------- model-level docs ---------- #}

{% docs stg_pipedrive__deal_changes %}
Cleaned Pipedrive deal changelog — one row per field-change event, deduplicated on the
natural key. This is the event stream from which the deal entity is reconstructed
downstream. `new_value` is polymorphic and kept as text.
{% enddocs %}

{% docs stg_pipedrive__activities %}
Cleaned Pipedrive activities, deduplicated to one row per `activity_id`. Activities are
not reliably joinable to deals in this export (see `activity_deal_id`).
{% enddocs %}

{% docs stg_pipedrive__stages %}
Pipeline stage reference (1-9), one row per stage. Built by unioning the `stages`
table with the stage_id option list nested in the `fields` metadata JSON, then
deduplicating on stage_id — preferring the fields option label for canonical casing.
{% enddocs %}

{% docs stg_pipedrive__activity_types %}
Activity type reference, one row per type, with an activity-type code used to join to
activities.
{% enddocs %}

{% docs stg_pipedrive__users %}
Pipedrive users (sales reps / deal owners), one row per user.
{% enddocs %}

{% docs stg_pipedrive__lost_reasons %}
Lost-reason reference, unnested from the `fields` JSON option list. The only decode
source for lost_reason codes.
{% enddocs %}

{# ---------- raw source docs ---------- #}

{% docs src_pipedrive__deal_changes %}
Raw Pipedrive Deal Changelog. One row per field-change event on a deal; only four
standard fields are tracked (add_time, user_id, stage_id, lost_reason). Append-only and
**not unique per deal** — deals are reconstructed from this table downstream.
{% enddocs %}

{% docs src_pipedrive__activity %}
Raw Pipedrive activities (calls, meetings, follow-ups). `activity_id` contains a few
duplicate values, and `deal_id` overlaps with deal_changes for only 8 rows, so
activities are effectively not joinable to deals in this export.
{% enddocs %}

{% docs src_pipedrive__stages %}
Raw pipeline stage reference (stage id 1-9 to display name).
{% enddocs %}

{% docs src_pipedrive__activity_types %}
Raw activity type reference. The `type` code (not `id`) is the join key to
activity.type.
{% enddocs %}

{% docs src_pipedrive__users %}
Raw Pipedrive users (sales reps / deal owners).
{% enddocs %}

{% docs src_pipedrive__fields %}
Raw Pipedrive field metadata. `field_value_options` (JSONB) holds the canonical option
labels and is the only decode source for lost_reason.
{% enddocs %}

{# ---------- intermediate column docs ---------- #}

{% docs pd_deal_creation_timestamp %}
When the deal was created, from the `add_time` change event (earliest if more than one
exists for a deal_id).
{% enddocs %}

{% docs pd_deal_lost_timestamp %}
When the deal's most recent `lost_reason` was recorded. ⚠️ Present for effectively every
deal in this export, so it is **not** a reliable indicator that a deal was genuinely lost.
{% enddocs %}

{% docs pd_valid_from_timestamp %}
Start of the validity interval for this record — the `changed_at` timestamp of the event
that opened it.
{% enddocs %}

{% docs pd_valid_to_timestamp %}
Inclusive end of the validity interval — the next event's timestamp for the same deal
minus 1 millisecond, so consecutive intervals never overlap and are safe to query with
BETWEEN. For the current (open) record this defaults to the sentinel 9999-12-31 23:59:59.
{% enddocs %}

{# ---------- surrogate keys & current-record flags ---------- #}

{% docs pd_field_id %}
Pipedrive field id — primary key of the field metadata table.
{% enddocs %}

{% docs pd_deal_assigned_user_id %}
Surrogate key of a deal ownership interval, hashed from (deal_id, valid_from_timestamp,
user_id). One per deal × owner interval.
{% enddocs %}

{% docs pd_deal_stage_id %}
Surrogate key of a deal stage interval, hashed from (deal_id, valid_from_timestamp,
stage_id). One per deal × stage interval — the grain of the stage history and the
deal-stage fact.
{% enddocs %}

{% docs pd_is_current_assignment %}
True when this is the deal's current owner — the open interval whose valid_to is the
far-future sentinel.
{% enddocs %}

{% docs pd_is_current_stage %}
True when this is the deal's current stage — the open interval whose valid_to is the
far-future sentinel.
{% enddocs %}

{# ---------- intermediate model docs ---------- #}

{% docs int_deal_lifecycle %}
One row per deal: creation timestamp (from add_time) plus the latest lost_reason
timestamp and its decoded reason. The per-deal spine for deal-level reporting.
{% enddocs %}

{% docs int_deal_assigned_user %}
Deal ownership history — one row per deal × owner interval, built from `user_id` change
events with a valid_from / valid_to window. Enriched with user attributes.
{% enddocs %}

{% docs int_deal_stage_history %}
Deal stage history — one row per deal × stage interval, built from `stage_id` change
events with a valid_from / valid_to window. Enriched with the stage name.
{% enddocs %}

{# ---------- marts column docs ---------- #}

{% docs pd_is_deal_lost_in_stage %}
True when the deal's `deal_lost_timestamp` falls within this stage interval — i.e. the
deal was recorded as lost while in this stage. Note: see the lost_reason caveat; this
export may contain only lost deals, or lost_reason may not be a genuine loss signal.
{% enddocs %}

{% docs pd_stage_duration_seconds %}
Seconds the deal spent in this stage (valid_to − valid_from). NULL for the current
(open) stage, where the interval end is the far-future sentinel.
{% enddocs %}

{% docs pd_stage_entered_month %}
Month the deal entered this stage (date_trunc of valid_from), as a date on the first of
the month. Precomputed so monthly funnel aggregation is a simple group-by.
{% enddocs %}

{# ---------- marts model docs ---------- #}

{% docs fct_deal_stage_history %}
Wide, presentation-grade deal-stage fact — one row per deal × stage interval, enriched
with the owner at stage entry, deal creation/loss context, and time-in-stage measures.
The reusable base that `rep_sales_funnel_monthly` and other stage KPIs aggregate from.
Activities are deliberately excluded (their deal_id does not reliably link to deals).
{% enddocs %}

{% docs fct_activities %}
Activity fact — one row per activity (call, meeting, follow-up), enriched with the
activity type, the assigned user, and the due month. The curated base for activity KPIs
and for the Sales Call steps in the sales funnel report. ⚠️ `deal_id` is retained but
does not reliably link to deals in this export (only 8 of 4,572 match), so activities
should not be attributed to deals.
{% enddocs %}

{% docs pd_activity_due_month %}
Month the activity is/was due (date_trunc of due_at_timestamp), as a date on the first
of the month. Precomputed for monthly activity aggregation.
{% enddocs %}

{# ---------- reporting docs ---------- #}

{% docs rep_sales_funnel_monthly %}
Monthly sales funnel, matching the assignment's requested structure: steps 1-9 plus the
Sales Call sub-steps 2.1 and 3.1. One row per (month, funnel step): how many clients
entered each step in that month. Steps 1-9 are pipeline stages (distinct deals that
entered the stage that month, from fct_deal_stage_history). Steps 2.1 / 3.1 are completed
Sales Call activities (is_done = true), mapped via the seed_activity_type_funnel_step
seed and filtered to the in-scope rows. ⚠️ Caveats: (1) stage entries are explicit
events, so deals that *skip* a stage are not counted in the skipped step; (2) activity
steps count activities, not deals — activities cannot be attributed to deals in this
export.
{% enddocs %}

{% docs seed_activity_type_funnel_step %}
Business mapping from Pipedrive activity type to sales-funnel sub-step. Maintained as a
seed so funnel membership is declarative and every activity type is mapped explicitly —
nothing is silently dropped. The assignment's funnel only defines Sales Call 1 (2.1) and
Sales Call 2 (3.1); After Close Call (7.1) and Follow Up Call (8.1) are mapped here to
document where they would fit, but flagged out of scope via include_in_funnel_report.
Consumed by rep_sales_funnel_monthly.
{% enddocs %}

{% docs pd_include_in_funnel_report %}
Whether this activity type is part of the assignment's requested funnel and therefore
emitted by rep_sales_funnel_monthly. TRUE for the specified Sales Call steps (2.1, 3.1);
FALSE for activity types mapped for completeness but outside the requested structure
(7.1 After Close Call, 8.1 Follow Up Call). Flip to TRUE to include them.
{% enddocs %}

{% docs pd_rep_month %}
Calendar month of the funnel event (first day of month), from the stage-entry month or
the activity due month.
{% enddocs %}

{% docs pd_rep_kpi_name %}
Human-readable name of the funnel step / KPI (e.g. "Lead Generation", "Sales Call 1").
{% enddocs %}

{% docs pd_rep_funnel_step %}
Funnel step identifier. The report emits '1'-'9' (pipeline stages) plus '2.1' Sales Call
1 and '3.1' Sales Call 2 (the assignment's requested structure). The mapping seed also
defines '7.1' After Close Call and '8.1' Follow Up Call for completeness, but they are
flagged out of scope and excluded from the report. Sorts lexically into funnel order.
{% enddocs %}

{% docs pd_rep_deals_count %}
Number of clients that entered the step in the month. For stage steps this is distinct
deals; for the Sales Call steps it is the count of activities (not deal-attributed —
see model description).
{% enddocs %}
