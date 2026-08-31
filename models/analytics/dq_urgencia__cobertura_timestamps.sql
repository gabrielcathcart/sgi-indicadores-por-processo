-- Taxa de completude por timestamp do funil. Grao: campo_timestamp.
-- Numerador e denominador restritos a MESMA populacao "esperada" (etapas nao
-- aplicaveis nao entram): imagem so quando possui_imagem; internacao so quando
-- desfecho Internado; consulta/anamnese so quando o paciente foi atendido;
-- desfecho so quando nao "Em Atendimento".

{% set pred = {
    'sempre':    'true',
    'atendido':  "desfecho_urgencia not in ('Evasao','Nao informado/Em Atendimento')",
    'imagem':    'possui_imagem',
    'internado': 'flag_internado',
    'desfecho':  "desfecho_urgencia <> 'Nao informado/Em Atendimento'"
} %}
{% set campos = [
    ('dt_retirada_senha',        'sempre'),
    ('dt_entrada',               'sempre'),
    ('dt_inicio_triagem',        'sempre'),
    ('dt_fim_triagem',           'sempre'),
    ('dt_inicio_consulta',       'atendido'),
    ('dt_abertura_evolucao',     'atendido'),
    ('dt_prescricao',            'atendido'),
    ('dt_conduta',               'atendido'),
    ('dt_solicitacao_imagem',    'imagem'),
    ('dt_realizacao_imagem',     'imagem'),
    ('dt_solicitacao_internacao','internado'),
    ('dt_finalizacao_aih',       'internado'),
    ('dt_internacao_efetiva',    'internado'),
    ('dt_desfecho',              'desfecho')
] %}

with f as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
)

{% for campo, regra in campos %}
{% set p = pred[regra] %}
select
    '{{ campo }}'                                                  as campo_timestamp,
    {{ loop.index }}                                               as ordem,
    '{{ regra }}'                                                  as regra_esperado,
    count(*) filter (where {{ p }})                                as n_esperado,
    count({{ campo }}) filter (where {{ p }})                      as n_preenchido,
    round(100.0 * count({{ campo }}) filter (where {{ p }})
          / nullif(count(*) filter (where {{ p }}), 0), 2)         as pct_preenchido
from f
{{ "union all" if not loop.last }}
{% endfor %}
order by ordem
