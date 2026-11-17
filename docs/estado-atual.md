# Estado atual

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

**Leia isto primeiro ao retomar o trabalho** (pessoa ou IA). Atualize no fim de
cada sessão, no mesmo commit das mudanças.

Última atualização: 2026-11-17.

## Onde estamos

- O repositório começa com os scripts do fluxo prontos (simulação, lint, NDM,
  síntese `01` a `03`, físico `04` a `09`, Formality), o método de trabalho, os
  critérios de aceite, as decisões vigentes e os estudos E01 a E10.
- **Síntese lógica concluída pela Alanna (2026-11-17),** rodada
  `pnr_hvt_20261117-170523` (registro em `docs/rodadas/`). Setup: ff +0,762,
  ss −1,287, tt −0,130 ns; registrador → registrador fecha nos três corners;
  violam caminhos de entrada e saída (E04). Hold ff −0,003 ns (clock ideal).
  1340 redes com violação elétrica (E03). Critérios 02.1 a 02.5 cumpridos;
  03.1 e 03.3 ainda não. Falta o Formality.
- **Etapa 0 concluída pela Alanna (2026-11-17):** clone na conta dela, submódulo
  em `cv32e40p_v1.8.3`, hook ativo, filelist de síntese gerada (33 arquivos,
  clock gate da SAED32). Falta a etapa 0 do Apolônio (acesso ao repositório e
  token com o repositório novo).
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

`docs/plano-de-trabalho.md`, **etapa 1** (entender o processador: diagrama de
blocos, pipeline, interfaces OBI, interrupções; estudo E04, passos 1 e 2) e
mandar ao professor a pergunta dos atrasos de E/S com alternativas.

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
| Inserção automática de clock gating | desligada no `03` (bloco 3.0b, fonte: `man set_clock_gating_objects`); a dupla confere no E06 | ADR-009, E06 |
| Atrasos de E/S do SDC | premissa em estudo; perguntar ao professor com alternativas | ADR-007, E04 |
| Violações elétricas na síntese | perguntar ao professor onde termina a síntese lógica | E03 |
| Margens (derate, incerteza) | medir e perguntar ao professor | ADR-008, E08 |
| TIEH/TIEL liberadas no `03` | levar como pergunta ao professor | ADR-010 |
| Potência relatada só no tt | pedir a exceção ao professor ou relatar nos três corners | ADR-006 |
| Relatórios e logs no Git | decidir se as rodadas oficiais entram (permitido pelo professor) | ADR-015 |
| Restrições da árvore de clock | estudar antes do `07` | E09 |
| Antena, densidade, LVS, pinos de alimentação | estudar antes do `08` | E10 |

## Perguntas a levar ao professor (com dados e alternativas)

1. Atrasos de E/S: que ambiente supor para a memória e o barramento (E04).
2. Onde termina a síntese lógica diante das violações elétricas (E03).
3. Margens adequadas para síntese e sign-off (E08).
4. Liberar TIEH/TIEL na síntese (ADR-010).
5. Potência só no tt ou nos três corners (ADR-006).

## Repositório

- Este repositório começou em 2026-11-14, limpo. Por enquanto é privado; vai
  ser público (portfólio), com o acordo do professor e dos dois autores.
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
