# E02 — Como ler o `report_qor` em vários corners

**Pergunta:** o que significa cada linha do `report_qor -summary`, em especial a linha "Design"?
**Nível:** júnior
**Situação:** aberto

## Por que este estudo existe

O `report_qor -summary` é o relatório que resume o timing de todos os
cenários numa tabela só, e é o que vai para os slides. Além de uma linha por
cenário (`func_ss`, `func_tt`, `func_ff`), ele traz uma linha chamada
"Design". É fácil confundir essa linha com um quarto corner, ou achar que um
corner "sumiu" porque os números dela repetem os de outro cenário. Antes de
mostrar o relatório a alguém, precisamos saber explicar cada linha.

## O que precisamos saber

- **Cenário** = modo + corner. Cada cenário só analisa o que estiver ligado no
  `set_scenario_status` (setup, hold, potência). Se um cenário estiver com
  `-setup false`, ele não aparece na parte de setup do relatório. No nosso
  `02_scenarios.tcl`, setup e hold ficam ligados nos três cenários.
- **A linha "Design" não é um corner.** É o resumo do projeto inteiro. Para o
  WNS, é o pior valor entre os cenários; por isso ela repete o número do
  cenário que estiver pior.
- **Cuidado com o TNS e o NVE da linha "Design".** Eles provavelmente são
  calculados por ponto de chegada: para cada ponto vale a pior folga entre os
  cenários. Então o TNS da linha "Design" não é a soma dos três cenários, e
  pode nem ser igual ao pior deles. Isso é hipótese até o passo 4.
- **WNS** (worst negative slack) é a pior folga. **TNS** (total negative
  slack) é a soma das folgas negativas. **NVE** (number of violating
  endpoints) é o número de pontos de chegada violando.

## Fonte primária

`man report_qor` no `fc_shell` (ler a descrição das colunas e da opção
`-summary`). O `man` não define a linha "Design"; por isso o passo 4 testa
o comportamento dela.

## Experimento (rodado por nós)

1. No `fc_shell`, depois do 03: `man report_qor`. Anotar o que o manual diz
   sobre o resumo do design.
2. `report_qor -summary`. Anotar o WNS de setup de cada linha.
3. Para cada cenário, separado:
   `report_qor -scenarios func_ss`, depois `func_tt`, depois `func_ff`.
4. Conferir que o WNS da linha "Design" é o **menor** (mais negativo) dos três.
   Fazer o mesmo com o TNS e o NVE e anotar se batem ou não. Para descobrir o
   que a linha é, um teste de uma variável, sem salvar o bloco:
   `set_scenario_status func_ss -setup false`, depois `report_qor -summary`.
   Se a linha "Design" de setup passar a ser igual à do pior cenário que
   sobrou, ela é "o pior cenário". Volte com
   `set_scenario_status func_ss -setup true`.
5. `report_scenarios`: ver quais análises estão ligadas em cada cenário.
6. Escrever com as nossas palavras, em três linhas, como explicar o relatório
   ao professor.

## Evidência já observada

Rodada `pnr_hvt_20261117-170523`, `report_qor -summary -significant_digits 3`:
setup ss −1,287 / TNS −201,551 / NVE 1011; tt −0,130 / −0,535 / 19; ff +0,762.
A linha `Design` (setup) é −1,287 / −201,551 / 1011: igual ao ss, e o TNS não é
a soma (seria −202,086). No hold, a linha `Design` repete o ff (−0,003). Falta o
teste do passo 4 (desligar o setup do ss) para separar "pior cenário" de "pior
por ponto de chegada".

## Resultado anotado

| Rodada | Quem rodou | WNS ss / tt / ff | WNS "Design" | TNS e NVE ss / tt / ff / Design | Bate com o pior? |
|---|---|---|---|---|---|
| | | | | | |

## Conclusão

(preencher)

## Decisão

Não é uma decisão de projeto. É conhecimento necessário para ler qualquer
relatório. O resultado vira um parágrafo nos slides: "como ler esta tabela".
