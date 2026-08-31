-- Aba 1. Mapa de calor de admissoes por dia da semana x hora da retirada de
-- senha. Grao: dia_semana_iso x hora_retirada_senha.

with f as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
)

select
    dia_semana_iso,
    dia_semana_nome,
    hora_retirada_senha,
    count(*)                                              as qt_admissoes,
    count(distinct data_referencia)                       as qt_dias_observados,
    round(count(*)::double / nullif(count(distinct data_referencia), 0), 2) as admissoes_por_dia
from f
group by 1, 2, 3
