# E02 — Como ler o `report_qor` em vários corners

**Pergunta:** como ler o `report_qor -summary` com um cenário por corner?
**Nível:** júnior
**Situação:** aberto

## Por que este estudo existe

O `report_qor -summary` resume o timing de todos os cenários numa tabela só,
e é o que vai para os slides. Antes de mostrar o relatório a alguém, precisamos
saber explicar cada número de cada cenário (`func_ss`, `func_tt`, `func_ff`).

## O que precisamos saber

- **Cenário** = modo + corner. Cada cenário só analisa o que estiver ligado no
  `set_scenario_status` (setup, hold, potência). Se um cenário estiver com
  `-setup false`, ele não aparece na parte de setup do relatório. No nosso
  `02_scenarios.tcl`, setup e hold ficam ligados nos três cenários.
- **WNS** (worst negative slack) é a pior folga. **TNS** (total negative
  slack) é a soma das folgas negativas. **NVE** (number of violating
  endpoints) é o número de pontos de chegada violando.

## Fonte primária

`man report_qor` no `fc_shell` (ler a descrição das colunas e da opção
`-summary`).

## Experimento (rodado por nós)

1. No `fc_shell`, depois do 03: `man report_qor`. Anotar o que o manual diz
   sobre cada coluna.
2. `report_qor -summary`. Anotar WNS, TNS e NVE de setup e de hold de cada
   cenário.
3. Para cada cenário, separado:
   `report_qor -scenarios func_ss`, depois `func_tt`, depois `func_ff`.
   Conferir que os números batem com os do passo 2.
4. `report_scenarios`: ver quais análises estão ligadas em cada cenário.
5. Escrever com as nossas palavras, em três linhas, como explicar o relatório
   ao professor.

## Evidência já observada

Rodada `pnr_hvt_20261117-170523`, `report_qor -summary -significant_digits 3`:
setup ss −1,287 / TNS −201,551 / NVE 1011; tt −0,130 / −0,535 / 19; ff +0,762.
Hold ss +0,229; tt +0,097; ff −0,003 (1 caminho).

## Resultado anotado

| Rodada | Quem rodou | WNS setup ss / tt / ff | TNS e NVE ss / tt / ff | WNS hold ss / tt / ff |
|---|---|---|---|---|
| | | | | |

## Conclusão

(preencher)

## Decisão

Não é uma decisão de projeto. É conhecimento necessário para ler qualquer
relatório. O resultado vira um parágrafo nos slides: "como ler esta tabela".
