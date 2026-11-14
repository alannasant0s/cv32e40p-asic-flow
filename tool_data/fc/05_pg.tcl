# tool_data/fc/05_pg.tcl — rede de alimentação, PG (HVT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Critérios de aceite desta etapa: docs/criterios-aceite.md.
#
# PG = power/ground. Toda célula precisa de VDD (alimentação) e VSS (terra).
# A rede de alimentação leva VDD e VSS a todas elas, em três níveis:
#   1. anel (ring): VDD e VSS em volta do core, em metal grosso;
#   2. malha (mesh): faixas que atravessam o core, ligadas ao anel;
#   3. trilhos (rails): linhas finas em M1, ao longo de cada row, onde os
#      pinos VDD/VSS das células encostam.
# Camadas: M7 e M9 são horizontais, M8 é vertical (report_design -floorplan, 04).
# A malha usa M8 (vertical) e M9 (horizontal). NÃO usar M7 na malha: as
# pilhas de via dos trilhos (M1) até o M8 atravessam o M7 e dão curto com
# faixas da outra rede (shorts e erros de espaçamento em M7).
#
# COMO USAR: na mesma sessão do fc_shell do 04, um bloco por vez.
# Esperado no fim (bloco 5.5): sem erro de DRC e sem nenhum fio solto.

### BLOCO 5.1 — Ligar os pinos VDD/VSS das células às redes ####################
# Diz à ferramenta que todo pino de alimentação das células vai na rede VDD e
# todo pino de terra vai na rede VSS. Ainda não desenha nada: é a ligação
# lógica.
# Esperado: o mesmo número de pinos VDD e VSS ligados (um par por célula).
connect_pg_net -automatic
# CONFERIR: sem "Error".

### BLOCO 5.2 — Anel em volta do core ##########################################
# Largura 1,5 µm, espaço 0,6 µm entre VDD e VSS, 0,5 µm de distância do core.
# Por que 0,6 µm e não 0,5 µm: fio largo pede mais espaço; com 0,5 µm o DRC
# oficial (ICV) acusa M7.S.3.3 e M8.S.3.3 nos lados do anel.
# Ocupa uns 4 µm; a margem do floorplan (core_offset) é de 5 µm.
# Esperado: 8 fios (4 lados x VDD/VSS) e 8 vias nos cantos.
# Aviso PGR-095 ("via rule is not defined"): usa as vias padrão da tecnologia.
create_pg_ring_pattern anel \
    -horizontal_layer M7 -horizontal_width 1.5 -horizontal_spacing 0.6 \
    -vertical_layer   M8 -vertical_width   1.5 -vertical_spacing   0.6
set_pg_strategy estrategia_anel -core \
    -pattern {{name: anel} {nets: {VDD VSS}} {offset: {0.5 0.5}}}
compile_pg -strategies estrategia_anel
# PRINT (GUI): o anel em volta do core.

### BLOCO 5.3 — Malha sobre o core #############################################
# Faixas de 1 µm, uma a cada 30 µm, alternando VDD e VSS: horizontais em M9 e
# verticais em M8, ligadas ao anel.
# Por que M9 e não M7 nas horizontais: com a malha em M7, as vias dos
# trilhos (bloco 5.4) não podem ser criadas (curto no M7).
create_pg_mesh_pattern malha -layers {     {{horizontal_layer: M9} {width: 1} {pitch: 30} {offset: 15} {spacing: interleaving}}     {{vertical_layer: M8}   {width: 1} {pitch: 30} {offset: 15} {spacing: interleaving}} }
set_pg_strategy estrategia_malha -core     -pattern {{name: malha} {nets: {VDD VSS}}}     -extension {{stop: outermost_ring}}
compile_pg -strategies estrategia_malha
# PRINT (GUI): a malha cruzando o core.

### BLOCO 5.4 — Trilhos em M1 nas rows #########################################
# Linhas de VDD e VSS em M1 ao longo de cada row, onde as células encostam.
# Os trilhos precisam de vias até o M8 (pilha M1 -> M8), criadas à parte
# (comando abaixo, depois do compile_pg).
create_pg_std_cell_conn_pattern trilhos -layers {M1}
set_pg_strategy estrategia_trilhos -core \
    -pattern {{name: trilhos} {nets: {VDD VSS}}}
compile_pg -strategies estrategia_trilhos
# O compile_pg cria os trilhos mas não as vias até a malha: sem células
# posicionadas, ele julga os trilhos "soltos" e descarta as pilhas
# ("Found N dangling/floating vias"), e o check_pg_connectivity acusa
# trilhos soltos. Com a checagem ligada, o
# create_pg_vias também descarta (PGR-051). Por isso as vias são criadas sem
# esse filtro (-drc no_check) e conferidas logo depois, no bloco 5.5, por
# duas checagens independentes: check_pg_drc (0 erros) e
# check_pg_connectivity (0 fios soltos).
create_pg_vias -nets {VDD VSS} -from_layers M1 -to_layers M8 -drc no_check
# CONFERIR: "Committed N vias", com N = número de pilhas x 7 níveis (M1 -> M8).

### BLOCO 5.5 — Conferir a rede #################################################
# check_pg_connectivity: tudo o que é VDD/VSS está ligado ao anel? Não pode
# sobrar pedaço solto ("floating").
# check_pg_drc: a rede respeita as regras de desenho (largura, espaço)?
# Resultado esperado: "No errors found"; VDD e VSS com
# "floating wires: 0". Todas as células aparecem como "floating std cells"
# porque ainda não foram posicionadas: isso se resolve no placement.
check_pg_connectivity
check_pg_connectivity > $RPT_DIR/05_pg_connectivity.rpt
check_pg_drc
check_pg_drc > $RPT_DIR/05_pg_drc.rpt

### BLOCO 5.6 — Salvar ##########################################################
save_block
save_lib
puts "### 05_pg pronto. Próximo: tool_data/fc/06_place.tcl (placement)"
