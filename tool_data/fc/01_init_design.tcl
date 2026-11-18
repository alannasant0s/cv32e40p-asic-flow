# tool_data/fc/01_init_design.tcl — criar a biblioteca e ler o RTL (HVT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# COMO USAR: com o fc_shell aberto na raiz do repositório (preparação em
# docs/passo-a-passo-sintese.md), cole UM COMANDO por vez, lendo o
# comentário antes. Depois, faça o que diz CONFERIR e tire print do que diz
# PRINT.

### BLOCO 1.1 — Variáveis ######################################################
source tool_data/fc/00_tech_setup.tcl
# CONFERIR: a última linha mostra "família hvt" e a pasta da rodada em runs/.

### BLOCO 1.2 — Arquivo para o Formality #######################################
# Liga o SVF, um registro de tudo o que a ferramenta renomear ou otimizar.
# O Formality usa esse arquivo para comparar a netlist com o RTL.
# Tem que vir antes de ler o RTL.
set_svf $RUN_DIR/cv32e40p.svf

### BLOCO 1.3 — Biblioteca do projeto ##########################################
# Cria a biblioteca do projeto (cv32e40p_lib, dentro da pasta da rodada).
# -technology: camadas de metal e regras de desenho da SAED32.
# -ref_libs:   a NDM da HVT. Daqui para frente só existem células HVT.
create_lib -technology $TECH_FILE -ref_libs $REFERENCE_LIBRARY $RUN_DIR/cv32e40p_lib
# CONFERIR: sem "Error"; aparece "Loading technology file ... saed32nm_1p9m.tf"
# e o nome da biblioteca criada, {cv32e40p_lib}. O aviso TECH-025 (VIA1 com
# "onGrid" e "onWireTrack") vem do arquivo de tecnologia e é esperado. A NDM
# saed32hvt_c só é carregada de fato no 1.5 (mensagem LNK-040).

### BLOCO 1.4 — Ler o RTL ######################################################
# analyze: lê os arquivos .sv da filelist e confere a sintaxe.
#   SYNTHESIS desliga o código que só serve para simulação.
#   VT_HVT escolhe o clock gate CGLPPRX2_HVT.
analyze -format sverilog -define {SYNTHESIS VT_HVT} -vcs "-f $FLIST"
# CONFERIR: a última linha é 1 (0 = falhou; procure a primeira "Error:").

### BLOCO 1.5 — Montar o circuito (elaborate) ##################################
# Monta o circuito a partir do módulo do topo, com os parâmetros do projeto.
# O resultado ainda é lógica genérica (somadores, multiplexadores, registradores
# "ideais"), não células da SAED32. A hierarquia do RTL existe aqui.
elaborate $DESIGN -parameters $PARAMS
# CONFERIR: elaborate termina com 1, e current_design mostra o nome com os
# parâmetros (cv32e40p_top_COREV_PULP0_..._NUM_MHPMCOUNTERS1).
# set_top_module faz o link do topo (liga o projeto às células da
# biblioteca). É aqui que a NDM da HVT é usada de fato: aparece
# "User units loaded from library 'saed32hvt_c' (LNK-040)" e o comando
# devolve 1. Sem ele, o 02 para em create_mode com DES-149 "cannot be
# auto-linked".
set_top_module $DESIGN_ELAB
current_design
# Hierarquia do RTL (conferida neste servidor). Cada nível de recuo é um
# submódulo. Além dos blocos do processador (if_stage, id_stage, ex_stage,
# load_store_unit, cs_registers...), aparecem:
#   __wvGtech__  lógica genérica (SELECT_OP = multiplexador, OR, AND...);
#   DW01_*, DW_* componentes aritméticos prontos da Synopsys (DesignWare):
#                somadores, comparadores, multiplicadores, deslocadores;
#   saed32hvt_c  algumas células HVT já escolhidas dentro desses componentes.
report_hierarchy -nosplit > $RPT_DIR/01_hierarquia_rtl.rpt
report_hierarchy -nosplit
# PRINT (só os blocos do processador, sem a lógica genérica): num terminal
# Linux comum, fora do fc_shell, troque <pasta> pela pasta da rodada:
#   grep -v -E "Gtech|saed32|DW|_OP" runs/<pasta>/rpt/01_hierarquia_rtl.rpt

### BLOCO 1.6 — Netlist flat ####################################################
# Flat: a síntese desfaz os submódulos (if_stage, id_stage, ex_stage...) e
# otimiza o processador como um bloco só, atravessando as fronteiras entre
# eles. Costuma dar timing um pouco melhor. O flat é permitido pelo professor
# (docs/requisitos-professor.md; decisão do flat em docs/decisions.md).
# No fim, o report_qor mostra "Hierarchical Cell Count: 1": esse 1
# é o core_i (cv32e40p_core), e tudo abaixo dele foi desfeito.
set_app_options -name compile.flow.autoungroup -value true
# CONFERIR: a coluna User-value mostra true.
# A coluna System-default também mostra true: o Fusion Compiler já desfaz a
# hierarquia por padrão. O comando deixa a decisão explícita no script, sem
# depender do padrão da ferramenta.
report_app_options compile.flow.autoungroup

### BLOCO 1.7 — Salvar ##########################################################
# Salva o estado. Se algo der errado no 02, dá para reabrir daqui.
save_block -as ${DESIGN}_init
save_lib
puts "### 01_init_design pronto. Próximo: tool_data/fc/02_scenarios.tcl"
