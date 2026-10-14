#!/bin/sh
# Debian 12 native GNAT 12 production and runtime qualification of
# opencv_geometry, independent of Alire toolchain selection.
#
# Builds the complete production library and C++ shim in each Alire build
# profile (release, validation, development), runs the complete AUnit suite
# against each, and runs the native sanitizer and fault-injection tests.
# Core is exported from an exact commit and built with Alire's release
# switch set. AUnit is built from its unpacked sources. tests/alire.toml,
# with its GNATprove and GNATcov dependencies, is not used.
#
# Inputs:
#   GNAT12_WORK         absolute workspace; must not exist
#   GNAT12_CORE_ROOT    clean opencv_core Git checkout
#   GNAT12_CORE_COMMIT  40-hex Core commit expected at GNAT12_CORE_ROOT
#   GNAT12_AUNIT_ROOT   unpacked AUnit 26.0.0 sources (lib/gnat/aunit.gpr)
#   GNAT12_SOURCE_ROOT  clean Geometry Git checkout (default: this one)
#   GNAT12_PROFILES     optional subset of "release validation development",
#                       in order (default: all three)
#
# Prints PASS on success; any failed check exits nonzero.
set -eu

expected_tests=542
expected_opencv=4.6.0
expected_gcc=12.2.0
expected_ada_lib='V "GNAT Lib v12"'

fail() {
    echo "error: $*" >&2
    exit 1
}

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=${GNAT12_SOURCE_ROOT:-$(CDPATH='' cd -- "$here/../.." && pwd)}
work=${GNAT12_WORK:?set GNAT12_WORK to a fresh absolute directory}
core_root=${GNAT12_CORE_ROOT:?set GNAT12_CORE_ROOT to a Core checkout}
core_commit=${GNAT12_CORE_COMMIT:?set GNAT12_CORE_COMMIT to the Core commit}
aunit=${GNAT12_AUNIT_ROOT:?set GNAT12_AUNIT_ROOT to AUnit 26 sources}

for path in "$work" "$root" "$core_root" "$aunit"; do
    case "$path" in
        /) fail "filesystem root is not an acceptable path" ;;
        /*) ;;
        *) fail "absolute path required: $path" ;;
    esac
done
for source in "$root" "$core_root" "$aunit"; do
    case "$work/" in "$source/"*) fail "workspace overlaps $source" ;; esac
    case "$source/" in "$work/"*) fail "$source overlaps workspace" ;; esac
done
test ! -e "$work" || fail "workspace already exists: $work"
test -f "$root/opencv_geometry.gpr" || fail "not a Geometry checkout: $root"
test -f "$core_root/opencv_core.gpr" || fail "not a Core checkout: $core_root"
test -f "$aunit/lib/gnat/aunit.gpr" || fail "not AUnit sources: $aunit"
printf '%s\n' "$core_commit" | grep -Eqx '[0-9a-f]{40}' \
    || fail "GNAT12_CORE_COMMIT is not a full commit id: $core_commit"
profiles=${GNAT12_PROFILES:-release validation development}
profile_count=0
for profile in $profiles; do
    case "$profile" in
        release|validation|development) ;;
        *) fail "unknown build profile: $profile" ;;
    esac
    profile_count=$((profile_count + 1))
done
test "$profile_count" -gt 0 || fail "no build profile selected"
first_profile=${profiles%% *}

# Exact, clean source identities. safe.directory is limited to the two
# checkouts; container checkouts are often owned by another user.
git_in() {
    repo=$1
    shift
    git -c "safe.directory=$repo" -C "$repo" "$@"
}
geometry_commit=$(git_in "$root" rev-parse HEAD)
test "$(git_in "$core_root" rev-parse HEAD)" = "$core_commit" \
    || fail "Core checkout is not at $core_commit"
for repo in "$root" "$core_root"; do
    if [ -n "$(git_in "$repo" status --porcelain --untracked-files=all)" ]
    then
        fail "checkout has modified or untracked files: $repo"
    fi
done

# Native Debian 12 compiler, matching runtime and OpenCV.
test "$(gcc -dumpfullversion)" = "$expected_gcc" || fail "gcc is not $expected_gcc"
test "$(gcc -dumpmachine)" = x86_64-linux-gnu || fail "gcc target is not x86_64-linux-gnu"
test "$(g++ -dumpfullversion)" = "$expected_gcc" || fail "g++ is not $expected_gcc"
test "$(gcc -print-file-name=adalib)" = /usr/lib/gcc/x86_64-linux-gnu/12/adalib \
    || fail "gcc does not use the Debian GNAT 12 runtime"
command -v gprbuild >/dev/null || fail "gprbuild is required"
test "$(pkg-config --modversion opencv4)" = "$expected_opencv" \
    || fail "OpenCV is not $expected_opencv"

unset GPR_PROJECT_PATH ADA_PROJECT_PATH ADA_INCLUDE_PATH ADA_OBJECTS_PATH
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH GCC_EXEC_PREFIX
unset COMPILER_PATH LD_LIBRARY_PATH ADAFLAGS

logs=$work/logs
mkdir -p "$logs" "$work/geometry-source" "$work/core" "$work/aunit"
git_in "$root" archive HEAD | tar -x -C "$work/geometry-source"
git_in "$core_root" archive "$core_commit" | tar -x -C "$work/core"
cp -a "$aunit/." "$work/aunit/"

# No previously built Ada or C++ artifact may enter the workspace.
prebuilt=$(find "$work" \( -name '*.ali' -o -name '*.o' -o -name '*.a' \
    -o -name '*.so' -o -name '*.so.*' \) -print)
test -z "$prebuilt" || fail "prebuilt artifacts in the workspace: $prebuilt"

{
    echo "geometry: $geometry_commit"
    echo "core: $core_commit"
    echo "aunit: $(sed -n 's/^version = //p' "$aunit/alire.toml")"
    cat /etc/os-release
    gcc --version
    g++ --version
    gnatls -v
    gprbuild --version
    pkg-config --modversion opencv4
    dpkg-query -W gnat-12 gcc-12 g++-12 libgnat-12 gprbuild libopencv-dev \
        libopencv-core406 libopencv-imgproc406
} > "$logs/identities.log" 2>&1

cd "$work/core"
mkdir -p config
cp "$here/opencv_core_config.gpr" config/
sh scripts/configure_opencv.sh > "$logs/core-configure.log" 2>&1

# Compile-only checks over a gprbuild -v log: no warning of any kind, and
# no language-version switch except Core's documented per-unit Ada 2022
# typed-access body.
check_build_log() {
    if grep -n 'warning:' "$1"; then
        fail "compiler warnings in $1"
    fi
    language=$(grep -E ' -c .*-gnat(83|95|05|2005|12|2012|22|2022|X)( |$)' "$1" \
        | grep -v 'opencv-core-internal-typed_access\.adb' || true)
    test -z "$language" || fail "unexpected language switch in $1: $language"
}

check_results() {
    run_log=$1
    grep -qx "Total Tests Run:   $expected_tests" "$run_log" \
        || fail "expected $expected_tests registered tests in $run_log"
    grep -qx "Successful Tests:  $expected_tests" "$run_log" \
        || fail "not every test passed in $run_log"
    grep -qx 'Failed Assertions: 0' "$run_log" || fail "failures in $run_log"
    grep -qx 'Unexpected Errors: 0' "$run_log" || fail "errors in $run_log"
}

for profile in $profiles; do
    geometry=$work/$profile/geometry
    mkdir -p "$work/$profile"
    cp -a "$work/geometry-source" "$geometry"
    mkdir -p "$geometry/config" "$geometry/tests/config"
    cp "$here/opencv_geometry_config.gpr" "$geometry/config/"
    cp "$here/tests_config.gpr" "$geometry/tests/config/"
    cd "$geometry"
    sh scripts/configure_opencv.sh > "$logs/$profile-configure.log" 2>&1

    install=config/opencv_geometry_install.gpr
    grep -q 'OpenCV_Major := "4";' "$install" || fail "OpenCV 4 not selected"
    grep -q 'Native_Geometry_Module := "imgproc";' "$install" \
        || fail "imgproc backend not selected"
    grep -q 'OpenCV_Geometry_Link_Option := "-lopencv_imgproc";' "$install" \
        || fail "native imgproc library not linked"
    grep -q 'OpenCV_Core_Link_Option := "-lopencv_core";' "$install" \
        || fail "native core library not linked"
    grep -q 'Shim_Build : Shim_Build_Kind := "Static_PIC";' "$install" \
        || fail "Linux shim is not Static_PIC"

    export GPR_PROJECT_PATH="$work/core:$work/aunit/lib/gnat:$geometry"
    gprbuild -P opencv_geometry.gpr -p -j0 -v \
        "-XGEOMETRY_GNAT12_PROFILE=$profile" \
        > "$logs/$profile-production.log" 2>&1 \
        || fail "production build failed ($profile)"
    check_build_log "$logs/$profile-production.log"
    test -f lib/libopencv_geometry_ada.a || fail "no production library"
    test -f lib/libopencv_geometry_shim.a || fail "no C++ shim library"

    gprbuild -P tests/tests.gpr -p -j0 -v \
        "-XGEOMETRY_GNAT12_PROFILE=$profile" \
        > "$logs/$profile-aunit-build.log" 2>&1 \
        || fail "AUnit harness build failed ($profile)"
    check_build_log "$logs/$profile-aunit-build.log"
    tests/bin/tests > "$logs/$profile-aunit-run.log" 2>&1 \
        || fail "AUnit suite failed ($profile)"
    check_results "$logs/$profile-aunit-run.log"
    unset GPR_PROJECT_PATH
done

# Core is compiled once, by the first production build. Its one Ada 2022
# unit proves that the language-switch scan above reads compile commands.
grep -Eq ' -c .*-gnat2022 .*opencv-core-internal-typed_access\.adb' \
    "$logs/$first_profile-production.log" \
    || fail "Core typed-access compile command not found in the build log"

# Native shim tests under AddressSanitizer and UndefinedBehaviorSanitizer,
# including Subdiv2D allocation-failure injection.
cd "$work/release/geometry"
sh scripts/run_native_tests.sh > "$logs/native.log" 2>&1 \
    || fail "native tests failed"
test "$(grep -c '^Running ' "$logs/native.log")" -eq \
    "$(find tests/native -maxdepth 1 -name '*.cpp' | wc -l)" \
    || fail "not every native test ran"

# Every Ada library information file and every object in the workspace
# was produced by this GNAT 12.
find "$work" -name '*.ali' > "$logs/ali-files.txt"
test -s "$logs/ali-files.txt" || fail "no ALI files were produced"
while read -r ali; do
    test "$(head -n 1 "$ali")" = "$expected_ada_lib" \
        || fail "ALI not produced by GNAT 12: $ali"
done < "$logs/ali-files.txt"
find "$work" \( -name '*.o' -o -name '*.a' \) > "$logs/object-files.txt"
while read -r object; do
    readelf -p .comment "$object" 2>/dev/null | grep -o 'GCC: .*'
done < "$logs/object-files.txt" | sort | uniq -c > "$logs/object-compilers.txt"
if grep -v "GCC: (Debian $expected_gcc-14+deb12u1) $expected_gcc" \
    "$logs/object-compilers.txt"; then
    fail "objects from another compiler"
fi
for program in "$work"/*/geometry/tests/bin/tests; do
    readelf -p .comment "$program" | grep -o 'GCC: .*' | sort -u
    ldd -r "$program"
done > "$logs/executables.log" 2>&1
if grep -E 'GCC: ' "$logs/executables.log" | grep -v " $expected_gcc\$"; then
    fail "executables contain code from another compiler"
fi
if grep -E 'not found|undefined symbol' "$logs/executables.log"; then
    fail "unresolved executable dependencies"
fi

echo "PASS GNAT $expected_gcc production, $expected_tests/$expected_tests AUnit" \
    "in $profile_count profile(s) ($profiles), native tests;" \
    "Geometry $geometry_commit, Core $core_commit"
