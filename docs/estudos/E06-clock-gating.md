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

- `man compile_fusion` e a documentação de clock gating do Fusion Compiler:
  nome da opção que liga ou desliga a inserção. `TODO(verify)`: o nome exato
  da opção nesta versão.
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
3. Achar no manual o nome da opção que controla a inserção automática e
   anotar a fonte (comando `man` e trecho).
4. Desligar a inserção (opção achada no passo 3), rodar 01 a 03 de novo e
   conferir que só sobram os do RTL. Comparar área, potência e timing com e
   sem a inserção (é a única variável que muda entre as duas rodadas).
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
