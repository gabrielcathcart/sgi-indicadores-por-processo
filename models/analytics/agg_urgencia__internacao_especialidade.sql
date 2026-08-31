-- Aba 3 (Desfecho). Internacoes por especialidade e mes. Grao:
-- especialidade_internacao x mes_referencia.
--
-- Metrica principal do grafico "Internacoes por Especialidade": qt_internacoes
-- (contagem de atendimentos, eixo de CONTAGEM). O boarding pos-AIH
-- (mediana/P90, em MINUTOS) e coluna complementar: nao deve dividir o mesmo
-- eixo da contagem — vai em tabela associada / tooltip / coluna. So e calculado
-- sobre internacoes ELEGIVEIS com sequencia valida
-- (flag_elegivel_tempo_finalizacao_aih_internacao ja garante etapa aplicavel +
-- os dois timestamps + sequencia valida).

with f as (
    select *
    from {{ ref('fct_urgencia_atendimentos') }}
    where flag_internado
)

select
    especialidade_internacao,
    mes_referencia,
    count(distinct atendimento_id)                                 as qt_internacoes,
    round(median(tempo_finalizacao_aih_internacao_min)
          filter (where flag_elegivel_tempo_finalizacao_aih_internacao), 0) as mediana_boarding_min,
    round(quantile_cont(tempo_finalizacao_aih_internacao_min, 0.90)
          filter (where flag_elegivel_tempo_finalizacao_aih_internacao), 0) as p90_boarding_min,
    round(median(tempo_porta_desfecho_min), 0)                     as mediana_porta_internacao_min
from f
group by 1, 2
