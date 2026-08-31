-- Integridade do grao apos os joins: o fato tem exatamente as mesmas linhas do
-- staging de episodios (nenhuma perdida, nenhuma duplicada).
with c as (
    select
        (select count(*) from {{ ref('fct_urgencia_atendimentos') }})   as n_fct,
        (select count(*) from {{ ref('stg_urgencia__episodios') }})      as n_stg
)
select * from c where n_fct <> n_stg
