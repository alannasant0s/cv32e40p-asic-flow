# tool_data/fc/08_route.tcl — roteamento e DRC oficial (HVT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Critérios de aceite desta etapa: docs/criterios-aceite.md.
#
# Roteamento = desenhar os fios de metal reais entre os pinos das células.
#   route_auto        roteamento global, trilhas e detalhado
#   signoff_check_drc DRC oficial: o IC Validator (ICV) confere o layout com
#                     as regras de fabricação da SAED32 (runset do PDK)
#   signoff_fix_drc   o roteador refaz só os trechos que o ICV reprovou
#
# Por que rotear com as opções PADRÃO e corrigir pelo ICV: o roteador não
# enxerga todas as regras do ICV (por exemplo, pontas de metal 1 frente a
# frente no meio das células). Mudar as opções do roteador não resolve; o
# signoff_fix_drc corrige usando as regras do próprio ICV.
# Se o DRC acusar erros concentrados numa célula, ver
# docs/estudos/E05-or2x1.md (tratar só as células com erro, sem proibir a
# célula no projeto inteiro).
#
# COMO USAR: na mesma sessão do 07 (GUI pelo X2Go ou terminal), bloco a bloco.
# Na GUI, cada open_block abre uma janela: clique nela e confira current_block.

### BLOCO 8.1 — Cópia do bloco do CTS ##########################################
save_block
copy_block -from_block ${DESIGN}_cts -to_block ${DESIGN}_route
open_block ${DESIGN}_route
# SVF: registra no arquivo da rodada o que a ferramenta muda na netlist (o
# Formality lê depois). Repetido a cada etapa: se o fc_shell foi reaberto,
# sem isto o registro iria para um default-*.svf solto na pasta.
set_svf -append $RUN_DIR/cv32e40p.svf
current_block
# check_routability antes de rotear: esperado nada grave. As portas VDD/VSS
# aparecem sem posição porque o bloco não tem pinos de alimentação na borda
# (pendência para integração).
check_routability > $RPT_DIR/08_routability.rpt

### BLOCO 8.2 — Rotear (opções padrão) ##########################################
# 10 a 20 min. Esperado: 0 redes abertas. Os erros de DRC que o roteador
# deixar são tratados no 8.5.
route_auto
save_block
save_lib
check_routes > $RPT_DIR/08_check_routes.rpt

### BLOCO 8.3 — Otimizar com os fios reais (antes do DRC final) ######################
# route_opt refaz fios; por isso vem ANTES do DRC oficial e da correção.
# route_opt: reajusta o timing com o atraso real dos fios.
report_qor -summary
route_opt
report_qor -summary
# Se o setup ainda violar (WNS negativo), rodar route_opt de novo.
save_block
save_lib

### BLOCO 8.4 — DRC oficial (ICV) ###############################################
# As opções valem por BLOCO: num bloco novo, configurar de novo.
# SEMPRE salvar antes: o ICV lê o bloco do disco (sem salvar: "Top block does
# not exist", erro 420).
# NÃO usar o mapa tech/map/saed32nm_1p9m_gdsout.map: o FC recusa (GDS-017).
# Sem mapa, o FC usa a numeração de camadas do .tf, que o ICV reconhece.
# Caminhos montados com ${VT}: valem para HVT, LVT e RVT.
set_app_options -name signoff.check_drc.runset \
    -value $PDK/tech/icv_drc/saed32nm_1p9m_drc_rules.rs
set_app_options -name signoff.physical.merge_stream_files \
    -value $GDS_CELULAS
set_app_options -name signoff.check_drc.run_dir -value $RUN_DIR/icv_drc_route
save_block
signoff_check_drc
# Resultado: tabela de regras no fim; os erros aparecem no Error Browser
# (signoff_check_drc.err). Nunca copiar o conteúdo do runset para docs/git.

### BLOCO 8.5 — Correção automática pelo ICV ###################################
# signoff_fix_drc: lê os erros do ICV e refaz só os trechos reprovados.
# Ele cria a pasta signoff_fix_drc_run/ na pasta atual (fora do git).
# Se algum dia usar route_eco (ex.: depois de size_cell), rode signoff_fix_drc
# de novo: o route_eco refaz fios no projeto inteiro.
signoff_fix_drc
save_block
save_lib
# Pasta separada, para não apagar a medição do 8.4.
set_app_options -name signoff.check_drc.run_dir -value $RUN_DIR/icv_drc_route_fix
signoff_check_drc

### BLOCO 8.6 — Relatórios ######################################################
report_qor
report_qor -scenarios [all_scenarios]                           > $RPT_DIR/08_qor.rpt
report_qor -summary -significant_digits 3                        > $RPT_DIR/08_qor_resumo.rpt
# Setup e hold nos três corners, um arquivo por corner e por tipo.
foreach c {ss tt ff} {
    report_timing -scenarios func_$c -delay_type max -max_paths 10 -nosplit > $RPT_DIR/08_timing_setup_$c.rpt
    report_timing -scenarios func_$c -delay_type min -max_paths 10 -nosplit > $RPT_DIR/08_timing_hold_$c.rpt
}
report_constraint -all_violators -max_transition -max_capacitance -nosplit -scenarios [all_scenarios] > $RPT_DIR/08_violacoes_eletricas.rpt
report_power -scenarios func_tt -hierarchy                      > $RPT_DIR/08_power_tt.rpt
check_routes                                                    > $RPT_DIR/08_check_routes_final.rpt
puts "### 08_route pronto. Próximo: 09_finish (fillers, LVS, Formality, GDS)"
