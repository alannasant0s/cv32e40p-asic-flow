# E01 — Quais corners usar

**Pergunta:** quais condições de processo, tensão e temperatura (corners) o projeto usa para setup, hold e potência?
**Nível:** júnior
**Situação:** aberto. Os scripts já usam o conjunto nominal (decisão sobre corners em `docs/decisions.md`); a dupla reproduz o estudo e confirma.

## Por que este estudo existe

A pasta de bibliotecas da SAED32 tem arquivos `.db` de vários corners, de
**três conjuntos de tensão diferentes**. Todos existem e todos têm nomes
parecidos (`ss0p75v125c`, `ss0p95v125c`...). Misturar corners de conjuntos
diferentes é um erro comum: o projeto passa a analisar chips diferentes em
cada corner, e o resultado de timing deixa de fazer sentido (por exemplo, um
ss com tensão muito baixa deixa o clock de 8 ns parecer impossível). Saber que
um arquivo existe não diz qual usar. Este estudo prova, pelo databook, qual
conjunto usar e qual arquivo vale para cada corner.

## O que precisamos saber

- **Corner** é uma condição de operação: processo (transistor lento, típico ou
  rápido), tensão e temperatura. Cada uma tem um arquivo de biblioteca
  (`.db`) com os atrasos das células medidos naquela condição.
- **Setup** costuma ser pior no corner lento (ss). **Hold** costuma ser pior no
  rápido (ff). Mas "costuma" não é "sempre": depois da árvore de clock, o skew
  pode criar violação de hold em outro corner. Por isso analisamos setup e
  hold **nos três** (bloco 2.6 do `02_scenarios.tcl`).
- Tensão menor deixa o transistor mais lento. De 0,95 V para 0,75 V a célula
  fica muito mais lenta.
- Os três corners de um projeto descrevem **o mesmo chip, na mesma tensão de
  alimentação**, com variação em volta dela. Não se misturam corners de
  tensões de alimentação diferentes.
- **Potência:** usamos o tt (consumo típico). O pior vazamento seria no corner
  rápido e quente (ff a 125 °C), que hoje não analisamos (estudo E08).

## Fonte primária

Databook da biblioteca, na instalação do PDK:
`/Tools/PDK/SAED32/EDK_Digital/doc/SAED32.28nm_Digital_Standard_Cell_Library_b100_01312012.pdf`

- **Tabela 1.6 (p. 19), "Base Characterization Corners":** os 27 corners vêm
  em três conjuntos de tensão. **É este o argumento da decisão.**

| Conjunto | Típico | Lento | Rápido |
|---|---|---|---|
| nominal (1,05 V) | tt1p05 | **ss0p95** | ff1p16 |
| "middle voltage" | tt0p85 | ss0p75 | ff0p95 |
| "low voltage" | tt0p78 | ss0p7 | ff0p85 |

  Os três corners do projeto saem da mesma linha. No conjunto nominal, o lento
  é 1,05 V − 10 % = 0,95 V e o rápido é 1,05 V + 10 % ≈ 1,16 V. Pegar o tt e o
  ff do conjunto nominal e o ss de outro conjunto é exatamente a mistura que
  este estudo existe para evitar.
- **Tabela 1.4 (p. 18), "Operating conditions":** diz que a biblioteca é
  especificada para 1,05 V e cita uma frequência de referência. **O máximo
  da faixa de tensão escrita nela não bate com o ff de 1,16 V** da
  Tabela 1.6 (confira na p. 18). Parece um erro do próprio documento. Por isso não usamos essa
  faixa como argumento. Anotem isso ao ler: fonte primária também pode ter
  erro, e o certo é dizer onde.

## Experimento (rodado por nós)

**Uma variável por vez:** para medir o efeito do corner, usamos a **mesma
netlist** e mudamos só o corner da análise. Comparar duas sínteses
diferentes mistura o efeito do corner com o da otimização.

1. **Ler a fonte.** Abrir o PDF (X2Go, ou copiar para o Windows) nas páginas
   18 e 19. Anotar, com as nossas palavras, o que cada conjunto significa, e
   a inconsistência da Tabela 1.4.
2. **Ver os arquivos existentes:**
   `ls /Tools/PDK/SAED32/EDK_Digital/lib/stdcell_hvt/db_nldm/ | grep -E "^saed32hvt_(ss|tt|ff)"`.
   Existem arquivos dos três conjuntos. Existir não diz qual usar.
3. **Conferir a condição dentro do arquivo.** Ler só três atributos (sem
   copiar o arquivo para lugar nenhum):
   `grep -m3 -E "nom_(process|voltage|temperature)" /Tools/PDK/SAED32/EDK_Digital/lib/stdcell_hvt/db_nldm/saed32hvt_ss0p95v125c.lib`.
   Esperado: 0,95 V, 125 °C, processo 0,99, os números do `array set PVT`
   do `02_scenarios.tcl`.
4. **Gerar a NDM:**
   `lm_shell -x "set VT hvt" -file tool_data/fc/create_ndm.tcl -batch`.
   Conferir `rpt/create_ndm_hvt_check_workspace.rpt` com 0 erros.
5. **Síntese 01 a 03, bloco a bloco** (uma pessoa roda, a outra acompanha;
   método, seção 4). No bloco 2.4, o `report_pvt` tem que mostrar 0,95 V no ss
   e nenhum PVT-030. Anotar setup e hold de cada corner (`report_qor -summary`).
6. **Efeito só da tensão, na mesma netlist.** Com o bloco `_syn` aberto, criar
   um corner extra **só para análise**, com o ss do conjunto "middle voltage"
   (0,75 V), e comparar:
   ```
   create_corner ss075
   current_corner ss075
   set_process_number 0.99
   set_voltage 0.75 -object_list [get_supply_nets VDD]
   set_temperature 125
   set_parasitic_parameters -corner ss075 -early_spec Cmax -late_spec Cmax
   set_timing_derate -late 1.05
   set_timing_derate -early 0.95
   create_scenario -name func_ss075 -mode func -corner ss075
   current_scenario func_ss075
   source $SDC
   set_scenario_status func_ss075 -setup true -hold false -leakage_power false -dynamic_power false
   report_pvt
   report_qor -summary
   ```
   **Não salvar o bloco depois disso** (é só medida). Anotar o setup do
   `func_ss` e do `func_ss075`: a diferença é o efeito só da tensão.
   (Depende da NDM ter o `ss0p75v125c`, e a NDM do projeto não tem. Se
   quiserem esse passo, gerem uma NDM de teste à parte, com os dois arquivos.)
7. **Inversão de temperatura**, do mesmo jeito: **acrescentar** um corner de
   análise `ss_m40` (processo 0,99, 0,95 V, −40 °C, Cmax), na mesma netlist, e
   comparar com o `func_ss` a 125 °C. Se o −40 °C for pior, o corner de
   −40 °C **entra** na análise de setup, sem tirar o de 125 °C. A NDM do
   projeto já tem o `ss0p95vn40c`.

## Resultado anotado

| Rodada (pasta e hash do git) | Quem rodou / quem conferiu | Setup ss / tt / ff | Hold ss / tt / ff | Observação |
|---|---|---|---|---|
| | | | | |

## Conclusão

(preencher depois do experimento)

## Decisão

Decisão sobre corners em `docs/decisions.md` (conjunto nominal:
`ss0p95v125c`, `tt1p05v25c`, `ff1p16vn40c`). Confirmar ou rever depois dos
passos acima.
