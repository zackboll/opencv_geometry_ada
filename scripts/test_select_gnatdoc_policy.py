"""Event/ancestry bootstrap scenarios; no GitHub approval is synthesized."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from select_gnatdoc_policy import (
    select, reviewed_bootstrap, git, PREDECESSOR, SDK_BASE, RELEASE_BASE,
)

ROOT = Path(__file__).absolute().parents[1]


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / "repo"
        subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(self.repo)], check=True)
        self.policy = git(ROOT, "rev-parse", "HEAD")

    def commit(self, tree, parents):
        env = {**os.environ, "GIT_AUTHOR_NAME": "Fixture", "GIT_COMMITTER_NAME": "Fixture",
               "GIT_AUTHOR_EMAIL": "fixture@invalid.example", "GIT_COMMITTER_EMAIL": "fixture@invalid.example"}
        args = ["git", "-C", str(self.repo), "commit-tree", tree]
        for parent in parents:
            args += ["-p", parent]
        return subprocess.check_output(args, input="Disposable policy-selection scenario\n",
                                       text=True, env=env).strip()

    def pr(self, base, candidate):
        return select(self.repo, "pull_request", {"pull_request": {
            "base": {"sha": base}, "head": {"sha": candidate}}}, candidate)

    def test_initial_pr_on_reviewed_sdk_main_is_exploratory(self):
        result = self.pr(SDK_BASE, self.policy)
        self.assertEqual(result["policy_revision"], self.policy)
        self.assertTrue(result["bootstrap_exploratory"])
        self.assertFalse(result["policy_approved"])

    def test_original_predecessor_remains_explicit(self):
        reviewed_bootstrap(self.repo, PREDECESSOR)
        reviewed_bootstrap(self.repo, SDK_BASE)

    def test_first_main_push_uses_policy_second_parent(self):
        merged = self.commit(git(self.repo, "rev-parse", self.policy + "^{tree}"),
                             (SDK_BASE, self.policy))
        result = select(self.repo, "push", {"ref": "refs/heads/main", "before": SDK_BASE,
                                           "after": merged}, merged)
        self.assertEqual(result["policy_revision"], self.policy)
        self.assertTrue(result["bootstrap_exploratory"])
        self.assertFalse(result["policy_approved"])

    def test_manual_first_merge_uses_same_actual_ancestry(self):
        merged = self.commit(git(self.repo, "rev-parse", self.policy + "^{tree}"),
                             (SDK_BASE, self.policy))
        result = select(self.repo, "workflow_dispatch", {"ref": "refs/heads/main"}, merged)
        self.assertEqual(result["base"], SDK_BASE)
        self.assertEqual(result["policy_revision"], self.policy)

    def test_later_feature_uses_independent_base(self):
        feature = self.commit(git(self.repo, "rev-parse", self.policy + "^{tree}"), (self.policy,))
        result = self.pr(self.policy, feature)
        self.assertEqual(result["policy_revision"], self.policy)
        self.assertFalse(result["bootstrap_exploratory"])
        self.assertNotEqual(result["policy_revision"], feature)

    def test_unknown_bootstrap_commit_is_not_mutable_main_authority(self):
        unknown = self.commit(git(self.repo, "rev-parse", SDK_BASE + "^{tree}"), (SDK_BASE,))
        candidate = self.commit(git(self.repo, "rev-parse", self.policy + "^{tree}"),
                                (unknown, self.policy))
        with self.assertRaisesRegex(ValueError, "unreviewed first-policy"):
            self.pr(unknown, candidate)

    def test_push_before_must_be_actual_first_parent(self):
        merged = self.commit(git(self.repo, "rev-parse", self.policy + "^{tree}"),
                             (SDK_BASE, self.policy))
        with self.assertRaisesRegex(ValueError, "not candidate first parent"):
            select(self.repo, "push", {"ref": "refs/heads/main", "before": PREDECESSOR,
                                       "after": merged}, merged)

    def test_first_push_cannot_substitute_verifier_tree(self):
        merged = self.commit(git(self.repo, "rev-parse", SDK_BASE + "^{tree}"),
                             (SDK_BASE, self.policy))
        with self.assertRaisesRegex(ValueError, "substituted verifier"):
            select(self.repo, "push", {"ref": "refs/heads/main", "before": SDK_BASE,
                                       "after": merged}, merged)

    def test_pr_candidate_must_match_event(self):
        with self.assertRaisesRegex(ValueError, "substituted PR candidate"):
            select(self.repo, "pull_request", {"pull_request": {
                "base": {"sha": SDK_BASE}, "head": {"sha": PREDECESSOR}}}, self.policy)

    def test_reviewed_tree_mismatch_fails_closed(self):
        from select_gnatdoc_policy import BOOTSTRAP_TREES
        with patch.dict(BOOTSTRAP_TREES, {SDK_BASE: "0" * 40}):
            with self.assertRaisesRegex(ValueError, "tree differs"):
                reviewed_bootstrap(self.repo, SDK_BASE)

    def test_first_main_push_cannot_be_squash_or_unrelated_parent(self):
        tree = git(self.repo, "rev-parse", self.policy + "^{tree}")
        squash = self.commit(tree, (SDK_BASE,))
        with self.assertRaisesRegex(ValueError, "two-parent merge"):
            select(self.repo, "push", {"ref": "refs/heads/main", "before": SDK_BASE,
                                       "after": squash}, squash)
        unrelated = self.commit(tree, (PREDECESSOR,))
        merged = self.commit(tree, (SDK_BASE, unrelated))
        with self.assertRaises(subprocess.CalledProcessError):
            select(self.repo, "push", {"ref": "refs/heads/main", "before": SDK_BASE,
                                       "after": merged}, merged)

    def test_release_initial_pr_is_exact_and_unapproved(self):
        result = self.pr(RELEASE_BASE, self.policy)
        self.assertEqual(result["base_tree"], "be543978b6fe33cc7bb18c4c1ca58328ae741ee6")
        self.assertTrue(result["bootstrap_exploratory"])
        self.assertFalse(result["policy_approved"])

    def test_release_first_merge_selects_actual_policy_parent(self):
        merged = self.commit(git(self.repo, "rev-parse", self.policy + "^{tree}"),
                             (RELEASE_BASE, self.policy))
        result = select(self.repo, "push", {"ref": "refs/heads/main", "before": RELEASE_BASE,
                                           "after": merged}, merged)
        self.assertEqual(result["policy_revision"], self.policy)
        self.assertTrue(result["bootstrap_exploratory"])
        self.assertFalse(result["policy_approved"])

    def test_release_blob_and_ancestry_controls(self):
        from select_gnatdoc_policy import RELEASE_BLOBS, CROSS_BASE
        with patch.dict(RELEASE_BLOBS, {"alire.toml": "0" * 40}):
            with self.assertRaisesRegex(ValueError, "reviewed bytes differ: alire.toml"):
                reviewed_bootstrap(self.repo, RELEASE_BASE)
        with self.assertRaisesRegex(ValueError, "unreviewed first-policy"):
            reviewed_bootstrap(self.repo, CROSS_BASE)


if __name__ == "__main__":
    unittest.main()