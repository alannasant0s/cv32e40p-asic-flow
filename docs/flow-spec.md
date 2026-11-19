# Especificação do fluxo — CV32E40P na SAED32

Documento vivo. Itens marcados `TODO(verify)` precisam ser confirmados na documentação da ferramenta ou da biblioteca (ou no ambiente) antes de serem usados.

Ferramentas (requisito R1, `docs/requisitos-professor.md`): **Fusion Compiler** da síntese até o roteamento, numa única ferramenta e num único banco de dados; **Formality**, **StarRC**, **PrimeTime**, **IC Validator**, **PrimePower** (se houver licença) e **VCS** para o signoff (a verificação final que atesta que o circuito está correto). Design Compiler e IC Compiler II não fazem parte do fluxo.

Resumo da configuração: família **HVT** primeiro (LVT e RVT depois), clock de **8 ns (125 MHz)**, netlist **flat abaixo do `core_i`**, **três corners** (ss0p95v125c, tt1p05v25c, ff1p16vn40c) com setup e hold analisados nos três.

## 1. Projeto a ser implementado

- Topo: `cv32e40p_top`, implementado como **macro rígido em nível de bloco** (sem pads de entrada/saída; os pinos ficam na borda do die).
- Parâmetros (a configuração de referência): `FPU=0 COREV_PULP=0 COREV_CLUSTER=0 ZFINX=0 NUM_MHPMCOUNTERS=1`, banco de registradores com flip-flops. É um RV32IMC sem FPU e sem extensões PULP.
- Upstream (o RTL original do OpenHW): tag de release `cv32e40p_v1.8.3` (commit `360d272`), fixada como submódulo em `third_party/cv32e40p`.
- Clock gating (desligar o clock de partes ociosas para economizar energia): `rtl/cv32e40p_clock_gate_saed32.sv`, com o mesmo nome de módulo e as mesmas portas de `bhv/cv32e40p_sim_clock_gate.sv` (módulo `cv32e40p_clock_gate`, portas `clk_i en_i scan_cg_en_i clk_o`). Ele instancia uma célula ICG da SAED32 (célula de clock gating integrada, baseada em latch, sensível à borda de subida): `CGLPPRX2_<vt>`, com pinos `CLK` (clock), `EN` (enable), `SE` (teste) e `GCLK` (saída). A família é escolhida pelas macros `VT_LVT`/`VT_HVT` (sem macro, RVT), não por parâmetro, porque a síntese não aceita `parameter string`. Fica como `dont_touch` na síntese (a ferramenta não pode alterá-lo).
- **A inserção automática de clock gating pela síntese fica desligada.** As ICGs do RTL são as únicas (configuração de referência em `docs/decisions.md`; estudo E06). Opção: `set_clock_gating_objects -exclude [get_cells core_i]` (`03_synth.tcl`, bloco 3.0b; fonte: `man set_clock_gating_objects`, ADR-009).
- A lista de arquivos (filelist) é gerada por `scripts/gen_filelist.sh` a partir de `cv32e40p_manifest.flist`: (a) removendo os arquivos só de simulação `bhv/cv32e40p_tb_wrapper.sv` e `bhv/include/cv32e40p_tracer_pkg.sv`; (b) trocando `bhv/cv32e40p_sim_clock_gate.sv` pelo nosso wrapper (opção `--synthesis`). O manifesto já seleciona `cv32e40p_register_file_ff.sv`. O resultado é conferido por script (conjunto de arquivos e nomes de módulos esperados), não à mão.

## 2. Metodologia de timing

**Clocks**
- Um único clock, `clk_i`, com período de **8 ns** (R6). O período é definido uma vez, em `CLK_PERIOD` no `tool_data/fc/00_tech_setup.tcl`, e o SDC o lê de lá (o SDC não tem valor padrão).
- SDC: `constraints/cv32e40p_baseline.sdc`, derivado do exemplo do upstream (`third_party/cv32e40p/constraints/cv32e40p_core.sdc`, que fixa 5 ns para uma tecnologia não especificada). Decisão sobre o SDC em `docs/decisions.md`.
- Antes do CTS (síntese, placement): clock ideal. `set_clock_uncertainty -setup` = jitter + skew estimado + margem; `-hold` = jitter + margem pequena. Os valores estão no SDC e são estudados no E08.
- Depois do CTS: `set_propagated_clock`; a incerteza cai para jitter + margem (`07_cts.tcl`).

**Orçamento de entrada/saída (nível de bloco)**
- As interfaces OBI de instrução e dados se conectam a memórias fora do bloco. Os atrasos de entrada/saída são definidos por interface, como fração do período, com as mesmas frações do SDC de exemplo do upstream. São uma **premissa declarada** (método, seção 1), estudada no E04.
- Verificar caminhos combinacionais entrada→saída (`report_timing -from [all_inputs] -to [all_outputs]`, relatório `rpt/03_timing_in2out.rpt`). Se existirem, a soma dos dois atrasos externos tem que caber no período; o tratamento é decidido no E04 e registrado em `docs/decisions.md`.
- Ambiente de E/S com números fixos, iguais nas três famílias: `set_input_transition` e `set_load`, sem `set_driving_cell`. `set_max_transition` / `set_max_capacitance`: os limites da biblioteca.

**Entradas quase estáticas e de teste**
- `boot_addr_i`, `mtvec_addr_i`, `dm_halt_addr_i`, `dm_exception_addr_i` e `hart_id_i` não podem mudar depois de `fetch_enable_i` (manual do usuário). São tratadas como quase estáticas, com atraso de entrada pequeno (10 % do período), **sem** `set_false_path`, para continuarem checadas.
- Sem DFT (estruturas de teste de fabricação): `set_case_analysis 0 [get_ports scan_cg_en_i]`.
- `rst_ni` é assíncrono para ativar e sincronizado para desativar **fora** do bloco (premissa, documentada). É restringido com atraso de entrada; as checagens de recovery/removal continuam ativas (sem false path no reset).

**Corners e cenários**

Um *corner* é uma combinação de processo (ss = transistores lentos, tt = típicos, ff = rápidos), tensão e temperatura usada para analisar o circuito. O circuito precisa funcionar em todos eles.

- VT das células padrão: **HVT** primeiro (R3); LVT e RVT depois, com os mesmos corners e o mesmo SDC, trocando só a família (a NDM e o clock gate). Os nomes de arquivo seguem o mesmo padrão nas três famílias.
- **Três corners, usados em todas as etapas** (R2), da síntese ao signoff. Cada corner é um `.db` (processo/tensão/temperatura), um extremo de RC (parasitas de fios: TLU+ / SPEF) e a NDM da SAED32, montados como um cenário do Fusion Compiler (modo `func` × corner):

  | Corner | Biblioteca | RC | Papel principal | Análises ligadas |
  |---|---|---|---|---|
  | ss | `saed32<vt>_ss0p95v125c` (0,95 V, 125 °C) | Cmax | setup | setup e hold |
  | tt | `saed32<vt>_tt1p05v25c` (1,05 V, 25 °C) | nominal | potência | setup, hold e potência |
  | ff | `saed32<vt>_ff1p16vn40c` (1,16 V, −40 °C) | Cmin | hold | setup e hold |

- **Setup e hold são analisados nos três cenários** (bloco 2.6 do `02_scenarios.tcl`). Depois do CTS, o skew pode criar violação de hold fora do ff, e o professor pede os três corners em todos os relatórios.
- **Toda métrica é reportada nos três corners**, não só a checagem que cada corner "possui". A tabela de métricas (`docs/data-spec.md`) exige a coluna de corner em todas as etapas.
- **Os três corners vêm do mesmo conjunto de tensão**: o nominal (1,05 V) do databook da SAED32 (Tabela 1.6, p. 19). O lento é 1,05 V − 10 % e o rápido, 1,05 V + 10 %. Misturar conjuntos é o erro que o estudo E01 existe para evitar.
- **Inversão de temperatura:** com tensão de alimentação baixa, o atraso das células pode *aumentar* quando a temperatura cai, porque a redução da tensão de limiar deixa de compensar a perda de mobilidade. A NDM inclui também o `ss0p95vn40c` (ss a −40 °C) só para essa checagem: medir o setup na mesma netlist com o ss a 125 °C e a −40 °C (estudo E01, passo 7). Se o −40 °C for pior, ele entra na análise de setup.
- Extremos de RC: Cmax com o ss, Cmin com o ff, nominal com o tt. Os três arquivos TLU+ existem no PDK (`tech/starrc/{max,min,nominal}/`), referenciados no `00_tech_setup.tcl`.
- Os cenários MCMM (multi-corner, multi-modo) são definidos no Fusion Compiler **desde a síntese**, não só no signoff.
- OCV (variação dentro do chip): derate fixo (±5 %, parâmetro no `02_scenarios.tcl`, estudado no E08), a menos que existam tabelas AOCV/POCV no PDK (`TODO(verify)`).
- O PrimeTime é a autoridade de timing no signoff. Acompanhar a correlação Fusion Compiler × PrimeTime (diferença de WNS/TNS por corner, por etapa) nas métricas.

## 3. Fluxo no Fusion Compiler (da síntese ao roteamento)

Um único banco de dados do `fc_shell` leva o projeto do RTL até a netlist roteada. Cada etapa é um script separado em `tool_data/fc/` (`00_tech_setup.tcl` a `09_finish.tcl`), salva um bloco (`save_block`), escreve seus relatórios nos três cenários e tem seus próprios critérios de aceite (`docs/criterios-aceite.md`). Uma etapa que não atende aos critérios é reportada, não avançada. A NDM de cada família é gerada antes, com o `lm_shell` (`tool_data/fc/create_ndm.tcl`).

### 3.1 Síntese (01 a 03)

- `01_init_design.tcl`: ler com a filelist SystemVerilog; elaborar `cv32e40p_top` com os parâmetros do projeto. **Netlist flat abaixo do `core_i`** (R8): o desagrupamento automático (`compile.flow.autoungroup`) fica ligado, e tudo abaixo do `cv32e40p_core` é desfeito.
- `02_scenarios.tcl`: carregar os dados de tecnologia, os três corners, os cenários e o SDC antes de compilar, para que a síntese já seja MCMM.
- `03_synth.tcl`: `compile_fusion` só até a etapa `logic_opto` (mapeamento inicial e otimização lógica). As etapas seguintes (`initial_place`, `initial_drc`, `initial_opto`...) rodam no `06_place.tcl`, com `compile_fusion -from initial_place`. Onde termina a síntese lógica, diante das violações elétricas, é estudado no E03.
- Saídas: netlist (`write_verilog`), **SVF escrito pelo Fusion Compiler** (para o Formality), relatórios: `check_timing` (no 02), `report_qor`, violações elétricas por cenário (`rpt/03_violacoes_eletricas.rpt`), caminhos entrada→saída (`rpt/03_timing_in2out.rpt`), área, potência e timing, cada um nos três cenários.
- Critérios de aceite: 02.1 a 02.6 e 03.1 a 03.9 (`docs/criterios-aceite.md`).

### 3.2 Floorplan (04)

- Utilização do core e razão de aspecto são parâmetros do `04_floorplan.tcl` (utilização 0,70, razão 1:1). O tamanho do die é derivado, nunca fixado à mão.
- Posicionamento dos pinos: automático (`place_pins -self`). Agrupar por interface (instrução, dados, interrupção/debug, clock/reset) em bordas definidas é uma melhoria futura.
- Células físicas de borda (end-cap) e de poço (well-tap): `TODO(verify)` no databook se a SAED32 exige alguma (estudo E10).

### 3.3 Rede de alimentação (05)

- Anéis mais uma malha de straps nas camadas superiores, trilhos das células padrão na camada de trilho das células. Escolhas de camada e largura são documentadas no script.
- Critérios: sem DRC de PG, sem PG flutuante, checagem de conectividade de PG limpa. Os pinos de VDD/VSS na borda do bloco são estudados no E10.

### 3.4 Placement (06)

- Continuação do `compile_fusion` a partir de `initial_place`, com os três cenários ativos. As células tie já foram inseridas na síntese (03, blocos 3.0 e 3.2).
- Critérios: placement legal, violações elétricas zero, congestionamento revisado, setup nos três corners.

### 3.5 CTS — síntese da árvore de clock (07)

- `clock_opt` cobre o CTS, a otimização pós-CTS e a correção de hold.
- As restrições da árvore (alvo de skew, transição máxima no clock, NDR, células permitidas) são definidas no estudo E09, **antes** de rodar esta etapa.
- Critérios: setup e hold nos três corners, árvore dentro das restrições do E09, sem violações elétricas.

### 3.6 Roteamento (08) e acabamento (09)

- `route_auto` + `route_opt`, depois o DRC oficial (`signoff_check_drc`, com o runset do IC Validator). Fillers no acabamento.
- Correção de antena (diodo `ANTENNA_<VT>`, definido no `00_tech_setup.tcl`), densidade, fill e LVS do IC Validator ainda não estão no fluxo: estudo E10, **antes** do 08.
- Saídas para o signoff: netlist pós-roteamento (com e sem células só físicas, com alimentação para o LVS), GDS, SVF e os relatórios de timing/potência do Fusion Compiler nos três cenários para a métrica de correlação.
- Critérios: zero DRC, sem opens/shorts, timing nos três corners.

## 4. Formality

- RTL × netlist de síntese do Fusion Compiler, usando o SVF da mesma rodada (`tool_data/fm/fm.tcl`). Saída: "Verification SUCCEEDED", sem pontos não casados ou não verificados sem explicação (critério 03.7).
- Depois do fluxo físico: RTL × netlist pós-layout (critério 09.5).

## 5. Signoff

Formality, PrimeTime, PrimePower, StarRC e IC Validator são licenças separadas. Cada passo abaixo diz o que fazer quando a licença falta; uma licença faltando é reportada, nunca pulada em silêncio.

- **Extração:** StarRC, **três SPEFs**, um por corner (Cmax, nominal, Cmin). Alternativa sem StarRC: extração interna do Fusion Compiler (`write_parasitics`), marcada como não-signoff.
- **STA (PrimeTime):** **nos três corners**, cada um com seu `.db` e seu SPEF: setup, hold, DRV, checagens de clock gating e largura mínima de pulso. Alternativa sem PrimeTime: o timing do Fusion Compiler vira a autoridade e a métrica de correlação é descartada, com isso registrado.
- **Laço de ECO:** ECO do PrimeTime (correção de timing/DRV) → aplicar no Fusion Compiler → re-extrair → re-rodar a STA. Cada iteração de ECO é registrada.
- **Verificação física:** DRC e LVS no IC Validator com os runsets da SAED32. Referência do LVS = netlist com alimentação exportada do Fusion Compiler. Alternativa: só `check_routes`/`check_lvs` do Fusion Compiler, e a linha de verificação física da seção 6 é reportada como *não assinada*.
- **Potência:** PrimePower no corner típico para o número principal, reportado nos três (alternativa: `report_power` do Fusion Compiler, marcado como estimativa). Atividade padrão (sem vetores) versus atividade real (SAIF da simulação, mapeado com o SVF). Detalhamento hierárquico quando a netlist permitir.
- **Queda de IR / EM:** só se houver licença de análise de rail (opcional; estudo E10).
- **Simulação em nível de portas (GLS, VCS):** netlist pós-roteamento + SDF do pior e do melhor corner, mesmo programa da simulação RTL, resultado idêntico. Problemas de propagação de X no reset são investigados, não mascarados.

## 6. Resumo dos critérios de saída

Os critérios detalhados, por etapa, estão em `docs/criterios-aceite.md`.

| Etapa | Condição de aprovação |
|---|---|
| Lint | Cada aviso justificado (`docs/lint.md`). Ferramenta: VC SpyGlass |
| Simulação RTL | Programa de exemplo passa (`docs/sim-vcs.md`); CoreMark quando houver compilador RISC-V |
| Síntese | Critérios 02 e 03 |
| Formality | Equivalente |
| Floorplan / PG / Placement / CTS / Roteamento | Critérios 04 a 08 |
| Acabamento e signoff | Critérios 09: DRC = 0, LVS limpo, setup e hold com WNS > −0,01 ns nos três corners |
| GLS | Mesmo resultado do RTL com SDF no pior e no melhor corner |
| Potência | Relatórios nos três corners |
