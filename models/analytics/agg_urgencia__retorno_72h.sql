-- COMPLEMENTAR (nao KPI principal) — retorno em <=72h por mes.
-- Limitacoes (docs/metric_definitions.md): so capta retornos deste dataset
-- sintetico; nao e readmissao clinica validada; nao ve retorno em outra
-- instituicao. Episodio sem desfecho valido nao serve de indice (excluido).

with f as (
    select
        mes_referencia,
        flag_retorno_72h,
        flag_indice_com_retorno_72h,
        (desfecho_urgencia <> 'Nao informado/Em Atendimento' and dt_desfecho is not null) as desfecho_valido,
        horas_ate_retorno
    from {{ ref('fct_urgencia_atendimentos') }}
)

select
    mes_referencia,
    count(*)                                                       as qt_atendimentos,
    count(*) filter (where not desfecho_valido)                    as qt_sem_desfecho_valido_excluidos,
    count(*) filter (where desfecho_valido)                        as qt_indice_avaliavel,
    count(*) filter (where flag_indice_com_retorno_72h)            as qt_indice_com_retorno_72h,
    round(100.0 * count(*) filter (where flag_indice_com_retorno_72h)
          / nullif(count(*) filter (where desfecho_valido), 0), 2) as pct_retorno_72h,
    count(*) filter (where flag_retorno_72h)                       as qt_episodios_que_sao_retorno,
    round(median(horas_ate_retorno)
          filter (where flag_indice_com_retorno_72h), 1)           as mediana_horas_ate_retorno
from f
group by 1
order by 1
