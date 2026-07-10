{#
    Use the custom schema name verbatim (no target-schema prefix).

    dbt's default prepends target.schema (here "public"), producing schema names
    like "public_staging". We want the layer schemas to be exactly the names set
    in each model's config: staging, intermediate, curated, reporting.

    Models without a custom schema fall back to target.schema.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
