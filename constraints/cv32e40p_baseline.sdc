# constraints/cv32e40p_baseline.sdc — restrições do baseline (modo func)
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
#
# Derivado de third_party/cv32e40p/constraints/cv32e40p_core.sdc
#   Copyright 2020 Silicon Labs, Inc.
#   Licenciado sob a Solderpad Hardware License, Version 2.0
#   (https://solderpad.org/licenses/SHL-2.0/).
# Mudanças em relação ao original:
#   - período parametrizado: vem do fluxo (CLK_PERIOD, 8 ns); o original fixa 5 ns;
#   - acrescentados: incerteza e transição do clock ideal, transição das
#     entradas, carga das saídas, scan_cg_en_i fixo em 0.
#   - mantidos: os atrasos de entrada/saída por interface, como fração
#     do período, exatamente como no original.
#
# Só restrições do modo (clock, E/S, exceções). O que depende do corner
# (derate de OCV, parasitas) fica no script de síntese, por corner.

# ------------------------------------------------------------------ parâmetros
# Unidade de tempo da SAED32: 1 ns (time_unit do .lib).
# Sem valor padrão de propósito: sem CLK_PERIOD definido, o SDC para com erro,
# em vez de usar um período qualquer em silêncio.
if {![info exists CLK_PERIOD]} {
    error "CLK_PERIOD não definido. Carregue antes o tool_data/fc/00_tech_setup.tcl (8 ns)."
}

# Clock ideal (antes do CTS). Depois do CTS o script do CTS reduz a
# incerteza para jitter + margem (07_cts.tcl, bloco 7.2). Os valores ainda
# dependem do estudo de margens (docs/estudos/E08-margens.md).
set CLK_UNC_SETUP 0.30   ;# jitter + skew estimado + margem
set CLK_UNC_HOLD  0.10   ;# o hold é corrigido de verdade depois do CTS
set CLK_TRAN      0.10   ;# transição do clock ideal, evita clock "perfeito"

# Ambiente fora do bloco: números fixos, iguais nas três famílias de célula,
# para a comparação LVT/RVT/HVT não mudar o "mundo de fora" (decisão das
# restrições em docs/decisions.md).
set IN_TRAN  0.10        ;# ns
# Unidade de capacitância da SAED32: 1 fF (capacitive_load_unit do .lib).
# 5 = 5 fF.
set OUT_LOAD 5

# ----------------------------------------------- orçamentos de E/S (original)
# As entradas do barramento OBI chegam tarde de propósito e as saídas OBI
# não dependem combinacionalmente das entradas OBI (comentário do original).
# EM ESTUDO (docs/estudos/E04-orcamento-es.md): frações copiadas do SDC de
# exemplo do upstream (escrito para 5 ns, tecnologia não informada). A
# justificativa qualitativa está em docs/decisions.md (as entradas OBI chegam tarde pelo
# protocolo); a conferência em números a 8 ns na SAED32 é o E04. Exemplo:
# entrada OBI a 80 % deixa 1,6 ns (menos 0,3 ns de incerteza) para a lógica
# dentro do bloco. Não mudar sem concluir o E04.
set in_delay_irq          [expr $CLK_PERIOD * 0.50]
set out_delay_irq         [expr $CLK_PERIOD * 0.25]
set in_delay_early        [expr $CLK_PERIOD * 0.10]
set in_delay_obi          [expr $CLK_PERIOD * 0.80]
set out_delay_obi         [expr $CLK_PERIOD * 0.60]
set in_delay_other        [expr $CLK_PERIOD * 0.10]
set out_delay_other       [expr $CLK_PERIOD * 0.60]
set out_delay_core_sleep  [expr $CLK_PERIOD * 0.25]

# ------------------------------------------------------------ grupos de portas
set clock_ports      [list clk_i]
# irq_i* também casaria com a saída irq_id_o (DES-012 na síntese): tirar.
set irq_input_ports  [remove_from_collection [get_ports irq_i*] [get_ports irq_id_o*]]
set irq_output_ports [get_ports [list irq_ack_o irq_id_o*]]

# Entradas que mudam pouco (endereços de configuração) e o pedido de debug.
# Ficam com atraso pequeno, não com false_path: assim continuam sendo
# checadas, a um custo quase nulo (sobra 90% do período).
set early_input_ports [get_ports [list debug_req_i boot_addr_i* mtvec_addr_i* \
                                       dm_halt_addr_i* hart_id_i* dm_exception_addr_i*]]

set obi_input_ports  [get_ports [list instr_gnt_i instr_rvalid_i instr_rdata_i* \
                                      data_gnt_i data_rvalid_i data_rdata_i*]]
set obi_output_ports [get_ports [list instr_req_o instr_addr_o* data_req_o data_we_o \
                                      data_be_o* data_addr_o* data_wdata_o*]]
set sleep_output_ports [get_ports core_sleep_o]

set other_input_ports  [remove_from_collection [all_inputs] \
    [add_to_collection [get_ports $clock_ports] \
        [add_to_collection $obi_input_ports \
            [add_to_collection $irq_input_ports $early_input_ports]]]]
set other_output_ports [remove_from_collection [all_outputs] \
    [add_to_collection $obi_output_ports \
        [add_to_collection $sleep_output_ports $irq_output_ports]]]

# ----------------------------------------------------------------------- clock
create_clock -name clk_i -period $CLK_PERIOD [get_ports clk_i]
set_clock_uncertainty -setup $CLK_UNC_SETUP [get_clocks clk_i]
set_clock_uncertainty -hold  $CLK_UNC_HOLD  [get_clocks clk_i]
set_clock_transition $CLK_TRAN [get_clocks clk_i]

# ----------------------------------------------------------------- entradas/saídas
set_input_delay  $in_delay_irq         -clock clk_i $irq_input_ports
set_output_delay $out_delay_irq        -clock clk_i $irq_output_ports
set_input_delay  $in_delay_obi         -clock clk_i $obi_input_ports
set_output_delay $out_delay_obi        -clock clk_i $obi_output_ports
set_input_delay  $in_delay_early       -clock clk_i $early_input_ports
set_input_delay  $in_delay_other       -clock clk_i $other_input_ports
set_output_delay $out_delay_other      -clock clk_i $other_output_ports
set_output_delay $out_delay_core_sleep -clock clk_i $sleep_output_ports

set_input_transition $IN_TRAN [remove_from_collection [all_inputs] [get_ports $clock_ports]]
set_load $OUT_LOAD [all_outputs]

# ----------------------------------------------------------------------- modo
# Sem DFT no baseline: os clock gates nunca ficam forçados ligados por scan.
set_case_analysis 0 [get_ports scan_cg_en_i]

# Limites de transição/capacitância: os da própria biblioteca (nenhum
# comando aqui de propósito).
