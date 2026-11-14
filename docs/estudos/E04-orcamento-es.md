# E04 — Atrasos de entrada e saída do SDC

**Pergunta:** os atrasos de entrada e saída (`set_input_delay`/`set_output_delay`) do nosso SDC são uma premissa razoável para um clock de 8 ns?
**Nível:** avançada. O orçamento de E/S é o que o bloco promete a quem vai usá-lo. Levar ao professor com o estudo e com alternativas.
**Situação:** aberto

## Por que este estudo existe

Os atrasos de E/S do nosso SDC seguem as frações por interface do SDC de
exemplo do upstream, que foi escrito para outro clock (5 ns) e para uma
tecnologia que ele não informa. Esses números nunca foram justificados para
o nosso caso. Num bloco como o nosso, sem memória nem barramento de verdade
em volta, o orçamento de E/S decide boa parte do resultado: com frações
altas, os caminhos de entrada e saída podem violar mesmo que a lógica interna
feche com folga. Este estudo mede o efeito e prepara a pergunta ao professor.

## O que precisamos saber

- `set_input_delay X`: o sinal chega no pino de entrada X ns depois da borda
  do clock, porque gastou esse tempo fora do bloco. Para a lógica de dentro
  sobra, aproximadamente: `período − X − incerteza − setup do flip-flop`.
- `set_output_delay Y`: depois de sair do bloco, o sinal ainda gasta Y ns lá
  fora. Para a lógica de dentro sobra: `período − Y − incerteza − (tempo do
  flip-flop de origem soltar o dado, o clock-to-q)`.
- Hoje, com período de 8 ns e incerteza de setup de 0,3 ns (antes do CTS):

| Grupo | Fração | Atraso fora | Sobra para dentro (aprox., sem setup e sem clock-to-q) |
|---|---|---|---|
| entradas OBI (memória) | 80 % | 6,4 ns | 1,3 ns |
| saídas OBI | 60 % | 4,8 ns | 2,9 ns |
| IRQ entrada / saída | 50 % / 25 % | 4,0 / 2,0 ns | 3,7 / 5,7 ns |
| outras entradas | 10 % | 0,8 ns | 6,9 ns |
| outras saídas | 60 % | 4,8 ns | 2,9 ns |

- **Caminho direto entrada → saída** (sem passar por flip-flop): a soma dos
  dois atrasos externos tem que caber no período. Exemplo: entrada de IRQ
  (4,0 ns) até uma saída OBI (4,8 ns) dá 8,8 ns, mais que 8 ns. Se esse
  caminho existir, ele é **impossível** de fechar, qualquer que seja a
  lógica. Precisamos saber quais caminhos diretos existem.
- **Latência do clock.** Antes do CTS o clock é ideal (chega com atraso zero).
  Depois do CTS ele chega nos flip-flops com algum atraso (latência). Isso
  dá folga às entradas e tira folga das saídas. Um orçamento que fecha na
  síntese pode deixar de fechar no 07. Isso precisa entrar na conta.
- **Premissa, não verdade.** Escrever o atraso externo como fração do período
  supõe que a memória fica mais rápida quando o clock fica mais rápido. Na
  vida real, o tempo da memória é fixo. O número que usamos representa o
  resto do chip (memória, barramento), que não existe no nosso projeto. Por
  isso ele é uma **premissa declarada** (método, seção 1): precisa de
  justificativa, do efeito no slack e da aprovação do professor.

## Fonte primária

- `third_party/cv32e40p/constraints/cv32e40p_core.sdc`: comentários do autor
  sobre cada interface.
- Manual do usuário do CV32E40P, capítulo da interface OBI: o que o protocolo
  exige em cada ciclo.
- O requisito do professor, se ele definir o ambiente do bloco.

## Experimento (rodado por nós)

1. Ler o SDC do upstream e anotar por que o autor colocou 80 % nas entradas
   OBI.
2. Ler no manual do usuário como funciona a interface OBI.
3. Depois do 03, os piores caminhos de cada tipo no ss:
   `report_timing -scenarios func_ss -from [all_inputs] -max_paths 5`
   `report_timing -scenarios func_ss -to [all_outputs] -max_paths 5`
   `report_timing -scenarios func_ss -from [all_inputs] -to [all_outputs] -max_paths 5`.
   Para cada caminho: qual porta, quanto foi o atraso externo, quanto foi a
   lógica de dentro. Desenhar a linha do tempo de um caminho de cada tipo.
4. Identificar **qual saída** viola (por exemplo, um endereço que sai de
   lógica combinacional) e se há caminhos diretos entrada → saída
   (`rpt/03_timing_in2out.rpt`). Se houver, fazer a conta do item "caminho
   direto" para eles.
5. Responder: a lógica de dentro é longa demais, ou o orçamento é apertado
   demais? Ver também o que muda depois do CTS (latência).
6. Levar ao professor **uma proposta com 2 ou 3 alternativas** e o slack de
   cada uma. Exemplo: (a) manter as frações do upstream (80/60 %) e mostrar o
   que viola; (b) supor uma memória síncrona com atraso fixo X ns (justificar
   X); (c) outra fração justificada. "Qual ambiente devemos supor?"

## Resultado anotado

| Rodada | Quem rodou | entrada→reg ss / tt / ff | reg→saída ss / tt / ff | entrada→saída | Observação |
|---|---|---|---|---|---|
| | | | | | |

## Conclusão

(preencher)

## Decisão

Depende da resposta do professor. Não mudar o SDC antes disso (o SDC tem um
aviso nesse sentido). Decisão sobre o SDC em `docs/decisions.md`.
