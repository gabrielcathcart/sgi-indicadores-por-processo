# Contexto e método

Onde este repositório se encaixa, qual problema analítico ele resolve e como os
indicadores são definidos. Detalhe técnico do pipeline:
[`architecture.md`](./architecture.md).

## 1. Contexto profissional

Trabalho com dados hospitalares num serviço de gestão da informação. Nesse
trabalho lido com arquitetura institucional de dados, dados homologados, camadas
semânticas de consumo, catálogo e linhagem, e indicadores acompanhados pela
gestão.

**Este repositório não é essa plataforma.** É um recorte técnico, com dados que
eu gerei para publicação, que demonstra práticas que aplico ou estudo nesse
trabalho: modelagem por processo, regras de qualidade sobre timestamps,
rastreabilidade de cada número até o dado bruto e preparação de datasets para
consumo analítico. Nenhum número institucional, estrutura de leitos, organograma
ou resultado de projeto real aparece aqui.

## 2. O problema do case

Numa urgência hospitalar, "tempo de triagem" ou "tempo até a internação" só são
comparáveis quando quatro coisas ficam explícitas:

- **Grão** — uma linha por atendimento, não por evento;
- **Timestamps** — o par nomeado que abre e fecha cada etapa;
- **Elegibilidade** — quais episódios entram no cálculo de uma etapa e quais
  entram apenas na cobertura;
- **Sequência válida** — o fim depois do início; a inversão é sinalizada, não
  descartada em silêncio.

Registro incompleto é a regra. Um marco não anotado, anotado com atraso ou fora
de ordem não pode virar zero nem desaparecer: precisa reduzir a cobertura da
etapa e ficar visível. O foco é o **fluxo** do atendimento e seus tempos — não
dado clínico, diagnóstico ou conduta.

## 3. Método de definição de indicadores

**Ficha técnica.** Cada indicador tem uma ficha que fixa pergunta, fórmula, grão,
marcos de início e fim, população aplicável, critérios de elegibilidade,
tratamento de nulos e limitações. O critério prático: uma pessoa fora do
processo, lendo só a ficha, chega ao mesmo número a partir dos mesmos dados
brutos. Template em
[`../indicadores/template_ficha_tecnica.md`](../indicadores/template_ficha_tecnica.md);
exemplo preenchido em
[`../indicadores/ficha_boarding.md`](../indicadores/ficha_boarding.md).

**Dimensão da qualidade (Donabedian).** Referência simples para classificar o que
cada indicador mede:

| Dimensão | No case |
|---|---|
| Estrutura | disponibilidade e recursos — não modelada diretamente aqui |
| Processo | as etapas e os tempos do atendimento — o foco deste repositório |
| Resultado | o desfecho do atendimento e a internação |

## 4. Limites

- Os dados são **sintéticos**, calibrados à mão para ordem de grandeza plausível;
  não medem nenhuma instituição.
- O dashboard é **especificação + mockups**, não uma instância publicada.
- As definições de etapa e os valores de referência de tempo precisariam de
  **validação com as áreas operacionais** e de dados homologados antes de
  qualquer uso em produção.
