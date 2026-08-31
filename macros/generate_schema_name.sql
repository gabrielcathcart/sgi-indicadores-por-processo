{#
    Usa o schema custom "as-is" (sem prefixo do schema alvo do profile).

    Padrão do dbt: custom_schema -> "<target_schema>_<custom_schema>".
    Num banco DuckDB local de um único usuário isso só polui os nomes
    (main_staging, main_marts, ...). Aqui os modelos ficam em schemas
    limpos — raw, seeds, staging, intermediate, marts, analytics —
    o que também simplifica o cadastro dos datasets no Superset.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
