"""
relatorio_qualidade.py
--------------------------------------------------------------------
Relatorio de qualidade de dados REPRODUZIVEL da jornada de urgencia.
Le os modelos ja materializados pelo dbt (target/sgi_urgencia.duckdb) e
imprime um resumo unico. Nenhuma transformacao acontece aqui.

Pre-requisito:  dbt seed && dbt build

Uso:
    python scripts/relatorio_qualidade.py
    python scripts/relatorio_qualidade.py --duckdb target/sgi_urgencia.duckdb --md docs/_gerado_qualidade.md
--------------------------------------------------------------------
"""
import argparse
import io
import os

import duckdb

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tabela(con, sql):
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    w = [max(len(str(c)), *(len(str(r[i])) for r in rows)) if rows else len(str(c))
         for i, c in enumerate(cols)]
    out = io.StringIO()
    out.write("| " + " | ".join(str(c).ljust(w[i]) for i, c in enumerate(cols)) + " |\n")
    out.write("|" + "|".join("-" * (w[i] + 2) for i in range(len(cols))) + "|\n")
    for r in rows:
        out.write("| " + " | ".join(str(v).ljust(w[i]) for i, v in enumerate(r)) + " |\n")
    return out.getvalue()


SECOES = [
    ("1. Volumes",
     "select metrica, qt, pct_do_total_atendimentos as pct from analytics.dq_urgencia__resumo where ordem in (1,2,3) order by ordem"),
    ("2. Falhas intencionais no RAW e tratamento no MART",
     """select metrica, qt, pct_do_total_atendimentos as pct
        from analytics.dq_urgencia__resumo where ordem in (4,5,6,7,8,9,13,14) order by ordem"""),
    ("3. Completude por timestamp (populacao esperada = etapas aplicaveis)",
     "select campo_timestamp, regra_esperado, n_esperado, n_preenchido, pct_preenchido from analytics.dq_urgencia__cobertura_timestamps order by ordem"),
    ("4. Cobertura e dispersao por indicador de tempo (linha 'Todos')",
     """select indicador, n_aplicavel, n_elegivel, cobertura_pct, qt_sequencia_invalida,
               mediana_min, p75_min, p90_min, p95_min, qt_outlier, pct_acima_meta_demo
        from analytics.agg_urgencia__tempos where classificacao_manchester = 'Todos' order by indicador_ordem"""),
    ("5. Distribuicao — Classificacao de Manchester (ordem de criticidade)",
     """select classificacao_manchester, manchester_ordem_criticidade as ordem, sum(qt_atendimentos) as qt
        from analytics.agg_urgencia__perfil_demografico group by 1,2 order by 2"""),
    ("6. Distribuicao — Desfecho",
     """select desfecho_urgencia, sum(qt_atendimentos) as qt
        from analytics.agg_urgencia__desfecho_dia group by 1 order by qt desc"""),
    ("7. Distribuicao — Procedencia / Periodo",
     """select 'procedencia' as dim, procedencia as valor, sum(qt_admissoes) as qt
        from analytics.agg_urgencia__admissoes_dia group by 1,2
        union all
        select 'periodo', periodo_admissao, sum(qt_admissoes)
        from analytics.agg_urgencia__admissoes_dia group by 1,2
        order by dim, qt desc"""),
    ("8. Retorno em <=72h por mes (COMPLEMENTAR, nao KPI principal)",
     """select mes_referencia, qt_indice_avaliavel, qt_indice_com_retorno_72h, pct_retorno_72h,
               qt_episodios_que_sao_retorno
        from analytics.agg_urgencia__retorno_72h order by mes_referencia"""),
    ("9. Duplicidades",
     """select 'eventos duplicados (atendimento x tipo)' as verificacao,
               (select count(*) from analytics.dq_urgencia__resumo where metrica='evento_duplicado' and qt>0) as ocorrencias
        union all
        select 'atendimento_id duplicado no mart',
               (select count(*) - count(distinct atendimento_id) from marts.fct_urgencia_atendimentos)"""),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duckdb", default=os.environ.get(
        "DBT_DUCKDB_PATH", os.path.join(REPO, "target", "sgi_urgencia.duckdb")))
    ap.add_argument("--md", default=None, help="tambem grava o relatorio neste .md")
    args = ap.parse_args()
    if not os.path.exists(args.duckdb):
        raise SystemExit(f"Banco nao encontrado: {args.duckdb}\nRode 'dbt build' antes.")

    con = duckdb.connect(args.duckdb, read_only=True)
    buf = io.StringIO()
    buf.write("# Relatorio de qualidade — jornada de urgencia (dados sinteticos)\n\n")
    buf.write("Gerado por `scripts/relatorio_qualidade.py` a partir dos modelos dbt.\n\n")
    for titulo, sql in SECOES:
        buf.write(f"## {titulo}\n\n")
        buf.write(tabela(con, sql))
        buf.write("\n")
    con.close()

    print(buf.getvalue())
    if args.md:
        with open(args.md, "w", encoding="utf-8") as fh:
            fh.write(buf.getvalue())
        print(f"(gravado em {args.md})")


if __name__ == "__main__":
    main()
