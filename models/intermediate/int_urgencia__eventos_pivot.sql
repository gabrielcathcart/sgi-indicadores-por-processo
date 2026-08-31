-- Pivota o log de eventos para 1 linha por atendimento, um timestamp por tipo
-- de evento (o mais recente, se houver duplicidade). Usado para reconciliar a
-- jornada e para checar duplicidade de evento por (atendimento, tipo).

{% set tipos = [
    'retirada_senha','entrada_urgencia','inicio_triagem','fim_triagem','inicio_consulta',
    'abertura_evolucao','prescricao','solicitacao_imagem','realizacao_imagem','conduta',
    'solicitacao_internacao','finalizacao_aih','internacao_efetiva','desfecho'
] %}

with ev as (
    select * from {{ ref('stg_urgencia__eventos') }}
),

agrupado as (
    select
        atendimento_id,
        count(*)                                                as qt_eventos,
        count(*) filter (where flag_timestamp_estimado)         as qt_eventos_estimados
        {%- for t in tipos %}
        , max(case when tipo_evento = '{{ t }}' then dt_evento end) as ev_dt_{{ t }}
        , count(*) filter (where tipo_evento = '{{ t }}')          as qt_ev_{{ t }}
        {%- endfor %}
    from ev
    group by 1
)

select
    atendimento_id,
    qt_eventos,
    qt_eventos_estimados,
    {%- for t in tipos %}
    ev_dt_{{ t }},
    {%- endfor %}
    greatest(
        {%- for t in tipos %}
        qt_ev_{{ t }}{{ "," if not loop.last }}
        {%- endfor %}
    ) > 1 as flag_evento_duplicado
from agrupado
