-- especialidade_internacao so pode estar preenchida quando desfecho = 'Internado'
-- (e deve estar preenchida sempre que for 'Internado').
select atendimento_id, desfecho_urgencia, especialidade_internacao
from {{ ref('fct_urgencia_atendimentos') }}
where (especialidade_internacao is not null) <> (desfecho_urgencia = 'Internado')
