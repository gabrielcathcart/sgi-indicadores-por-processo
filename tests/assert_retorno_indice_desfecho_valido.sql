-- Todo episodio-indice marcado com retorno em <=72h precisa ter desfecho valido
-- (nao pode servir de indice quem nao tem desfecho).
select atendimento_id
from {{ ref('fct_urgencia_atendimentos') }}
where flag_indice_com_retorno_72h
  and (dt_desfecho is null or desfecho_urgencia = 'Nao informado/Em Atendimento')
