# O que introduzimos no projeto base e por quê

O projeto base é o núcleo **CV32E40P** do OpenHW Group (submódulo `third_party/cv32e40p`, tag `cv32e40p_v1.8.3`). Ele traz:
- o RTL do processador;
- um testbench de exemplo;
- um SDC de exemplo;
- scripts de lint e de verificação formal.

Esses scripts foram feitos **para ferramentas de outros fabricantes** (Siemens Questa) ou para uma tecnologia não especificada.

O ambiente da residência só tem ferramentas **Synopsys** e o kit **SAED32**. Por isso, quase todo o fluxo é nosso. **O RTL do processador não foi alterado em nenhuma linha.** Cada decisão está registrada com o porquê em `docs/decisions.md`.

## Resumo

| Etapa | O que o projeto base tem | O que nós fizemos | Por quê |
|---|---|---|---|
| Configuração do núcleo | Parâmetros com padrão | Escolhemos `FPU=0`, `COREV_PULP=0`, `COREV_CLUSTER=0`, `ZFINX=0`, `NUM_MHPMCOUNTERS=1`, ou seja, um RV32IMC simples | Começar pelo núcleo básico. FPU e extensões PULP aumentariam muito a área e o tempo de cada rodada. |
| Lista de arquivos | Um manifesto (`cv32e40p_manifest.flist`) | `scripts/gen_filelist.sh` gera a lista a partir do manifesto. A opção `--synthesis` troca o clock gate de simulação pelo da SAED32. | Uma só fonte de verdade para simulação, lint, síntese e Formality: todos leem os mesmos arquivos. |
| Clock gate | `cv32e40p_sim_clock_gate.sv`, um modelo só de simulação | `rtl/cv32e40p_clock_gate_saed32.sv`, que usa a célula `CGLPPRX2_<VT>` da biblioteca | Um clock gate tem que ser uma célula própria da biblioteca, para não gerar glitch (pulso falso) no clock. O próprio OpenHW manda trocar esse arquivo pela célula da tecnologia. Mantivemos o mesmo nome de módulo e as mesmas portas, então o RTL não muda. |
| Simulação RTL | Makefile para **Questa (Siemens)** e programas em C, que precisam de um compilador RISC-V | `tool_data/vcs/Makefile` e `tool_data/vcs/dump.tcl` para o **VCS (Synopsys)**, com forma de onda no Verdi. Usamos o testbench do OpenHW sem mudar nada. `verif/sw/hello.hex` foi **montado à mão**. | O ambiente não tem Questa nem compilador RISC-V. Montamos o Hello World instrução por instrução, direto na codificação RV32I (`docs/sim-vcs.md`). |
| Biblioteca (NDM) | Não tem, porque não é ligado a nenhuma tecnologia | `tool_data/fc/create_ndm.tcl`: uma NDM por família (HVT primeiro), com os três corners do conjunto nominal e o ss a −40 °C para a checagem de inversão de temperatura | O Fusion Compiler precisa das células no formato NDM. Os corners vêm do databook (estudo E01). |
| Constraints (SDC) | `constraints/cv32e40p_core.sdc`, com período fixo de 5 ns, para uma tecnologia não especificada | `constraints/cv32e40p_baseline.sdc`: período lido do fluxo (8 ns), incerteza de clock, transição e carga fixas nas portas. Os atrasos de entrada e saída seguem as **mesmas frações por interface** do SDC do OpenHW. | O período é o pedido no projeto. As frações de E/S são uma premissa declarada, estudada no E04. |
| Síntese | Não tem | `tool_data/fc/00_tech_setup.tcl` a `03_synth.tcl` no **Fusion Compiler**, bloco a bloco, com três cenários (ss, tt, ff) e setup e hold analisados nos três; netlist flat abaixo do `core_i` | Fluxo pedido pelo professor (`docs/requisitos-professor.md`). Os três corners mostram o pior caso de velocidade, o caso típico de consumo e o pior caso de hold. |
| Fluxo físico | Não tem | `tool_data/fc/04_floorplan.tcl` a `09_finish.tcl` | Levar o processador até o layout, depois da síntese aceita. |
| Lint | Scripts para **Questa AutoCheck (Siemens)** | `tool_data/lint/lint.tcl` no **VC SpyGlass (Synopsys)**, com a mesma configuração da síntese. Cada tipo de aviso está justificado em `docs/lint.md`. | O ambiente não tem a ferramenta da Siemens. Fazer o lint com a mesma configuração da síntese garante que olhamos o mesmo circuito que vira chip. |
| Equivalência (Formality) | Não tem (os scripts formais do base são de outro tipo de verificação) | `tool_data/fm/fm.tcl` no **Formality (Synopsys)**, que compara o RTL com a netlist usando o SVF da síntese | Provar que a síntese não mudou a função do circuito (critério 03.7). |
| Análise de dados | Não tem | `scripts/analysis/coleta_metricas.py` (servidor, só biblioteca padrão) lê os relatórios de cada rodada e grava CSV. `scripts/analysis/tabela_fluxo.py` e `tabela_familias.py` (Windows, pandas) montam as tabelas. | Tirar os números dos relatórios sem cópia à mão (`docs/data-spec.md`). |
| Método | — | Estudos de decisão com fonte primária (`docs/estudos/`), critérios de aceite por etapa (`docs/criterios-aceite.md`), decisões registradas (`docs/decisions.md`) e cada rodada numa pasta própria em `runs/` | Cada resultado pode ser refeito e explicado. Nenhuma decisão fica sem fonte. |

## A comparação entre famílias (depois da HVT)

Depois que o fluxo completo fechar na HVT, a pergunta é **o que muda quando o mesmo núcleo é feito com cada família de transistores** (LVT, RVT, HVT). Para responder, o mesmo script e o mesmo SDC rodam trocando só a família (a NDM e o clock gate). Assim, toda diferença nos números vem da família.

## Explicando o lint em uma frase

O projeto base já tinha lint, mas para uma ferramenta que não temos. Então escrevemos o nosso no VC SpyGlass, da Synopsys, lendo exatamente os mesmos arquivos e parâmetros da síntese, e justificamos cada tipo de aviso: nenhum exige mudar o RTL, e a maioria vem de partes que a nossa configuração desliga (FPU, PULP, PMP).
