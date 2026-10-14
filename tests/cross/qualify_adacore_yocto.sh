#!/bin/sh
# AdaCore GNAT 12 / Yocto Scarthgap AArch64 qualification of opencv_geometry
# from externally supplied inputs.
#
# Nothing is discovered or substituted: the caller supplies the AdaCore
# GNAT 12 cross toolchain, a compatible target C++ compiler, the reviewed
# GPR configuration and the Yocto Scarthgap development sysroot through the
# scripts/cross_geometry.py inputs, without sourcing any SDK script here.
# The provenance file is a claim; it is checked against the binaries first
# (tests/cross/verify_target_claims.py). Then tests/cross/qualify_target.sh
# cross-builds and installs Core and Geometry, cross-links the independent
# consumers before and after relocation, and inspects every executable.
#
# The release states below are printed only when every claim is verified
# and every gate passes:
#   ADACORE_GNAT12_CROSS_BUILD_QUALIFIED
#   YOCTO_SCARTHGAP_SYSROOT_QUALIFIED
#   GEOMETRY_YOCTO_CROSS_INSTALL_QUALIFIED
#   GEOMETRY_YOCTO_CONSUMER_LINK_QUALIFIED
# Emulated execution (QUALIFY_EMULATOR) is recorded separately and is
# never target execution.
#
# usage: qualify_adacore_yocto.sh EVIDENCE
# Inputs: the scripts/cross_geometry.py inputs except
#   OPENCV_CROSS_CORE_PREFIX; OPENCV_CROSS_YOCTO_PROVENANCE (JSON, see
#   tests/cross/verify_target_claims.py); QUALIFY_CORE_ROOT,
#   QUALIFY_CORE_COMMIT, QUALIFY_AUNIT_ROOT and optional QUALIFY_EMULATOR,
#   as for tests/cross/qualify_target.sh.
set -eu

fail() {
    echo "error: $*" >&2
    exit 1
}

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
test "$#" -eq 1 || fail "usage: qualify_adacore_yocto.sh EVIDENCE"
evidence=$1
provenance=${OPENCV_CROSS_YOCTO_PROVENANCE:?set OPENCV_CROSS_YOCTO_PROVENANCE}
case "$evidence" in /?*) ;; *) fail "absolute evidence path required" ;; esac
test ! -e "$evidence" || fail "evidence directory already exists"
test -f "$provenance" || fail "provenance file missing: $provenance"
logs=$evidence/logs
mkdir -p "$logs"
dispositions=$evidence/dispositions.txt
: > "$dispositions"
cp "$provenance" "$logs/provenance-claims.json"

# 1. Claims against binary evidence, before any build.
if ! python3 "$here/verify_target_claims.py" "$provenance" \
    > "$logs/claims-verification.json" 2> "$logs/claims-verification.err"
then
    {
        echo "ADACORE_YOCTO_QUALIFICATION_BLOCKED (claims not verified;" \
            "see logs/claims-verification.err)"
        cat "$logs/claims-verification.err"
    } >> "$dispositions"
    cat "$dispositions"
    exit 1
fi

# 2. Toolchain and sysroot identities.
{
    for tool in "$OPENCV_CROSS_ADA" "$OPENCV_CROSS_CXX" \
        "$OPENCV_CROSS_GPRBUILD" "$OPENCV_CROSS_GPRINSTALL"; do
        echo "== $tool"
        sha256sum "$tool"
        "$tool" --version 2>&1 | head -n 3
    done
    echo "== linker"
    linker=$("$OPENCV_CROSS_CXX" -print-prog-name=ld)
    echo "$linker"
    "$linker" --version 2>&1 | head -n 1
    echo "== configuration"
    sha256sum "$OPENCV_CROSS_GPR_CONFIG"
    echo "== runtime"
    sha256sum "$OPENCV_CROSS_RUNTIME/adalib/libgnat.a"
    echo "== search directories"
    "$OPENCV_CROSS_CXX" "--sysroot=$ENV_PREFIX" -print-search-dirs
} > "$logs/identities.log" 2>&1
cp "$OPENCV_CROSS_GPR_CONFIG" "$logs/target.cgpr"

# 3. Production cross build, installation, consumers and inspection.
if ! sh "$here/qualify_target.sh" "$evidence"; then
    echo "ADACORE_YOCTO_QUALIFICATION_BLOCKED (a cross gate failed; see" \
        "logs)" >> "$dispositions"
    cat "$dispositions"
    exit 1
fi
{
    echo "ADACORE_GNAT12_CROSS_BUILD_QUALIFIED"
    echo "YOCTO_SCARTHGAP_SYSROOT_QUALIFIED"
    echo "GEOMETRY_YOCTO_CROSS_INSTALL_QUALIFIED"
    echo "GEOMETRY_YOCTO_CONSUMER_LINK_QUALIFIED"
} >> "$dispositions"
cat "$dispositions"
