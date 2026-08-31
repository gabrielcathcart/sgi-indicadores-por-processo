-- Staging do fato de episodios de urgencia.
-- Padroniza tipos, converte timestamps, normaliza categorias e deriva os campos
-- de calendario a partir do timestamp da retirada de senha. NAO aplica regra de
-- negocio de indicador (isso e do mart). Mantem os campos brutos para auditoria.

with fonte as (
    select * from {{ ref('urgencia_episodios_raw') }}
),

tipado as (
    select
        atendimento_id,
        trim(paciente_id_pseudonimo)                       as paciente_id_pseudonimo,

        cast(dt_retirada_senha        as timestamp)        as dt_retirada_senha,
        cast(dt_entrada               as timestamp)        as dt_entrada,
        cast(dt_inicio_triagem        as timestamp)        as dt_inicio_triagem,
        cast(dt_fim_triagem           as timestamp)        as dt_fim_triagem,
        cast(dt_inicio_consulta       as timestamp)        as dt_inicio_consulta,
        cast(dt_abertura_evolucao     as timestamp)        as dt_abertura_evolucao,
        cast(dt_prescricao            as timestamp)        as dt_prescricao,
        cast(dt_solicitacao_imagem    as timestamp)        as dt_solicitacao_imagem,
        cast(dt_realizacao_imagem     as timestamp)        as dt_realizacao_imagem,
        cast(dt_conduta               as timestamp)        as dt_conduta,
        cast(dt_solicitacao_internacao as timestamp)       as dt_solicitacao_internacao,
        cast(dt_finalizacao_aih       as timestamp)        as dt_finalizacao_aih,
        cast(dt_internacao_efetiva    as timestamp)        as dt_internacao_efetiva,
        cast(dt_desfecho              as timestamp)        as dt_desfecho,

        trim(periodo_admissao)                             as periodo_admissao,
        trim(procedencia)                                  as procedencia,
        trim(sexo)                                         as sexo,
        cast(idade_anos as integer)                        as idade_anos,
        trim(classificacao_faixa_etaria)                   as classificacao_faixa_etaria_raw,
        trim(classificacao_manchester)                     as classificacao_manchester,
        cast(manchester_ordem_criticidade as integer)      as manchester_ordem_criticidade,
        trim(desfecho_urgencia)                            as desfecho_urgencia,
        nullif(trim(especialidade_internacao), '')         as especialidade_internacao,
        cast(possui_imagem       as boolean)               as possui_imagem,
        cast(possui_internacao   as boolean)               as possui_internacao,
        cast(flag_dado_incompleto as boolean)              as flag_dado_incompleto
    from fonte
),

derivado as (
    select
        *,
        {{ faixa_etaria('idade_anos') }}                             as classificacao_faixa_etaria,
        cast(dt_retirada_senha as date)                              as data_referencia,
        extract('hour'   from dt_retirada_senha)::int                as hora_retirada_senha,
        extract('isodow' from dt_retirada_senha)::int                as dia_semana_iso,
        {{ dia_semana_nome("extract('isodow' from dt_retirada_senha)::int") }} as dia_semana_nome,
        extract('year'  from dt_retirada_senha)::int                 as ano,
        extract('month' from dt_retirada_senha)::int                 as mes,
        date_trunc('month', dt_retirada_senha)::date                 as mes_referencia,
        date_trunc('week',  dt_retirada_senha)::date                 as semana_referencia,
        extract('week'  from dt_retirada_senha)::int                 as semana_iso
    from tipado
)

select * from derivado
