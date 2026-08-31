-- Ordem de criticidade de Manchester sempre preenchida e coerente com a
-- dimensao (nunca dependente de ordenacao alfabetica).
select f.atendimento_id, f.classificacao_manchester, f.manchester_ordem_criticidade
from {{ ref('fct_urgencia_atendimentos') }} f
left join {{ ref('dim_manchester') }} d
  on d.classificacao_manchester = f.classificacao_manchester
where f.manchester_ordem_criticidade is null
   or d.classificacao_manchester is null
   or f.manchester_ordem_criticidade <> d.manchester_ordem_criticidade
