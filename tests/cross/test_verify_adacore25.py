"""Negative controls for the separate 25.2 gate; no proprietary inputs."""
import importlib.util
import io
import lzma
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "claims25", Path(__file__).with_name("verify_adacore25.py"))
claims = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(claims)


class SDKIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.sdk = self.base / "sdk"
        self.root = self.sdk / "tmp/sysroots/qemuarm64"
        self.root.mkdir(parents=True)
        metadata = self.sdk / "conf/local.conf"
        metadata.parent.mkdir()
        metadata.write_text(
            f'METADATA_REVISION:poky = "{claims.POKY_REVISION}"\n'
            'MACHINE = "qemuarm64"\n')
        self.installer = self.base / "sdk.sh"
        content = io.BytesIO()
        with tarfile.open(fileobj=content, mode="w") as archive:
            for key in ["glibc", "gcc-runtime"]:
                name = f"sstate-cache/sstate:{key}:cortexa57-poky-linux_populate_sysroot.tar.zst"
                data = (key + " fixture").encode()
                member = tarfile.TarInfo(name)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
                path = self.sdk / name
                path.parent.mkdir(exist_ok=True)
                path.write_bytes(data)
        self.installer.write_bytes(b"#!/bin/sh\nMARKER:\n" +
                                   lzma.compress(content.getvalue()))
        self.files = ["lib/libc.so.6", "lib/ld-linux-aarch64.so.1",
                      "usr/include/stdio.h", "usr/lib/libstdc++.so.6.0.32"]
        for name in self.files:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())

    def verify(self):
        def member(command, **kwargs):
            name = command[-1].removeprefix("sysroot-destdir/")
            return subprocess.CompletedProcess(command, 0, name.encode(), b"")
        with patch.object(claims, "SDK_SHA256", claims.cross.digest(self.installer)), \
                patch.object(claims.subprocess, "run", side_effect=member):
            return claims.sdk_identity(self.installer, self.sdk, self.root)

    def test_authenticated_runtime_without_os_release(self):
        report = self.verify()
        self.assertEqual(report["release"], "scarthgap")
        self.assertEqual(len(report["runtime_files"]), 4)
        self.assertFalse(report["os_release_required"])

    def test_untrusted_installer_is_rejected(self):
        with self.assertRaisesRegex(claims.cross.ConfigurationError, "checksum"):
            claims.sdk_identity(self.installer, self.sdk, self.root)

    def test_modified_or_missing_runtime_cache(self):
        cache = next((self.sdk / "sstate-cache").iterdir())
        cache.write_bytes(b"foreign SDK")
        with self.assertRaisesRegex(claims.cross.ConfigurationError, "cache differs"):
            self.verify()
        cache.unlink()
        with self.assertRaisesRegex(claims.cross.ConfigurationError, "invalid target"):
            self.verify()

    def test_foreign_target_runtime_is_rejected(self):
        (self.root / self.files[0]).write_bytes(b"Debian or foreign libc")
        with self.assertRaisesRegex(claims.cross.ConfigurationError, "runtime differs"):
            self.verify()

    def test_wrong_machine_metadata_is_rejected(self):
        (self.sdk / "conf/local.conf").write_text('MACHINE = "qemux86-64"\n')
        with self.assertRaisesRegex(claims.cross.ConfigurationError, "metadata"):
            self.verify()


if __name__ == "__main__":
    unittest.main()