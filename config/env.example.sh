#!/usr/bin/env bash
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
# =============================================================================
# config/env.example.sh - template do ambiente do servidor.
#
# Copie para config/env.sh no servidor (config/env.sh é ignorado pelo git),
# preencha os valores reais (o relatório do scripts/env_probe.sh ajuda a
# encontrá-los) e então:
#     source config/env.sh
#
# Todo valor abaixo é um placeholder: confira cada um no seu servidor.
# =============================================================================

# --- projeto ------------------------------------------------------------------
export PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export RUNS_DIR="${PROJECT_ROOT}/runs"            # saídas por rodada, nunca no Git
export UPSTREAM_RTL="${PROJECT_ROOT}/third_party/cv32e40p"
export DESIGN_RTL_DIR="${UPSTREAM_RTL}/rtl"       # nome usado pelo manifesto do upstream

# --- carregamento das ferramentas Synopsys ------------------------------------
# As ferramentas são carregadas por um script de setup do servidor (ajuste o
# caminho ao seu).
# Repita este `source` em cada sessão de shell nova antes de rodar qualquer
# ferramenta (vcs, fc_shell, pt_shell, etc.).
source /Tools/synopsys-scripts/snps.sh

# Servidor de licença no formato porta@máquina (placeholder: troque pelo seu).
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27020@SERVIDOR_DE_LICENCA}"

# VC SpyGlass (lint): se o vc_static_shell não estiver no PATH depois do
# script de setup, acrescente a pasta bin/ da instalação, por exemplo:
#   export PATH="<instalação do vc_static>/bin:${PATH}"

# --- biblioteca / PDK ---------------------------------------------------------
# Não rode, de dentro do repositório, scripts que copiam a biblioteca para a
# pasta atual: isso põe arquivos do PDK na árvore do Git. O fluxo digital só
# precisa saber onde a biblioteca está (SAED32_HOME).
export SAED32_HOME="${SAED32_HOME:-/Tools/PDK/SAED32/EDK_Digital}"
# Os arquivos de corner NÃO ficam aqui: são escolhidos nos scripts do fluxo
# (tool_data/fc/create_ndm.tcl e 02_scenarios.tcl). Ver docs/flow-spec.md.

# --- paralelismo ----------------------------------------------------------------
export MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-1}" # TODO(verify): licenças e escalonador
export SCHEDULER="${SCHEDULER:-none}"              # none | slurm | sge | lsf  TODO(verify)

# --- software -------------------------------------------------------------------
export PYTHON3="${PYTHON3:-python3}"               # >= 3.6, só biblioteca padrão no servidor (decisão de software em docs/decisions.md)
export RISCV_PREFIX="${RISCV_PREFIX:-}"            # ex.: riscv32-unknown-elf-  TODO(verify)

# --- sanidade -------------------------------------------------------------------
if [[ -z "${SAED32_HOME}" ]]; then
    echo "env.sh: SAED32_HOME não está definido; preencha config/env.sh" >&2
fi
