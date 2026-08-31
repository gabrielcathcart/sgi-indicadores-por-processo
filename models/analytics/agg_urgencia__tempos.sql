-- Aba 4 (Tempos de Processo / VSM). Grao: indicador x classificacao_manchester
-- (+ linha 'Todos'). Leitura priorizada: n_elegivel, cobertura_pct, mediana,
-- P75, P90, P95. "% acima do valor de referencia" e visao COMPLEMENTAR.
-- Os valores de referencia sao de SIMULACAO -- nao sao SLA/protocolo/meta
-- institucional (docs/parametros.md). As colunas meta_demo_min /
-- qt_acima_meta_demo / pct_acima_meta_demo mantem o nome atual; a renomeacao
-- para "referencia_demo" depende de arquivos fora do escopo desta etapa.

with base as (
    select
        l.indicador,
        l.indicador_ordem,
        l.aplicabilidade,
        l.classificacao_manchester,
        l.manchester_ordem_criticidade,
        l.valor_min,
        l.flag_aplicavel,
        l.flag_elegivel,
        l.flag_sequencia_invalida,
        l.flag_outlier,
        l.flag_acima_meta_demo,
        m.meta_demo_min
    from {{ ref('int_urgencia__tempos_long') }} l
    left join {{ ref('metas_demo') }} m on m.indicador = l.indicador
)

select
    indicador,
    indicador_ordem,
    any_value(aplicabilidade)                                      as aplicabilidade,
    case any_value(aplicabilidade)
        when 'IMAGEM'     then 'Aplicavel apenas a atendimentos com exame de imagem'
        when 'INTERNACAO' then 'Aplicavel apenas a atendimentos com desfecho Internado'
        else 'Aplicavel a todos os atendimentos'
    end                                                            as obs_elegibilidade,
    coalesce(classificacao_manchester, 'Todos')                    as classificacao_manchester,
    coalesce(manchester_ordem_criticidade, 0)                      as manchester_ordem_criticidade,

    count(*) filter (where flag_aplicavel)                         as n_aplicavel,
    count(*) filter (where flag_elegivel)                          as n_elegivel,
    round(100.0 * count(*) filter (where flag_elegivel)
          / nullif(count(*) filter (where flag_aplicavel), 0), 1)  as cobertura_pct,
    count(*) filter (where flag_sequencia_invalida)               as qt_sequencia_invalida,

    round(median(valor_min) filter (where flag_elegivel), 1)                   as mediana_min,
    round(quantile_cont(valor_min, 0.75) filter (where flag_elegivel), 1)      as p75_min,
    round(quantile_cont(valor_min, 0.90) filter (where flag_elegivel), 1)      as p90_min,
    round(quantile_cont(valor_min, 0.95) filter (where flag_elegivel), 1)      as p95_min,
    round(avg(valor_min) filter (where flag_elegivel), 1)                      as media_min,
    min(valor_min) filter (where flag_elegivel)                                as min_min,
    max(valor_min) filter (where flag_elegivel)                                as max_min,

    count(*) filter (where flag_outlier)                                       as qt_outlier,
    round(100.0 * count(*) filter (where flag_outlier)
          / nullif(count(*) filter (where flag_elegivel), 0), 1)               as pct_outlier,
    round(median(valor_min) filter (where flag_elegivel and not flag_outlier), 1) as mediana_sem_outlier_min,

    max(meta_demo_min)                                                        as meta_demo_min,
    count(*) filter (where flag_acima_meta_demo)                              as qt_acima_meta_demo,
    round(100.0 * count(*) filter (where flag_acima_meta_demo)
          / nullif(count(*) filter (where flag_elegivel), 0), 1)             as pct_acima_meta_demo
from base
group by grouping sets (
    (indicador, indicador_ordem),
    (indicador, indicador_ordem, classificacao_manchester, manchester_ordem_criticidade)
)
