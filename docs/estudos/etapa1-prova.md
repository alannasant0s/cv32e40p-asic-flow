# Etapa 1 — Conhecer o processador CV32E40P

**Prova de estudo** · Projeto CV32E40P na SAED32 · Residência CI Expert, polo UFCG

Nome: ______________________________________ Data: ____/____/______

Conferido por (dupla): ______________________________________

---

**Como usar.** Cada parte tem um texto de leitura, resumido do manual do
usuário do CV32E40P (OpenHW Group, em `third_party/cv32e40p/docs/source/`),
e questões. Responda com as suas palavras. Quando a questão pede a fonte,
escreva o arquivo e a seção onde achou. Na dúvida, abra o capítulo original:
o resumo ajuda, mas a fonte é o manual.

Objetivo: no fim, conseguir explicar o processador em 5 minutos e entender de
onde vêm os atrasos de entrada e saída do nosso SDC (estudo E04).

---

## Parte 1 — O que é o CV32E40P

### Leitura

**Fonte:** `intro.rst` e `integration.rst`.

- O CV32E40P é um processador **RISC-V de 32 bits**, com **pipeline de 4 estágios**, que executa as instruções **em ordem**.
- Conjunto de instruções base: **RV32I**. Extensões sempre ligadas: **C** (instruções comprimidas, de 16 bits), **M** (multiplicação e divisão), **Zicsr** (registradores de controle), **Zicntr** (contadores) e **Zifencei**.
- Extensões opcionais, controladas por parâmetros: **F** (ponto flutuante, parâmetro `FPU`), **Zfinx** (`ZFINX`), extensões próprias da PULP (`COREV_PULP`) e suporte a cluster (`COREV_CLUSTER`).
- O módulo do topo é o `cv32e40p_top`. Ele instancia o `cv32e40p_core` (o processador) e, se `FPU = 1`, a unidade de ponto flutuante.
- **Nossa configuração** (`tool_data/fc/00_tech_setup.tcl`, variável `PARAMS`): `COREV_PULP=0, COREV_CLUSTER=0, FPU=0, ZFINX=0, NUM_MHPMCOUNTERS=1`. Ou seja: **RV32IMC**, sem ponto flutuante, sem extensões PULP, com 1 contador de desempenho.
- O processador é descrito como "totalmente sintetizável", pensado principalmente para ASIC.
- As interfaces de busca de instrução e de dados seguem o protocolo **OBI** (*Open Bus Interface*).

### Questões

**1.1** Quantos estágios tem o pipeline? As instruções terminam em ordem ou
fora de ordem?

_______________________________________________________________________________

**1.2** O que quer dizer "RV32IMC"? Explique cada letra.

_______________________________________________________________________________

_______________________________________________________________________________

**1.3** Marque V (verdadeiro) ou F (falso) para a nossa configuração:

- ( ) O processador tem unidade de ponto flutuante.
- ( ) As instruções comprimidas (16 bits) são aceitas.
- ( ) As extensões PULP (ex.: laços em hardware) estão ligadas.
- ( ) O módulo que sintetizamos é o `cv32e40p_top`.

**1.4** Por que o manual recomenda usar o `cv32e40p_top` em vez do
`cv32e40p_core` como módulo de topo?

_______________________________________________________________________________

_______________________________________________________________________________

**1.5** Escreva, com as suas palavras, em 3 linhas, o que é o CV32E40P (como
você explicaria ao professor).

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

---

## Parte 2 — O pipeline

### Leitura

**Fonte:** `pipeline.rst` e a figura `docs/img/cv32e40p_pipeline.png`.

| Estágio | O que faz |
|---|---|
| **IF** (*Instruction Fetch*, busca) | Busca instruções na memória por um *prefetch buffer* (guarda até 2 palavras de 32 bits). Consegue entregar 1 instrução por ciclo, se a memória permitir. Também pré-decodifica as instruções comprimidas (C) em instruções RV32I. |
| **ID** (*Instruction Decode*, decodificação) | Decodifica a instrução e lê o banco de registradores. Os **saltos** (*jumps*) são feitos aqui. |
| **EX** (*Execute*, execução) | ALU, multiplicador e divisor. Os **desvios** (*branches*) com condição verdadeira são tomados aqui. A ALU, o multiplicador e o divisor escrevem o resultado no banco de registradores já neste estágio. A geração de endereço da unidade de load/store também fica aqui. Instruções de vários ciclos seguram este estágio até terminar. |
| **WB** (*Writeback*, escrita) | Escreve no banco de registradores o resultado das instruções de **load** (leitura da memória). |

- **Encaminhamento (*forwarding*):** o resultado da ALU, do multiplicador e do divisor volta direto do EX para o ID, então a instrução seguinte pode usar o resultado sem esperar (0 ciclo de penalidade).
- **Penalidade de 1 ciclo** quando: a instrução logo depois de um load usa o resultado do load; ou um `jalr` depende do resultado da instrução anterior.
- Ciclos por tipo de instrução (sem espera de memória): operações inteiras 1; `mul` 1; `mulh`/`mulhsu`/`mulhu` 5; divisão e resto de 3 a 35 (depende do divisor); load/store 1 (2 se o acesso for desalinhado); salto 2.

### Questões

**2.1** Complete a tabela:

| Estágio | Nome por extenso | Uma coisa que acontece nele |
|---|---|---|
| IF | | |
| ID | | |
| EX | | |
| WB | | |

**2.2** Em que estágio os *saltos* são feitos? E os *desvios* com condição
verdadeira?

_______________________________________________________________________________

**2.3** O que é *forwarding* e qual problema ele evita?

_______________________________________________________________________________

_______________________________________________________________________________

**2.4** Por que uma instrução que usa o resultado de um load logo em seguida
perde 1 ciclo? (Pense em qual estágio o load escreve o resultado.)

_______________________________________________________________________________

_______________________________________________________________________________

**2.5** Uma divisão pode levar até 35 ciclos. Isso significa que o caminho
lógico do divisor precisa caber em 35 ciclos de clock? Justifique.
(Dica: o divisor é sequencial; cada ciclo faz uma parte.)

_______________________________________________________________________________

_______________________________________________________________________________

---

## Parte 3 — As portas do bloco

### Leitura

**Fonte:** `integration.rst`, seções "Instantiation Template" e "Interfaces".

| Grupo | Portas | Direção |
|---|---|---|
| Clock e reset | `clk_i`, `rst_ni` (reset assíncrono, ativo em 0), `scan_cg_en_i` (teste: força os clock gates ligados; deve ser 0 em operação normal) | entrada |
| Controle | `fetch_enable_i` (libera a primeira busca depois do reset), `pulp_clock_en_i` (só usado com `COREV_CLUSTER = 1`; ligar em 0) | entrada |
| | `core_sleep_o` (o processador está dormindo) | saída |
| Configuração | `boot_addr_i`, `mtvec_addr_i`, `dm_halt_addr_i`, `dm_exception_addr_i`, `hart_id_i` (32 bits cada). O manual diz: **"não mudar depois de liberar o processador com `fetch_enable_i`"** | entrada |
| Memória de instrução (OBI) | `instr_addr_o`, `instr_req_o` | saída |
| | `instr_gnt_i`, `instr_rvalid_i`, `instr_rdata_i` | entrada |
| Memória de dados (OBI) | `data_addr_o`, `data_req_o`, `data_we_o`, `data_be_o`, `data_wdata_o` | saída |
| | `data_gnt_i`, `data_rvalid_i`, `data_rdata_i` | entrada |
| Interrupções | `irq_i[31:0]` | entrada |
| | `irq_ack_o`, `irq_id_o[4:0]` | saída |
| Debug | `debug_req_i` | entrada |
| | `debug_havereset_o`, `debug_running_o`, `debug_halted_o` | saída |

- **Célula de clock gating:** o processador precisa de uma célula de clock gating. O manual explica que ela depende da tecnologia e por isso não vem no RTL; o arquivo `cv32e40p_sim_clock_gate.sv` serve **só para simulação**. Para síntese, cada projeto troca por um módulo `cv32e40p_clock_gate` feito com uma célula da biblioteca. No nosso projeto, é o `rtl/cv32e40p_clock_gate_saed32.sv`, com a célula `CGLPPRX2_HVT`.

### Questões

**3.1** Liste as entradas que o manual diz que **não podem mudar** depois que
o processador é liberado. Por que isso importa para o timing? (Pense: se o
sinal não muda, ele precisa chegar rápido?)

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

**3.2** O `rst_ni` é ativo em 0 ou em 1? É síncrono ou assíncrono?

_______________________________________________________________________________

**3.3** Que valor o `scan_cg_en_i` deve ter em operação normal? Onde, no nosso
SDC, isso aparece? (Procure em `constraints/cv32e40p_baseline.sdc`.)

_______________________________________________________________________________

**3.4** Por que o arquivo `cv32e40p_sim_clock_gate.sv` não pode ir para a
síntese? O que colocamos no lugar dele, e onde isso acontece? (Dica: veja o
`scripts/gen_filelist.sh`.)

_______________________________________________________________________________

_______________________________________________________________________________

**3.5** Conte: quantas portas de **saída** o bloco tem nos dois barramentos OBI
juntos (só os nomes, sem contar bits)?

_______________________________________________________________________________

---

## Parte 4 — A interface OBI (memória de instrução e de dados)

### Leitura

**Fonte:** `instruction_fetch.rst` e `load_store_unit.rst`, seção "Protocol".

Como funciona uma transação, nos dois barramentos:

1. **Fase de endereço.** O processador põe o endereço (`*_addr_o`) e, nos dados, as informações de controle (`data_we_o`: escrita ou leitura; `data_be_o`: quais bytes; `data_wdata_o`: o dado, se for escrita) e sobe o pedido (`*_req_o = 1`).
2. A memória responde com o **aceite** (`*_gnt_i = 1`) quando estiver pronta. Pode acontecer a qualquer momento, até antes do pedido. O pedido fica em 1 até o aceite. Depois do aceite, o processador pode mudar o endereço já no ciclo seguinte.
3. **Fase de resposta.** Um ou mais ciclos depois do aceite, a memória sobe o **dado válido** (`*_rvalid_i = 1`) por **exatamente 1 ciclo** por pedido. Numa leitura, `*_rdata_i` traz o dado nesse ciclo. Numa escrita, o `data_rvalid_i` também sobe, só para marcar o fim.
4. As respostas voltam **na mesma ordem** dos pedidos.

Outros pontos:

- Instrução: só leitura, sempre alinhada em palavra (32 bits). O *prefetch* pode ter até 2 pedidos pendentes.
- Dados: leitura e escrita de palavra, meia palavra e byte. Até **2 pedidos pendentes**. Acesso desalinhado vira **duas** transações.
- **Comentário do autor do SDC de exemplo** (`constraints/cv32e40p_core.sdc` do upstream): *"OBI related bus inputs arrive late on purpose and OBI related outputs are available earlier (as they shall not combinatorially depend on the OBI inputs)"*. Em português: as entradas OBI chegam **tarde** de propósito, e as saídas OBI ficam prontas **mais cedo**, porque elas **não podem depender combinacionalmente** das entradas OBI.

### Questões

**4.1** Coloque na ordem certa (1 a 4):

- ( ) a memória sobe `data_rvalid_i` por um ciclo
- ( ) o processador põe `data_addr_o` e sobe `data_req_o`
- ( ) a memória sobe `data_gnt_i`
- ( ) o processador pode trocar `data_addr_o` para o próximo pedido

**4.2** Qual a diferença entre `*_gnt_i` e `*_rvalid_i`?

_______________________________________________________________________________

_______________________________________________________________________________

**4.3** Numa **escrita**, a memória também sobe `data_rvalid_i`? Para quê?

_______________________________________________________________________________

**4.4** Quantos pedidos podem ficar pendentes na interface de dados? E na de
instrução?

_______________________________________________________________________________

**4.5** O que quer dizer "as saídas OBI não podem depender combinacionalmente
das entradas OBI"? Dê um exemplo do que seria um caminho combinacional
proibido (de qual porta para qual porta).

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

**4.6** Se o `data_rdata_i` chega "tarde" no ciclo, o que acontece com o tempo
que sobra para a lógica **dentro** do processador antes do flip-flop que
recebe esse dado? Isso é bom ou ruim para fechar o timing?

_______________________________________________________________________________

_______________________________________________________________________________

---

## Parte 5 — Interrupções

### Leitura

**Fonte:** `exceptions_interrupts.rst`, seção "Interrupt Interface".

- `irq_i[31:0]`: 32 entradas de interrupção, sensíveis a **nível** e ativas em 1.
- **Nem todos os bits são usados.** `irq_i[15:12]`, `irq_i[10:8]`, `irq_i[6:4]` e `irq_i[2:0]` são **reservados** e devem ser ligados em 0 fora do processador.
- `irq_i[11]` = interrupção externa da máquina (MEI); `irq_i[7]` = do timer (MTI); `irq_i[3]` = de software (MSI). `irq_i[31:16]` são uma extensão própria do CV32E40P.
- `irq_ack_o` sobe por 1 ciclo quando uma interrupção é atendida, e `irq_id_o[4:0]` diz qual foi.
- Depois do reset, todas as interrupções começam desligadas.
- No RTL, o parâmetro `IRQ_MASK` (`cv32e40p_pkg.sv`) marca quais bits o processador usa. Os bits reservados não chegam a nenhum flip-flop.

### Questões

**5.1** Quais bits de `irq_i` são reservados (não usados)?

_______________________________________________________________________________

**5.2** Na síntese, a ferramenta avisa (TIM-010) que vários bits de `irq_i`
"não são ponto de partida de timing". Explique por que isso acontece e por
que **não** é um erro.

_______________________________________________________________________________

_______________________________________________________________________________

**5.3** O mesmo aviso aparece para `boot_addr_i[1:0]`. Por quê? (Dica: o
endereço de boot precisa ser alinhado em meia palavra; veja como o
`cv32e40p_if_stage.sv` usa o `boot_addr_i`.)

_______________________________________________________________________________

_______________________________________________________________________________

---

## Parte 6 — O clock gating do processador

### Leitura

**Fonte:** `sleep.rst`.

- A **unidade de sono** (`cv32e40p_sleep_unit.sv`) contém o clock gate do processador. Ela é o **único** lugar que usa o `clk_i` direto; todos os outros módulos usam o clock que passa pelo clock gate.
- Com `COREV_CLUSTER = 0` (nosso caso), o clock é cortado quando o processador executa a instrução **`wfi`** (*wait for interrupt*: esperar uma interrupção). Aí `core_sleep_o = 1`.
- No nosso projeto, a síntese **não** pode inserir clock gates por conta própria (decisão "Clock gating" em `docs/decisions.md`; bloco 3.0b do `03_synth.tcl`). Fica só este, do RTL.

### Questões

**6.1** Para que serve o clock gate da unidade de sono? Quando ele corta o
clock?

_______________________________________________________________________________

_______________________________________________________________________________

**6.2** Se a síntese inserisse clock gates por conta própria, o que mudaria na
árvore de clock (CTS)? Por que isso é uma decisão, e não um detalhe?

_______________________________________________________________________________

_______________________________________________________________________________

---

## Parte 7 — Os atrasos de entrada e saída do nosso SDC (base do estudo E04)

### Leitura

**Fonte:** `constraints/cv32e40p_baseline.sdc` (nosso) e `third_party/cv32e40p/constraints/cv32e40p_core.sdc` (exemplo do upstream).

- O SDC de exemplo foi escrito para um clock de **5 ns** (200 MHz), numa tecnologia que ele não informa. O próprio autor escreve que o período e os atrasos "dependem da tecnologia e do projeto e devem ser ajustados".
- Nós copiamos as **frações** do período. Com o nosso clock de **8 ns**:

| Grupo de portas | Fração | Atraso fora do bloco |
|---|---|---|
| Entradas OBI (`*_gnt_i`, `*_rvalid_i`, `*_rdata_i`) | 80 % | 6,4 ns |
| Saídas OBI (`*_req_o`, `*_addr_o`, `data_we_o`, `data_be_o`, `data_wdata_o`) | 60 % | 4,8 ns |
| Entrada de interrupção (`irq_i`) | 50 % | 4,0 ns |
| Saídas de interrupção (`irq_ack_o`, `irq_id_o`) | 25 % | 2,0 ns |
| Entradas "adiantadas" (`debug_req_i` e as de configuração) | 10 % | 0,8 ns |
| Outras entradas | 10 % | 0,8 ns |
| Outras saídas | 60 % | 4,8 ns |
| `core_sleep_o` | 25 % | 2,0 ns |

- Incerteza do clock antes da árvore de clock: 0,30 ns (setup).
- `set_input_delay X` quer dizer: o sinal chega na porta **X ns depois da borda do clock**, porque gastou esse tempo fora do bloco. Sobra para a lógica de dentro, mais ou menos: **período − X − incerteza − setup do flip-flop**.
- `set_output_delay Y` quer dizer: depois de sair do bloco, o sinal ainda gasta **Y ns lá fora**. Sobra para a lógica de dentro: **período − Y − incerteza − tempo do flip-flop soltar o dado**.

### Questões

**7.1** Calcule quanto sobra (aproximadamente, sem o setup do flip-flop) para
a lógica dentro do bloco:

| Caso | Conta | Resultado |
|---|---|---|
| Entrada OBI até um flip-flop | 8 − 6,4 − 0,3 = | |
| Flip-flop até uma saída OBI | 8 − 4,8 − 0,3 = | |
| Entrada de configuração até um flip-flop | 8 − 0,8 − 0,3 = | |

**7.2** Por que faz sentido as entradas de configuração (`boot_addr_i` etc.)
terem um atraso tão pequeno (10 %)? Relacione com a Parte 3.

_______________________________________________________________________________

_______________________________________________________________________________

**7.3** Um caminho **direto** de entrada para saída (sem passar por
flip-flop) precisa que os dois atrasos de fora somados caibam no período.
Faça a conta para uma entrada de interrupção (4,0 ns) chegando
combinacionalmente numa saída OBI (4,8 ns). O que você conclui?

_______________________________________________________________________________

_______________________________________________________________________________

**7.4** O SDC de exemplo escreve o atraso de fora como **fração do período**.
Se o nosso clock ficasse mais rápido (período menor), o atraso da memória lá
fora também diminuiria? Isso é realista? Explique.

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

**7.5** Por que esses atrasos são chamados de **premissa** no nosso projeto, e
não de um valor "confirmado"? Quem precisa aprovar uma premissa dessas?
(Veja `docs/metodo-de-trabalho.md`, seção 1, e `docs/decisions.md`, decisão
"SDC".)

_______________________________________________________________________________

_______________________________________________________________________________

**7.6** Proponha **duas alternativas** de atraso para as entradas OBI, diferentes
de 80 %, e diga, para cada uma, uma vantagem e uma desvantagem. (Essas
alternativas vão para a pergunta ao professor.)

Alternativa A: ________________________________________________________________

Vantagem: _____________________________ Desvantagem: __________________________

Alternativa B: ________________________________________________________________

Vantagem: _____________________________ Desvantagem: __________________________

---

## Parte 8 — Síntese da etapa

**8.1** Explique o processador em 5 frases: o que é, os estágios, as
interfaces com a memória, as interrupções e o clock gating.

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

**8.2** Escreva a pergunta que vamos levar ao professor sobre os atrasos de
entrada e saída, já com as alternativas da questão 7.6.

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

**8.3** O que ainda não ficou claro para você (leve para a dupla e para a IA)?

_______________________________________________________________________________

_______________________________________________________________________________
