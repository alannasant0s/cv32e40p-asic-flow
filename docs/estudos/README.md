# Estudos de decisão

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

Cada decisão de projeto tem um estudo aqui, feito por nós (regras em
`docs/metodo-de-trabalho.md`). Todo estudo serve a um requisito do projeto
(`docs/requisitos-professor.md`) e não pode contradizê-lo. Um estudo só fica
**concluído** quando:

- o experimento foi rodado por nós, bloco a bloco, com a saída anotada;
- cada um de nós consegue explicar a conclusão sem ler o texto;
- a decisão foi registrada em `docs/decisions.md`;
- se a decisão é avançada (método, seção 3), o professor respondeu.

Regra de todo experimento: **uma variável por vez**. De preferência, a mesma
netlist, mudando só a análise.

## Lista

| Estudo | Pergunta | Nível | Quando fazer |
|---|---|---|---|
| [E01](E01-corners.md) | Quais corners (tensão e temperatura) usar? | júnior | antes da síntese (etapa 3 do plano) |
| [E02](E02-ler-report-qor.md) | Como ler o `report_qor` em vários corners? | júnior | depois do 03 |
| [E03](E03-drv-sintese.md) | Por que a síntese pode terminar com violações elétricas, e onde elas devem ser corrigidas? | avançada (pergunta ao professor) | depois do 03 |
| [E04](E04-orcamento-es.md) | Os atrasos de entrada e saída do SDC estão certos para 8 ns? | avançada (pergunta ao professor) | entender as interfaces cedo; medir depois do 03 |
| [E05](E05-or2x1.md) | Se o DRC acusar erros concentrados numa célula, como investigar e tratar sem proibir a célula no projeto inteiro? | avançada (pergunta ao professor) | só se acontecer no roteamento (08) |
| [E06](E06-clock-gating.md) | A síntese deve inserir clock gating sozinha? | júnior para cumprir a decisão registrada; avançada para mudá-la | depois do 03 |
| [E07](E07-hold-sintese.md) | Por que o hold pode ser negativo na síntese? | júnior | depois do 03 e de novo depois do 07 |
| [E08](E08-margens.md) | As margens (derate, incerteza, ambiente) são justificadas? Quanto pesam? | avançada (pergunta ao professor) | depois do 03 |
| [E09](E09-cts.md) | Que restrições a árvore de clock precisa ter? | avançada (pergunta ao professor) | **antes do 07** |
| [E10](E10-signoff-fisico.md) | O que falta para o sign-off físico (antena, densidade, LVS, pinos de PG)? | avançada (pergunta ao professor) | **antes do 08** |

## Modelo

```markdown
# Exx — <título>

**Pergunta:** <uma frase>
**Nível:** júnior | avançada
**Situação:** aberto | em experimento | concluído (decisão em docs/decisions.md)

## Por que este estudo existe
<a motivação técnica>

## O que precisamos saber
<conceitos, com as nossas palavras>

## Fonte primária
<documento, página, tabela; ou comando man>

## Experimento (rodado por nós)
<passo a passo com os comandos e o que anotar>

## Resultado anotado
| Rodada | Quem rodou | Número | Observação |

## Conclusão
<o que a evidência mostra>

## Decisão
<tema em docs/decisions.md; se avançada, a resposta do professor>
```

## Provas de estudo

- [Etapa 1 — Conhecer o processador](etapa1-prova.md): leitura resumida do manual do CV32E40P e questões (pipeline, portas, OBI, interrupções, clock gating, atrasos de E/S do SDC).
