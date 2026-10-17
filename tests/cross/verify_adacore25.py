#!/usr/bin/env python3
"""Separate GNAT Pro 25.2 / official Scarthgap 5.0 eSDK evidence gate.

The original GNAT 12 verifier is deliberately unchanged. This profile also
supports the official minimal eSDK whose assembled sysroot has no os-release:
authenticate its installer against the official SHA-256, then authenticate
the cached glibc/GCC runtime archives *inside* that installer and compare
their actual target libraries with the supplied sysroot. A provenance JSON
or a locally invented os-release is not sufficient evidence.
"""
import hashlib
import importlib.util
import json
import lzma
import os
from pathlib import Path
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "cross", ROOT / "scripts/cross_geometry.py")
cross = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cross)

# Official HTTPS checksum sidecar for the 5.0 qemuarm64 minimal eSDK.
SDK_SHA256 = "70503a72aef10546fc2186e9f61155a8e7a4e5715824495d52136bb9f976edc3"
POKY_REVISION = "fb91a49387cfb0c8d48303bb3354325ba2a05587"


def sdk_identity(installer, sdk, sysroot):
    cross.require(cross.digest(installer) == SDK_SHA256,
                  "official Scarthgap SDK installer checksum mismatch")
    cross.require(sysroot == cross.resolved(sdk / "tmp/sysroots/qemuarm64"),
                  "sysroot is not the assembled official qemuarm64 SDK")
    cached = {}
    with installer.open("rb") as stream:
        for line in stream:
            if line == b"MARKER:\n":
                break
        else:
            raise cross.ConfigurationError("missing SDK payload marker")
        with lzma.LZMAFile(stream) as payload, \
                tarfile.open(fileobj=payload, mode="r|") as archive:
            for member in archive:
                name = member.name
                if (member.isfile() and "sstate-cache/" in name
                        and ("sstate:glibc:cortexa57-" in name
                             or "sstate:gcc-runtime:cortexa57-" in name)
                        and name.endswith("_populate_sysroot.tar.zst")):
                    relative = name[name.index("sstate-cache/"):]
                    content = archive.extractfile(member)
                    sha = hashlib.sha256()
                    for block in iter(lambda: content.read(1024 * 1024), b""):
                        sha.update(block)
                    path = cross.resolved(sdk / relative, [sdk])
                    cross.require(cross.digest(path) == sha.hexdigest(),
                                  "SDK runtime cache differs from installer")
                    key = "glibc" if "sstate:glibc:" in name else "gcc-runtime"
                    cross.require(key not in cached, "ambiguous SDK runtime cache")
                    cached[key] = path
    cross.require(set(cached) == {"glibc", "gcc-runtime"},
                  "missing authenticated SDK runtime caches")
    libraries = {}
    for key, names in {
            "glibc": ["lib/libc.so.6", "lib/ld-linux-aarch64.so.1",
                      "usr/include/stdio.h"],
            "gcc-runtime": ["usr/lib/libstdc++.so.6.0.32"]}.items():
        for name in names:
            result = subprocess.run(
                ["tar", "--zstd", "-xOf", str(cached[key]),
                 "sysroot-destdir/" + name], capture_output=True)
            cross.require(result.returncode == 0,
                          f"cannot read authenticated SDK member: {name}")
            expected = hashlib.sha256(result.stdout).hexdigest()
            actual = cross.resolved(sysroot / name, [sysroot])
            cross.require(cross.digest(actual) == expected,
                          f"target runtime differs from official SDK: {name}")
            libraries[name] = expected
    metadata = (sdk / "conf/local.conf").read_text()
    cross.require(f'METADATA_REVISION:poky = "{POKY_REVISION}"' in metadata
                  and 'MACHINE = "qemuarm64"' in metadata,
                  "SDK metadata does not match pinned Scarthgap qemuarm64")
    return dict(release="scarthgap", version="5.0", machine="qemuarm64",
                installer_sha256=SDK_SHA256, poky_revision=POKY_REVISION,
                runtime_files=libraries, os_release_required=False,
                method="official installer and embedded runtime comparison")


def verify(installer, sdk):
    settings = cross.validate(require_core=False)
    cross.require(settings["ada_version"] == "13.3.1"
                  and settings["cxx_version"] == "13.3.1",
                  "GNAT Pro 25.2 profile requires matching GCC 13.3.1")
    ada = cross.resolved(settings["ada"])
    cxx = cross.resolved(settings["cxx"])
    cross.require(ada.parent == cxx.parent,
                  "Ada and C++ are from different compiler installations")
    gnatls = cross.matching_gnatls(ada)
    banner = cross.run([gnatls, "--version"]).splitlines()[0]
    cross.require(banner.startswith("GNATLS Pro 25.2 "),
                  "matching GNATLS does not identify Pro 25.2")
    cpp = cross.probe_identity(cxx, "c++", settings["readelf"])
    for identity in [*settings["ada_probe"]["identities"], *cpp]:
        cross.require("for GNAT Pro 25.2 " in identity,
                      "object does not identify matching GNAT Pro 25.2")
    cross.require(set(settings["ada_probe"]["identities"]) == cpp,
                  "Ada/C++ compiler build identities differ")
    runtime = Path(settings["runtime"])
    settings["runtime_alis"] = cross.check_alis(
        runtime / "adalib", settings["ali_signature"])
    settings["yocto"] = sdk_identity(
        cross.resolved(installer), cross.resolved(sdk), Path(settings["sysroot"]))
    return dict(profile="ADACORE_GNAT_PRO_25_2", product_version="25.2",
                gnatls=banner, settings=settings, verified=True,
                target_hardware_tested=False)


if __name__ == "__main__":
    try:
        cross.require(len(sys.argv) == 3,
                      "usage: verify_adacore25.py OFFICIAL_INSTALLER SDK_ROOT")
        print(json.dumps(verify(*sys.argv[1:]), indent=2, sort_keys=True))
    except (cross.ConfigurationError, OSError, ValueError,
            tarfile.TarError, lzma.LZMAError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(1)