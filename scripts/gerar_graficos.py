"""
gerar_graficos.py
--------------------------------------------------------------------
Gera as quatro figuras de referencia (mockups) do dashboard de urgencia, uma
por aba, lendo os modelos ja materializados pelo dbt no DuckDB local.

Pre-requisito:  dbt seed && dbt build   (cria target/sgi_urgencia.duckdb)

Uso:
    python scripts/gerar_graficos.py
    python scripts/gerar_graficos.py --duckdb target/sgi_urgencia.duckdb

Sao figuras de referencia com dados sinteticos. Nao substituem a especificacao
em docs/dashboard.md nem representam uma instancia publicada.
Nenhuma transformacao de dado acontece aqui: o script le os modelos e desenha.

Regras de titulo/subtitulo:
    - Titulo: o que a pessoa esta vendo.
    - Subtitulo: periodo, unidade, populacao ou granularidade.
    - Formula, elegibilidade e regras tecnicas ficam na documentacao.
--------------------------------------------------------------------
"""
import argparse
import os

import duckdb
import matplotlib
import matplotlib.pyplot as plt

matplotlib.use("Agg")

# --- Paleta -------------------------------------------------------------------
# Roxo = identidade visual geral (titulos, layout, serie unica sem significado
# semantico). Categorias com convencao semantica NAO usam roxo.
ROXO_CLARO = "#C4B5FD"
ROXO_MEDIO = "#A78BFA"
ROXO = "#7C3AED"
ROXO_ESCURO = "#4C1D95"
CINZA_TXT = "#374151"
CINZA_GRID = "#E5E7EB"
NEUTRO = "#64748B"

# Sexo -- paleta fixa e consistente nos quatro mockups.
COR_SEXO = {"Masculino": "#2563EB", "Feminino": "#EC4899", "Nao informado": "#94A3B8"}

# Manchester -- cores semanticas; espelha seeds/dim_manchester.csv (fonte unica).
COR_MANCHESTER = {
    "Vermelho": "#C0392B", "Laranja": "#E67E22", "Amarelo": "#F1C40F",
    "Verde": "#27AE60", "Azul": "#2980B9", "Branco": "#D5D8DC",
}
ORDEM_MANCHESTER = ["Vermelho", "Laranja", "Amarelo", "Verde", "Azul", "Branco"]

# Tempos de processo -- paleta padrao (mediana / P90 / P95 / cobertura / ref.).
COR_TEMPOS = {
    "mediana": "#7C3AED", "p90": "#EA580C", "p95": "#B91C1C",
    "cobertura": "#16A34A", "referencia": "#64748B",
}

# Desfecho -- paleta categorica sobria; a mesma categoria na mesma cor nos quatro
# mockups; nao reutiliza cores de Manchester.
COR_DESFECHO = {
    "Liberado": "#0D9488",
    "Internado": "#7C3AED",
    "Transferido de Hospital": "#475569",
    "Obito": "#1F2937",
    "Evasao": "#BE185D",
    "Alta a Pedido": "#A16207",
    "Nao informado/Em Atendimento": "#94A3B8",
}

# Periodo de admissao -- ordem natural (madrugada -> noite); rampa roxa (sem
# significado semantico proprio).
COR_PERIODO = {"Madrugada": ROXO_CLARO, "Manha": ROXO_MEDIO, "Tarde": ROXO, "Noite": ROXO_ESCURO}
ORDEM_PERIODO = ["Madrugada", "Manha", "Tarde", "Noite"]

plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 10.5, "text.color": CINZA_TXT,
    "axes.edgecolor": CINZA_GRID, "axes.labelcolor": CINZA_TXT,
    "xtick.color": CINZA_TXT, "ytick.color": CINZA_TXT,
    "axes.grid": True, "grid.color": CINZA_GRID, "grid.linewidth": 0.8,
    "figure.facecolor": "white", "axes.facecolor": "white", "savefig.facecolor": "white",
})

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "assets", "mockups")


def semanas_plenas(datas):
    """Ordena as semanas (segunda-feira do date_trunc) e descarta a primeira e a
    ultima, que sao parciais por causa da janela fechada jan-jun/2025."""
    s = sorted(set(datas))
    return s[1:-1] if len(s) > 3 else s


def rodape(fig):
    fig.text(0.01, 0.012,
             "Figura de referencia  -  dados sinteticos  -  nao e uma instancia publicada",
             fontsize=7.5, color="#9CA3AF")


def sem_moldura(ax, manter=("left", "bottom")):
    for lado, spine in ax.spines.items():
        spine.set_visible(lado in manter)


def titulo(ax, txt, sub=None):
    ax.set_title(txt, fontsize=13, fontweight="bold", color=ROXO_ESCURO,
                 loc="left", pad=(28 if sub else 12))
    if sub:
        ax.text(0, 1.05, sub, transform=ax.transAxes, fontsize=8.5, color=NEUTRO, va="bottom")


def rot_semana(ax, semanas):
    ax.set_xticks(list(range(len(semanas)))[::2])
    ax.set_xticklabels([f"{s.day:02d}/{s.month:02d}" for s in semanas[::2]],
                       fontsize=8, rotation=45, ha="right")


# --- Aba 1 -----------------------------------------------------------------
def fig_entrada_capacidade(con):
    serie = con.execute("""
        select date_trunc('week', data_entrada) sem, periodo_admissao,
               sum(qt_admissoes) adm
        from analytics.agg_urgencia__admissoes_dia
        group by 1, 2 order by 1, 2
    """).fetchall()
    heat = con.execute("""
        select dia_semana_iso, hora_retirada_senha, sum(qt_admissoes)
        from analytics.agg_urgencia__heatmap_semana_hora group by 1,2
    """).fetchall()

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12.5, 5), dpi=150)
    semanas = semanas_plenas(r[0] for r in serie)
    idx = {s: i for i, s in enumerate(semanas)}
    x = range(len(semanas))
    for per in ORDEM_PERIODO:
        y = [0] * len(semanas)
        for s, p, adm in serie:
            if p == per and s in idx:
                y[idx[s]] = adm
        ax1.plot(list(x), y, marker="o", markersize=3, linewidth=1.6,
                 color=COR_PERIODO[per], label=per)
    rot_semana(ax1, semanas)
    titulo(ax1, "Admissões de urgência", "Distribuição semanal por período")
    ax1.grid(axis="x", visible=False); sem_moldura(ax1)
    ax1.legend(frameon=False, fontsize=8.5, ncol=4, loc="lower center", bbox_to_anchor=(0.5, -0.30))

    grade = [[0] * 24 for _ in range(7)]
    for dow, h, n in heat:
        grade[dow - 1][h] = n
    im = ax2.imshow(grade, aspect="auto", cmap="Purples")
    ax2.set_yticks(range(7)); ax2.set_yticklabels(["Seg", "Ter", "Qua", "Qui", "Sex", "Sab", "Dom"])
    ax2.set_xticks(range(0, 24, 3)); ax2.set_xticklabels([f"{h:02d}h" for h in range(0, 24, 3)])
    ax2.grid(False)
    titulo(ax2, "Distribuicao das admissoes por dia e hora", "Hora de retirada de senha")
    fig.colorbar(im, ax=ax2, shrink=0.8, label="admissoes")

    rodape(fig); fig.tight_layout(rect=[0, 0.06, 1, 0.92])
    p = os.path.join(OUT, "entrada_capacidade.png"); fig.savefig(p); plt.close(fig)
    return p


# --- Aba 2 -----------------------------------------------------------------
def fig_perfil(con):
    dem = con.execute("""
        select classificacao_faixa_etaria, sexo, sum(qt_atendimentos)
        from analytics.agg_urgencia__perfil_demografico group by 1,2
    """).fetchall()
    man = con.execute("""
        select date_trunc('week', data_referencia) sem, classificacao_manchester,
               manchester_ordem_criticidade, count(*)
        from marts.fct_urgencia_atendimentos
        group by 1,2,3 order by 1,3
    """).fetchall()

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12.5, 5), dpi=150)
    d = {(f, s): n for f, s, n in dem}
    faixas = ["Pediatrico", "Adulto"]
    y = range(len(faixas))
    ax1.barh([i + 0.19 for i in y], [d.get((f, "Masculino"), 0) for f in faixas],
             height=0.36, color=COR_SEXO["Masculino"], label="Masculino")
    ax1.barh([i - 0.19 for i in y], [d.get((f, "Feminino"), 0) for f in faixas],
             height=0.36, color=COR_SEXO["Feminino"], label="Feminino")
    ax1.set_yticks(list(y)); ax1.set_yticklabels(faixas)
    titulo(ax1, "Perfil dos atendimentos", "Faixa etária e sexo")
    ax1.grid(axis="y", visible=False); sem_moldura(ax1)
    ax1.legend(frameon=False, fontsize=8.5, loc="lower right")

    semanas = semanas_plenas(r[0] for r in man)
    idx = {s: i for i, s in enumerate(semanas)}
    x = range(len(semanas))
    base = [0.0] * len(semanas)
    for nome in ORDEM_MANCHESTER:
        vals = [0.0] * len(semanas)
        for s, n, _o, q in man:
            if n == nome and s in idx:
                vals[idx[s]] = q
        ax2.bar(list(x), vals, bottom=base, color=COR_MANCHESTER[nome], label=nome,
                edgecolor="#7F8C8D", linewidth=(0.7 if nome == "Branco" else 0))
        base = [b + v for b, v in zip(base, vals)]
    rot_semana(ax2, semanas)
    titulo(ax2, "Classificacao de risco (Manchester)", "Atendimentos por semana")
    ax2.grid(axis="x", visible=False); sem_moldura(ax2)
    ax2.legend(frameon=False, fontsize=7.5, ncol=6, loc="lower center", bbox_to_anchor=(0.5, -0.28))

    rodape(fig); fig.tight_layout(rect=[0, 0.06, 1, 0.92])
    p = os.path.join(OUT, "perfil.png"); fig.savefig(p); plt.close(fig)
    return p


# --- Aba 3 -----------------------------------------------------------------
def fig_desfecho(con):
    serie = con.execute("""
        select date_trunc('week', data_desfecho) sem, desfecho_urgencia,
               sum(qt_atendimentos) q
        from analytics.agg_urgencia__desfecho_dia
        where data_desfecho is not null
        group by 1, 2 order by 1
    """).fetchall()
    esp = con.execute("""
        select especialidade_internacao, sum(qt_internacoes) q,
               max(p90_boarding_min) p90
        from analytics.agg_urgencia__internacao_especialidade
        group by 1 order by 2 desc
    """).fetchall()

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12.5, 5.4), dpi=150)
    ordem_desf = ["Liberado", "Internado", "Transferido de Hospital", "Obito",
                  "Evasao", "Alta a Pedido", "Nao informado/Em Atendimento"]
    semanas = semanas_plenas(r[0] for r in serie)
    idx = {s: i for i, s in enumerate(semanas)}
    x = range(len(semanas))
    for des in ordem_desf:
        y = [0] * len(semanas)
        for s, d, q in serie:
            if d == des and s in idx:
                y[idx[s]] = q
        if not any(y):
            continue
        ax1.plot(list(x), y, marker="o", markersize=3, linewidth=1.6,
                 color=COR_DESFECHO[des],
                 label="Em Atendimento" if des.startswith("Nao informado") else des)
    rot_semana(ax1, semanas)
    titulo(ax1, "Desfechos de urgencia", "Registros com data de desfecho, por semana")
    ax1.grid(axis="x", visible=False); sem_moldura(ax1)
    ax1.legend(frameon=False, fontsize=7.5, ncol=3, loc="lower center", bbox_to_anchor=(0.5, -0.30))

    nomes = [r[0] for r in esp]
    vals = [r[1] for r in esp]
    yy = range(len(nomes))
    barras = ax2.barh(list(yy), vals, color=ROXO, height=0.62)
    ax2.set_yticks(list(yy)); ax2.set_yticklabels(nomes, fontsize=8); ax2.invert_yaxis()
    for b, v, p90 in zip(barras, vals, [r[2] for r in esp]):
        ax2.text(b.get_width() + max(vals) * 0.01, b.get_y() + b.get_height() / 2,
                 f"{v}  ·  P90 {p90 / 60:.0f}h", va="center", fontsize=7.5)
    titulo(ax2, "Internacoes por especialidade", "Atendimentos com desfecho de internacao")
    ax2.grid(axis="y", visible=False); sem_moldura(ax2)

    rodape(fig); fig.tight_layout(rect=[0, 0.07, 1, 0.92])
    p = os.path.join(OUT, "desfecho.png"); fig.savefig(p); plt.close(fig)
    return p


# --- Aba 4 -----------------------------------------------------------------
def fig_tempos_processo(con):
    rows = con.execute("""
        select indicador, indicador_ordem, mediana_min, p90_min, p95_min,
               cobertura_pct, n_elegivel
        from analytics.agg_urgencia__tempos
        where classificacao_manchester = 'Todos' order by indicador_ordem desc
    """).fetchall()
    rot = {
        "tempo_entrada_triagem": "Entrada -> Triagem",
        "tempo_triagem": "Duracao da Triagem",
        "tempo_triagem_consulta": "Triagem -> Consulta",
        "tempo_consulta": "Consulta (evolucao -> prescricao)",
        "tempo_solicitacao_realizacao_imagem": "Solicitacao -> Realizacao Imagem",
        "tempo_reavaliacao": "Reavaliacao (imagem -> conduta)",
        "tempo_finalizacao_aih_internacao": "AIH -> Internacao Efetiva",
    }
    etapas = [rot[r[0]] for r in rows]
    mediana = [r[2] for r in rows]
    p90 = [r[3] for r in rows]
    p95 = [r[4] for r in rows]
    cob = [r[5] for r in rows]

    fig, ax = plt.subplots(figsize=(12, 6), dpi=150)
    y = list(range(len(etapas)))
    ax.barh(y, mediana, color=COR_TEMPOS["mediana"], height=0.6)
    ax.plot(p90, y, "o", color=COR_TEMPOS["p90"], markersize=6, label="P90")
    ax.plot(p95, y, "D", color=COR_TEMPOS["p95"], markersize=4, label="P95")
    ax.set_xscale("log")
    ax.set_xlim(1, 6000)
    ax.set_yticks(y); ax.set_yticklabels(etapas)
    for yi, med, pp95, c in zip(y, mediana, p95, cob):
        r = f"{med:.0f} min" if med < 120 else f"{med / 60:.1f} h"
        ax.text(pp95 * 1.35, yi, f"{r}  ·  cobertura {c:.0f}%",
                va="center", fontsize=8, fontweight="bold")
    titulo(ax, "Tempos de processo", "Mediana, P90 e P95 · minutos")
    ax.set_xlabel("Minutos  ·  escala logaritmica")
    ax.grid(axis="y", visible=False); ax.grid(axis="x", which="both"); sem_moldura(ax)
    ax.legend(frameon=False, fontsize=8.5, loc="lower right",
              bbox_to_anchor=(1.0, 1.0), ncol=2)

    rodape(fig); fig.tight_layout(rect=[0, 0.04, 1, 0.9])
    p = os.path.join(OUT, "tempos_processo.png"); fig.savefig(p); plt.close(fig)
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duckdb", default=os.environ.get(
        "DBT_DUCKDB_PATH", os.path.join(REPO, "target", "sgi_urgencia.duckdb")))
    args = ap.parse_args()
    if not os.path.exists(args.duckdb):
        raise SystemExit(f"Banco nao encontrado: {args.duckdb}\nRode 'dbt build' antes.")
    os.makedirs(OUT, exist_ok=True)
    con = duckdb.connect(args.duckdb, read_only=True)
    for fn in (fig_entrada_capacidade, fig_perfil, fig_desfecho, fig_tempos_processo):
        print("Gerado:", os.path.relpath(fn(con), REPO))
    con.close()


if __name__ == "__main__":
    main()
