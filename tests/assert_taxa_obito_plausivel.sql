-- Guarda de sanidade do gerador sintetico: a taxa de obito entre episodios com
-- desfecho valido deve ficar entre 0,3% e 6%. Se o gerador for ajustado e sair
-- muito dessa faixa, provavelmente ha um erro na calibracao. O intervalo NAO e
-- parametro clinico nem meta institucional -- e so um limite amplo de
-- plausibilidade para o dado sintetico.
with r as (
    select
        count(*) filter (where desfecho_urgencia = 'Obito')::double
        / nullif(count(*) filter (where desfecho_urgencia <> 'Nao informado/Em Atendimento'), 0) as taxa
    from {{ ref('fct_urgencia_atendimentos') }}
)
select taxa from r
where taxa is null or taxa < 0.003 or taxa > 0.06
