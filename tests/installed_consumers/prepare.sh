#!/bin/sh
# Stage 1 of the Debian 12 GNAT 12 installed-consumer qualification.
#
# Runs in a Debian 12 builder container with native GNAT 12.2.0, GPRbuild
# and OpenCV 4.6.0:
#   1. builds and tests the exact Geometry and Core revisions
#      (tests/gnat12/run_production.sh, release profile);
#   2. installs Core into a clean prefix with GPRinstall;
#   3. builds Geometry from a fresh export against the installed Core only;
#   4. installs Geometry into a second clean prefix without reinstalling
#      Core;
#   5. verifies the installed projects, ALIs, libraries and dependencies;
#   6. stages the two prefixes, the consumer sources and consume.sh in the
#      payload for the separate consumer stage.
#
# Inputs: the GNAT12_* variables of tests/gnat12/run_production.sh, plus
#   CONSUMER_PAYLOAD  absolute payload directory; must not exist
#   CONSUMER_LOGS     absolute evidence directory; must not exist
set -eu

fail() {
    echo "error: $*" >&2
    exit 1
}

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=${GNAT12_SOURCE_ROOT:-$(CDPATH='' cd -- "$here/../.." && pwd)}
work=${GNAT12_WORK:?set GNAT12_WORK to a fresh absolute directory}
payload=${CONSUMER_PAYLOAD:?set CONSUMER_PAYLOAD to a fresh absolute directory}
logs=${CONSUMER_LOGS:?set CONSUMER_LOGS to a fresh absolute directory}

for path in "$payload" "$logs"; do
    case "$path" in
        /) fail "filesystem root is not an acceptable path" ;;
        /*) ;;
        *) fail "absolute path required: $path" ;;
    esac
    test ! -e "$path" || fail "already exists: $path"
done
for left in "$work" "$payload" "$logs" "$root"; do
    for right in "$work" "$payload" "$logs" "$root"; do
        test "$left" = "$right" && continue
        case "$left/" in "$right/"*) fail "$left overlaps $right" ;; esac
    done
done

# 1. Production build, complete AUnit suite and native tests.
GNAT12_SOURCE_ROOT=$root GNAT12_PROFILES=release \
    sh "$here/../gnat12/run_production.sh"
mkdir -p "$logs"
cp -a "$work/logs" "$logs/production"

unset GPR_PROJECT_PATH ADA_PROJECT_PATH ADA_INCLUDE_PATH ADA_OBJECTS_PATH
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH GCC_EXEC_PREFIX
unset COMPILER_PATH LD_LIBRARY_PATH ADAFLAGS

core_prefix=$payload/core-prefix
geometry_prefix=$payload/geometry-prefix
mkdir -p "$payload"

# 2. Core, from the tree that was just built and tested.
cd "$work/core"
gprinstall -P opencv_core.gpr -p -r --prefix="$core_prefix" \
    > "$logs/core-install.log" 2>&1 || fail "Core installation failed"

# 3. Geometry from a fresh export, resolving Core only through its
#    installed project.
build=$work/installed-build/geometry
mkdir -p "$build"
git -c "safe.directory=$root" -C "$root" archive HEAD | tar -x -C "$build"
mkdir -p "$build/config"
cp "$here/../gnat12/opencv_geometry_config.gpr" "$build/config/"
cd "$build"
sh scripts/configure_opencv.sh > "$logs/geometry-configure.log" 2>&1
GPR_PROJECT_PATH=$core_prefix/share/gpr \
    gprbuild -P opencv_geometry.gpr -p -j0 -v \
    -XGEOMETRY_GNAT12_PROFILE=release \
    > "$logs/geometry-build-installed-core.log" 2>&1 \
    || fail "Geometry build against the installed Core failed"
if grep -n 'warning:' "$logs/geometry-build-installed-core.log"; then
    fail "compiler warnings building against the installed Core"
fi
# gprbuild passes search paths through mapping files; gprls -v reports
# the source and object search paths that the build resolved.
GPR_PROJECT_PATH=$core_prefix/share/gpr \
    gprls -v -P opencv_geometry.gpr -XGEOMETRY_GNAT12_PROFILE=release \
    > "$logs/geometry-installed-core-gprls.log" 2>&1 \
    || fail "gprls failed for the installed-Core build"
for directory in "$core_prefix/include/opencv_core/" \
    "$core_prefix/lib/opencv_core/"; do
    grep -Fqx "   $directory" "$logs/geometry-installed-core-gprls.log" \
        || fail "the build did not resolve $directory"
done
if grep -F "$work/core/" "$logs/geometry-installed-core-gprls.log" \
    "$logs/geometry-build-installed-core.log"; then
    fail "the build used the Core build tree"
fi

# 4. Geometry and its C++ shim into their own prefix; Core is not
#    reinstalled.
for project in opencv_geometry_shim opencv_geometry; do
    GPR_PROJECT_PATH=$core_prefix/share/gpr \
        gprinstall -P "$project.gpr" -p --prefix="$geometry_prefix" \
        -XGEOMETRY_GNAT12_PROFILE=release \
        > "$logs/$project-install.log" 2>&1 \
        || fail "installation of $project failed"
done

# 5. Installed content.
for file in \
    "$core_prefix/share/gpr/opencv_core.gpr" \
    "$geometry_prefix/share/gpr/opencv_geometry.gpr" \
    "$geometry_prefix/share/gpr/opencv_geometry_shim.gpr" \
    "$geometry_prefix/include/opencv_geometry/opencv-geometry.ads" \
    "$geometry_prefix/include/opencv_geometry/opencv-geometry-subdiv2d.ads" \
    "$geometry_prefix/lib/opencv_geometry/libopencv_geometry_ada.a" \
    "$geometry_prefix/lib/opencv_geometry/opencv-geometry.ali" \
    "$geometry_prefix/lib/opencv_geometry_shim/libopencv_geometry_shim.a"
do
    test -f "$file" || fail "missing installed file: $file"
done
if find "$core_prefix" -name '*geometry*' | grep .; then
    fail "Geometry content installed into the Core prefix"
fi
if find "$geometry_prefix" \( -name 'opencv_core*' -o -name 'opencv-core*' \
    -o -name 'libopencv_core*' \) | grep .; then
    fail "Core content installed into the Geometry prefix"
fi
for gpr in "$core_prefix"/share/gpr/*.gpr "$geometry_prefix"/share/gpr/*.gpr
do
    echo "=== $gpr"
    cat "$gpr"
done > "$logs/installed-projects.log"
if grep -nE "$work|$payload|$root|/sources/" "$core_prefix"/share/gpr/*.gpr \
    "$geometry_prefix"/share/gpr/*.gpr; then
    fail "installed project files name build, source or payload paths"
fi
shim_gpr=$geometry_prefix/share/gpr/opencv_geometry_shim.gpr
for option in -lopencv_imgproc -lopencv_core -lstdc++; do
    grep -Fq "\"$option\"" "$shim_gpr" \
        || fail "installed shim project lacks $option"
done
# GPRinstall withs every library project of the static closure, so the
# installed Geometry projects name opencv_core_shim through opencv_core,
# which needs it in any case. Geometry itself must not link Core's shim:
# no such linker option, and no reference from the Geometry shim objects
# (checked with nm below).
if grep -E 'Linker_Options.*core_shim' "$geometry_prefix"/share/gpr/*.gpr
then
    fail "installed Geometry projects link Core's C++ shim"
fi
find "$geometry_prefix" "$core_prefix" -name '*.ali' > "$logs/installed-alis.txt"
while read -r ali; do
    test "$(head -n 1 "$ali")" = 'V "GNAT Lib v12"' \
        || fail "installed ALI not produced by GNAT 12: $ali"
done < "$logs/installed-alis.txt"
find "$geometry_prefix" "$core_prefix" -name '*.a' | while read -r library
do
    readelf -p .comment "$library" | grep -o 'GCC: .*'
done | sort | uniq -c > "$logs/installed-library-compilers.txt"
if grep -v 'GCC: (Debian 12.2.0-14+deb12u1) 12.2.0' \
    "$logs/installed-library-compilers.txt"; then
    fail "installed libraries contain objects from another compiler"
fi
nm -C --undefined-only \
    "$geometry_prefix/lib/opencv_geometry_shim/libopencv_geometry_shim.a" \
    > "$logs/shim-undefined-symbols.txt"
if grep -E 'opencv_core_|OpenCV_Core_' "$logs/shim-undefined-symbols.txt"
then
    fail "Geometry shim refers to Core's C++ shim"
fi

# 6. Payload for the consumer stage.
mkdir -p "$payload/consumers"
cp "$here/ada_consumer.gpr" "$here/mixed_consumer.gpr" \
    "$here/geometry_consumer_checks.ads" "$here/geometry_consumer_checks.adb" \
    "$here/installed_geometry_consumer.adb" \
    "$here/installed_mixed_consumer.adb" "$here/application.cpp" \
    "$payload/consumers/"
cp "$here/consume.sh" "$payload/consume.sh"
{
    echo "geometry: $(git -c "safe.directory=$root" -C "$root" rev-parse HEAD)"
    echo "core: ${GNAT12_CORE_COMMIT}"
    echo "builder-payload: $payload"
} > "$payload/identity.txt"
(cd "$payload" && find . | LC_ALL=C sort) > "$logs/payload-inventory.txt"
(cd "$payload" && find . -type f -print0 | LC_ALL=C sort -z \
    | xargs -0 sha256sum) > "$logs/payload-sha256.txt"
echo "PASS prepared installed Core and Geometry prefixes in $payload"
