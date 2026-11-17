#!/usr/bin/env bash
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
# Gera a filelist de arquivos RTL para o VCS a partir do manifesto do OpenHW.
#
# O manifesto original usa a variável ${DESIGN_RTL_DIR}, que este script
# substitui pelo caminho real do diretório rtl/ dentro do submódulo.
#
# Uso:
#   scripts/gen_filelist.sh              → filelist completa para simulação RTL
#   scripts/gen_filelist.sh --synthesis  → remove arquivos só de simulação
#
# Saída: tool_data/vcs/flist_rtl.f
#
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
RTL_DIR="${REPO_ROOT}/third_party/cv32e40p/rtl"
MANIFEST="${REPO_ROOT}/third_party/cv32e40p/cv32e40p_manifest.flist"
OUT="${REPO_ROOT}/tool_data/vcs/flist_rtl.f"

SYNTHESIS=0
for arg in "$@"; do
    [[ "$arg" == "--synthesis" ]] && SYNTHESIS=1
done

mkdir -p "$(dirname "$OUT")"

{
    # Cabeçalho informativo (linhas com # não são lidas pelo VCS)
    echo "# Gerado por scripts/gen_filelist.sh em $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "# Fonte: third_party/cv32e40p/cv32e40p_manifest.flist"
    if [[ "$SYNTHESIS" -eq 1 ]]; then
        echo "# Modo: síntese (tb_wrapper e tracer_pkg removidos)"
    else
        echo "# Modo: simulação RTL (todos os arquivos do manifesto)"
    fi
    echo ""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Pular linhas vazias e comentários do manifesto original
        [[ -z "$line" || "$line" == //* ]] && continue

        # Substituir ${DESIGN_RTL_DIR} pelo caminho real
        line="${line//\$\{DESIGN_RTL_DIR\}/$RTL_DIR}"

        # Em modo síntese, remover arquivos só de simulação e trocar
        # cv32e40p_sim_clock_gate.sv pelo wrapper real da SAED32, no mesmo
        # lugar do manifesto (rtl/cv32e40p_clock_gate_saed32.sv).
        if [[ "$SYNTHESIS" -eq 1 ]]; then
            [[ "$line" == *"cv32e40p_tb_wrapper.sv"*   ]] && continue
            [[ "$line" == *"cv32e40p_tracer_pkg.sv"*   ]] && continue
            if [[ "$line" == *"cv32e40p_sim_clock_gate.sv"* ]]; then
                echo "${REPO_ROOT}/rtl/cv32e40p_clock_gate_saed32.sv"
                continue
            fi
        fi

        echo "$line"
    done < "$MANIFEST"
} > "$OUT"

echo "[gen_filelist] Gerado: $OUT"
if [[ "$SYNTHESIS" -eq 1 ]]; then
    echo "[gen_filelist] Modo síntese: cv32e40p_sim_clock_gate.sv trocado por rtl/cv32e40p_clock_gate_saed32.sv"
fi
