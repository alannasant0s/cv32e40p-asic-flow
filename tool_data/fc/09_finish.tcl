# tool_data/fc/09_finish.tcl — acabamento e entregáveis (HVT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Critérios de aceite desta etapa: docs/criterios-aceite.md.
#
# O que esta etapa faz, em ordem:
#   9.1  copia o melhor bloco roteado para um bloco novo (_finish)
#   9.2  preenche os espaços vazios das rows com células de enchimento
#        (fillers) e capacitores de desacoplamento (DCAP)
#   9.3  confere tudo de novo: fios, alimentação, LVS da ferramenta e DRC
#        oficial (ICV), porque as células novas também têm metal
#   9.4  relatórios finais (timing, potência, área, violações elétricas)
#   9.5  grava os arquivos de saída: netlist, SDC, SDF, SPEF, DEF e GDS
#
# Termos:
#   filler  célula sem lógica, só com os trilhos VDD/VSS e os poços. Fecha
#           os buracos da row para os poços (N-well) e os trilhos ficarem
#           contínuos; a fábrica exige.
#   DCAP    célula de enchimento que também é um capacitor entre VDD e VSS:
#           segura a tensão quando muitas células chaveiam juntas.
#   LVS     "layout versus schematic": confere se as ligações desenhadas são
#           as mesmas da netlist (nenhum fio faltando ou em curto).
#   SPEF    resistências e capacitâncias dos fios reais (para STA externo).
#   SDF     atrasos de cada célula e fio (para simulação com atraso).
#   GDS     o desenho final, camada por camada, que vai para a fábrica.
#
# ENTRADA: bloco ${DESIGN}_route (fim do 08).
#
# COMO USAR: na mesma sessão do 08 (GUI pelo X2Go), bloco a bloco.

### BLOCO 9.1 — Cópia do bloco roteado #########################################
save_block
# Origem: o bloco final do 08_route.tcl (${DESIGN}_route).
copy_block -from_block ${DESIGN}_route -to_block ${DESIGN}_finish
open_block ${DESIGN}_finish
# SVF: registra no arquivo da rodada o que a ferramenta muda na netlist (o
# Formality lê depois). Repetido a cada etapa: se o fc_shell foi reaberto,
# sem isto o registro iria para um default-*.svf solto na pasta.
set_svf -append $RUN_DIR/cv32e40p.svf
current_block
# As opções do ICV valem por bloco: configurar de novo neste bloco.
set_app_options -name signoff.check_drc.runset \
    -value $PDK/tech/icv_drc/saed32nm_1p9m_drc_rules.rs
set_app_options -name signoff.physical.merge_stream_files \
    -value $GDS_CELULAS

### BLOCO 9.2 — Fillers e DCAP ##################################################
# Antes: as células precisam estar legais (sem sobreposição), senão o
# preenchimento falha. Esperado: 0 violações.
check_legality
report_utilization > $RPT_DIR/09_utilizacao_antes_fillers.rpt

# 1º os DCAP (têm metal em M1), em todo espaço livre onde couberem.
# -continue_on_error: segue mesmo se não couber em algum buraco.
create_stdcell_fillers -lib_cells $DECAP_CELLS -continue_on_error
# Tira os DCAP que ficaram em conflito com fios já roteados (DRC).
remove_stdcell_fillers_with_violation
# 2º os fillers sem lógica (SHFILL), do maior para o menor, no que sobrou.
create_stdcell_fillers -lib_cells $FILLER_CELLS
# Liga os pinos VDD/VSS das células novas às redes de alimentação.
connect_pg_net -net $POWER_NET  [get_pins -physical_context */$STD_CELLS_POWER_PIN]
connect_pg_net -net $GROUND_NET [get_pins -physical_context */$STD_CELLS_GROUND_PIN]

# Conferir: quantas entraram e se ainda há buraco vazio.
puts "DCAP:    [sizeof_collection [get_cells -hierarchical -filter {ref_name =~ DCAP*}]]"
puts "SHFILL:  [sizeof_collection [get_cells -hierarchical -filter {ref_name =~ SHFILL*}]]"
check_legality                     > $RPT_DIR/09_legality.rpt
check_empty_space                  > $RPT_DIR/09_espaco_vazio.rpt
report_utilization                 > $RPT_DIR/09_utilizacao_depois_fillers.rpt
save_block
save_lib

### BLOCO 9.3 — Conferências finais ############################################
# Fios: 0 redes abertas. (Regras de antena ainda não carregadas: depende do
# estudo E10, docs/estudos/E10-signoff-fisico.md.)
check_routes                       > $RPT_DIR/09_check_routes.rpt
# Alimentação: nenhuma célula, fio ou via de VDD/VSS solta.
check_pg_connectivity              > $RPT_DIR/09_pg_connectivity.rpt
# LVS da própria ferramenta (rápido, não substitui o LVS do ICV).
# Esperado: 0 curtos, 0 abertos, 0 pinos flutuando.
check_lvs -max_errors 200 -checks all -open_reporting detailed \
          -report_floating_pins true > $RPT_DIR/09_check_lvs.rpt
# DRC oficial (ICV) com as células novas, agora com TODAS as camadas.
# Sem a opção, o signoff_check_drc confere só metais e vias, e as regras de
# poço, difusão, poly... ficam como "NOT EXECUTED" na tabela. Com
# -check_all_runset_layers true, todas as regras rodam.
# Critério: 0 violações (docs/criterios-aceite.md, 09.1). Uma regra que não
# aparecia no DRC do 08 só pode ter vindo dos DCAP/fillers.
set_app_options -name signoff.check_drc.run_dir -value $RUN_DIR/icv_drc_finish
save_block
save_lib
signoff_check_drc -check_all_runset_layers true

### BLOCO 9.4 — Relatórios finais ##############################################
qor_resumo $RPT_DIR/09_qor_resumo.rpt
report_qor -scenarios [all_scenarios]                           > $RPT_DIR/09_qor.rpt
# Setup e hold nos três corners, um arquivo por corner e por tipo.
foreach c {ss tt ff} {
    report_timing -scenarios func_$c -delay_type max -max_paths 10 -nosplit > $RPT_DIR/09_timing_setup_$c.rpt
    report_timing -scenarios func_$c -delay_type min -max_paths 10 -nosplit > $RPT_DIR/09_timing_hold_$c.rpt
}
report_constraint -all_violators -max_transition -max_capacitance -nosplit -scenarios [all_scenarios] > $RPT_DIR/09_violacoes_eletricas.rpt
report_power -scenarios func_tt -hierarchy                      > $RPT_DIR/09_power_tt.rpt
report_area -hierarchy                                          > $RPT_DIR/09_area_hier.rpt
# Conferir: setup e hold sem violação (os fillers não mudam o timing).

### BLOCO 9.5 — Arquivos de saída ##############################################
# Nomes compatíveis com Verilog (sem caracteres especiais) antes de gravar.
change_names -rules verilog -hierarchy
# Netlist lógica (sem fillers/DCAP): para o Formality pós-layout e a simulação
# de portas.
write_verilog -exclude {physical_only_cells pg_netlist pg_objects supply_statements} \
    $OUT_DIR/${DESIGN}_finish.v
# Netlist com alimentação (VDD/VSS em cada célula): para o LVS do ICV.
write_verilog -include {pg_netlist pg_objects supply_statements} \
    $OUT_DIR/${DESIGN}_finish_pg.v
# Restrições de timing como estão no fim do fluxo.
write_sdc -output $OUT_DIR/${DESIGN}_finish.sdc
# Atrasos (SDF) de cada corner, para simulação com atraso: o lento (setup)
# e o rápido (hold), mais o típico. O write_sdf não tem -scenario (CMD-010):
# ele usa o cenário atual, então troca antes de cada um.
foreach c {ss tt ff} {
    current_scenario func_$c
    write_sdf $OUT_DIR/${DESIGN}_finish_$c.sdf
}
# Parasitas dos fios (um arquivo por corner).
write_parasitics -format spef -output $OUT_DIR/${DESIGN}_finish
# Posições de células, pinos e fios (formato aberto, lido por outras ferramentas).
write_def -include_tech_via_definitions $OUT_DIR/${DESIGN}_finish.def
# GDS SEM o mapa de camadas do PDK (o FC recusa o mapa, GDS-017; sem mapa ele
# usa a numeração do .tf, que o ICV reconhece). As células entram por referência;
# o desenho delas está no GDS da biblioteca (o ICV junta os dois).
# O write_gds confere TODOS os blocos abertos na sessão e para em qualquer um
# com diferença guardada (GDS-035; costuma ser um bloco de etapa anterior,
# como o _fp ou o _place). Por isso:
# fechar os outros blocos antes (continuam salvos em disco). get_blocks -all
# lista também os fechados; o catch ignora esses. Um bloco aberto duas vezes
# (open_count 2) só fecha com duas chamadas: cada close_blocks desconta uma
# (DES-022). Se sobrar um bloco aberto (ex.: o _cts), o write_gds para com
# GDS-035; por isso o laço tenta até 4 vezes.
foreach_in_collection _blk [get_blocks -all] {
    set _nome [get_object_name $_blk]
    if {![string match *top_finish* $_nome]} {
        for {set _i 0} {$_i < 4} {incr _i} { catch {close_blocks $_blk} }
    }
}
current_block
# -long_names: o nome do topo tem mais de 32 caracteres; sem isto ele sai
# cortado no GDS (aviso GDS-028).
write_gds -design ${DESIGN}_finish -long_names $OUT_DIR/${DESIGN}_finish.gds
save_block
save_lib
puts "### 09_finish pronto. Próximo: Formality pós-layout (tool_data/fm) e LVS do ICV."
