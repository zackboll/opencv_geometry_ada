"""Synthetic controls for tests/cross/verify_target_claims.py.

Fake compilers, gnatls and readelf stand in for an AdaCore GNAT 12
toolchain and a Yocto Scarthgap sysroot. These tests prove that claims are
checked against evidence; they are not evidence about any real toolchain.
"""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "claims", ROOT / "tests/cross/verify_target_claims.py")
claims = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(claims)

TARGET = "aarch64-poky-linux"
PRO = "GCC: (GNU) 12.2.1 20230301 (for GNAT Pro 23.2 20230301)"

FAKE_COMPILER = r'''#!/usr/bin/env python3
import json, os, sys
config = json.load(open(os.path.join(os.path.dirname(__file__),
                                     "tools.json")))[os.path.basename(__file__)]
arguments = sys.argv[1:]
if arguments == ["-dumpfullversion"]:
    print(config["version"])
elif arguments == ["--version"]:
    print(config["banner"])
elif "-c" in arguments:
    open(arguments[arguments.index("-o") + 1], "w").write(config["comment"])
'''

FAKE_READELF = r'''#!/usr/bin/env python3
import sys
mode, path = sys.argv[1], sys.argv[-1]
if mode == "-p":
    print("String dump of section '.comment':")
    print("  [     0]  " + open(path).read())
elif mode == "-V":
    print("Version definition section '.gnu.version_d' contains 2 entries:")
    print("  0x0000: Rev: 1  Flags: none  Index: 2  Cnt: 1  Name: GLIBC_2.17")
    print("  0x001c: Rev: 1  Flags: none  Index: 3  Cnt: 1  Name: GLIBC_2.39")
'''


class VerifyTargetClaimsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="geometry-claims.")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.tools = self.base / "toolchain/bin"
        self.tools.mkdir(parents=True)
        self.sysroot = self.base / "sysroot"
        (self.sysroot / "etc").mkdir(parents=True)
        (self.sysroot / "usr/lib").mkdir(parents=True)
        (self.sysroot / "usr/lib/libc.so.6").write_text("")
        (self.sysroot / "usr/lib/os-release").write_text(
            'ID=poky\nNAME="Poky (Yocto Project Reference Distro)"\n'
            'VERSION_ID=5.0.4\nVERSION_CODENAME="scarthgap"\n')
        (self.sysroot / "etc/os-release").symlink_to("../usr/lib/os-release")
        self.config = {
            f"{TARGET}-gcc": dict(version="12.2.1", banner="gcc", comment=PRO),
            f"{TARGET}-gnatls": dict(
                version="12.2.1", banner="GNATLS Pro 23.2 (20230301-115)",
                comment=""),
            f"{TARGET}-g++": dict(
                version="13.3.0", banner="g++",
                comment="GCC: (GNU) 13.3.0")}
        for name in self.config:
            self.executable(name, FAKE_COMPILER)
        self.readelf = self.executable("readelf", FAKE_READELF)
        self.provenance = {
            "yocto": dict(release="scarthgap", distro="poky",
                          machine="genericarm64", image="core-image-minimal",
                          build_identity="build-1", export_method="sdk",
                          sysroot=str(self.sysroot)),
            "toolchain": dict(vendor="AdaCore", product="GNAT Pro",
                              gnat_major=12)}
        self.env = {
            "PATH": os.environ["PATH"], "OPENCV_CROSS_TARGET": TARGET,
            "ENV_PREFIX": str(self.sysroot),
            "OPENCV_CROSS_ADA": str(self.tools / f"{TARGET}-gcc"),
            "OPENCV_CROSS_CXX": str(self.tools / f"{TARGET}-g++"),
            "OPENCV_CROSS_READELF": self.readelf}

    def executable(self, name, body):
        path = self.tools / name
        path.write_text(body)
        path.chmod(0o755)
        return str(path)

    def verify(self):
        (self.tools / "tools.json").write_text(json.dumps(self.config))
        with patch.dict(os.environ, self.env, clear=True):
            return claims.verify(self.provenance)

    def rejected(self, message):
        report = self.verify()
        self.assertFalse(report["verified"])
        self.assertTrue(any(message in failure
                            for failure in report["failures"]),
                        report["failures"])

    def test_verified_claims_record_evidence(self):
        report = self.verify()
        self.assertTrue(report["verified"], report["failures"])
        evidence = report["evidence"]
        self.assertEqual(evidence["glibc_versions"],
                         ["GLIBC_2.17", "GLIBC_2.39"])
        self.assertEqual(evidence["ada_version"], "12.2.1")
        self.assertEqual(evidence["cxx_version"], "13.3.0")
        self.assertEqual(evidence["recorded_unverified_machine"],
                         "genericarm64")

    def test_missing_claims(self):
        for section, key in [("yocto", "machine"), ("yocto", "sysroot"),
                             ("toolchain", "vendor"),
                             ("toolchain", "gnat_major")]:
            with self.subTest(claim=f"{section}.{key}"):
                saved = self.provenance[section].pop(key)
                self.rejected(f"missing claim {section}.{key}")
                self.provenance[section][key] = saved

    def test_release_must_be_scarthgap_and_match_the_sysroot(self):
        self.provenance["yocto"]["release"] = "kirkstone"
        self.rejected("not 'scarthgap'")
        self.rejected("contradicts yocto.release")
        self.provenance["yocto"]["release"] = "scarthgap"
        (self.sysroot / "usr/lib/os-release").write_text(
            "ID=poky\nVERSION_CODENAME=kirkstone\n")
        self.rejected("contradicts yocto.release")

    def test_distribution_and_sysroot_must_match(self):
        self.provenance["yocto"]["distro"] = "debian"
        self.rejected("contradicts yocto.distro")
        self.provenance["yocto"]["distro"] = "poky"
        self.provenance["yocto"]["sysroot"] = str(self.base)
        self.rejected("is not ENV_PREFIX")

    def test_sysroot_without_os_release_is_unverifiable(self):
        (self.sysroot / "etc/os-release").unlink()
        (self.sysroot / "usr/lib/os-release").unlink()
        self.rejected("cannot be verified")

    def test_os_release_link_escaping_the_sysroot(self):
        (self.sysroot / "etc/os-release").unlink()
        (self.sysroot / "usr/lib/os-release").unlink()
        outside = self.base / "os-release"
        outside.write_text("ID=poky\nVERSION_CODENAME=scarthgap\n")
        (self.sysroot / "etc/os-release").symlink_to(outside)
        with patch.dict(os.environ, self.env, clear=True), \
                self.assertRaisesRegex(claims.cross.ConfigurationError,
                                       "escapes"):
            (self.tools / "tools.json").write_text(json.dumps(self.config))
            claims.verify(self.provenance)

    def test_not_adacore(self):
        self.config[f"{TARGET}-gnatls"]["banner"] = "GNATLS 12.2.0"
        self.config[f"{TARGET}-gcc"]["comment"] = "GCC: (Debian 12.2.0-14) 12.2.0"
        self.rejected("identify GNAT Pro")
        self.provenance["toolchain"]["vendor"] = "FSF"
        self.rejected("not 'AdaCore'")

    def test_either_gnatls_or_objects_identify_gnat_pro(self):
        self.config[f"{TARGET}-gnatls"]["banner"] = "GNATLS 12.2.0"
        self.assertTrue(self.verify()["verified"])
        self.config[f"{TARGET}-gnatls"]["banner"] = "GNATLS Pro 23.2"
        self.config[f"{TARGET}-gcc"]["comment"] = "GCC: (GNU) 12.2.1"
        self.assertTrue(self.verify()["verified"])

    def test_gnat_major_must_be_twelve(self):
        self.config[f"{TARGET}-gcc"]["version"] = "13.2.1"
        self.rejected("contradicting toolchain.gnat_major")
        self.config[f"{TARGET}-gcc"]["version"] = "12.2.1"
        self.provenance["toolchain"]["gnat_major"] = 13
        self.rejected("not 12")


if __name__ == "__main__":
    unittest.main()
