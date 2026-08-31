-- Aba 3 (Desfecho). Composicao de desfecho por classificacao de Manchester e
-- faixa etaria. Grao: classificacao_manchester x classificacao_faixa_etaria x
-- desfecho_urgencia. pct_no_grupo = participacao do desfecho dentro do par.

with f as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
)

select
    classificacao_manchester,
    manchester_ordem_criticidade,
    classificacao_faixa_etaria,
    desfecho_urgencia,
    count(*)                                                       as qt_atendimentos,
    round(100.0 * count(*)
          / sum(count(*)) over (
              partition by classificacao_manchester, classificacao_faixa_etaria), 1) as pct_no_grupo,
    round(100.0 * count(*) / sum(count(*)) over (), 2)             as pct_do_total
from f
group by 1, 2, 3, 4
