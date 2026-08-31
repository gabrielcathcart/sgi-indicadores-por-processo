-- A divergencia entre o funil (episodios) e o log de eventos deve ficar abaixo
-- de 5% dos atendimentos. Acima disso, a reconciliacao esta quebrada.
with r as (
    select count(*) filter (where flag_divergencia_eventos)::double / nullif(count(*), 0) as taxa
    from {{ ref('fct_urgencia_atendimentos') }}
)
select taxa from r where taxa > 0.05
