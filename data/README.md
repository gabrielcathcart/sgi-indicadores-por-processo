# Dados

Todos os dados versionados aqui são **100% sintéticos**. Nenhum nome de paciente
ou de profissional — nem fictício — é gerado; paciente e profissional aparecem
apenas como código. Ver [`../PRIVACY.md`](../PRIVACY.md).

## Datasets sintéticos da jornada de urgência (`synthetic/`)

| Arquivo | Grão | Linhas | Gerador |
|---|---|---|---|
| [`synthetic/urgencia_episodios_raw.csv`](./synthetic/urgencia_episodios_raw.csv) | 1 linha por **atendimento/episódio** de urgência (`atendimento_id` único) | ~12.000 | [`gerar_urgencia_sintetico.py`](../scripts/gerar_urgencia_sintetico.py) |
| [`synthetic/urgencia_eventos_raw.csv`](./synthetic/urgencia_eventos_raw.csv) | 1 linha por **evento operacional** por atendimento | ~128.000 | idem |

Ambos são carregados como **seeds** do dbt (`seed-paths` inclui `data/synthetic`).
Janela de **entrada** fechada: **2025-01-01 a 2025-06-30**. Seed padrão: **42** —
rodar o gerador com a mesma seed reproduz exatamente os dois arquivos.

```bash
python scripts/gerar_urgencia_sintetico.py --episodios 12000 --seed 42
```

Dicionário completo de colunas: [`../docs/data_dictionary.md`](../docs/data_dictionary.md).

## Seeds de referência (`../seeds/`)

| Arquivo | Conteúdo |
|---|---|
| `seeds/dim_manchester.csv` | Classificação de Manchester + **ordem de criticidade** (1 Vermelho … 6 Branco) + paleta. Ver [`../docs/parametros.md`](../docs/parametros.md). |
| `seeds/metas_demo.csv` | Valores de **referência de simulação** por indicador de tempo (`tipo_referencia = referencia_de_simulacao`), com uma `observacao` por linha. Servem só para demonstrar o cálculo de "% acima da referência". Ver [`../docs/parametros.md`](../docs/parametros.md). |

## Por que sintético, e não uma amostra anonimizada do real

Uma amostra "anonimizada" ainda carrega risco de reidentificação (data de
nascimento exata + diagnóstico raro + unidade, num hospital de porte conhecido).
Um dataset gerado do zero remove esse risco por completo — não porque foi "bem
anonimizado", mas porque **não existe indivíduo real por trás de nenhuma linha**.
`paciente_id_pseudonimo` é inteiramente sintética e serve só para ligar episódios
do mesmo paciente sintético.

## Calibração

Nenhuma linha vem de um registro real. As **categorias** (unidades, procedência,
classificação, desfecho) e as **ordens de grandeza estatísticas** (médias/medianas
por etapa, taxa de internação por classificação, relação Manchester → imagem →
internação → tempo) foram calibradas a partir de um extrato real usado **apenas
como referência de esquema**, nunca versionado (ver [`../PRIVACY.md`](../PRIVACY.md)).

**Imperfeições injetadas de propósito** (para dar sinal aos testes de qualidade,
ver [`../docs/data_quality.md`](../docs/data_quality.md)): ~3 % com um timestamp
de funil faltante, ~2 % com sequência temporal inválida, ~2 % com divergência
funil × log de eventos, ~1,9 % com desfecho "Nao informado/Em Atendimento".
