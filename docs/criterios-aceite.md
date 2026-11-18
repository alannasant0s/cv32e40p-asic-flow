# Critérios de aceite por etapa

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

Uma etapa só está pronta quando **todos** os critérios dela passam, conferidos
por nós com `report_*`, `check_*` e `grep`. Se um critério não passa, a etapa
não está pronta. Nesse caso o resultado pode ir ao professor como
**pergunta**, com o estudo e uma proposta, nunca como entrega.

**Regra geral de timing** (requisito do projeto, `docs/requisitos-professor.md`):
violação aceitável é **menor que 0,01 ns**. Em número: **WNS > −0,01 ns**
(−0,009 passa; −0,01 não passa), lido com
`report_qor -summary -significant_digits 3` (com 2 casas, −0,009 aparece como
−0,01). Aplicar essa regra nos três corners e também ao hold é leitura nossa
do requisito: confirmar com o professor.

Os critérios de timing valem **nos três corners** (ss 0,95 V 125 °C, tt 1,05 V
25 °C, ff 1,16 V −40 °C; decisão sobre corners em `docs/decisions.md`). Um
número de um corner só não basta.

Onde um critério diz "valor do estudo Exx", o número ainda não foi decidido:
sai do estudo e da resposta do professor. Não inventar um limite antes disso.

## Etapa 02 — corners, cenários e SDC

| # | Critério | Como conferir |
|---|---|---|
| 02.1 | Cada corner pegou a biblioteca certa | `report_pvt`: sem PVT-030, sem "mismatch" nos três |
| 02.2 | Os três cenários analisam setup e hold | `report_scenarios`: Setup e Hold "true" nas três linhas |
| 02.3 | Clock com o período do projeto | `report_clocks`: período 8 |
| 02.4 | Nada sem constraint | `check_timing`: sem entrada sem atraso, sem flip-flop sem clock, sem laço |
| 02.5 | Só as exceções que decidimos | `report_exceptions`, `report_case_analysis`: só o `scan_cg_en_i = 0` |
| 02.6 | Margens em vigor registradas | anotar derate e incerteza em uso (estudo E08) |

## Etapa 03 — síntese lógica

| # | Critério | Como conferir |
|---|---|---|
| 03.1 | Setup nos três corners | `report_qor -summary`: WNS de setup > −0,01 ns nas linhas `func_ss`, `func_tt`, `func_ff` (a linha `Design` é o resumo, estudo E02). Anotar também a folga registrador → registrador: a síntese ainda não tem fios reais, então folga zero aqui tende a virar violação no placement |
| 03.2 | Hold relatado nos três corners e explicado | parte de hold do `report_qor -summary` nos três corners: números relatados e pior caminho lido e explicado (estudo E07), sem limite próprio até a resposta do professor. O hold tem que fechar no 07 (critério 07.1) |
| 03.3 | Violações elétricas contadas e explicadas | contagem por corner e por **rede única** (estudo E03). A síntese pode terminar com violações se o estudo E03 e o professor confirmarem que elas são corrigidas no 06. **Zero é exigido a partir do 06** |
| 03.4 | Caminhos entrada → saída | `rpt/03_timing_in2out.rpt` (um bloco por cenário): nenhum violando, ou explicado no estudo E04. Avisos TIM-010 em bits que o RTL não usa são esperados |
| 03.5 | Netlist flat abaixo do core | `report_qor`: "Hierarchical Cell Count: 1" (é o `core_i`, cv32e40p_core; tudo abaixo dele foi desfeito) e `grep -c '^module' runs/<pasta>/outputs/*_syn.v` = 2 (depois do bloco 3.5). Ao relatar, dizer "flat abaixo do core_i" |
| 03.6 | Nenhuma célula proibida por nós | o `03_synth.tcl` não tem `set_dont_use`; uma célula de exemplo, como a `OR2X1_HVT`, não está marcada: `get_attribute [get_lib_cells */OR2X1_HVT] dont_use` dá `false` (uma resposta por corner da biblioteca) |
| 03.7 | RTL e netlist equivalentes | Formality (`tool_data/fm/fm.tcl`, com a netlist desta rodada): "Verification SUCCEEDED"; o script para com erro se não passar. Ler e anotar o bloco "Auto Setup Summary" do `status.rpt` (as premissas em que o resultado vale) |
| 03.8 | Números da síntese registrados | área, número de células, potência do tt (estimativa, sem atividade real) |
| 03.9 | Clock gating conforme a decisão registrada | estudo E06 |

### Resultado da rodada `pnr_hvt_20261117-170523` (17/11/2026)

| Critério | Situação |
|---|---|
| 02.1 a 02.5 | cumpridos |
| 02.6 | derate ±5 % e incerteza 0,30 / 0,10 ns em uso; registrar no estudo E08 |
| 03.1 | não passa: ss −1,287 ns e tt −0,130 ns (entradas e saídas; registrador → registrador fecha nos três). Estudo E04 |
| 03.2 | relatado: ff −0,003 ns (1 caminho: `alu_div_i/Cnt_DP_reg[0]` ligado nele mesmo; o dado chega em 0,08 ns e o exigido é 0,10 de incerteza − 0,02 de hold da biblioteca = 0,08), ss +0,229, tt +0,097. Explicar no E07 |
| 03.3 | não passa: 1340 redes únicas. Estudo E03 e pergunta ao professor |
| 03.4 | entrada → saída: ss −0,14 ns (6 caminhos). Estudo E04 |
| 03.5 | `Hierarchical Cell Count: 1` conferido; falta registrar o `grep -c '^module'` da netlist (deve dar 2) |
| 03.6 | a conferir com o `get_attribute` do critério |
| 03.7 | SUCCEEDED (2243 pontos, 0 falhas). Falta explicar o ponto sem par (`aligner_ready_q_reg`), como pede o `docs/flow-spec.md` |
| 03.8 | registrado: 51.644 µm², 14.759 células, potência tt ≈ 51 mW (estimativa) |
| 03.9 | cumprido: 1 clock gate na netlist, o do RTL (`sleep_unit_i/core_clock_gate_i/u_icg`, `CGLPPRX2_HVT`) |

## Etapa 04 — floorplan

| # | Critério | Como conferir |
|---|---|---|
| 04.1 | Floorplan criado sem erro | log do bloco 4.2 sem `Error` |
| 04.2 | Utilização planejada | `report_design -floorplan`: anotar utilização, tamanho do core e número de rows; a utilização alvo é conferida com a área da síntese |
| 04.3 | Todos os pinos posicionados | número de pinos do `place_pins` igual ao número de portas do bloco |

## Etapa 05 — rede de alimentação

| # | Critério | Como conferir |
|---|---|---|
| 05.1 | Rede ligada | `check_pg_connectivity`: 0 fios soltos em VDD e VSS |
| 05.2 | Rede sem erro de desenho | `check_pg_drc`: sem erros |
| 05.3 | Pinos de alimentação do bloco | estudo E10 (hoje o bloco não tem) |

## Etapa 06 — placement

| # | Critério | Como conferir |
|---|---|---|
| 06.1 | Todas as células encaixadas | `check_legality`: 0 violações |
| 06.2 | Alimentação ligada | `check_pg_connectivity`: 0 células e fios soltos |
| 06.3 | Setup nos três corners | WNS > −0,01 ns (`report_qor -summary`) |
| 06.4 | Violações elétricas zero | `rpt/06_violacoes_eletricas.rpt` |
| 06.5 | Congestão aceitável | `report_congestion`: limite de transbordo definido antes desta etapa, com o professor |

## Etapa 07 — árvore de clock (CTS)

Antes desta etapa: estudo E09 (restrições da árvore) concluído.

| # | Critério | Como conferir |
|---|---|---|
| 07.1 | Setup **e hold** nos três corners | WNS > −0,01 ns em setup e em hold (`report_qor -summary`) |
| 07.2 | Árvore dentro das restrições | `report_clock_qor`: skew (global e local), latência e transição máxima no clock, nos valores do estudo E09 |
| 07.3 | Violações elétricas zero | `rpt/07_violacoes_eletricas.rpt` |
| 07.4 | Custo do hold registrado | número e área das células de atraso inseridas |

## Etapa 08 — roteamento

Antes desta etapa: estudo E10 (antena e demais verificações) concluído.

| # | Critério | Como conferir |
|---|---|---|
| 08.1 | Nenhuma rede aberta ou em curto | `check_routes` |
| 08.2 | Setup e hold nos três corners | WNS > −0,01 ns. Se for preciso repetir o `route_opt`, anotar quantas vezes e parar se não melhorar |
| 08.3 | DRC oficial (ICV) zero | tabela do `signoff_check_drc`. Cada violação que sobrar tem estudo próprio (erros concentrados numa célula: estudo E05) |
| 08.4 | Violações elétricas zero | `rpt/08_violacoes_eletricas.rpt` |

## Etapa 09 — acabamento e entregáveis

| # | Critério | Como conferir |
|---|---|---|
| 09.1 | DRC oficial com todas as camadas zero | `signoff_check_drc -check_all_runset_layers true`: 0 violações, 0 regras não executadas |
| 09.2 | LVS da ferramenta limpo | `rpt/09_check_lvs.rpt`: 0 curtos, 0 abertos, 0 pinos flutuando |
| 09.3 | LVS do IC Validator limpo | estudo E10 (ainda não está no fluxo) |
| 09.4 | Antena e densidade | estudo E10 (ainda não está no fluxo) |
| 09.5 | Formality pós-layout | netlist do 09 contra o RTL: SUCCEEDED |
| 09.6 | Timing final nos três corners | setup e hold com WNS > −0,01 ns |

## Antes de enviar ao professor

Copiar esta lista na mensagem de registro (ou no estudo) e marcar:

- [ ] Todos os critérios da etapa passaram, ou os que não passaram estão
      explicados com estudo, proposta e plano.
- [ ] Os números vêm de uma rodada nossa (pasta e hash do git anotados),
      rodada bloco a bloco.
- [ ] Os três corners aparecem em todos os números de timing.
- [ ] Sei explicar cada linha de cada relatório mostrado.
- [ ] Nenhuma decisão avançada sem a pergunta ao professor (método, seção 3).
- [ ] Rodou: ____  Acompanhou e conferiu: ____
