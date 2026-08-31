# models/ — camada de transformação (dbt-core + dbt-duckdb)

Pipeline **único**: nenhuma transformação vive fora do dbt. A camada SQL pura
anterior (pré-dbt) permanece apenas no histórico local de desenvolvimento e não
integra a versão publicada.

## Camadas

```
seeds (data/synthetic/*.csv, seeds/*.csv)
  └─ staging/        views  — tipagem, padronização, calendário, faixa etária
       └─ intermediate/  views  — pivot de eventos, 7 indicadores de tempo + flags
            │                     por indicador, retorno 72h, formato longo dos tempos
            └─ marts/    table — fct_urgencia_atendimentos (1 linha/atendimento) [MODELO DE CONSUMO PRINCIPAL]
                 └─ analytics/ views — 12 modelos: agg_* por aba + agg_urgencia__tempos_evento + dq_*
```

| Modelo | Camada | Mat. | Grão | Consumo |
|---|---|---|---|---|
| `stg_urgencia__episodios` · `stg_urgencia__eventos` | staging | view | atendimento / evento | interno |
| `int_urgencia__eventos_pivot` | intermediate | view | atendimento | reconciliação |
| `int_urgencia__tempos` | intermediate | view | atendimento | 7 tempos + flags por indicador |
| `int_urgencia__retorno_72h` | intermediate | view | atendimento | retorno ≤72h |
| `int_urgencia__tempos_long` | intermediate | view | atendimento × indicador | fonte única dos `agg` de tempo |
| `fct_urgencia_atendimentos` | marts | **table** | atendimento | **modelo de consumo do dashboard** |
| `agg_urgencia__admissoes_dia` · `__heatmap_semana_hora` | analytics | view | — | Aba 1 |
| `agg_urgencia__perfil_demografico` | analytics | view | — | Aba 2 (sexo/mês e Manchester/semana vêm direto do fato) |
| `agg_urgencia__desfecho_dia` · `__desfecho_manchester` · `__internacao_especialidade` | analytics | view | — | Aba 3 |
| `agg_urgencia__tempos` · `__tempos_tendencia` | analytics | view | — | Aba 4 (Visuais A/B) |
| `agg_urgencia__tempos_evento` | analytics | view | atendimento × indicador (elegíveis) | Aba 4 (Visual C — distribuição) |
| `agg_urgencia__retorno_72h` | analytics | view | mês | complementar / DQ |
| `dq_urgencia__resumo` · `dq_urgencia__cobertura_timestamps` | analytics | view | — | governança / DQ |

Schemas no banco (macro `generate_schema_name` = schema custom "as-is"):
`raw`, `seeds`, `staging`, `intermediate`, `marts`, `analytics`.

## Rodar

```bash
python -m venv .venv && . .venv/Scripts/activate      # Windows (Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt
cp profiles.yml.example profiles.yml                   # perfil local (ignorado pelo Git)

python scripts/gerar_urgencia_sintetico.py --episodios 12000 --seed 42
dbt seed  --profiles-dir .
dbt build --profiles-dir .
dbt docs generate --profiles-dir .
python scripts/relatorio_qualidade.py                  # relatório de qualidade
python scripts/gerar_graficos.py                       # 4 mockups em assets/mockups/
```

## Testes

- Genéricos (`schema.yml`): `not_null`, `unique`, `accepted_values`, `relationships`.
- Singulares (`../tests/`) — 13: grão único do fato, contagem = staging,
  especialidade só em Internado, tempos elegíveis não-negativos, elegível ⇒
  sequência válida, cobertura mínima de timestamps, sem evento duplicado, taxa de
  óbito plausível, ordem de Manchester consistente, janela de entrada fechada,
  índice de retorno com desfecho válido, divergência de eventos sob limite, sem
  colunas de PII.

Parâmetros e metas: [`../docs/parametros.md`](../docs/parametros.md).
Dicionário: [`../docs/data_dictionary.md`](../docs/data_dictionary.md).
Qualidade: [`../docs/data_quality.md`](../docs/data_quality.md).
