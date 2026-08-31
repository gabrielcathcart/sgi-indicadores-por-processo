# Dicionário de dados — jornada de urgência

Cobre a camada bruta (seeds), a dimensão de Manchester, as metas, o fato
principal (`fct_urgencia_atendimentos`) e os agregados de consumo. Descrições por
coluna também vivem nos `schema.yml` de cada camada e no site do
`dbt docs generate`. Dados **100% sintéticos**.

Linhagem: `data/synthetic/*.csv` (seed) → `staging` → `intermediate` →
`marts.fct_urgencia_atendimentos` → `analytics.agg_*`.

---

## 1. `data/synthetic/urgencia_episodios_raw.csv` — seed `urgencia_episodios_raw`

Grão: **1 linha por atendimento/episódio de urgência**. ~12.000 linhas.

### Identificação e timestamps
| Coluna | Tipo | Descrição | Nulo |
|---|---|---|---|
| `atendimento_id` | int | Identificador sintético do episódio. **Único.** | não |
| `paciente_id_pseudonimo` | varchar | Chave de paciente **inteiramente sintética** (`PAC` + contador). Estável entre episódios do mesmo paciente sintético. Não deriva de nome/CPF/prontuário; não reidentifica. | não |
| `dt_retirada_senha` | timestamp | Início da jornada. Base da `data_referencia` e do calendário. Sempre em 2025-01-01 → 2025-06-30. | não |
| `dt_entrada` | timestamp | Entrada efetiva na urgência (após recepção). | não |
| `dt_inicio_triagem` / `dt_fim_triagem` | timestamp | Início e fim da classificação de risco. | ~1% (incompletude injetada) |
| `dt_inicio_consulta` | timestamp | Início do atendimento médico. | quando evasão antes da consulta |
| `dt_abertura_evolucao` | timestamp | Abertura da evolução no prontuário. | idem / ~1% injetado |
| `dt_prescricao` | timestamp | Prescrição médica. Fim do "tempo de consulta". | idem |
| `dt_solicitacao_imagem` / `dt_realizacao_imagem` | timestamp | Solicitação e realização do exame de imagem. | quando `possui_imagem = false` (~36%) |
| `dt_conduta` | timestamp | Decisão/conduta clínica. Após a imagem, se houver. | quando evasão / em atendimento |
| `dt_solicitacao_internacao` / `dt_finalizacao_aih` | timestamp | Solicitação da internação e finalização da AIH. | só trajetória de internação |
| `dt_internacao_efetiva` | timestamp | Admissão efetiva no leito. | só `desfecho_urgencia = Internado` |
| `dt_desfecho` | timestamp | Momento do desfecho. | nulo para `Nao informado/Em Atendimento` (~1,9%) |

### Dimensões
| Coluna | Tipo | Domínio |
|---|---|---|
| `periodo_admissao` | varchar | `Madrugada` (0–5h) · `Manha` (6–11h) · `Tarde` (12–17h) · `Noite` (18–23h) |
| `procedencia` | varchar | `Demanda Espontanea` · `Atendimento Primario` · `UPA/CRS` · `Interior` · `Hospital` |
| `sexo` | varchar | `Masculino` · `Feminino` |
| `idade_anos` | int | 0–105 |
| `classificacao_faixa_etaria` | varchar | `Pediatrico` (idade < 18) · `Adulto` — convenção do portfólio (`docs/parametros.md`) |
| `classificacao_manchester` | varchar | `Vermelho` · `Laranja` · `Amarelo` · `Verde` · `Azul` · `Branco` |
| `manchester_ordem_criticidade` | int | 1 (Vermelho) … 6 (Branco). **Ordenar sempre por esta coluna.** |
| `desfecho_urgencia` | varchar | `Internado` · `Liberado` · `Evasao` · `Obito` · `Alta a Pedido` · `Nao informado/Em Atendimento` · `Transferido de Hospital` |
| `especialidade_internacao` | varchar | Preenchida **somente** quando `desfecho_urgencia = Internado` |
| `possui_imagem` | boolean | Houve exame de imagem |
| `possui_internacao` | boolean | Trajetória de internação (solicitação de internação existiu) |
| `flag_dado_incompleto` | boolean | Marca explícita: falta ao menos um timestamp de funil (incompletude injetada, ~3%) |

## 2. `data/synthetic/urgencia_eventos_raw.csv` — seed `urgencia_eventos_raw`

Grão: **1 linha por evento operacional por atendimento**. ~128.000 linhas.

| Coluna | Tipo | Descrição |
|---|---|---|
| `evento_id` | int | Identificador do evento. **Único.** |
| `atendimento_id` | int | FK → `urgencia_episodios_raw.atendimento_id`. |
| `tipo_evento` | varchar | `retirada_senha` · `entrada_urgencia` · `inicio_triagem` · `fim_triagem` · `inicio_consulta` · `abertura_evolucao` · `prescricao` · `solicitacao_imagem` · `realizacao_imagem` · `conduta` · `solicitacao_internacao` · `finalizacao_aih` · `internacao_efetiva` · `desfecho` |
| `dt_evento` | timestamp | Momento do evento. |
| `sequencia_evento` | int | Ordem do evento dentro do atendimento (1…n). |
| `origem_registro` | varchar | Sistema de origem: `totem_recepcao`, `painel_pa`, `sistema_triagem`, `prontuario_eletronico`, `sistema_ris_pacs`, `sistema_regulacao`, `painel_leitos`. |
| `flag_timestamp_estimado` | boolean | Timestamp estimado/impreciso (~3% + os ~2% de divergência injetada). |

## 3. `seeds/dim_manchester.csv` — ver `docs/parametros.md §2`
`classificacao_manchester` · `manchester_ordem_criticidade` (1–6) · `cor_hex` ·
`cor_nome` · `observacao`.

## 4. `seeds/metas_demo.csv` — ver `docs/parametros.md §3`
`indicador` (um dos 7 indicadores de tempo) · `meta_demo_min` · `tipo_referencia`
(`referencia_de_simulacao`) · `observacao`.

`meta_demo_min` é o nome físico herdado do seed; no case, o valor é apresentado
como referência de simulação.

---

## 5. `marts.fct_urgencia_atendimentos` — FATO PRINCIPAL (86 colunas)

Grão: **1 linha por `atendimento_id`**. Modelo de consumo principal do dashboard.

### Chaves e calendário
`atendimento_id` (único), `paciente_id_pseudonimo`, `data_referencia`,
`dt_retirada_senha`, `dt_entrada`, `ano`, `mes`, `mes_referencia` (1º dia do mês),
`semana_referencia` (1º dia da semana), `semana_iso`, `dia_semana_iso` (1=segunda),
`dia_semana_nome` (pt-BR), `hora_retirada_senha` (0–23), `periodo_admissao`.

### Dimensões
`procedencia`, `sexo`, `idade_anos`, `classificacao_faixa_etaria`,
`classificacao_manchester`, `manchester_ordem_criticidade` (**ordenação**),
`manchester_cor_hex`, `desfecho_urgencia`, `especialidade_internacao`.

### Flags de negócio
`possui_imagem`, `possui_internacao`, `flag_internado`
(`desfecho_urgencia = Internado`), `flag_imagem_realizada`
(`dt_realizacao_imagem` presente).

### Timestamps do funil (auditáveis)
`dt_inicio_triagem`, `dt_fim_triagem`, `dt_inicio_consulta`,
`dt_abertura_evolucao`, `dt_prescricao`, `dt_solicitacao_imagem`,
`dt_realizacao_imagem`, `dt_conduta`, `dt_solicitacao_internacao`,
`dt_finalizacao_aih`, `dt_internacao_efetiva`, `dt_desfecho`.

### Indicadores de tempo (minutos inteiros; **NULL** quando não aplicável/ausente — nunca zero)
| Coluna | Definição | ver `metric_definitions.md` |
|---|---|---|
| `tempo_entrada_triagem_min` | `dt_retirada_senha` → `dt_inicio_triagem` | 1 |
| `tempo_triagem_min` | `dt_inicio_triagem` → `dt_fim_triagem` | 2 |
| `tempo_triagem_consulta_min` | `dt_fim_triagem` → `dt_inicio_consulta` | 3 |
| `tempo_consulta_min` | `dt_abertura_evolucao` → `dt_prescricao` | 4 |
| `tempo_solicitacao_realizacao_imagem_min` | `dt_solicitacao_imagem` → `dt_realizacao_imagem` | 5 |
| `tempo_reavaliacao_min` | `dt_realizacao_imagem` → `dt_conduta` | 6 |
| `tempo_finalizacao_aih_internacao_min` | `dt_finalizacao_aih` → `dt_internacao_efetiva` (boarding pós-AIH) | 7 |
| `tempo_porta_conduta_min` | `dt_entrada` → `dt_conduta` (auxiliar) | — |
| `tempo_porta_desfecho_min` | `dt_entrada` → `dt_desfecho` (LOS, auxiliar) | — |

### Flags por indicador (para cada um dos 7 acima)
`flag_elegivel_<ind>` · `flag_sequencia_invalida_<ind>` · `flag_outlier_<ind>` ·
`flag_acima_meta_demo_<ind>`. Mais `flag_outlier_tempo_porta_desfecho` (cap
operacional de 48 h).

### Flags de jornada / qualidade
`flag_dado_incompleto` (do raw), `flag_timestamp_incompleto` (mart),
`flag_jornada_temporal_invalida`, `flag_divergencia_eventos`,
`flag_evento_duplicado`.

### Retorno em ≤72 h (COMPLEMENTAR — não KPI principal)
`flag_retorno_72h` (este episódio é um retorno), `flag_indice_com_retorno_72h`
(este episódio-índice foi seguido por um retorno), `horas_ate_retorno`,
`horas_desde_episodio_anterior`.

---

## 6. `analytics.*` — datasets de consumo

| Modelo | Grão | Aba / uso |
|---|---|---|
| `agg_urgencia__admissoes_dia` | data_entrada × data_referencia × periodo_admissao × procedencia | Aba 1 |
| `agg_urgencia__heatmap_semana_hora` | dia_semana_iso × hora_retirada_senha | Aba 1 |
| `agg_urgencia__perfil_demografico` | faixa_etaria × sexo × Manchester | Aba 2 |
| `agg_urgencia__desfecho_dia` | data_desfecho (nullable) × data_referencia × desfecho_urgencia | Aba 3 |
| `agg_urgencia__desfecho_manchester` | Manchester × faixa_etaria × desfecho_urgencia | Aba 3 |
| `agg_urgencia__internacao_especialidade` | especialidade_internacao × mes_referencia | Aba 3 |
| `agg_urgencia__tempos` | indicador × Manchester (+ linha `Todos`) | Aba 4 — Visual A |
| `agg_urgencia__tempos_tendencia` | granularidade (`Semana`/`Mes`) × periodo_ref × indicador × segmento × segmento_valor | Aba 4 — Visual B |
| `agg_urgencia__tempos_evento` | atendimento × indicador (só elegíveis) | Aba 4 — Visual C (distribuição) |
| `agg_urgencia__retorno_72h` | mes_referencia | complementar / DQ |
| `dq_urgencia__resumo` | métrica | governança / DQ |
| `dq_urgencia__cobertura_timestamps` | campo_timestamp | governança / DQ |

Sexo por mês e classificação de Manchester por semana (Aba 2) são derivados
direto de `marts.fct_urgencia_atendimentos` — não têm modelo `agg_*` dedicado.

Colunas de cada `agg_*` no `dbt docs` e em `docs/dashboard.md`.
