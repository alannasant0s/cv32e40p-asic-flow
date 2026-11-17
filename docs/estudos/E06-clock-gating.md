# E06 — Clock gating automático na síntese

**Pergunta:** a síntese deve inserir clock gating por conta própria, além dos clock gates que já existem no RTL?
**Nível:** júnior para **cumprir** a decisão registrada (só o clock gating do RTL; configuração de referência em `docs/decisions.md`). Avançada só se quisermos **mudar** essa decisão; aí vai ao professor, com área e potência com e sem a inserção.
**Situação:** aberto

## Por que este estudo existe

A decisão registrada é que o único clock gating do projeto é o do RTL
(`CGLPPRX2_HVT`, no `rtl/cv32e40p_clock_gate_saed32.sv`), com a inserção
automática da ferramenta desligada. Mas os scripts 01 a 03 não desligam essa
inserção de forma explícita, e o Fusion Compiler pode inserir clock gates
sozinho. Precisamos medir se isso acontece, achar a opção que controla a
inserção e fazer os scripts cumprirem a decisão (ou levar ao professor os
números para mudá-la).

## O que precisamos saber

- **Clock gating** desliga o clock de um grupo de flip-flops quando eles não
  vão mudar de valor. Economiza potência dinâmica.
- O **clock gate** (ICG, integrated clock gate) é uma célula com latch que
  deixa o clock passar ou não, sem criar pulsos falsos.
- O RTL do CV32E40P já tem clock gating no lugar certo (o `cv32e40p_clock_gate`).
  A ferramenta pode acrescentar outros, sozinha, em registradores com sinal de
  habilitação.
- Clock gates a mais mudam a árvore de clock (CTS), o skew e os relatórios
  de potência. Por isso é uma decisão, não um detalhe.

## Fonte primária

- `man set_clock_gating_objects` (conferido): a inserção automática é o
  padrão para todos os objetos; `-exclude <hierarquia>` tira os registradores
  dela da inserção; o comando vem antes do `compile_fusion`. Ler o `man`
  inteiro, inclusive os exemplos.
- `man report_clock_gating`: o que cada linha do resumo quer dizer.
- A configuração de referência em `docs/decisions.md` (o que decidimos e por
  quê).

## Experimento (rodado por nós)

1. Depois do 03, contar os clock gates na netlist:
   `sizeof_collection [get_cells -hierarchical -filter "ref_name =~ CGL*"]`.
2. Contar quantos existem no RTL (instâncias do `cv32e40p_clock_gate`; depois
   do flat, o nome da instância ajuda a separar). A diferença é o que a
   ferramenta inseriu.
   Atenção: o filtro `CGL*` pega juntos os do RTL e os inseridos pela
   ferramenta; a separação depende do nome da instância.
3. Ler o `man set_clock_gating_objects` e entender o bloco 3.0b do
   `03_synth.tcl` (`-exclude [get_cells core_i]`).
4. Comparar duas rodadas que só diferem nisso: uma com o bloco 3.0b e outra
   sem ele (comentado). Em cada uma: `rpt/03_clock_gating.rpt` (resumo) e
   `grep -c CGLPPRX2_HVT outputs/cv32e40p_top_syn.v`. Com o 3.0b deve sobrar
   um só clock gate, o do RTL (`sleep_unit_i/core_clock_gate_i/u_icg`).
   Atenção: o `report_clock_gating` chama esse clock gate de
   "Tool-Inserted"; confira pelo nome na netlist que ele é o do RTL. Anote
   também área, potência e timing das duas rodadas.
5. Se quisermos manter a inserção (contra a decisão registrada), aí sim levar
   ao professor os números do passo 4.

## Resultado anotado

| Rodada | Quem rodou | Clock gates total | Do RTL | Inseridos pela ferramenta |
|---|---|---|---|---|
| | | | | |

## Conclusão

(preencher)

## Decisão

(pendente; registrar em `docs/decisions.md`)
