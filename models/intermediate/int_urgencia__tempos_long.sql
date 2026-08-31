-- Formato LONGO dos 7 indicadores de tempo: 1 linha por (atendimento, indicador),
-- com o valor em minutos, as dimensoes analiticas e as flags por indicador.
-- Fonte unica dos modelos analytics de tempos (agg_urgencia__tempos,
-- __tempos_tendencia, __tempos_evento) -> evita logica duplicada.

{% set inds = indicadores_tempo() %}

with fct as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
)

{% for nome, ini, fim, aplic in inds %}
select
    atendimento_id,
    data_referencia,
    semana_referencia,
    mes_referencia,
    classificacao_manchester,
    manchester_ordem_criticidade,
    periodo_admissao,
    procedencia,
    especialidade_internacao,
    '{{ nome }}'                                   as indicador,
    {% if aplic == 'IMAGEM' %}'IMAGEM'{% elif aplic == 'INTERNACAO' %}'INTERNACAO'{% else %}'TODOS'{% endif %} as aplicabilidade,
    {{ loop.index }}                               as indicador_ordem,
    {{ nome }}_min                                 as valor_min,
    {% if aplic == 'IMAGEM' %}possui_imagem
    {%- elif aplic == 'INTERNACAO' %}flag_internado
    {%- else %}true{% endif %}                     as flag_aplicavel,
    flag_elegivel_{{ nome }}                       as flag_elegivel,
    flag_sequencia_invalida_{{ nome }}             as flag_sequencia_invalida,
    flag_outlier_{{ nome }}                        as flag_outlier,
    flag_acima_meta_demo_{{ nome }}               as flag_acima_meta_demo
from fct
{{ "union all" if not loop.last }}
{% endfor %}
