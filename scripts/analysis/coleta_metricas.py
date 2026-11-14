#!/usr/bin/env python3
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
# -*- coding: utf-8 -*-
"""
scripts/analysis/coleta_metricas.py — lê os relatórios das rodadas e grava as
métricas em CSV (primeira versão do pipeline de dados, docs/data-spec.md).

Roda NO SERVIDOR, da raiz do repositório:
    python3 scripts/analysis/coleta_metricas.py

Usa só a biblioteca padrão do Python (compatível com 3.6; decisão de software
em docs/decisions.md). A tabela
comparativa com pandas é feita no Windows por scripts/analysis/tabela_familias.py.

O que lê:
  runs/syn_<vt>_<data>/rpt/  síntese das três famílias (script ainda não
                             incluído neste repositório):
                             timing_setup_ss.rpt, timing_hold_ff.rpt, area.rpt,
                             power_tt.rpt, pvt.rpt
  runs/pnr_<vt>_<data>/rpt/  fluxo por etapas (scripts 00 a 09), uma linha por
                             etapa que já rodou: <NN>_qor.rpt (todas),
                             <NN>_qor_resumo.rpt (03 e 09), <NN>_power_tt.rpt
                             (NN = 03 síntese, 06 placement, 07 CTS,
                             08 roteamento, 09 acabamento)
  fm_<vt>*.log (raiz)        resultado do Formality e a síntese que ele comparou

O que grava (em results/: só números, nada da biblioteca):
  metricas_long.csv     uma linha por métrica (formato longo do data-spec)
  resumo_sintese.csv    uma linha por rodada syn_* (formato largo)
  resumo_fluxo.csv      uma linha por rodada × etapa do fluxo por etapas

Regra do data-spec: formato desconhecido não vira zero. Se uma métrica não for
encontrada, a célula fica vazia e o script avisa no terminal.
"""
import csv
import glob
import os
import re
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RUNS = os.path.join(REPO, "runs")
OUT = os.path.join(REPO, "results")

avisos = []


def ler(caminho):
    # errors="replace": os logs têm acentos gravados em outra codificação
    with open(caminho, encoding="utf-8", errors="replace") as f:
        return f.read()


def slack(caminho):
    """Menor 'slack (MET|VIOLATED)  <número>' do relatório. Não é o primeiro:
    com -max_paths, o report_timing lista por grupo de caminho, e o pior pode
    vir depois."""
    if not os.path.exists(caminho):
        return None
    vals = [float(x) for x in
            re.findall(r"slack \((?:MET|VIOLATED)[^)]*\)\s+(-?\d+\.\d+)", ler(caminho))]
    return min(vals) if vals else None


def area(caminho):
    if not os.path.exists(caminho):
        return None, None
    t = ler(caminho)
    a = re.search(r"Total cell area:\s+([\d.]+)", t)
    n = re.search(r"Number of cells:\s+(\d+)", t)
    return (float(a.group(1)) if a else None, int(n.group(1)) if n else None)


def potencia(caminho):
    """Linha logo abaixo do cabeçalho 'Hierarchy': interna, chaveamento,
    vazamento e total, em pW (unidade conferida no relatório)."""
    if not os.path.exists(caminho):
        return None
    linhas = ler(caminho).splitlines()
    for i, l in enumerate(linhas):
        if l.startswith("Hierarchy"):
            # Colunas na ordem do cabeçalho:
            # Internal, Switching, Leakage, Total, %. Pega as 4 primeiras
            # depois do nome, por posição. Campo não numérico (ex.: N/A) vira
            # vazio no lugar dele; descartá-lo deslocaria as colunas.
            for l2 in linhas[i + 1:i + 4]:
                campos = l2.split()
                if len(campos) < 5 or set(campos[0]) == {"-"}:
                    continue
                nums = []
                for c in campos[1:5]:
                    try:
                        nums.append(float(c))
                    except ValueError:
                        nums.append(None)
                return nums
    return None


def periodo(caminho):
    """Período do clk_i (ns) no report_clocks: linha 'clk_i  8.00  {0 4} ...'."""
    if not os.path.exists(caminho):
        return None
    m = re.search(r"^clk_i\s+(\d+\.\d+)", ler(caminho), re.M)
    return float(m.group(1)) if m else None


def corners_ok(caminho):
    """1 se os três corners usam a biblioteca certa (3x PVT-032, nenhum PVT-030),
    0 se não, vazio se o relatório não existe."""
    if not os.path.exists(caminho):
        return None
    t = ler(caminho)
    return 1 if t.count("PVT-032") >= 3 and "PVT-030" not in t else 0


def formality():
    """Lê os logs fm_*.log da raiz. Devolve {pasta_da_sintese: (passou, pontos)}."""
    res = {}
    # Ordenados por data de modificação: com vários logs da mesma rodada, vale o mais novo.
    for log in sorted(glob.glob(os.path.join(REPO, "fm_*.log")), key=os.path.getmtime):
        # só fm_lvt.log, fm_rvt.log, fm_hvt.log (e variações como fm_rvt_2.log);
        # fm_shell_command.log é o log automático do Formality
        if not re.match(r"fm_(lvt|rvt|hvt)", os.path.basename(log)):
            continue
        t = ler(log)
        # re.M e "^": o log repete as linhas do script (puts "### Formality: ...
        # $SYN_RUN ..."); só vale a linha impressa de fato, que começa com ###
        # Dois formatos: o antigo "### Formality: <vt> <pasta_syn> -> <saida>"
        # e o atual "### Formality: <netlist.v> (SVF <svf>) -> <saida>".
        m = re.search(r"^### Formality: (\S+) \(SVF \S+\) -> (\S+)", t, re.M)
        if m:
            # Sobe da netlist até a pasta da rodada (syn_* ou pnr_*). No fluxo
            # por etapas a netlist fica em <rodada>/outputs/, e o nome da pasta
            # imediata ("outputs") não identifica a rodada.
            d = os.path.dirname(m.group(1))
            while d and not re.match(r"(syn|pnr)_", os.path.basename(d)) and os.path.dirname(d) != d:
                d = os.path.dirname(d)
            syn = os.path.basename(d)
        else:
            m = re.search(r"^### Formality: \S+ (\S+) -> (\S+)", t, re.M)
            if not m:
                avisos.append("%s: sem a linha '### Formality:' (rodada incompleta?)" % os.path.basename(log))
                continue
            syn = os.path.basename(m.group(1).rstrip("/"))
        if re.search(r"^Verification SUCCEEDED", t, re.M):
            ok = 1
        elif re.search(r"^Verification FAILED", t, re.M):
            ok = 0
        else:
            avisos.append("%s: sem resultado de verificação" % os.path.basename(log))
            continue
        p = re.search(r"(\d+) Passing compare points", t)
        res[syn] = (ok, int(p.group(1)) if p else None)
    return res


# ---------------------------------------------------------------------------
# Fluxo por etapas (runs/pnr_<vt>_<data>/rpt/<NN>_*.rpt)
# ---------------------------------------------------------------------------
ETAPAS = [("03", "syn"), ("06", "place"), ("07", "cts"), ("08", "route"), ("09", "finish")]
CORNER = {"func_ss": "worst", "func_tt": "typical", "func_ff": "best"}


def num(texto):
    """Texto -> número: inteiro se não tiver ponto (contagens), senão float."""
    try:
        return int(texto) if re.match(r"^-?\d+$", texto) else float(texto)
    except (TypeError, ValueError):
        return None


def qor_grupos(caminho):
    """report_qor (completo): um quadro por cenário e grupo de caminho.
    Devolve (lista de grupos, dicionário de números gerais). Cada grupo:
    {"cenario", "grupo", "slack", "tns", "nvp", "niveis", "whs", "ths", "nhv"}
    (os de hold só nos cenários com hold). Os gerais: células, área e regras
    elétricas."""
    if not os.path.exists(caminho):
        return None, None
    grupos, atual, geral = [], None, {}
    campos = {"Critical Path Slack": "slack", "Total Negative Slack": "tns",
              "No. of Violating Paths": "nvp", "Levels of Logic": "niveis",
              "Worst Hold Violation": "whs", "Total Hold Violation": "ths",
              "No. of Hold Violations": "nhv"}
    gerais = {"Leaf Cell Count": "cell_count", "Cell Area (netlist)": "area_cell",
              "Nets with Violations": "nets_drv", "Max Trans Violations": "max_trans_viol",
              "Max Cap Violations": "max_cap_viol"}
    for l in ler(caminho).splitlines():
        m = re.match(r"^Scenario\s+'(\S+)'", l)
        if m:
            atual = {"cenario": m.group(1)}
            grupos.append(atual)
            continue
        m = re.match(r"^Timing Path Group\s+'(\S+)'", l)
        if m and atual is not None:
            atual["grupo"] = m.group(1).strip("*")
            continue
        m = re.match(r"^([A-Za-z.() ]+?):\s+(-?[\d.]+)\s*$", l)
        if m:
            chave, valor = m.group(1).strip(), num(m.group(2))
            if chave in campos and atual is not None:
                atual[campos[chave]] = valor
            elif chave in gerais:
                geral[gerais[chave]] = valor
    return grupos, geral


def qor_resumo(caminho):
    """report_qor -summary: linhas 'func_ss (Setup) WNS TNS NVE'.
    Devolve {(cenario, 'setup'|'hold'): (wns, tns, nve)}. O TNS e o NVE daqui
    contam pontos de chegada (endpoints); os do report_qor completo contam
    caminhos por grupo, por isso os dois não batem."""
    if not os.path.exists(caminho):
        return None
    res = {}
    for l in ler(caminho).splitlines():
        m = re.match(r"^(func_\w+)\s+\((Setup|Hold)\)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(\d+)\s*$", l)
        if m:
            res[(m.group(1), m.group(2).lower())] = (num(m.group(3)), num(m.group(4)), int(m.group(5)))
    return res


def coletar_fluxo(long_rows):
    """Uma linha por rodada × etapa. Devolve as linhas do formato largo."""
    largas = []
    for d in sorted(glob.glob(os.path.join(RUNS, "pnr_*_*"))):
        run = os.path.basename(d)
        m = re.match(r"pnr_(lvt|rvt|hvt)_(\d{8}-\d{6})$", run)
        if not m:
            continue
        vt, data = m.group(1), m.group(2)
        rpt = os.path.join(d, "rpt")
        for nn, etapa in ETAPAS:
            arq_qor = "%s_qor.rpt" % nn
            grupos, geral = qor_grupos(os.path.join(rpt, arq_qor))
            if grupos is None:
                continue  # etapa ainda não rodou nesta rodada
            resumo = qor_resumo(os.path.join(rpt, "%s_qor_resumo.rpt" % nn)) or {}
            pot = potencia(os.path.join(rpt, "%s_power_tt.rpt" % nn))

            def linha(cenario, escopo, nome, valor, un, fonte):
                long_rows.append([run, etapa, cenario, CORNER.get(cenario, "na"), escopo,
                                  nome, "" if valor is None else valor, un, fonte])

            # por grupo de caminho (formato longo)
            for g in grupos:
                for chave, nome in (("slack", "slack"), ("tns", "tns_paths"), ("nvp", "nvp"),
                                    ("niveis", "logic_levels"), ("whs", "whs"),
                                    ("ths", "ths"), ("nhv", "hold_viol")):
                    if chave in g:
                        linha(g["cenario"], g.get("grupo", "?"), nome, g[chave],
                              "" if chave in ("nvp", "niveis", "nhv") else "ns", arq_qor)

            # pior slack de setup por cenário (o menor entre os grupos)
            wns = {}
            for g in grupos:
                if "slack" in g:
                    c = g["cenario"]
                    wns[c] = g["slack"] if c not in wns else min(wns[c], g["slack"])
            # Pior hold por cenário. Fonte preferida: as linhas (Hold) do
            # report_qor -summary, que trazem o slack com sinal (+0,15 é +0,15).
            # O "Worst Hold Violation" do report_qor completo é VIOLAÇÃO, cortada
            # em 0 quando cumpre: só serve de reserva, quando não há o resumo.
            whs = {}
            for g in grupos:
                if "whs" in g:
                    c = g["cenario"]
                    whs[c] = g["whs"] if c not in whs else min(whs[c], g["whs"])
            for c in ("func_ss", "func_tt", "func_ff"):
                r = resumo.get((c, "hold"))
                if r:
                    whs[c] = r[0]

            larga = {"run_id": run, "familia": vt.upper(), "data": data, "etapa": etapa,
                     "clock_period": periodo(os.path.join(rpt, "02_clocks.rpt")),
                     "wns_setup_ss": wns.get("func_ss"), "wns_setup_tt": wns.get("func_tt"),
                     "wns_setup_ff": wns.get("func_ff"),
                     "wns_hold_ss": whs.get("func_ss"), "wns_hold_tt": whs.get("func_tt"),
                     "wns_hold_ff": whs.get("func_ff")}
            for c, sufixo in (("func_ss", "ss"), ("func_tt", "tt"), ("func_ff", "ff")):
                for tipo in ("setup", "hold"):
                    r = resumo.get((c, tipo))
                    larga["tns_%s_%s" % (tipo, sufixo)] = r[1] if r else None
                    larga["nve_%s_%s" % (tipo, sufixo)] = r[2] if r else None
            for chave in ("area_cell", "cell_count", "nets_drv", "max_trans_viol", "max_cap_viol"):
                larga[chave] = geral.get(chave)
            for i, nome in enumerate(("power_int", "power_switch", "power_leak", "power_total")):
                larga[nome] = pot[i] if pot else None

            for nome in ("wns_setup_ss", "wns_setup_tt", "wns_setup_ff", "wns_hold_ss",
                         "wns_hold_tt", "wns_hold_ff", "area_cell", "cell_count"):
                if larga[nome] is None:
                    avisos.append("%s/%s: '%s' não encontrado em %s" % (run, etapa, nome, arq_qor))
            for cen, nome in (("func_ss", "wns_setup_ss"), ("func_tt", "wns_setup_tt"),
                              ("func_ff", "wns_setup_ff"), ("func_ss", "wns_hold_ss"),
                              ("func_tt", "wns_hold_tt"), ("func_ff", "wns_hold_ff")):
                if larga[nome] is not None:
                    linha(cen, "top", nome.rsplit("_", 1)[0], larga[nome], "ns", arq_qor)
            for nome, un in (("area_cell", "um2"), ("cell_count", ""), ("nets_drv", ""),
                             ("max_trans_viol", ""), ("max_cap_viol", "")):
                linha("", "top", nome, larga[nome], un, arq_qor)
            for nome in ("power_int", "power_switch", "power_leak", "power_total"):
                linha("func_tt", "top", nome, larga[nome], "pW", "%s_power_tt.rpt" % nn)
            largas.append({k: ("" if v is None else v) for k, v in larga.items()})
    return largas


def main():
    # Rodadas syn_* (síntese das três famílias, script ainda não incluído
    # neste repositório): comparação LVT x RVT x HVT. Lê só setup no ss e
    # hold no ff, como aquele script relata.
    # O fluxo por etapas (pnr_*) é coletado em coletar_fluxo().
    fm = formality()
    long_rows, wide_rows = [], []
    for d in sorted(glob.glob(os.path.join(RUNS, "syn_*_*"))):
        run = os.path.basename(d)
        m = re.match(r"syn_(lvt|rvt|hvt)_(\d{8}-\d{6})$", run)
        if not m:
            continue
        vt, data = m.group(1), m.group(2)
        rpt = os.path.join(d, "rpt")
        if not os.path.exists(os.path.join(rpt, "timing_setup_ss.rpt")):
            avisos.append("%s: sem relatórios (rodada interrompida), ignorada" % run)
            continue

        s_setup = slack(os.path.join(rpt, "timing_setup_ss.rpt"))
        s_hold = slack(os.path.join(rpt, "timing_hold_ff.rpt"))
        a_cel, n_cel = area(os.path.join(rpt, "area.rpt"))
        pot = potencia(os.path.join(rpt, "power_tt.rpt"))
        c_ok = corners_ok(os.path.join(rpt, "pvt.rpt"))
        per = periodo(os.path.join(rpt, "clocks.rpt"))
        fm_ok, fm_pts = fm.get(run, (None, None))

        metricas = [
            # (etapa, corner, métrica, valor, unidade, relatório)
            ("syn", "worst", "wns_setup", s_setup, "ns", "timing_setup_ss.rpt"),
            ("syn", "best", "wns_hold", s_hold, "ns", "timing_hold_ff.rpt"),
            ("syn", "na", "area_cell", a_cel, "um2", "area.rpt"),
            ("syn", "na", "cell_count", n_cel, "", "area.rpt"),
            ("syn", "typical", "power_int", pot[0] if pot else None, "pW", "power_tt.rpt"),
            ("syn", "typical", "power_switch", pot[1] if pot else None, "pW", "power_tt.rpt"),
            ("syn", "typical", "power_leak", pot[2] if pot else None, "pW", "power_tt.rpt"),
            ("syn", "typical", "power_total", pot[3] if pot else None, "pW", "power_tt.rpt"),
            ("syn", "na", "corners_ok", c_ok, "", "pvt.rpt"),
            ("syn", "na", "clock_period", per, "ns", "clocks.rpt"),
            ("fm", "na", "equivalence", fm_ok, "", "fm_<vt>.log"),
            ("fm", "na", "fm_passing_points", fm_pts, "", "fm_<vt>.log"),
        ]
        for etapa, corner, nome, valor, un, fonte in metricas:
            if valor is None and nome not in ("corners_ok", "equivalence", "fm_passing_points"):
                avisos.append("%s: '%s' não encontrado em %s" % (run, nome, fonte))
            long_rows.append([run, etapa, "", corner, "top", nome,
                              "" if valor is None else valor, un, fonte])

        linha = {"run_id": run, "familia": vt.upper(), "data": data}
        for _, _, nome, valor, _, _ in metricas:
            linha[nome] = "" if valor is None else valor
        wide_rows.append(linha)

    fluxo_rows = coletar_fluxo(long_rows)

    if not wide_rows and not fluxo_rows:
        sys.exit("Nenhuma rodada com relatórios em runs/. Rode da raiz do repositório.")

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "metricas_long.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["run_id", "stage", "scenario", "corner", "scope", "metric", "value", "unit", "source_report"])
        w.writerows(long_rows)
    gravados = ["metricas_long.csv"]
    # Cada resumo só é gravado se houver rodadas daquele tipo: assim, numa
    # pasta sem rodadas syn_*, um resumo_sintese.csv já existente não é apagado.
    for nome, linhas in (("resumo_sintese.csv", wide_rows), ("resumo_fluxo.csv", fluxo_rows)):
        if not linhas:
            continue
        with open(os.path.join(OUT, nome), "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(linhas[0].keys()))
            w.writeheader()
            w.writerows(linhas)
        gravados.append(nome)

    print("### %d rodadas de síntese (syn_*) e %d etapas do fluxo lidas, %d métricas gravadas"
          % (len(wide_rows), len(fluxo_rows), len(long_rows)))
    print("### results/" + ", results/".join(gravados))
    for a in avisos:
        print("AVISO: " + a)


if __name__ == "__main__":
    main()
