-- Janela de ENTRADA fechada: nenhuma retirada de senha fora de
-- 2025-01-01 .. 2025-06-30. (Desfechos de internacao podem cair alguns dias
-- depois por boarding — esperado, nao testado aqui.)
select atendimento_id, data_referencia
from {{ ref('fct_urgencia_atendimentos') }}
where data_referencia < date '2025-01-01'
   or data_referencia > date '2025-06-30'
