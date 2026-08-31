# Parâmetros analíticos do projeto

**Fonte humana** dos parâmetros que orientam modelos e dashboard. Os valores de
execução vivem em `dbt_project.yml` (`vars:`) e, quando o BI precisa consumir, em
seeds (`seeds/dim_manchester.csv`, `seeds/metas_demo.csv`). Ao mudar um parâmetro,
altere aqui **e** no local de execução.

Todos os dados são **100% sintéticos**. Nenhum parâmetro abaixo é regra clínica,
regulatória ou institucional — são convenções analíticas deste portfólio.

---

## 1. Faixa etária (corte pediátrico / adulto)

| Faixa | Regra | Execução |
|---|---|---|
| `Pediatrico` | `idade_anos < 18` | `var('idade_corte_pediatrico_anos') = 18` |
| `Adulto` | `idade_anos >= 18` | idem |

- **Convenção analítica deste portfólio**, não regra clínica/regulatória/
  institucional universal.
- A macro `faixa_etaria()` (`macros/urgencia_helpers.sql`) aplica o corte;
  `stg_urgencia__episodios.classificacao_faixa_etaria` é a coluna canônica
  (re-derivada do parâmetro; o raw traz a mesma regra e há teste de coerência).
- Faixas SBP / epidemiológicas do material de referência foram **deliberadamente
  excluídas** do dashboard principal para evitar sobreposição de classificações.
  Se voltarem, entram como aba/modelo separado, nunca misturadas à faixa binária.

## 2. Classificação de Manchester — ordem de criticidade e paleta

Seis categorias, **ordem fixa** (nunca alfabética). Persistida em
`seeds/dim_manchester.csv` → `manchester_ordem_criticidade`, propagada a todos os
modelos e a `fct_urgencia_atendimentos.manchester_ordem_criticidade`. A visão de
Manchester ao longo do tempo é construída direto de `fct_urgencia_atendimentos`
(`data_referencia` × `classificacao_manchester`; o Superset agrega para semana) e,
segmentada nos tempos de processo, em `analytics.agg_urgencia__tempos_tendencia`.

| Ordem | Classificação | Cor (hex) | Papel |
|---|---|---|---|
| 1 | Vermelho | `#C0392B` | vermelho |
| 2 | Laranja | `#E67E22` | laranja |
| 3 | Amarelo | `#F1C40F` | amarelo |
| 4 | Verde | `#27AE60` | verde |
| 5 | Azul | `#2980B9` | azul |
| 6 | Branco | `#D5D8DC` | cinza claro — **renderizar com borda `#7F8C8D` e texto escuro** para contraste |

- **Branco é categoria parametrizada NESTE projeto** (ex.: sem queixa aguda /
  fluxo administrativo). Uso pode variar conforme o fluxo institucional; **não
  tem aplicação universal**.
- A paleta roxa da identidade visual (`#6D28D9` etc.) é para títulos, cabeçalhos,
  cartões e neutros — **nunca** para as cores semânticas de Manchester.

## 3. Valores de referência de tempo — SIMULAÇÃO

Os valores abaixo servem **apenas para demonstrar a regra de cálculo** de
"% acima do valor de referência". **Não são SLA, contrato, protocolo nem meta
institucional.** Em produção, referências e metas precisam ser pactuadas com a
operação; os valores deste case não têm fonte bibliográfica e não representam
desempenho de nenhuma instituição.

Seed `seeds/metas_demo.csv` — uma linha por indicador de tempo, colunas
`indicador`, `meta_demo_min`, `tipo_referencia` (`referencia_de_simulacao`) e
`observacao`:

| `indicador` | `meta_demo_min` (referência de simulação) |
|---|---|
| `tempo_entrada_triagem` | 15 |
| `tempo_triagem` | 10 |
| `tempo_triagem_consulta` | 60 |
| `tempo_consulta` | 45 |
| `tempo_solicitacao_realizacao_imagem` | 90 |
| `tempo_reavaliacao` | 60 |
| `tempo_finalizacao_aih_internacao` | 360 |

`fct_urgencia_atendimentos.flag_acima_meta_demo_<ind>` e
`agg_urgencia__tempos.pct_acima_meta_demo` implementam a **visão complementar**
"% acima do valor de referência" (o nome físico das colunas mantém `meta_demo`).
A leitura principal continua sendo elegíveis → cobertura → mediana → P75 → P90 →
P95.

## 4. Detecção de outlier de tempo — configurável

`dbt_project.yml` (`vars`):

| var | default | efeito |
|---|---|---|
| `outlier_metodo` | `iqr` | `iqr` → valor > `Q3 + k·IQR` (por indicador, sobre elegíveis); `meta` → valor > `outlier_cap_mult × meta_demo_min` (múltiplo do valor de referência) |
| `outlier_iqr_k` | `3` | fator k da cerca de Tukey (mais conservador que o 1,5 clássico — ajuste conforme a distribuição) |
| `outlier_cap_mult` | `6` | múltiplo do valor de referência (quando `outlier_metodo = meta`) |
| `outlier_los_max_min` | `2880` | cap de sanidade do LOS (48 h) → `flag_outlier_tempo_porta_desfecho` |

Outliers são **sinalizados, nunca removidos** do dado bruto. `agg_urgencia__tempos`
traz `qt_outlier`, `pct_outlier` e `mediana_sem_outlier_min` (visão "com e sem
outliers" explícita), além de `aplicabilidade` / `obs_elegibilidade` descrevendo a
população elegível de cada indicador. A distribuição por episódio elegível (para
boxplot/histograma) fica em `analytics.agg_urgencia__tempos_evento`.

## 5. Retorno em ≤72 h — análise COMPLEMENTAR

- Janela: `var('retorno_janela_horas') = 72`.
- Regra: para o mesmo `paciente_id_pseudonimo`, intervalo entre o **desfecho** de
  um episódio e a **entrada** do seguinte; retorno quando `0 ≤ intervalo ≤ 72h`.
- Episódios **sem desfecho válido** (`desfecho_urgencia = 'Nao informado/Em
  Atendimento'` ou `dt_desfecho` nulo) não servem como índice e são sinalizados.
- **Não é KPI principal.** Vive em `agg_urgencia__retorno_72h`,
  `dq_urgencia__resumo` e nas fichas técnicas.
- **Limitações:** só capta retornos **deste dataset sintético**; não é readmissão
  clínica validada; não identifica retorno em outra instituição.

## 6. Dado sintético — volume, período, reprodutibilidade

| Parâmetro | Valor | Observação |
|---|---|---|
| Episódios | ~12.000 | `scripts/gerar_urgencia_sintetico.py --episodios 12000` |
| Janela de **entrada** | 2025-01-01 a 2025-06-30 (fechada) | nenhuma retirada de senha fora disso |
| Desfecho pós-janela | permitido | internações de fim de junho podem admitir em leito nos primeiros dias de julho (boarding). As análises filtram por `data_referencia` (entrada), sempre na janela. |
| Seed | 42 | `--seed`; determinístico |
| Fração de retorno plantada | ~3 % | `--retorno-frac 0.03` (soma-se aos retornos orgânicos) |

**Imperfeições injetadas de propósito** (`docs/data_quality.md`): ~3 % com um
timestamp de funil faltante (`flag_dado_incompleto`); ~2 % com sequência temporal
inválida; ~2 % com divergência funil × log de eventos; ~1,9 % com desfecho
"Nao informado/Em Atendimento".

## 7. Sem métricas de capacidade / ocupação

Decisão de escopo: **não** existe tabela de capacidade nem taxa de ocupação de
leito, disponibilidade, capacidade instalada ou produtividade por profissional —
não há denominador confiável neste recorte. A Aba 1 usa apenas sinais indiretos
derivados do fato de episódios: volume de admissões (dia / semana / turno),
procedência, volume de internações e o **boarding pós-AIH**
(`tempo_finalizacao_aih_internacao_min`) como sinal de gargalo da porta de
internação.
