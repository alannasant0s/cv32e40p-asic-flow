# tool_data/lint/lint.tcl — lint do RTL do CV32E40P no VC SpyGlass
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Relatório em runs/lint_<data>/lint.rpt. Na elaboração, o esperado é
# 0 latches (detalhes em docs/lint.md).
#
# Lint é uma checagem automática do RTL procurando código suspeito (sinais
# sem uso, larguras diferentes, latch sem querer...) antes da síntese. O RTL
# é do OpenHW e não é alterado: o resultado esperado é um relatório com cada
# aviso justificado, não correções.
#
# Uso (da raiz do repositório, depois de source /Tools/synopsys-scripts/snps.sh):
#   scripts/gen_filelist.sh --synthesis
#   nohup vc_static_shell -f tool_data/lint/lint.tcl > lint.log 2>&1 &
#
# Usa a filelist de síntese (o que vai virar circuito). O clock gate da SAED32
# instancia uma célula da biblioteca (CGLPPRX2_*), que o lint não conhece:
# um aviso de módulo não encontrado para ela é esperado.

# ==== Caminhos [confirmado] ==================================================
set REPO    [exec git rev-parse --show-toplevel]
set FLIST   $REPO/tool_data/vcs/flist_rtl.f
set TOP     cv32e40p_top
set PARAMS  "COREV_PULP=0,COREV_CLUSTER=0,FPU=0,ZFINX=0,NUM_MHPMCOUNTERS=1"
set RUN_DIR $REPO/runs/lint_[clock format [clock seconds] -format %Y%m%d-%H%M%S]
file mkdir $RUN_DIR

if {![file exists $FLIST]} { error "Filelist não encontrada: $FLIST" }

# ==== Ligar o lint [confirmado] =============================================
set_app_var enable_lint true
configure_lint_setup -goal lint_rtl

# ==== Ler e montar o RTL [confirmado] =======================================
analyze -format sverilog -vcs "-f $FLIST +define+SYNTHESIS+VT_HVT"
elaborate $TOP -parameters $PARAMS

# ==== Rodar e salvar o relatório [confirmado] ===============================
check_lint
# report_lint funciona, mas a ferramenta avisa que está obsoleto e indica
# report_violations. TODO(verify): opções do report_violations.
report_lint -verbose -file $RUN_DIR/lint.rpt

puts "### Lint terminado. Relatório em $RUN_DIR/lint.rpt"
quit
