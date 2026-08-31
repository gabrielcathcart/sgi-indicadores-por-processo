-- Consistencia: se um indicador esta ELEGIVEL, a sequencia daquele par de
-- timestamps nao pode estar invalida.
{% set inds = [
  'tempo_entrada_triagem','tempo_triagem','tempo_triagem_consulta','tempo_consulta',
  'tempo_solicitacao_realizacao_imagem','tempo_reavaliacao','tempo_finalizacao_aih_internacao'
] %}
select atendimento_id
from {{ ref('fct_urgencia_atendimentos') }}
where
{% for ind in inds %}
    (flag_elegivel_{{ ind }} and flag_sequencia_invalida_{{ ind }})
    {{ "or" if not loop.last }}
{% endfor %}
