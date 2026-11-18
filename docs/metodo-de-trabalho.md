# Método de trabalho

Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
polo UFCG (trilha de Physical Design), 2026.

Somos uma dupla júnior aprendendo projeto físico. O objetivo do projeto é
**aprender cada decisão**, não só chegar ao GDS. Cada valor que entra no
fluxo precisa ter uma fonte, cada decisão precisa de um estudo, e cada etapa
só termina quando passa nos critérios de aceite e nós dois sabemos explicar o
que foi feito. As regras abaixo valem para nós dois e para qualquer IA que
ajude no projeto.

## 1. Nada é "confirmado" sem fonte primária

- **Fonte primária** é o documento que define o valor: o databook da
  biblioteca, o `.lib` (só para ler um atributo, sem copiar o conteúdo), o
  manual da ferramenta (`man <comando>` no `fc_shell`) ou o requisito do
  professor.
- **Saber que um arquivo existe não confirma nada.** A pasta da biblioteca tem
  arquivos de corners de três conjuntos de tensão; todos existem, e só o
  databook diz qual conjunto usar (estudo E01).
- Todo valor de projeto (tensão, temperatura, período, atraso de E/S, limite,
  margem) tem, no comentário do script ou em `docs/decisions.md`: **de onde
  veio** (documento, página, tabela) e **quem conferiu**.
- Se não houver fonte, escrevemos `TODO(verify): <o quê e onde checar>` e o
  valor não vai para o professor como fato.
- **Premissa declarada** é a terceira categoria: um valor que nenhum documento
  pode dar, porque descreve algo que não existe no nosso projeto (por
  exemplo, o atraso da memória fora do bloco, estudo E04). Ela vale quando
  tem: justificativa escrita, o efeito dela no slack medido, e a aprovação do
  professor. Sempre aparece como "premissa" nos relatórios.
- Fonte primária também pode ter erro (o databook tem uma faixa de tensão que
  não bate com os próprios corners, estudo E01). Quando duas fontes
  discordam, anotamos as duas e dizemos qual usamos e por quê.

## 2. Cada decisão tem um estudo, feito por nós

Uma decisão de projeto (um corner, um valor do SDC, uma opção de ferramenta,
proibir ou forçar uma célula) passa por um estudo em `docs/estudos/`, no
modelo de `docs/estudos/README.md`. **Uma variável por vez:** cada
experimento muda uma coisa só e mantém o resto igual (de preferência, a mesma
netlist, mudando só a análise). Comparar duas rodadas que diferem em várias
coisas não prova nada.

1. **Pergunta:** o que estamos decidindo, em uma frase.
2. **O que precisamos saber:** os conceitos, explicados por nós, com as
   nossas palavras.
3. **Fonte primária:** onde o valor está definido.
4. **Experimento:** os comandos, rodados por nós, um de cada vez, com a saída
   anotada. Só comandos `report_*` e de consulta que saibamos explicar.
5. **Conclusão:** o que a evidência mostra.
6. **Decisão:** só depois dos itens acima, com os dois de acordo, registrada
   em `docs/decisions.md`.

A IA pode redigir o rascunho, mas o estudo só fica pronto quando cada um de
nós consegue explicar a conclusão sem ler o texto.

## 3. Nível da decisão: júnior ou avançada

| Nível | Exemplos | Quem decide |
|---|---|---|
| Júnior | ler um relatório, escolher o arquivo do corner pelo databook, corrigir um erro de script, mudar um nome de pasta | a dupla, com estudo |
| Avançada | `set_dont_use`/`set_dont_touch` em célula da biblioteca, mudar orçamento de E/S do SDC, derate, regras de roteamento não padrão (NDR), mudar a estratégia da ferramenta, multi-Vt | **só depois de perguntar ao professor**, levando o estudo junto |

Na dúvida, a decisão é avançada. Pergunta ao professor sempre vai **com os
dados** (o estudo) e com **uma proposta de 2 ou 3 alternativas**, com o
resultado de cada uma. Nunca uma pergunta aberta ("o que devemos fazer?").

Se o professor não responder a tempo: seguimos com a alternativa mais
conservadora, registrada como **provisória** em `docs/decisions.md`, e
dizemos isso no próximo envio.

## 4. Nada em lote antes de entender bloco a bloco

- Cada etapa do fluxo é rodada **à mão, bloco a bloco**, lendo o comentário
  do bloco antes de colar. Para caber no prazo: **uma pessoa roda e a outra
  acompanha e confere ao vivo** (chamada ou tela compartilhada), e quem roda
  alterna a cada etapa. Os dois precisam conseguir explicar cada bloco.
- Toda rodada que vale tem anotados: a pasta (`runs/pnr_<vt>_<data>`), o hash
  do git (`git log -1 --oneline`), quem rodou e quem conferiu.
- Depois de cada bloco: conferir o que o comentário pede (`CONFERIR`) e
  conseguir dizer o que mudou no projeto.
- Rodar em segundo plano (`run_01_a_03.tcl`) só é permitido para repetir uma
  etapa que os dois já rodaram e entenderam à mão.
- Só conta como resultado o que um de nós rodou, bloco a bloco, numa rodada
  anotada.

## 5. Relatório só vai ao professor se passar nos critérios e for explicado

Antes de enviar qualquer relatório ou slide:

1. Conferir os números com `docs/criterios-aceite.md` (setup e hold nos três
   corners, violações elétricas, etc.).
2. Saber explicar **cada linha** do relatório mostrado. Se alguma linha não
   for clara, ler o `man` antes.
3. **Conferência cruzada:** a Alanna confere os números do Apolonio e o
   Apolonio confere os da Alanna. Cada um assina na lista de verificação do
   envio (`docs/criterios-aceite.md`, seção "Antes de enviar").
4. Escrever o resultado como ele é: o que fecha, o que não fecha e por quê.
   Número fora do critério vai com o motivo e o plano, nunca escondido.

## 6. Regras para a IA

- **Explica e propõe; não decide.** Toda proposta diz o nível (júnior ou
  avançada, seção 3) e a fonte primária.
- Nunca escreve "confirmado" sem citar o documento e o trecho.
- Não roda o fluxo nem as ferramentas de EDA. Quem roda é a dupla.
- Quando a dupla pedir um script, ele vem com o porquê de cada bloco e com o
  que conferir na saída.
- Se perceber que uma decisão já registrada pode estar errada, avisa logo,
  com a evidência, e propõe um estudo; não corrige em silêncio.

## 7. Quando aparecer um problema

1. Anotar o sintoma, a causa e a correção. Se for uma armadilha da ferramenta
   que pode se repetir, ela entra em `docs/erros-conhecidos.md`, com o código
   da mensagem.
2. Procurar o mesmo problema em outros lugares (scripts, `docs/decisions.md`,
   documentos, slides). Uma premissa errada costuma estar copiada em vários
   arquivos.
3. Corrigir tudo no mesmo commit e dizer, na mensagem do commit, quais
   resultados deixaram de valer.
