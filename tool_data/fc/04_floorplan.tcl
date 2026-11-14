# tool_data/fc/04_floorplan.tcl — floorplan (HVT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Critérios de aceite desta etapa: docs/criterios-aceite.md.
#
# O floorplan define o "terreno" do chip: o tamanho e o formato da área onde
# as células vão ficar (core), a margem em volta, as linhas onde as células se
# encaixam (rows) e a posição dos pinos de entrada e saída.
# Sem ele, o compile_fusion inventa um floorplan automático (aviso LGL-397 e
# "Generated core area" no log). Aqui decidimos nós.
#
# COMO USAR: abra o fc_shell da raiz do repositório e cole um bloco por vez.

### BLOCO 4.1 — Abrir a síntese numa cópia #####################################
# Trabalha numa CÓPIA do bloco da síntese (cv32e40p_top_fp), para o
# cv32e40p_top_syn continuar intacto. HVT a 8 ns.
# RUN_DIR: escreva a pasta da SUA rodada da síntese (a do 01 a 03), por
# exemplo: set RUN_DIR [pwd]/runs/pnr_hvt_AAAAMMDD-HHMMSS
# A pasta não é escolhida sozinha de propósito: a mais recente pode ser a de
# um teste. Liste as pastas com: ls runs/
if {![info exists RUN_DIR]} { error "Defina RUN_DIR com a pasta da sua rodada (ls runs/)." }
puts "Rodada: $RUN_DIR"
source tool_data/fc/00_tech_setup.tcl
open_lib $RUN_DIR/cv32e40p_lib
# copy_block: copia um bloco dentro da biblioteca.
copy_block -from_block ${DESIGN}_syn -to_block ${DESIGN}_fp
open_block ${DESIGN}_fp
set_svf -append $RUN_DIR/cv32e40p.svf
# CONFERIR: o clock continua com 8 ns.
report_clocks

### BLOCO 4.2 — Criar o floorplan ##############################################
# core_utilization: que fração do core as células ocupam. 0,70 deixa 30 % de
# espaço livre para os buffers do CTS, as correções de hold e os fios do
# roteamento. O floorplan automático da ferramenta sai mais cheio, com
# menos folga.
# side_ratio {1 1}: core quadrado (altura = largura).
# core_offset: margem de 5 µm entre o core e a borda do bloco, para os anéis
# de alimentação (05_pg.tcl).
initialize_floorplan -core_utilization 0.70 -side_ratio {1 1} -core_offset {5}
# CONFERIR: sem "Error". O LGL-397 ("No site rows") deve parar de aparecer
# daqui em diante, porque agora existem rows.

### BLOCO 4.3 — Posicionar os pinos de entrada e saída #########################
# Distribui os 379 pinos (clock, reset, interfaces de instrução e de dados,
# interrupções, debug) pelas bordas do bloco, perto das células que usam
# cada um.
place_pins -self
# CONFERIR: sem "Error".

### BLOCO 4.4 — Conferir ######################################################
# Tamanho do core e do bloco, número de rows e ocupação.
report_design -floorplan
report_design -floorplan > $RPT_DIR/04_floorplan.rpt
# PRINT (GUI, X2Go): o floorplan vazio, só com o contorno do core, as rows e
# os pinos nas bordas. As células ainda não foram posicionadas.

### BLOCO 4.5 — Salvar #########################################################
save_block
save_lib
puts "### 04_floorplan pronto. Próximo: tool_data/fc/05_pg.tcl (rede de alimentação)"
