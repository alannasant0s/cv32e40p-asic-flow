# E07 — Por que o hold pode ser negativo na síntese

**Pergunta:** se a síntese mostrar hold um pouco negativo (por exemplo, no ff), isso é um erro?
**Nível:** júnior
**Situação:** aberto

## Por que este estudo existe

Depois do 03, é comum o `report_qor -summary` mostrar alguns centésimos de
nanossegundo negativos no hold, principalmente no corner rápido. Isso parece
um problema, mas pode ser só consequência de o clock ainda ser ideal na
síntese. Precisamos saber ler o relatório de hold, explicar o número e saber
em que etapa o hold é corrigido, para não "consertar" na síntese algo que o
fluxo corrige depois do CTS.

## O que precisamos saber

- **Hold** confere se o dado novo não chega cedo demais e atropela o dado que
  o flip-flop ainda está capturando. É limitado pelo caminho **mais rápido**,
  por isso costuma ser pior no corner rápido (ff).
- Na síntese o clock é **ideal**: chega em todos os flip-flops no mesmo
  instante, sem atraso. A árvore de clock real só existe depois do CTS (07).
- A diferença de chegada do clock entre os flip-flops (skew) é o que mais pesa
  no hold. Sem a árvore, a ferramenta não sabe o skew real. Por isso, por
  padrão, o hold é corrigido depois do CTS (`clock_opt`, no 07).
- No SDC, a incerteza de hold antes do CTS é de 0,10 ns. Uma folga de, por
  exemplo, −0,03 ns quer dizer que alguns caminhos curtos ficaram a 0,03 ns
  de cumprir essa margem.

## Fonte primária

- O `man clock_opt` **não fala de hold**. A evidência de que o `clock_opt`
  corrige hold tem que vir do log do 07: procurar o custo de hold
  (HOLD-COST) caindo e uma etapa "Hold Opt". Por isso o passo 3 confere o
  resultado nos três corners, com 3 casas decimais.
- O nosso SDC, `constraints/cv32e40p_baseline.sdc` (por que a incerteza de hold
  é pequena antes do CTS).

## Experimento (rodado por nós)

1. Depois do 03: `report_timing -scenarios func_ff -delay_type min`.
   Procurar no relatório a linha do clock e ver que ele está como "ideal".
   Achar também as linhas **"clock uncertainty"** e **"library hold time"**:
   são elas que explicam o número. Com clock ideal, o dado precisa chegar
   depois de (incerteza de hold + hold time do flip-flop). Uma folga de
   −0,03 ns quer dizer que faltaram 0,03 ns para isso.
2. Anotar o caminho: de onde sai, onde chega, quantas células tem (caminho
   curto, de poucas células, é o típico de problema de hold).
3. Depois do 07: o mesmo comando, **nos três corners** (`func_ss`, `func_tt`,
   `func_ff`). Agora o clock está "propagated" (real). O hold deve cumprir o
   critério 07.1 nos três: com a árvore real, o skew pode criar violação de
   hold também fora do ff. No log do 07, procurar a etapa de correção de hold.
4. Escrever com as nossas palavras, em três linhas, como explicar isso ao
   professor.

## Resultado anotado

| Etapa | Quem rodou | Hold ss / tt / ff | Incerteza e hold time lidos | Clock ideal ou propagado? |
|---|---|---|---|---|
| 03 | | | | |
| 07 | | | | |

## Conclusão

(preencher)

## Decisão

Não é uma decisão nova: segue o fluxo padrão (hold corrigido no 07). É
conhecimento para explicar o relatório.
