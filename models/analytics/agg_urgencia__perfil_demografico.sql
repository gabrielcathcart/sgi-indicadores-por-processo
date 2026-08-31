-- Aba 2 (Perfil). Grao: classificacao_faixa_etaria x sexo x
-- classificacao_manchester. Ordem de criticidade de Manchester persistida
-- (nunca alfabetica). Top de CID/queixa nao se aplica (nao ha CID no escopo);
-- perfil por procedencia via agg_urgencia__admissoes_dia.

with f as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
),
tot as (select count(*) n from f)

select
    f.classificacao_faixa_etaria,
    f.sexo,
    f.classificacao_manchester,
    f.manchester_ordem_criticidade,
    f.manchester_cor_hex,

    count(*)                                                       as qt_atendimentos,
    round(100.0 * count(*) / max(t.n), 2)                          as pct_do_total,
    count(*) filter (where f.flag_internado)                       as qt_internado,
    round(100.0 * count(*) filter (where f.flag_internado) / count(*), 1) as pct_internacao_no_grupo,
    count(*) filter (where f.desfecho_urgencia = 'Obito')          as qt_obito,
    round(median(f.idade_anos), 0)                                 as mediana_idade
from f cross join tot t
group by 1, 2, 3, 4, 5
