# Estado atual

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

**Leia isto primeiro ao retomar o trabalho** (pessoa ou IA). Atualize no fim de
cada sessão, no mesmo commit das mudanças.

Última atualização: 2026-11-19.

## Onde estamos

- O repositório começa com os scripts do fluxo prontos (simulação, lint, NDM,
  síntese `01` a `03`, físico `04` a `09`, Formality), o método de trabalho, os
  critérios de aceite, as decisões vigentes e os estudos E01 a E10.
- **Primeira rodada da síntese executada pela Alanna (2026-11-17), ainda
  não aceita** (03.1 não passa; não é a entrega), rodada
  `pnr_hvt_20261117-170523` (registro em `docs/rodadas/`). Setup: ff +0,762,
  ss −1,287, tt −0,130 ns; registrador → registrador fecha nos três corners;
  violam caminhos de entrada e saída (E04). Hold ff −0,003 ns (incerteza de hold, E07).
  1340 redes com violação elétrica, relatadas e explicadas (E03; zero
  cobrado no 06). Critérios 02.1 a 02.5, 03.5, 03.6, 03.7 e 03.9 cumpridos; 03.3
  relatado e explicado; 03.1 não passa. **Formality: Verification SUCCEEDED**
  (`fm_hvt_20261117-200223`, 2243 pontos, 0 falhas). O registrador do RTL sem par na netlist
  (`aligner_ready_q`) não tinha carga e foi removido pela síntese.
- **Simulação do RTL passou (Alanna, 2026-11-18, `15f9a5c`):** "Hello World"
  e `EXIT SUCCESS` em 360 ns (`docs/sim-vcs.md`). Avisos só do testbench e o
  `RT-NCMUCS` já conhecido.
- **Lint passou (Alanna, 2026-11-18, `lint_20261118-150448`):** 0 latches,
  2613 bits de flip-flop; 2 errors, 228 warnings e 28 infos, iguais à
  referência tipo a tipo, todos justificados (`docs/lint.md`). Etapa 2
  concluída.
- **Etapa 0 concluída pela Alanna (2026-11-17):** clone na conta dela, submódulo
  em `cv32e40p_v1.8.3`, hook ativo, filelist de síntese gerada (33 arquivos,
  clock gate da SAED32). Falta a etapa 0 do Apolônio: clonar o repositório
  novo (público; o token só é necessário para dar push) e reproduzir a rodada.
- Nenhum número de resultado vale até a dupla rodar e conferir com os critérios.
- Os scripts foram validados de ponta a ponta em 2026-11-17 (NDM, `01` a
  `03` e Formality, numa pasta separada): rodam sem erro, o `report_pvt` dá
  "no PVT mismatches" nos três corners, os relatórios saem nos três corners,
  sobra só o clock gate do RTL e o Formality passa. Essa validação prova que
  os scripts funcionam; os números dela não são resultado da dupla.
- Entrega mais próxima: **síntese lógica do processador RISC-V CV32E40P**
  (HVT, 8 ns, três corners) **até o fim de novembro de 2026**
  (`docs/requisitos-professor.md`).

## Próximo passo

1. **Apolônio:** clonar o repositório novo e reproduzir a rodada pelo
   `docs/passo-a-passo-sintese.md` (cada bloco tem os números de 17/11 para
   comparar).
2. **Mensagem ao professor enviada (2026-11-18)**, com os prints do resumo de
   timing e da folga registrador → registrador. Perguntas: manter ou mudar os
   atrasos de entrada e saída (E04) e onde corrigir as violações elétricas
   (E03). **Resposta em 19/11:** o professor marcou **reunião para
   segunda, 23/11**, para esclarecer as perguntas. Preparar a reunião com
   explicação simples e dados medidos (E04: efeito dos atrasos de E/S na
   folga). Margens e CRPR (E08) e TIEH/TIEL ficam para
   depois, se ele não comentar.
3. Conferências de 18/11 feitas (03.5, 03.6, 03.7 cumpridos; potência nos
   três corners). Etapa 2 concluída (18/11): simulação e lint passaram (`docs/sim-vcs.md`,
   `docs/lint.md`).
4. Pendência pequena da rodada de 17/11: conferir o DMM-116 ("1 mismatches")
   com `report_design_mismatch` no bloco `cv32e40p_top_syn` (registro da
   rodada, fim da seção de conferências).

Em paralelo:

`docs/plano-de-trabalho.md`, **etapa 1** (entender o processador: diagrama de
blocos, pipeline, interfaces OBI, interrupções; estudo E04, passos 1 e 2). A pergunta dos atrasos de E/S já foi enviada
(18/11); resposta em 19/11: o professor marcou reunião para segunda, 23/11, para esclarecer as perguntas.

Para rodar a síntese linha por linha: `docs/passo-a-passo-sintese.md` (gerado
dos scripts por `scripts/docs/gera_passo_a_passo.py`; mudou um script, gere de novo).

Etapa 0, para quem ainda não fez:

```bash
git clone --recurse-submodules https://github.com/alannasant0s/cv32e40p-asic-flow.git
cd cv32e40p-asic-flow
git config core.hooksPath .githooks
source /Tools/synopsys-scripts/snps.sh
scripts/gen_filelist.sh --synthesis
```

Depois: etapas 1 (entender o processador) a 6 (entrega da síntese).

## Decisões em aberto

| Assunto | Situação | Onde |
|---|---|---|
| Corners (ss 0,95 V) | aplicado; a dupla prova no estudo E01 | ADR-006, E01 |
| Inserção automática de clock gating | desligada no `03` (bloco 3.0b, fonte: `man set_clock_gating_objects`); conferida na rodada de 17/11 (1 clock gate, o do RTL; 03.9 cumprido); falta entender a potência no E06 | ADR-009, E06 |
| Atrasos de E/S do SDC | premissa em estudo; pergunta enviada em 18/11; resposta em 19/11: o professor marcou reunião para segunda, 23/11, para esclarecer as perguntas | ADR-007, E04 |
| Violações elétricas na síntese | proposta (relatar na síntese, zero no 06; critérios 03.3 e 06.4) enviada em 18/11; resposta em 19/11: o professor marcou reunião para segunda, 23/11, para esclarecer as perguntas | E03 |
| Margens (derate, incerteza) | medir e perguntar ao professor | ADR-008, E08 |
| TIEH/TIEL liberadas no `03` | levar como pergunta ao professor | ADR-010 |
| Potência nos três corners | feito (18/11): ss 42,3 / tt 51,1 / ff 72,0 mW; entender o vazamento alto e a interna negativa no ff | ADR-006, E06 |
| Relatórios e logs no Git | decidir se as rodadas oficiais entram (permitido pelo professor) | ADR-015 |
| Restrições da árvore de clock | estudar antes do `07` | E09 |
| Antena, densidade, LVS, pinos de alimentação | estudar antes do `08` | E10 |

## Perguntas ao professor (com dados e alternativas)

Enviadas em 2026-11-18; resposta em 19/11: o professor marcou reunião para segunda, 23/11, para esclarecer as perguntas:

1. Atrasos de E/S: que ambiente supor para a memória e o barramento (E04).
2. Onde termina a síntese lógica diante das violações elétricas (E03).

A levar depois, se ele não comentar:

3. Margens adequadas para síntese e sign-off (E08).
4. Liberar TIEH/TIEL na síntese (ADR-010).

## Repositório

- Este repositório começou em 2026-11-14, limpo, e é público desde
  2026-11-18 (portfólio), com o acordo do professor e dos dois autores. Por
  isso nada do PDK, nem nome do professor, logins ou nome do servidor.
- Commits com o e-mail "noreply" do GitHub (`git config user.email`).
- O hook de pre-commit barra arquivos do PDK e, se existir o arquivo local
  `.git/info/padroes-proibidos` (uma expressão regular por linha, fora do
  Git), também conteúdo proibido (nome do servidor, servidor de licença,
  logins). Cada autor cria o seu.
- Licença: Apache 2.0 para os arquivos dos autores; Solderpad para o RTL, o SDC
  derivado e as figuras do OpenHW (`NOTICE`).

## Como manter este arquivo

No fim de cada sessão: atualizar "Onde estamos", "Próximo passo" e "Decisões em
aberto"; registrar erro novo em `docs/erros-conhecidos.md`; decisão nova em
`docs/decisions.md`.
