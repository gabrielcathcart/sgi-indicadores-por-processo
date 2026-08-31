-- Cobertura minima dos timestamps do funil: cada campo "sempre esperado" ou
-- "esperado quando atendido" deve ter >= 90% de preenchimento (as unicas
-- lacunas sao as ~3% de incompletude injetada de proposito).
select campo_timestamp, regra_esperado, pct_preenchido
from {{ ref('dq_urgencia__cobertura_timestamps') }}
where regra_esperado in ('sempre', 'atendido')
  and pct_preenchido < 90
