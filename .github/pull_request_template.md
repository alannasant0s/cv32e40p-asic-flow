## Resumo

<!-- O que muda e por quê. Cite a decisão (docs/decisions.md) e o estudo (docs/estudos/) quando houver. -->

## Etapa

<!-- Qual etapa do docs/plano-de-trabalho.md e quais critérios de docs/criterios-aceite.md isto toca. -->

## Rodadas por trás deste PR

<!-- Pasta da rodada (runs/<rodada>), hash do git, quem rodou e quem conferiu. "nenhuma" se o PR não tem resultados. -->

## Comando no servidor / o que conferir

<!-- Comando exato para reproduzir e qual relatório conferir. "n/a" para PRs só de documentação. -->

## Checklist

- [ ] O hook de pre-commit passou em todos os commits (sem `--no-verify`).
- [ ] Nenhum arquivo do PDK, saída binária de ferramenta ou arquivo acima de 5 MB.
- [ ] `third_party/cv32e40p` intocado.
- [ ] Nada inventado: o que não tem fonte primária está como `TODO(verify)`.
- [ ] Todo número vem de uma rodada listada acima.
- [ ] Critérios de aceite da etapa conferidos, ou a falha está explicada aqui.
- [ ] Decisão nova registrada em `docs/decisions.md`; decisão avançada só com resposta do professor.
- [ ] Os dois autores conseguem explicar cada mudança (trabalho com IA: `docs/ai-usage.md`).
- [ ] Textos em português; LF em tudo.
