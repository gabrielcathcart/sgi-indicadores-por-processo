# Definição de indicadores — tempos de processo da urgência

Sete indicadores de tempo, calculados em
`models/intermediate/int_urgencia__tempos.sql`, expostos em formato largo em
`marts.fct_urgencia_atendimentos` e em formato longo em
`models/intermediate/int_urgencia__tempos_long.sql` (fonte única dos modelos
`analytics.agg_urgencia__tempos*` e `analytics.agg_urgencia__tempos_evento`). Todos em
**minutos inteiros**.

## Regras transversais

- Tempo = `arredondar( (dt_fim − dt_inicio) em segundos ÷ 60 )`.
- **Timestamp ausente vira `NULL`, nunca zero** — reduz a cobertura da etapa, não
  a mediana.
- **Sequência inválida** (`dt_fim < dt_inicio`, ambos presentes) **exclui o
  episódio** das métricas elegíveis; ele permanece no fato e no painel de
  qualidade (`flag_sequencia_invalida_<ind>`).
- **Elegibilidade** (`flag_elegivel_<ind>`): etapa aplicável **e** os dois
  timestamps presentes **e** sequência válida. É o denominador das medianas e
  percentis.
- **Cobertura** de um indicador = `n_elegivel / n_aplicavel`.
- **Outliers** são sinalizados (`flag_outlier_<ind>`, cerca `Q3 + 3·IQR` por
  indicador sobre os elegíveis), **nunca removidos**. Mediana e P90/P95 são
  calculados com eles. Método configurável em `docs/parametros.md §4`.
- Leitura priorizada: **nº elegíveis → cobertura → mediana → P75 → P90 → P95**.
  Média não é métrica principal. "% acima do valor de referência" é visão
  complementar.
- Os **valores de referência são de simulação**: existem só para demonstrar o
  cálculo de "% acima da referência". Não são SLA, contrato, protocolo nem meta
  institucional, e não têm fonte bibliográfica. O nome físico das colunas mantém
  `meta_demo` (ver [`parametros.md`](./parametros.md) §3).
- A **cobertura alta deste dataset (96–100 %)** decorre em boa parte da taxa de
  incompletude injetada no gerador (~3 %); ela existe para exercitar as regras de
  elegibilidade, não para representar a qualidade de registro de uma instituição.
  Interpretação em [`data_quality.md`](./data_quality.md).

## Os 7 indicadores

| # | Indicador | Início | Fim | População aplicável | Nº elegível | Ref. de simulação (min) | Observação |
|---|---|---|---|---|---|---|---|
| 1 | `tempo_entrada_triagem` | `dt_retirada_senha` | `dt_inicio_triagem` | todos (12.000) | 11.885 | 15 | tempo até **iniciar** a triagem; sensível a picos de chegada |
| 2 | `tempo_triagem` | `dt_inicio_triagem` | `dt_fim_triagem` | todos (12.000) | 11.675 | 10 | duração curta; a inversão injetada é a principal fonte de não-elegibilidade |
| 3 | `tempo_triagem_consulta` | `dt_fim_triagem` | `dt_inicio_consulta` | todos (12.000)¹ | 11.639 | 60 | principal indicador de espera por consulta |
| 4 | `tempo_consulta` | `dt_abertura_evolucao` | `dt_prescricao` | todos (12.000)¹ | 11.530 | 45 | proxy da duração do atendimento médico; menor cobertura dos 7 |
| 5 | `tempo_solicitacao_realizacao_imagem` | `dt_solicitacao_imagem` | `dt_realizacao_imagem` | `possui_imagem` (7.725) | 7.677 | 90 | vai da solicitação à **realização**, não ao laudo |
| 6 | `tempo_reavaliacao` | `dt_realizacao_imagem` | `dt_conduta` | `possui_imagem` (7.725) | 7.659 | 60 | reavaliação médica pós-exame; ler junto com o indicador 5 |
| 7 | `tempo_finalizacao_aih_internacao` | `dt_finalizacao_aih` | `dt_internacao_efetiva` | `desfecho = Internado` (2.143) | 2.143 | 360 | boarding pós-AIH — ver nota abaixo |

¹ Aplicável a todo atendimento, mas NULL (não elegível) para quem evadiu antes da
consulta ou está "Em Atendimento" — isso aparece na cobertura, não é mascarado.

Contagens: dado sintético, seed 42, ~12.000 episódios, janela 2025-01-01…06-30 —
saídas do gerador calibrado, não desempenho de instituição. Reproduzir com
`python scripts/relatorio_qualidade.py` após `dbt build`.

## Tempos-jornada auxiliares

| Coluna | Fórmula | Uso |
|---|---|---|
| `tempo_porta_conduta_min` | `dt_conduta − dt_entrada` | tempo até a decisão clínica |
| `tempo_porta_desfecho_min` | `dt_desfecho − dt_entrada` | LOS na urgência; `flag_outlier_tempo_porta_desfecho` se < 0 ou > 48 h (`outlier_los_max_min`) |

## Flags de jornada

| Flag | Verdadeiro quando |
|---|---|
| `flag_dado_incompleto` | (raw) falta ao menos um timestamp de funil — incompletude injetada |
| `flag_timestamp_incompleto` | (mart) `flag_dado_incompleto` **ou** um marco de triagem/consulta ausente num atendimento que não evadiu nem está em atendimento |
| `flag_jornada_temporal_invalida` | algum par adjacente da cadeia de 14 marcos, ambos presentes, fora de ordem |
| `flag_divergencia_eventos` | funil × log de eventos divergem > 2 min em `inicio_consulta`, `fim_triagem` ou `realizacao_imagem` |
| `flag_evento_duplicado` | algum `tipo_evento` aparece > 1 vez para o mesmo atendimento |

## Métricas e denominadores das abas

| Métrica | Numerador | Denominador |
|---|---|---|
| Taxa de internação | `desfecho_urgencia = Internado` | total de atendimentos do recorte |
| Taxa de óbito | `desfecho_urgencia = Obito` | atendimentos com **desfecho válido** (≠ "Em Atendimento") |
| Taxa de evasão | `desfecho_urgencia = Evasao` | total do recorte |
| Cobertura de um indicador de tempo | `n_elegivel` (episódios `flag_elegivel_<ind>`) | `n_aplicavel` (episódios aplicáveis no formato longo) |
| % acima do valor de referência | `flag_acima_meta_demo_<ind>` (nome físico da coluna) | `flag_elegivel_<ind>` |
| Mediana / P75 / P90 / P95 do tempo | `quantile_cont(valor)` sobre `flag_elegivel_<ind>` | — |
| % de retorno ≤72 h (**complementar**) | `flag_indice_com_retorno_72h` | episódios-índice com **desfecho válido** |

## Boarding pós-AIH (indicador 7) — nota

"Finalização da AIH → internação efetiva" é uma **definição de modelagem deste
case**. Em produção, o par de marcos precisa ser validado com regulação,
internação e áreas operacionais. **Não** mede ocupação nem disponibilidade de
leito. No gerador, esta etapa foi parametrizada em escala de horas para
representar um cenário de espera por internação — por isso o painel a destaca como
etapa de atenção **no exercício**, não como achado sobre nenhuma instituição.

## Retorno em ≤72 h — complementar

Análise **exploratória**, não KPI. Para o mesmo `paciente_id_pseudonimo`,
intervalo entre o **desfecho** de um episódio-índice (com desfecho válido) e a
**entrada** do episódio seguinte, quando entre 0 e 72 h. Vive em
`agg_urgencia__retorno_72h` e `dq_urgencia__resumo`.

- só capta retornos **deste dataset sintético**;
- **não** é readmissão clínica validada; não identifica retorno em outra
  instituição;
- `paciente_id_pseudonimo` é sintético;
- **sem ficha técnica dedicada e sem destaque no dashboard.**

## Dimensão da qualidade (Donabedian)

| Dimensão | Neste projeto |
|---|---|
| Estrutura | não modelada diretamente |
| Processo | os tempos e as etapas do atendimento |
| Resultado | os desfechos e as internações |
