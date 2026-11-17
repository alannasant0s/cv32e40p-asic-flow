# E03 — Violações elétricas na síntese

**Pergunta:** por que a síntese pode terminar com violações de transição e capacitância, e em que etapa elas devem ser corrigidas?
**Nível:** avançada. Onde termina a "síntese lógica" no nosso fluxo é uma pergunta ao professor, levando este estudo.
**Situação:** aberto

## Por que este estudo existe

Violações elétricas em massa não são aceitáveis (requisito do projeto,
`docs/requisitos-professor.md`): ninguém corrige centenas de redes à mão. O
nosso `03_synth.tcl` para o `compile_fusion` antes das etapas físicas, e é
provável que parte das correções elétricas só aconteça depois. Precisamos
saber, com fonte e medida, de onde vêm as violações que sobrarem no fim da
síntese, contar direito (cada rede uma vez) e saber em que etapa elas são
corrigidas, para propor ao professor onde termina a síntese lógica.

## O que precisamos saber

- **Transição** é o tempo que um sinal leva para subir ou descer. A biblioteca
  define um máximo (`max_transition`). Acima dele, o atraso calculado deixa de
  ser confiável e a célula seguinte sofre.
- **Capacitância** é a carga que uma saída alimenta: os pinos de entrada
  ligados nela mais o fio. Cada saída de célula tem um máximo
  (`max_capacitance`).
- **Fanout** é o número de pinos de entrada ligados numa saída. Fanout alto
  passa dos dois limites. A correção é uma árvore de buffers: dividir a carga.
- **Cascata:** uma saída sobrecarregada (capacitância) gera uma transição
  lenta, e essa transição lenta aparece como violação de transição nas
  células seguintes. Uma causa pode virar várias violações.
- **Contagem:** o `report_constraint` lista as violações **por cenário**. A
  mesma rede pode aparecer no ss, no tt e no ff, e nos dois tipos. Somar tudo
  conta a mesma rede várias vezes.
- O nosso `03_synth.tcl` roda o `compile_fusion` só até a etapa `logic_opto`.
  Pelo comentário do script (do `man compile_fusion`), as árvores de buffer
  para fanout alto são da etapa `initial_drc`, que vem **depois** do placement
  grosseiro e roda no `06_place.tcl`. Isso é uma hipótese a provar.

## Fonte primária

- `man compile_fusion`: o que cada etapa faz; o que diz sobre `logic_opto` e
  `initial_drc`.
- `man report_constraint`.

## Experimento (rodado por nós)

1. `man compile_fusion`: anotar com as nossas palavras o que cada uma das 7
   etapas faz e em qual delas as violações elétricas são tratadas.
2. **Contar direito.** Depois do 03:
   `grep -B3 "Number of" rpt/03_violacoes_eletricas.rpt` dá a contagem por
   corner e por tipo. Depois, contar as **redes únicas** (cada rede uma vez,
   em qualquer corner e tipo). Anotar os dois números e dizer qual deles vai
   no relatório.
3. **Controle: onde as violações nascem.** No bloco 3.1 (depois do
   `initial_map`) e no 3.2 (depois do `logic_opto`), rodar o mesmo
   `report_constraint -all_violators -max_transition -max_capacitance -scenarios [all_scenarios]`.
   Se o número cai do 3.1 para o 3.2, o `logic_opto` também corrige parte
   delas. Se não cai, ele não trata disso.
4. **Causa.** Pegar as 3 piores redes de capacitância. Para cada uma, contar
   só os pinos de entrada ligados (o fanout; sem contar quem dirige a rede):
   `sizeof_collection [get_pins -of_objects [get_nets <rede>] -filter "direction==in"]`.
   Depois do flat, use o nome exatamente como aparece no relatório. Se o
   fanout for alto, a explicação "falta árvore de buffers" ganha força.
   Conferir também se há violação de `max_fanout` no relatório.
5. **O que o 06 corrige.** Seguir até o 06 e comparar
   `rpt/06_violacoes_eletricas.rpt`. Atenção: o 06 roda várias etapas
   (`initial_place`, `initial_drc`, `initial_opto`...). Se as violações
   caírem, isso mostra que **o 06** corrige, não que foi só o `initial_drc`.
6. **Levar ao professor uma proposta, não só uma pergunta.** Exemplo:
   "A síntese lógica (até `logic_opto`) termina com N redes únicas violando,
   quase todas de fanout alto (dados). O placement (06) deixa M. Opções:
   (a) aceitar a síntese assim e exigir zero a partir do 06; (b) rodar a
   síntese até uma etapa que corrija, se houver (o que o `man` mostrar no
   passo 1). Qual o senhor considera o fim da síntese lógica?"

## Evidência já observada

Rodada `pnr_hvt_20261117-170523` (03): transição / capacitância por corner:
ff 55 / 1202, ss 560 / 1340, tt 308 / 1288. Contando cada rede uma vez, são
1340 redes, igual ao "Nets with Violations" do `report_qor`. Redes que
aparecem em mais corners e tipos: `core_i/useincr_addr_ex`, `core_i/N30553`,
`core_i/N29574` (falta medir o fanout delas, passo 4).

## Resultado anotado

| Etapa | Quem rodou | Transição ss / tt / ff | Capacitância ss / tt / ff | Redes únicas | Observação |
|---|---|---|---|---|---|
| 3.1 (initial_map) | | | | | |
| 3.2 (logic_opto) | | | | | |
| 06 | | | | | |

## Conclusão

(preencher)

## Decisão

Depende da resposta do professor. Não mudar o `03_synth.tcl` antes disso.
