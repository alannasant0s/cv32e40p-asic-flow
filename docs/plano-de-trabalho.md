# Plano de trabalho

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

Este plano vai do ambiente pronto até a entrega da síntese lógica, no fim de
novembro de 2026. O fluxo físico (04 a 09) vem depois. Cada script é rodado e
entendido bloco a bloco, por nós dois.

**Régua:** `docs/requisitos-professor.md` (R1 a R16). **Como trabalhar:**
`docs/metodo-de-trabalho.md`. **Quando uma etapa está pronta:**
`docs/criterios-aceite.md`.

**Entrega da síntese (R7, R12):** síntese lógica do processador RISC-V
CV32E40P (biblioteca HVT, 8 ns, flat abaixo do `core_i`, três corners)
revisada e explicada, **até o fim de novembro**. O fluxo físico só começa
depois.

## Situação (17/11/2026)

| Etapa | Situação |
|---|---|
| 0 — ambiente | Alanna: feita. Apolônio: falta clonar o repositório novo (passo a passo, seção "Primeiro: o repositório mudou") |
| 1 — entender o processador | em andamento (prova da etapa 1, `docs/estudos/etapa1-prova.md`) |
| 2 — simulação e lint | a fazer |
| 3 — NDM e corners | feita pela Alanna (0 erros, quatro corners da HVT) |
| 4 — síntese bloco a bloco | primeira rodada feita pela Alanna (`docs/rodadas/pnr_hvt_20261117-170523.md`): critérios 02 cumpridos; 03.9 cumprido; 03.5, 03.6 e 03.7 com conferências pendentes (registro da rodada); 03.1 e 03.3 não passam ainda. Falta o Apolônio reproduzir e conferir |
| 5 — estudos e perguntas | próximo passo: E04 (entradas e saídas), E03 (regras elétricas), E08 (margens), TIEH/TIEL; potência nos três corners já no `03` |
| 6 — entrega | fim de novembro |

## Regras do plano

- Uma etapa por vez. Só se passa para a próxima quando os critérios da atual
  passam e os dois sabem explicar o que foi feito.
- Uma pessoa roda e a outra acompanha e confere ao vivo; quem roda alterna a
  cada etapa (método, seção 4). Anotar pasta da rodada, hash do git, quem
  rodou e quem conferiu.
- Só conta como resultado o que a dupla rodou, bloco a bloco.
- Nada de metas de potência, desempenho ou área (R15): o objetivo é que tudo
  funcione e feche.

## Etapa 0 — Preparar o ambiente

**Para quê:** cada um ter o repositório, as ferramentas e a lista de arquivos
do RTL prontos na sua conta.

1. Clonar o repositório com o submódulo do processador:
   `git clone --recurse-submodules <url do repositório>` (ou, num clone já
   feito, `git submodule update --init`).
2. Em todo terminal novo, carregar as ferramentas:
   `source /Tools/synopsys-scripts/snps.sh`.
3. Gerar a lista de arquivos do RTL para a síntese:
   `scripts/gen_filelist.sh --synthesis`.
4. Ler juntos: `docs/requisitos-professor.md`, `docs/metodo-de-trabalho.md`,
   `docs/criterios-aceite.md`.

**Pronto quando:** `fc_shell` abre nos dois terminais, a filelist existe, e
os dois sabem dizer, sem ler, os requisitos R2, R6, R10, R11, R12, R13, R15 e
R16.

## Etapa 1 — Entender o que vamos implementar

**Requisitos:** R4 (imagens do projeto), R9 (é um processador RISC-V).

1. Ler o diagrama de blocos e o pipeline do CV32E40P
   (`docs/img/cv32e40p_diagrama_blocos.png` e `docs/img/cv32e40p_pipeline.png`,
   do OpenHW, citando a fonte).
2. Anotar, com as nossas palavras: estágios do pipeline (IF, ID, EX, WB),
   o que são as interfaces OBI de instrução e de dados, e as interrupções.
   Isso é a base do estudo E04 (atrasos de E/S).
3. Ver os parâmetros que usamos (`00_tech_setup.tcl`, `PARAMS`) e o que cada
   um liga ou desliga.

**Pronto quando:** os dois explicam o diagrama em 5 minutos.

## Etapa 2 — Simulação do RTL e lint

**Para quê:** saber que o RTL funciona antes de sintetizar (R15: "tudo
funcionando").

1. Simulação: seguir `docs/sim-vcs.md` (`tool_data/vcs/`). Entender o que o
   teste mostra.
2. Lint: seguir `docs/lint.md` (`tool_data/lint/lint.tcl`). Entender cada
   aviso que sobrar.

**Pronto quando:** a simulação passa e cada aviso de lint está explicado.

## Etapa 3 — Biblioteca (NDM) e corners

**Requisitos:** R2, R14. **Estudo:** E01.

1. Ler o databook (Tabelas 1.4 e 1.6) e fazer os passos 1 a 3 do E01.
2. Gerar a NDM: `lm_shell -x "set VT hvt" -file tool_data/fc/create_ndm.tcl -batch`.
3. Conferir o relatório de `check_workspace` (0 erros).

**Pronto quando:** os dois explicam por que o ss é o de 0,95 V (conjunto
nominal) e não o de 0,75 V.

## Etapa 4 — Síntese lógica, bloco a bloco

**Requisitos:** R2, R6, R7, R8, R9, R10, R11, R13. **Estudos:** E02, E06, E07.

1. `01_init_design.tcl`: ler o RTL, montar o circuito, deixar flat.
2. `02_scenarios.tcl`: corners, cenários, SDC. Conferir os critérios 02.1 a
   02.6.
3. `03_synth.tcl`: síntese. Conferir os critérios 03.1 a 03.9.
4. Formality, com a netlist e o SVF desta rodada (troque `<rodada>` pela pasta):
   `fm_shell -x "set VT hvt; set NETLIST runs/<rodada>/outputs/cv32e40p_top_syn.v; set SVF runs/<rodada>/cv32e40p.svf" -file tool_data/fm/fm.tcl > fm_hvt.log 2>&1`
5. Fazer os estudos E02 (ler o `report_qor`), E07 (hold na síntese) e E06
   (clock gating conforme a decisão registrada).

**Pronto quando:** critérios 02 e 03 conferidos, ou cada falha explicada.

## Etapa 5 — O que não fechar vira estudo e pergunta

**Requisitos:** R10, R11. **Estudos:** E03, E04, E08.

1. Se algum corner tiver WNS ≤ −0,01 ns: E04 (entradas e saídas) e E08
   (margens), uma variável por vez.
2. Violações elétricas: E03.
3. Montar as perguntas ao professor **com dados e 2 ou 3 alternativas**
   (método, seção 3). Mandar assim que estiverem prontas, para dar tempo de
   resposta antes do fim de novembro.

## Etapa 6 — Entrega da síntese lógica (até o fim de novembro)

**Requisitos:** R5, R7, R9, R12, R16.

1. Relatório com o título certo: "Síntese lógica do processador RISC-V
   CV32E40P" (R9).
2. Prints direto do terminal (R5): `report_clocks`, `report_pvt`,
   `report_scenarios`, `report_qor -summary`, `report_timing` por corner,
   violações elétricas, `report_area`, `report_power`, resultado do
   Formality.
3. Lista "Antes de enviar ao professor" de `docs/criterios-aceite.md`
   preenchida e assinada pelos dois.
4. Relatórios e logs da rodada oficial podem ir para o GitHub (R16), sem
   conteúdo do PDK.

## Depois da síntese — fluxo físico

Só depois da síntese aceita: estudos E09 (árvore de clock) e E10 (sign-off
físico), e então 04 a 09, uma etapa por vez, com os mesmos cuidados. Se o DRC
do roteamento acusar erros concentrados numa célula, estudo E05. Depois da
HVT, a LVT e a RVT (R3).

## Calendário sugerido

| Período | Etapas |
|---|---|
| 1ª semana | 0, 1 (mandar logo a pergunta do E04, que já sai do entendimento das interfaces) |
| 2ª semana | 2, 3 |
| 2ª e 3ª semanas | 4 (mandar logo depois do 03 a pergunta do E03, com os números) |
| 3ª semana | 5 (fechamento dos estudos) |
| última semana de novembro | 6 |
