#!/usr/bin/env python3
"""Check AdaCore GNAT 12 and Yocto Scarthgap provenance claims against
binary evidence.

A provenance file is a caller's claim, never proof. Each claim must be
present and supported by the supplied toolchain and sysroot:

- yocto.release must be "scarthgap", and the sysroot's os-release must
  carry that codename (VERSION_CODENAME or DISTRO_CODENAME) and the
  claimed distribution ID;
- yocto.sysroot must be ENV_PREFIX;
- yocto.machine, image, build_identity and export_method must be given;
  they are recorded, as they cannot be checked from the sysroot alone;
- toolchain.vendor must be "AdaCore" and toolchain.gnat_major 12: the Ada
  driver must report GCC 12, and either the gnatls beside it must identify
  as GNATLS Pro or the objects it compiles must record GNAT Pro.

usage: verify_target_claims.py PROVENANCE_JSON
Environment: OPENCV_CROSS_TARGET, ENV_PREFIX, OPENCV_CROSS_ADA,
OPENCV_CROSS_CXX and OPENCV_CROSS_READELF, as for scripts/cross_geometry.py.
Prints a JSON report; exits nonzero when any claim is not verified.
"""
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "cross", ROOT / "scripts/cross_geometry.py")
cross = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cross)

REQUIRED = {
    "yocto": ["release", "distro", "machine", "image", "build_identity",
              "export_method", "sysroot"],
    "toolchain": ["vendor", "product", "gnat_major"]}


def os_release(sysroot):
    """Fields of the sysroot's os-release, or None."""
    for name in ["etc/os-release", "usr/lib/os-release"]:
        candidate = sysroot / name
        if candidate.exists() or candidate.is_symlink():
            path = cross.resolved(candidate, [sysroot])
            fields = {}
            for line in path.read_text().splitlines():
                match = re.fullmatch(r"\s*([A-Z_]+)=(.*?)\s*", line)
                if match:
                    fields[match[1]] = match[2].strip("\"'")
            return dict(path=str(path), fields=fields)
    return None


def glibc_versions(sysroot, readelf):
    found = sorted(sysroot.rglob("libc.so.6"))
    if not found:
        return []
    library = cross.resolved(found[0], [sysroot])
    names = cross.version_definitions(library, readelf)
    return sorted((name for name in names if name.startswith("GLIBC_2.")),
                  key=lambda name: [int(part) for part in
                                    name[6:].split(".")])


def verify(provenance):
    failures = []
    evidence = {}

    def claim(condition, message):
        if not condition:
            failures.append(message)

    for section, keys in REQUIRED.items():
        for key in keys:
            item = provenance.get(section, {}).get(key)
            claim(item not in [None, ""], f"missing claim {section}.{key}")
    yocto = provenance.get("yocto", {})
    toolchain = provenance.get("toolchain", {})
    target = cross.value("OPENCV_CROSS_TARGET")
    sysroot = cross.resolved(cross.value("ENV_PREFIX"))
    readelf = cross.tool("OPENCV_CROSS_READELF", "readelf")
    ada = cross.tool("OPENCV_CROSS_ADA")
    cxx = cross.tool("OPENCV_CROSS_CXX")

    claim(yocto.get("release") == "scarthgap",
          f"yocto.release is {yocto.get('release')!r}, not 'scarthgap'")
    if yocto.get("sysroot"):
        try:
            same = cross.resolved(yocto["sysroot"]) == sysroot
        except cross.ConfigurationError:
            same = False
        claim(same, "yocto.sysroot is not ENV_PREFIX")
    release = os_release(sysroot)
    evidence["os_release"] = release
    if release is None:
        failures.append("the sysroot has no os-release: the Yocto release "
                        "claim cannot be verified")
    else:
        fields = release["fields"]
        codename = fields.get("VERSION_CODENAME") \
            or fields.get("DISTRO_CODENAME")
        claim(codename == yocto.get("release"),
              f"sysroot os-release codename {codename!r} contradicts "
              f"yocto.release {yocto.get('release')!r}")
        claim(fields.get("ID") == yocto.get("distro"),
              f"sysroot os-release ID {fields.get('ID')!r} contradicts "
              f"yocto.distro {yocto.get('distro')!r}")
    evidence["glibc_versions"] = glibc_versions(sysroot, readelf)
    for key in ["machine", "image", "build_identity", "export_method"]:
        evidence[f"recorded_unverified_{key}"] = yocto.get(key)

    claim(toolchain.get("vendor") == "AdaCore",
          f"toolchain.vendor is {toolchain.get('vendor')!r}, not 'AdaCore'")
    claim(toolchain.get("gnat_major") == 12,
          f"toolchain.gnat_major is {toolchain.get('gnat_major')!r}, not 12")
    ada_version = cross.run([ada, "-dumpfullversion"])
    evidence["ada_version"] = ada_version
    claim(ada_version.split(".")[0] == str(toolchain.get("gnat_major")),
          f"the Ada driver reports GCC {ada_version}, contradicting "
          f"toolchain.gnat_major {toolchain.get('gnat_major')!r}")
    gnatls = Path(ada).parent / f"{target}-gnatls"
    banner = ""
    if os.access(gnatls, os.X_OK):
        banner = cross.run([gnatls, "--version"]).splitlines()[0]
    evidence["gnatls"] = dict(path=str(gnatls), version=banner)
    identities = sorted(cross.probe_identity(ada, "ada", readelf))
    evidence["ada_object_identities"] = identities
    adacore = "GNATLS Pro" in banner \
        or any("GNAT Pro" in identity for identity in identities)
    claim(adacore, "neither gnatls nor the compiled objects identify GNAT "
          f"Pro (gnatls: {banner!r}; objects: {identities})")
    evidence["cxx_version"] = cross.run([cxx, "-dumpfullversion"])
    evidence["cxx_object_identities"] = sorted(
        cross.probe_identity(cxx, "c++", readelf))
    return dict(claims=provenance, evidence=evidence, failures=failures,
                verified=not failures)


def main(arguments):
    cross.require(len(arguments) == 1, __doc__)
    report = verify(json.loads(Path(arguments[0]).read_text()))
    print(json.dumps(report, indent=2, sort_keys=True))
    if not report["verified"]:
        for failure in report["failures"]:
            print(f"claim not verified: {failure}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (cross.ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(2)
