-- Retorno em <=72h (ANALISE COMPLEMENTAR — nao KPI principal).
--
-- Para o mesmo paciente sintetico, mede o intervalo entre o DESFECHO de um
-- episodio e a ENTRADA (retirada de senha) do episodio seguinte. Marca retorno
-- quando 0 <= intervalo <= var('retorno_janela_horas').
--
-- Limitacoes (docs/metric_definitions.md): so capta retornos deste dataset
-- sintetico; nao e readmissao clinica validada; nao ve retorno em outra
-- instituicao. Episodio sem desfecho valido nao serve de indice (sinalizado).

with epi as (
    select
        atendimento_id,
        paciente_id_pseudonimo,
        dt_retirada_senha,
        dt_desfecho,
        desfecho_urgencia,
        (dt_desfecho is not null
         and desfecho_urgencia <> 'Nao informado/Em Atendimento') as desfecho_valido
    from {{ ref('stg_urgencia__episodios') }}
),

seq as (
    select
        *,
        lead(dt_retirada_senha) over w  as dt_entrada_proximo,
        lead(atendimento_id)    over w  as atendimento_id_proximo,
        lag(dt_desfecho)        over w  as dt_desfecho_anterior,
        lag(desfecho_valido)    over w  as desfecho_anterior_valido
    from epi
    window w as (partition by paciente_id_pseudonimo order by dt_retirada_senha, atendimento_id)
)

select
    atendimento_id,
    paciente_id_pseudonimo,
    atendimento_id_proximo,

    case when desfecho_valido
         then round(date_diff('second', dt_desfecho, dt_entrada_proximo) / 3600.0, 1)
    end                                                            as horas_ate_retorno,

    (desfecho_valido and dt_entrada_proximo is not null
     and date_diff('second', dt_desfecho, dt_entrada_proximo)
         between 0 and {{ var('retorno_janela_horas') }} * 3600)   as flag_indice_com_retorno_72h,
    (desfecho_valido and dt_entrada_proximo is not null)           as flag_indice_avaliavel,
    (not desfecho_valido)                                          as flag_indice_sem_desfecho_valido,

    (
        coalesce(desfecho_anterior_valido, false)
        and dt_desfecho_anterior is not null
        and date_diff('second', dt_desfecho_anterior, dt_retirada_senha)
            between 0 and {{ var('retorno_janela_horas') }} * 3600
    )                                                              as flag_retorno_72h,
    round(date_diff('second', dt_desfecho_anterior, dt_retirada_senha) / 3600.0, 1)
                                                                   as horas_desde_episodio_anterior
from seq
