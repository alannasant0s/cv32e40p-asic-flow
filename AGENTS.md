# AGENTS.md

Contexto permanente para agentes de IA de programação (Claude Code, Codex, Cursor, GitHub Copilot, Gemini CLI). Fonte única das regras do projeto; os arquivos específicos de cada ferramenta só apontam para cá.

## Projeto

Implementação RTL-para-GDSII do processador RISC-V **CV32E40P** (OpenHW Group) como bloco sem pads, com o fluxo **Synopsys** (Fusion Compiler) e a biblioteca educacional **SAED32**. Feito por uma dupla júnior (Alanna Santos e Apolonio Neto) na residência CI Expert, polo UFCG, trilha de Physical Design. O objetivo é **aprender cada decisão**, não só chegar ao GDS.

## Por onde começar

Leia nesta ordem:

0. `docs/estado-atual.md`: onde o projeto está, o próximo passo e as decisões em aberto. **Atualize no fim de cada sessão.**
1. `docs/requisitos-professor.md`: o que o projeto exige. **Manda em tudo.** Se um script, decisão ou documento contradiz um requisito, o erro é nosso.
2. `docs/plano-de-trabalho.md`: o que a dupla está fazendo agora.
3. `docs/metodo-de-trabalho.md`: como trabalhamos (fonte primária, estudos, nível das decisões).
4. `docs/criterios-aceite.md`: quando uma etapa está pronta.
5. `docs/decisions.md`: as decisões vigentes.
6. `docs/estudos/README.md`: os estudos de cada decisão.
7. `docs/erros-conhecidos.md`: armadilhas da ferramenta e como resolver.

## Regras inegociáveis

1. **Nada do PDK no Git, nunca**: `.db .lib .ndm .tf .lef .gds .itf .tluplus .spef .sdf .fsdb .vpd .saif .ddc .nxtgrd .vcd .wlf .shm .svf`, runsets, `runs/`. O hook `.githooks/pre-commit` aplica a lista e o limite de 5 MB. Relatórios e logs de rodadas oficiais podem entrar, conferidos antes (decisão "O que entra no Git"). Nunca contorne o hook.
2. **O RTL upstream é só leitura**: `third_party/cv32e40p` é um submódulo fixado numa tag. Nossas adições ficam em `rtl/`.
3. **Nenhum comando, opção, nome de célula, camada ou corner inventado.** Sem fonte, escreva `TODO(verify): <o quê e onde checar>`.
4. **"Confirmado" exige fonte primária**: o documento que define o valor (databook com página e tabela, `man` da ferramenta, requisito do projeto). Saber que um arquivo existe não confirma nada.
5. **Nenhum número inventado.** Todo número em documento vem de um relatório de uma rodada identificada.
6. **Decisão avançada só com estudo e resposta do professor**: `set_dont_use`/`set_dont_touch` em célula de biblioteca, orçamento de E/S do SDC, derate, regras de roteamento não padrão, mudança de estratégia da ferramenta, multi-Vt. O agente avisa que é avançada e propõe um estudo em `docs/estudos/`.
7. **Critérios de aceite antes de avançar** (`docs/criterios-aceite.md`; timing: WNS > −0,01 ns em setup e hold nos três corners, lido com 3 casas decimais). Etapa que não passa não avança; o agente reporta.
8. **Experimento da IA não é resultado.** O número vale quando a dupla roda bloco a bloco e entende.
9. **Material de terceiros:** não copie scripts de exemplo do curso nem conteúdo de arquivos do PDK (`.lib`, `.lef`, `.tf`, runsets) para documentos ou conversas com IA.
10. Ações destrutivas (apagar, reescrever histórico, force push, sobrescrever rodada) precisam do OK explícito dos autores.

## Acordo de trabalho

- **Modo ensino, sempre.** Para cada ação: o que vai fazer, por quê, o comando exato e o que esperar na saída. Sugira; não execute no lugar da dupla. Erro de ferramenta: explique em linguagem simples antes de propor a correção.
- Português do Brasil em documentação, comentários e commits; nomes de arquivos, comandos, opções e identificadores em inglês. Termo técnico em inglês é explicado na primeira vez.
- Decisão de projeto: o agente avisa que é uma decisão, redige o ADR em `docs/decisions.md` (status, fonte primária, estudo, nível, quem decidiu, "Rascunhado com") e mostra aos dois autores antes do commit.
- Erro novo de ferramenta: entra em `docs/erros-conhecidos.md` (sintoma, causa, correção), no mesmo commit da correção.
- Uso de IA: `docs/ai-usage.md`.

## Ambiente

- **Local (Windows):** edição, Git, Python de análise. Ferramentas de EDA nunca rodam aqui.
- **Servidor (Linux):** onde rodam as ferramentas Synopsys. Em cada terminal novo: `source /Tools/synopsys-scripts/snps.sh`. NDM com `lm_shell`, não `fc_shell`.
- Fim de linha LF em tudo. Scripts `bash` com `set -euo pipefail`.

## Layout

```
third_party/   cv32e40p (submódulo, fixado)
rtl/           wrapper de clock gating para a SAED32
constraints/   SDC (só o modo: clock, E/S, exceções)
tool_data/     vcs/ (simulação), lint/, fc/ (NDM e fluxo 00 a 09), fm/ (Formality)
scripts/       gen_filelist.sh, env_probe.sh, analysis/ (métricas), fc/ (ajudantes), docs/ (PDF)
verif/         sw/ (programa de teste)
docs/          requisitos, plano, método, critérios, decisões, estudos, erros conhecidos, especificações
runs/          saídas por rodada (fora do Git)
```

## Notas por ferramenta

- **Claude Code:** lê `CLAUDE.md`, que importa este arquivo.
- **Codex, Cursor, Copilot:** leem `AGENTS.md` (o Chat do github.com lê `.github/copilot-instructions.md`, que aponta para cá).
- **Gemini CLI:** lê `GEMINI.md`, que importa este arquivo.
