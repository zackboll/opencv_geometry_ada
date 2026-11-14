"""Independent inventories and fail-closed maintenance routing, using real Git."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from documentation_policy_transition import accepted, compatibility, inventory, protected, route

ROOT = Path(__file__).resolve().parents[1]


class TransitionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@invalid.example")
        self.write("scripts/run_additive_gnatdoc_review.py", "policy marker\n")
        self.write("scripts/verifier.py", "raise ValueError('reject')\n")
        self.write("docs/documentation.md", "docs\n")
        self.base = self.commit()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], text=True).strip()

    def write(self, name, data):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")
        return self.git("rev-parse", "HEAD")

    def selection(self, candidate, **labels):
        return route(self.repo, "pull_request", {"pull_request": {
            "base": {"sha": self.base}, "head": {"sha": candidate}, **labels}}, candidate)

    def test_ordinary_docs_uses_base_even_with_candidate_policy_label(self):
        self.write("docs/documentation.md", "qualified docs\n")
        head = self.commit()
        result = self.selection(head, labels=[{"name": "policy-approved"}])
        self.assertEqual(result["mode"], "ordinary")
        self.assertEqual(result["policy_revision"], self.base)
        self.assertNotIn("policy_approved", result)

    def test_verifier_substitution_cannot_claim_ordinary(self):
        self.write("scripts/verifier.py", "pass\n")
        result = self.selection(self.commit(), labels=[{"name": "docs-only"}])
        self.assertEqual(result["mode"], "maintenance")
        self.assertEqual(result["protected"], ["scripts/verifier.py"])

    def test_rename_deletion_and_newline_paths_remain_protected(self):
        self.git("mv", "scripts/verifier.py", "docs/renamed.py")
        self.write(".github/workflows/evil\nname.yml", "permissions: write-all\n")
        names = inventory(self.repo, self.base, self.commit())
        self.assertIn("scripts/verifier.py", names)
        self.assertIn("docs/renamed.py", names)
        self.assertIn(".github/workflows/evil\nname.yml", names)
        self.assertEqual(self.selection(self.git("rev-parse", "HEAD"))["mode"], "maintenance")

    def test_source_changes_do_not_select_policy_mode(self):
        self.write("src/opencv-geometry.ads", "broken source\n")
        result = self.selection(self.commit())
        self.assertEqual(result["mode"], "ordinary")  # strict qualification must reject it

    def test_ordinary_ada_implementation_retains_strict_base(self):
        self.write("src/ordinary.adb", "passing implementation fixture\n")
        result = self.selection(self.commit())
        self.assertEqual(result["mode"], "ordinary")
        self.assertEqual(result["policy_revision"], self.base)

    def test_stale_or_short_candidate_is_rejected(self):
        self.write("docs/documentation.md", "new\n")
        head = self.commit()
        for identity in (head[:12], self.base):
            with self.subTest(identity=identity), self.assertRaises(ValueError):
                route(self.repo, "pull_request", {"pull_request": {
                    "base": {"sha": self.base}, "head": {"sha": head}}}, identity)

    def test_real_main_merge_routes_protected_policy(self):
        self.write("scripts/verifier.py", "new verifier\n")
        head = self.commit()
        tree = self.git("rev-parse", head + "^{tree}")
        merge = subprocess.check_output(["git", "-C", str(self.repo), "commit-tree", tree,
                                         "-p", self.base, "-p", head], input="merge\n", text=True).strip()
        result = route(self.repo, "push", {"ref": "refs/heads/main", "before": self.base,
                                           "after": merge}, merge)
        self.assertEqual(result["mode"], "maintenance")
        self.assertEqual(result["policy_revision"], merge)
        self.assertNotIn("policy_approved", result)

    def test_all_gate_results_fail_closed(self):
        states = ("success", "failure", "cancelled", "skipped", "pending", "rejected")
        for technical in states:
            for build in states:
                self.assertEqual(accepted(build, technical), build == technical == "success")

    def test_policy_change_selects_proposed_technical_tests_without_authorization(self):
        self.write("scripts/verifier.py", "new legitimate implementation\n")
        head = self.commit()
        result = self.selection(head)
        self.assertEqual(result["mode"], "maintenance")
        self.assertEqual(result["policy_revision"], head)
        self.assertNotIn("policy_approved", result)

    def test_main_ordinary_and_manual_use_actual_merged_policy(self):
        self.write("src/ordinary.adb", "passing implementation fixture\n")
        head = self.commit()
        for event, payload in (("push", {"ref": "refs/heads/main", "before": self.base, "after": head}),
                               ("workflow_dispatch", {"ref": "refs/heads/main"})):
            self.assertEqual(route(self.repo, event, payload, head)["policy_revision"], head)

    def test_security_inputs_and_policy_dependencies_are_protected(self):
        for name in ("scripts/new.py", ".github/scripts/new.cjs", "tests/ci/test_gate.py",
                     "docs/evidence/forged.json", "docs/requirements.txt", "alire.toml",
                     "docs_api.gpr", "docs/shared-gnatdoc-shadow.toml"):
            self.assertTrue(protected(name), name)


class IndependentCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.base = "23701d526bd0870de5fb126c2ecdd0b9c24913e2"
        self.policy = self.folder / "policy"
        self.candidate = self.folder / "candidate"
        for path, revision in ((self.policy, self.base), (self.candidate, "HEAD")):
            subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(path)], check=True)
            subprocess.run(["git", "-C", str(path), "checkout", "--quiet", "--detach", revision], check=True)
        self.selection = {"base": self.base, "candidate": subprocess.check_output(
            ["git", "-C", str(self.candidate), "rev-parse", "HEAD"], text=True).strip()}

    def test_old_rejection_is_evidence_not_candidate_approval(self):
        result = compatibility(self.candidate, self.selection, self.folder / "analysis", self.policy)
        self.assertEqual(result["old_policy"]["status"], "rejected")
        self.assertNotEqual(result["old_policy"]["exit"], 0)
        self.assertNotIn("policy_approved", result)
        self.assertTrue(result["non_deployable"])
        tree = subprocess.check_output(["git", "-C", str(self.candidate), "rev-parse", "HEAD^{tree}"],
                                       text=True).strip()
        self.assertNotEqual(result["projection_tree"], tree)

    def test_dependency_and_source_failures_remain_blocking_in_maintenance(self):
        attacks = {"docs/requirements.txt": lambda b: b + b"evil-package==1\n",
                   "src/opencv-geometry.ads": lambda b: b.replace(
                       b"subtype Contour is", b"subtype Forged_Contour is", 1)}
        for index, (name, mutate) in enumerate(attacks.items()):
            path = self.candidate / name
            before = path.read_bytes()
            try:
                path.write_bytes(mutate(before))
                subprocess.run(["git", "-C", str(self.candidate), "add", name], check=True)
                subprocess.run(["git", "-C", str(self.candidate), "-c", "user.name=Fixture",
                                "-c", "user.email=fixture@invalid.example", "commit", "-qm", "attack"], check=True)
                selection = {**self.selection, "candidate": subprocess.check_output(
                    ["git", "-C", str(self.candidate), "rev-parse", "HEAD"], text=True).strip()}
                with self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    compatibility(self.candidate, selection, self.folder / str(index), self.policy)
            finally:
                subprocess.run(["git", "-C", str(self.candidate), "reset", "--hard",
                                self.selection["candidate"]], check=True, capture_output=True)

    def test_unexpected_baseline_crash_is_not_expected_rejection(self):
        from unittest.mock import patch
        run = subprocess.run

        def crash(argv, **kwargs):
            if "-c" in argv and kwargs.get("capture_output"):
                return subprocess.CompletedProcess(argv, 1, "", "RuntimeError: verifier crashed")
            return run(argv, **kwargs)

        with patch("documentation_policy_transition.subprocess.run", side_effect=crash):
            with self.assertRaisesRegex(ValueError, "unexpected baseline failure"):
                compatibility(self.candidate, self.selection, self.folder / "crash", self.policy)


class IndependentChallengeTests(unittest.TestCase):
    def test_legacy_output_explicitly_selects_legacy_fixture_validation(self):
        from unittest.mock import patch
        from gnatdoc_test_fixtures import validate_generated

        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with patch("validate_docs.validate", return_value={}) as validate:
                self.assertEqual(validate_generated(root / "site", root), {})
            validate.assert_called_once_with(root / "site", root, legacy_fixture=True)

    def test_released_preview_requires_matching_migration_sources(self):
        from unittest.mock import patch
        from gnatdoc_test_fixtures import release_source
        from gnatdoc_migration_policy import CONFIGURATION

        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "root"
            preview = Path(folder) / "preview"
            source = preview / "candidate"
            for name in CONFIGURATION | {
                    "src/opencv-geometry.ads", "src/opencv-geometry-subdiv2d.ads"}:
                for target in (root, source):
                    path = target / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(name)
            with patch.dict(os.environ, GEOMETRY_MIGRATION_PREVIEW=str(preview)):
                self.assertEqual(release_source(root), source)
                (source / "src/opencv-geometry.ads").write_text("substituted")
                with self.assertRaisesRegex(ValueError, "preview source differs"):
                    release_source(root)

    def test_baseline_module_local_patches_resolve_loaded_test_bytes(self):
        import sys
        from unittest.mock import patch
        from challenge_documentation_policy import challenge

        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            candidate, policy = root / "candidate", root / "policy"
            (candidate / "scripts").mkdir(parents=True)
            (policy / "scripts").mkdir(parents=True)
            test = (
                "import unittest\n"
                "from unittest.mock import patch\n"
                "ROOT = None\n"
                "class BaselineTest(unittest.TestCase):\n"
                "    def test_module_local_fixture(self):\n"
                "        with patch(__name__ + '.ROOT', 'baseline fixture'):\n"
                "            self.assertEqual(ROOT, 'baseline fixture')\n"
            )
            for name in ("test_gnatdoc_migration_policy",
                         "test_additive_gnatdoc_policy", "test_native_core_policy",
                         "test_select_gnatdoc_policy"):
                (policy / "scripts" / (name + ".py")).write_text(test)
            with patch("gnatdoc_test_fixtures.legacy_policy", return_value=candidate), \
                    patch.dict(sys.modules), patch.object(sys, "path", sys.path.copy()):
                self.assertTrue(challenge(candidate, policy))


if __name__ == "__main__":
    unittest.main()