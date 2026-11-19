# Erros e avisos conhecidos do fluxo

Armadilhas que podem aparecer ao rodar o fluxo (HVT, 8 ns, três corners), com
a causa e o que fazer. Os casos que os scripts já evitam estão aqui para
reconhecer a mensagem se ela aparecer.

Como procurar erros num log: `grep -n "^Error" <arquivo.log>`. No `fc_shell`,
`man <código>` (ex.: `man CMD-001`) explica qualquer mensagem.

## Ambiente e terminal

| Situação | Causa | O que fazer |
|---|---|---|
| `fc_shell: command not found` | ferramentas não carregadas neste terminal | `source /Tools/synopsys-scripts/snps.sh` (em todo terminal novo) |
| Arquivos do PDK aparecem dentro do repositório | algum script de setup copiou a biblioteca para a pasta atual | não rode scripts que copiam a biblioteca de dentro do repositório; o fluxo só precisa do caminho dela |
| `No such file` no `ndm_lib/saed32hvt_c.ndm` | a biblioteca ainda não foi gerada na sua conta | gerar com `lm_shell -x "set VT hvt" -file tool_data/fc/create_ndm.tcl -batch`. A biblioteca se gera com `lm_shell`, não com `fc_shell` |
| `Information: Interrupting current command. (INT-2)` | Ctrl+C no console | no terminal, Ctrl+C interrompe; para copiar use Ctrl+Shift+C |
| A ferramenta continua presa depois de fechar a janela do X2Go | fechar a janela não fecha o `fc_shell` | sempre `exit` no console. Para achar o que sobrou: `pgrep -u $USER -a fc_shell` e `kill <número>` |
| `client_loop: send disconnect: Connection reset` | a conexão SSH caiu; o que rodava direto no terminal pode ter morrido junto | reconecte e confira: `pgrep -u $USER -a _shell` e o fim do log (`tail -5 <arquivo.log>`). Se o log fecha com "Thank you for using...", terminou. Rode sempre dentro do `tmux` (`tmux new -s fc`; voltar com `tmux attach -t fc`) |
| `cd ~/cv32e40p-asic-flow` dá `ItemNotFoundException` | o comando foi digitado no PowerShell do Windows, antes do `ssh` | conecte primeiro (`ssh <servidor>`) e rode os comandos no prompt do servidor, não no `PS C:...>` do Windows |
| `fatal: repository not found` ou erro 403 no `push` | o token do GitHub não tem permissão de escrita no repositório novo | no GitHub, edite o token e adicione o repositório `cv32e40p-asic-flow` (o clone não precisa de token: o repositório é público) |
| `NDM-029` (biblioteca travada para edição) | outra sessão do `fc_shell` sua ainda está com a biblioteca aberta | feche a outra sessão (linha acima) e abra de novo |

## Git

| Situação | Causa | O que fazer |
|---|---|---|
| O `push` pede usuário e senha | o GitHub não aceita a senha da conta pela linha de comando | usuário = o do GitHub; senha = um token pessoal (`ghp_...`) |
| `Password authentication is not supported` | usou a senha da conta | use o token |
| `Your local changes would be overwritten` | algum arquivo do projeto foi modificado na sua pasta | `git status --short`; se for arquivo do projeto (` M`) que você não quer manter, `git restore <arquivo>` e `git pull` de novo |
| A pasta `third_party/cv32e40p` está vazia | o submódulo não foi baixado | `git submodule update --init` |

## Script 01 (biblioteca e RTL)

| Mensagem | Causa | O que fazer |
|---|---|---|
| `analyze` ou `elaborate` termina com `0` | falha na leitura do RTL | procure a primeira linha `Error:` acima dele. Confira se rodou `scripts/gen_filelist.sh --synthesis` |
| `VER-61` "Statement unreachable", `VER-318` "signed to unsigned conversion" | avisos do código do processador (OpenHW, terceiros) | normais |
| `set_top_module` devolve `0` | o link do topo falhou | procure a mensagem acima dele. O normal é `Information: User units loaded from library 'saed32hvt_c' (LNK-040)` e `1` |
| `DES-002` "Cannot find module" | o topo foi chamado pelo nome curto; depois do `elaborate` ele ganha os parâmetros no nome (`cv32e40p_top_COREV_PULP0_...`) | os scripts usam a variável `DESIGN_ELAB` com o nome completo |
| `DES-149` "cannot be auto-linked" no `02` | faltou o `set_top_module` | o bloco 1.5 faz isso; confira se ele rodou |
| Aviso TECH-025 (`Layer 'VIA1' 'onGrid' and 'onWireTrack' coexist`) no `create_lib` | vem do arquivo de tecnologia da SAED32 | esperado; não é erro |

## Script 02 (corners, cenários e constraints)

| Mensagem | Causa | O que fazer |
|---|---|---|
| `write_sdc` avisa `Multiply cell derates are skipped!` / `Multiply net derates are skipped!` | é um tipo de margem ("multiply derate") que o projeto não usa | esperado; as margens de ±5 % estão no SDC gravado (`set_timing_derate`) |
| `PVT-030` no `report_pvt` | um corner pegou a biblioteca errada (por exemplo, faltou o número de processo) | o bloco 2.4 define processo, tensão e temperatura de cada corner. O certo é `no PVT mismatches` nos três. Se aparecer, confira se o seu `02_scenarios.tcl` é o do repositório (`git status`) e se a NDM foi gerada com o `create_ndm.tcl` atual |
| `TCK-012` no `check_timing` (entrada sem atraso) | o SDC lido uma vez só vale só no cenário atual | o bloco 2.5 lê o SDC em cada cenário; confira se o laço rodou nos três |
| `TCK-001` "unconstrained ... case constant" | lógica constante: o processador está sem as extensões PULP (`COREV_PULP=0`) | normal |
| `Warning: Redefining clock 'clk_i'` | o mesmo clock é lido em cada cenário | normal |
| `UIC-061` "Implicitly setting the '-net_delay' option" | detalhe do `set_timing_derate` | normal |
| `NEX-001` / `DMM-115` sobre direção de roteamento do M1 | informação da tecnologia | normal |

## Script 03 (síntese lógica)

| Mensagem | Causa | O que fazer |
|---|---|---|
| `LGL-397` "No site rows found in floorplan" | o floorplan só é criado no `04` | normal na síntese |
| `OPT-902` "No clock routing rules", `SQM-1040` "no multibit cells" | informações da otimização | normais |
| `OPT-200` (tie cells não usadas) e saídas ligadas direto no VSS | a biblioteca marca TIEH/TIEL como `dont_touch` | o bloco 3.0 tira o `dont_touch` e o 3.2 roda o `add_tie_cells`. Confira a linha `Tie cells: TIEL=...` no log |
| `VW-007` no `write_verilog` | nomes de fios ajustados na netlist | normal |
| `SVF file is corrupt` ao reabrir | a sessão anterior caiu no meio da escrita do SVF | **não** comece um SVF novo: o Formality precisa do registro inteiro, desde o 01. Refaça a rodada a partir do 01, numa pasta nova |

## Relatórios

| Situação | Causa | O que fazer |
|---|---|---|
| Avisos UIC-061 ("Implicitly setting the '-net_delay' / '-cell_delay' option for the set_timing_derate") no 02 | o `set_timing_derate` sem `-cell_delay`/`-net_delay` vale para os dois | esperado; não é erro (margens: estudo E08) |

| Situação | Causa | O que fazer |
|---|---|---|
| `report_constraint` mostra `max_delay/setup 0.00 (MET)` | sem `-scenarios`, ele mostra só o cenário atual | use `report_constraint -scenarios [all_scenarios]` |
| `CMD-001` "Cannot specify '-summary' with '-scenarios'" | o `report_qor -summary` não aceita `-scenarios` | use só `report_qor -summary` (ele já mostra os três corners) |
| `UIC-058` "Scenario ... is not configured for setup/hold analysis: skipping" | o cenário não analisa aquilo | os três cenários analisam setup e hold (bloco 2.6); se aparecer, confira o `02_scenarios.tcl` |
| `POW-046` / `POW-069` no `report_power` | estimativa de atividade sem simulação | normais |
| Slack muito negativo no bloco 3.1 | o 3.1 só traduz o RTL em células, sem otimizar | normal antes da otimização; compare com o 3.2 |
| Violações de regra elétrica (max_transition, max_capacitance) no fim da síntese | a síntese para antes das etapas físicas | por que e onde se corrigem: estudo E03 |

## Formality

| Mensagem | Causa | O que fazer |
|---|---|---|
| `FMR_ELAB-116` "unique case but some items may overlap", `FMR_VLOG-063` "Signed to unsigned assignment" | avisos do RTL do OpenHW (fifo, controller, ALU) | esperados; por causa deles o `status.rpt` avisa que o resultado "pode discordar de um simulador" |
| `1(0) Unmatched reference(implementation) compare points` com `aligner_ready_q_reg` | registrador do RTL que não aparece na netlist | se a verificação passa, a lógica ficou equivalente sem ele. Na rodada `pnr_hvt_20261117-170523`, o `report_transformed_registers` mostra `aligner_ready_q_reg` como `ulr` (registrador sem carga, removido pela síntese) |
| `breakpoint` "Unprocessed" no Guidance Summary | dicas do SVF que o Formality não precisou usar | o próprio Formality diz que podem ser ignoradas quando a verificação passa |

## Netlist

| Situação | Causa | O que fazer |
|---|---|---|
| `grep -c " OR2X1_HVT "` dá 0 mesmo com a célula presente | na netlist do Fusion Compiler, as instâncias começam no início da linha | use `grep -c "^ *OR2X1_HVT " <netlist>.v` |

## Se for um erro que não está aqui

1. Leia a mensagem inteira e o código entre parênteses; rode `man <código>` no `fc_shell`.
2. Se for usar uma IA para ajudar: anexe o `AGENTS.md`, cole o comando e as
   linhas de erro (`grep -n "^Error" <log>`, `tail -40 <log>`) e diga o bloco
   (ex.: "bloco 3.2").
3. Peça para a IA não inventar comandos; confira opções novas com `man <comando>`.
4. Não cole na IA conteúdo de arquivos da biblioteca ou da PDK (`.lib`, `.lef`, `.tf`, runsets).
5. Anote o erro, a causa e a correção, e acrescente aqui.
