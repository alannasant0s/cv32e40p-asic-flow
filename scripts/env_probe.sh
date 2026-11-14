#!/usr/bin/env bash
# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
# =============================================================================
# env_probe.sh - descoberta só de leitura do servidor Linux de EDA.
#
# Coleta localização/versão das ferramentas, configuração de shell e módulos,
# escalonador, acesso ao servidor de licenças, o layout da biblioteca SAED32
# (corners, .db/.lib, .ndm, TLU+, runsets do ICV, nomes de células físicas),
# a toolchain RISC-V e o Python. A saída é Markdown: um retrato do servidor
# para consulta local (descreve a máquina; não é para publicar).
#
# Uso:
#   scripts/env_probe.sh [-o ARQUIVO] [--invoke-tools] [--license] [--depth N]
#                        [--pdk-root DIR]... [--tool-root DIR]...
#
#   -o ARQUIVO       escreve o Markdown em ARQUIVO em vez da saída padrão
#   --pdk-root DIR   árvore de diretórios a varrer em busca da SAED32 (repetível).
#                    Padrão: SAED32_HOME, PDK_HOME, SAED32, PDK, SAED_HOME,
#                    se alguma estiver definida e existir.
#   --tool-root DIR  árvore a varrer em busca de instalações Synopsys (repetível).
#                    Padrão: SYNOPSYS, SYNOPSYS_HOME, /tools, /opt,
#                    /usr/synopsys, /eda, /cad, /apps (só as que existirem).
#   --depth N        profundidade máxima do find nas varreduras (padrão 6)
#   --invoke-tools   também roda "<ferramenta> -version" para cada uma encontrada.
#                    DESLIGADO por padrão: inicia o binário (pode tocar o servidor
#                    de licenças). Prefira rodar uma vez, fora do horário de pico.
#   --license        também roda "lmstat -a" com SNPSLMD_LICENSE_FILE /
#                    LM_LICENSE_FILE para listar as licenças (consulta só de leitura).
#
# Garantias:
#   * nunca escreve em lugar nenhum além do arquivo de -o;
#   * nunca roda uma ferramenta Synopsys sem --invoke-tools;
#   * nunca imprime conteúdo das tabelas Liberty, só nomes de células e atributos;
#   * cada coleta é "melhor esforço": um comando ausente imprime
#     "não encontrado" e o script continua.
# =============================================================================
set -euo pipefail

VERSION="0.2.0"
OUT=""
INVOKE_TOOLS=0
LICENSE=0
DEPTH=6
PDK_ROOTS=()
TOOL_ROOTS=()
ARGS_GIVEN="$*"

usage() { sed -n '3,/^# ====/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while (($#)); do
    case "$1" in
        -o) OUT="$2"; shift 2 ;;
        --invoke-tools) INVOKE_TOOLS=1; shift ;;
        --license) LICENSE=1; shift ;;
        --depth) DEPTH="$2"; shift 2 ;;
        --pdk-root) PDK_ROOTS+=("$2"); shift 2 ;;
        --tool-root) TOOL_ROOTS+=("$2"); shift 2 ;;
        -h|--help) usage 0 ;;
        *) echo "argumento desconhecido: $1" >&2; usage 2 ;;
    esac
done

if [[ -n "$OUT" ]]; then
    exec > "$OUT"
fi

# ----------------------------------------------------------------------------- auxiliares
have() { command -v "$1" >/dev/null 2>&1; }

# g ARGS... : grep cujo "sem resultado" (saída 1) não aborta o script
# (set -e + pipefail matariam toda listagem opcional).
g() { grep "$@" || [[ $? -eq 1 ]]; }

h1() { printf '\n# %s\n\n' "$*"; }
h2() { printf '\n## %s\n\n' "$*"; }
kv() { printf -- '- **%s:** %s\n' "$1" "$2"; }
fence_open() { printf '```%s\n' "${1:-text}"; }
fence_close() { printf '```\n'; }

NF="não encontrado"

# run_fenced RÓTULO CMD... : roda um comando e mostra o comando e a saída num bloco.
run_fenced() {
    local label="$1"; shift
    printf '%s\n\n' "$label"
    fence_open
    printf '$ %s\n' "$*"
    "$@" 2>&1 | head -n 200 || true
    fence_close
}

# cmd_or_missing NOME : "- NOME: /caminho" ou "- NOME: não encontrado"
cmd_or_missing() {
    local n="$1"
    if have "$n"; then kv "$n" "\`$(command -v "$n")\`"; else kv "$n" "$NF"; fi
}

# first_existing DIR... : imprime os diretórios que existem, um por linha
first_existing() { local d; for d in "$@"; do [[ -n "$d" && -d "$d" ]] && printf '%s\n' "$d"; done; return 0; }

# catz ARQUIVO : cat de arquivo simples ou comprimido com gzip
# O "|| true" engole o SIGPIPE que acontece quando um "head" fecha a leitura
# antes do fim de um .lib grande; sem isso, pipefail + set -e matariam o script.
catz() { { case "$1" in *.gz) gzip -dc "$1";; *) cat "$1";; esac; } 2>/dev/null || true; }

# lib_cells ARQUIVO : imprime o nome de cada bloco cell(...) de um arquivo Liberty
lib_cells() {
    catz "$1" | g -oE '^[[:space:]]*cell[[:space:]]*\([[:space:]]*"?[A-Za-z0-9_]+"?[[:space:]]*\)' \
              | sed -E 's/.*\([[:space:]]*"?([A-Za-z0-9_]+)"?[[:space:]]*\)/\1/'
}

# cells_with_attr ARQUIVO REGEX : nomes das células cujo bloco cell(...) tem uma
# linha casando com REGEX. O awk acompanha a célula atual, então não há
# "vazamento" de células vizinhas (pequenas) como aconteceria com grep -B.
cells_with_attr() {
    catz "$1" | awk -v re="$2" '
        /^[[:space:]]*cell[[:space:]]*\(/ {
            c = $0
            sub(/^[[:space:]]*cell[[:space:]]*\([[:space:]]*"?/, "", c)
            sub(/"?[[:space:]]*\).*/, "", c)
        }
        c != "" && $0 ~ re { print c }
    ' | sort -u
}

indent() { sed 's/^/   /'; }

# ----------------------------------------------------------------------------- padrões
if ((${#PDK_ROOTS[@]} == 0)); then
    mapfile -t PDK_ROOTS < <(first_existing "${SAED32_HOME:-}" "${PDK_HOME:-}" "${SAED32:-}" "${PDK:-}" "${SAED_HOME:-}")
fi
if ((${#TOOL_ROOTS[@]} == 0)); then
    mapfile -t TOOL_ROOTS < <(first_existing "${SYNOPSYS:-}" "${SYNOPSYS_HOME:-}" /tools /opt /usr/synopsys /eda /cad /apps)
fi

# ============================================================================= cabeçalho
printf '# Ambiente do servidor (gerado)\n\n'
printf '> Gerado por `scripts/env_probe.sh` v%s. Não edite à mão; rode o probe de novo.\n\n' "$VERSION"
kv "Data (UTC)" "$(date -u '+%Y-%m-%d %H:%M:%S')"
kv "Host" "$(hostname -f 2>/dev/null || hostname)"
kv "Usuário" "$(id -un) (uid $(id -u))"
kv "Invocação" "\`$0 $ARGS_GIVEN\` (invoke-tools=$INVOKE_TOOLS license=$LICENSE depth=$DEPTH)"
kv "Raízes do PDK varridas" "${PDK_ROOTS[*]:-(nenhuma; passe --pdk-root)}"
kv "Raízes de ferramentas varridas" "${TOOL_ROOTS[*]:-(nenhuma; passe --tool-root)}"

# ============================================================================= 1. SO / shell
h1 "1. Sistema operacional e shell"
kv "Kernel" "$(uname -srmo 2>/dev/null || uname -a)"
if [[ -r /etc/os-release ]]; then
    kv "Distribuição" "$(. /etc/os-release; echo "${PRETTY_NAME:-$NAME $VERSION_ID}")"
elif [[ -r /etc/redhat-release ]]; then
    kv "Distribuição" "$(cat /etc/redhat-release)"
fi
kv "Shell de login" "${SHELL:-?}"
kv "bash" "$(bash --version 2>/dev/null | head -1)"
kv "tcsh" "$( (have tcsh && tcsh --version 2>/dev/null | head -1) || echo "$NF")"
kv "CPUs" "$(nproc 2>/dev/null || g -c ^processor /proc/cpuinfo)"
kv "Modelo de CPU" "$(g -m1 'model name' /proc/cpuinfo 2>/dev/null | sed 's/.*: //')"
kv "RAM" "$(free -g 2>/dev/null | awk '/Mem:/{print $2 " GB no total, " $7 " GB disponíveis"}')"
kv "Carga (1/5/15 min)" "$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"
kv "Tempo ligado" "$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo '?')"

h2 "1.1 Disco e cota"
run_fenced "Sistemas de arquivos (home, tmp, diretório atual):" df -h "$HOME" /tmp "$PWD"
if have quota; then run_fenced "Cota do usuário:" quota -s; else kv "quota" "$NF"; fi
kv "TMPDIR" "${TMPDIR:-não definido}"

h2 "1.2 Environment modules"
if have module || [[ -n "${MODULESHOME:-}" ]] || [[ -n "${LMOD_DIR:-}" ]]; then
    kv "MODULESHOME" "${MODULESHOME:-não definido}"
    kv "LMOD_DIR" "${LMOD_DIR:-não definido}"
    run_fenced "Módulos carregados:" bash -lc 'module list 2>&1'
    run_fenced "Módulos disponíveis (filtrados por palavras-chave de EDA):" \
        bash -lc 'module avail 2>&1 | grep -iE "synopsys|syn|icc|prime|star|icv|formality|vcs|verdi|saed|riscv|gcc|python|verilator|cadence|mentor|siemens" | head -100'
else
    kv "module" "$NF (sem environment modules)"
fi

h2 "1.3 Variáveis de ambiente relevantes"
fence_open
env | g -iE '^(SYNOPSYS|SNPS|LM_LICENSE|SNPSLMD|SAED|PDK|VCS|VERDI|ICC|PT_|STARRC|ICV|RISCV|PATH|LD_LIBRARY_PATH|MODULEPATH|TMPDIR|DISPLAY)' \
    | sed -E 's/^(PATH|LD_LIBRARY_PATH)=/\1=\n    /; s/:/\n    :/g' | head -120 || true
fence_close

h2 "1.4 Arquivos de inicialização do shell"
fence_open
ls -la "$HOME"/.bashrc "$HOME"/.bash_profile "$HOME"/.profile "$HOME"/.cshrc "$HOME"/.tcshrc "$HOME"/.login 2>/dev/null || true
fence_close
printf '\nLinhas dos arquivos de inicialização que citam Synopsys, licenças ou módulos (para reproduzir a configuração):\n\n'
fence_open
g -nHiE 'synopsys|snps|license|module load|module use|saed|source .*\.(sh|csh)' \
    "$HOME"/.bashrc "$HOME"/.bash_profile "$HOME"/.profile "$HOME"/.cshrc "$HOME"/.tcshrc "$HOME"/.login 2>/dev/null | head -60 || true
fence_close

# ============================================================================= 2. escalonador
h1 "2. Escalonador de jobs e paralelismo"
for c in sbatch squeue sinfo qsub qstat bsub bjobs; do cmd_or_missing "$c"; done
if have sinfo; then run_fenced "Partições do Slurm:" sinfo -s; fi
if have sacctmgr; then run_fenced "Limites do Slurm para este usuário:" sacctmgr show assoc user="$(id -un)" format=Account,Partition,MaxJobs,MaxSubmit,GrpTRES -P; fi
if have qstat; then run_fenced "Filas SGE/PBS:" qstat -g c; fi
if have bqueues; then run_fenced "Filas LSF:" bqueues; fi
kv "ulimit -u (máximo de processos do usuário)" "$(ulimit -u)"
kv "ulimit -n (arquivos abertos)" "$(ulimit -n)"
kv "ulimit -v (memória virtual, KB)" "$(ulimit -v)"
kv "ulimit -s (pilha, KB)" "$(ulimit -s)"

# ============================================================================= 3. ferramentas Synopsys
h1 "3. Ferramentas Synopsys"
# fc_shell primeiro (a ferramenta do fluxo); dc_shell/icc2_shell estão
# listados só para inventariar o que o servidor tem, não fazem parte do fluxo.
TOOLS=(fc_shell lm_shell pt_shell pwr_shell fm_shell StarXtract icv icv_nb vcs vlogan vhdlan verdi dve vc_static vc_static_shell spyglass lc_shell tmax tmax2 dc_shell dc_shell-t icc2_shell icc2_lm_shell)

h2 "3.1 Ferramentas no PATH"
for t in "${TOOLS[@]}"; do cmd_or_missing "$t"; done

# Algumas ferramentas instaladas não entram no PATH pelo snps.sh (ex.:
# vc_static_shell, do VC SpyGlass). Procura o binário nas raízes de ferramentas.
h2 "3.1.1 Fora do PATH, encontradas nas raízes de ferramentas"
fence_open
if ((${#TOOL_ROOTS[@]})); then
    for t in vc_static_shell spyglass lm_shell; do
        have "$t" && continue
        for r in "${TOOL_ROOTS[@]}"; do
            for f in "$r"/*/*/bin/"$t" "$r"/*/*/*/bin/"$t"; do
                [[ -x "$f" ]] && printf '%s: %s\n' "$t" "$f"
            done
        done
    done | head -20 || true
fi
fence_close

h2 "3.2 Árvores de instalação sob as raízes de ferramentas (versão inferida pelo caminho)"
printf 'Diretórios com nomes de produtos Synopsys, profundidade <= %s, com seus subdiretórios de release:\n\n' "$DEPTH"
fence_open
if ((${#TOOL_ROOTS[@]})); then
    find "${TOOL_ROOTS[@]}" -maxdepth "$DEPTH" -type d \
        \( -iname 'syn' -o -iname 'icc2' -o -iname 'fc' -o -iname 'prime' -o -iname 'pts' -o -iname 'pt' \
           -o -iname 'starrc' -o -iname 'icvalidator' -o -iname 'icv' -o -iname 'fm' -o -iname 'vcs*' \
           -o -iname 'verdi*' -o -iname 'spyglass*' -o -iname 'vc_static*' -o -iname 'lc' -o -iname 'txs' \
           -o -iname 'scl' -o -iname 'synopsys*' -o -iname 'snps*' \) 2>/dev/null \
        | while IFS= read -r d; do
              printf '%s\n' "$d"
              ls "$d" 2>/dev/null | g -E '^[A-Z]-20[0-9]{2}\.[0-9]{2}' | sed 's/^/    release: /'
          done | head -150 || true
else
    echo "(nenhuma raiz de ferramentas)"
fi
fence_close

h2 "3.3 Versões das ferramentas"
if ((INVOKE_TOOLS)); then
    for t in fc_shell pt_shell pwr_shell fm_shell icv verdi lc_shell dc_shell icc2_shell; do
        if have "$t"; then run_fenced "$t:" timeout 120 "$t" -version; fi
    done
    # VCS: sempre com -full64 (sem ela o wrapper procura o binário de 32 bits, que não existe)
    if have vcs; then run_fenced "vcs:" timeout 120 vcs -full64 -ID; fi
    if have StarXtract; then run_fenced "StarXtract:" timeout 120 StarXtract -v; fi
else
    printf '_Pulado: rode com `--invoke-tools` para executar `<ferramenta> -version`. As versões acima são inferidas só pelos caminhos de instalação._\n'
fi

# ============================================================================= 4. licenças
h1 "4. Licenças"
kv "SNPSLMD_LICENSE_FILE" "${SNPSLMD_LICENSE_FILE:-não definido}"
kv "LM_LICENSE_FILE" "${LM_LICENSE_FILE:-não definido}"
for c in lmstat lmutil; do cmd_or_missing "$c"; done
if ((LICENSE)); then
    LMS="${SNPSLMD_LICENSE_FILE:-${LM_LICENSE_FILE:-}}"
    if [[ -z "$LMS" ]]; then
        printf '\n_Nenhuma variável de licença definida; não é possível consultar._\n'
    else
        # lmstat normalmente não está no PATH; fica na instalação SCL
        # (no servidor: /Tools/synopsys/scl/<versão>/linux64/bin/lmstat).
        LMSTAT_BIN=""
        if have lmstat; then
            LMSTAT_BIN="lmstat"
        else
            for r in "${TOOL_ROOTS[@]}"; do
                for f in "$r"/scl/*/linux64/bin/lmstat; do
                    [[ -x "$f" ]] && { LMSTAT_BIN="$f"; break 2; }
                done
            done
        fi
        if [[ -n "$LMSTAT_BIN" ]]; then
            kv "lmstat usado" "\`$LMSTAT_BIN\`"
            run_fenced "Contagem de licenças (emitidas / em uso):" bash -c "timeout 60 '$LMSTAT_BIN' -a -c '$LMS' 2>&1 | grep -E 'Users of|Total of|license server|UP|DOWN' | head -200"
        elif have lmutil; then
            run_fenced "Contagem de licenças (emitidas / em uso):" bash -c "timeout 60 lmutil lmstat -a -c '$LMS' 2>&1 | grep -E 'Users of|Total of|license server|UP|DOWN' | head -200"
        else
            printf '\n_lmstat/lmutil não encontrados no PATH nem em <raiz>/scl/*/linux64/bin._\n'
        fi
    fi
else
    printf '\n_Pulado: rode com `--license` para consultar o lmstat e contar licenças (necessário para dimensionar rodadas paralelas)._\n'
fi

# ============================================================================= 5. SAED32
h1 "5. Biblioteca SAED32"
if ((${#PDK_ROOTS[@]} == 0)); then
    printf '_Nenhuma raiz de PDK informada e nenhuma de SAED32_HOME/PDK_HOME/SAED32/PDK/SAED_HOME está definida. Rode de novo com `--pdk-root <dir>`._\n'
else
    h2 "5.1 Layout de topo"
    for r in "${PDK_ROOTS[@]}"; do
        run_fenced "Raiz \`$r\` (2 níveis):" find "$r" -maxdepth 2 -mindepth 1 -not -name '.*' -printf '%y %p\n'
    done

    h2 "5.2 Arquivos por tipo (tamanho em bytes, caminho)"
    scan() { # scan RÓTULO ARGS-DO-FIND...
        local label="$1"; shift
        printf '%s\n\n' "$label"
        fence_open
        find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type f "$@" -printf '%s\t%p\n' 2>/dev/null | sort -k2 | head -200 || true
        fence_close
    }
    scan "Liberty (.lib / .lib.gz):" \( -iname '*.lib' -o -iname '*.lib.gz' \)
    scan ".db compilados:" -iname '*.db'
    scan "Arquivos de tecnologia (.tf):" -iname '*.tf'
    scan "LEF:" \( -iname '*.lef' -o -iname '*.lef.gz' \)
    scan "TLU+ / nxtgrd / ITF (extração de RC):" \( -iname '*.tluplus' -o -iname '*.tlup' -o -iname '*.nxtgrd' -o -iname '*.itf' -o -iname '*tlu*map*' \)
    scan "Runsets / regras do ICV:" \( -iname '*.rs' -o -iname '*runset*' -o -iname '*drc*' -o -iname '*lvs*' -o -iname '*.rul' \)
    scan "Modelos de célula Verilog / SPICE:" \( -iname '*.v' -o -iname '*.sp' -o -iname '*.spi' -o -iname '*.cdl' \)
    scan "GDS / OASIS:" \( -iname '*.gds' -o -iname '*.gds2' -o -iname '*.oas' \)
    scan "Antena / mapa de camadas / diversos:" \( -iname '*antenna*' -o -iname '*.map' -o -iname '*layermap*' -o -iname '*.plib' \)
    printf 'Diretórios NDM / nlib:\n\n'; fence_open
    find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type d \( -iname '*.ndm' -o -iname '*.nlib' \) 2>/dev/null | head -100 || true
    fence_close
    printf 'Documentação (PDF/README) encontrada:\n\n'; fence_open
    find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type f \( -iname '*.pdf' -o -iname 'readme*' -o -iname '*.txt' \) 2>/dev/null | head -60 || true
    fence_close

    h2 "5.3 Corners (dos cabeçalhos dos .lib)"
    printf 'Uma linha por arquivo Liberty: nome da biblioteca, tensão e temperatura nominais, VT deduzido do nome do arquivo.\n\n'
    fence_open
    printf '%-60s %-28s %-8s %-8s %s\n' "arquivo" "lib_name" "nom_V" "nom_T" "VT"
    find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type f \( -iname '*.lib' -o -iname '*.lib.gz' \) 2>/dev/null | sort | while IFS= read -r f; do
        hdr=$(catz "$f" | head -n 400)
        name=$(printf '%s\n' "$hdr" | g -m1 -oE '^[[:space:]]*library[[:space:]]*\([[:space:]]*"?[^")]+' | sed -E 's/.*\([[:space:]]*"?//')
        v=$(printf '%s\n' "$hdr" | g -m1 -oE 'nom_voltage[[:space:]]*:[[:space:]]*[0-9.]+' | g -oE '[0-9.]+$')
        t=$(printf '%s\n' "$hdr" | g -m1 -oE 'nom_temperature[[:space:]]*:[[:space:]]*-?[0-9.]+' | g -oE -- '-?[0-9.]+$')
        vt=$(basename "$f" | g -oiE 'slvt|rvt|lvt|hvt' | head -1)
        printf '%-60s %-28s %-8s %-8s %s\n' "$(basename "$f")" "${name:-?}" "${v:-?}" "${t:-?}" "${vt:-?}"
    done | head -100 || true
    fence_close

    h2 "5.4 Células físicas / especiais (dos .lib, só nomes e atributos)"
    printf 'Um bloco por família Liberty (sufixo de corner removido). Padrões: ICG, TIE, FILL/DCAP, TAP/CAP, ANTENNA, DELAY.\n\n'
    seen=""
    find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type f \( -iname '*.lib' -o -iname '*.lib.gz' \) 2>/dev/null | sort | while IFS= read -r f; do
        key=$(basename "$f" | sed -E 's/_(ss|tt|ff)[0-9a-z]*//i; s/\.lib(\.gz)?$//')
        case ",$seen," in *",$key,"*) continue;; esac
        seen="$seen,$key"
        printf '**%s**\n\n' "$(basename "$f")"
        fence_open
        cells=$(lib_cells "$f" | sort -u)
        n=$(printf '%s\n' "$cells" | g -c . || true)
        echo "total de células: $n"
        echo "-- células com o atributo clock_gating_integrated_cell (ICG):"
        cells_with_attr "$f" 'clock_gating_integrated_cell' | indent | head -40
        echo "-- valores de clock_gating_integrated_cell:"
        catz "$f" | g -oE 'clock_gating_integrated_cell[[:space:]]*:[[:space:]]*"?[a-z_]+' | sed -E 's/.*:[[:space:]]*"?//' | sort | uniq -c | indent
        echo "-- padrão de nome ICG/CG/GATE:";   printf '%s\n' "$cells" | g -iE 'icg|cgl|clkgat|gate|^cg' | indent | head -40
        echo "-- padrão de nome TIE:";            printf '%s\n' "$cells" | g -iE 'tie' | indent | head -20
        echo "-- padrão de nome FILL/DCAP:";      printf '%s\n' "$cells" | g -iE 'fill|dcap|decap' | indent | head -40
        echo "-- padrão de nome TAP/CAP/END:";    printf '%s\n' "$cells" | g -iE 'tap|endcap|boundary|bcap|ecap|^cap' | indent | head -20
        echo "-- padrão de nome ANTENNA/DIODE:";  printf '%s\n' "$cells" | g -iE 'antenna|diode' | indent | head -20
        echo "-- padrão de nome DELAY/BUF/INV (amostra):"; printf '%s\n' "$cells" | g -iE '^(dly|del|buf|inv|nbuf)' | indent | head -30
        echo "-- células que contêm um grupo latch(...):"
        cells_with_attr "$f" '^[[:space:]]*latch[[:space:]]*[(]' | indent | head -40
        echo "-- células dont_use:"
        cells_with_attr "$f" 'dont_use[[:space:]]*:[[:space:]]*true' | indent | head -40
        echo "-- unidades e limites no nível da biblioteca:"
        catz "$f" | head -n 400 | g -E 'default_max_transition|default_max_capacitance|default_max_fanout|default_operating_conditions|delay_model|time_unit|voltage_unit|capacitive_load_unit|leakage_power_unit|current_unit' | sed -E 's/^[[:space:]]*/   /'
        echo "-- blocos operating_conditions:"
        catz "$f" | g -oE 'operating_conditions[[:space:]]*\([[:space:]]*"?[A-Za-z0-9_]+' | sed -E 's/.*\([[:space:]]*"?//' | sort -u | indent
        fence_close
    done || true

    h2 "5.5 Camadas do arquivo de tecnologia (só nomes)"
    find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type f -iname '*.tf' 2>/dev/null | sort | head -5 | while IFS= read -r f; do
        printf '**%s**\n\n' "$f"
        fence_open
        g -oE '^[[:space:]]*Layer[[:space:]]+"[^"]+"' "$f" | sed -E 's/.*"([^"]+)"/\1/' | tr '\n' ' ' | fold -w 100
        printf '\nunidades/grade:\n'
        g -E 'lengthPrecision|unitLengthName|gridResolution|manufacturingGrid' "$f" | head -5 | sed -E 's/^[[:space:]]*/   /'
        fence_close
    done || true
    printf 'Resumo das camadas do LEF (primeiro LEF de tecnologia encontrado):\n\n'; fence_open
    lef=$(find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type f -iname '*.lef' 2>/dev/null | g -viE 'cell|macro|sram' | head -1 || true)
    if [[ -n "$lef" ]]; then
        echo "$lef"
        g -E '^[[:space:]]*LAYER[[:space:]]+[A-Za-z0-9_]+' "$lef" | awk '{print $2}' | tr '\n' ' ' | fold -w 100
        printf '\n'; g -E 'MANUFACTURINGGRID|UNITS|DATABASE' -A1 "$lef" | head -8
    else
        echo "(nenhum LEF de tecnologia encontrado)"
    fi
    fence_close

    h2 "5.6 Compiladores de memória, IO e outros diretórios de IP"
    fence_open
    find "${PDK_ROOTS[@]}" -maxdepth "$DEPTH" -type d \( -iname '*sram*' -o -iname '*memory*' -o -iname '*mem*' -o -iname '*io*' -o -iname '*pll*' \) 2>/dev/null | head -40 || true
    fence_close
fi

# ============================================================================= 6. outras toolchains
h1 "6. Toolchain RISC-V, simuladores e ferramentas de build"
RISCV_GCCS=(riscv32-unknown-elf-gcc riscv64-unknown-elf-gcc riscv-none-elf-gcc riscv32-corev-elf-gcc riscv-none-embed-gcc)
for c in "${RISCV_GCCS[@]}" clang spike qemu-riscv32 verilator iverilog yosys gtkwave make cmake gcc g++ perl tclsh jq; do
    cmd_or_missing "$c"
done
for c in "${RISCV_GCCS[@]}" verilator make gcc; do
    if have "$c"; then kv "versão de $c" "$("$c" --version 2>/dev/null | head -1)"; fi
done
fence_open
echo "Instalações RISC-V sob as raízes de ferramentas:"
if ((${#TOOL_ROOTS[@]})); then find "${TOOL_ROOTS[@]}" -maxdepth "$DEPTH" -type d -iname '*riscv*' 2>/dev/null | head -20; fi
fence_close

# ============================================================================= 7. python
h1 "7. Python"
for c in python python3 python2 pip pip3 virtualenv conda; do cmd_or_missing "$c"; done
for c in python python3; do
    if have "$c"; then
        kv "versão de $c" "$("$c" --version 2>&1)"
        kv "módulo venv de $c" "$("$c" -c 'import venv; print("ok")' 2>&1 | tail -1)"
        kv "biblioteca padrão de $c (sqlite3 json csv pathlib)" "$("$c" -c 'import sqlite3,json,csv,pathlib; print("ok")' 2>&1 | tail -1)"
    fi
done
if have python3; then
    run_fenced "Pacotes de terceiros visíveis ao python3 (filtrados):" \
        bash -c "python3 -m pip list 2>/dev/null | grep -iE 'pandas|numpy|pyarrow|matplotlib|yaml|pytest|scipy|polars|jinja' || echo '(pip indisponível ou nenhum dos pacotes de análise instalado)'"
fi
if ((${#TOOL_ROOTS[@]})); then
    kv "Outras instalações de Python sob as raízes de ferramentas" "$(find "${TOOL_ROOTS[@]}" -maxdepth 3 -type d -iname 'python*' 2>/dev/null | head -10 | tr '\n' ' ')"
fi

# ============================================================================= 8. git / rede
h1 "8. Git e rede"
kv "git" "$(git --version 2>/dev/null || echo "$NF")"
kv "git lfs" "$(git lfs version 2>/dev/null || echo "$NF")"
kv "GitHub acessível (https)" "$( (have curl && curl -sS -o /dev/null -m 10 -w '%{http_code}' https://github.com) 2>&1 || echo 'curl falhou/não encontrado')"
kv "GitHub acessível (ssh)" "$( (have ssh && timeout 15 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | head -1) || echo 'ssh falhou/não encontrado')"
kv "Proxy" "${http_proxy:-${HTTP_PROXY:-não definido}} / ${https_proxy:-${HTTPS_PROXY:-não definido}}"

# ============================================================================= 9. checklist
h1 "9. Checklist dos itens TODO(verify) de docs/flow-spec.md"
cat <<'MSG'
Preencha a partir das seções acima (mantenha os textos exatos; eles alimentam config/ e o SDC):

| Item | Valor obtido neste probe | Seção |
|---|---|---|
| Versão do Fusion Compiler (síntese ao roteamento) | | 3 |
| Licença do Fusion Compiler disponível (feature do fc_shell) | | 4 |
| Versão do PrimeTime / PrimePower | | 3 |
| Versão do StarRC | | 3 |
| Versão do IC Validator | | 3 |
| Versão do Formality | | 3 |
| Versão do VCS | | 3 |
| Máximo de jobs paralelos (licenças / escalonador) | | 2, 4 |
| Arquivo .db / .lib do pior corner (ss), após a checagem de inversão de temperatura | | 5.2, 5.3 |
| Arquivo .db / .lib do corner típico (tt) | | 5.2, 5.3 |
| Arquivo .db / .lib do melhor corner (ff) | | 5.2, 5.3 |
| Bibliotecas ss em mais de uma temperatura? (checagem de inversão necessária) | | 5.3 |
| VT escolhido (baseline RVT) | | 5.3 |
| Nome e pinos da célula ICG | | 5.4 |
| Células tie-high / tie-low | | 5.4 |
| Células filler / decap | | 5.4 |
| Células tap / endcap (obrigatórias?) | | 5.4 |
| Célula de diodo de antena | | 5.4 |
| Arquivo de tecnologia (.tf) | | 5.2 |
| Bibliotecas de referência NDM | | 5.2 |
| TLU+ (Cmax / nominal / Cmin) + arquivo de mapa | | 5.2 |
| Runsets de DRC / LVS do ICV | | 5.2 |
| Pilha de metais (camadas) | | 5.5 |
| Toolchain RISC-V | | 6 |
| Versão do Python para os parsers do servidor (biblioteca padrão, >= 3.6) | | 7 |
MSG

printf '\n_Fim do probe._\n'
