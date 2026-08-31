# Nota sobre Dados e Privacidade

## Resumo

**Nenhum dado real de paciente, de profissional de saúde ou de operação está
presente neste repositório.** Os datasets, scripts e figuras publicados aqui são
sintéticos, criados especificamente para esta publicação.

## Contexto e por quê

Este recorte se inspira no trabalho institucional de gestão da informação, que
opera sobre dados do prontuário eletrônico e do ERP hospitalar (MV SOUL/Oracle).
Esses dados incluem, entre outros campos, nome do paciente, data de nascimento,
diagnóstico (CID) e nome dos profissionais responsáveis pelo atendimento.

Nos termos do art. 5º, inciso II, da Lei Geral de Proteção de Dados (Lei nº
13.709/2018), **dado de saúde é dado pessoal sensível**. Mesmo com finalidade
legítima de gestão institucional (art. 23 da LGPD), o tratamento desse tipo de
dado exige controles de acesso, finalidade e minimização que **não são
compatíveis com um repositório público de portfólio**.

Por isso, nenhum artefato do ambiente institucional — dataset, consulta com nomes
de tabelas reais, documento interno — é publicado aqui. O que está no repositório
foi construído do zero contra dados sintéticos.

## O que é sintético neste repositório

| Item | O que seria no ambiente institucional | O que está publicado aqui |
|---|---|---|
| Dados de atendimento | Extrato do ERP com nome de paciente, data de nascimento, CID, nome de médico/prestador, texto clínico livre | Dois CSVs sintéticos gerados por [`scripts/gerar_urgencia_sintetico.py`](./scripts/gerar_urgencia_sintetico.py): `data/synthetic/urgencia_episodios_raw.csv` (1 linha/episódio) e `urgencia_eventos_raw.csv` (1 linha/evento). Nenhum nome é gerado; paciente e profissional aparecem só como código. |
| Chave de paciente | Identificador que vincula episódios de uma pessoa real | `paciente_id_pseudonimo`: chave **inteiramente sintética** (`PAC` + contador), estável entre episódios do mesmo paciente sintético, sem relação com nome/CPF/prontuário e sem possibilidade de reidentificação. |
| Transformação | Regras de negócio versionadas contra o schema real do ERP | Projeto **dbt-core + dbt-duckdb** novo, escrito para este recorte, contra o schema dos CSVs sintéticos. |
| Referência de esquema | Um extrato real usado localmente para calibrar categorias e ordens de grandeza | **Nunca versionado.** Ver [`data/README.md`](./data/README.md). |
| Fichas técnicas de indicador | Documentos institucionais controlados, com nomes de colaboradores e código de controle interno | Template genérico + exemplos preenchidos com dado sintético. |

## Autorização

A publicação deste recorte, com uso exclusivo de dados sintéticos, foi autorizada
pela superintendência da instituição. Nomes de colaboradores não são citados,
com exceção de crédito explícito e autorizado à autoria da metodologia de
referência (Israel Stahl, Enfermeiro da Qualidade). A autorização cobre a
publicação do recorte técnico; **não** há neste repositório números operacionais
da instituição.

## Se você é da área de dados em saúde

Se está usando este repositório como referência para seu próprio projeto: trate
qualquer dataset com CID, nome de paciente ou nome de profissional de saúde como
dado sensível por padrão. Anonimização "cosmética" (remover só o nome, manter data
de nascimento exata + CEP + diagnóstico raro, por exemplo) frequentemente ainda
permite reidentificação. Quando o objetivo é portfólio, demonstração ou
treinamento, dado sintético bem desenhado — que preserva a distribuição
estatística sem corresponder a nenhuma pessoa real — quase sempre é a escolha
certa.
