# Template — Ficha Técnica de Indicador

> Formulário em branco, preenchido a cada novo indicador. O critério de validação
> é prático: **uma pessoa fora do processo, lendo só a ficha, chega ao mesmo
> resultado a partir dos mesmos dados brutos.**
>
> No contexto institucional, a ficha completa pode ter campos adicionais de
> governança e pactuação. Este template preserva apenas os campos usados neste
> case.

---

**1. Nome** — `___`

**2. Pergunta que responde** — `___`

**3. Fórmula** — `___` (a mais simples possível)

**4. Grão** — `___` (a que corresponde uma linha: atendimento, atendimento ×
indicador, …)

**5. Início e fim do evento** — `___` → `___` (o par de marcos que delimita a
medida)

**6. População aplicável** — `___` (quais episódios a etapa alcança; os demais
ficam fora do denominador)

**7. Critérios de elegibilidade** — `___` (o que precisa estar presente e válido
para o episódio entrar no cálculo)

**8. Tratamento de nulos e sequência inválida** — `___` (timestamp ausente → NULL,
nunca zero; `dt_fim < dt_inicio` → episódio fora das métricas elegíveis)

**9. Frequência e recorte** — `___` (periodicidade de apuração; segmentações
previstas)

**10. Fonte / modelo** — `___` (modelos dbt e colunas de origem)

**11. Limitações** — `___` (o que o indicador não mede; dependências de registro)

**12. Referência ou meta, quando houver** — `___` (o valor e a sua natureza:
pactuada com a operação, referência de simulação, literatura)

---

Exemplo preenchido, com dado sintético:
[`ficha_boarding.md`](./ficha_boarding.md).
