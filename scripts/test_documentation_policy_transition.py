"""Independent inventories and fail-closed maintenance routing, using real Git."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from documentation_policy_transition import accepted, inventory, protected, route

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
        self.assertFalse(result["policy_approved"])

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
        self.assertEqual(result["policy_revision"], self.base)
        self.assertFalse(result["policy_approved"])

    def test_all_gate_results_fail_closed(self):
        states = ("success", "failure", "cancelled", "skipped", "pending", "rejected")
        for technical in states:
            for approval in states:
                for build in states:
                    self.assertEqual(accepted("maintenance", technical, approval, build),
                                     technical == approval == build == "success")
                    self.assertEqual(accepted("ordinary", technical, approval, build),
                                     technical == build == "success" and approval == "skipped")
        self.assertFalse(accepted("candidate-approved", "success", "success", "success"))

    def test_security_inputs_and_policy_dependencies_are_protected(self):
        for name in ("scripts/new.py", ".github/scripts/new.cjs", "tests/ci/test_gate.py",
                     "docs/evidence/forged.json", "docs/requirements.txt", "alire.toml",
                     "docs_api.gpr", "docs/shared-gnatdoc-shadow.toml"):
            self.assertTrue(protected(name), name)


if __name__ == "__main__":
    unittest.main()