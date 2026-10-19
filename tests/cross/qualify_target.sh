#!/bin/sh
# Target cross qualification of opencv_geometry from explicit inputs.
#
# Shared by tests/cross/qualify_debian_aarch64_reference.sh (public Debian
# reference inputs) and tests/cross/qualify_adacore_yocto.sh (externally
# supplied AdaCore GNAT 12 and Yocto inputs). It never selects a compiler,
# runtime, configuration or sysroot itself:
#   1. Core is cross-built and installed by its own
#      scripts/cross_build_core.sh at the exact commit;
#   2. Geometry is validated (scripts/cross_geometry.py check) and
#      cross-built and installed by scripts/cross_build_geometry.sh from the
#      clean HEAD of this checkout;
#   3. independent Ada and mixed Ada/C++ consumers are cross-linked against
#      the installed prefixes, before and after relocating them, and
#      inspected (tests/cross/qualify_reference_consumers.py);
#   4. with QUALIFY_EMULATOR, the consumers and the cross-built AUnit suite
#      also run under that user-mode emulator; that is emulated execution,
#      never target execution.
#
# usage: qualify_target.sh EVIDENCE
# Inputs: every input of scripts/cross_geometry.py except
#   OPENCV_CROSS_CORE_PREFIX, which this script produces; plus
#   QUALIFY_CORE_ROOT    clean opencv_core Git checkout
#   QUALIFY_CORE_COMMIT  40-hex Core commit expected there
#   QUALIFY_AUNIT_ROOT   unpacked AUnit 26.0.0 sources
#   QUALIFY_EMULATOR     optional absolute path of a user-mode emulator
# Writes EVIDENCE/logs and appends dispositions to EVIDENCE/dispositions.txt.
set -eu

fail() {
    echo "error: $*" >&2
    exit 1
}

expected_tests=547
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
test "$#" -eq 1 || fail "usage: qualify_target.sh EVIDENCE"
evidence=$1
core_root=${QUALIFY_CORE_ROOT:?set QUALIFY_CORE_ROOT}
core_commit=${QUALIFY_CORE_COMMIT:?set QUALIFY_CORE_COMMIT}
aunit=${QUALIFY_AUNIT_ROOT:?set QUALIFY_AUNIT_ROOT}
emulator=${QUALIFY_EMULATOR:-}
case "$evidence" in /?*) ;; *) fail "absolute evidence path required" ;; esac
test -f "$aunit/lib/gnat/aunit.gpr" || fail "not AUnit sources: $aunit"
if [ -n "$emulator" ]; then
    case "$emulator" in /*) ;; *) fail "absolute emulator path required" ;; esac
    test -x "$emulator" || fail "emulator unavailable: $emulator"
fi
sysroot=${ENV_PREFIX:?set ENV_PREFIX}
config=${OPENCV_CROSS_GPR_CONFIG:?set OPENCV_CROSS_GPR_CONFIG}
gprbuild=${OPENCV_CROSS_GPRBUILD:?set OPENCV_CROSS_GPRBUILD}
readelf=${OPENCV_CROSS_READELF:-readelf}
test -z "${OPENCV_CROSS_CORE_PREFIX:-}" \
    || fail "OPENCV_CROSS_CORE_PREFIX is produced here, not supplied"

git_in() {
    repo=$1
    shift
    git -c "safe.directory=$repo" -C "$repo" "$@"
}
test "$(git_in "$core_root" rev-parse HEAD)" = "$core_commit" \
    || fail "Core checkout is not at $core_commit"
geometry_commit=$(git_in "$root" rev-parse HEAD)
logs=$evidence/logs
dispositions=$evidence/dispositions.txt
mkdir -p "$logs"
touch "$dispositions"
for name in core-work geometry-work consumers-installed consumers-relocated \
    relocated aunit; do
    test ! -e "$evidence/$name" || fail "stale evidence: $evidence/$name"
done

# 1. Core, by Core's own cross build at the exact commit. Its script runs
#    git without a safe.directory override; trust exactly that checkout in
#    this disposable environment.
git config --global --add safe.directory "$core_root"
sh "$core_root/scripts/cross_build_core.sh" --build "$evidence/core-work" \
    > "$logs/core-cross-build.log" 2>&1 || fail "Core cross build failed"
test "$(cat "$evidence/core-work/source-revision.txt")" = "$core_commit" \
    || fail "Core workspace is not from $core_commit"
core_prefix=$evidence/core-work/install
echo "CORE_AARCH64_CROSS_BUILD_INSTALL PASS ($core_commit)" >> "$dispositions"

# 2. Geometry, through the fail-closed cross configuration.
export OPENCV_CROSS_CORE_PREFIX="$core_prefix"
python3 "$root/scripts/cross_geometry.py" check \
    > "$logs/geometry-cross-check.json" 2> "$logs/geometry-cross-check.err" \
    || fail "Geometry cross check failed: $(cat "$logs/geometry-cross-check.err")"
sh "$root/scripts/cross_build_geometry.sh" --build "$evidence/geometry-work" \
    > "$logs/geometry-cross-build.log" 2>&1 \
    || fail "Geometry cross build failed; see $logs/geometry-cross-build.log"
work=$evidence/geometry-work
test "$(cat "$work/source-revision.txt")" = "$geometry_commit" \
    || fail "Geometry workspace is not from $geometry_commit"
for log in toolchain-probe.log production-build.log cross-evidence.json \
    opencv_geometry-install.log opencv_geometry_shim-install.log; do
    cp "$work/$log" "$logs/geometry-$log"
done
echo "GEOMETRY_AARCH64_CROSS_BUILD_INSTALL PASS ($geometry_commit)" \
    >> "$dispositions"

# 3. Independent consumers, against the installed prefixes, then against
#    both prefixes moved to new paths.
cross_evidence=$work/cross-evidence.json
if [ -n "$emulator" ]; then
    emulate="--emulator $emulator"
else
    emulate=
fi
# shellcheck disable=SC2086 # $emulate is empty or two words
python3 "$here/qualify_reference_consumers.py" "$cross_evidence" "$core_prefix" \
    "$work/install" "$evidence/consumers-installed" \
    "$logs/consumers-installed" $emulate \
    > "$logs/consumers-installed.log" 2>&1 \
    || fail "installed consumers failed; see $logs/consumers-installed.log"
relocated=$evidence/relocated/a-longer-installation-root
mkdir -p "$relocated"
mv "$core_prefix" "$relocated/core-prefix-b"
mv "$work/install" "$relocated/geometry-prefix-b"
# shellcheck disable=SC2086 # $emulate is empty or two words
python3 "$here/qualify_reference_consumers.py" "$cross_evidence" \
    "$relocated/core-prefix-b" "$relocated/geometry-prefix-b" \
    "$evidence/consumers-relocated" "$logs/consumers-relocated" $emulate \
    > "$logs/consumers-relocated.log" 2>&1 \
    || fail "relocated consumers failed; see $logs/consumers-relocated.log"
echo "GEOMETRY_AARCH64_CONSUMER_LINK PASS (Ada and mixed; installed and" \
    "relocated)" >> "$dispositions"

# 4. The complete AUnit suite, cross-built against the installed Core and,
#    with an emulator, run.
cp -a "$aunit" "$evidence/aunit"
mkdir -p "$work/tests/config"
cp "$work/tests/gnat12/tests_config.gpr" "$work/tests/config/"
if [ "${QUALIFY_TRACK:-}" = adacore25 ]; then
    cp "$here/../adacore25/tests_config.gpr" "$work/tests/config/"
fi
(
    cd "$work"
    GPR_PROJECT_PATH="$relocated/core-prefix-b/share/gpr:$evidence/aunit/lib/gnat:$work" \
        "$gprbuild" --config="$config" -P tests/tests.gpr -p -j0 -v -R \
        -XGEOMETRY_GNAT12_PROFILE=release \
        -cargs:C++ "--sysroot=$sysroot" -largs "--sysroot=$sysroot" \
        > "$logs/aunit-cross-build.log" 2>&1
) || fail "AUnit cross build failed; see $logs/aunit-cross-build.log"
if grep -n 'warning:' "$logs/aunit-cross-build.log"; then
    fail "AUnit cross build has warnings"
fi
"$readelf" -h "$work/tests/bin/tests" | grep -q 'Machine:.*AArch64' \
    || fail "the AUnit executable is not AArch64"
python3 "$root/scripts/cross_geometry.py" --verify-built \
    "$cross_evidence" "$work" > "$logs/aunit-object-identity.json" \
    2> "$logs/aunit-object-identity.err" || fail "AUnit object/ALI mismatch"
python3 "$root/scripts/cross_geometry.py" --verify-built \
    "$cross_evidence" "$evidence/aunit" > "$logs/aunit-library-identity.json" \
    2> "$logs/aunit-library-identity.err" || fail "AUnit library object/ALI mismatch"
python3 "$root/scripts/cross_geometry.py" --verify-executable \
    "$cross_evidence" "$work/tests/bin/tests" > "$logs/aunit-executable-abi.json" \
    2> "$logs/aunit-executable-abi.err" || fail "AUnit executable ABI mismatch"
echo "GEOMETRY_AARCH64_AUNIT_CROSS_BUILD PASS" >> "$dispositions"
if [ -z "$emulator" ]; then
    {
        echo "EMULATED_EXECUTION NOT RUN (no emulator supplied)"
        echo "TARGET_EXECUTION NOT RUN (no target hardware)"
    } >> "$dispositions"
    exit 0
fi
"$emulator" -L "$sysroot" "$work/tests/bin/tests" \
    > "$logs/aunit-emulated.log" 2>&1 \
    || fail "AUnit suite failed under emulation"
grep -qx "Total Tests Run:   $expected_tests" "$logs/aunit-emulated.log" \
    || fail "expected $expected_tests registered tests"
grep -qx "Successful Tests:  $expected_tests" "$logs/aunit-emulated.log" \
    || fail "not every AUnit test passed under emulation"
grep -qx 'Failed Assertions: 0' "$logs/aunit-emulated.log" || fail "failures"
grep -qx 'Unexpected Errors: 0' "$logs/aunit-emulated.log" || fail "errors"
{
    echo "EMULATED_CONSUMER_EXECUTION PASS (user-mode emulation only)"
    echo "EMULATED_AUNIT PASS ($expected_tests/$expected_tests; user-mode" \
        "emulation only)"
    echo "TARGET_EXECUTION NOT RUN (no target hardware)"
} >> "$dispositions"
