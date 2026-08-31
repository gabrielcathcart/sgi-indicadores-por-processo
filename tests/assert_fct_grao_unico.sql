-- O fato principal deve ter exatamente 1 linha por atendimento_id.
select atendimento_id, count(*) as n
from {{ ref('fct_urgencia_atendimentos') }}
group by atendimento_id
having count(*) > 1
