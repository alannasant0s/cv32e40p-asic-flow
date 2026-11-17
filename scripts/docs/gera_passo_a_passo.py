# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
"""Gera docs/passo-a-passo-sintese.md: a síntese lógica linha por linha.

Lê os próprios scripts (tool_data/fc/01..03) e, para cada bloco, escreve:
  - os comentários do script como texto (o porquê de cada comando);
  - cada comando num quadro, exatamente como está no script, para copiar
    e colar no fc_shell;
  - as linhas CONFERIR/PRINT destacadas;
  - o que deve aparecer (dicionário ESPERADO abaixo).
Assim o guia nunca fica diferente do script: mudou um script, gere de novo.

Os textos de "deve aparecer" vêm das mensagens da ferramenta numa rodada de
validação dos scripts (2026-11-17). Números de resultado (slack, área) NÃO
entram aqui: eles valem quando a dupla roda e confere.

Uso (na raiz do repositório):
    python scripts/docs/gera_passo_a_passo.py
    py scripts/docs/md2pdf.py docs/passo-a-passo-sintese.md <saida.pdf> "<rodapé>"
"""
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
SCRIPTS = [
    ("01_init_design", "Script 01 — Ler o RTL e montar o circuito"),
    ("02_scenarios", "Script 02 — Corners, cenários e constraints"),
    ("03_synth", "Script 03 — Síntese lógica"),
]

# bloco -> lista de frases "deve aparecer"
ESPERADO = {
    "1.1": ["`### 00_tech_setup: família hvt, clock 8.0 ns, rodada .../runs/pnr_hvt_<data e hora>`. **Anote o nome da pasta da rodada.**"],
    "1.2": ["Responde `1`, sem erro."],
    "1.3": ["`Information: Loading technology file '.../saed32nm_1p9m.tf' (FILE-007)` e o nome da biblioteca criada: `{cv32e40p_lib}`.",
            "Aviso TECH-025 (`Layer 'VIA1' 'onGrid' and 'onWireTrack' coexist`): vem do arquivo de tecnologia; esperado.",
            "A NDM `saed32hvt_c` ainda não aparece aqui: ela só é carregada no 1.5."],
    "1.4": ["Várias linhas de leitura dos arquivos `.sv`; a **última linha é `1`**. Se for `0`, procure a primeira linha com `Error:`."],
    "1.5": ["`Presto compilation completed successfully`.",
            "`set_top_module`: `Information: User units loaded from library 'saed32hvt_c' (LNK-040)` e `1`. É aqui que a NDM da HVT é usada de fato.",
            "`Module: cv32e40p_top_COREV_PULP0_..._NUM_MHPMCOUNTERS1, Ports: 379, Input: 266, Output: 113`: o bloco tem 379 portas.",
            "`current_design`: `{cv32e40p_lib:cv32e40p_top_COREV_PULP0_..._NUM_MHPMCOUNTERS1.design}`.",
            "`report_hierarchy`: o `cv32e40p_core_...` e, dentro dele, cs_registers, ex_stage (alu, alu_div, mult), id_stage (controller, decoder, register_file), if_stage (aligner, prefetch_buffer), load_store_unit e sleep_unit, com o `cv32e40p_clock_gate` usando a `CGLPPRX2_HVT`. As linhas `__wvGtech__` (lógica genérica) e `DW01_*`/`DW_*` (somadores, comparadores, multiplicadores prontos) são normais nesta fase."],
    "1.6": ["`compile.flow.autoungroup` com `true` na coluna do valor do usuário."],
    "1.7": ["`Saving library 'cv32e40p_lib'` e `### 01_init_design pronto`."],
    "2.1": ["Sem erro. Numa rodada nova pode avisar que não há nada para remover; o `catch` ignora."],
    "2.2": ["Sem erro: as três tabelas de fio (Cmax, nominal, Cmin) são lidas."],
    "2.3": ["Sem erro: modo `func`, corners `ss`, `tt`, `ff` e os três cenários criados."],
    "2.4": ["`Information: Corner ss: no PVT mismatches. (PVT-032)`, e o mesmo para `tt` e `ff`. **Se aparecer PVT-030, pare**: a biblioteca do corner está errada.",
            "Avisos UIC-061 sobre o `set_timing_derate` (vale para célula e fio) são esperados."],
    "2.5": ["O `report_clocks` mostra `clk_i  8.00  {0 4}`: período de 8 ns, borda de subida em 0 e de descida em 4."],
    "2.6": ["O `report_scenarios` mostra `func_ss`, `func_tt` e `func_ff` com **Setup `true` e Hold `true`**. A potência fica ligada só no `func_tt`."],
    "2.7": ["Responde `1`: o clock gate do RTL está protegido."],
    "2.8": ["O `check_timing` mostra muitos avisos **TCK-001** \"unconstrained ... Reason: 'case constant'\". São esperados: vêm do `scan_cg_en_i` fixo em 0 (SDC) e de registradores das extensões PULP, que estão desligadas e ficam com valor constante. Não deve haver entrada sem atraso nem flip-flop sem clock.",
            "O `report_case_analysis` mostra só o `scan_cg_en_i = 0`; o `report_exceptions` vem vazio (nenhum false path nem multicycle).",
            "O `write_sdc` avisa `Multiply cell derates are skipped!` e `Multiply net derates are skipped!`: é um tipo de margem que não usamos; as margens de ±5 % aparecem no SDC gravado (`set_timing_derate`)."],
    "2.9": ["`### 02_scenarios pronto`."],
    "3.0": ["Sem erro: as células de tie (TIEH e TIEL) são liberadas."],
    "3.0b": ["O `report_clock_gating_objects` mostra o `core_i` como **Exclude**."],
    "3.1": ["Leva alguns minutos. O `report_area` mostra o número de células e a área logo depois do mapeamento.",
            "O `report_timing` mostra um bloco por cenário (`func_ss`, `func_tt`, `func_ff`)."],
    "3.2": ["Leva alguns minutos. `Tie cells: TIEL=<n> TIEH=<n>`: as saídas constantes passam a ter célula de tie.",
            "O `report_qor` e o `report_timing` mostram os três cenários."],
    "3.3": ["`report_area` sem erro. No `report_qor` do 3.4: `Hierarchical Cell Count: 1` (o `core_i`; tudo abaixo dele foi desfeito)."],
    "3.4": ["O `report_qor -summary` mostra **uma linha por cenário** em setup e em hold, mais a linha `Design` (o resumo, não um corner; estudo E02), com 3 casas decimais.",
            "Os arquivos `03_timing_setup_{ss,tt,ff}.rpt`, `03_timing_hold_{ss,tt,ff}.rpt`, `03_violacoes_eletricas.rpt`, `03_timing_in2out.rpt`, `03_power_tt.rpt` e `03_clock_gating.rpt` aparecem em `rpt/`.",
            "O `03_clock_gating.rpt` mostra **1** clock gate. O relatório o chama de \"Tool-Inserted\", mas ele é o do RTL: confira com `grep CGLPPRX2_HVT outputs/cv32e40p_top_syn.v` (aparece só o `sleep_unit_i/core_clock_gate_i/u_icg`).",
            "Avisos TIM-010 no relatório entrada→saída, em bits que o RTL não usa (`boot_addr_i[1:0]`, bits reservados de `irq_i`...), são esperados."],
    "3.5": ["`### 03_synth pronto`. Em `outputs/`: `cv32e40p_top_syn.v` (netlist) e `cv32e40p_top_syn.sdc`."],
}

INICIO = """# Passo a passo — síntese lógica do processador RISC-V CV32E40P

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

Este guia é **gerado a partir dos próprios scripts**
(`scripts/docs/gera_passo_a_passo.py`): cada comando está exatamente como no
arquivo, e o texto antes dele é o comentário do script. Se o guia e o script
discordarem, vale o script; gere o guia de novo.

Biblioteca HVT, clock de 8 ns (125 MHz), três corners (ss 0,95 V 125 °C; tt
1,05 V 25 °C; ff 1,16 V −40 °C), netlist flat abaixo do `core_i`.

## Como rodar linha por linha

1. Abra o script no editor (VS Code) de um lado e o terminal do `fc_shell` do
   outro.
2. **Linhas que começam com `#` são comentário**: leia, não cole.
3. **Copie um comando por vez** e cole no `fc_shell>`. Um comando que termina
   com `\\` continua na linha de baixo; um comando com `{` aberto (por exemplo
   um `foreach`) vai até o `}` que fecha. Nesses casos, copie o quadro inteiro.
4. Depois de cada comando, compare a saída com o **Conferir** e o **Deve
   aparecer** do bloco.
5. **Não feche o `fc_shell`** no meio de um script: as variáveis (`$RUN_DIR`,
   `$TECH_FILE`, `$FLIST`...) só existem nessa sessão. Para ver o valor de uma
   variável antes de usar: `puts $RUN_DIR`.
6. **Não aperte Ctrl+C** enquanto um comando roda.
7. Se aparecer `Error`, pare, leia a mensagem e veja `docs/erros-conhecidos.md`
   antes de seguir.
8. Uma pessoa roda e a outra acompanha e confere. Anote: pasta da rodada,
   `git log -1 --oneline`, quem rodou e quem conferiu.

Alternativa: em vez de colar comando a comando, o `scripts/fc/bloco.tcl` roda
um bloco inteiro (`source scripts/fc/bloco.tcl` e depois `bloco 1.2`).

## Antes de começar (uma vez por conta)

No terminal do servidor:

```
git clone --recurse-submodules https://github.com/alannasant0s/cv32e40p-asic-flow.git
cd ~/cv32e40p-asic-flow
git config core.hooksPath .githooks
source /Tools/synopsys-scripts/snps.sh
scripts/gen_filelist.sh --synthesis
```

**Deve aparecer:** `tool_data/vcs/flist_rtl.f` com o cabeçalho
`# Modo: síntese (tb_wrapper e tracer_pkg removidos)`;
`grep -c clock_gate_saed32 tool_data/vcs/flist_rtl.f` dá `1`.

## Biblioteca da SAED32 (NDM)

Leia antes o `tool_data/fc/create_ndm.tcl` e o estudo E01 (por que o corner
lento é o de 0,95 V). Depois:

```
lm_shell -x "set VT hvt" -file tool_data/fc/create_ndm.tcl -batch > ndm_hvt.log 2>&1
grep -c "^Error" ndm_hvt.log
tail -15 rpt/create_ndm_hvt_check_workspace.rpt
grep -o "saed32hvt_[a-z0-9]*\\.db" ndm_hvt.log | sort -u
```

**Deve aparecer:** `0` erros; `Using saed32hvt_ss0p95v125c as the base
library`; `2/2 workspaces checked successfully`; os quatro arquivos
`saed32hvt_ss0p95v125c.db`, `tt1p05v25c`, `ff1p16vn40c` e `ss0p95vn40c`.
Avisos esperados: LM-054 (direção dos pinos VDD/VSS), LMUI-009 e FRAM-066
(célula `LSDNSSX8_HVT`, que o projeto não usa). Atenção: o log repete o texto
do script; procure as mensagens da ferramenta, não os comentários.

## Abrir o Fusion Compiler

```
fc_shell
```

Os comandos abaixo são colados no `fc_shell>`, na ordem.
"""

FIM = """## Formality: a netlist faz o mesmo que o RTL?

Saia do `fc_shell` (`exit`) e, no terminal, troque `<rodada>` pela pasta
anotada no bloco 1.1:

```
fm_shell -x "set VT hvt; set NETLIST runs/<rodada>/outputs/cv32e40p_top_syn.v; set SVF runs/<rodada>/cv32e40p.svf" -file tool_data/fm/fm.tcl > fm_hvt.log 2>&1
tail -3 fm_hvt.log
grep -A2 "Verification Results" runs/fm_hvt_*/rpt/status.rpt | tail -3
```

**Deve aparecer:** `### Formality: SUCCEEDED` e `Verification SUCCEEDED`. Leia
e anote o bloco "Auto Setup Summary" do `status.rpt` (critério 03.7).

## Depois da síntese

1. Conferir os critérios 02 e 03 em `docs/criterios-aceite.md`, com os
   relatórios em `runs/<rodada>/rpt/`.
2. Preencher as tabelas "Resultado anotado" dos estudos E01, E02, E06 e E07.
3. O que não fechar vira estudo e pergunta ao professor, com dados: entradas e
   saídas (E04), violações elétricas (E03), margens (E08).
4. Atualizar `docs/estado-atual.md`.

## Se o fc_shell fechar no meio

Abra de novo, na pasta do projeto, e diga qual rodada continuar **antes** de
carregar as variáveis (senão uma pasta nova é criada):

```
set RUN_DIR [pwd]/runs/<rodada>
source tool_data/fc/00_tech_setup.tcl
open_lib $RUN_DIR/cv32e40p_lib
open_block cv32e40p_top_scenarios
set_svf -append $RUN_DIR/cv32e40p.svf
```

Troque `cv32e40p_top_scenarios` pelo último bloco salvo (`_init` depois do
01, `_scenarios` depois do 02, `_syn` depois do 03). O que rodou depois do
último salvamento precisa ser refeito.
"""


def blocos(caminho):
    """[(id, título, [linhas do bloco])] de um script."""
    res, atual = [], None
    for linha in caminho.read_text(encoding="utf-8").split("\n"):
        m = re.match(r"^### BLOCO (\S+) — (.*?)\s*#*\s*$", linha)
        if m:
            atual = (m.group(1), m.group(2), [])
            res.append(atual)
        elif atual is not None:
            atual[2].append(linha)
    return res


def cabecalho(caminho):
    """Comentários do topo do script (antes do primeiro bloco), sem a linha de autores."""
    linhas = []
    for linha in caminho.read_text(encoding="utf-8").split("\n"):
        if linha.startswith("### BLOCO"):
            break
        if linha.startswith("#"):
            t = linha.lstrip("#").strip()
            if "Autores:" in t or "polo UFCG" in t:
                continue
            linhas.append(t)
    return linhas


def chaves(s):
    """Saldo de chaves fora de comentário (para juntar foreach/if de várias linhas)."""
    return s.count("{") - s.count("}")


def render_bloco(bid, titulo, linhas):
    md = [f"### Bloco {bid} — {titulo}", ""]
    texto, comando, saldo, n = [], [], 0, 0
    destaque = False  # continuação de uma linha CONFERIR/PRINT

    def fecha_texto():
        if texto:
            paragrafo = " ".join(t for t in texto if t)
            md.append(paragrafo)
            md.append("")
            texto.clear()

    for linha in linhas:
        cru = linha.rstrip()
        if comando:  # continuação de um comando
            comando.append(cru)
            saldo += chaves(cru)
            if saldo <= 0 and not cru.endswith("\\"):
                md += ["```", *comando, "```", ""]
                comando, saldo = [], 0
            continue
        if not cru.strip():
            fecha_texto()
            destaque = False
            continue
        if cru.lstrip().startswith("#"):
            t = cru.lstrip().lstrip("#").strip()
            if re.match(r"^(CONFERIR|PRINT)", t):
                fecha_texto()
                md.append(f"> **{t.split(':')[0].capitalize()}:**{t.split(':', 1)[1] if ':' in t else ''}")
                md.append("")
                destaque = True
            elif destaque:
                md[-2] = md[-2] + " " + t
            else:
                texto.append(t)
            continue
        # linha de comando
        fecha_texto()
        destaque = False
        n += 1
        saldo = chaves(cru)
        comando = [cru]
        if saldo <= 0 and not cru.endswith("\\"):
            md += ["```", *comando, "```", ""]
            comando, saldo = [], 0
    if comando:
        md += ["```", *comando, "```", ""]
    fecha_texto()
    if bid in ESPERADO:
        md.append("**Deve aparecer:**")
        md.append("")
        md += [f"- {e}" for e in ESPERADO[bid]]
        md.append("")
    md.append("Feito: ( )  Conferido: ( )")
    md.append("")
    return md


def main():
    md = [INICIO]
    vistos = set()
    for nome, titulo in SCRIPTS:
        caminho = RAIZ / "tool_data" / "fc" / f"{nome}.tcl"
        md += [f"## {titulo}", "", f"Arquivo: `tool_data/fc/{nome}.tcl`.", ""]
        cab = [c for c in cabecalho(caminho) if c and not c.startswith("tool_data/")]
        if cab:
            md += ["> " + " ".join(cab), ""]
        for bid, tit, linhas in blocos(caminho):
            vistos.add(bid)
            md += render_bloco(bid, tit, linhas)
    faltando = set(ESPERADO) - vistos
    if faltando:
        raise SystemExit(f"Blocos em ESPERADO que não existem nos scripts: {sorted(faltando)}")
    md.append(FIM)
    saida = RAIZ / "docs" / "passo-a-passo-sintese.md"
    with open(saida, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(md))
    print("ok", saida.relative_to(RAIZ))


if __name__ == "__main__":
    main()
