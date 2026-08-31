-- ============================================================================
-- fct_urgencia_atendimentos  —  FATO PRINCIPAL do projeto.
-- Grao: EXATAMENTE 1 linha por atendimento_id.
-- Sem duplicacao por join: a reconciliacao com o log de eventos acontece nos
-- modelos intermediarios, ja no grao de atendimento.
--
-- Dataset CERTIFICADO para o Superset. As quatro abas (Entrada e Capacidade,
-- Perfil, Desfecho, Tempos de Processo) leem daqui, direto ou via analytics/.
-- ============================================================================

{% set inds = indicadores_tempo() %}

with epi as (
    select * from {{ ref('stg_urgencia__episodios') }}
),
tempos as (
    select * from {{ ref('int_urgencia__tempos') }}
),
retorno as (
    select * from {{ ref('int_urgencia__retorno_72h') }}
),
manch as (
    select * from {{ ref('dim_manchester') }}
),
metas_wide as (
    select
        {%- for nome, ini, fim, aplic in inds %}
        max(meta_demo_min) filter (where indicador = '{{ nome }}') as meta_{{ nome }}{{ "," if not loop.last }}
        {%- endfor %}
    from {{ ref('metas_demo') }}
)

select
    -- chaves ------------------------------------------------------------------
    e.atendimento_id,
    e.paciente_id_pseudonimo,

    -- calendario / entrada --------------------------------------------------
    e.data_referencia,
    e.dt_retirada_senha,
    e.dt_entrada,
    e.ano,
    e.mes,
    e.mes_referencia,
    e.semana_referencia,
    e.semana_iso,
    e.dia_semana_iso,
    e.dia_semana_nome,
    e.hora_retirada_senha,
    e.periodo_admissao,

    -- dimensoes -----------------------------------------------------------
    e.procedencia,
    e.sexo,
    e.idade_anos,
    e.classificacao_faixa_etaria,
    e.classificacao_manchester,
    e.manchester_ordem_criticidade,
    m.cor_hex                                              as manchester_cor_hex,
    e.desfecho_urgencia,
    e.especialidade_internacao,

    -- flags de negocio --------------------------------------------------
    e.possui_imagem,
    e.possui_internacao,
    (e.desfecho_urgencia = 'Internado')                   as flag_internado,
    (e.dt_realizacao_imagem is not null)                  as flag_imagem_realizada,

    -- timestamps do funil (auditaveis) --------------------------------
    e.dt_inicio_triagem, e.dt_fim_triagem, e.dt_inicio_consulta,
    e.dt_abertura_evolucao, e.dt_prescricao, e.dt_solicitacao_imagem,
    e.dt_realizacao_imagem, e.dt_conduta, e.dt_solicitacao_internacao,
    e.dt_finalizacao_aih, e.dt_internacao_efetiva, e.dt_desfecho,

    -- 7 indicadores de tempo (minutos; NULL quando nao aplicavel/ausente) ---
    {%- for nome, ini, fim, aplic in inds %}
    t.{{ nome }}_min,
    {%- endfor %}
    -- tempos-jornada auxiliares
    {{ diff_min('e.dt_entrada', 'e.dt_conduta') }}        as tempo_porta_conduta_min,
    {{ diff_min('e.dt_entrada', 'e.dt_desfecho') }}       as tempo_porta_desfecho_min,

    -- flags por indicador (elegibilidade / sequencia / outlier) ------------
    {%- for nome, ini, fim, aplic in inds %}
    t.flag_elegivel_{{ nome }},
    t.flag_sequencia_invalida_{{ nome }},
    t.flag_outlier_{{ nome }},
    (t.flag_elegivel_{{ nome }} and t.{{ nome }}_min > mw.meta_{{ nome }})
        as flag_acima_meta_demo_{{ nome }},
    {%- endfor %}

    -- outlier do tempo porta -> desfecho (cap operacional de sanidade) -----
    (
        {{ diff_min('e.dt_entrada', 'e.dt_desfecho') }} is not null
        and (
            {{ diff_min('e.dt_entrada', 'e.dt_desfecho') }} < 0
            or {{ diff_min('e.dt_entrada', 'e.dt_desfecho') }} > {{ var('outlier_los_max_min') }}
        )
    )                                                     as flag_outlier_tempo_porta_desfecho,

    -- flags de jornada / qualidade ---------------------------------------
    e.flag_dado_incompleto,
    t.flag_timestamp_incompleto,
    t.flag_jornada_temporal_invalida,
    t.flag_divergencia_eventos,
    t.flag_evento_duplicado,

    -- retorno em <=72h (COMPLEMENTAR — nao KPI principal) -----------------
    r.flag_retorno_72h,
    r.flag_indice_com_retorno_72h,
    r.horas_ate_retorno,
    r.horas_desde_episodio_anterior
from epi e
left join tempos  t on t.atendimento_id = e.atendimento_id
left join retorno r on r.atendimento_id = e.atendimento_id
left join manch   m on m.classificacao_manchester = e.classificacao_manchester
cross join metas_wide mw
