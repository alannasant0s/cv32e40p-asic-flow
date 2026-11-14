# scripts/fc/bloco.tcl — roda UM bloco de um script do fluxo físico
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Os scripts tool_data/fc/01_init_design.tcl ... 09_finish.tcl são divididos
# em blocos ("### BLOCO 4.2 — ..."). Em vez de copiar e colar cada bloco, digite
# no fc_shell:
#     bloco 4.2
# e o comando roda exatamente as linhas desse bloco, como estão no
# repositório, mostrando cada comando antes da saída dele.
#
# Para carregar (uma vez por sessão do fc_shell, aberto na pasta do projeto):
#     source scripts/fc/bloco.tcl
#
# Se um comando do bloco der erro, o bloco para ali. Não rode o bloco de novo
# sem entender o erro (veja docs/erros-conhecidos.md).

proc bloco {id} {
    set etapa [lindex [split $id .] 0]
    set achados [glob -nocomplain tool_data/fc/0${etapa}_*.tcl]
    if {[llength $achados] != 1} {
        error "Nao achei o script da etapa $etapa. O fc_shell precisa ser aberto na pasta ~/cv32e40p-asic-flow."
    }
    set arquivo [lindex $achados 0]
    set fh [open $arquivo r]
    set dentro 0
    set linhas {}
    while {[gets $fh l] >= 0} {
        if {[regexp {^### BLOCO (\S+)} $l -> b]} {
            if {$dentro} { break }
            set dentro [expr {$b eq $id}]
            continue
        }
        if {$dentro} { lappend linhas $l }
    }
    close $fh
    if {[llength $linhas] == 0} { error "O bloco $id nao existe em $arquivo." }
    set tmp /tmp/bloco_[pid]_[string map {. _} $id].tcl
    set out [open $tmp w]
    puts $out [join $linhas \n]
    close $out
    puts "\n========== $arquivo - bloco $id ==========\n"
    # uplevel #0: roda no nível global, como se tivesse sido colado no console
    # (as variáveis do 00_tech_setup.tcl, como RUN_DIR e DESIGN, continuam
    # valendo entre um bloco e outro).
    uplevel #0 [list source -echo -verbose $tmp]
    puts "\n========== fim do bloco $id ==========\n"
}
puts "Comando 'bloco' carregado. Exemplo: bloco 1.1"
