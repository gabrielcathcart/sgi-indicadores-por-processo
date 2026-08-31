-- Tempos de processo por atendimento + flags de validade/elegibilidade/outlier,
-- POR INDICADOR. Implementa, dentro do dbt, a logica de VSM (Value Stream
-- Mapping) do funil de urgencia.
--
-- Regras (docs/parametros.md, docs/data_quality.md):
--   * tempo em minutos inteiros; NULL quando um dos timestamps nao se aplica ou
--     esta ausente. NUNCA vira zero.
--   * duracao negativa e mantida no dado, mas sinalizada:
--     flag_sequencia_invalida_<ind> = (fim < inicio).
--   * flag_elegivel_<ind> = etapa aplicavel + os dois timestamps presentes +
--     sequencia valida.
--   * outlier configuravel (var outlier_metodo): "iqr" (Q3 + k*IQR sobre
--     registros elegiveis, por indicador) ou "meta" (> outlier_cap_mult x meta).

{% set inds = indicadores_tempo() %}

with epi as (
    select * from {{ ref('stg_urgencia__episodios') }}
),
piv as (
    select * from {{ ref('int_urgencia__eventos_pivot') }}
),
metas_wide as (
    select
        {%- for nome, ini, fim, aplic in inds %}
        max(meta_demo_min) filter (where indicador = '{{ nome }}') as meta_{{ nome }}{{ "," if not loop.last }}
        {%- endfor %}
    from {{ ref('metas_demo') }}
),

calc as (
    select
        e.atendimento_id,
        e.possui_imagem,
        e.possui_internacao,
        e.desfecho_urgencia,
        e.flag_dado_incompleto,

        {%- for nome, ini, fim, aplic in inds %}
        {{ diff_min('e.' ~ ini, 'e.' ~ fim) }}                        as {{ nome }}_min,
        (e.{{ ini }} is not null and e.{{ fim }} is not null and e.{{ fim }} < e.{{ ini }})
                                                                     as flag_sequencia_invalida_{{ nome }},
        {% if aplic == 'IMAGEM' %}e.possui_imagem
        {%- elif aplic == 'INTERNACAO' %}(e.desfecho_urgencia = 'Internado')
        {%- else %}true{% endif %}                                    as aplic_{{ nome }},
        {%- endfor %}

        -- jornada temporal completa: monotonicidade dos marcos PRESENTES
        (
            coalesce(e.dt_entrada              >= e.dt_retirada_senha,     true)
        and coalesce(e.dt_inicio_triagem       >= e.dt_entrada,            true)
        and coalesce(e.dt_fim_triagem          >= e.dt_inicio_triagem,     true)
        and coalesce(e.dt_inicio_consulta      >= e.dt_fim_triagem,        true)
        and coalesce(e.dt_abertura_evolucao    >= e.dt_inicio_consulta,    true)
        and coalesce(e.dt_prescricao           >= e.dt_abertura_evolucao,  true)
        and coalesce(e.dt_solicitacao_imagem   >= e.dt_prescricao,         true)
        and coalesce(e.dt_realizacao_imagem    >= e.dt_solicitacao_imagem, true)
        and coalesce(e.dt_conduta              >= e.dt_prescricao,         true)
        and coalesce(e.dt_solicitacao_internacao >= e.dt_conduta,          true)
        and coalesce(e.dt_finalizacao_aih      >= e.dt_solicitacao_internacao, true)
        and coalesce(e.dt_internacao_efetiva   >= e.dt_finalizacao_aih,    true)
        and coalesce(e.dt_desfecho             >= e.dt_conduta,            true)
        ) = false                                                    as flag_jornada_temporal_invalida,

        (
            e.flag_dado_incompleto
            or (
                e.desfecho_urgencia not in ('Evasao', 'Nao informado/Em Atendimento')
                and (
                    e.dt_inicio_triagem is null or e.dt_fim_triagem is null
                    or e.dt_inicio_consulta is null or e.dt_abertura_evolucao is null
                    or e.dt_prescricao is null
                )
            )
        )                                                            as flag_timestamp_incompleto,

        (
            coalesce(abs(date_diff('minute', e.dt_inicio_consulta,  p.ev_dt_inicio_consulta))  > 2, false)
         or coalesce(abs(date_diff('minute', e.dt_fim_triagem,      p.ev_dt_fim_triagem))      > 2, false)
         or coalesce(abs(date_diff('minute', e.dt_realizacao_imagem, p.ev_dt_realizacao_imagem)) > 2, false)
        )                                                            as flag_divergencia_eventos,
        coalesce(p.flag_evento_duplicado, false)                     as flag_evento_duplicado
    from epi e
    left join piv p using (atendimento_id)
),

elig as (
    select
        *,
        {%- for nome, ini, fim, aplic in inds %}
        (aplic_{{ nome }} and {{ nome }}_min is not null and not flag_sequencia_invalida_{{ nome }})
            as flag_elegivel_{{ nome }}{{ "," if not loop.last }}
        {%- endfor %}
    from calc
),

fences as (
    select
        {%- for nome, ini, fim, aplic in inds %}
        quantile_cont({{ nome }}_min, 0.75) filter (where flag_elegivel_{{ nome }})
          + {{ var('outlier_iqr_k') }} * (
              quantile_cont({{ nome }}_min, 0.75) filter (where flag_elegivel_{{ nome }})
            - quantile_cont({{ nome }}_min, 0.25) filter (where flag_elegivel_{{ nome }})
          ) as fence_{{ nome }}{{ "," if not loop.last }}
        {%- endfor %}
    from elig
)

select
    e.*,
    {%- for nome, ini, fim, aplic in inds %}
    (
        e.flag_elegivel_{{ nome }}
        and (
            e.{{ nome }}_min < 0
        {%- if var('outlier_metodo') == 'meta' %}
            or e.{{ nome }}_min > {{ var('outlier_cap_mult') }} * coalesce(mw.meta_{{ nome }}, 1000000)
        {%- else %}
            or e.{{ nome }}_min > f.fence_{{ nome }}
        {%- endif %}
        )
    ) as flag_outlier_{{ nome }}{{ "," if not loop.last }}
    {%- endfor %}
from elig e
cross join fences f
cross join metas_wide mw
