#!/usr/bin/env python3
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
# -*- coding: utf-8 -*-
"""
scripts/analysis/tabela_fluxo.py — evolução de uma rodada do fluxo por etapas
(síntese -> placement -> CTS -> roteamento -> acabamento), com pandas, a partir
do results/resumo_fluxo.csv gravado no servidor por coleta_metricas.py.

Roda no Windows (pandas; decisão de software em docs/decisions.md):
    python scripts/analysis/tabela_fluxo.py                  # rodada mais recente
    python scripts/analysis/tabela_fluxo.py pnr_hvt_AAAAMMDD-HHMMSS

Grava results/fluxo_<run_id>.md e mostra a tabela no terminal. É a análise 2 do
docs/data-spec.md (como o timing e a área mudam ao longo das etapas).
"""
import os
import sys

import pandas as pd

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RES = os.path.join(REPO, "results")
ORDEM = ["syn", "place", "cts", "route", "finish"]
NOMES = {"syn": "Síntese (03)", "place": "Placement (06)", "cts": "CTS (07)",
         "route": "Roteamento (08)", "finish": "Acabamento (09)"}
PW_MW = 1e-9  # relatórios em pW; 1 mW = 1e9 pW

df = pd.read_csv(os.path.join(RES, "resumo_fluxo.csv"), dtype={"data": str})
if df.empty:
    sys.exit("results/resumo_fluxo.csv está vazio")

run = sys.argv[1] if len(sys.argv) > 1 else df.sort_values("data")["run_id"].iloc[-1]
r = df[df["run_id"] == run].copy()
if r.empty:
    sys.exit("Rodada %s não está em results/resumo_fluxo.csv" % run)

r["ordem"] = r["etapa"].map({e: i for i, e in enumerate(ORDEM)})
r = r.sort_values("ordem").set_index("etapa")

# Setup e hold nos três corners. Se uma rodada não tiver alguma dessas
# colunas, ela aparece vazia.
def _col(nome):
    return r[nome] if nome in r.columns else pd.Series(index=r.index, dtype=float)

tabela = pd.DataFrame({
    "Setup ss WNS (ns)": r["wns_setup_ss"],
    "Setup tt WNS (ns)": r["wns_setup_tt"],
    "Setup ff WNS (ns)": _col("wns_setup_ff"),
    "Hold ss WNS (ns)": _col("wns_hold_ss"),
    "Hold tt WNS (ns)": _col("wns_hold_tt"),
    "Hold ff WNS (ns)": r["wns_hold_ff"],
    "Área (µm²)": r["area_cell"].round(0),
    "Células": r["cell_count"],
    "Redes com violação elétrica": r["nets_drv"],
    "Leakage tt (mW)": (r["power_leak"] * PW_MW).round(3),
    "Potência total tt (mW)": (r["power_total"] * PW_MW).round(3),
}).rename(index=NOMES).T

pd.set_option("display.width", 160)
print("Rodada:", run)
print(tabela.to_string())

saida = os.path.join(RES, "fluxo_%s.md" % run)
with open(saida, "w", encoding="utf-8") as f:
    f.write("# Evolução por etapa: %s\n\n" % run)
    f.write("Gerado por scripts/analysis/tabela_fluxo.py a partir de results/resumo_fluxo.csv.\n\n")
    cols = list(tabela.columns)
    f.write("| Métrica | " + " | ".join(cols) + " |\n")
    f.write("|---|" + "---|" * len(cols) + "\n")
    for nome, linha in tabela.iterrows():
        f.write("| %s | %s |\n" % (nome, " | ".join("" if pd.isna(v) else str(v) for v in linha.values)))
print("### " + os.path.relpath(saida, REPO))
