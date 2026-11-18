# Requisitos do projeto (orientação do professor da residência)

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

Os requisitos abaixo vêm da orientação do professor da residência. Estão em
paráfrase fiel, com a data e a fonte. **Estes requisitos mandam:** se um
script, uma decisão ou um documento contradiz algum deles, quem está errado é
o script, a decisão ou o documento. Toda decisão nossa (`docs/decisions.md`)
tem que caber dentro destes requisitos.

Coluna **Fonte**: "mensagem" = orientação escrita; "reunião" = registro nosso
de conversa oral (pode ter imprecisão; confirmar com ele quando houver
dúvida).

## Requisitos

| # | Requisito (paráfrase) | Data | Fonte | Onde aparece no projeto |
|---|---|---|---|---|
| R1 | O fluxo usa só o Fusion Compiler, da síntese ao roteamento | 2026-10-14 | reunião | `docs/flow-spec.md`; scripts em `tool_data/fc/` |
| R2 | Três corners (ss, tt, ff) em todas as etapas e em todos os relatórios | 2026-10-14 (reforçado em 2026-11-13) | reunião; mensagem | `02_scenarios.tcl` bloco 2.6 (setup e hold nos três); critérios de aceite |
| R3 | O fluxo completo é feito primeiro só com a família HVT; LVT e RVT vêm depois | 2026-11-06 | reunião | `docs/plano-de-trabalho.md` |
| R4 | As apresentações mostram imagens do projeto: arquitetura do processador (diagrama do OpenHW, citando a fonte), esquemático da GUI, hierarquia | 2026-11-06 | reunião | `docs/img/` |
| R5 | Relatórios e apresentações levam prints direto do terminal, não só tabelas redigitadas | 2026-11-06 | reunião | etapa 6 do plano |
| R6 | Clock de 8 ns (125 MHz) | 2026-11-09 | mensagem | `00_tech_setup.tcl` (`CLK_PERIOD`) |
| R7 | Antes de qualquer outra coisa, os relatórios da síntese lógica | 2026-11-09 | mensagem | `docs/plano-de-trabalho.md` |
| R8 | A netlist pode ser flat (não precisa ser hierárquica) | 2026-11-09 | mensagem | `01_init_design.tcl` bloco 1.6; critério 03.5 |
| R9 | O trabalho é a "síntese lógica de um processador RISC-V" (o CV32E40P), e é assim que deve ser chamado | 2026-11-13 | mensagem | títulos de relatórios e slides |
| R10 | Violação de timing aceitável: menor que 0,01 ns | 2026-11-13 | mensagem | `docs/criterios-aceite.md` (WNS > −0,01 ns) |
| R11 | Violações elétricas em massa não são aceitáveis: ninguém corrige centenas de redes à mão | 2026-11-13 | mensagem | estudo E03; critério 03.3 |
| R12 | Terminar a síntese lógica até o fim de novembro de 2026, revendo com cuidado cada passo | 2026-11-13 | mensagem | `docs/plano-de-trabalho.md` |
| R13 | Proibir uma célula (`dont_use`) vale para todo o design e exige um estudo sólido da célula; é decisão de nível avançado | 2026-11-13 | mensagem | estudo E05; critério 03.6 |
| R14 | Com a biblioteca certa, 8 ns é um clock folgado: nenhuma célula é lenta para ele. A frequência de 125 MHz é menos da metade da frequência de referência da documentação do PDK | 2026-11-13 | mensagem | estudo E01 |
| R15 | Não há metas de PPA (potência, desempenho, área): o requisito é que tudo funcione | 2026-10-27 | mensagem | critérios de aceite |
| R16 | No GitHub só vão scripts, relatórios e logs; nunca arquivos do PDK | 2026-10-27 | mensagem | `AGENTS.md`; `.gitignore` |

Sobre o R16: relatórios e logs das rodadas podem ser versionados, desde que
não carreguem conteúdo do PDK (bibliotecas, arquivos de tecnologia, runsets,
NDM, GDS ou trechos desses arquivos).

Sobre o R15: leitura nossa, nada de otimizar além do necessário. O que
"funcionar" exige em cada etapa está em `docs/criterios-aceite.md`.

## O que isso quer dizer para a síntese lógica (até o fim de novembro)

A entrega da síntese lógica precisa ter:

1. O título certo (R9).
2. Setup e hold dos três corners, cada um na sua linha (R2).
3. WNS > −0,01 ns em setup nos três corners (R10). Leitura nossa: se algum
   caminho não fechar, o motivo e a proposta (estudo E04 para entradas e
   saídas).
4. As violações elétricas explicadas e com o plano aceito pelo professor
   (R11, estudo E03).
5. Nenhuma célula proibida sem estudo (R13).
6. Prints direto do terminal (R5).
7. Tudo rodado e explicado pela dupla (`docs/metodo-de-trabalho.md`).

## Perguntas que vamos levar ao professor (com dados e alternativas)

- Onde termina a "síntese lógica" no nosso fluxo, diante das violações
  elétricas (E03).
- Que ambiente supor para a memória e o barramento nos atrasos de E/S (E04).
- Que margens ele considera adequadas (E08).
