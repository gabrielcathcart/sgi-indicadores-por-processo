"""
gerar_urgencia_sintetico.py
--------------------------------------------------------------------
Gerador DETERMINISTICO dos dois datasets sinteticos da jornada de urgencia.

    data/synthetic/urgencia_episodios_raw.csv   (1 linha por atendimento/episodio)
    data/synthetic/urgencia_eventos_raw.csv     (1 linha por evento operacional)

Periodo de ENTRADA (fechado): 2025-01-01 a 2025-06-30.
Volume padrao: ~12.000 episodios.

Nada e aleatorio "sem logica de negocio": sazonalidade por dia da semana e hora,
variacao de demanda por periodo, relacao entre criticidade de Manchester e
chance de imagem / internacao / tempos, timestamps em ordem coerente, nulos
controlados para etapas nao aplicaveis, parcela documentada de retornos <=72h e
parcela documentada de inconsistencias artificiais (que os testes de qualidade
capturam e o mart isola).

Nenhum dado pessoal. `paciente_id_pseudonimo` = "PAC" + contador; estavel entre
episodios do mesmo paciente sintetico; nao reidentifica.

Uso:
    python scripts/gerar_urgencia_sintetico.py --episodios 12000 --seed 42 \
        --inicio 2025-01-01 --fim 2025-06-30 --out-dir data/synthetic
--------------------------------------------------------------------
"""
from __future__ import annotations

import argparse
import csv
import math
import os
import random
from datetime import datetime, timedelta

FMT = "%Y-%m-%d %H:%M:%S"

# --------------------------------------------------------------------------
# Dominios (rotulos de negocio; nada extraido de sistema real)
# --------------------------------------------------------------------------
MANCHESTER = ["Vermelho", "Laranja", "Amarelo", "Verde", "Azul", "Branco"]
MANCHESTER_ORDEM = {"Vermelho": 1, "Laranja": 2, "Amarelo": 3, "Verde": 4, "Azul": 5, "Branco": 6}
PESO_MANCHESTER = [0.03, 0.14, 0.33, 0.38, 0.08, 0.04]

PROCEDENCIAS = ["Demanda Espontanea", "Atendimento Primario", "UPA/CRS", "Interior", "Hospital"]
PESO_PROCEDENCIA = [0.50, 0.18, 0.15, 0.10, 0.07]

PERIODOS = ["Madrugada", "Manha", "Tarde", "Noite"]  # 0-5 / 6-11 / 12-17 / 18-23

DESFECHOS_INTERNACAO = ["Internado", "Obito", "Transferido de Hospital"]
PESO_DESF_INTERNACAO = [0.965, 0.020, 0.015]
DESFECHOS_NAO_INT = ["Liberado", "Evasao", "Alta a Pedido", "Transferido de Hospital",
                     "Obito", "Nao informado/Em Atendimento"]
PESO_DESF_NAO_INT = [0.865, 0.045, 0.030, 0.030, 0.008, 0.022]

ESPECIALIDADES = ["Clinica Medica", "Cirurgia Geral", "Ortopedia/Traumatologia", "Cardiologia",
                  "Neurologia", "Neurocirurgia", "Pneumologia", "Gastroenterologia"]
PESO_ESPECIALIDADE = [0.34, 0.16, 0.14, 0.12, 0.09, 0.06, 0.05, 0.04]

ORIGEM_REGISTRO = {
    "retirada_senha": "totem_recepcao",
    "entrada_urgencia": "painel_pa",
    "inicio_triagem": "sistema_triagem",
    "fim_triagem": "sistema_triagem",
    "inicio_consulta": "prontuario_eletronico",
    "abertura_evolucao": "prontuario_eletronico",
    "prescricao": "prontuario_eletronico",
    "solicitacao_imagem": "prontuario_eletronico",
    "realizacao_imagem": "sistema_ris_pacs",
    "conduta": "prontuario_eletronico",
    "solicitacao_internacao": "sistema_regulacao",
    "finalizacao_aih": "sistema_regulacao",
    "internacao_efetiva": "painel_leitos",
    "desfecho": "prontuario_eletronico",
}

# probabilidade de internacao / imagem por classificacao
P_INTERNA = {"Vermelho": 0.72, "Laranja": 0.48, "Amarelo": 0.22, "Verde": 0.06, "Azul": 0.02, "Branco": 0.01}
P_IMAGEM = {"Vermelho": 0.90, "Laranja": 0.86, "Amarelo": 0.78, "Verde": 0.55, "Azul": 0.42, "Branco": 0.30}

# medias (min) por etapa, moduladas pela criticidade
MEDIA_SENHA_ENTRADA = 6                      # retirada de senha -> entrada na urgencia
MEDIA_ENTRADA_TRIAGEM = {"Vermelho": 2, "Laranja": 5, "Amarelo": 9, "Verde": 14, "Azul": 18, "Branco": 22}
MEDIA_TRIAGEM = 3
MEDIA_TRIAGEM_CONSULTA = {"Vermelho": 4, "Laranja": 12, "Amarelo": 30, "Verde": 52, "Azul": 68, "Branco": 78}
MEDIA_CONSULTA_ABERTURA = 4                  # inicio da consulta -> abertura da evolucao
MEDIA_EVOLUCAO_PRESCRICAO = 22               # abertura da evolucao -> prescricao  (== "tempo de consulta")
MEDIA_PRESC_SOLIC_IMAGEM = 8
MEDIA_SOLIC_REALIZ_IMAGEM = 55
MEDIA_REALIZ_CONDUTA = 40                    # reavaliacao pos-imagem
MEDIA_PRESC_CONDUTA_SEM_IMAGEM = 35
MEDIA_CONDUTA_SOLIC_INT = 15
MEDIA_SOLIC_FIN_AIH = 45
MEDIA_FIN_AIH_INTERNACAO = 430              # boarding pos-AIH
MEDIA_CONDUTA_DESFECHO_LIBERADO = 40

PESO_HORA = [0.35, 0.30, 0.27, 0.27, 0.33, 0.48,
             0.62, 0.86, 0.98, 1.00, 1.00, 1.10,
             1.16, 1.10, 1.20, 1.24, 1.22, 1.18,
             1.12, 1.05, 1.00, 0.90, 0.72, 0.52]
PESO_DIA = {0: 1.00, 1: 1.00, 2: 1.00, 3: 1.00, 4: 1.03, 5: 0.91, 6: 0.85}


def logn(rng, media, cv):
    media = max(media, 0.1)
    sigma = math.sqrt(math.log(1.0 + cv * cv))
    mu = math.log(media) - 0.5 * sigma * sigma
    return max(0.0, rng.lognormvariate(mu, sigma))


def esc(rng, itens, pesos):
    return rng.choices(itens, weights=pesos, k=1)[0]


def periodo_de_hora(h):
    return PERIODOS[0] if h < 6 else PERIODOS[1] if h < 12 else PERIODOS[2] if h < 18 else PERIODOS[3]


def sortear_entrada(rng, inicio, fim):
    dias = (fim.date() - inicio.date()).days
    while True:
        d = inicio.date() + timedelta(days=rng.randint(0, dias))
        if rng.random() < PESO_DIA[d.weekday()]:
            break
    h = esc(rng, list(range(24)), PESO_HORA)
    return datetime(d.year, d.month, d.day, h, rng.randint(0, 59), rng.randint(0, 59))


def add(ts, minutos):
    return ts + timedelta(minutes=minutos) if ts is not None else None


def construir_jornada(rng, dt_senha, manch):
    """Timestamps 'limpos' de um episodio, em ordem coerente."""
    j = {"dt_retirada_senha": dt_senha}
    j["dt_entrada"] = add(dt_senha, logn(rng, MEDIA_SENHA_ENTRADA, 0.8))
    j["dt_inicio_triagem"] = add(j["dt_entrada"], logn(rng, MEDIA_ENTRADA_TRIAGEM[manch], 0.8))
    j["dt_fim_triagem"] = add(j["dt_inicio_triagem"], logn(rng, MEDIA_TRIAGEM, 0.5))
    j["dt_inicio_consulta"] = add(j["dt_fim_triagem"], logn(rng, MEDIA_TRIAGEM_CONSULTA[manch], 0.9))
    j["dt_abertura_evolucao"] = add(j["dt_inicio_consulta"], logn(rng, MEDIA_CONSULTA_ABERTURA, 0.6))
    fator = {"Vermelho": 1.30, "Laranja": 1.15}.get(manch, 1.0)
    j["dt_prescricao"] = add(j["dt_abertura_evolucao"], logn(rng, MEDIA_EVOLUCAO_PRESCRICAO * fator, 0.7))

    tem_imagem = rng.random() < P_IMAGEM[manch]
    j["dt_solicitacao_imagem"] = None
    j["dt_realizacao_imagem"] = None
    if tem_imagem:
        j["dt_solicitacao_imagem"] = add(j["dt_prescricao"], logn(rng, MEDIA_PRESC_SOLIC_IMAGEM, 0.7))
        j["dt_realizacao_imagem"] = add(j["dt_solicitacao_imagem"], logn(rng, MEDIA_SOLIC_REALIZ_IMAGEM, 0.8))
        j["dt_conduta"] = add(j["dt_realizacao_imagem"], logn(rng, MEDIA_REALIZ_CONDUTA, 0.8))
    else:
        j["dt_conduta"] = add(j["dt_prescricao"], logn(rng, MEDIA_PRESC_CONDUTA_SEM_IMAGEM, 0.8))

    j["dt_solicitacao_internacao"] = None
    j["dt_finalizacao_aih"] = None
    j["dt_internacao_efetiva"] = None
    j["dt_desfecho"] = None
    j["_tem_imagem"] = tem_imagem
    return j


def desloca_tudo(j, delta):
    for k, v in list(j.items()):
        if k.startswith("dt_") and isinstance(v, datetime):
            j[k] = v + delta
    return j


def gerar_episodio(rng, inicio, fim):
    dt_senha = sortear_entrada(rng, inicio, fim)
    manch = esc(rng, MANCHESTER, PESO_MANCHESTER)

    pediatrico = rng.random() < 0.18
    if pediatrico:
        idade = min(17, max(0, int(rng.triangular(0, 17, 6))))
    else:
        idade = min(105, max(18, int(rng.gauss(46, 19))))
    faixa = "Pediatrico" if idade < 18 else "Adulto"
    sexo = esc(rng, ["Masculino", "Feminino"], [0.51, 0.49])
    procedencia = esc(rng, PROCEDENCIAS, PESO_PROCEDENCIA)

    j = construir_jornada(rng, dt_senha, manch)

    internou = rng.random() < P_INTERNA[manch]
    especialidade = ""
    if internou:
        desfecho = esc(rng, DESFECHOS_INTERNACAO, PESO_DESF_INTERNACAO)
        j["dt_solicitacao_internacao"] = add(j["dt_conduta"], logn(rng, MEDIA_CONDUTA_SOLIC_INT, 0.7))
        j["dt_finalizacao_aih"] = add(j["dt_solicitacao_internacao"], logn(rng, MEDIA_SOLIC_FIN_AIH, 0.8))
        if desfecho == "Internado":
            j["dt_internacao_efetiva"] = add(j["dt_finalizacao_aih"], logn(rng, MEDIA_FIN_AIH_INTERNACAO, 1.10))
            j["dt_desfecho"] = j["dt_internacao_efetiva"]
            especialidade = "Pediatria" if pediatrico else esc(rng, ESPECIALIDADES, PESO_ESPECIALIDADE)
        else:  # Obito / Transferido antes do leito
            j["dt_desfecho"] = add(j["dt_finalizacao_aih"], logn(rng, 70, 1.0))
    else:
        desfecho = esc(rng, DESFECHOS_NAO_INT, PESO_DESF_NAO_INT)
        if desfecho == "Obito" and manch not in ("Vermelho", "Laranja"):
            desfecho = "Liberado"
        if desfecho == "Nao informado/Em Atendimento":
            j["dt_desfecho"] = None                       # episodio ainda aberto
            j["dt_conduta"] = None if rng.random() < 0.5 else j["dt_conduta"]
        elif desfecho == "Evasao" and rng.random() < 0.55:
            # evadiu antes da consulta -> zera etapas medicas
            for k in ("dt_inicio_consulta", "dt_abertura_evolucao", "dt_prescricao",
                      "dt_solicitacao_imagem", "dt_realizacao_imagem", "dt_conduta"):
                j[k] = None
            j["_tem_imagem"] = False
            j["dt_desfecho"] = add(j["dt_fim_triagem"], logn(rng, 90, 1.0))
        else:
            base = j["dt_conduta"] or j["dt_prescricao"]
            extra = MEDIA_CONDUTA_DESFECHO_LIBERADO * (2.2 if desfecho == "Transferido de Hospital" else 1.0)
            j["dt_desfecho"] = add(base, logn(rng, extra, 0.9))

    hora = dt_senha.hour
    epi = {
        "atendimento_id": None,
        "paciente_id_pseudonimo": None,
        "dt_retirada_senha": j["dt_retirada_senha"],
        "dt_entrada": j["dt_entrada"],
        "dt_inicio_triagem": j["dt_inicio_triagem"],
        "dt_fim_triagem": j["dt_fim_triagem"],
        "dt_inicio_consulta": j["dt_inicio_consulta"],
        "dt_abertura_evolucao": j["dt_abertura_evolucao"],
        "dt_prescricao": j["dt_prescricao"],
        "dt_solicitacao_imagem": j["dt_solicitacao_imagem"],
        "dt_realizacao_imagem": j["dt_realizacao_imagem"],
        "dt_conduta": j["dt_conduta"],
        "dt_solicitacao_internacao": j["dt_solicitacao_internacao"],
        "dt_finalizacao_aih": j["dt_finalizacao_aih"],
        "dt_internacao_efetiva": j["dt_internacao_efetiva"],
        "dt_desfecho": j["dt_desfecho"],
        "periodo_admissao": periodo_de_hora(hora),
        "procedencia": procedencia,
        "sexo": sexo,
        "idade_anos": idade,
        "classificacao_faixa_etaria": faixa,
        "classificacao_manchester": manch,
        "manchester_ordem_criticidade": MANCHESTER_ORDEM[manch],
        "desfecho_urgencia": desfecho,
        "especialidade_internacao": especialidade,
        "possui_imagem": bool(j["_tem_imagem"]),
        "possui_internacao": bool(internou),
        "flag_dado_incompleto": False,
    }
    return epi


# ---- ordem canonica dos marcos p/ eventos e p/ deteccao de sequencia ----
MARCOS = [
    ("retirada_senha", "dt_retirada_senha"),
    ("entrada_urgencia", "dt_entrada"),
    ("inicio_triagem", "dt_inicio_triagem"),
    ("fim_triagem", "dt_fim_triagem"),
    ("inicio_consulta", "dt_inicio_consulta"),
    ("abertura_evolucao", "dt_abertura_evolucao"),
    ("prescricao", "dt_prescricao"),
    ("solicitacao_imagem", "dt_solicitacao_imagem"),
    ("realizacao_imagem", "dt_realizacao_imagem"),
    ("conduta", "dt_conduta"),
    ("solicitacao_internacao", "dt_solicitacao_internacao"),
    ("finalizacao_aih", "dt_finalizacao_aih"),
    ("internacao_efetiva", "dt_internacao_efetiva"),
    ("desfecho", "dt_desfecho"),
]


def aplicar_inconsistencias(rng, epis):
    n = len(epis)
    reg = {}

    # (a) 1 timestamp de funil faltante -> flag_dado_incompleto
    alvos_a = [e for e in epis if e["dt_inicio_consulta"] and e["desfecho_urgencia"] != "Evasao"]
    for e in rng.sample(alvos_a, k=int(round(n * 0.03))):
        campo = rng.choice(["dt_inicio_triagem", "dt_fim_triagem", "dt_abertura_evolucao"])
        e[campo] = None
        e["flag_dado_incompleto"] = True
    reg["timestamp_funil_faltante"] = int(round(n * 0.03))

    # (b) inversao de sequencia em 1 par -> duracao negativa naquele indicador
    alvos_b = [e for e in epis if e["dt_prescricao"] and e["dt_abertura_evolucao"]]
    for e in rng.sample(alvos_b, k=int(round(n * 0.02))):
        r = rng.random()
        if r < 0.4:
            e["dt_abertura_evolucao"], e["dt_prescricao"] = e["dt_prescricao"], e["dt_abertura_evolucao"]
        elif r < 0.7 and e["dt_inicio_triagem"] and e["dt_fim_triagem"]:
            e["dt_inicio_triagem"] = e["dt_inicio_triagem"] + timedelta(minutes=rng.randint(15, 60))
        elif e["dt_solicitacao_imagem"] and e["dt_realizacao_imagem"]:
            e["dt_realizacao_imagem"] = e["dt_solicitacao_imagem"] - timedelta(minutes=rng.randint(10, 45))
        else:
            e["dt_inicio_triagem"] = (e["dt_inicio_triagem"] or e["dt_entrada"]) + timedelta(minutes=30)
    reg["sequencia_invalida"] = int(round(n * 0.02))

    # (c) divergencia evento x episodio -> 1 evento deslocado / estimado
    for e in rng.sample(epis, k=int(round(n * 0.02))):
        e["_divergir"] = rng.choice(["inicio_consulta", "fim_triagem", "realizacao_imagem"])
    reg["evento_timestamp_estimado_extra"] = int(round(n * 0.02))

    reg["desfecho_nao_informado_em_atendimento"] = sum(
        1 for e in epis if e["desfecho_urgencia"] == "Nao informado/Em Atendimento")
    return reg


def main():
    ap = argparse.ArgumentParser(description="Gera os CSVs sinteticos da jornada de urgencia.")
    ap.add_argument("--episodios", type=int, default=12000)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--inicio", type=str, default="2025-01-01")
    ap.add_argument("--fim", type=str, default="2025-06-30")
    ap.add_argument("--out-dir", type=str, default="data/synthetic")
    ap.add_argument("--retorno-frac", type=float, default=0.03)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    inicio = datetime.fromisoformat(args.inicio)
    fim = datetime.fromisoformat(args.fim)
    limite = fim.replace(hour=23, minute=59, second=59)

    n_total = args.episodios
    n_ret = int(round(n_total * args.retorno_frac))
    n_prim = n_total - n_ret
    n_pac = max(1, int(round(n_prim * 0.80)))
    pacientes = [f"PAC{100000 + i}" for i in range(n_pac)]

    epis = [gerar_episodio(rng, inicio, fim) for _ in range(n_prim)]
    for e in epis:
        e["paciente_id_pseudonimo"] = pacientes[int(n_pac * (rng.random() ** 1.3)) % n_pac]

    # retornos: mesmo paciente, entrada 6-66h (85%) ou 74-120h (15%) apos o
    # desfecho de um episodio-indice com desfecho valido dentro da janela.
    indices = [e for e in epis
               if e["dt_desfecho"] and e["dt_desfecho"] + timedelta(hours=120) <= limite]
    for _ in range(n_ret):
        base = rng.choice(indices)
        atraso_h = rng.uniform(6, 66) if rng.random() < 0.85 else rng.uniform(74, 120)
        nova = base["dt_desfecho"] + timedelta(hours=atraso_h)
        e = gerar_episodio(rng, inicio, fim)
        desloca_tudo(e, nova - e["dt_retirada_senha"])
        e["periodo_admissao"] = periodo_de_hora(e["dt_retirada_senha"].hour)
        e["paciente_id_pseudonimo"] = base["paciente_id_pseudonimo"]
        epis.append(e)

    registro_inconsistencias = aplicar_inconsistencias(rng, epis)

    epis.sort(key=lambda e: (e["dt_retirada_senha"], e["paciente_id_pseudonimo"]))
    for i, e in enumerate(epis):
        e["atendimento_id"] = 5_000_000 + i

    os.makedirs(args.out_dir, exist_ok=True)
    p_epi = os.path.join(args.out_dir, "urgencia_episodios_raw.csv")
    p_ev = os.path.join(args.out_dir, "urgencia_eventos_raw.csv")

    def f(v):
        if v is None:
            return ""
        if isinstance(v, datetime):
            return v.strftime(FMT)
        if isinstance(v, bool):
            return "true" if v else "false"
        return v

    cols = [
        "atendimento_id", "paciente_id_pseudonimo", "dt_retirada_senha", "dt_entrada",
        "dt_inicio_triagem", "dt_fim_triagem", "dt_inicio_consulta", "dt_abertura_evolucao",
        "dt_prescricao", "dt_solicitacao_imagem", "dt_realizacao_imagem", "dt_conduta",
        "dt_solicitacao_internacao", "dt_finalizacao_aih", "dt_internacao_efetiva", "dt_desfecho",
        "periodo_admissao", "procedencia", "sexo", "idade_anos", "classificacao_faixa_etaria",
        "classificacao_manchester", "manchester_ordem_criticidade", "desfecho_urgencia",
        "especialidade_internacao", "possui_imagem", "possui_internacao", "flag_dado_incompleto",
    ]
    with open(p_epi, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(cols)
        for e in epis:
            w.writerow([f(e[c]) for c in cols])

    with open(p_ev, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["evento_id", "atendimento_id", "tipo_evento", "dt_evento",
                    "sequencia_evento", "origem_registro", "flag_timestamp_estimado"])
        eid = 8_000_000
        for e in epis:
            divergir = e.get("_divergir")
            seq = 0
            for tipo, campo in MARCOS:
                val = e.get(campo)
                if val is None:
                    continue
                seq += 1
                estimado = rng.random() < 0.03
                if divergir == tipo:
                    val = val + timedelta(minutes=rng.choice([-1, 1]) * rng.randint(3, 15))
                    estimado = True
                w.writerow([eid, e["atendimento_id"], tipo, val.strftime(FMT), seq,
                            ORIGEM_REGISTRO[tipo], "true" if estimado else "false"])
                eid += 1

    print(f"OK  episodios : {len(epis):>6}  -> {p_epi}")
    print(f"OK  eventos   : {eid - 8_000_000:>6}  -> {p_ev}")
    print(f"    janela de entrada: {args.inicio} a {args.fim} (fechada)  |  seed: {args.seed}")
    print(f"    inconsistencias injetadas: {registro_inconsistencias}")
    print(f"    retornos plantados: {n_ret} (~{args.retorno_frac:.0%})  |  pacientes distintos no pool: {n_pac}")


if __name__ == "__main__":
    main()
