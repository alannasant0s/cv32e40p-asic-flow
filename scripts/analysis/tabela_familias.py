#!/usr/bin/env python3
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
# -*- coding: utf-8 -*-
"""
scripts/analysis/tabela_familias.py — monta a tabela comparativa LVT × RVT × HVT
com pandas, a partir do results/resumo_sintese.csv gravado no servidor por
scripts/analysis/coleta_metricas.py.

Roda no Windows (pandas não é usado no servidor; decisão de software em
docs/decisions.md):
    python scripts/analysis/tabela_familias.py

Regras:
  - só entram rodadas com corners_ok = 1 (corners conferidos no report_pvt);
    rodadas com PVT-030 (biblioteca errada em algum corner) ficam de fora;
  - de cada família, entra a rodada mais recente.

Grava results/tabela_familias.csv e results/tabela_familias.md e mostra a
tabela no terminal.
"""
import os
import sys

import pandas as pd

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RES = os.path.join(REPO, "results")

df = pd.read_csv(os.path.join(RES, "resumo_sintese.csv"), dtype={"data": str})

validas = df[df["corners_ok"] == 1]
# Período: por padrão, o da rodada válida mais recente; outro com o argumento
# (ex.: python scripts/analysis/tabela_familias.py 8). Assim a tabela nunca
# mistura famílias sintetizadas com clocks diferentes.
if "clock_period" in validas and validas["clock_period"].notna().any():
    per = float(sys.argv[1]) if len(sys.argv) > 1 else validas.sort_values("data")["clock_period"].dropna().iloc[-1]
    validas = validas[validas["clock_period"] == per]
    print("Período do clock: %.1f ns" % per)
descartadas = df[df["corners_ok"] != 1]
if validas.empty:
    sys.exit("Nenhuma rodada com corners_ok = 1 em results/resumo_sintese.csv")

ultima = validas.sort_values("data").groupby("familia").tail(1).set_index("familia")
ultima = ultima.reindex([f for f in ["LVT", "RVT", "HVT"] if f in ultima.index])

PW_MW = 1e-9  # relatórios em pW; 1 mW = 1e9 pW
tabela = pd.DataFrame({
    "Rodada": ultima["run_id"],
    "Período do clock (ns)": ultima["clock_period"] if "clock_period" in ultima else None,
    "Slack setup ss (ns)": ultima["wns_setup"],
    "Slack hold ff (ns)": ultima["wns_hold"],
    "Área de células (µm²)": ultima["area_cell"].round(0),
    "Células": ultima["cell_count"],
    "Leakage tt (mW)": (ultima["power_leak"] * PW_MW).round(2),
    "Potência total tt (mW)": (ultima["power_total"] * PW_MW).round(2),
    "Formality": ultima["equivalence"].map({1: "SUCCEEDED", 0: "FAILED"}).fillna("não rodado"),
}).T

# Razões entre famílias, quando as três existem
extra = []
if {"LVT", "RVT", "HVT"} <= set(ultima.index):
    lk = ultima["power_leak"]
    extra.append("Leakage LVT/RVT = %.1f×   RVT/HVT = %.1f×" % (lk["LVT"] / lk["RVT"], lk["RVT"] / lk["HVT"]))
    ar = ultima["area_cell"]
    extra.append("Área HVT/RVT = %.2f×   LVT/RVT = %.2f×" % (ar["HVT"] / ar["RVT"], ar["LVT"] / ar["RVT"]))

pd.set_option("display.width", 160)
print(tabela.to_string())
for e in extra:
    print(e)
print("\nRodadas descartadas (corners não conferidos): %d" % len(descartadas))

tabela.to_csv(os.path.join(RES, "tabela_familias.csv"), encoding="utf-8")
with open(os.path.join(RES, "tabela_familias.md"), "w", encoding="utf-8") as f:
    f.write("# Tabela LVT × RVT × HVT (gerada por scripts/analysis/tabela_familias.py)\n\n")
    cols = list(tabela.columns)
    f.write("| Métrica | " + " | ".join(cols) + " |\n")
    f.write("|---|" + "---|" * len(cols) + "\n")
    for nome, linha in tabela.iterrows():
        f.write("| %s | %s |\n" % (nome, " | ".join(str(v) for v in linha.values)))
    if extra:
        f.write("\n" + "\n".join("- " + e for e in extra) + "\n")
    f.write("\nRodadas descartadas por corners não conferidos: %d\n" % len(descartadas))
print("### results/tabela_familias.csv e results/tabela_familias.md")
