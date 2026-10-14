#!/bin/sh
# Stages a Debian 12 arm64 sysroot from real Debian packages, without
# installing them into the build host: the packages are downloaded and
# unpacked into NEW_SYSROOT, and every package, version and hash is
# recorded. Run as root in a disposable Debian 12 container.
#
# usage: prepare_debian12_sysroot.sh NEW_SYSROOT EVIDENCE
set -eu

fail() {
    echo "error: $*" >&2
    exit 1
}

test "$#" -eq 2 || fail "usage: prepare_debian12_sysroot.sh NEW_SYSROOT EVIDENCE"
sysroot=$1
evidence=$2
for path in "$sysroot" "$evidence"; do
    case "$path" in /?*) ;; *) fail "absolute path required: $path" ;; esac
done
test ! -e "$sysroot" || fail "sysroot already exists: $sysroot"
grep -qx 'VERSION_ID="12"' /etc/os-release || fail "Debian 12 required"

dpkg --add-architecture arm64
apt-get update > "$evidence/apt-update.log" 2>&1
# The OpenCV development closure, the C and C++ runtimes and libraries, and
# the GNAT 12 shared runtime needed only for emulated execution.
archives=$(mktemp -d)
apt-get -y --download-only --no-install-recommends \
    -o "Dir::Cache::archives=$archives" install \
    libopencv-dev:arm64 libc6-dev:arm64 libstdc++-12-dev:arm64 \
    libgnat-12:arm64 > "$evidence/apt-download.log" 2>&1 \
    || fail "package download failed; see $evidence/apt-download.log"
mkdir -p "$sysroot"
: > "$evidence/sysroot-packages.txt"
: > "$evidence/skipped-host-packages.txt"
candidates=$(mktemp)
for package in "$archives"/*.deb; do
    architecture=$(dpkg-deb -f "$package" Architecture)
    case "$architecture" in
        arm64|all) ;;
        *)
            # apt satisfies Multi-Arch: foreign dependencies (host tools and
            # data) with the host architecture, together with their own
            # host dependencies. None is unpacked into the target sysroot;
            # each is recorded. The cross validator separately proves that
            # every target library dependency resolves inside the sysroot.
            printf '%s %s %s %s\n' "$(dpkg-deb -f "$package" Package)" \
                "$(dpkg-deb -f "$package" Version)" "$architecture" \
                "$(sha256sum "$package" | cut -d ' ' -f 1)" \
                >> "$evidence/skipped-host-packages.txt"
            continue
            ;;
    esac
    printf '%s %s %s %s\n' "$(dpkg-deb -f "$package" Package)" \
        "$(dpkg-deb -f "$package" Version)" "$architecture" \
        "$(sha256sum "$package" | cut -d ' ' -f 1)" \
        >> "$evidence/sysroot-packages.txt"
    dpkg-deb -x "$package" "$sysroot"
    # Unpacking runs no maintainer script. Collect the shared-library
    # alternatives that postinst would register (for example libblas.so.3),
    # as "link path priority package".
    control=$(mktemp -d)
    dpkg-deb -e "$package" "$control"
    if [ -f "$control/postinst" ]; then
        sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$control/postinst" \
            | grep -E '^[[:space:]]*update-alternatives[[:space:]]+--install' \
            | while read -r _ _ link _ path priority _; do
                case "$link" in
                    /lib/*.so.*|/usr/lib/*.so.*)
                        printf '%s %s %s %s\n' "$link" "$path" "$priority" \
                            "$(dpkg-deb -f "$package" Package)"
                        ;;
                esac
            done >> "$candidates"
    fi
    rm -rf "$control"
done
rm -rf "$archives"
# Apply the highest-priority alternative for each library link, as a
# relative link inside the sysroot, and record it.
: > "$evidence/sysroot-alternatives.txt"
LC_ALL=C sort -k1,1 -k3,3nr "$candidates" | awk '!seen[$1]++' \
    | while read -r link path priority owner; do
        test -e "$sysroot$path" || fail "alternative target missing: $path"
        test ! -e "$sysroot$link" || fail "alternative link exists: $link"
        relative=$(realpath --relative-to="$(dirname "$sysroot$link")" \
            "$sysroot$path")
        ln -s "$relative" "$sysroot$link"
        printf '%s -> %s (priority %s, %s)\n' "$link" "$relative" \
            "$priority" "$owner" >> "$evidence/sysroot-alternatives.txt"
    done
rm -f "$candidates"
LC_ALL=C sort -o "$evidence/sysroot-packages.txt" \
    "$evidence/sysroot-packages.txt"
cp /etc/apt/sources.list.d/debian.sources "$evidence/apt-sources.txt" \
    2>/dev/null || true
test -f "$sysroot/usr/lib/aarch64-linux-gnu/pkgconfig/opencv4.pc" \
    || fail "the staged sysroot has no opencv4.pc"
echo "staged $(wc -l < "$evidence/sysroot-packages.txt") packages into $sysroot"
