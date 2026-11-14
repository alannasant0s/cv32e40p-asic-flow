# Script UCLI para gerar o banco de formas de onda do Verdi (FSDB).
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Não mexe no testbench (third_party/cv32e40p é somente leitura, regra 2 do
# AGENTS.md): o dump é pedido via comandos UCLI, de fora do RTL, rodando a
# simulação já compilada (simv).
#
# "-depth 0" = profundidade ilimitada (grava todos os níveis de hierarquia
# abaixo do escopo, não só os sinais do topo).

dump -file wave.fsdb -type FSDB
dump -add /tb_top -depth 0
run
exit
