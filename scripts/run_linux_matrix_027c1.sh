#!/bin/bash
# Task 027C1: one Linux OpenCV x Core qualification cell, in isolation.
#
#   scripts/run_linux_matrix_027c1.sh <opencv-version> <core-version>
#
# Clones Geometry at GEOMETRY_SHA (default: this checkout's HEAD) and the Core
# commit for <core-version> into a fresh directory under WORK (default
# /var/tmp/geometry-027c1), builds and tests there with PKG_CONFIG_LIBDIR and
# LD_LIBRARY_PATH pinned to the exact OpenCV prefix, and appends one CSV row to
# WORK/results.csv. Logs stay outside the repository. Linux only. The original
# worktree is not modified.
set -u

ov=${1:?opencv version, for example 4.10.0}
core_version=${2:?core version, 0.3.0 or 0.4.1}

here=$(cd "$(dirname "$0")/.." && pwd)
geometry_sha=${GEOMETRY_SHA:-$(git -C "$here" rev-parse HEAD)}
core_repo=${CORE_REPO:-/home/zboll/git/opencv/core}
work=${WORK:-/var/tmp/geometry-027c1}
prefixes=${PREFIXES:-"/var/tmp/geometry-026 /var/tmp/geometry-027c1"}

case "$core_version" in
    0.3.0) core_sha=0e2753be8ea05fc972ec452c32b975f9e9b3912f ;;
    0.4.1) core_sha=386c5360ac51f2b62e522853d94290aec4ee14a0 ;;
    *) echo "unknown core version $core_version" >&2; exit 64 ;;
esac

prefix=
for base in $prefixes; do
    for name in "install-rel-$ov" "install-$ov"; do
        if [ -d "$base/$name/lib" ]; then prefix=$base/$name; break 2; fi
    done
done
[ -n "$prefix" ] || { echo "no prefix for OpenCV $ov" >&2; exit 65; }

major=${ov%%.*}
if [ "$major" = 5 ]; then module=geometry; pc=opencv5; else module=imgproc; pc=opencv4; fi

cell=$work/cells/$ov-core$core_version
logs=$work/logs/$ov-core$core_version
rm -rf "$cell"; mkdir -p "$cell" "$logs"
log() { echo "[$(date +%T)] $*" | tee -a "$logs/summary.txt"; }
: > "$logs/summary.txt"

# Exact-tag OpenCV only: no system pkg-config path, runtime libs first.
export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
unset PKG_CONFIG_PATH
export LD_LIBRARY_PATH="$prefix/lib"

git clone -q -s "$here" "$cell/geometry" && git -C "$cell/geometry" checkout -q "$geometry_sha"
git clone -q -s "$core_repo" "$cell/core" && git -C "$cell/core" checkout -q "$core_sha"
g_head=$(git -C "$cell/geometry" rev-parse HEAD)
c_head=$(git -C "$cell/core" rev-parse HEAD)
log "cell OpenCV $ov Core $core_version prefix $prefix"
log "geometry $g_head core $c_head"
[ "$g_head" = "$geometry_sha" ] && [ "$c_head" = "$core_sha" ] || { log "SHA MISMATCH"; exit 66; }
log "pkg-config: $(pkg-config --modversion $pc) $(pkg-config --variable=libdir $pc)"
log "alr: $(alr --version | head -1)  g++: $(g++ --version | head -1)"

cd "$cell/geometry" || exit 67
step() { # name command...
    name=$1; shift
    "$@" > "$logs/$name.log" 2>&1
    rc=$?
    log "$name rc=$rc"
    eval "rc_$name=$rc"
    return 0
}

step pin alr -n pin opencv_core --use=../core
step solve alr -n with --solve
step solve_tests alr -n -C tests with --solve
step core_sha alr -n -C tests exec -- sh -c \
    "test \"\$(git -C \"\$OPENCV_CORE_ALIRE_PREFIX\" rev-parse HEAD)\" = $core_sha"
step build alr -n build

cfg=config/opencv_geometry_install.gpr
cfg_value() { sed -n "s/^ *$1[ :A-Za-z_]*:= \"\\(.*\\)\";\$/\\1/p" $cfg | head -1; }
cfg_version=$(cfg_value OpenCV_Version)
cfg_lib=$(cfg_value Library_Search_Switch)
cfg_link=$(cfg_value OpenCV_Geometry_Link_Option)
log "config: version=$cfg_version lib=$cfg_lib link=$cfg_link"
config_ok=0
[ "$cfg_version" = "$ov" ] && [ "$cfg_lib" = "-L$prefix/lib" ] \
    && [ "$cfg_link" = "-lopencv_$module" ] && config_ok=1
log "config_ok=$config_ok"

# Release profile first (default), then native tests, validation last.
step tests_release alr -n -C tests run
LD_DEBUG=libs tests/bin/tests > "$logs/tests_release_ld.log" 2>&1
loaded=$(grep -o 'calling init: [^ ]*libopencv_[a-z]*\.so[.0-9]*' \
    "$logs/tests_release_ld.log" | sed 's/calling init: //' | sort -u \
    | tr '\n' ' ')
normalized=
for lib in $loaded; do
    normalized="$normalized $(realpath -m "$lib")"
done
loaded=${normalized# }
log "loaded: $loaded"
loaded_ok=1
for lib in $loaded; do
    case "$lib" in "$(realpath -m "$prefix")"/lib/*) ;; *) loaded_ok=0 ;; esac
done
case "$loaded" in *libopencv_core*) ;; *) loaded_ok=0 ;; esac
case "$loaded" in *libopencv_$module*) ;; *) loaded_ok=0 ;; esac
log "loaded_ok=$loaded_ok"
step native sh scripts/run_native_tests.sh
step tests_validation_build alr -n -C tests build \
    --profiles=opencv_geometry=validation
step tests_validation tests/bin/tests
alr -n -C tests build --profiles=opencv_geometry=release \
    > "$logs/restore_release.log" 2>&1

count() { # log field
    sed -n "s/^$2: *\([0-9]*\).*/\1/p" "$1" | tail -1
}
r_run=$(count "$logs/tests_release.log" "Total Tests Run")
r_ok=$(count "$logs/tests_release.log" "Successful Tests")
r_fail=$(count "$logs/tests_release.log" "Failed Assertions")
r_err=$(count "$logs/tests_release.log" "Unexpected Errors")
v_run=$(count "$logs/tests_validation.log" "Total Tests Run")
v_ok=$(count "$logs/tests_validation.log" "Successful Tests")
v_fail=$(count "$logs/tests_validation.log" "Failed Assertions")
v_err=$(count "$logs/tests_validation.log" "Unexpected Errors")
n_pass=$(grep -c '^PASS' "$logs/native.log")
n_san=$(grep -ci 'runtime error\|AddressSanitizer\|LeakSanitizer' \
    "$logs/native.log")
ce=$(cat "$logs"/tests_release.log "$logs"/tests_validation.log \
    | grep -c 'CONSTRAINT_ERROR')
native_ver=$(grep -o 'Native tests: OpenCV [0-9.]*' "$logs/native.log" | head -1)

header="opencv,core,geometry_sha,core_sha,config_ok,loaded_ok,release_run"
header="$header,release_ok,release_fail,release_err,release_rc,native_rc"
header="$header,native_pass,native_sanitizer_hits,validation_run"
header="$header,validation_ok,validation_fail,validation_err,validation_rc"
header="$header,constraint_errors"
[ -f "$work/results.csv" ] || echo "$header" > "$work/results.csv"
row="$ov,$core_version,$g_head,$c_head,$config_ok,$loaded_ok"
row="$row,$r_run,$r_ok,$r_fail,$r_err,$rc_tests_release,$rc_native,$n_pass"
row="$row,$n_san,$v_run,$v_ok,$v_fail,$v_err,$rc_tests_validation,$ce"
echo "$row" >> "$work/results.csv"
log "release $r_ok/$r_run fail=$r_fail err=$r_err rc=$rc_tests_release"
log "validation $v_ok/$v_run fail=$v_fail err=$v_err rc=$rc_tests_validation"
log "native rc=$rc_native pass=$n_pass sanitizer=$n_san ($native_ver)"
