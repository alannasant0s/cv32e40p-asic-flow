# tool_data/fm/fm.tcl — verificação de equivalência RTL × netlist no Formality
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# O que faz: prova matematicamente que a netlist da síntese (implementação,
# "i:") faz a mesma função lógica que o RTL (referência, "r:"), para todas as
# entradas possíveis. Usa o arquivo SVF que a síntese grava (bloco 1.2 do
# 01_init_design.tcl), que conta ao Formality o que a síntese renomeou ou mudou.
#
# Uso (da raiz do repositório, depois de source /Tools/synopsys-scripts/snps.sh):
#   scripts/gen_filelist.sh --synthesis
#   fm_shell -x "set VT hvt; set NETLIST runs/<rodada>/outputs/cv32e40p_top_syn.v; set SVF runs/<rodada>/cv32e40p.svf" -file tool_data/fm/fm.tcl > fm_hvt.log 2>&1
# Rodadas syn_* (síntese das três famílias, script ainda não incluído neste
# repositório): -x "set VT rvt; set SYN_RUN runs/syn_rvt_<data>".
# A rodada é sempre informada: o script não escolhe sozinho.

# ==== Passo 1 — Caminhos =====================================================
if {![info exists VT]} { set VT rvt }
if {$VT ni {rvt lvt hvt}} { error "VT inválido: '$VT' (use rvt, lvt ou hvt)" }

set REPO   [exec git rev-parse --show-toplevel]
set PDK    /Tools/PDK/SAED32/EDK_Digital
# Só a função lógica das células importa aqui; qualquer corner serve.
set DB     $PDK/lib/stdcell_${VT}/db_nldm/saed32${VT}_tt1p05v25c.db
# Multi-Vt: com VT_EXTRA (ex.: lvt), as células da outra família também
# precisam do .db; sem ele viram caixa-preta e a prova não vale.
if {![info exists VT_EXTRA]} { set VT_EXTRA {} }
set DBS [list $DB]
foreach _v $VT_EXTRA { lappend DBS $PDK/lib/stdcell_${_v}/db_nldm/saed32${_v}_tt1p05v25c.db }
set FLIST  $REPO/tool_data/vcs/flist_rtl.f
set TOP    cv32e40p_top
set PARAMS "COREV_PULP=0,COREV_CLUSTER=0,FPU=0,ZFINX=0,NUM_MHPMCOUNTERS=1"
set TOP_ELAB ${TOP}_[string map {= "" , _} $PARAMS]

# Pós-layout (fluxo físico): informe a netlist final e o SVF da rodada, ex.:
#   -x "set VT hvt; set NETLIST runs/pnr_hvt_<data>/outputs/cv32e40p_top_finish.v;
#       set SVF runs/pnr_hvt_<data>/cv32e40p.svf"
# Síntese do fluxo atual: a mesma coisa, com a netlist do 03:
#   NETLIST runs/pnr_hvt_<data>/outputs/cv32e40p_top_syn.v
# Sem NETLIST nem SYN_RUN, o script para com erro (não escolhe sozinho).
if {[info exists NETLIST]} {
    if {![info exists SVF]} { error "Com NETLIST, informe também o SVF da mesma rodada" }
    set NETLIST [file normalize $NETLIST]
    set SVF     [file normalize $SVF]
} else {
    # Sem escolha automática da "rodada mais recente": ela poderia pegar uma
    # rodada syn_<vt>_* em vez da do fluxo atual (pnr_hvt_*). Quem roda
    # informa qual netlist está provando.
    if {![info exists SYN_RUN]} {
        error "Informe a netlist: -x \"set VT hvt; set NETLIST runs/<rodada>/outputs/cv32e40p_top_syn.v; set SVF runs/<rodada>/cv32e40p.svf\" (ou SYN_RUN para as rodadas syn_*)"
    }
    set SYN_RUN [file normalize $SYN_RUN]
    set NETLIST $SYN_RUN/${TOP}_syn.v
    set SVF     $SYN_RUN/cv32e40p.svf
}
set RUN_DIR $REPO/runs/fm_${VT}_[clock format [clock seconds] -format %Y%m%d-%H%M%S]
set RPT     $RUN_DIR/rpt

foreach f [concat $DBS [list $FLIST $NETLIST $SVF]] {
    if {![file exists $f]} { error "Arquivo não encontrado: $f" }
}
if {![string match *clock_gate_saed32* [exec cat $FLIST]]} {
    error "A filelist não é a de síntese. Rode antes: scripts/gen_filelist.sh --synthesis"
}
file mkdir $RPT
puts "### Formality: $NETLIST (SVF $SVF) -> $RUN_DIR"

# ==== Passo 2 — Configuração automática e SVF [confirmado] ==================
# synopsys_auto_setup ajusta o Formality para interpretar o RTL do mesmo jeito
# que a síntese da Synopsys. Tem que vir antes do set_svf.
set synopsys_auto_setup true
set_svf $SVF

# ==== Passo 3 — Biblioteca de células [confirmado] ==========================
# -tech: a biblioteca vale para a referência e a implementação. O RTL também
# precisa dela, porque instancia a célula de clock gate CGLPPRX2_<VT>.
foreach _db $DBS { read_db -tech $_db }

# ==== Passo 4 — Referência: o RTL [confirmado] ==============================
set DEFS SYNTHESIS
if {$VT eq "lvt"} { lappend DEFS VT_LVT }
if {$VT eq "hvt"} { lappend DEFS VT_HVT }
read_sverilog -r -libname WORK -define $DEFS -vcs "-f $FLIST"
set_top r:/WORK/$TOP -parameter $PARAMS

# ==== Passo 5 — Implementação: a netlist [confirmado] =======================
read_verilog -i -libname WORK $NETLIST
set_top i:/WORK/$TOP_ELAB

# ==== Passo 6 — Casar e provar [confirmado] =================================
match
report_unmatched_points > $RPT/unmatched.rpt
verify
report_status          > $RPT/status.rpt
report_failing_points  > $RPT/failing.rpt
report_aborted_points  > $RPT/aborted.rpt

# Resultado: sai com erro (exit 1) se não for SUCCEEDED, para que quem chamou
# o Formality (make, outro script) perceba a falha.
set _st [exec cat $RPT/status.rpt]
if {[string match "*Verification SUCCEEDED*" $_st]} {
    puts "### Formality: SUCCEEDED. Relatórios em $RPT"
    exit 0
}
puts "### Formality: NÃO PASSOU. Veja $RPT/status.rpt e failing.rpt"
exit 1
