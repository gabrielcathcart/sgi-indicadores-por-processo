-- Aba 1 (Entrada e Capacidade). Grao: data_entrada x data_referencia x
-- periodo_admissao x procedencia. So sinais de fluxo derivados do fato de
-- episodios. NAO ha ocupacao de leito, taxa de ocupacao nem disponibilidade
-- (sem denominador confiavel -- ver docs/parametros.md).
--
-- Referencia temporal oficial do volume de admissoes: data_entrada (data de
-- dt_entrada). data_referencia (data de dt_retirada_senha) e mantida para
-- reconciliacao; as duas so divergem para senhas retiradas perto da meia-noite.
--
-- SEGURO para o grafico de Procedencia (e para Aba 1 em geral): qt_admissoes =
-- count(distinct atendimento_id) por celula do grao, e cada atendimento_id cai
-- em exatamente UMA celula (data_entrada, data_referencia, periodo_admissao,
-- procedencia sao todos 1:1 com o atendimento). Logo SUM(qt_admissoes) sobre
-- qualquer subconjunto do grao = contagem distinta exata, sem dupla agregacao.
-- O % por procedencia e calculado no BI como participacao sobre o total
-- filtrado. Nao ha necessidade de um modelo agg_urgencia__procedencia separado.
-- (pct_internacao aqui e por celula — para agregacoes use
--  SUM(qt_internados)/SUM(qt_admissoes), nunca a media da coluna de %.)

with f as (
    select * from {{ ref('fct_urgencia_atendimentos') }}
)

select
    cast(dt_entrada as date)                                             as data_entrada,
    data_referencia,
    ano,
    mes,
    mes_referencia,
    semana_referencia,
    dia_semana_iso,
    dia_semana_nome,
    periodo_admissao,
    procedencia,

    count(distinct atendimento_id)                                       as qt_admissoes,
    count(*) filter (where flag_internado)                               as qt_internados,
    round(100.0 * count(*) filter (where flag_internado) / count(*), 1)  as pct_internacao,
    count(*) filter (where flag_imagem_realizada)                        as qt_com_imagem,
    count(*) filter (where desfecho_urgencia = 'Evasao')                 as qt_evasao,
    count(*) filter (where desfecho_urgencia = 'Obito')                  as qt_obito,
    count(*) filter (where desfecho_urgencia = 'Transferido de Hospital') as qt_transferido,
    count(*) filter (where desfecho_urgencia = 'Nao informado/Em Atendimento') as qt_em_atendimento,

    -- sinal indireto de gargalo na porta de internacao (boarding pos-AIH)
    round(median(tempo_finalizacao_aih_internacao_min)
          filter (where flag_elegivel_tempo_finalizacao_aih_internacao), 0) as mediana_boarding_min,
    round(quantile_cont(tempo_finalizacao_aih_internacao_min, 0.90)
          filter (where flag_elegivel_tempo_finalizacao_aih_internacao), 0) as p90_boarding_min
from f
group by 1,2,3,4,5,6,7,8,9,10
