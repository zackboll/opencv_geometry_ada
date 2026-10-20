#!/bin/bash
# Native ARM64 qualification of the project's SDK selection, not SDKROOT.
# Invoked in a fresh runner by macos-standalone-sdk.yml. Evidence is retained
# even on failure. Core 0.5.0 is retrieved from the accepted Alire index;
# 0.5.1 uses its immutable release source until that release is indexed.
set -euo pipefail

test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
test "${SDKROOT+x}" != x
test "${LIBRARY_PATH+x}" != x
root=$PWD
evidence=${RUNNER_TEMP:?}/geometry-standalone-sdk
mkdir -p "$evidence"
exec > >(tee "$evidence/qualification.log") 2>&1

test "$(git rev-parse HEAD)" = "${EXPECTED_GEOMETRY_HEAD:?}"
core_version=${QUALIFY_CORE_VERSION:?}
case "$core_version" in
    0.5.0) core_commit=f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f ;;
    0.5.1) core_commit=64d8a60b59acfe4334045280e430c4774b5cad89 ;;
    *) exit 1 ;;
esac

echo "Geometry: $EXPECTED_GEOMETRY_HEAD"
echo "Core: $core_version / $core_commit"
echo "Provider: ${QUALIFY_PROVIDER:?}"
echo "Runner image: ${ImageOS:-unknown} / ${ImageVersion:-unknown}"
uname -a
sw_vers
xcode-select -p
xcodebuild -version
sdk=$(xcrun --sdk macosx --show-sdk-path)
xcrun --sdk macosx --show-sdk-version
echo "Selected Xcode SDK: $sdk"
case "$sdk" in
    "$(xcode-select -p)"/Platforms/MacOSX.platform/Developer/SDKs/*) ;;
    *) echo 'Selected SDK is not inside Xcode'; exit 1 ;;
esac
pkgutil --pkg-info=com.apple.pkg.CLTools_Executables || true
clt=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/libSystem.tbd
if test -f "$clt"; then
    head -8 "$clt"
fi
alr -n toolchain

select_core() {
    if test "$core_version" = 0.5.0; then
        # Version-only selection: no Core source or path pin. Verify the
        # accepted origin in the lockfile as well as the resolved version.
        alr -n pin opencv_core=0.5.0
    else
        alr -n pin opencv_core \
            --use=https://github.com/zackboll/opencv_core_ada.git \
            --commit="$core_commit"
    fi
    alr -n with --solve
    alr -n -C tests with --solve
    grep -F "$core_commit" alire/alire.lock
    grep -F "$core_commit" tests/alire/alire.lock
    alr -n exec -- gnat --version
    alr -n exec -- gcc -v
    alr -n exec -- gcc -print-sysroot
    gnat_ld=$(alr -n exec -- gcc -print-prog-name=ld)
    echo "GNAT bundled linker: $gnat_ld"
    "$gnat_ld" -v || true
}

# Control uses the real pre-correction project and the same indexed Core,
# provider, runner and toolchain. A failure counts only if it is #112, not
# an unrelated compilation or dependency failure. On a future fixed image,
# report NOT_REPRODUCED rather than claiming the old/new comparison proved it.
if test "$core_version" = 0.5.0; then
    cd "$root/../baseline"
    test "$(git rev-parse HEAD)" = 2f5239a0e264ca2bb4106cdb338d3eac25abf674
    select_core
    if alr -n -C tests build -- -v -largs -Wl,-t \
        > "$evidence/baseline-link.log" 2>&1; then
        echo NOT_REPRODUCED | tee "$evidence/control-result.txt"
        echo '::warning::Old Geometry links on this image; affected-runner regression comparison remains unproven'
    else
        grep -E "${clt//./\\.}:[0-9]+:[0-9]+: error: unknown architecture" \
            "$evidence/baseline-link.log"
        grep -F 'arm64e.x1-macos' "$evidence/baseline-link.log"
        echo REPRODUCED_GNAT_FSF_112 | tee "$evidence/control-result.txt"
    fi
    cd "$root"
fi

select_core
cp alire/alire.lock "$evidence/library-alire.lock"
cp tests/alire/alire.lock "$evidence/tests-alire.lock"
alr -n build --release -- -v 2>&1 | tee "$evidence/production-build.log"
config=config/opencv_geometry_install.gpr
cp "$config" "$evidence/"
grep -F "Cxx_Sysroot := \"$sdk\";" "$config"
grep -F 'Shim_Build : Shim_Build_Kind := "External_Relocatable";' "$config"
grep -F 'Cxx_Toolchain : Cxx_Toolchain_Kind := "Apple_Clang";' "$config"
native=$(sed -n 's/.*Native_Geometry_Module := "\(.*\)";/\1/p' "$config")
major=$(sed -n 's/.*OpenCV_Major := "\(.*\)";/\1/p' "$config")
case "$major:$native" in 4:imgproc|5:geometry) ;; *) exit 1 ;; esac
library=$(sed -n 's/.*Library_Search_Switch := "-L\(.*\)";/\1/p' "$config")
case "$library" in "${EXPECTED_OPENCV_PREFIX:?}"/*) ;; *) exit 1 ;; esac

check_trace() {
    grep -F -- "--sysroot=$sdk" "$1"
    grep -F "$sdk/usr/lib/libSystem" "$1"
    if grep -E 'malformed file|unknown architecture|/Library/Developer/CommandLineTools/SDKs/' "$1"; then
        echo "Rejected SDK or CLT input in $1"
        exit 1
    fi
}

check_dependencies() {
    local binary=$1
    otool -L "$binary"
    otool -l "$binary" | grep -A4 LC_BUILD_VERSION
    otool -L "$binary" | grep -F /usr/lib/libSystem.B.dylib
}

shim=lib/libopencv_geometry_shim.dylib
otool -D "$shim" | grep -Fx '@rpath/libopencv_geometry_shim.dylib'
otool -L "$shim" | grep -F "$library/libopencv_$native."
otool -L "$shim" | grep -F "$library/libopencv_core."
otool -L "$shim" | grep -F /usr/lib/libc++
# GNAT's executable driver itself can link libstdc++; the isolation
# requirement applies to the externally compiled Geometry C++ shim.
if otool -L "$shim" | grep -E 'libopencv_core_shim|libstdc\+\+'; then exit 1; fi
check_dependencies "$shim"

# -v retains the actual gprbuild/GCC command. -t retains every linker input.
# Do not pass a sysroot through -largs: only the project may supply it.
alr -n -C tests build -- -v -largs -Wl,-t \
    2>&1 | tee "$evidence/corrected-tests-link.log"
check_trace "$evidence/corrected-tests-link.log"
check_dependencies tests/bin/tests
DYLD_PRINT_LIBRARIES=1 tests/bin/tests \
    > "$evidence/aunit.log" 2> "$evidence/aunit-dyld.log"
cat "$evidence/aunit.log"
grep -E '^Total Tests Run: *547$' "$evidence/aunit.log"
grep -E '^Successful Tests: *547$' "$evidence/aunit.log"
grep -E '^Failed Assertions: *0$' "$evidence/aunit.log"
grep -E '^Unexpected Errors: *0$' "$evidence/aunit.log"
grep -F libopencv_geometry_shim "$evidence/aunit-dyld.log"
physical_library=$(cd "$library" && pwd -P)
grep -F -e "$library/libopencv_$native." \
    -e "$physical_library/libopencv_$native." "$evidence/aunit-dyld.log"

# Exercise Library_Options too. Geometry's macOS C++ shim stays independently
# built; only the production Ada library changes to relocatable here.
OPENCV_GEOMETRY_LIBRARY_TYPE=relocatable alr -n exec -- \
    gprbuild -P opencv_geometry.gpr -p -f -v -largs -Wl,-t \
    2>&1 | tee "$evidence/relocatable-library-link.log"
check_trace "$evidence/relocatable-library-link.log"
check_dependencies lib/libopencv_geometry_ada.dylib

# Install a static-PIC Ada library with the external dylib shim, then build
# the existing independent Ada consumer through installed projects alone.
# Copy the shim explicitly: Externally_Built libraries are not installed by
# default. Never modify the generated installed GPRs or inject SDK switches.
alr -n exec -- gprbuild -P opencv_geometry.gpr -p -f
prefix="$evidence/installed"
alr -n exec -- gprinstall -P opencv_geometry.gpr -p -r --prefix="$prefix"
mkdir -p "$prefix/lib/opencv_geometry_shim"
cp "$shim" "$prefix/lib/opencv_geometry_shim/"
# GPRinstall preserves the established source-tree -L/rpath options. Do
# not rewrite those options for this SDK correction. Make their target
# unavailable so only installed project/library paths can satisfy the link
# and runtime loader; preserve the source artifacts for evidence afterwards.
mv "$root/lib" "$root/lib-standalone-unavailable"
trap 'mv "$root/lib-standalone-unavailable" "$root/lib"' EXIT
consumer="$evidence/consumer"
mkdir -p "$consumer"
cp tests/installed_consumers/ada_consumer.gpr \
    tests/installed_consumers/installed_geometry_consumer.adb \
    tests/installed_consumers/geometry_consumer_checks.ad[bs] "$consumer/"
# Obtain only toolchain access from Alire. env overrides its project search
# path, so gprbuild cannot resolve source projects via the Alire closure.
# Also leave the source working directory: GPRbuild searches its current
# directory before GPR_PROJECT_PATH, even with an absolute consumer -P.
for mode in installed relocated; do
    if test "$mode" = relocated; then
        moved="$evidence/relocated/a-longer-installation-root"
        mkdir -p "$moved"
        mv "$prefix" "$moved/prefix"
        prefix="$moved/prefix"
        rm -rf "${consumer:?}/obj-ada" "${consumer:?}/bin"
    fi
    # Positional parameters expand in the consumer shell, not this one.
    # shellcheck disable=SC2016
    alr -n exec -- env -u ADA_PROJECT_PATH -u ADA_INCLUDE_PATH -u ADA_OBJECTS_PATH \
        GPR_PROJECT_PATH="$prefix/share/gpr" \
        sh -c 'cd "$1"; shift; exec "$@"' sh "$consumer" \
        gprbuild -P ada_consumer.gpr -p -v -largs -Wl,-t \
        2>&1 | tee "$evidence/$mode-consumer-link.log"
    check_trace "$evidence/$mode-consumer-link.log"
    grep -F "$prefix/lib/opencv_geometry/libopencv_geometry_ada.a" \
        "$evidence/$mode-consumer-link.log"
    check_dependencies "$consumer/bin/installed_geometry_consumer"
    DYLD_PRINT_LIBRARIES=1 "$consumer/bin/installed_geometry_consumer" \
        > "$evidence/$mode-consumer-run.log" 2> "$evidence/$mode-consumer-dyld.log"
    cat "$evidence/$mode-consumer-run.log"
    grep -Fx 'consumer PASS installed Ada' "$evidence/$mode-consumer-run.log"
    grep -F "$prefix/lib/opencv_geometry_shim/libopencv_geometry_shim.dylib" \
        "$evidence/$mode-consumer-dyld.log"
    if grep -F "$root/" "$evidence/$mode-consumer-dyld.log"; then exit 1; fi
done
echo 'PASS standalone GPR SDK linking, 547/547 AUnit, installed and relocated consumers'