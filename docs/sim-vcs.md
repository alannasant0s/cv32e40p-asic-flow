# Etapa de simulação RTL (VCS)

## Objetivo

Confirmar que o RTL do CV32E40P (submódulo `third_party/cv32e40p`, tag `cv32e40p_v1.8.3`), compilado com o testbench de exemplo do OpenHW, executa um programa simples corretamente, antes de qualquer síntese ou biblioteca entrarem no fluxo.

Critério de aprovação: o programa imprime "Hello World" e termina com `EXIT SUCCESS`.

## Como rodar

Da raiz do repositório:

```bash
source /Tools/synopsys-scripts/snps.sh
make -C tool_data/vcs compile                                 # gera tool_data/vcs/simv
make -C tool_data/vcs run FIRMWARE=../../verif/sw/hello.hex   # executa e imprime o log
```

`FIRMWARE` é relativo ao diretório onde o `make` roda de fato (`tool_data/vcs`, por causa do `-C`), não à raiz do repositório.

O `make -C tool_data/vcs compile` gera de novo a `tool_data/vcs/flist_rtl.f` na versão de simulação. Antes de sintetizar, rode `scripts/gen_filelist.sh --synthesis` outra vez.

## Forma de onda (Verdi)

Opcional para esta etapa (o critério de aprovação é o "Hello World" com `EXIT SUCCESS`), mas útil para apresentação e para depuração. São dois passos separados: gerar o banco de dados não precisa de sessão gráfica, só abrir o Verdi precisa.

```bash
make -C tool_data/vcs wave FIRMWARE=../../verif/sw/hello.hex   # roda em modo batch, gera tool_data/vcs/wave.fsdb
make -C tool_data/vcs verdi                                    # abre o Verdi com a forma de onda (precisa de sessão gráfica)
```

A geração roda via `tool_data/vcs/dump.tcl`, um script UCLI (interface de linha de comando do VCS para controlar a simulação) que pede o dump de fora, sem tocar no testbench do OpenHW, que é somente leitura (regra 2 do `AGENTS.md`). No Verdi, para ver algo interessante: procure por `tb_top/dp_ram_i` (ou hierarquia equivalente) e pelos acessos de dados em `0x1000_0000`, ou simplesmente o clock e o contador de programa (`pc`) do núcleo ao longo da simulação.

`wave.fsdb` nunca é commitado (está no `.gitignore`, regra 1 do `AGENTS.md`: saída de ferramenta, não código).

## Arquitetura do testbench (`example_tb/core`)

- `tb_top.sv`: topo da simulação; instancia o subsistema e o `dp_ram`/`mm_ram`; chama `$finish` quando o core escreve no endereço de saída.
- `cv32e40p_tb_subsystem.sv`: conecta o core (`BOOT_ADDR = 0x180`, `mtvec_addr_i = 0x0`) à memória.
- `mm_ram.sv`: roteia acessos de dados. Endereços normais vão para a RAM (`dp_ram`); endereços especiais viram periféricos simulados:
  - `0x1000_0000` (escrita): periférico de stdout. O testbench usa `print_wdata[7:0]` como o caractere a imprimir (`$write("%c", ...)`), e também mostra `OUT: '<char>'` com `+verbose`.
  - `0x2000_0004` (escrita): sinaliza fim da simulação (`exit_valid_o`/`exit_value_o`); valor 0 = sucesso.
- `dp_ram.sv`: RAM genérica, **indexada por byte** (`logic [7:0] mem [bytes]`), carregada via `$readmemh` no `tb_top.sv` a partir do arquivo passado em `+firmware=`.

## `verif/sw/hello.hex`: por que foi escrito à mão

O ambiente não tem um compilador RISC-V (`riscv32-unknown-elf-gcc`), então não dá para compilar um Hello World em C. A alternativa foi montar diretamente a codificação RV32I das instruções necessárias e gravar o `.hex` no formato que o `$readmemh` do Verilog espera (não é Intel HEX): um `@endereço` em hexadecimal seguido de bytes separados por espaço, um por posição de memória.

Programa (começa em `0x180`, o `BOOT_ADDR` do testbench):

```asm
lui  t0, 0x10000     # t0 = 0x1000_0000 (endereço de stdout)
lui  t1, 0x20000     # t1 = 0x2000_0000 (base do endereço de saída)
addi t2, x0, 'H'     # carrega cada caractere de "Hello World\n"
sw   t2, 0(t0)       # escreve no periférico de stdout
...                  # repete addi/sw para cada caractere
sw   x0, 4(t1)       # escreve 0 em 0x2000_0004 → exit(0)
jal  x0, 0           # loop infinito (não chega a executar; $finish já disparou)
```

Cada instrução foi codificada manualmente nos campos do RV32I (opcode, rd, rs1, funct3, imm) e gravada em little-endian, byte a byte, no arquivo. É um processo tedioso mas direto, e útil para entender a codificação de instruções na prática, já que normalmente o assembler/compilador faz isso.

Se houver acesso a um compilador RISC-V depois, este arquivo pode ser substituído por um hex gerado de verdade a partir de C, sem mudar nada no Makefile.

## Saída esperada

```
OUT: 'H' OUT: 'e' OUT: 'l' OUT: 'l' OUT: 'o' OUT: ' '
OUT: 'W' OUT: 'o' OUT: 'r' OUT: 'l' OUT: 'd' OUT: 10
EXIT SUCCESS
$finish called ... at simulation time 360ns
```

Não há métrica numérica nesta etapa: o resultado é binário, passou ou não passou.

## Avisos do VCS (não bloqueantes)

- `RT-NCMUCS` em `cv32e40p_load_store_unit.sv:419`: `unique case` sem `default`. É do RTL original do OpenHW, não alterado por nós. Não afeta a simulação deste teste. Aparece duas vezes no tempo 0, durante o
  reset, antes de o núcleo executar qualquer instrução.
- `AOUP` em `cv32e40p_tb_subsystem.sv:81` (2 vezes): o testbench do OpenHW passa
  os parâmetros `PULP_XPULP` e `PULP_CLUSTER`, que não existem mais no núcleo
  v1.8.3 (hoje se chamam `COREV_PULP` e `COREV_CLUSTER`). O VCS ignora os dois.
  Como usamos o PULP desligado, não muda nada.
- `IDTS` em `mm_ram.sv`, linhas 255, 256, 259 e 260 (4 vezes): o testbench usa
  variáveis do tipo `string` dentro de um `always @*`, e o VCS avisa que elas
  ficam fora da lista de sensibilidade. São só as mensagens de erro do
  testbench; não é RTL do processador.

## Resultado anotado

| Rodada (hash do git) | Quem rodou / quem conferiu | Hello World + EXIT SUCCESS? | Avisos além do RT-NCMUCS |
|---|---|---|---|
| 2026-11-18, `15f9a5c`, VCS X-2025.06-SP2 | Alanna / Alanna | sim: "Hello World", `EXIT SUCCESS`, `$finish` em 360 ns | 2 `AOUP` e 4 `IDTS`, todos do testbench (explicados acima) |

## Limitação

O critério completo da simulação RTL (`docs/flow-spec.md` seção 6) também pede o **CoreMark**, que ainda não roda: depende de um compilador RISC-V, que o ambiente não tem.
