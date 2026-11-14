# =============================================================================
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
# Makefile - pontos de entrada no servidor Linux (GNU make, bash).
#
# No Windows não há make: rode os comandos de cada alvo direto no terminal.
# Os alvos de etapa ainda são placeholders: as etapas rodam pelos scripts de
# tool_data/, bloco a bloco (ver docs/plano-de-trabalho.md).
# =============================================================================
SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

PYTHON3  ?= python3
PROBE_OUT ?= docs/server-env.md
PDK_ROOT ?=
PROBE_FLAGS ?=

.PHONY: help hooks submodules probe venv test lint-sh consolidate clean \
        lint sim syn formality floorplan place cts route signoff

help: ## lista os alvos
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

# ---------------------------------------------------------------- repositório
hooks: ## instala o hook de pre-commit (core.hooksPath)
	git config core.hooksPath .githooks
	@echo "hooks instalados: $$(git config core.hooksPath)"

submodules: ## baixa third_party/cv32e40p no commit fixado
	git submodule update --init --depth 1
	@git -C third_party/cv32e40p describe --tags

# ---------------------------------------------------------------- descoberta do ambiente
probe: ## roda scripts/env_probe.sh -> $(PROBE_OUT)  (PDK_ROOT=<dir> PROBE_FLAGS="--license")
	@test -n "$(PDK_ROOT)" || { echo "uso: make probe PDK_ROOT=/caminho/da/SAED32 [PROBE_FLAGS=\"--invoke-tools --license\"]"; exit 2; }
	scripts/env_probe.sh --pdk-root "$(PDK_ROOT)" $(PROBE_FLAGS) -o "$(PROBE_OUT)"
	@echo "escrito $(PROBE_OUT)"

# ---------------------------------------------------------------- python (análise, Windows/Linux)
venv: ## cria .venv com os pacotes de análise (no Windows: py -m venv .venv)
	$(PYTHON3) -m venv .venv
	.venv/bin/python -m pip install --upgrade pip
	.venv/bin/python -m pip install -r requirements-analysis.txt

test: ## testes do Python (ainda não existem; ver docs/data-spec.md)
	@echo "ainda não há testes automáticos (planejado em docs/data-spec.md)"; exit 1

lint-sh: ## roda shellcheck em todos os scripts bash (se o shellcheck estiver instalado)
	@command -v shellcheck >/dev/null || { echo "shellcheck não encontrado"; exit 0; }
	shellcheck -x scripts/*.sh .githooks/pre-commit config/env.example.sh

consolidate: ## coleta as métricas das rodadas em runs/ (scripts/analysis/coleta_metricas.py)
	$(PYTHON3) scripts/analysis/coleta_metricas.py

# ---------------------------------------------------------------- etapas do fluxo (placeholders)
lint sim syn formality floorplan place cts route signoff: ## etapas do fluxo (ainda não implementadas no make)
	@echo "o alvo '$@' ainda não está implementado (ver docs/flow-spec.md e docs/plano-de-trabalho.md)"; exit 1

clean: ## remove só caches do Python (runs/ nunca é tocado pelo make)
	find . -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache
