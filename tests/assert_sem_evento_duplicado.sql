-- Nao pode haver mais de um evento do mesmo tipo para o mesmo atendimento.
select atendimento_id, tipo_evento, count(*) as n
from {{ ref('stg_urgencia__eventos') }}
group by atendimento_id, tipo_evento
having count(*) > 1
