#!/bin/bash
# Compile and run the can_fd_fi testbenches in src/sim with GHDL.
#
# The testbenches here are plain self-checking VHDL (no VUnit runner_cfg), so
# this drives GHDL directly instead of going through run_tb_vunit_axi.py.
#
# Two external pieces are needed and are fetched into .ghdl-deps/ on first run:
#
#   * GHDL >= 4: the distro package on Ubuntu 22.04 is 1.0.0, which cannot parse
#     the VHDL-2008 aggregates that hdl-registers generates. v4.1.0 is the newest
#     upstream release with an ubuntu-22.04 build; the 6.x tarballs are built
#     against glibc 2.38 and will not run on 22.04 (glibc 2.35).
#   * xpm_vhdl: memory_unit.vhd instantiates xpm_memory_sdpram. Xilinx ships XPM
#     as SystemVerilog, which GHDL cannot read, so a VHDL translation is used.
#
# Usage:
#   ./run_tb_ghdl.sh                  # run all testbenches
#   ./run_tb_ghdl.sh tb_memory_unit   # run one (substring match)
#   GHDL=/path/to/ghdl ./run_tb_ghdl.sh   # use an existing GHDL >= 4 instead
#
# Exit status is 0 only if every selected testbench passed.

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IP="$(cd "${HERE}/.." && pwd)"
DEPS="${IP}/.ghdl-deps"
BUILD="${IP}/.ghdl-build"
HDL_MODULES="$(cd "${IP}/../../external/git_hdl_modules" 2>/dev/null && pwd)/modules"

GHDL_VERSION="4.1.0"
GHDL_TARBALL="ghdl-gha-ubuntu-22.04-mcode.tgz"
GHDL_URL="https://github.com/ghdl/ghdl/releases/download/v${GHDL_VERSION}/${GHDL_TARBALL}"
XPM_REPO="https://github.com/fransschreuder/xpm_vhdl.git"

STD="--std=08"

# Wall-clock limit per testbench. tb_ref sweeps ~11 reference data sets and
# needs several seconds of simulated time; override with STOP_TIME=... if a
# testbench reports INCONCLUSIVE.
STOP_TIME="${STOP_TIME:-500ms}"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '\033[36m==>\033[0m %s\n' "$*"; }

# --- GHDL ---------------------------------------------------------------

# Accept an externally provided GHDL if it is new enough, else use our own.
ghdl_major() { "$1" --version 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1; }

if [ -n "${GHDL:-}" ]; then
    :
elif command -v ghdl >/dev/null 2>&1 && [ "$(ghdl_major ghdl)" -ge 4 ] 2>/dev/null; then
    GHDL="$(command -v ghdl)"
else
    GHDL="${DEPS}/ghdl/bin/ghdl"
    if [ ! -x "${GHDL}" ]; then
        info "Installing GHDL ${GHDL_VERSION} into ${DEPS}/ghdl (no sudo needed)"
        mkdir -p "${DEPS}/ghdl"
        curl -sSL -o "${DEPS}/${GHDL_TARBALL}" "${GHDL_URL}" || { red "Download failed: ${GHDL_URL}"; exit 1; }
        tar xzf "${DEPS}/${GHDL_TARBALL}" -C "${DEPS}/ghdl" || { red "Extract failed"; exit 1; }
        rm -f "${DEPS}/${GHDL_TARBALL}"
    fi
fi

if ! "${GHDL}" --version >/dev/null 2>&1; then
    red "GHDL at '${GHDL}' is not runnable."
    red "On Ubuntu 22.04 the 6.x tarballs need glibc 2.38 and will not work; v${GHDL_VERSION} is the newest usable release."
    exit 1
fi
if [ "$(ghdl_major "${GHDL}")" -lt 4 ] 2>/dev/null; then
    red "GHDL $("${GHDL}" --version | head -1) is too old; >= 4 is required to parse the generated register packages."
    exit 1
fi
info "Using $("${GHDL}" --version | head -1)"

# --- xpm_vhdl -----------------------------------------------------------

XPM_SRC="${DEPS}/xpm_vhdl/src/xpm"
if [ ! -d "${XPM_SRC}" ]; then
    info "Cloning xpm_vhdl into ${DEPS}/xpm_vhdl"
    git clone --depth 1 -q "${XPM_REPO}" "${DEPS}/xpm_vhdl" || { red "Clone failed: ${XPM_REPO}"; exit 1; }
fi

# xpm_memory_sdpram in this translation is missing two generics that
# memory_unit.vhd passes. Both are synthesis-only hints with no simulation
# behaviour. They must be added to the entity *and* to the component
# declaration in xpm_VCOMP.vhd, which is what the instantiation binds against.
patch_xpm_generics() {
    python3 - "$1" <<'PYEOF'
import sys
path = sys.argv[1]
anchor = '    WRITE_PROTECT           : integer := 1               ;\n'
added = ('    RAM_DECOMP              : string  := "auto"          ;\n'
         '    IGNORE_INIT_SYNTH       : integer := 0               ;\n')
text = open(path).read()
if path.endswith('xpm_VCOMP.vhd'):
    # Scope to the sdpram component: tdpram already declares these generics,
    # so a file-wide check would wrongly report this as already patched.
    start = text.index('component xpm_memory_sdpram')
    end = text.index('end component;', start)
    seg = text[start:end]
    if 'RAM_DECOMP' in seg:
        sys.exit(0)
    if seg.count(anchor) != 1:
        sys.exit('unexpected xpm_VCOMP.vhd layout')
    text = text[:start] + seg.replace(anchor, anchor + added) + text[end:]
else:
    if 'RAM_DECOMP' in text:
        sys.exit(0)
    if text.count(anchor) != 1:
        sys.exit('unexpected xpm_memory_sdpram.vhd layout')
    text = text.replace(anchor, anchor + added)
open(path, 'w').write(text)
PYEOF
}
patch_xpm_generics "${XPM_SRC}/xpm_memory/hdl/xpm_memory_sdpram.vhd" || exit 1
patch_xpm_generics "${XPM_SRC}/xpm_VCOMP.vhd" || exit 1

# --- libraries ----------------------------------------------------------

rm -rf "${BUILD}"
mkdir -p "${BUILD}/xpm" "${BUILD}/work"

# Every already-built library directory is on the search path, so analysis
# order across libraries is what matters, not the -P list.
lib_paths() {
    local p=()
    for d in "${BUILD}"/*/; do p+=(-P"${d%/}"); done
    printf '%s\n' "${p[@]}"
}

analyse() {  # analyse <workdir> <libname> <file>...
    local workdir="$1" lib="$2"; shift 2
    local out rc paths=()
    while IFS= read -r p; do paths+=("$p"); done < <(lib_paths)
    for f in "$@"; do
        out=$("${GHDL}" -a ${STD} --workdir="${workdir}" --work="${lib}" \
              "${paths[@]}" "$f" 2>&1)
        rc=$?
        if [ ${rc} -ne 0 ]; then
            red "Analysis failed: $f"
            printf '%s\n' "${out}" | grep -E 'error|Error' | head -10
            return 1
        fi
    done
}

info "Analysing xpm library"
# Order matters: components and leaf cells before the modules that use them.
analyse "${BUILD}/xpm" xpm \
    "${XPM_SRC}/xpm_VCOMP.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_single.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_array_single.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_async_rst.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_gray.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_sync_rst.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_pulse.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_handshake.vhd" \
    "${XPM_SRC}/xpm_cdc/hdl/xpm_cdc_low_latency_handshake.vhd" \
    "${XPM_SRC}/xpm_memory/hdl/xpm_memory_base.vhd" \
    "${XPM_SRC}/xpm_memory/hdl/xpm_memory_sdpram.vhd" \
    "${XPM_SRC}/xpm_memory/hdl/xpm_memory_spram.vhd" \
    "${XPM_SRC}/xpm_memory/hdl/xpm_memory_tdpram.vhd" \
    || exit 1

# The generated register file is built on hdl-modules, so those libraries have
# to exist first. Only src/ is analysed: the test/ directories need a newer
# VUnit than the one pinned in .venv.
if [ ! -d "${HDL_MODULES}" ]; then
    red "hdl-modules not found at ${HDL_MODULES}"
    red "Run: git submodule update --init hw/vivado/src/external/git_hdl_modules"
    exit 1
fi

# Files inside a library are not in dependency order on disk, so analyse
# repeatedly and keep whatever succeeded; each pass resolves one more layer.
# Anything still failing on the final pass is a real error.
analyse_unordered() {  # analyse_unordered <workdir> <lib> <file>...
    local workdir="$1" lib="$2"; shift 2
    local pending=("$@") failed=() paths=() out
    local pass
    for pass in 1 2 3 4 5; do
        while IFS= read -r p; do paths+=("$p"); done < <(lib_paths)
        failed=()
        for f in "${pending[@]}"; do
            if ! out=$("${GHDL}" -a ${STD} --workdir="${workdir}" --work="${lib}" \
                       "${paths[@]}" "$f" 2>&1); then
                failed+=("$f")
            fi
        done
        [ ${#failed[@]} -eq 0 ] && return 0
        # No progress this pass means the remainder cannot be resolved.
        [ ${#failed[@]} -eq ${#pending[@]} ] && [ ${pass} -gt 1 ] && break
        pending=("${failed[@]}")
        paths=()
    done
    red "Analysis failed in library '${lib}':"
    printf '  %s\n' "${failed[@]}" | head -5
    printf '%s\n' "${out}" | grep -E 'error' | head -5
    return 1
}

info "Analysing hdl-modules libraries"
# hdl-modules has dependencies *between* libraries in both directions (math
# uses common.types_pkg, common uses math.math_pkg), so a per-library ordering
# does not exist. Collect every file with its target library and resolve the
# whole set together, one layer per pass.
HM_FILES=() HM_LIBS=()
for lib in math common resync fifo axi axi_lite register_file; do
    mkdir -p "${BUILD}/${lib}"
    while IFS= read -r f; do
        HM_FILES+=("$f"); HM_LIBS+=("${lib}")
    done < <(find "${HDL_MODULES}/${lib}/src" -name '*.vhd' 2>/dev/null | sort)
done

pending_idx=($(seq 0 $((${#HM_FILES[@]} - 1))))
for pass in 1 2 3 4 5 6; do
    paths=(); while IFS= read -r p; do paths+=("$p"); done < <(lib_paths)
    failed_idx=(); last_out=""
    for i in "${pending_idx[@]}"; do
        lib="${HM_LIBS[$i]}"
        if ! last_out=$("${GHDL}" -a ${STD} --workdir="${BUILD}/${lib}" --work="${lib}" \
                        "${paths[@]}" "${HM_FILES[$i]}" 2>&1); then
            failed_idx+=("$i")
        fi
    done
    [ ${#failed_idx[@]} -eq 0 ] && break
    if [ ${#failed_idx[@]} -eq ${#pending_idx[@]} ] && [ ${pass} -gt 1 ]; then
        red "Analysis stalled in hdl-modules (${#failed_idx[@]} files unresolved):"
        for i in "${failed_idx[@]:0:3}"; do printf '  %s\n' "${HM_FILES[$i]}"; done
        printf '%s\n' "${last_out}" | grep -E 'error' | head -5
        exit 1
    fi
    pending_idx=("${failed_idx[@]}")
done

info "Analysing design and testbench sources"
# sys_config_pkg defines the shared types, so it has to come first, and the
# register packages must precede the register file that uses them.
analyse "${BUILD}/work" work "${IP}/src/hdl/sys_config_pkg.vhd" || exit 1
analyse "${BUILD}/work" work \
    "${IP}/gen/hdl/can_fd_fi_regs_pkg.vhd" \
    "${IP}/gen/hdl/can_fd_fi_register_record_pkg.vhd" \
    "${IP}/gen/hdl/can_fd_fi_register_file_axi_lite.vhd" || exit 1

# can_test_vec_pkg_old.vhd declares the same package as can_test_vec_pkg.vhd;
# analysing both makes the later one silently win. Only the current one is used.
# can_fi_route.vhd and can_fi_axi_top.vhd do not analyse under GHDL: the
# `synthesis translate_off` debug ports are unconstrained in the component
# but constrained at the instantiation, which Vivado tolerates and GHDL
# rejects ("actual constraints don't match formal ones"). No testbench in
# src/sim instantiates them, so they are skipped rather than blocking the run.
# Remove these exclusions once the port declarations are made consistent.
DESIGN_SKIP='can_fi_route.vhd|can_fi_axi_top.vhd'

DESIGN_FILES=()
while IFS= read -r f; do DESIGN_FILES+=("$f"); done < <(
    find "${IP}/src/hdl" -name '*.vhd' ! -name 'sys_config_pkg.vhd' \
    | grep -vE "(${DESIGN_SKIP})$" | sort)
analyse_unordered "${BUILD}/work" work "${DESIGN_FILES[@]}" || exit 1

SUPPORT_FILES=("${IP}/src/sim/can_test_vec_pkg.vhd"
               "${IP}/src/sim/ctu_can_reftest/tb_ref_defs.vhd")
while IFS= read -r f; do SUPPORT_FILES+=("$f"); done < <(
    find "${IP}/src/sim/ctu_can_reftest" -name 'reference_data_set_*.vhd' | sort)
analyse_unordered "${BUILD}/work" work "${SUPPORT_FILES[@]}" || exit 1

# --- testbenches --------------------------------------------------------

# tb_func_axi.vhd depends on the hdl-modules AXI BFMs, which in turn need a
# newer VUnit than the pinned one in .venv, so it is not run here.
ALL_TBS=(tb_memory_unit tb_override_unit tb_func_can_fsm tb_func_timer_unit)

# tb_ref replays the CTU CAN reference vectors: ~8000 per set across 11 sets,
# at roughly 90 vectors/minute. That is a multi-hour regression, not something
# to run by default, so it is only selected when named explicitly:
#   ./run_tb_ghdl.sh tb_ref            (expect INCONCLUSIVE at the default limit)
#   STOP_TIME=600000ms ./run_tb_ghdl.sh tb_ref
OPT_IN_TBS=(tb_ref)

FILTER="${1:-}"
SELECTED=()
for tb in "${ALL_TBS[@]}"; do
    if [ -z "${FILTER}" ] || [[ "${tb}" == *"${FILTER}"* ]]; then
        SELECTED+=("${tb}")
    fi
done
# Opt-in testbenches only run when the filter names them.
if [ -n "${FILTER}" ]; then
    for tb in "${OPT_IN_TBS[@]}"; do
        [[ "${tb}" == *"${FILTER}"* ]] && SELECTED+=("${tb}")
    done
fi
if [ ${#SELECTED[@]} -eq 0 ]; then
    red "No testbench matches '${FILTER}'. Available: ${ALL_TBS[*]} ${OPT_IN_TBS[*]}"
    exit 1
fi

# These testbenches report success with `assert false ... severity failure`,
# which makes GHDL exit non-zero on a *passing* run. Success is therefore
# decided by the reported message, not by the exit status.
SUCCESS_RE='All tests passed successfully!|Test Successful!|Test finished|Simulation Finished, no errors'

declare -a PASSED=() FAILED=()
for tb in "${SELECTED[@]}"; do
    src=$(find "${IP}/src/sim" -name "${tb}.vhd" | head -1)
    [ -z "${src}" ] && { red "Source not found for ${tb}"; FAILED+=("${tb}"); continue; }

    info "Running ${tb}"
    if ! analyse "${BUILD}/work" work "${src}"; then
        FAILED+=("${tb}"); continue
    fi
    mapfile -t PATHS < <(lib_paths)
    elab_log="${BUILD}/${tb}.elab.log"
    if ! "${GHDL}" -e ${STD} --workdir="${BUILD}/work" \
         "${PATHS[@]}" "${tb}" > "${elab_log}" 2>&1; then
        red "  elaboration failed"
        grep -E 'error' "${elab_log}" | head -3 | sed 's/^/      /'
        # GHDL checks port bounds strictly where Vivado's simulator does not,
        # so this usually means the testbench signal and the DUT port really
        # do have different ranges.
        if grep -q "bounds or direction of actual" "${elab_log}"; then
            red "      (testbench signal widths disagree with the DUT ports)"
        fi
        FAILED+=("${tb}"); continue
    fi

    log="${BUILD}/${tb}.log"
    "${GHDL}" -r ${STD} --workdir="${BUILD}/work" \
        "${PATHS[@]}" "${tb}" \
        --stop-time="${STOP_TIME}" > "${log}" 2>&1
    rc=$?

    if grep -qE "${SUCCESS_RE}" "${log}"; then
        green "  PASS  ($(basename "${log}"))"
        PASSED+=("${tb}")
    elif grep -q "assertion failure" "${log}"; then
        red "  FAIL"
        grep "assertion failure" "${log}" | head -3 | sed 's/^/      /'
        FAILED+=("${tb}")
    elif grep -q "simulation stopped by --stop-time" "${log}"; then
        # Hit the wall clock before finishing. Not a pass: the remaining
        # stimulus never ran, so nothing about it has been checked.
        red "  INCONCLUSIVE  (hit --stop-time=${STOP_TIME}, test did not finish)"
        red "      raise STOP_TIME to let it run to completion"
        FAILED+=("${tb}")
    elif [ ${rc} -eq 0 ]; then
        green "  PASS  (ran to completion, no failing assertion)"
        PASSED+=("${tb}")
    else
        red "  FAIL  (exit ${rc}, no success message)"
        tail -5 "${log}" | sed 's/^/      /'
        FAILED+=("${tb}")
    fi
done

echo
echo "─────────────────────────────────────────"
green "passed: ${#PASSED[@]}${PASSED[*]:+  (${PASSED[*]})}"
[ ${#FAILED[@]} -gt 0 ] && red "failed: ${#FAILED[@]}  (${FAILED[*]})"
echo "logs in ${BUILD}/"
echo "─────────────────────────────────────────"

[ ${#FAILED[@]} -eq 0 ]
