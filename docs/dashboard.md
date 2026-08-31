# Dashboard "Jornada de Urgência" — especificação

## 1. Propósito

O dashboard é entregue como **especificação construtível + quatro mockups**
gerados dos próprios modelos (`assets/mockups/`, `scripts/gerar_graficos.py`).
Não há instância publicada do Superset nem integração automatizada: a entrega são
os modelos dbt (`marts` + `analytics`) mais este documento. A unidade de análise
é sempre o **atendimento/episódio** (`atendimento_id`), nunca o paciente. Não há
métrica de capacidade instalada, ocupação ou disponibilidade de leito — não
existe denominador confiável neste recorte.

Fórmulas dos tempos: [`metric_definitions.md`](./metric_definitions.md).
Nulos, sequência inválida, outliers e cobertura:
[`data_quality.md`](./data_quality.md).
Parâmetros e valores de referência: [`parametros.md`](./parametros.md).

## 2. Filtros globais

Filtros nativos do dashboard, aplicados a todo chart que expõe a coluna.

| Filtro | Coluna | Observação / exceção |
|---|---|---|
| Período | `data_entrada` (aba 1), `data_referencia` (aba 2), `data_desfecho` (aba 3), `periodo_ref` (aba 4 tendência) | os modelos `dq_*` são snapshot do dataset inteiro — não respondem ao filtro de período |
| Período de admissão | `periodo_admissao` (Madrugada/Manhã/Tarde/Noite) | o heatmap já tem a hora no eixo; filtrar por turno seria redundante |
| Procedência | `procedencia` | — |
| Classificação de Manchester | `classificacao_manchester` (ordenar por `manchester_ordem_criticidade`) | o visual de Manchester ao longo do tempo pode ficar fora do filtro para não se auto-anular |
| Faixa etária | `classificacao_faixa_etaria` (Pediátrico/Adulto) | os modelos de tempo não expõem faixa etária — não respondem |
| Sexo | `sexo` | idem tempos |
| Desfecho | `desfecho_urgencia` | aplicado a uma análise de tempo montada sobre o fato, é **seleção de casos**: a composição de cada indicador muda e deixa de ser comparável entre etapas. O boarding permanece restrito a `Internado` por definição |
| Especialidade de internação | `especialidade_internacao` | só tem valor para a população `Internado`. **Não** deve escopar admissões, perfil geral nem desfechos gerais — nesses a coluna é NULL e o denominador mudaria |

Regra de ordenação: em todo chart, Manchester por `manchester_ordem_criticidade`
(1 Vermelho … 6 Branco), nunca alfabética; cores semânticas de
[`parametros.md`](./parametros.md) (§2), nunca roxo nas marcas.

## 3. Visuais

Quatro abas. Cada linha é um visual; o bloco completo (público-alvo, cálculo,
elegibilidade, nulos) vive no `dbt docs` do modelo de origem.

| Aba | Visual | Pergunta | Fonte / modelo | Métrica principal | Observação importante |
|---|---|---|---|---|---|
| 1 | Admissões de urgência | Qual o volume de entradas e como evolui no tempo? | `agg_urgencia__admissoes_dia` | contagem de admissões | eixo temporal por `data_entrada`; volume ≠ gravidade |
| 1 | Distribuição das admissões por dia e hora | Em que dia da semana e faixa horária a demanda se concentra? | `agg_urgencia__heatmap_semana_hora` | admissões por célula | dia × hora da retirada de senha; mostra *quando*, não a causa |
| 1 | Admissões por dia e período | Como o volume diário se reparte entre os turnos? | `agg_urgencia__admissoes_dia` | admissões por turno | os 4 turnos são convenção do projeto |
| 1 | Admissões por procedência | De onde vêm os pacientes e qual a participação de cada origem? | `agg_urgencia__admissoes_dia` | admissões e participação % | depende de fatores de rede externos ao dataset |
| 2 | Perfil dos atendimentos | Qual o perfil etário e por sexo? | `agg_urgencia__perfil_demografico`; sexo por mês direto de `fct_urgencia_atendimentos` | contagem e participação % | mediana ao lado da média; unidade = atendimento |
| 2 | Classificação de risco | Qual o mix de gravidade na porta e como varia por semana? | `fct_urgencia_atendimentos` (`data_referencia` × `classificacao_manchester`) | atendimentos por classificação | cores semânticas; Branco é categoria parametrizada deste projeto |
| 3 | Desfechos de urgência | Como evoluem alta, internação, transferência, óbito e evasão? | `agg_urgencia__desfecho_dia` | atendimentos por desfecho | série por `data_desfecho`; "Em Atendimento" não tem data e fica fora da série |
| 3 | Internações por especialidade | Qual a demanda de internação a partir da urgência, por especialidade? | `agg_urgencia__internacao_especialidade` | contagem de internações | é **demanda**, não ocupação; boarding mediano/P90 em coluna à parte, nunca no mesmo eixo da contagem |
| 4 | Tempos de processo: tabela de KPIs | Para cada etapa, qual a mediana, os percentis altos, a cobertura e o nº elegível? | `agg_urgencia__tempos` | mediana e P90 por indicador | cobertura < 100 % é qualidade de registro; as etapas 5–7 têm base menor |
| 4 | Tempos de processo: tendência | A mediana/P90 de cada etapa melhora ou piora ao longo do semestre? | `agg_urgencia__tempos_tendencia` | mediana por período | 1 indicador + 1 segmento por vez; exibir a cobertura junto |
| 4 | Tempos de processo: distribuição | Qual a dispersão de cada etapa? Há cauda longa? | `agg_urgencia__tempos_evento` | distribuição de `valor_min` | só episódios elegíveis; outliers visíveis, não removidos |
| 4 | Cobertura de timestamps | Que percentual dos registros tem timestamps completos, por etapa? | `dq_urgencia__cobertura_timestamps` | `pct_preenchido` por marco | snapshot de governança; não responde ao filtro de período |

Retorno em ≤72 h **não** é um visual principal: fica em
`agg_urgencia__retorno_72h` como leitura complementar (ver §7 e
[`metric_definitions.md`](./metric_definitions.md)).

## 4. Referência temporal

| Uso | Timestamp | Coluna de data |
|---|---|---|
| Volume de admissões (aba 1) | `dt_entrada` | `data_entrada` |
| Distribuição dia × hora (heatmap) | `dt_retirada_senha` | `hora_retirada_senha`, `dia_semana_iso` |
| Séries de desfecho (aba 3) | `dt_desfecho` | `data_desfecho` (NULO para "Em Atendimento") |
| Tempos de processo (aba 4) | par início→fim de cada indicador | ver [`metric_definitions.md`](./metric_definitions.md) |

## 5. Como montar no Superset

Não há integração automatizada; os passos abaixo são o roteiro. Pré-requisito:
`dbt build` verde materializando `marts` e `analytics` num destino que o Superset
leia.

1. Registrar **um dataset físico por modelo** de `marts` e `analytics` — o fato
   primeiro (`fct_urgencia_atendimentos`), depois um dataset por aba, e por
   último os `dq_*` e o retorno 72 h, marcados como "qualidade" / "complementar".
2. Definir a **coluna temporal principal** de cada dataset conforme a §4 (fato:
   `data_entrada`; desfecho: `data_desfecho`; tendência: `periodo_ref`; `dq_*`:
   sem eixo de tempo).
3. Definir **métricas e colunas calculadas no dataset**, nunca no chart; os
   `agg_*` já trazem `mediana_min`, `p90_min`, `cobertura_pct`, `n_elegivel` etc.
   — não recalcular elegibilidade, cobertura ou outlier.
4. Criar os **filtros nativos** da §2 e usar *filter scoping* para as exceções
   (especialidade fora dos indicadores gerais; `dq_*` fora do filtro de período).
5. Fixar o **mapa de cores de Manchester** (label colors no metadata do
   dashboard) com os hex de `parametros.md` §2; Branco com borda `#7F8C8D`;
   ordenar sempre por `manchester_ordem_criticidade`.
6. Montar as **4 abas** na ordem da §3; cada aba abre com um cabeçalho curto e o
   aviso "dados 100 % sintéticos".
7. Formatar tempo em **minutos e `h:mm`**; `cobertura_pct` e `pct_*` como
   percentual com uma casa decimal.
8. Exportar os assets com `superset export-dashboards` (YAML de texto,
   versionável); os YAMLs vivem na instância, não neste repositório.

## 6. Como ler os visuais

As leituras abaixo são **modos de interpretar**, não achados: o gerador usa
distribuições fixas, sem tendência ao longo do tempo.

**Aba 1 — entrada.** Se o heatmap indicar demanda concentrada em faixas
recorrentes de dia e hora, o recorte pode apoiar o dimensionamento de acolhimento
e triagem nesses horários. Volume alto num turno não implica, por si, pior tempo;
a leitura deve ser confirmada com a aba 4 e com dados operacionais.

**Aba 2 — perfil.** Se a participação de uma classificação de Manchester ou de
uma faixa etária se deslocar de forma sustentada, o recorte pode apoiar a revisão
de linhas de cuidado e do protocolo de triagem. Volume absoluto e participação %
contam histórias diferentes e devem ser lidos juntos.

**Aba 3 — desfecho.** Se a curva de "Em Atendimento" subir, a leitura é de
registro pendente ou backlog, não de pior assistência. A taxa de óbito usa só
desfecho válido no denominador. Internações por especialidade indicam **demanda**
de retaguarda, não ocupação de leito.

**Aba 4 — tempos.** Se um indicador tiver mediana moderada mas P90/P95 muito
acima dela, a cauda é o objeto de análise — segmentar por Manchester, período e
procedência antes de concluir, e conferir a cobertura da etapa. A leitura deve
ser confirmada com dados operacionais.

## 7. O que o dashboard não responde

- Não prova causalidade — apenas localiza onde investigar.
- Não mede ocupação, capacidade instalada nem disponibilidade de leito.
- Não representa o desempenho de nenhuma instituição real — os números são
  sintéticos.
- Não substitui a validação das definições de etapa com as áreas operacionais.
- Retorno em ≤72 h não é readmissão clínica validada: só enxerga retornos deste
  dataset, com identificador de paciente sintético.

## 8. Como se conecta à produção

Num ambiente institucional, o mesmo desenho dependeria de componentes que **não**
fazem parte deste repositório:

- **dados homologados** no lugar dos CSVs sintéticos;
- **catálogo, linhagem e classificação de sensibilidade** dos modelos;
- **governança de acesso** à camada de consumo;
- **validação das métricas e das definições de etapa** com a operação;
- uma **instância do Superset** ligada a esses datasets;
- **homologação formal do dataset** antes da publicação em BI.
