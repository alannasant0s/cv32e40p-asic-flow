// rtl/cv32e40p_clock_gate_saed32.sv — clock gate de síntese (substitui a versão
// de simulação só para a filelist de síntese, scripts/gen_filelist.sh --synthesis)
// Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
// polo UFCG (trilha de Physical Design), 2026.
//
// Mesmo nome de módulo e mesmas portas de bhv/cv32e40p_sim_clock_gate.sv
// (decisão do clock gate em docs/decisions.md; estudo E06), para que o resto
// do RTL do CV32E40P (upstream, só leitura) não
// precise mudar nenhuma instanciação.
//
// Instancia a célula ICG real da SAED32: CGLPPRX2_<VT> (confirmada nas três
// famílias — RVT, LVT, HVT), pinos CLK (clock), EN (enable),
// SE (test enable), GCLK (saída). A família vem de uma macro definida na leitura
// do RTL (-define VT_LVT ou VT_HVT; sem macro, RVT), para que cada netlist use
// o clock gate da própria família. Macro, e não parâmetro, porque o módulo é
// instanciado dentro do RTL do upstream e o parâmetro não poderia ser passado.
//
// Por que `ifdef e não "parameter string VT": o VCS aceita parâmetro string,
// mas o leitor de RTL da síntese recusa (VER-700, 'string' não suportado em
// síntese). O `ifdef é aceito pelas duas ferramentas.
//
// O dont_touch nesta célula é aplicado no script de síntese
// (tool_data/fc/02_scenarios.tcl, bloco 2.7).

module cv32e40p_clock_gate (
    input  logic clk_i,
    input  logic en_i,
    input  logic scan_cg_en_i,
    output logic clk_o
);

`ifdef VT_LVT
  CGLPPRX2_LVT u_icg (.CLK(clk_i), .EN(en_i), .SE(scan_cg_en_i), .GCLK(clk_o));
`elsif VT_HVT
  CGLPPRX2_HVT u_icg (.CLK(clk_i), .EN(en_i), .SE(scan_cg_en_i), .GCLK(clk_o));
`else
  CGLPPRX2_RVT u_icg (.CLK(clk_i), .EN(en_i), .SE(scan_cg_en_i), .GCLK(clk_o));
`endif

endmodule  // cv32e40p_clock_gate
