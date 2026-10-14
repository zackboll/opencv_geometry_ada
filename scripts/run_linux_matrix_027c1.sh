#!/bin/bash
# Task 027C1/027C2: one Linux OpenCV x Core qualification cell, in isolation.
#
#   scripts/run_linux_matrix_027c1.sh <opencv-version> <core-version>
#
# Clones Geometry at GEOMETRY_SHA (default: this checkout's HEAD) and the Core
# commit for <core-version> into a fresh directory under WORK (default
# /var/tmp/geometry-027c2), builds and tests there with PKG_CONFIG_LIBDIR and
# LD_LIBRARY_PATH pinned to the exact OpenCV prefix, and appends one CSV row to
# WORK/results-v2.csv. Linux only. The original worktree is not modified.
#
# Fail closed: every required stage is checked. The first failure is logged,
# recorded as a FAIL row naming the stage, and the runner exits nonzero. Each
# run writes a new timestamped log directory, so earlier evidence is never
# overwritten.
#
# Native tests: each expected program in tests/native is built and run
# separately with the flags of scripts/run_native_tests.sh, and its exit
# status is recorded. Success is never inferred from printed text.
#
# MATRIX_RUNNER_LIB_ONLY=1 makes `source` define the check functions and
# return, for scripts/test_run_linux_matrix_027c1.sh.
set -u -o pipefail

expected_tests=${EXPECTED_TESTS:-542}
native_programs=${NATIVE_PROGRAMS:-"closest_ellipse_equivalence \
extended_convex_intersection subdiv2d_fault_injection \
subdiv2d_float32_equivalence"}
sanitizer_pattern='runtime error|AddressSanitizer|LeakSanitizer'
sanitizer_pattern="$sanitizer_pattern|UndefinedBehaviorSanitizer"
sanitizer_pattern="$sanitizer_pattern|ThreadSanitizer|MemorySanitizer"

# ---- checks ------------------------------------------------------------

# Prints the number of lines of FILE matching the extended regex PATTERN.
# Zero matches is a normal result; returns 2 only if grep itself fails
# (for example a missing file).
count_matches() { # pattern file
    local n rc
    n=$(grep -c -E -- "$1" "$2" 2>/dev/null)
    rc=$?
    [ "$rc" -le 1 ] || return 2
    echo "$n"
}

# Prints the last numeric value of an AUnit summary field, or nothing.
test_field() { # log field
    sed -n "s/^$2:[[:space:]]*\([0-9][0-9]*\)[[:space:]]*\$/\1/p" "$1" \
        2>/dev/null | tail -n 1
}

# Sets t_run t_ok t_fail t_err from an AUnit log. Fails unless all four
# totals are present, Total = Successful = EXPECTED, and Failed = Errors = 0.
check_test_totals() { # log expected
    local log=$1 expected=$2
    t_run=NA; t_ok=NA; t_fail=NA; t_err=NA
    [ -s "$log" ] || { echo "test log missing or empty: $log"; return 1; }
    t_run=$(test_field "$log" 'Total Tests Run')
    t_ok=$(test_field "$log" 'Successful Tests')
    t_fail=$(test_field "$log" 'Failed Assertions')
    t_err=$(test_field "$log" 'Unexpected Errors')
    if [ -z "$t_run" ] || [ -z "$t_ok" ] || [ -z "$t_fail" ] \
        || [ -z "$t_err" ]; then
        echo "missing or malformed AUnit totals in $log"
        return 1
    fi
    [ "$t_run" -eq "$expected" ] \
        || { echo "ran $t_run tests, expected $expected"; return 1; }
    [ "$t_ok" -eq "$expected" ] \
        || { echo "$t_ok successful, expected $expected"; return 1; }
    [ "$t_fail" -eq 0 ] \
        || { echo "$t_fail failed assertions"; return 1; }
    [ "$t_err" -eq 0 ] \
        || { echo "$t_err unexpected errors"; return 1; }
}

# Sets san_hits. Fails on any sanitizer report or an unreadable log.
check_sanitizer() { # log...
    local f n
    san_hits=0
    for f in "$@"; do
        n=$(count_matches "$sanitizer_pattern" "$f") \
            || { echo "cannot scan $f"; san_hits=NA; return 1; }
        san_hits=$((san_hits + n))
    done
    [ "$san_hits" -eq 0 ] \
        || { echo "$san_hits sanitizer report line(s)"; return 1; }
}

# Fails unless the generated configuration selects this exact OpenCV.
check_config() { # cfg_version cfg_lib cfg_link ov prefix module
    [ "$1" = "$4" ] || { echo "config version '$1' != $4"; return 1; }
    [ "$2" = "-L$5/lib" ] || { echo "config search '$2' != -L$5/lib"; return 1; }
    [ "$3" = "-lopencv_$6" ] \
        || { echo "config link '$3' != -lopencv_$6"; return 1; }
}

# Fails unless every loaded OpenCV library resolves under PREFIX/lib and
# both libopencv_core and libopencv_MODULE were loaded.
check_loaded() { # prefix module lib...
    local prefix module lib real_prefix
    prefix=$1; module=$2; shift 2
    [ "$#" -gt 0 ] || { echo "no OpenCV libraries were loaded"; return 1; }
    real_prefix=$(realpath -m "$prefix")
    for lib in "$@"; do
        case "$(realpath -m "$lib")" in
            "$real_prefix"/lib/*) ;;
            *) echo "loaded outside $prefix: $lib"; return 1 ;;
        esac
    done
    case " $* " in *libopencv_core.so*) ;;
        *) echo "libopencv_core not loaded"; return 1 ;; esac
    case " $* " in *"libopencv_$module.so"*) ;;
        *) echo "libopencv_$module not loaded"; return 1 ;; esac
}

# Fails unless tests/native/*.cpp is exactly the expected program set.
check_native_inventory() { # dir program...
    local dir=$1 src name found=
    shift
    for src in "$dir"/*.cpp; do
        [ -e "$src" ] || continue
        name=$(basename "$src" .cpp)
        found="$found $name"
        case " $* " in *" $name "*) ;;
            *) echo "unexpected native program $name"; return 1 ;; esac
    done
    for name in "$@"; do
        case "$found " in *" $name "*) ;;
            *) echo "expected native program $name is missing"
               return 1 ;; esac
    done
}

if [ "${MATRIX_RUNNER_LIB_ONLY:-0}" = 1 ]; then
    return 0 2>/dev/null || exit 0
fi

# ---- cell setup ------------------------------------------------------

ov=${1:?opencv version, for example 4.10.0}
core_version=${2:?core version, 0.3.0, 0.4.1 or 0.5.0}

here=$(cd "$(dirname "$0")/.." && pwd)
geometry_sha=${GEOMETRY_SHA:-$(git -C "$here" rev-parse HEAD)}
core_repo=${CORE_REPO:-/home/zboll/git/opencv/core}
work=${WORK:-/var/tmp/geometry-027c2}
prefixes=${PREFIXES:-"/var/tmp/geometry-026 /var/tmp/geometry-027c1"}
results=$work/results-v2.csv

case "$core_version" in
    0.3.0) core_sha=0e2753be8ea05fc972ec452c32b975f9e9b3912f ;;
    0.4.1) core_sha=386c5360ac51f2b62e522853d94290aec4ee14a0 ;;
    0.5.0) core_sha=f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f ;;
    *) echo "unknown core version $core_version" >&2; exit 64 ;;
esac

prefix=${OPENCV_PREFIX:-}
if [ -z "$prefix" ]; then
    for base in $prefixes; do
        for name in "install-rel-$ov" "install-$ov"; do
            if [ -d "$base/$name/lib" ]; then
                prefix=$base/$name; break 2
            fi
        done
    done
fi
[ -n "$prefix" ] && [ -d "$prefix/lib" ] \
    || { echo "no prefix for OpenCV $ov" >&2; exit 65; }

major=${ov%%.*}
if [ "$major" = 5 ]; then module=geometry; pc=opencv5
else module=imgproc; pc=opencv4; fi

stamp=$(date +%Y%m%dT%H%M%S)-$$
cell=$work/cells/$ov-core$core_version-$stamp
logs=$work/logs/$ov-core$core_version-$stamp
[ ! -e "$cell" ] && [ ! -e "$logs" ] \
    || { echo "run directory already exists: $cell" >&2; exit 66; }
mkdir -p "$cell" "$logs" || exit 66
: > "$logs/summary.txt"
log() { echo "[$(date +%T)] $*" | tee -a "$logs/summary.txt"; }

g_head=NA; c_head=NA; config_ok=0; loaded_ok=0
r_run=NA; r_ok=NA; r_fail=NA; r_err=NA
v_run=NA; v_ok=NA; v_fail=NA; v_err=NA
n_expected=$(echo $native_programs | wc -w); n_run=0; n_pass=0; san_hits=NA
restore=not_run

record() { # status stage
    local header row
    header="opencv,core,geometry_sha,core_sha,status,failed_stage"
    header="$header,config_ok,loaded_ok,release_run,release_ok"
    header="$header,release_fail,release_err,native_expected,native_run"
    header="$header,native_pass,sanitizer_hits,validation_run"
    header="$header,validation_ok,validation_fail,validation_err"
    header="$header,restore_release,log_dir"
    [ -f "$results" ] || echo "$header" > "$results"
    row="$ov,$core_version,$g_head,$c_head,$1,$2,$config_ok,$loaded_ok"
    row="$row,$r_run,$r_ok,$r_fail,$r_err,$n_expected,$n_run,$n_pass"
    row="$row,$san_hits,$v_run,$v_ok,$v_fail,$v_err,$restore,$logs"
    echo "$row" >> "$results"
}

fail() { # stage message
    log "FAIL [$1] $2"
    log "logs preserved in $logs"
    record FAIL "$1"
    exit 1
}

step() { # name command...
    local name=$1 rc
    shift
    "$@" > "$logs/$name.log" 2>&1
    rc=$?
    log "$name rc=$rc"
    [ "$rc" -eq 0 ] || fail "$name" "exit status $rc (see $name.log)"
}

restore_release() {
    if alr -n -C tests build --profiles=opencv_geometry=release \
        > "$logs/restore_release.log" 2>&1; then
        restore=ok
    else
        restore=FAILED
        log "WARNING: release profile restoration failed"
    fi
    log "restore_release=$restore"
}

export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
unset PKG_CONFIG_PATH
export LD_LIBRARY_PATH="$prefix/lib"

log "cell OpenCV $ov Core $core_version prefix $prefix"
step clone_geometry git clone -q -s "$here" "$cell/geometry"
step checkout_geometry git -C "$cell/geometry" checkout -q "$geometry_sha"
step clone_core git clone -q -s "$core_repo" "$cell/core"
step checkout_core git -C "$cell/core" checkout -q "$core_sha"
g_head=$(git -C "$cell/geometry" rev-parse HEAD)
c_head=$(git -C "$cell/core" rev-parse HEAD)
log "geometry $g_head core $c_head"
[ "$g_head" = "$geometry_sha" ] || fail geometry_sha "$g_head != $geometry_sha"
[ "$c_head" = "$core_sha" ] || fail core_sha "$c_head != $core_sha"
pc_version=$(pkg-config --modversion "$pc") \
    || fail pkg_config "pkg-config cannot find $pc in $PKG_CONFIG_LIBDIR"
[ "$pc_version" = "$ov" ] || fail pkg_config "pkg-config $pc_version != $ov"
log "pkg-config: $pc_version $(pkg-config --variable=libdir "$pc")"
log "alr: $(alr --version | head -n 1)  g++: $(g++ --version | head -n 1)"

cd "$cell/geometry" || fail chdir "cannot enter $cell/geometry"
inventory=$(check_native_inventory tests/native $native_programs) \
    || fail native_inventory "$inventory"

step pin alr -n pin opencv_core --use=../core
step solve alr -n with --solve
step solve_tests alr -n -C tests with --solve
step core_sha alr -n -C tests exec -- sh -c \
    "test \"\$(git -C \"\$OPENCV_CORE_ALIRE_PREFIX\" rev-parse HEAD)\" = $core_sha"
step build alr -n build

cfg=config/opencv_geometry_install.gpr
[ -f "$cfg" ] || fail config "$cfg was not generated"
cfg_value() {
    sed -n "s/^ *$1[ :A-Za-z_]*:= \"\\(.*\\)\";\$/\\1/p" "$cfg" | head -n 1
}
cfg_version=$(cfg_value OpenCV_Version)
cfg_lib=$(cfg_value Library_Search_Switch)
cfg_link=$(cfg_value OpenCV_Geometry_Link_Option)
cfg_core=$(cfg_value OpenCV_Core_Link_Option)
log "config: version=$cfg_version lib=$cfg_lib link=$cfg_link core=$cfg_core"
msg=$(check_config "$cfg_version" "$cfg_lib" "$cfg_link" "$ov" "$prefix" \
    "$module") || fail config "$msg"
config_ok=1


# ---- release profile -------------------------------------------------

step tests_release alr -n -C tests run
check_test_totals "$logs/tests_release.log" "$expected_tests" \
    > "$logs/tests_release_check.txt"
rc=$?
r_run=$t_run; r_ok=$t_ok; r_fail=$t_fail; r_err=$t_err
[ "$rc" -eq 0 ] \
    || fail tests_release_totals "$(cat "$logs/tests_release_check.txt")"
log "release $r_ok/$r_run fail=$r_fail err=$r_err"

[ -x tests/bin/tests ] || fail library_identity "tests/bin/tests is missing"
LD_DEBUG=libs tests/bin/tests > "$logs/tests_release_ld.log" 2>&1 \
    || fail library_identity "LD_DEBUG run of tests/bin/tests failed"
loaded=$(grep -o 'calling init: [^ ]*libopencv_[a-z0-9_]*\.so[.0-9]*' \
    "$logs/tests_release_ld.log" | sed 's/calling init: //' | sort -u)
loaded=$(echo $loaded)
log "loaded: $loaded"
msg=$(check_loaded "$prefix" "$module" $loaded) || fail library_identity "$msg"
loaded_ok=1

# ---- native C++ tests (each program checked by exit status) ----------

include_switch=$(sed -n 's/^ *Include_Switch[ :A-Za-z_]*:= "\(.*\)";$/\1/p' \
    "$cfg" | head -n 1)
core_link=$cfg_core
[ -n "$include_switch" ] && [ -n "$core_link" ] \
    || fail native_config "native build switches missing from $cfg"
mkdir -p obj/native
for name in $native_programs; do
    program=obj/native/$name
    if ! g++ -std=c++17 -Wall -Wextra -Wpedantic -Werror -O1 -g \
        -fsanitize=address,undefined -fno-omit-frame-pointer \
        "$include_switch" -o "$program" "tests/native/$name.cpp" \
        "$cfg_lib" "$cfg_link" "$core_link" \
        > "$logs/native_build_$name.log" 2>&1; then
        fail native_build "$name did not compile (native_build_$name.log)"
    fi
    n_run=$((n_run + 1))
    timeout 60 "$program" > "$logs/native_$name.log" 2>&1
    rc=$?
    log "native $name rc=$rc"
    [ "$rc" -eq 0 ] || fail native_test "$name exited $rc (native_$name.log)"
    n_pass=$((n_pass + 1))
done
[ "$n_run" -eq "$n_expected" ] && [ "$n_pass" -eq "$n_expected" ] \
    || fail native_count "ran $n_run, passed $n_pass, expected $n_expected"
log "native executed=$n_run passed=$n_pass expected=$n_expected"

# ---- validation profile ----------------------------------------------

if ! alr -n -C tests build --profiles=opencv_geometry=validation \
    > "$logs/tests_validation_build.log" 2>&1; then
    log "tests_validation_build rc=nonzero"
    restore_release
    fail tests_validation_build "validation build failed"
fi
log "tests_validation_build rc=0"
tests/bin/tests > "$logs/tests_validation.log" 2>&1
rc=$?
log "tests_validation rc=$rc"
check_test_totals "$logs/tests_validation.log" "$expected_tests" \
    > "$logs/tests_validation_check.txt"
check_rc=$?
v_run=$t_run; v_ok=$t_ok; v_fail=$t_fail; v_err=$t_err
restore_release
[ "$rc" -eq 0 ] || fail tests_validation "exit status $rc"
[ "$check_rc" -eq 0 ] \
    || fail tests_validation_totals "$(cat "$logs/tests_validation_check.txt")"
log "validation $v_ok/$v_run fail=$v_fail err=$v_err"

# ---- whole-cell scans -------------------------------------------------

ce=$(cat "$logs/tests_release.log" "$logs/tests_validation.log" \
    | grep -c 'CONSTRAINT_ERROR')
[ "${ce:-1}" -eq 0 ] || fail ada_exceptions "$ce CONSTRAINT_ERROR line(s)"
check_sanitizer "$logs"/native_*.log "$logs/tests_release.log" \
    "$logs/tests_validation.log" > "$logs/sanitizer_check.txt"
rc=$?
[ "$rc" -eq 0 ] || fail sanitizer "$(cat "$logs/sanitizer_check.txt")"
[ "$restore" = ok ] || fail restore_release "release profile not restored"

record PASS none
log "PASS OpenCV $ov Core $core_version: release $r_ok/$r_run," \
    "validation $v_ok/$v_run, native $n_pass/$n_run, sanitizer $san_hits"
