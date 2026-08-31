# Qualidade de dados

Como o projeto trata nulos, sequências inválidas e outliers, quais testes rodam,
e o que existe de imperfeição **injetada de propósito** no dado bruto para
exercitar esses testes (sem contaminar o mart).

## Princípios

1. **Dado bruto não é "corrigido".** Duração negativa, timestamp faltante,
   sequência fora de ordem — tudo permanece no `raw` e no `staging`. O que muda
   entre camadas são as **flags** e a **elegibilidade**.
2. **Nulo aplicável ≠ falha.** Um exame que não foi pedido não tem
   `dt_solicitacao_imagem`; isso não é lacuna, é não-aplicabilidade. A cobertura
   é medida sobre a **população esperada** de cada etapa
   (`dq_urgencia__cobertura_timestamps`).
3. **Nunca zero no lugar de nulo.** Todo indicador de tempo é NULL quando um
   timestamp falta.
4. **A métrica principal usa mediana e percentis**, não média. "Com e sem
   outliers" só aparece quando é útil e explicitamente rotulado
   (`agg_urgencia__tempos.mediana_sem_outlier_min`).
5. **Sem PII.** Um teste varre `information_schema` procurando nomes de coluna
   típicos de dado pessoal (`assert_sem_colunas_pii.sql`).
6. **Cobertura é medida de registro, não de assistência.** Ver abaixo.

## Cobertura — como interpretar

`cobertura_pct` de um indicador = `n_elegivel / n_aplicavel`: a fração da
população **aplicável** àquela etapa que tem os dois timestamps presentes e em
sequência válida.

> **Neste dataset a cobertura é alta (96–100 %) por construção:** o gerador
> injeta uma taxa fixa de incompletude (~3 %), e a cobertura é o complemento
> disso. Ela existe para **exercitar as regras de elegibilidade e os testes**,
> não para representar a qualidade de registro de uma instituição real.

> **Num contexto real, cobertura baixa é sinal de qualidade e governança de
> registro — não é evidência direta de pior desempenho assistencial.** Um marco
> não registrado, registrado com atraso ou fora de ordem derruba a cobertura sem
> que o tempo real do processo tenha mudado.

Consequências práticas:

- **Não** concluir "a etapa X piorou" a partir de queda de cobertura; primeiro
  investigar registro (parametrização de sistema, fluxo de anotação, treinamento).
- Ao comparar indicadores entre si, lembrar que as colunas 5–7 têm **população
  menor** (imagem: 7.725; internado: 2.143) — cobertura alta sobre base pequena
  não é diretamente comparável a cobertura sobre 12.000.
- Uma etapa **não aplicável** (ex.: imagem em quem não fez exame; consulta em
  quem evadiu antes) **não** entra no denominador — ausência aqui não é lacuna.
- O Visual D do dashboard (`dq_urgencia__cobertura_timestamps`) é um **snapshot
  de governança do dado carregado**; não responde ao filtro de período.
- No dado sintético, as lacunas são exatamente a incompletude injetada de
  propósito (~3%); num extrato real, a cobertura por marco é o primeiro
  diagnóstico antes de qualquer leitura de tempo.

## Outliers — critério documentado e configurável

Configurado em `dbt_project.yml` (`vars`), ver `docs/parametros.md §4`:

| var | default | efeito |
|---|---|---|
| `outlier_metodo` | `iqr` | `iqr` → valor > `Q3 + k·IQR`; `meta` → valor > `outlier_cap_mult × meta_demo_min` |
| `outlier_iqr_k` | `3` | fator k da cerca de Tukey, **por indicador**, calculado sobre os elegíveis |
| `outlier_cap_mult` | `6` | múltiplo do valor de referência (quando `outlier_metodo = meta`) |
| `outlier_los_max_min` | `2880` | cap de sanidade do LOS (48 h) para `flag_outlier_tempo_porta_desfecho` |

`flag_outlier_<ind>` no fato marca o episódio; `agg_urgencia__tempos.qt_outlier`
conta por indicador. Outliers **não são removidos** do dado — só sinalizados.

## Imperfeições injetadas no `raw` (parcela limitada e documentada)

Geradas por `scripts/gerar_urgencia_sintetico.py` (determinístico, seed 42):

| Injeção | ~% dos episódios | Como aparece | Onde é capturada |
|---|---|---|---|
| Um timestamp de funil faltante | 3,0 % | `flag_dado_incompleto = true` | `dq_urgencia__resumo` linha 4/5; `dq_urgencia__cobertura_timestamps` |
| Inversão de sequência em um par | 2,0 % | duração negativa naquele indicador | `flag_sequencia_invalida_<ind>`, `flag_jornada_temporal_invalida` |
| Evento deslocado vs. episódio | 2,0 % | `flag_timestamp_estimado` no evento | `flag_divergencia_eventos` |
| Desfecho "Não informado/Em Atendimento" | ~1,9 % | `dt_desfecho` nulo | excluído dos denominadores de desfecho e do índice de retorno |
| Eventos com timestamp estimado (ruído de base) | ~3 % dos eventos | `flag_timestamp_estimado` | `dq_urgencia__resumo` linha 3 |

**Tratamento no mart:** essas linhas **não são descartadas**. Elas ficam fora da
elegibilidade dos indicadores afetados (`flag_elegivel_<ind> = false`), fora dos
denominadores de taxa quando não têm desfecho válido, e visíveis no painel de
qualidade. O grão do mart continua íntegro (1 linha por atendimento).

## Testes (`dbt build` roda todos) — 132 data tests

### Genéricos (`*.yml`) — ~119
`not_null`, `unique` em chaves de todas as camadas; `accepted_values` para
Manchester, ordem 1–6, procedência, sexo, faixa etária, período, desfecho, tipo
de evento, dimensão de segmentação; `relationships` evento → episódio.

### Singulares (`tests/`) — 13
| Teste | Garante |
|---|---|
| `assert_fct_grao_unico` | 1 linha por `atendimento_id` no mart |
| `assert_fct_conta_igual_stg` | integridade do grão após joins (mesma contagem do staging) |
| `assert_especialidade_so_internado` | `especialidade_internacao` preenchida ⇔ `desfecho = Internado` |
| `assert_tempos_elegiveis_nao_negativos` | nenhum indicador elegível com valor < 0 |
| `assert_elegivel_implica_sequencia_valida` | elegível ⇒ sequência daquele par não é inválida |
| `assert_cobertura_timestamps_minima` | campos "sempre"/"atendido" com ≥ 90 % de preenchimento |
| `assert_sem_evento_duplicado` | nenhum `tipo_evento` repetido por atendimento |
| `assert_taxa_obito_plausivel` | óbito/desfecho-válido entre 0,3 % e 6 % (limite amplo de plausibilidade para o gerador sintético — não é parâmetro clínico) |
| `assert_manchester_ordem_consistente` | `manchester_ordem_criticidade` sempre preenchida e coerente com a dimensão |
| `assert_janela_entrada_fechada` | nenhuma retirada de senha fora de 2025-01-01…06-30 |
| `assert_retorno_indice_desfecho_valido` | índice de retorno só com desfecho válido |
| `assert_divergencia_eventos_sob_limite` | divergência funil × eventos < 5 % |
| `assert_sem_colunas_pii` | nenhuma coluna com nome típico de dado pessoal em staging/marts/analytics |

## Relatório reprodutível

`python scripts/relatorio_qualidade.py` (após `dbt build`) imprime, num só
lugar: volumes, imperfeições injetadas e tratamento, completude por timestamp,
cobertura e dispersão por indicador, distribuição de categorias, retorno ≤72 h e
duplicidades. Os números vêm dos modelos `dq_*` e `agg_*` — não há cálculo novo
no script.

### Números de referência (seed 42, ~12.000 episódios)

| Métrica | Valor |
|---|---|
| Episódios / eventos | 12.000 / 128.387 |
| `flag_dado_incompleto` | 360 (3,0 %) |
| `flag_jornada_temporal_invalida` | 240 (2,0 %) |
| `flag_divergencia_eventos` | 207 (1,7 %) |
| `flag_evento_duplicado` | 0 |
| Sequência inválida em algum indicador | 240 (2,0 %) |
| Outlier em algum indicador | 908 (7,6 %) — por indicador: 0,1 %–2,8 % |
| Cobertura dos 7 indicadores | 96,1 %–100 % |
| Taxa de óbito (desfecho válido) | ~0,47 % |
| Retorno ≤72 h | 4,5 %–5,5 % ao mês |
