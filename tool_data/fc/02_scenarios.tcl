# tool_data/fc/02_scenarios.tcl — modos, corners, cenários e constraints (HVT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# COMO USAR: na mesma sessão do fc_shell do 01, um bloco por vez.
#
# Ideia geral:
#   modo     = o que o chip está fazendo (aqui só "func", funcionamento normal);
#   corner   = condição de processo, tensão e temperatura;
#   cenário  = modo + corner. O timing e a potência são analisados por cenário.
# Usamos três corners (decisão de corners em docs/decisions.md), todos do
# conjunto nominal de 1,05 V do databook da biblioteca (Tabela 1.6, p. 19;
# estudo E01):
#   ss  0,95 V 125 °C  (lento:  -10 %)  -> pior caso de setup
#   tt  1,05 V  25 °C  (típico: nominal) -> referência e potência
#   ff  1,16 V -40 °C  (rápido: +10 %)  -> pior caso de hold
# Setup e hold são ANALISADOS e RELATADOS nos três (bloco 2.6): o professor
# pede os três corners em todos os relatórios.
# Armadilha: não usar o ss0p75 (0,75 V). Ele é do conjunto "middle voltage"
# e não se mistura com tt1p05/ff1p16. Por que importa: docs/estudos/E01.

### BLOCO 2.1 — Limpar definições anteriores ###################################
# Garante que não sobrou modo, corner ou cenário de uma tentativa anterior.
# O catch ignora o erro quando não há nada para remover (rodada nova). Sem
# ele, rodando em segundo plano (run_01_a_03.tcl), o script para aqui.
catch {remove_scenarios -all}
catch {remove_modes     -all}
catch {remove_corners   -all}

### BLOCO 2.2 — Modelos dos fios (TLU+) #########################################
# Lê as três versões das tabelas de resistência e capacitância dos fios:
#   Cmax: fios mais lentos (pior caso para setup);
#   nominal: típico;
#   Cmin: fios mais rápidos (pior caso para hold).
read_parasitic_tech -tlup $TLUPLUS_MAX_FILE -layermap $TLUPLUS_MAP_FILE -name Cmax
read_parasitic_tech -tlup $TLUPLUS_TYP_FILE -layermap $TLUPLUS_MAP_FILE -name nominal
read_parasitic_tech -tlup $TLUPLUS_MIN_FILE -layermap $TLUPLUS_MAP_FILE -name Cmin

### BLOCO 2.3 — Modo, corners e cenários ########################################
create_mode func
foreach c {ss tt ff} { create_corner $c }
create_scenario -name func_ss -mode func -corner ss
create_scenario -name func_tt -mode func -corner tt
create_scenario -name func_ff -mode func -corner ff

### BLOCO 2.4 — Condição de cada corner ########################################
# A NDM tem uma biblioteca para cada condição. A ferramenta escolhe a de cada
# corner por três números: processo, tensão e temperatura. Os três são
# obrigatórios: sem o processo, o tt e o ff pegam a biblioteca errada
# (aviso PVT-030). Processo: ss 0,99, tt 1,00, ff 1,01 (lidos nos .lib).
# Tensão do ss: 0,95 V (decisão de corners em docs/decisions.md; estudo E01).
array set PVT {ss {0.99 0.95 125} tt {1.00 1.05 25} ff {1.01 1.16 -40}}
foreach c {ss tt ff} {
    current_corner $c
    lassign $PVT($c) p v t
    set_process_number $p
    set_voltage $v -object_list [get_supply_nets $POWER_NET]
    set_temperature $t
}
# Cada corner usa o modelo de fio que combina com ele.
set_parasitic_parameters -corner ss -early_spec Cmax    -late_spec Cmax
set_parasitic_parameters -corner tt -early_spec nominal -late_spec nominal
set_parasitic_parameters -corner ff -early_spec Cmin    -late_spec Cmin
# Margem de variação no chip (OCV): o caminho que chega tarde fica 5 % mais
# lento e o que chega cedo, 5 % mais rápido. Deixa a análise pessimista.
foreach c {ss tt ff} {
    current_corner $c
    set_timing_derate -late  1.05
    set_timing_derate -early 0.95
}
# CONFERIR (o mais importante deste arquivo): "no PVT mismatches" nos três
# corners. Se aparecer PVT-030, a biblioteca do corner está errada: veja
# o PVT-030 em docs/erros-conhecidos.md antes de seguir.
# PRINT: esta saída.
report_pvt
report_pvt > $RPT_DIR/02_pvt.rpt

### BLOCO 2.5 — Constraints (SDC) ##############################################
# O SDC define o clock, os atrasos das entradas e saídas e as cargas. Ele usa
# a variável CLK_PERIOD do 00_tech_setup, por isso é "source", e não read_sdc.
# O SDC é lido UMA VEZ EM CADA CENÁRIO: parte dele (atrasos de entrada e
# saída) só vale no cenário atual. Lido uma vez só, os outros cenários ficam
# sem atraso nas entradas (TCK-012 no check_timing), e o setup deles não
# analisa os caminhos de entrada e saída.
# Pode avisar que o clock foi redefinido: é o mesmo clock em cada cenário.
foreach s {func_ss func_tt func_ff} {
    current_scenario $s
    source $SDC
}
# CONFERIR / PRINT: o clk_i com o período do CLK_PERIOD.
report_clocks
report_clocks > $RPT_DIR/02_clocks.rpt

### BLOCO 2.6 — O que cada cenário analisa #####################################
# Setup E hold ligados nos TRÊS cenários. Assim o report_qor mostra cada
# corner numa linha própria, para setup e para hold.
# Atenção ao ler o report_qor -summary: a linha "Design" NÃO é um corner.
# É o resumo de todos os cenários: o WNS dela é o pior entre eles; TNS e NVE
# dela não são a soma (medido; o man não define essa linha; estudo E02).
# Com hold ligado, o min_cap também passa a ser checado no ss e no tt
# (man set_scenario_status: -min_capacitance precisa de -hold).
# Se o ff tivesse só hold e o ss/tt só setup, o ff não apareceria no setup
# e a linha "Design" pareceria uma cópia do ss.
# Potência: só no tt. É uma ESTIMATIVA: sem atividade de simulação (SAIF),
# a ferramenta supõe uma taxa de chaveamento padrão. O pior vazamento seria
# no ff a 125 °C, que não é analisado (ver estudo E08).
# Por que a síntese mostra hold negativo no ff: o clock ainda é ideal; o
# hold é corrigido depois do CTS (07). Ver estudo E07.
set_scenario_status func_ss -setup true -hold true -leakage_power false -dynamic_power false
set_scenario_status func_tt -setup true -hold true -leakage_power true  -dynamic_power true
set_scenario_status func_ff -setup true -hold true -leakage_power false -dynamic_power false
# PRINT: a tabela de cenários. CONFERIR: Setup e Hold "true" nas três linhas.
report_scenarios
report_scenarios > $RPT_DIR/02_scenarios.rpt

### BLOCO 2.7 — Proteger o clock gate ##########################################
# Proíbe a ferramenta de trocar ou apagar o clock gate escolhido no RTL.
set_dont_touch [get_cells -hierarchical -filter "ref_name =~ ${CLOCK_GATE}*"]
# CONFERIR: imprime 1.

### BLOCO 2.8 — Checagens das constraints ######################################
# check_timing: avisa se falta constraint (entrada sem atraso, flip-flop sem
# clock, laço combinacional).
check_timing > $RPT_DIR/02_check_timing.rpt
check_timing
# Exceções (false path, multicycle) e valores fixos (case analysis) em vigor.
# Esperado: só o case analysis do scan_cg_en_i = 0 (ver o fim do SDC).
report_exceptions    > $RPT_DIR/02_exceptions.rpt
report_case_analysis > $RPT_DIR/02_case_analysis.rpt
# Grava o SDC como a ferramenta entendeu, para conferir depois.
write_sdc -output $OUT_DIR/02_constraints_lidas.sdc

### BLOCO 2.9 — Salvar ##########################################################
save_block -as ${DESIGN}_scenarios
save_lib
puts "### 02_scenarios pronto. Próximo: tool_data/fc/03_synth.tcl"
