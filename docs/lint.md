# Etapa de lint (VC SpyGlass)

## O que é

Lint é uma checagem automática do RTL. Ela procura código suspeito antes da síntese, como sinais sem uso, larguras diferentes ou latch criado sem querer. O RTL é do OpenHW e **não é alterado** (regra 2 do `AGENTS.md`). Por isso, o resultado desta etapa é um relatório com **cada tipo de aviso justificado**, e não correções no código.

## De onde vem (o que é nosso e o que é do projeto base)

- **O RTL** é do OpenHW (submódulo `third_party/cv32e40p`, tag `cv32e40p_v1.8.3`) e não é alterado.
- **O projeto base também tem lint** (`third_party/cv32e40p/tool_data/lint/`), mas feito para a ferramenta **Questa AutoCheck, da Siemens**, que não temos. O ambiente da residência só tem ferramentas Synopsys.
- **Nosso fluxo de lint é próprio.** O script `tool_data/lint/lint.tcl` foi escrito por nós para o **VC SpyGlass, da Synopsys**. Ele usa a mesma configuração da síntese: mesmos parâmetros, mesma lista de arquivos e o clock gate da SAED32. As justificativas abaixo também são nossas.

## Como rodar

Da raiz do repositório:

```bash
source /Tools/synopsys-scripts/snps.sh
scripts/gen_filelist.sh --synthesis
nohup vc_static_shell -f tool_data/lint/lint.tcl > lint.log 2>&1 &
# (se vc_static_shell não for achado, ver config/env.example.sh)
```

- Usa a lista de arquivos de **síntese** e o mesmo topo e parâmetros da síntese (`tool_data/lint/lint.tcl`).
- Leva menos de um minuto.
- O relatório sai em `runs/lint_<data>/lint.rpt`.
- O fim do log deve mostrar `### Lint terminado`.

## Resultado esperado e justificativas

Referência da nossa primeira rodada do lint (anotar pasta e hash na tabela "Resultado anotado" ao repetir): com o RTL na tag `cv32e40p_v1.8.3` e os parâmetros do projeto, a elaboração deu **2613 bits de flip-flop e 0 latches**, e os avisos foram: 0 fatal, **2 errors, 228 warnings**, 28 infos (258 no total). A coluna "Quantos" é a referência para conferir a nossa rodada: se um número for diferente, algo mudou (RTL, parâmetros, filelist ou versão da ferramenta) e precisa ser investigado antes de seguir.

| Gravidade | Tag | Quantos | Justificativa |
|---|---|---|---|
| error | ErrorAnalyzeBBox | 1 | Justificado (abaixo) |
| error | W71 | 1 | Justificado (abaixo) |
| warning | SM_PNP | 8 | **Ponto de atenção.** `unique0 case` com condições que podem se sobrepor: `controller` (5), `cs_registers` (2), `fifo` (1). O `unique0` avisa a síntese que só uma condição vale de cada vez. Se duas valessem juntas, a simulação do RTL e o circuito poderiam se comportar diferente. O código é do OpenHW, verificado, e não é alterado. Quem confirma é a simulação de portas (GLS, a simulação da netlist), comparando com a simulação do RTL. |
| warning | SM_URMI | 1 | Mesma causa do ErrorAnalyzeBBox: a instância `u_icg` usa uma célula da biblioteca (`CGLPPRX2_RVT`, porque o lint lê o RTL sem a macro de família). Esperado. |
| warning | VC_WRN_FUNC | 2 | `$unsigned()` aplicado a um sinal que já é sem sinal (`alu.sv:261`, `id_stage.sv:661`). Não muda nada. |
| warning | STARC05-2.1.4.5 | 4 | Estilo: operador lógico (`&&`, `||`) onde a regra STARC prefere bit a bit. Mesmo resultado em sinal de 1 bit. |
| warning | STARC05-2.1.5.3 | 4 | Estilo: condição com vetor (ex.: `if (vetor)`, que quer dizer "diferente de zero"). Mesmo caso do W224. |
| warning | STARC05-2.2.3.3 | 1 | `mult_operator_ex_o` atribuído duas vezes no mesmo `always` sequencial (`id_stage.sv`, linhas 1536 e 1545): um valor padrão e outro dependendo da condição, como no W415a. Não é problema. |
| warning | W224 | 4 | Estilo: expressão de vários bits onde se espera 1 bit (ex.: `if (vetor)`). O Verilog trata como "diferente de zero", que é a intenção. |
| warning | W240 | 46 | Entrada declarada e não usada. São entradas de recursos desligados pelos parâmetros ou não implementados nesta configuração: FPU/APU (`apu_*`, `fflags_*`), extensões PULP (`hwlp_*`, `p_elw_*`, `pulp_clock_en_i`), PMP e modo usuário (`u_ie_i`, `csr_restore_uret_i`), e sinais de teste (`testmode_i`, `scan_cg_en_i`). A síntese remove. |
| warning | W287b | 5 | Saídas não ligadas no `prefetch_buffer`. O próprio RTL comenta "Left unconnected on purpose": a busca de instruções nunca escreve na memória (`obi_we_o`, `obi_be_o`, `obi_wdata_o`, `obi_atop_o`) e não usa o `full_o` da FIFO. Intencional. |
| warning | W415a | 72 | Sinal atribuído mais de uma vez no mesmo `always`. Concentrado em `decoder` (33) e `cs_registers` (20). É o padrão recomendado de lógica combinacional: um valor padrão no início do bloco e outro dentro do `case`. Esse padrão evita latch. **Não é problema.** |
| warning | W486 | 8 | Deslocamento com resultado 1 bit mais largo que o destino, no deslocador da ALU (`alu.sv`, 7 casos) e no `mult.sv` (1). O bit a mais é o sinal, usado no deslocamento aritmético, e o resultado é cortado para o tamanho certo de propósito. Não é problema. |
| warning | W528 | 70 | Variável escrita e não lida. Mesmos grupos do W240: FPU/APU (`apu_*`, `fpu_*`), hardware loops PULP (`hwlp_*`), PMP (`pmp_*`) e modo usuário (`utvec_*`, `uepc_*`, `ucause_*`). A síntese remove. |
| warning | FlopEConst | 3 | Flip-flops com enable sempre 0: `hwlp_addr_q` (hardware loop PULP), `apu_flags_ex_o` (FPU) e `mult_clpx_img_ex_o` (multiplicação complexa PULP). Recursos desligados pelos parâmetros (COREV_PULP=0, FPU=0). A síntese remove. |
| info | ReportPortInfo-ML, W240, W528, RegInputOutput-ML | 28 | só informação |

### Os 2 errors

1. **ErrorAnalyzeBBox: módulo `CGLPPRX2_RVT` sem definição** (`rtl/cv32e40p_clock_gate_saed32.sv`). **Esperado.** `CGLPPRX2_<VT>` é a célula de clock gate da biblioteca SAED32 (configuração de referência em `docs/decisions.md`). Ela existe na biblioteca, não no RTL. Por isso o lint não acha o código dela e a trata como caixa-preta: só conhece as portas, sem o que tem dentro. Na síntese, a célula vem da NDM.
2. **W71: `case (csr_addr_i)` sem `default`** (`third_party/cv32e40p/rtl/cv32e40p_cs_registers.sv`, linha 920, bloco combinacional). **Não é problema real.** A falta de `default` num bloco combinacional pode criar um latch. Mas aqui:
   - antes do `case`, o RTL dá um valor padrão aos sinais (linhas 905–918, por exemplo `mie_n = mie_q;`);
   - a elaboração do lint conta **0 latches**.

   O código é do OpenHW e não é alterado. O lint indica o caso, e a contagem de latches mostra que nenhum latch foi criado. É o mesmo tipo de aviso que o VCS dá em outro arquivo (`RT-NCMUCS`, `docs/sim-vcs.md`).

### Conclusão

Todos os 17 tipos têm justificativa.

- Nenhum aviso pede mudança no RTL.
- A grande maioria vem de recursos que esta configuração desliga (FPU, extensões PULP, PMP, modo usuário) ou é questão de estilo.
- **O único ponto de atenção é o SM_PNP** (`unique0` com condições que podem se sobrepor). Fica anotado para conferir na simulação de portas (GLS).
- O lint também confirma **0 latches**.

## Resultado anotado

| Rodada (pasta e hash do git) | Quem rodou / quem conferiu | Flip-flops / latches | errors / warnings / infos | Bate com a referência? |
|---|---|---|---|---|
| | | | | |

## Pendências

- Trocar `report_lint`, que a ferramenta avisa estar obsoleto, por `report_violations`.
