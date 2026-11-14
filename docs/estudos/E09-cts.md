# E09 — Restrições da árvore de clock (CTS)

**Pergunta:** que restrições a árvore de clock precisa ter antes de rodar o `07_cts.tcl`?
**Nível:** avançada (pergunta ao professor, com o estudo)
**Situação:** aberto. **Fazer antes do 07.**

## Por que este estudo existe

O `07_cts.tcl` roda o `clock_opt` **sem nenhuma restrição** de árvore:

- não há alvo de skew;
- não há limite de transição no clock. A biblioteca HVT não tem um limite
  padrão de transição; cada pino tem o seu (da ordem de 1 ns), o que é largo
  demais para um clock;
- não há regra de fio própria para o clock (NDR: fio mais largo ou com mais
  espaço, que deixa o clock menos sensível a ruído);
- não há lista de células permitidas na árvore (só buffers e inversores de
  clock);
- o clock gate do RTL está `dont_touch`, então o CTS não pode trocar o tamanho
  dele, mesmo alimentando boa parte do processador.

Sem essas restrições, a ferramenta pode construir uma árvore com skew alto
demais para um clock de 8 ns, e o hold e o setup pioram depois do CTS. Este
estudo define, com fonte, as restrições e os valores a propor ao professor.

## O que precisamos saber

- **Skew:** diferença de chegada do clock entre flip-flops. **Global** é entre
  o mais cedo e o mais tarde do chip inteiro; **local** é entre flip-flops que
  conversam entre si. O que importa para o timing é o local. O
  `report_clock_qor` mostra qual? (ler o `man`).
- **Latência:** quanto o clock demora do pino até os flip-flops. Afeta os
  caminhos de entrada e saída (estudo E04).
- **Transição do clock:** borda lenta piora o setup/hold dos flip-flops e o
  consumo.

## Fonte primária

- `man clock_opt`, `man report_clock_qor` e a documentação de CTS do Fusion
  Compiler: nomes dos comandos de alvo de skew, transição máxima no clock,
  NDR e células de CTS (`TODO(verify)` para cada nome antes de usar).
- O requisito do professor.

## Experimento (rodado por nós)

1. Ler no `man` como se definem: alvo de skew, transição máxima no clock,
   células da árvore e NDR. Anotar os nomes exatos.
2. Rodar o 07 como está (numa cópia do bloco) e anotar: skew global e local,
   latência, transição máxima no clock, número e tipos de buffers, área.
3. Propor ao professor valores para cada restrição, com o resultado do passo 2
   e a justificativa.
4. Depois da resposta: aplicar no 07 e rodar de novo; comparar.

## Resultado anotado

| Rodada | Quem rodou | Skew global / local | Latência | Transição máx. no clock | Buffers | Observação |
|---|---|---|---|---|---|---|
| | | | | | | |

## Conclusão

(preencher)

## Decisão

(pendente; registrar em `docs/decisions.md`)
