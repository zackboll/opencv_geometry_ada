"""Negative-first envelope qualification; passing never authorizes a bootstrap."""
import copy
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from gnatdoc_migration_policy import (
    ROOT, WHEEL, MIGRATION, CONFIGURATION, TEST_REPAIRS, WORKFLOW,
    envelope, migration_workflow, migration_generator, verify_wheel, native_output,
    verify_current_commit,
    installed_wheel,
)
from additive_gnatdoc_policy import (
    candidate_rules, historical_inputs, inventory, compatible, exact_snapshot, coverage,
)
from validate_gnatdoc_inputs import validate


class MigrationPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.candidate = Path(self.temp.name) / "candidate"
        subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT),
                        str(self.candidate)], check=True)

    def write(self, name, data):
        path = self.candidate / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def mutate(self, name):
        path = self.candidate / name
        return self.write(name, path.read_bytes() + b"\n# unreviewed mutation\n")

    def migration(self):
        # Deliberately not executable production configuration: scope recognition
        # cannot substitute for the full independent output campaign.
        for name in CONFIGURATION:
            self.write(name, b"fixture only\n")
        self.write(WORKFLOW, migration_workflow((ROOT / WORKFLOW).read_text()).encode())
        name = "scripts/generate_docs.sh"
        self.write(name, migration_generator((ROOT / name).read_text()).encode())
        subprocess.run(["git", "-C", str(self.candidate), "add", "."], check=True)

    def test_01_unrelated_scripts_workflows_and_new_executables_rejected(self):
        for name in ("scripts/configure_opencv.sh", ".github/workflows/documentation-additive-policy.yml",
                     "scripts/select_gnatdoc_policy.py", "scripts/validate_gnatdoc_inputs.py",
                     "scripts/gnatdoc_migration_policy.py", "scripts/run_additive_gnatdoc_review.py",
                     "scripts/qualify_additive_gnatdoc.py", "scripts/new_verifier.py",
                     ".github/workflows/new-publication.yml"):
            with self.subTest(name=name):
                path = self.candidate / name
                original = path.read_bytes() if path.exists() else None
                try:
                    self.write(name, (original or b"") + b"\n# unapproved\n")
                    with self.assertRaisesRegex(ValueError, "unapproved migration verification files"):
                        envelope(ROOT, self.candidate)
                finally:
                    path.write_bytes(original) if original is not None else path.unlink()
        self.assertEqual(envelope(ROOT, self.candidate), set())

    def test_02_missing_configuration_and_generator_mutation_rejected(self):
        name = "scripts/generate_docs.sh"
        self.mutate(name)
        with self.assertRaisesRegex(ValueError, "configuration missing"):
            envelope(ROOT, self.candidate)
        self.migration()
        self.mutate(name)
        with self.assertRaisesRegex(ValueError, "generator is not the release-backed template"):
            envelope(ROOT, self.candidate)

    def test_03_permissions_selector_core_and_install_substitutions_rejected(self):
        self.migration()
        original = (self.candidate / WORKFLOW).read_bytes()
        attacks = (
            (b"contents: read", b"contents: write"),
            (b"pages: write", b"pages: read"),
            (b"id-token: write", b"id-token: read"),
            (b"github.event_name != 'pull_request'", b"true"),
            (b"needs: [build, current-trust]", b"needs: [build]"),
            (b"persist-credentials: false", b"persist-credentials: true"),
            (b"../build-policy/scripts/validate_gnatdoc_inputs.py", b"scripts/validate_gnatdoc_inputs.py"),
            (b"f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f", b"main"),
            (b"ec4d689eac748b7837abd4c3754c3090ca4bf814", b"main"),
            (b"--wheel /tmp/" + WHEEL.encode() + b" --install", b"--wheel /tmp/unverified.whl --install"),
            (b"--install\n", b"--install\n          pip install -e ../enhancer\n"),
            (b"--install\n", b"--install\n          pip install ada-gnatdoc-enhancer\n"),
            (b"--install\n", b"--install\n          pip install git+https://example.invalid/main\n"),
        )
        for old, new in attacks:
            with self.subTest(attack=new):
                self.assertIn(old, original)
                self.write(WORKFLOW, original.replace(old, new, 1))
                with self.assertRaisesRegex(ValueError, "workflow is not the release-backed template"):
                    envelope(ROOT, self.candidate)
        self.write(WORKFLOW, original)
        self.assertTrue(envelope(ROOT, self.candidate))

    def test_04_build_dependencies_and_unrelated_migration_inputs_rejected(self):
        self.migration()
        name = "alire.toml"
        original = (self.candidate / name).read_bytes()
        self.write(name, original + b'\n[[depends-on]]\nunexpected = "*"\n')
        with self.assertRaisesRegex(ValueError, "trusted build input changed: alire.toml"):
            validate(self.candidate, ROOT)
        with self.assertRaisesRegex(ValueError, "migration includes unrelated files"):
            envelope(ROOT, self.candidate)
        self.write(name, original)
        self.mutate("src/opencv-geometry.ads")
        with self.assertRaisesRegex(ValueError, "migration includes unrelated files"):
            envelope(ROOT, self.candidate)

    def test_05_substituted_corrupt_wrong_version_wheels_rejected(self):
        wheel = Path(self.temp.name) / WHEEL
        for data in (b"corrupt", b"version=0.1.4", b"version=0.1.5 unverified substitute"):
            wheel.write_bytes(data)
            with self.subTest(data=data), self.assertRaisesRegex(ValueError, "official v0.1.5 wheel identity differs"):
                verify_wheel(wheel)
        wheel.unlink()
        wheel.symlink_to(ROOT / "alire.toml")
        with self.assertRaisesRegex(ValueError, "substituted policy input"):
            verify_wheel(wheel)

    def test_06_historical_evidence_and_existing_declarations_rejected(self):
        name = "docs/evidence/gnatdoc009/type-link-occurrences.json"
        self.mutate(name)
        with self.assertRaisesRegex(ValueError, "historical evidence modified"):
            historical_inputs(self.candidate)
        old = inventory(ROOT)
        changed = copy.deepcopy(old)
        changed["opencv.geometry"].pop()
        with self.assertRaisesRegex(ValueError, "published declaration removed or modified"):
            compatible(old, changed)

    def test_07_changed_candidate_commit_rejected(self):
        revision = subprocess.check_output(["git", "-C", str(self.candidate), "rev-parse", "HEAD"],
                                           text=True).strip()
        self.mutate("docs/documentation.md")
        subprocess.run(["git", "-C", str(self.candidate), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.candidate), "-c", "user.name=Fixture",
                        "-c", "user.email=fixture@invalid.example", "commit", "--quiet",
                        "-m", "Changed candidate after verification"], check=True)
        with self.assertRaisesRegex(ValueError, "stale/substituted candidate commit"):
            verify_current_commit(self.candidate, revision)
        with self.assertRaisesRegex(ValueError, "candidate snapshot changed: docs/documentation.md"):
            exact_snapshot(self.candidate, self.candidate, revision)

    def test_08_scope_recognition_is_not_output_approval(self):
        self.migration()
        authorized = envelope(ROOT, self.candidate)
        self.assertEqual(authorized, CONFIGURATION | {WORKFLOW, "scripts/generate_docs.sh"})
        self.assertTrue(authorized <= MIGRATION)
        # Full source rules still run independently, without parsing candidate code.
        self.assertEqual(candidate_rules(ROOT, self.candidate)["declarations"],
                         sum(map(len, inventory(ROOT).values())))

    def test_09_contemporary_test_repair_scope(self):
        for name in TEST_REPAIRS:
            self.mutate(name)
        self.assertEqual(envelope(ROOT, self.candidate), TEST_REPAIRS)
        self.mutate("scripts/check_doc_coverage.py")
        with self.assertRaisesRegex(ValueError, "unapproved migration verification files"):
            envelope(ROOT, self.candidate)

    def test_10_source_editable_floating_and_wrong_installed_version_rejected(self):
        import json
        from unittest.mock import Mock
        distribution = Mock()
        distribution.version = "0.1.4"
        with patch("gnatdoc_migration_policy.verify_wheel"), patch(
                "gnatdoc_migration_policy.importlib.metadata.distribution", return_value=distribution):
            with self.assertRaisesRegex(ValueError, "installed enhancer version differs"):
                installed_wheel(Path("unused.whl"))
            distribution.version = "0.1.5"
            for record in ({}, {"dir_info": {"editable": True}},
                           {"vcs_info": {"requested_revision": "main"}},
                           {"archive_info": {"hashes": {"sha256": "0" * 64}}}):
                distribution.read_text.return_value = json.dumps(record)
                with self.subTest(record=record), self.assertRaisesRegex(
                        ValueError, "installed enhancer is not the official wheel"):
                    installed_wheel(Path("unused.whl"))

    def test_11_incorrect_resolved_core_and_lock_rejected(self):
        from unittest.mock import Mock
        from qualify_shared_gnatdoc_shadow import resolved_core
        session = Mock()
        source, core = Path("/qualification/geometry"), Path("/qualification/core")
        session.run.return_value = "/untrusted/core"
        with self.assertRaisesRegex(ValueError, "incorrect Alire Core resolution"):
            resolved_core(session, source, core)
        session.run.return_value = str(core)
        lock = b'''[[solution.state]]
crate="opencv_core"
fulfilment="linked"
[solution.state.link]
path="../wrong-core"
'''
        with patch("qualify_shared_gnatdoc_shadow.regular", return_value=lock):
            with self.assertRaisesRegex(ValueError, "incorrect Core lock"):
                resolved_core(session, source, core)


class OutputBoundaryTests(unittest.TestCase):
    def test_missing_or_altered_native_anchor_rejected(self):
        # Exercise the actual independent HTML reader, not a forged count report.
        with tempfile.TemporaryDirectory() as folder:
            before, after = (Path(folder) / name for name in ("before", "after"))
            for root, anchor in ((before, "original"), (after, "substitute")):
                (root / "api").mkdir(parents=True)
                (root / "api/pkg.html").write_text(
                    '<h1>OpenCV.Geometry</h1><h4 id=' + anchor + '>Compose</h4>'
                    '<pre class=ada-code-snippet><code>function Compose;</code></pre>')
            with self.assertRaisesRegex(ValueError, "native declaration/anchor inventory differs"):
                native_output(ROOT, before, after)
            (after / "api/pkg.html").write_text('<h1>OpenCV.Geometry</h1>')
            with self.assertRaisesRegex(ValueError, "native declaration/anchor inventory differs"):
                native_output(ROOT, before, after)

    def test_missing_or_altered_coverage_and_warnings_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / "native.log"
            log.write_text("")
            for items, missing, errors in (({}, {"removed"}, []), ({}, set(), ["altered member"])):
                with patch("additive_gnatdoc_policy.check_site", return_value=(items, missing, errors)):
                    with self.assertRaisesRegex(ValueError, "current documentation gaps"):
                        coverage(ROOT, ROOT, log)
            log.write_text("warning: new undocumented declaration\n")
            with patch("additive_gnatdoc_policy.check_site", return_value=({"item": "function"}, set(), [])):
                with self.assertRaisesRegex(ValueError, "current native diagnostics are not clean"):
                    coverage(ROOT, ROOT, log)


if __name__ == "__main__":
    unittest.main()