-- Nenhum indicador de tempo pode ser negativo quando marcado como ELEGIVEL.
-- (Duracoes negativas existem no dado bruto por inconsistencia injetada, mas
--  nesses casos flag_elegivel_<ind> deve ser falso.)
{% set inds = [
  'tempo_entrada_triagem','tempo_triagem','tempo_triagem_consulta','tempo_consulta',
  'tempo_solicitacao_realizacao_imagem','tempo_reavaliacao','tempo_finalizacao_aih_internacao'
] %}
select atendimento_id
from {{ ref('fct_urgencia_atendimentos') }}
where
{% for ind in inds %}
    (flag_elegivel_{{ ind }} and {{ ind }}_min < 0)
    {{ "or" if not loop.last }}
{% endfor %}
