-- Aba 3 (Desfecho). Desfechos de urgencia ao longo do tempo.
-- Grao: data_desfecho x data_referencia x desfecho_urgencia.
--
-- data_desfecho = data de dt_desfecho. E NULL para 'Nao informado/Em
-- Atendimento' (dt_desfecho ausente): essas linhas NAO entram na serie por
-- data de desfecho; devem ser acompanhadas por data_referencia (entrada) como
-- sinal de pendencia/atraso de registro, nao como desfecho final.

with f as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
)

select
    cast(dt_desfecho as date)                                      as data_desfecho,
    data_referencia,
    mes_referencia,
    desfecho_urgencia,
    (dt_desfecho is null)                                          as flag_sem_data_desfecho,
    count(*)                                                       as qt_atendimentos
from f
group by 1, 2, 3, 4, 5
