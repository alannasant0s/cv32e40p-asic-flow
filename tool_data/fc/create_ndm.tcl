# tool_data/fc/create_ndm.tcl — gera a NDM da SAED32 para uma família de células (VT)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# O script:
#   - é parametrizado por família (RVT/LVT/HVT), em vez de uma família fixa;
#   - usa os três corners do projeto (decisão de corners em docs/decisions.md)
#     e o ss a -40 °C (inversão de temperatura);
#   - grava fora do Git (regra 1 do AGENTS.md; *.ndm já está no .gitignore).
#
# Uso (rodando da raiz do repositório):
#   lm_shell -x "set VT rvt" -file tool_data/fc/create_ndm.tcl -batch
#   (troque VT por lvt ou hvt para as outras famílias; rode uma vez por família)
#
# Atenção: o fc_shell NÃO reconhece os comandos de Library Manager
# (create_workspace, read_db, read_lef, group_libs, check_workspace,
# process_workspaces, remove_workspace) usados aqui -- dá "unknown command"
# (CMD-005). O binário certo é lm_shell (Library Manager dedicado). Saída
# esperada: "2/2 workspaces processed successfully" e 0 erros em
# rpt/create_ndm_<vt>_check_workspace.rpt.
#
# Os avisos "Direction 'inout' ... does not match expected value 'in'" para
# pinos VDD/VSS são esperados e inofensivos -- o LEF define pino de
# alimentação como inout, o Liberty como in; o Library Manager reconcilia
# sozinho ("Information: Fixed direction mismatches ... (LM-054)").
#
# Corners usados (estudo E01), conferidos no databook da biblioteca:
#   /Tools/PDK/SAED32/EDK_Digital/doc/SAED32.28nm_Digital_Standard_Cell_Library_b100_01312012.pdf
#   Tabela 1.4 (p. 18): biblioteca especificada para 1,05 V. (A faixa de
#   tensão escrita lá não bate com o ff de 1,16 V: o argumento que vale é a
#   Tabela 1.6, abaixo.)
#   Tabela 1.6 (p. 19): os corners vêm em TRÊS CONJUNTOS de tensão, e os três
#   corners de um projeto saem do MESMO conjunto:
#     nominal (1,05 V):  tt1p05 / ss0p95 / ff1p16   <- o nosso
#     middle voltage:    tt0p85 / ss0p75 / ff0p95
#     low voltage:       tt0p78 / ss0p7  / ff0p85
#   saed32<vt>_ss0p95v125c.db  -> lento: 1,05 V - 10 % = 0,95 V, 125 °C (setup)
#   saed32<vt>_tt1p05v25c.db   -> típico: 1,05 V nominal, 25 °C (potência)
#   saed32<vt>_ff1p16vn40c.db  -> rápido: 1,05 V + 10 % = 1,16 V, -40 °C (hold)
#   saed32<vt>_ss0p95vn40c.db  -> ss a -40 °C, só para a checagem de
#                                 inversão de temperatura (estudo E01)
# Armadilha: não usar o ss0p75v125c só porque o arquivo existe. Ele é o ss
# do conjunto "middle voltage" (0,75 V) e não se mistura com o tt e o ff do
# conjunto nominal. Ver docs/estudos/E01-corners.md.
# A pasta db_nldm/ tem vários pontos de tensão (0p7, 0p75, 0p78, 0p85, 0p95,
# 1p05, 1p16): existir não quer dizer que seja o certo para o projeto.

if {![info exists VT]} {
    error "defina a variável VT (rvt, lvt ou hvt) antes de rodar este script.\
 Exemplo: lm_shell -x \"set VT rvt\" -file tool_data/fc/create_ndm.tcl -batch"
}
if {$VT ni {rvt lvt hvt}} {
    error "VT inválido: '$VT' (use rvt, lvt ou hvt)"
}

set DESIGN_STAGE "create_ndm"

# Caminhos do PDK no servidor (iguais para todos os alunos)
set PDK_BASE     "/Tools/PDK/SAED32/EDK_Digital"
set STDCELL_DIR  "${PDK_BASE}/lib/stdcell_${VT}"
set TECH_FILE    "${PDK_BASE}/tech/tf/saed32nm_1p9m.tf"
set LEF_DIR      "${STDCELL_DIR}/lef"
set DB_DIR       "${STDCELL_DIR}/db_nldm"

# Caminhos do projeto. NDM_DIR fica fora do Git (regra 1 do AGENTS.md); o
# padrão *.ndm/ já está no .gitignore, então mesmo gerando dentro do
# repositório nada entra no commit sem querer.
# Raiz do repositório se estiver num clone; senão, a pasta atual.
if {[catch {exec git rev-parse --show-toplevel} PRJT_BASE]} {
    set PRJT_BASE [pwd]
}
set NDM_DIR      "${PRJT_BASE}/ndm_lib"
set RPT_DIR      "${PRJT_BASE}/rpt"

file mkdir ${NDM_DIR}
file mkdir ${RPT_DIR}

set bus_delimeter {[]}
set sh_continue_on_error true

set_app_options -as_user_default -name link.require_physical          -value true
set_app_options -as_user_default -name design.bus_delimiters          -value $bus_delimeter
set_app_options -as_user_default -name lib.logic_model.use_db_rail_names -value true

create_workspace SAED32_[string toupper $VT] -tech $TECH_FILE -flow exploration

# Três corners do projeto mais o ss a -40 °C, para a checagem de
# inversão de temperatura. Uma NDM pode ter mais PVTs do que a síntese usa:
# cada corner escolhe o seu. NAO usar glob: db_nldm/ tem centenas de
# arquivos (dlvl, ulvl, pg, outros pontos de tensão).
set db_files [list \
    ${DB_DIR}/saed32${VT}_ss0p95v125c.db \
    ${DB_DIR}/saed32${VT}_tt1p05v25c.db \
    ${DB_DIR}/saed32${VT}_ff1p16vn40c.db \
    ${DB_DIR}/saed32${VT}_ss0p95vn40c.db \
]
read_db $db_files

set lef_files [glob ${LEF_DIR}/*.lef]
read_lef $lef_files

group_libs

# Sanity check antes de gravar: procura modelo físico/lógico faltando
check_workspace > ${RPT_DIR}/${DESIGN_STAGE}_${VT}_check_workspace.rpt

# Atenção: a ferramenta nomeia a saída pelo grupo de
# bibliotecas (saed32<vt>_c.ndm), não pelo -output, e cria também
# SAED32_<VT>_physical_only.ndm ao lado.
process_workspaces -force -directory $NDM_DIR -output saed32_${VT}.ndm

remove_workspace

puts "NDM gerada em ${NDM_DIR}/saed32${VT}_c.ndm"
