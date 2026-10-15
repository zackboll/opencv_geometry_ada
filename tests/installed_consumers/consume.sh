#!/bin/sh
# Stage 2 of the Debian 12 GNAT 12 installed-consumer qualification.
#
# Runs in a separate Debian 12 container that has native GNAT 12.2.0,
# GPRbuild, g++ and OpenCV 4.6.0, but no Core or Geometry source checkout
# and no Alire. Projects resolve only through the installed prefixes'
# share/gpr directories. Independent Ada and mixed Ada/C++ consumers are
# built with plain gprbuild, run, and inspected; then both prefixes are
# moved to new, longer paths and the consumers are rebuilt from fresh
# object directories and checked again. The Geometry prefix must carry the
# verified redistribution notices in both places. Installed files are never
# edited.
#
# usage: consume.sh PAYLOAD LOGS
#   PAYLOAD  directory written by prepare.sh
#   LOGS     absolute evidence directory; must not exist
set -eu

fail() {
    echo "error: $*" >&2
    exit 1
}

test "$#" -eq 2 || fail "usage: consume.sh PAYLOAD LOGS"
payload=$1
logs=$2
case "$payload" in /*) ;; *) fail "absolute payload path required" ;; esac
case "$logs" in /*) ;; *) fail "absolute log path required" ;; esac
test ! -e "$logs" || fail "log directory already exists: $logs"
test -f "$payload/identity.txt" || fail "not a prepared payload: $payload"

# Independence from the build environment.
if command -v alr >/dev/null 2>&1; then
    fail "Alire is present in the consumer environment"
fi
test ! -e /sources || fail "a source checkout is mounted at /sources"
# Installed prefixes legitimately contain Ada bodies; any other copy of
# these units means a source tree is reachable.
for unit in opencv-geometry.adb opencv_geometry_shim.cpp opencv-core.adb \
    opencv_geometry.gpr opencv_core.gpr
do
    if find / -xdev -path "$payload" -prune -o -name "$unit" -print 2>/dev/null \
        | grep .; then
        fail "a Core or Geometry source tree is present"
    fi
done
unset GPR_PROJECT_PATH ADA_PROJECT_PATH ADA_INCLUDE_PATH ADA_OBJECTS_PATH
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH GCC_EXEC_PREFIX
unset COMPILER_PATH LD_LIBRARY_PATH ADAFLAGS ALIRE
unset OPENCV_CORE_ALIRE_PREFIX OPENCV_GEOMETRY_ALIRE_PREFIX

test "$(gcc -dumpfullversion)" = 12.2.0 || fail "gcc is not 12.2.0"
test "$(g++ -dumpfullversion)" = 12.2.0 || fail "g++ is not 12.2.0"
test "$(gcc -print-file-name=adalib)" = /usr/lib/gcc/x86_64-linux-gnu/12/adalib \
    || fail "gcc does not use the Debian GNAT 12 runtime"
test "$(pkg-config --modversion opencv4)" = 4.6.0 || fail "OpenCV is not 4.6.0"
include=$(pkg-config --cflags-only-I opencv4 | tr ' ' '\n' | grep '^-I' | head -n 1)
test -n "$include" || fail "no OpenCV include directory"

mkdir -p "$logs"
{
    cat "$payload/identity.txt"
    cat /etc/os-release
    gcc --version
    gprbuild --version
    pkg-config --modversion opencv4
} > "$logs/consumer-environment.log" 2>&1

core=$payload/core-prefix
geometry=$payload/geometry-prefix
original_core=$core
original_geometry=$geometry

# Linux installs are static-PIC only. gprbuild gives consumers
# $ORIGIN-relative run paths to every library directory of the closure;
# with no shared object in either prefix, those paths can load nothing.
if find "$core" "$geometry" \( -name '*.so' -o -name '*.so.*' \) | grep .
then
    fail "shared objects in the installed prefixes"
fi

for mode in installed relocated; do
    if [ "$mode" = relocated ]; then
        moved=$payload/relocated/a-longer-installation-root
        mkdir -p "$moved"
        mv "$core" "$moved/core-prefix-b"
        mv "$geometry" "$moved/geometry-prefix-b"
        core=$moved/core-prefix-b
        geometry=$moved/geometry-prefix-b
        test ! -e "$original_core" || fail "Core prefix was not moved"
        test ! -e "$original_geometry" || fail "Geometry prefix was not moved"
    fi
    if grep -rnE '/work/|/sources/|/evidence/|/tmp/' \
        "$core/share/gpr" "$geometry/share/gpr"; then
        fail "installed project files name build or source paths"
    fi
    if grep -rnF -e "$original_core" -e "$original_geometry" \
        "$core/share/gpr" "$geometry/share/gpr"; then
        fail "installed project files name an absolute prefix"
    fi
    # The redistribution notices travel with the Geometry prefix:
    # byte-identical to the copies prepare.sh verified against the sources.
    for name in LICENSE THIRD_PARTY_NOTICES; do
        notice=$geometry/share/doc/opencv_geometry/$name
        test -f "$notice" || fail "$mode Geometry prefix lacks $name"
        expected=$(awk -v path="geometry-prefix/share/doc/opencv_geometry/$name" \
            '$2 == path { print $1 }' "$payload/notices.sha256")
        test -n "$expected" || fail "no verified digest recorded for $name"
        actual=$(sha256sum < "$notice" | cut -d ' ' -f 1)
        test "$actual" = "$expected" \
            || fail "$mode $name differs from the verified notice"
        echo "$actual  $notice" >> "$logs/$mode-notices.log"
    done

    run=$payload/run-$mode
    mkdir -p "$run"
    cp "$payload"/consumers/* "$run/"
    export GPR_PROJECT_PATH="$core/share/gpr:$geometry/share/gpr"
    cd "$run"
    gprbuild -P ada_consumer.gpr -p -v > "$logs/$mode-ada-build.log" 2>&1 \
        || fail "$mode Ada consumer build failed"
    gprbuild -P mixed_consumer.gpr -p -v "-XCONSUMER_OPENCV_INCLUDE=$include" \
        > "$logs/$mode-mixed-build.log" 2>&1 \
        || fail "$mode mixed consumer build failed"
    for kind in ada mixed; do
        gprls -v -P "${kind}_consumer.gpr" \
            "-XCONSUMER_OPENCV_INCLUDE=$include" \
            > "$logs/$mode-$kind-gprls.log" 2>&1 \
            || fail "gprls failed for the $mode $kind consumer"
    done
    unset GPR_PROJECT_PATH

    for kind in ada mixed; do
        build_log=$logs/$mode-$kind-build.log
        gprls_log=$logs/$mode-$kind-gprls.log
        if grep -n 'warning:' "$build_log"; then
            fail "$mode $kind consumer build has warnings"
        fi
        # gprbuild passes search paths through mapping files; gprls -v
        # reports what the build resolved.
        for directory in "$core/include/opencv_core/" \
            "$core/lib/opencv_core/" "$geometry/include/opencv_geometry/" \
            "$geometry/lib/opencv_geometry/"
        do
            grep -Fqx "   $directory" "$gprls_log" \
                || fail "$mode $kind consumer did not resolve $directory"
        done
        grep -Fq "$geometry/lib/opencv_geometry_shim/" "$build_log" \
            || fail "$mode $kind consumer did not link the installed shim"
        if [ "$mode" = relocated ] && grep -F -e "$original_core/" \
            -e "$original_geometry/" "$build_log" "$gprls_log"; then
            fail "relocated $kind consumer refers to the original prefixes"
        fi
    done

    for program in installed_geometry_consumer installed_mixed_consumer; do
        run_log=$logs/$mode-$program-run.log
        "bin/$program" > "$run_log" 2>&1 || fail "$mode $program failed"
        grep -q '^consumer PASS' "$run_log" || fail "$mode $program did not pass"
        if grep -q '^FAIL' "$run_log"; then
            fail "$mode $program reported a failed check"
        fi
        elf_log=$logs/$mode-$program-elf.log
        readelf -h -d -W "bin/$program" > "$elf_log"
        readelf -p .comment "bin/$program" >> "$elf_log"
        grep -q 'Advanced Micro Devices X86-64' "$elf_log" \
            || fail "$program is not an x86-64 executable"
        if grep -E 'GCC: ' "$elf_log" | grep -v ' 12\.2\.0$'; then
            fail "$program contains code from another compiler"
        fi
        if grep -E '\((RPATH|RUNPATH)\)' "$elf_log" \
            | grep -E "$payload|/work/|/sources/"; then
            fail "$program has a run path into the build or payload"
        fi
        ldd_log=$logs/$mode-$program-ldd.log
        ldd -r "bin/$program" > "$ldd_log" 2>&1
        if grep -E 'not found|undefined symbol' "$ldd_log"; then
            fail "$program has unresolved dependencies"
        fi
        for needed in libopencv_imgproc.so.406 libopencv_core.so.406 \
            libstdc++.so.6 libgnat-12.so
        do
            grep -q "$needed => /usr/lib/x86_64-linux-gnu/" "$ldd_log" \
                || fail "$program does not resolve $needed from the system"
        done
        if grep -o '=> /[^ ]*' "$ldd_log" \
            | grep -vE '=> /(usr/)?lib(64)?/'; then
            fail "$program loads a library from outside the system directories"
        fi
    done
    cd "$payload"
done

echo "PASS independent Ada and mixed Ada/C++ consumers and redistribution" \
    "notices, installed and relocated, without sources or Alire"
