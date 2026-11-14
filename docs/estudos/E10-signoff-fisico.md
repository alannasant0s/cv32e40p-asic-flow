# E10 — Verificações de sign-off físico

**Pergunta:** o que falta no fluxo para o layout estar realmente pronto (sign-off físico), e o que cada verificação exige?
**Nível:** avançada (pergunta ao professor sobre o que é exigido no curso)
**Situação:** aberto. **Fazer antes do 08 e do 09.**

## Por que este estudo existe

Os scripts 08 e 09 param antes de um sign-off completo:

| Verificação | Situação hoje |
|---|---|
| Regras de antena | O PDK tem arquivos de regra de antena (pasta `tech/ant/` e um runset de antena do IC Validator), mas nenhum é usado. A célula de diodo de antena está definida no `00`, mas nunca é usada. |
| Densidade de metal e preenchimento (fill) | O PDK tem runsets de densidade e de preenchimento de metal; não são usados. |
| LVS do IC Validator | Não está nos scripts. Só há o `check_lvs` da própria ferramenta, que não substitui. |
| Pinos de alimentação do bloco | O bloco não tem pinos de VDD/VSS na borda. Sem eles, o bloco não pode ser integrado nem passar no LVS como macro. |
| DRC | O critério é zero. Nenhum erro é aceito como "esperado" sem estudo. |
| GDS | O GDS sai com as células por referência; o desenho delas é juntado só na hora do DRC. O GDS final entregue precisa estar completo (conferir). |
| Queda de tensão (IR drop) | Não é analisada. |
| Células de borda | Erros de poço (NWELL) na borda do core são possíveis. Conferir no databook se a SAED32 pede alguma célula de borda ou de "tap". |

## O que precisamos saber

- **Antena:** durante a fabricação, um fio longo ligado só à porta de um
  transistor acumula carga e pode danificá-lo. A correção é quebrar o fio
  subindo de camada, ou pôr um diodo que descarrega.
- **Densidade:** a fábrica exige uma porcentagem mínima e máxima de metal por
  área; o fill completa as áreas vazias.
- **LVS:** confere se o desenho tem exatamente as ligações da netlist.

## Fonte primária

- Os runsets e arquivos de regra do PDK (sem copiar o conteúdo para
  documentos: só os nomes dos arquivos e o resultado).
- `man` dos comandos de sign-off do Fusion Compiler e do IC Validator
  (`TODO(verify)` para cada nome antes de usar).
- O que o professor exige como entrega final.

## Experimento (rodado por nós)

1. Perguntar ao professor quais verificações são exigidas na entrega.
2. Para cada uma: achar no `man` como roda, rodar numa cópia do bloco final e
   anotar o resultado.
3. Para cada erro: entender a causa antes de corrigir. Nada de aceitar erro
   como "esperado" sem estudo.

## Resultado anotado

| Verificação | Quem rodou | Resultado | Observação |
|---|---|---|---|
| | | | |

## Conclusão

(preencher)

## Decisão

(pendente; registrar em `docs/decisions.md`)
