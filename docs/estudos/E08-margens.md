# E08 — Margens: derate, incerteza e ambiente

**Pergunta:** as margens de segurança que somamos ao timing (derate de OCV, incerteza do clock, transição e carga do ambiente) são justificadas, e quanto cada uma pesa no resultado?
**Nível:** avançada (pergunta ao professor, com os números)
**Situação:** aberto

## Por que este estudo existe

Vários valores do SDC e do `02_scenarios.tcl` estão em vigor **sem fonte
primária**: são escolhas iniciais razoáveis, mas ninguém mediu quanto cada
uma pesa.

| Margem | Valor | Onde |
|---|---|---|
| Derate de OCV | caminho tarde +5 %, cedo −5 %, em clock e dados | `02_scenarios.tcl`, bloco 2.4 |
| Incerteza de setup / hold antes do CTS | 0,30 / 0,10 ns | SDC |
| Incerteza de setup / hold depois do CTS | 0,15 / 0,05 ns | `07_cts.tcl`, bloco 7.2 |
| Transição do clock ideal | 0,10 ns | SDC |
| Transição nas entradas | 0,10 ns | SDC |
| Carga nas saídas | 5 fF | SDC |

Elas somam pessimismo. Num caminho de uns 7 ns, 5 % de derate são cerca de
0,35 ns; com os 0,30 ns de incerteza, são uns 0,65 ns de margem. Isso é muito
maior que a violação aceitável do projeto (menor que 0,01 ns). Margem não é
erro, mas precisa ser escolhida de propósito e com justificativa.

## O que precisamos saber

- **OCV (variação no chip) e derate:** duas células iguais no mesmo chip não
  têm exatamente o mesmo atraso. O derate deixa o caminho que chega tarde um
  pouco mais lento e o que chega cedo um pouco mais rápido, para cobrir isso.
- **CRPR** (remoção do pessimismo do caminho comum do clock): quando o clock
  de origem e o de destino passam pelos mesmos buffers, o derate não deveria
  contar duas vezes nesse trecho comum. Precisamos saber se está ligado no
  nosso fluxo (opção a achar no `man`; `TODO(verify)`).
- **Incerteza (uncertainty):** margem para jitter (variação do período do
  clock) e, antes do CTS, para o skew que ainda não existe.
- **VSS:** hoje só a tensão do VDD é definida por corner. Conferir no `man
  set_voltage` se o VSS precisa ser definido (0 V) e o que acontece se não for.
- **Hold otimizado em todos os corners:** o hold é analisado nos três
  cenários. As etapas que corrigem hold (`clock_opt`, `route_opt`) podem
  então inserir atrasos também por causa do ss. Isso é certo (o hold tem que
  cumprir em todos os corners), mas custa área. Medir.

## Fonte primária

- `man set_timing_derate`, `man set_clock_uncertainty`, `man set_voltage`.
- Documentação do Fusion Compiler sobre CRPR (nome da opção: `TODO(verify)`).
- O requisito do professor: que margem ele aceita.

## Experimento (rodado por nós)

1. Num caminho crítico, `report_timing -scenarios func_ss` e achar as linhas
   do derate e da incerteza. Anotar quanto cada uma pesa nesse caminho.
2. Na mesma netlist, só como análise (sem salvar o bloco): o derate vale para
   o corner atual (`man set_timing_derate`), então escolha o corner antes:
   `current_corner ss`, depois `set_timing_derate -late 1.00` e
   `set_timing_derate -early 1.00`, e veja o WNS do ss. Repita com
   `current_corner tt`. Depois, à parte, a incerteza de setup para 0,15 ns.
   Uma variável por vez.
3. Achar a opção que liga o CRPR e conferir se está ligada.
   `report_app_options *crpr*` lista opções de ajuste fino
   (`time.crpr_different_transition_derate`, `time.crpr_remove_clock_to_data_crp`...),
   mas não uma que liga ou desliga. Procurar com outro padrão, por exemplo
   `report_app_options *reconvergence*` (`TODO(verify)`), e anotar o nome e o valor.
4. Levar ao professor a tabela "margem → quanto pesa no WNS" e a pergunta:
   "que margem o senhor considera adequada para a síntese e para o
   sign-off?"

## Resultado anotado

| Margem testada | Quem rodou | WNS ss antes | WNS ss depois | Observação |
|---|---|---|---|---|
| | | | | |

## Conclusão

(preencher)

## Decisão

(pendente; registrar em `docs/decisions.md` depois da resposta do professor)
