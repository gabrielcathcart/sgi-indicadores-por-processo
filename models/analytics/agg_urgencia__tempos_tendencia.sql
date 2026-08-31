-- Aba 4 (Tempos de Processo) - Visual B (Tendencia).
-- Grao: granularidade x periodo_ref x indicador x segmento x segmento_valor.
--   granularidade in ('Semana','Mes')
--   segmento in ('Geral','Periodo','Manchester','Procedencia','Especialidade')
-- 'Geral' = linha unica do indicador (sem segmentar). Os demais segmentos
-- permitem, no Superset, filtrar UMA dimensao por vez para preservar
-- legibilidade (ver docs/dashboard.md).
-- So episodios elegiveis entram nos percentis; a media NAO e exposta.

with l as (
    select * from {{ ref('int_urgencia__tempos_long') }}
),

grade as (
    -- (granularidade, periodo_ref) x (segmento, segmento_valor)
    select 'Semana' as granularidade, semana_referencia as periodo_ref,
           indicador, indicador_ordem, 'Geral' as segmento, 'Geral' as segmento_valor,
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Mes', mes_referencia, indicador, indicador_ordem, 'Geral', 'Geral',
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Semana', semana_referencia, indicador, indicador_ordem, 'Periodo', periodo_admissao,
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Mes', mes_referencia, indicador, indicador_ordem, 'Periodo', periodo_admissao,
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Semana', semana_referencia, indicador, indicador_ordem, 'Manchester', classificacao_manchester,
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Mes', mes_referencia, indicador, indicador_ordem, 'Manchester', classificacao_manchester,
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Semana', semana_referencia, indicador, indicador_ordem, 'Procedencia', procedencia,
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Mes', mes_referencia, indicador, indicador_ordem, 'Procedencia', procedencia,
           valor_min, flag_aplicavel, flag_elegivel from l
    union all
    select 'Semana', semana_referencia, indicador, indicador_ordem, 'Especialidade', especialidade_internacao,
           valor_min, flag_aplicavel, flag_elegivel from l where especialidade_internacao is not null
    union all
    select 'Mes', mes_referencia, indicador, indicador_ordem, 'Especialidade', especialidade_internacao,
           valor_min, flag_aplicavel, flag_elegivel from l where especialidade_internacao is not null
)

select
    granularidade,
    periodo_ref,
    indicador,
    indicador_ordem,
    segmento,
    segmento_valor,
    count(*) filter (where flag_aplicavel)                         as n_aplicavel,
    count(*) filter (where flag_elegivel)                          as n_elegivel,
    round(100.0 * count(*) filter (where flag_elegivel)
          / nullif(count(*) filter (where flag_aplicavel), 0), 1)  as cobertura_pct,
    round(median(valor_min) filter (where flag_elegivel), 1)                as mediana_min,
    round(quantile_cont(valor_min, 0.90) filter (where flag_elegivel), 1)   as p90_min,
    round(quantile_cont(valor_min, 0.95) filter (where flag_elegivel), 1)   as p95_min
from grade
group by 1, 2, 3, 4, 5, 6
