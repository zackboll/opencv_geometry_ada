#!/bin/sh
# Installs the public Debian 12 AArch64 cross reference tools into a
# disposable Debian 12 container. Shared by tests/cross/Containerfile and
# .github/workflows/debian-aarch64-reference.yml.
#
# Debian's gnat-12-aarch64-linux-gnu is reference evidence only; it is not
# the AdaCore GNAT 12 toolchain and not a Yocto Scarthgap sysroot. Debian
# 12's GPRconfig 2023 does not recognize Debian's cross GNAT, so the project
# tools come from the public GPRbuild 26.0.0-1 x86_64 release that the
# Alire index lists for gprbuild=26.0.1, verified by its index hash. It
# contains no compiler. No native compiler is installed.
set -eu

url=https://github.com/alire-project/GNAT-FSF-builds/releases/download/gprbuild-26.0.0-1/gprbuild-x86_64-linux-26.0.0-1.tar.gz
sha256=e3f27f2515ec04d963f6badade6595993b1c091ba15d1919a7c75aad1b7ed49b

grep -qx 'VERSION_ID="12"' /etc/os-release
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git python3 pkg-config binutils file \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu gnat-12-aarch64-linux-gnu \
    qemu-user-static
rm -rf /var/lib/apt/lists/*
curl --fail --location --output /tmp/gprbuild.tar.gz "$url"
echo "$sha256  /tmp/gprbuild.tar.gz" | sha256sum -c -
mkdir -p /opt/gprbuild-26
tar -xzf /tmp/gprbuild.tar.gz -C /opt/gprbuild-26 --strip-components=1
rm /tmp/gprbuild.tar.gz
for program in gprbuild gprconfig gprinstall; do
    test -x "/opt/gprbuild-26/bin/$program"
done
for host in gcc g++ gnat gnatmake gprbuild; do
    if command -v "$host" >/dev/null 2>&1; then
        echo "error: host tool on PATH: $host" >&2
        exit 1
    fi
done
