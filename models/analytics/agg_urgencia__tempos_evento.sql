-- Aba 4 (Tempos de Processo) - Visual C (Distribuicao).
-- Grao: 1 linha por (atendimento x indicador), APENAS registros ELEGIVEIS
-- (etapa aplicavel + dois timestamps presentes + sequencia valida).
-- Fonte de consumo para boxplot / histograma / distribuicao no Superset -
-- evita expor a camada intermediaria e garante que a distribuicao use a mesma
-- regra de elegibilidade dos KPIs.
--
-- valor_min nunca e negativo aqui (sequencia invalida ja foi excluida) e nunca
-- e zero por timestamp ausente (esses casos nao sao elegiveis).

select
    atendimento_id,
    indicador,
    indicador_ordem,
    aplicabilidade,
    data_referencia,
    semana_referencia,
    mes_referencia,
    classificacao_manchester,
    manchester_ordem_criticidade,
    periodo_admissao,
    procedencia,
    especialidade_internacao,
    valor_min,
    flag_outlier
from {{ ref('int_urgencia__tempos_long') }}
where flag_elegivel
