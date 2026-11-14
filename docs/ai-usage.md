# Política de uso de IA

Como os agentes de IA para programação são usados neste projeto, o que podem e não podem fazer, como o trabalho deles é revisado e como é atribuído. Esta política vale para todas as pessoas que contribuem e para todas as ferramentas.

**Declaração:** este projeto usa IA. A IA ajuda a escrever e revisar scripts e documentos, explica conceitos e propõe alternativas. A dupla (Alanna Santos e Apolonio Neto) roda as ferramentas, lê os relatórios, entende cada passo e toma as decisões. Nenhum resultado deste repositório foi produzido pela IA no lugar de uma rodada real feita pela dupla.

## 1. Fonte única das regras

- `AGENTS.md`, na raiz do repositório, é o **único** lugar onde as regras para agentes de IA são escritas. Os arquivos específicos de cada ferramenta existem só para que ela carregue esse arquivo:

  | Ferramenta | Como encontra as regras |
  |---|---|
  | Claude Code | `CLAUDE.md` importa `AGENTS.md` (`@AGENTS.md`). Confira com `/context`: os dois arquivos precisam aparecer em "Memory files" |
  | OpenAI Codex | lê `AGENTS.md` nativamente |
  | Cursor | lê `AGENTS.md` nativamente |
  | GitHub Copilot | o coding agent lê `AGENTS.md` nativamente; o Chat do VS Code com a configuração `chat.useAgentsMdFile`; o Chat do github.com e o code review leem `.github/copilot-instructions.md`, que aponta para `AGENTS.md` |
  | Gemini CLI | `GEMINI.md` importa `AGENTS.md` (`@./AGENTS.md`) |

- Uma regra escrita em qualquer outro lugar (arquivo-ponteiro, prompt, conversa) não conta. Se falta uma regra, altere o `AGENTS.md` num commit revisado.

## 2. Ferramentas aceitas

Claude Code, OpenAI Codex, Cursor, GitHub Copilot e Gemini CLI. Qualquer outra ferramenta só pode ser usada se conseguir carregar o `AGENTS.md` (nativamente ou por um arquivo-ponteiro adicionado num commit revisado) e se os autores concordarem antes. A ferramenta e o modelo usados são registrados no trailer do commit (seção 6) e, nas decisões de `docs/decisions.md`, no campo "Rascunhado com".

## 3. Papéis

**Os agentes de IA rascunham:**
- scripts (`scripts/`, `tool_data/`, `verif/`), configurações do fluxo e varreduras;
- parsers, código de consolidação e de gráficos, e seus testes (`scripts/analysis/`);
- documentação: especificações, README, texto das decisões, rascunhos dos estudos, esta política.

**Os autores (pessoas) decidem e executam:**
- restrições de timing (clocks, incerteza, orçamentos de E/S, exceções), corners e cenários;
- floorplan (die, utilização, pinos, malha de alimentação), alvos e estratégia de CTS, regras de roteamento;
- a estratégia de signoff e a aceitação de cada etapa contra seus critérios de saída;
- a execução das ferramentas de EDA no servidor, a leitura dos relatórios brutos e a interpretação dos resultados;
- toda decisão de projeto registrada em `docs/decisions.md`, com as pessoas que decidiram nomeadas em "Decidido por".

Um agente pode *propor* uma restrição, um corner ou um parâmetro de floorplan, com o raciocínio de projeto físico por trás, mas quem decide e assume a responsabilidade é o autor. Agentes nunca rodam ferramentas de EDA, nunca acessam o servidor diretamente e nunca escrevem em `runs/`.

## 4. Revisão humana obrigatória

- **Todo diff** produzido com um agente é lido, linha a linha, por um autor humano antes de ser commitado numa branch compartilhada ou mesclado.
- **Regra da explicabilidade:** os autores precisam conseguir explicar qualquer mudança que aprovem, incluindo o raciocínio de projeto físico por trás de uma restrição ou de uma correção. Uma mudança que os autores não conseguem explicar não é mesclada; ou é estudada até poder ser explicada, ou é descartada.
- A revisão não é só "roda ou não roda": ela confere as regras 1 a 6 do `AGENTS.md` (sem dados de biblioteca, upstream só leitura, sem nomes ou números inventados, critérios de saída, ações destrutivas só com OK explícito).
- O template de pull request (`.github/pull_request_template.md`) carrega essas checagens; um PR com itens não marcados não é mesclado.

## 5. Nenhum resultado sem execução real

- Todo número, gráfico ou afirmação no README, nos docs ou num relatório vem de um relatório interpretado de uma rodada real em `runs/<run_id>/` no servidor (`docs/data-spec.md`). Os ids das rodadas são listados no PR.
- Agentes não estimam, extrapolam, simulam nem "preenchem" saídas de ferramenta. Um valor que falta é escrito como `TODO(verify)` ou deixado vazio, nunca como um número com cara de plausível.
- Os trechos de teste dos parsers (planejados, `docs/data-spec.md` seção 4) são cópias recortadas de relatórios reais, não sintéticos, exceto fixtures explicitamente rotuladas como sintéticas e que nunca alimentam `results/`.
- Se uma ferramenta, licença ou biblioteca não está disponível, a etapa é reportada como não executada. O fluxo nunca é rebaixado em silêncio (ver os fallbacks em `docs/flow-spec.md` seção 5).

## 6. Atribuição

- **Commits** gerados ou escritos em boa parte com um agente levam um trailer nomeando a ferramenta e o modelo:
  - quando a ferramenta documenta um endereço de e-mail para isso, usar `Co-Authored-By`. Claude Code: `Co-Authored-By: <nome do modelo como a ferramenta emite> <noreply@anthropic.com>`, por exemplo `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - quando a ferramenta não documenta endereço, usar `Assisted-by: <Ferramenta> (<modelo>)`, com o nome do modelo exatamente como a ferramenta informa e sem e-mail, por exemplo `Assisted-by: Codex (<modelo>)` ou `Assisted-by: Gemini CLI (<modelo>)`;
  - nunca inventar um endereço e nunca adicionar trailer de uma ferramenta que não foi usada.
- **Decisões** (`docs/decisions.md`) levam `Decidido por` (só pessoas) e, opcionalmente, `Rascunhado com` (ferramenta e modelo). Decidir nunca é atribuído a uma ferramenta.
- **Pull requests** abertos por um agente dizem isso na descrição.

## 7. Confidencialidade dos dados de biblioteca e de ferramenta

A regra 1 do `AGENTS.md` se estende a prompts e conversas: tabelas Liberty, arquivos de tecnologia, runsets, conteúdo de NDM, documentação das ferramentas e qualquer outra coisa sob as licenças da SAED32 ou da Synopsys nunca são colados numa ferramenta de IA, enviados como contexto ou commitados. Nomes de células e pinos, números de relatórios e nossos próprios scripts podem.

## 8. Política do programa

- **Orientação do professor da residência:** os requisitos do projeto (só Fusion Compiler; três corners em todas as etapas e relatórios; HVT primeiro; clock de 8 ns; nada do PDK no GitHub, entre outros) estão em `docs/requisitos-professor.md`. A IA trabalha dentro deles e não os altera.
- A metodologia de trabalho (estudo com fonte primária para cada decisão, uma variável por vez, critérios de aceite por etapa) está em `docs/metodo-de-trabalho.md`, seção 6 (regras para a IA).
- `TODO(verify)`: a política do programa CI Expert UFCG sobre uso de IA nos entregáveis (usos permitidos, declaração, regras de avaliação). A confirmar com o professor e registrar aqui; até lá, este documento é a política do projeto.

## 9. Mudanças nesta política

Mudanças neste arquivo passam por pull request revisado e, quando alteram papéis ou atribuição, por uma decisão registrada em `docs/decisions.md` com os autores em "Decidido por".
