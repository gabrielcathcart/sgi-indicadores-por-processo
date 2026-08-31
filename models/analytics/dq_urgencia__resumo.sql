-- Relatorio de QUALIDADE DE DADOS — 1 linha por metrica, com contagem e % sobre
-- o total de atendimentos. Alimenta a secao de governanca do dashboard e o
-- script scripts/relatorio_qualidade.py.

with f as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
),
ev as (
    select count(*) n_eventos, count(*) filter (where flag_timestamp_estimado) n_estimados
    from {{ ref('stg_urgencia__eventos') }}
),
n as (select count(*) total from f),

m as (
    select 1 ordem, 'total_atendimentos'                    metrica, (select total from n)::bigint qt
    union all select  2, 'total_eventos',                   (select n_eventos from ev)
    union all select  3, 'eventos_timestamp_estimado',      (select n_estimados from ev)
    union all select  4, 'dado_incompleto (raw)',           (select count(*) filter (where flag_dado_incompleto) from f)
    union all select  5, 'timestamp_incompleto (mart)',     (select count(*) filter (where flag_timestamp_incompleto) from f)
    union all select  6, 'jornada_temporal_invalida',       (select count(*) filter (where flag_jornada_temporal_invalida) from f)
    union all select  7, 'divergencia_funil_x_eventos',     (select count(*) filter (where flag_divergencia_eventos) from f)
    union all select  8, 'evento_duplicado',                (select count(*) filter (where flag_evento_duplicado) from f)
    union all select  9, 'desfecho_nao_informado',          (select count(*) filter (where desfecho_urgencia = 'Nao informado/Em Atendimento') from f)
    union all select 10, 'internado',                       (select count(*) filter (where flag_internado) from f)
    union all select 11, 'imagem_realizada',                (select count(*) filter (where flag_imagem_realizada) from f)
    union all select 12, 'episodio_e_retorno_72h',          (select count(*) filter (where flag_retorno_72h) from f)
    union all select 13, 'sequencia_invalida (qualquer indicador)',
              (select count(*) filter (where
                  flag_sequencia_invalida_tempo_entrada_triagem or flag_sequencia_invalida_tempo_triagem
               or flag_sequencia_invalida_tempo_triagem_consulta or flag_sequencia_invalida_tempo_consulta
               or flag_sequencia_invalida_tempo_solicitacao_realizacao_imagem
               or flag_sequencia_invalida_tempo_reavaliacao
               or flag_sequencia_invalida_tempo_finalizacao_aih_internacao) from f)
    union all select 14, 'outlier (qualquer indicador)',
              (select count(*) filter (where
                  flag_outlier_tempo_entrada_triagem or flag_outlier_tempo_triagem
               or flag_outlier_tempo_triagem_consulta or flag_outlier_tempo_consulta
               or flag_outlier_tempo_solicitacao_realizacao_imagem or flag_outlier_tempo_reavaliacao
               or flag_outlier_tempo_finalizacao_aih_internacao) from f)
)

select
    m.ordem,
    m.metrica,
    m.qt,
    round(100.0 * m.qt / (select total from n), 2) as pct_do_total_atendimentos
from m
order by m.ordem
