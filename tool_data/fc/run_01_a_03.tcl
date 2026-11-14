# tool_data/fc/run_01_a_03.tcl — roda o 01, o 02 e o 03 em sequência, sem parar.
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Para quando já se conhece os blocos e se quer o resultado sem acompanhar
# linha a linha. Roda em segundo plano: continua mesmo se a conexão cair.
# Da raiz do repositório, num terminal Linux:
#   source /Tools/synopsys-scripts/snps.sh
#   scripts/gen_filelist.sh --synthesis
#   nohup fc_shell -f tool_data/fc/run_01_a_03.tcl -batch > fc_hvt_run.log 2>&1 &
# Acompanhar:  grep -a "^### \|^Error" fc_hvt_run.log
# Se algum comando der erro, o source para ali e o fc_shell sai; o log mostra
# o primeiro "Error". Os relatórios ficam em runs/pnr_hvt_<data>/rpt/.
# Depois, para ver na GUI (X2Go): open_lib runs/pnr_hvt_<data>/cv32e40p_lib
# e open_block cv32e40p_top_syn.

source tool_data/fc/01_init_design.tcl
source tool_data/fc/02_scenarios.tcl
source tool_data/fc/03_synth.tcl
puts "### run_01_a_03 terminado: $RUN_DIR"
exit
