# Especificação de dados — métricas das rodadas e análise

## 0. Estado da implementação

Primeira versão, mais simples que o descrito nas seções seguintes:
- `scripts/analysis/coleta_metricas.py` roda no servidor, com `python3` e só a biblioteca padrão. Ele lê os relatórios do fluxo por etapas (`runs/pnr_<vt>_<data>/rpt/<NN>_qor.rpt`, `<NN>_qor_resumo.rpt`, `<NN>_power_tt.rpt`, com NN = 03, 06, 07, 08, 09) e os logs do Formality (`fm_<vt>*.log`). Grava `results/metricas_long.csv`, no formato longo da seção 3 (com linhas por cenário e por grupo de caminho, `scope` = grupo), e `results/resumo_fluxo.csv`, uma linha por rodada × etapa.
- `scripts/analysis/tabela_fluxo.py` roda no Windows, com pandas, e gera `results/fluxo_<rodada>.md`: a análise 2 da seção 6 (como o timing e a área mudam ao longo das etapas).
- `scripts/analysis/tabela_familias.py` roda no Windows e monta a tabela comparativa LVT × RVT × HVT. Só entram rodadas com os corners conferidos no `report_pvt`. Vai ser usada quando as três famílias tiverem rodado (a HVT vem primeiro).
- Ainda não existem: `meta.json`, o `run_id` com hash, `py/flowkit/`, parquet e os testes pytest da seção 4. Por enquanto, a pasta da rodada (`pnr_<vt>_<data>`) faz o papel do `run_id`.

Próximas melhorias, por ordem:
1. **Metadados de cada rodada (`meta.json`, seção 2):** família, corners e bibliotecas usadas de fato (`report_pvt`), versão da ferramenta, hash do SDC e do script, commit do git, parâmetros de otimização e `run_id`.
2. **Testes e validação:** pytest com trechos reais dos relatórios. Falhar de forma explícita quando o relatório estiver incompleto, faltar valor, a unidade for diferente da esperada, ou quando uma comparação misturar rodadas de commits ou SDCs diferentes.
3. **Análises da síntese:**
   - leakage nos corners ss a 125 °C, ss a −40 °C e ff, para ver a sensibilidade à temperatura (hoje a potência só sai no tt);
   - uso de células (`report_reference`).
4. **Depois do fluxo físico:** degradação do timing entre a síntese e o pós-roteamento; depois, comparação entre famílias (gráficos de PPA por família).

## 1. Princípios

- Uma rodada (run) = uma pasta imutável `runs/<run_id>/`. Uma rodada nunca é sobrescrita; rodar de novo gera um id novo.
- Os relatórios brutos das ferramentas ficam no servidor. Só métricas pequenas, estruturadas e já interpretadas pelos parsers são commitadas.
- Toda afirmação de análise precisa sobreviver a duas perguntas: *a diferença é maior que o ruído da ferramenta?* e *o N é grande o suficiente?*

## 2. Identidade e metadados da rodada

`run_id = <AAAAMMDD-HHMMSS>_<config>_<hash-curto>`, onde o hash cobre a configuração resolvida, o commit do git e um nonce por lançamento (timestamp + PID). Repetições com a mesma configuração (piso de ruído, checagens de determinismo) nunca colidem, mesmo lançadas no mesmo segundo pelo runner.

`runs/<run_id>/meta.json`:
- run_id, usuário, host, hora de início/fim por etapa, status por etapa (`pass | fail | skipped`), etapa alcançada
- hash do git do repo, flag de "sujo" (rodadas com alterações não commitadas são marcadas e excluídas da análise por padrão), tag + hash do upstream
- versões das ferramentas, capturadas na hora da rodada do banner/log da própria ferramenta (`fc_shell -version`, `pt_shell -version` etc.), nunca copiadas de um documento, que envelhece; conjunto de bibliotecas/corners (os três corners com seu `.db`, arquivo de RC e NDM; decisão sobre corners em `docs/decisions.md`)
- a configuração completa resolvida do fluxo (todos os parâmetros, inclusive os padrões)

## 3. Métricas (formato longo)

Os parsers escrevem `runs/<run_id>/metrics.csv` com as colunas:

`run_id, stage, scenario, corner, scope, metric, value, unit, source_report`

- `value` é sempre numérico. Resultados de passa/falha (`lvs_result`, `drc_clean`, `equivalence`) são codificados como 1 = passou, 0 = falhou; contagens continuam contagens.
- `corner` é **obrigatório em toda linha de toda etapa** (requisito R2): `worst`, `typical` ou `best`, mapeados para os nomes de corner da biblioteca em `meta.json`, ou `na` para métricas que não dependem de corner. Métricas que dependem de corner (timing, DRV, skew/latência, potência) são reportadas nos três corners; um parser que encontra uma métrica dessas em menos de três corners falha de forma explícita. Métricas independentes de corner (área, contagem de células, utilização, congestionamento, resultados de DRC/LVS, tempo de execução) são escritas **uma vez**, com `corner = na`. Motivo: escrevê-las por corner triplicaria toda soma e contagem agregada por rodada (área total, células totais, tempo total) e inflaria as análises em silêncio.
- `scenario`: o nome do cenário do Fusion Compiler (modo × corner) ou o nome da sessão do PrimeTime. Para ferramentas sem cenários (StarRC, ICV) `scenario` fica vazio.

- `stage`: syn, place, cts, route, signoff, power, pv
- `scope`: `top` ou uma instância hierárquica (por exemplo `core_i/ex_stage_i`), para área/potência/timing por submódulo
- exemplos de `metric`: wns, tns, nvp, whs, ths, hnvp, area_cell, area_total, cell_count, util, max_trans_viol, max_cap_viol, skew, latency, drc_count, lvs_result, power_leak, power_int, power_switch, power_total, runtime_s, congestion_overflow

Planejado: `py/flowkit/consolidate.py` junta todas as rodadas concluídas em `results/metrics_long.parquet` (ou CSV) mais um `results/runs_summary.csv` largo, uma linha por rodada com as métricas principais nos corners de signoff. A consolidação é um passo separado, nunca appends concorrentes de jobs paralelos.

## 4. Parsers

- Um parser por tipo de relatório (QoR/área/potência/timing/utilização/congestionamento/DRC do Fusion Compiler, timing global/constraints/clock gating do PT, PrimePower, log do StarRC, resumo do ICV). Cada parser é chamado uma vez por corner e marca suas linhas com esse corner.
- Os parsers rodam **no servidor**, ao lado dos relatórios, e usam só a biblioteca padrão do Python (compatível com Python >= 3.6; decisão sobre os parsers em `docs/decisions.md`). pandas, pyarrow e gráficos rodam só no Windows (`requirements-analysis.txt`).
- Planejado: cada parser tem um teste pytest com um trecho real (recortado) de relatório em `py/tests/data/`, salvo com extensão `.txt` para que as regras de ignore de `*.rpt`/`*.log` não se apliquem. Os trechos não podem conter conteúdo proprietário da biblioteca além de nomes de células/instâncias e números; caminhos de biblioteca são apagados.
- Formato desconhecido → falhar de forma explícita; nunca devolver zeros em silêncio.

## 5. Desenho dos experimentos

- **Orçamento de rodadas primeiro:** medir o tempo de execução do baseline por etapa e o limite de licenças/jobs paralelos do ambiente, depois dimensionar as varreduras para caber no calendário.
- **Piso de ruído:** rodar o baseline 3× com perturbações mínimas (por exemplo, período alvo ±0,5 %) para estimar o caos da ferramenta. Diferenças abaixo desse piso não são reportadas como efeitos.
- **Um fator por vez** em torno do baseline primeiro: utilização, razão de aspecto, banco de registradores, hierarquia (preservada × desagrupada), configuração (base/PULP/FPU). Depois, grades pequenas de 2 fatores só para os fatores que importam.
- Planejado: as varreduras são declaradas em `config/sweeps/*.yaml` e executadas por `py/flowkit/runner.py` com um limite de jobs paralelos.

## 6. Análises (em ordem de valor)

1. Tabela de PPA (potência, desempenho, área) e frentes de Pareto (área × fmax × potência) por configuração.
2. Degradação de slack e área ao longo das etapas (syn → place → cts → route → signoff), por corner, mais a correlação Fusion Compiler × PrimeTime por corner.
3. Composição do caminho crítico: pontos de início/fim agrupados por submódulo, por corner.
4. Potência por submódulo × carga de trabalho (vectorless × CoreMark × ocioso/WFI), incluindo o efeito do clock gating.
5. Sensibilidade a parâmetros (efeitos de um fator por vez, com o piso de ruído mostrado).
6. *Opcional:* prever o WNS pós-roteamento a partir das métricas de síntese/placement. Só com ≥ ~30 rodadas comparáveis, validação cruzada leave-one-out e sempre comparado com um baseline ingênuo (WNS da síntese menos a degradação média). Reportar com honestidade, inclusive um resultado negativo.

## 7. Saídas

- `results/plots/*.png` (estilo, unidades e títulos consistentes; gerados só por scripts).
- `results/report.md` gerado a partir das tabelas, embutido no README.
