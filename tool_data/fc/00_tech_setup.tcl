# tool_data/fc/00_tech_setup.tcl — variáveis do projeto e da tecnologia (HVT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Só define variáveis: não chama nenhuma ferramenta e não muda nada.
# Este arquivo pode ser carregado inteiro, no console do fc_shell, da raiz
# do repositório:
#     source tool_data/fc/00_tech_setup.tcl
# Os outros arquivos (01, 02, 03...) usam estas variáveis.

###############################################################################
# Projeto
###############################################################################
set VT          hvt
# Multi-Vt: famílias a mais que a ferramenta pode usar além da VT (ex.: lvt).
# Vazio = família única. Com {lvt}, a NDM e o GDS da LVT entram na lista de
# referência (01) e no DRC (08, 09).
if {![info exists VT_EXTRA]} { set VT_EXTRA {} }
set DESIGN      cv32e40p_top
# Parâmetros do RTL: sem extensões PULP, sem FPU. Na mesma ordem em que estão
# declarados no cv32e40p_top.sv (o elaborate gruda no nome do módulo nessa ordem).
set PARAMS      "COREV_PULP=0,COREV_CLUSTER=0,FPU=0,ZFINX=0,NUM_MHPMCOUNTERS=1"
# Nome que o módulo do topo ganha depois do elaborate, com os parâmetros.
set DESIGN_ELAB ${DESIGN}_[string map {= "" , _} $PARAMS]

# Período do clock em ns: 8 ns = 125 MHz, requisito do projeto (decisão do
# clock em docs/decisions.md).
# É menos da metade da frequência de referência do databook da SAED32
# (300 MHz, Tabela 1.4, p. 18): com os corners certos (estudo E01), 8 ns não
# é um clock difícil. Armadilha: com o ss de 0,75 V (de outro conjunto de
# tensão) a HVT parece não fechar no ss. Ver docs/estudos/E01-corners.md.
set CLK_PERIOD  8.0

###############################################################################
# Pastas
###############################################################################
set PRJT_BASE   [pwd]
set PDK         /Tools/PDK/SAED32/EDK_Digital
set NDM_DIR     $PRJT_BASE/ndm_lib
set FLIST       $PRJT_BASE/tool_data/vcs/flist_rtl.f
set SDC         $PRJT_BASE/constraints/cv32e40p_baseline.sdc
# Uma pasta por rodada, com a data e a hora: uma rodada não apaga a outra.
# Para continuar uma rodada já começada (fc_shell fechado no meio), defina
# RUN_DIR com a pasta dela antes de carregar este arquivo.
if {![info exists RUN_DIR]} {
    set RUN_DIR $PRJT_BASE/runs/pnr_${VT}_[clock format [clock seconds] -format %Y%m%d-%H%M%S]
}
set RPT_DIR     $RUN_DIR/rpt
set OUT_DIR     $RUN_DIR/outputs
file mkdir $RPT_DIR $OUT_DIR

###############################################################################
# Arquivos da tecnologia
###############################################################################
set TECH_FILE         $PDK/tech/tf/saed32nm_1p9m.tf
set REFERENCE_LIBRARY {}
set GDS_CELULAS       {}
foreach _v [concat $VT $VT_EXTRA] {
    lappend REFERENCE_LIBRARY $NDM_DIR/saed32${_v}_c.ndm
    # desenho das células de cada família, juntado ao layout no DRC do ICV
    lappend GDS_CELULAS $PDK/lib/stdcell_${_v}/gds/saed32nm_${_v}_oa.gds
}
# TLU+: tabelas de resistência e capacitância dos fios, uma por condição.
set TLUPLUS_MAX_FILE  $PDK/tech/starrc/max/saed32nm_1p9m_Cmax.tluplus
set TLUPLUS_TYP_FILE  $PDK/tech/starrc/nominal/saed32nm_1p9m_nominal.tluplus
set TLUPLUS_MIN_FILE  $PDK/tech/starrc/min/saed32nm_1p9m_Cmin.tluplus
set TLUPLUS_MAP_FILE  $PDK/tech/starrc/saed32nm_tf_itf_tluplus.map

###############################################################################
# Alimentação (PG = power/ground)
###############################################################################
set POWER_NET             VDD
set GROUND_NET            VSS
set STD_CELLS_POWER_PIN   VDD
set STD_CELLS_GROUND_PIN  VSS

###############################################################################
# Células especiais da HVT (todas conferidas na NDM da SAED32)
###############################################################################
# Tie: fornecem 1 ou 0 fixo às entradas que o RTL liga direto em VDD/VSS.
set TIE_HIGH       TIEH_HVT
set TIE_LOW        TIEL_HVT
# Delay: atrasam um sinal de propósito; usadas para corrigir hold.
set DELAY_CELLS    "DELLN3X2_HVT DELLN2X2_HVT DELLN1X2_HVT"
# Filler: preenchem os buracos entre as células no fim, para as linhas de
# alimentação ficarem contínuas. Da maior para a menor.
set FILLER_CELLS   "SHFILL128_HVT SHFILL64_HVT SHFILL3_HVT SHFILL2_HVT SHFILL1_HVT"
# Decap: capacitores entre VDD e VSS que seguram a tensão quando muitas
# células chaveiam juntas.
set DECAP_CELLS    DCAP_HVT
# Diodo de antena: protege a porta do transistor da carga acumulada no metal
# durante a fabricação.
set ANTENNA_DIODES ANTENNA_HVT
# Clock gate escolhido no RTL (rtl/cv32e40p_clock_gate_saed32.sv).
set CLOCK_GATE     CGLPPRX2_HVT
# Limites de transição, capacitância e fanout: os da biblioteca (ver constraints/cv32e40p_baseline.sdc),
# por isso não há variável para eles aqui.

puts "### 00_tech_setup: família $VT, clock ${CLK_PERIOD} ns, rodada $RUN_DIR"
