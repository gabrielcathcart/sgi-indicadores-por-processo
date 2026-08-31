# Ficha Técnica — Boarding pós-AIH (finalização da AIH → internação efetiva)

> Exemplo preenchido com dado sintético, na estrutura de
> [`template_ficha_tecnica.md`](./template_ficha_tecnica.md). O valor de
> referência é de **simulação** — ver [`../docs/parametros.md`](../docs/parametros.md).

---

**1. Nome** — `tempo_finalizacao_aih_internacao` (boarding pós-AIH): tempo entre a
finalização da AIH e a internação efetiva no leito.

**2. Pergunta que responde** — Quanto tempo o paciente com internação já
autorizada espera até ser admitido no leito?

**3. Fórmula** — mediana (e P75, P90, P95) de
`(dt_internacao_efetiva − dt_finalizacao_aih)`, em minutos, sobre os episódios
elegíveis.

**4. Grão** — 1 linha por atendimento
(`tempo_finalizacao_aih_internacao_min` em `fct_urgencia_atendimentos`).

**5. Início e fim do evento** — `dt_finalizacao_aih` → `dt_internacao_efetiva`.
"Finalização da AIH → internação efetiva" é uma **definição de modelagem deste
case**; em produção, o par de marcos precisa ser validado com regulação,
internação e áreas operacionais.

**6. População aplicável** — episódios com `desfecho_urgencia = 'Internado'`
(~2.143 no dado sintético). Todo desfecho ≠ Internado fica fora do denominador.

**7. Critérios de elegibilidade** —
`flag_elegivel_tempo_finalizacao_aih_internacao`: os dois marcos presentes e em
sequência válida (`dt_internacao_efetiva >= dt_finalizacao_aih`).

**8. Tratamento de nulos e sequência inválida** — marco ausente → indicador NULL,
nunca zero, e o episódio sai da cobertura; sequência inválida → episódio fora das
métricas elegíveis, mantido no painel de qualidade.

**9. Frequência e recorte** — apuração diária; segmentações úteis:
`especialidade_internacao`, `periodo_admissao`, `classificacao_manchester`, mês.

**10. Fonte / modelo** — `int_urgencia__tempos.sql` → `fct_urgencia_atendimentos`
→ `agg_urgencia__tempos` (indicador `tempo_finalizacao_aih_internacao`),
`agg_urgencia__internacao_especialidade`, `agg_urgencia__tempos_evento`.

**11. Limitações** — **não** mede ocupação nem disponibilidade de leito; é tempo
de espera pós-AIH. No gerador, a etapa foi parametrizada em escala de horas para
representar um cenário de espera por internação — por isso aparece como a de maior
duração **no exercício**, não como achado sobre nenhuma instituição. A leitura
deve ser confirmada com dados operacionais.

**12. Referência ou meta** — ≤ 360 min, **referência de simulação** — não é SLA,
contrato, protocolo nem meta institucional, e não tem fonte bibliográfica. O nome
físico da coluna mantém `meta_demo`.

---

## Resultado sobre o dataset sintético

`agg_urgencia__tempos`, indicador `tempo_finalizacao_aih_internacao`, linha
`Todos` (seed 42): cobertura 100 % da população aplicável · mediana ≈ 285 min ·
P90 ≈ 919 min · P95 ≈ 1.230 min. Saída do gerador calibrado — muda se a seed ou o
volume mudarem.
