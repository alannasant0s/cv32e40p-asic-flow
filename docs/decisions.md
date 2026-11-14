# Decisões de projeto

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

Registro das decisões que valem hoje (ADR, *architecture decision record*).
Uma entrada por decisão. Decisão nova recebe o próximo número livre.

**Os requisitos do projeto (`docs/requisitos-professor.md`) estão acima de
qualquer decisão daqui.** Uma decisão que contradiga um requisito está errada.

Campos de cada decisão:
- **Status:** `vigente`, `proposta` (aplicada, mas ainda não provada pela
  dupla), `em estudo` (aplicada provisoriamente; o estudo pode mudar),
  `pendente` (decidida, mas ainda não está nos scripts) ou `substituída por ADR-nnn`.
- **Fonte primária:** o documento que sustenta a decisão (databook, `man` da
  ferramenta, requisito do projeto). "O arquivo existe" não é fonte.
- **Estudo:** o arquivo em `docs/estudos/` com o experimento da dupla.
- **Nível:** júnior, ou avançada (só depois de perguntar ao professor; ver
  `docs/metodo-de-trabalho.md`).
- **Decidido por** e **Rascunhado com** (a ferramenta de IA que redigiu o
  texto, quando houver; ver `docs/ai-usage.md`).

---

## ADR-001: Ferramentas

- **Status:** vigente
- **Fonte primária:** requisito do projeto (só Fusion Compiler)
- **Nível:** requisito
- **Decidido por:** professor; registrado por Alanna Santos e Apolonio Neto
- **Rascunhado com:** Claude Code

| Etapa | Ferramenta |
|---|---|
| Simulação do RTL | VCS (`tool_data/vcs/`) |
| Lint | VC SpyGlass (`tool_data/lint/`) |
| Biblioteca (NDM) | Library Manager, `lm_shell` (`tool_data/fc/create_ndm.tcl`) |
| Síntese, floorplan, PG, placement, CTS, roteamento | Fusion Compiler, `fc_shell` (`tool_data/fc/`) |
| Equivalência RTL × netlist | Formality (`tool_data/fm/`) |
| DRC e LVS oficiais | IC Validator (chamado de dentro do Fusion Compiler) |
| Sign-off de timing e parasitas | PrimeTime e StarRC (previstos; ainda não estão no fluxo) |

O `lm_shell` cria a NDM; o `fc_shell` não reconhece os comandos do Library
Manager (aviso CMD-005).

---

## ADR-002: Configuração do processador

- **Status:** vigente
- **Fonte primária:** manifesto e manual do usuário do CV32E40P (OpenHW)
- **Nível:** júnior
- **Decidido por:** Alanna Santos, Apolonio Neto
- **Rascunhado com:** Claude Code

| Item | Decisão |
|---|---|
| RTL | `third_party/cv32e40p`, submódulo fixado na tag `cv32e40p_v1.8.3`, só leitura |
| Topo | `cv32e40p_top`, bloco sem pads; os pinos ficam na borda do bloco |
| Parâmetros | `COREV_PULP=0, COREV_CLUSTER=0, FPU=0, ZFINX=0, NUM_MHPMCOUNTERS=1` (RV32IMC) |
| Banco de registradores | com flip-flops (`cv32e40p_register_file_ff.sv`) |
| Clock gating do RTL | `rtl/cv32e40p_clock_gate_saed32.sv`: o wrapper `cv32e40p_clock_gate` usa a célula `CGLPPRX2_<família>` da biblioteca, protegida com `dont_touch` |
| Teste (DFT) | nenhum; `scan_cg_en_i` fixo em 0 no SDC |
| Reset | `rst_ni` assíncrono; o sincronizador fica com quem integrar o bloco |

---

## ADR-003: Família de células

- **Status:** vigente
- **Fonte primária:** requisito do projeto
- **Nível:** requisito

O fluxo completo é feito primeiro com a família **HVT** (transistor de tensão
de limiar alta: mais lento e com menos vazamento). LVT e RVT vêm depois, com o
mesmo SDC e o mesmo período, para comparar as três famílias.

---

## ADR-004: Clock de 8 ns (125 MHz)

- **Status:** vigente
- **Fonte primária:** requisito do projeto
- **Nível:** requisito

`CLK_PERIOD = 8.0` em `tool_data/fc/00_tech_setup.tcl`. O SDC não tem valor
padrão: sem o `00_tech_setup.tcl`, ele para com erro. Pela documentação da
biblioteca (frequência de referência de 300 MHz), 8 ns é um clock folgado.

---

## ADR-005: Netlist flat

- **Status:** vigente
- **Fonte primária:** requisito do projeto (flat permitido)
- **Nível:** júnior

`compile.flow.autoungroup true` (`01_init_design.tcl`, bloco 1.6). Resultado
esperado: "Hierarchical Cell Count: 1" no `report_qor`. Esse 1 é o `core_i`
(cv32e40p_core): a netlist é flat abaixo do core, e o arquivo `.v` tem 2
módulos. Nos relatórios, dizer "flat abaixo do core_i".

---

## ADR-006: Corners

- **Status:** proposta (vale nos scripts; fica vigente quando a dupla concluir o estudo E01)
- **Fonte primária:** databook da biblioteca
  (`/Tools/PDK/SAED32/EDK_Digital/doc/SAED32.28nm_Digital_Standard_Cell_Library_b100_01312012.pdf`):
  Tabela 1.6 (p. 19), corners agrupados em conjuntos de tensão; §1.3 (p. 18),
  biblioteca especificada para 1,05 V. Atributos `nom_*` de cada `.lib`.
- **Estudo:** `docs/estudos/E01-corners.md`
- **Nível:** júnior
- **Decidido por:** Alanna Santos, Apolonio Neto
- **Rascunhado com:** Claude Code

| Corner | Arquivo | Processo / tensão / temperatura | Fio (TLU+) |
|---|---|---|---|
| ss (lento) | `saed32<vt>_ss0p95v125c.db` | 0,99 / 0,95 V / 125 °C | Cmax |
| tt (típico) | `saed32<vt>_tt1p05v25c.db` | 1,00 / 1,05 V / 25 °C | nominal |
| ff (rápido) | `saed32<vt>_ff1p16vn40c.db` | 1,01 / 1,16 V / −40 °C | Cmin |
| checagem | `saed32<vt>_ss0p95vn40c.db` | 0,99 / 0,95 V / −40 °C | Cmax |

- Os três corners são do mesmo conjunto da Tabela 1.6 (o de 1,05 V). Não se
  misturam corners de conjuntos diferentes: o `ss0p75v125c`, por exemplo, é do
  conjunto "middle voltage".
- A faixa de tensão da Tabela 1.4 (0,945 a 1,061 V) não bate com o ff de
  1,16 V da Tabela 1.6; por isso o argumento é a Tabela 1.6.
- **Setup e hold são analisados e relatados nos três corners** (requisito).
  Potência: no tt. Relatar a potência só no tt é uma exceção a confirmar com o
  professor.
- O corner de checagem serve para medir a inversão de temperatura (E01,
  passo 7).

---

## ADR-007: SDC

- **Status:** em estudo (atrasos de E/S: E04; margens: E08)
- **Fonte primária:** SDC de exemplo do upstream
  (`third_party/cv32e40p/constraints/cv32e40p_core.sdc`, Solderpad 2.0)
- **Estudo:** `docs/estudos/E04-orcamento-es.md`, `docs/estudos/E08-margens.md`
- **Nível:** avançada (mudar exige pergunta ao professor)
- **Decidido por:** Alanna Santos, Apolonio Neto
- **Rascunhado com:** Claude Code

| Item | Valor hoje |
|---|---|
| Base | derivado do SDC do upstream, mantendo a atribuição |
| Atrasos de E/S | os do upstream, como fração do período: entradas OBI 80 %, saídas OBI 60 %, IRQ 50 % entrada / 25 % saída, entradas quase estáticas e demais entradas 10 %, demais saídas 60 %, `core_sleep_o` 25 %. Justificativa qualitativa: as entradas OBI chegam tarde pelo protocolo. É uma **premissa declarada** sobre o resto do chip, em estudo |
| Entradas quase estáticas | atraso de 10 %, sem `false_path` (continuam checadas) |
| Incerteza do clock | antes do CTS: setup 0,30 ns, hold 0,10 ns; depois do CTS: 0,15 / 0,05 ns (`07_cts.tcl`) |
| Ambiente | transição de entrada 0,10 ns; carga de saída 5 fF; transição do clock ideal 0,10 ns |
| Limites de transição e capacitância | os da biblioteca |
| Modo | `set_case_analysis 0` em `scan_cg_en_i` |

O SDC é lido com `source` em **cada** cenário (os atrasos de E/S valem por
cenário). Avisos TIM-010 em bits que o RTL não usa (por exemplo
`boot_addr_i[1:0]`, bits de `irq_i` fora do `IRQ_MASK`) são esperados.

---

## ADR-008: Variação no chip (OCV)

- **Status:** em estudo (E08)
- **Estudo:** `docs/estudos/E08-margens.md`
- **Nível:** avançada

Derate de ±5 % em clock e dados, nos três corners (`02_scenarios.tcl`, bloco
2.4). O E08 mede quanto pesa e leva a pergunta ao professor.

---

## ADR-009: Clock gating

- **Status:** pendente nos scripts (E06)
- **Estudo:** `docs/estudos/E06-clock-gating.md`
- **Nível:** júnior para cumprir; avançada para mudar

Só o clock gating do RTL. A inserção automática de clock gating pela síntese
deve ficar desligada; o nome da opção ainda vai ser confirmado no `man` (E06,
passo 3), e só então entra no `03_synth.tcl`.

---

## ADR-010: Células proibidas e liberadas

- **Status:** vigente (proibição); pendente (TIEH/TIEL)
- **Fonte primária:** requisito do projeto (proibir uma célula com `dont_use`
  vale para todo o design e exige estudo sólido)
- **Estudo:** `docs/estudos/E05-or2x1.md`
- **Nível:** avançada

- Nenhuma célula é proibida pela dupla. Problema de DRC concentrado numa
  célula é tratado localmente, no roteamento, depois de estudo e de pergunta
  ao professor.
- O `03_synth.tcl` libera as células de tie (TIEH/TIEL), que a biblioteca
  marca `dont_touch`: sem elas, saídas constantes ficam ligadas direto no
  VSS/VDD e aparecem como terminais soltos no `check_pg_connectivity`. Mexer
  em atributo de célula da biblioteca é decisão avançada: levar ao professor.

---

## ADR-011: Floorplan

- **Status:** proposta (conferir com a área da síntese, critério 04.2)
- **Nível:** júnior

| Item | Valor | Motivo |
|---|---|---|
| Ocupação do core | 70 % | deixa espaço para buffers do CTS, correção de hold e fios |
| Formato | quadrado (`-side_ratio {1 1}`) | bloco sem macros; encurta os fios mais longos |
| Margem core → borda | 5 µm | espaço para o anel de alimentação (`05_pg.tcl`) |
| Pinos | `place_pins -self` | distribuição automática pelas bordas |

---

## ADR-012: Organização das pastas

- **Status:** vigente
- **Nível:** júnior

Um diretório por ferramenta em `tool_data/` (`vcs`, `lint`, `fc`, `fm`), com os
scripts do fluxo numerados de `00` a `09` e rodados bloco a bloco. `scripts/`
guarda os ajudantes. As saídas ficam em `runs/<etapa>_<família>_<data>/`, uma
pasta por rodada, fora do Git. A NDM fica em `ndm_lib/`, fora do Git.

---

## ADR-013: Idioma

- **Status:** vigente
- **Nível:** júnior

Documentação, comentários e mensagens de commit em português do Brasil. Em
inglês: nomes de arquivos, identificadores, comandos, opções e nomes de
métricas. Termo técnico em inglês é explicado na primeira vez em que aparece.

---

## ADR-014: Python no servidor só com a biblioteca padrão

- **Status:** vigente
- **Nível:** júnior

Os coletores que rodam no servidor (`scripts/analysis/coleta_metricas.py`) usam
só a biblioteca padrão, compatíveis com Python 3.6 ou mais novo. Tabelas e
gráficos (pandas) rodam no Windows (`requirements-analysis.txt`).

---

## ADR-015: O que entra no Git

- **Status:** vigente
- **Fonte primária:** requisito do projeto (no GitHub só scripts, relatórios e
  logs; nunca arquivos do PDK)
- **Nível:** requisito

- Entram: scripts, documentos, SDC, o wrapper de RTL e, se a dupla decidir,
  relatórios (`.rpt`) e logs de rodadas oficiais, conferidos antes.
- Nunca entram: arquivos do PDK ou derivados (`.db .lib .ndm .tf .lef .gds
  .tluplus .spef .sdf`, runsets), saídas binárias das ferramentas, NDM, nem
  material confidencial do curso. O hook `.githooks/pre-commit` barra as
  extensões proibidas e arquivos acima de 5 MB (ative com
  `git config core.hooksPath .githooks`).
- Commits com o e-mail "noreply" do GitHub.
