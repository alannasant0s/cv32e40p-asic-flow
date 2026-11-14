# scripts/fc/drc_por_celula.tcl — em que célula cai cada erro de DRC do ICV
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# O QUE FAZ: lê o arquivo de texto do IC Validator (*.LAYOUT_ERRORS), pega as
# caixas de UMA regra (padrão: M1.S.1), junta as caixas vizinhas na mesma
# altura (o ICV corta um erro em 3 pedaços) e, para cada local, mostra:
#   - a célula que está ali (tipo, nome, orientação);
#   - a posição do erro DENTRO da célula (dx, dy a partir do canto da célula);
#   - os pinos da célula que encostam no erro;
#   - as vias e os fios de M1 que encostam no erro (com a rede).
# No fim, um resumo: quantos erros por tipo de célula e por pino, comparado
# com quantas instâncias daquele tipo existem no bloco.
#
# POR QUE: se os erros se concentram num tipo de célula (ou num pino), dá para
# tratar só as instâncias daquela célula em vez de mexer no roteador inteiro
# (ver docs/estudos/E05-or2x1.md).
#
# COMO USAR (no fc_shell / GUI, com o bloco certo aberto, ex. _route):
#   set drc_arquivo $RUN_DIR/icv_drc_route_fix/<arquivo>.LAYOUT_ERRORS
#   set drc_regra   M1.S.1      ;# opcional
#   source $env(HOME)/cv32e40p-asic-flow/scripts/fc/drc_por_celula.tcl
# Saída: na tela e em drc_por_celula_<regra>.rpt (na pasta $RPT_DIR, se existir).
# Só lê o bloco; não muda nada.

if {![info exists drc_arquivo]} { error "defina drc_arquivo antes do source" }
if {![info exists drc_regra]}   { set drc_regra M1.S.1 }
set _folga 0.06   ;# µm a mais em volta do erro para achar pinos/vias/fios

# --- 1. Ler as caixas da regra -------------------------------------------------
set _fh [open $drc_arquivo r]
set _regra_atual ""
set _caixas {}
while {[gets $_fh _l] >= 0} {
    # cabeçalho de regra na parte de detalhes: começa na coluna 0, "REGRA: ..."
    if {[regexp {^(\S+): } $_l -> _r]} { set _regra_atual $_r; continue }
    if {$_regra_atual ne $drc_regra} { continue }
    if {[regexp {\(\s*([-\d.]+),\s*([-\d.]+)\)\s*\(\s*([-\d.]+),\s*([-\d.]+)\)} $_l -> x1 y1 x2 y2]} {
        lappend _caixas [list $x1 $y1 $x2 $y2]
    }
}
close $_fh
if {[llength $_caixas] == 0} { error "nenhuma caixa da regra $drc_regra em $drc_arquivo" }

# --- 2. Juntar caixas encostadas na mesma altura ------------------------------
set _caixas [lsort -command {apply {{a b} {
    set d [expr {[lindex $a 1] - [lindex $b 1]}]
    if {abs($d) > 1e-6} { return [expr {$d < 0 ? -1 : 1}] }
    set d [expr {[lindex $a 0] - [lindex $b 0]}]
    return [expr {$d < 0 ? -1 : ($d > 0 ? 1 : 0)}]
}}} $_caixas]
set _locais {}
foreach c $_caixas {
    lassign $c x1 y1 x2 y2
    if {[llength $_locais] > 0} {
        lassign [lindex $_locais end] a1 b1 a2 b2
        if {abs($b1 - $y1) < 1e-6 && abs($a2 - $x1) < 1e-6} {
            lset _locais end [list $a1 $b1 $x2 $y2]
            continue
        }
    }
    lappend _locais [list $x1 $y1 $x2 $y2]
}

# --- 3. Saída ------------------------------------------------------------------
set _dir [expr {[info exists RPT_DIR] ? $RPT_DIR : "."}]
set _rpt "$_dir/drc_por_celula_${drc_regra}.rpt"
set _out [open $_rpt w]
proc _p {msg} { global _out; puts $msg; puts $_out $msg }
proc _attr {obj nomes} {
    # devolve o primeiro atributo que existir (os nomes variam entre versões)
    foreach n $nomes {
        if {![catch {get_attribute -quiet $obj $n} v] && $v ne ""} { return $v }
    }
    return "?"
}
proc _encosta {bb box} {
    lassign [join $bb] a1 b1 a2 b2
    lassign $box x1 y1 x2 y2
    return [expr {$a1 <= $x2 && $a2 >= $x1 && $b1 <= $y2 && $b2 >= $y1}]
}

_p "Bloco: [get_object_name [current_block]]   Regra: $drc_regra"
_p "Arquivo: $drc_arquivo"
_p "Caixas: [llength $_caixas]   Locais (caixas juntadas): [llength $_locais]"
_p ""
_p [format "%-4s %-20s %-18s %-4s %-14s %-12s %s" "#" "centro (x,y)" "tipo" "ori" "dx,dy na cel." "pinos" "vias / fios M1 (rede)"]

array unset _n_tipo; array unset _n_pino; array unset _n_via; array unset _n_dxdy
set _i 0
foreach loc $_locais {
    incr _i
    lassign $loc x1 y1 x2 y2
    set cx [expr {($x1 + $x2) / 2.0}]
    set cy [expr {($y1 + $y2) / 2.0}]
    set box [list [expr {$x1 - $_folga}] [expr {$y1 - $_folga}] \
                  [expr {$x2 + $_folga}] [expr {$y2 + $_folga}]]
    set boxtcl [list [list [lindex $box 0] [lindex $box 1]] [list [lindex $box 2] [lindex $box 3]]]

    # célula no centro do erro
    set cel ""
    catch {set cel [get_cells -quiet -at [list $cx $cy]]}
    if {[sizeof_collection $cel] == 0} {
        catch {set cel [get_cells -quiet -intersect $boxtcl]}
    }
    set tipo "-"; set ori "-"; set dxdy "-"; set pinos {}
    if {[sizeof_collection $cel] > 0} {
        set cel [index_collection $cel 0]
        set tipo [_attr $cel {ref_name}]
        set ori  [_attr $cel {orientation}]
        set bb   [_attr $cel {boundary_bbox bbox}]
        if {$bb ne "?"} {
            lassign [join $bb] llx lly
            set dxdy [format "%.3f,%.3f" [expr {$cx - $llx}] [expr {$cy - $lly}]]
        }
        foreach_in_collection p [get_pins -quiet -of_objects $cel] {
            set pbb [_attr $p {bbox}]
            if {$pbb ne "?" && [_encosta $pbb $box]} {
                lappend pinos [get_attribute $p name]
            }
        }
        incr _n_tipo($tipo)
        incr _n_dxdy($tipo|$ori|$dxdy)
        foreach pn $pinos { incr _n_pino($tipo/$pn) }
    }

    # vias e fios de M1 que encostam no erro
    set extra {}
    catch {
        foreach_in_collection v [get_vias -quiet -intersect $boxtcl] {
            set vd [_attr $v {via_def_name via_def.name}]
            set vn [_attr $v {net.name owner.name}]
            lappend extra "via:$vd($vn)"
            incr _n_via($vd)
        }
    }
    catch {
        foreach_in_collection s [get_shapes -quiet -intersect $boxtcl -filter "layer_name == M1"] {
            set sn [_attr $s {net.name owner.name}]
            set su [_attr $s {shape_use}]
            lappend extra "M1:$su($sn)"
        }
    }
    _p [format "%-4d %-20s %-18s %-4s %-14s %-12s %s" $_i \
        [format "%.3f,%.3f" $cx $cy] $tipo $ori $dxdy [join $pinos ,] [join $extra " "]]
}

# --- 4. Resumo -----------------------------------------------------------------
_p ""
_p "=== Erros por tipo de celula (instancias desse tipo no bloco) ==="
foreach t [lsort [array names _n_tipo]] {
    set tot [sizeof_collection [get_cells -quiet -hierarchical -filter "ref_name == $t"]]
    _p [format "  %-20s %4d erros   %6d instancias" $t $_n_tipo($t) $tot]
}
_p "=== Erros por pino ==="
foreach k [lsort [array names _n_pino]] { _p [format "  %-28s %4d" $k $_n_pino($k)] }
_p "=== Erros por via ==="
foreach k [lsort [array names _n_via]] { _p [format "  %-28s %4d" $k $_n_via($k)] }
_p "=== Mesma posicao dentro da celula? (tipo | orientacao | dx,dy) ==="
foreach k [lsort [array names _n_dxdy]] { _p [format "  %-44s %4d" $k $_n_dxdy($k)] }
close $_out
puts "\nRelatorio gravado em $_rpt"
