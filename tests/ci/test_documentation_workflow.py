"""Documentation event routing and independent protected-transition checks.

Run: python3 -m unittest discover -s tests/ci -v
These are local routing simulations, not hosted push/deployment approval.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest


ROOT = Path(__file__).resolve().parents[2]
BASE = "a91f7fe6423ea439b08cb7c29f595a936d29c0e4"
WORKFLOW = ".github/workflows/documentation.yml"
POLICY = ".github/workflows/documentation-additive-policy.yml"
MAIN_ONLY = "github.ref == 'refs/heads/main' && github.event_name != 'pull_request'"


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def job(text, name):
    match = re.search(r"^  " + re.escape(name) + r":\n(.*?)(?=^  [\w-]+:|\Z)",
                      text, re.MULTILINE | re.DOTALL)
    if not match:
        raise AssertionError("missing job: " + name)
    return match[1]


def condition(body):
    return re.search(r"^    if: (.+)$", body, re.MULTILINE).group(1)


def routed(expression, event, ref):
    # The accepted expression is deliberately finite. Model only its two
    # comparisons; GitHub's implicit success() prerequisite is checked separately.
    if expression != MAIN_ONLY:
        raise AssertionError("unreviewed event guard: " + expression)
    context = SimpleNamespace(event_name=event, ref=ref)
    return context.ref == "refs/heads/main" and context.event_name != "pull_request"


class HistoricalDocumentationRoutingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Preserve the complete prior routing campaign on its actual immutable
        # workflow, not on a successor expected to have different routing.
        cls.workflow = git(ROOT, "show", "6af0b1aaee9d37239d1babc238fcb22c6093348a:" + WORKFLOW) + "\n"
        cls.policy = git(ROOT, "show", BASE + ":" + POLICY) + "\n"
        cls.reviewed = git(ROOT, "show", BASE + ":" + WORKFLOW) + "\n"

    def test_only_current_trust_job_changes(self):
        before = job(self.reviewed, "current-trust")
        after = job(self.workflow, "current-trust")
        self.assertEqual(self.workflow.replace(after, before), self.reviewed)
        self.assertEqual(condition(after), MAIN_ONLY)
        self.assertIn("uses: ./" + POLICY, after)
        self.assertNotIn("continue-on-error", after)

    def test_independent_pr_policy_is_byte_identical_and_unfiltered(self):
        self.assertEqual(self.policy.rstrip().encode(), subprocess.check_output(
            ["git", "-C", str(ROOT), "show", BASE + ":" + POLICY]).rstrip())
        self.assertIn("on:\n  pull_request:\n  workflow_call:\n", self.policy)
        self.assertNotIn("paths-ignore:", self.policy)
        self.assertIsNone(re.search(r"^    if:", job(self.policy, "qualify"), re.MULTILINE))
        self.assertNotIn("continue-on-error", self.policy)

    def test_historical_tests_attacks_and_selector_unchanged(self):
        for name in ("scripts/select_gnatdoc_policy.py", "scripts/run_additive_gnatdoc_review.py",
                     "scripts/adversarial_additive_gnatdoc.py"):
            with self.subTest(name=name):
                self.assertEqual(subprocess.check_output(
                    ["git", "-C", str(ROOT), "show", "6af0b1a:" + name]), subprocess.check_output(
                    ["git", "-C", str(ROOT), "show", BASE + ":" + name]))
        self.assertIn("test_shared_gnatdoc_shadow.py -v", self.policy)
        self.assertIn("test_additive_gnatdoc_policy.py -v", self.policy)

    def test_migration_policy_transition_is_not_self_authorized(self):
        # Protected policy evolves only through explicit bootstrap review. The
        # old authority must still reject this transition, never label it green.
        with tempfile.TemporaryDirectory() as folder:
            policy = Path(folder) / "policy"
            subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(policy)], check=True)
            subprocess.run(["git", "-C", str(policy), "checkout", "--quiet", "--detach",
                            "05c6680cdf4f9fe544cfbbab21cf13eab41d0112"], check=True)
            program = ("import sys; from pathlib import Path; sys.path.insert(0, sys.argv[1]); "
                       "from gnatdoc_migration_policy import envelope; "
                       "envelope(Path(sys.argv[2]), Path(sys.argv[3]))")
            result = subprocess.run([sys.executable, "-I", "-c", program, str(policy / "scripts"),
                                     str(policy), str(ROOT)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unapproved migration verification files", result.stderr)
            self.assertIn("scripts/gnatdoc_migration_policy.py", result.stderr)

    def test_event_matrix(self):
        scenarios = (
            ("pull_request", "refs/pull/62/merge", False),
            ("pull_request", "refs/heads/main", False),
            ("pull_request", "refs/heads/stacked-docs", False),
            ("push", "refs/heads/main", True),
            ("push", "refs/heads/docs", False),
            ("workflow_dispatch", "refs/heads/main", True),
            ("workflow_dispatch", "refs/heads/docs", False),
            ("workflow_dispatch", "refs/tags/main", False),
        )
        for event, ref, expected in scenarios:
            with self.subTest(event=event, ref=ref):
                self.assertEqual(routed(condition(job(self.workflow, "current-trust")), event, ref),
                                 expected)
                self.assertEqual(routed(condition(job(self.workflow, "deploy")), event, ref),
                                 expected)
        self.assertIn("  push:\n    branches: [main]\n", self.workflow)
        self.assertIn("  pull_request:\n", self.workflow)

    def test_deploy_remains_fail_closed(self):
        deploy = job(self.workflow, "deploy")
        self.assertIn("    needs: [build, current-trust]\n", deploy)
        self.assertEqual(condition(deploy), MAIN_ONLY)  # No always()/failure() override.
        for event in ("push", "workflow_dispatch"):
            for build in ("success", "failure", "cancelled", "skipped"):
                for trust in ("success", "failure", "cancelled", "skipped"):
                    with self.subTest(event=event, build=build, trust=trust):
                        prerequisites = all(result == "success" for result in (build, trust))
                        eligible = routed(condition(deploy), event, "refs/heads/main")
                        self.assertEqual(eligible and prerequisites,
                                         build == trust == "success")

    def test_pages_permissions_and_steps_unchanged(self):
        self.assertIn("permissions:\n  contents: read\n", self.workflow)
        self.assertEqual(job(self.workflow, "build"), job(self.reviewed, "build"))
        self.assertEqual(job(self.workflow, "deploy"), job(self.reviewed, "deploy"))
        self.assertEqual(self.workflow.count("if: " + MAIN_ONLY), 4)


class CurrentDocumentationRoutingTests(unittest.TestCase):
    def setUp(self):
        self.workflow = (ROOT / WORKFLOW).read_text()
        self.policy = (ROOT / POLICY).read_text()

    def test_pages_gate_and_actions_unchanged(self):
        reviewed = git(ROOT, "show", "23701d5:" + WORKFLOW) + "\n"
        self.assertEqual(job(self.workflow, "deploy"), job(reviewed, "deploy"))
        self.assertEqual(condition(job(self.workflow, "current-trust")), MAIN_ONLY)
        self.assertIn("needs: current-trust", job(self.workflow, "build"))
        self.assertIn("needs.current-trust.result == 'success'", job(self.workflow, "build"))
        self.assertEqual(self.workflow.count("if: " + MAIN_ONLY), 4)

    def test_no_privileged_candidate_execution_or_failure_suppression(self):
        self.assertNotIn("continue-on-error", self.policy)
        self.assertNotIn("pull_request_target", self.policy)
        self.assertNotIn("pages: write", self.policy)
        self.assertNotIn("id-token: write", self.policy)
        self.assertIn("contents: read", self.policy)
        self.assertNotIn("environment:", self.policy)
        for forbidden in ("documentation-policy-maintenance", "approval-configuration:",
                          "Maintainer policy approval", "github-script", "provenance.cjs",
                          "23701d526bd0870de5fb126c2ecdd0b9c24913e2"):
            self.assertNotIn(forbidden, self.policy)
        acceptance = job(self.workflow, "acceptance")
        self.assertIn("if: always()", acceptance)
        self.assertIn('test "$BUILD" = success', acceptance)
        self.assertIn('test "$TRUST" = success', acceptance)
        self.assertIn('test "$CURRENT" = success', acceptance)

    def test_every_pr_gets_independent_inventory_and_technical_qualification(self):
        self.assertIsNone(re.search(r"^    if:", job(self.policy, "qualify"), re.MULTILINE))
        self.assertIn("--compatibility-workspace /tmp/baseline-compatibility", self.policy)
        self.assertIn("challenge_documentation_policy.py", self.policy)
        self.assertIn("preview_gnatdoc_migration.py", self.policy)
        self.assertEqual(self.policy.count("python scripts/run_additive_gnatdoc_review.py"), 1)
        self.assertNotIn("/tmp/old-policy/projection", self.policy)
        self.assertFalse((ROOT / ".github/workflows/documentation-shared-shadow.yml").exists())
        self.assertIn("pip install -r baseline/docs/requirements.txt", self.policy)
        preview = self.policy.split("      - name: Execute real production migration preview\n", 1)[1]
        self.assertIn("GH_TOKEN: ${{ github.token }}", preview.split("      - name:", 1)[0])

    def test_single_technical_acceptance_and_pages_event_matrix(self):
        self.assertEqual(self.workflow.count("name: Documentation policy acceptance"), 1)
        for event in ("pull_request", "push", "workflow_dispatch"):
            for ref in ("refs/heads/main", "refs/heads/topic", "refs/pull/64/merge"):
                for build in ("success", "failure", "cancelled", "skipped"):
                    for technical in ("success", "failure", "cancelled", "skipped"):
                        eligible = routed(condition(job(self.workflow, "deploy")), event, ref)
                        self.assertEqual(eligible and build == technical == "success",
                                         event != "pull_request" and ref == "refs/heads/main"
                                         and build == technical == "success")

    def test_pages_failure_is_not_reclassified_as_success(self):
        deploy = job(self.workflow, "deploy")
        self.assertIn("needs: [build, current-trust]", deploy)
        self.assertNotIn("continue-on-error", deploy)
        self.assertNotIn("always()", deploy)
        self.assertIn("uses: actions/deploy-pages@v4", deploy)


class IndependentPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.policy = Path(self.temp.name) / "policy"
        self.candidate = Path(self.temp.name) / "candidate"
        for path in (self.policy, self.candidate):
            subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(path)], check=True)
            subprocess.run(["git", "-C", str(path), "checkout", "--quiet", "--detach", BASE], check=True)

    def rules(self):
        # Isolated interpreter loads only the clean, exact independent base.
        program = ("import sys; from pathlib import Path; sys.path.insert(0, sys.argv[1]); "
                   "from additive_gnatdoc_policy import candidate_rules, policy_identity; "
                   "policy_identity(sys.argv[3]); "
                   "print(candidate_rules(Path(sys.argv[2]), Path(sys.argv[2])))")
        return subprocess.run([sys.executable, "-I", "-c", program, str(self.policy / "scripts"),
                               str(self.candidate), BASE], text=True, capture_output=True)

    def test_ordinary_documentation_candidate_passes_independent_rules(self):
        with (self.candidate / "docs/documentation.md").open("a") as output:
            output.write("\nDocumentation-only qualification fixture.\n")
        result = self.rules()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("'added': []", result.stdout)

    def test_workflow_transition_is_rejected_not_bootstrap_approved(self):
        (self.candidate / WORKFLOW).write_bytes((ROOT / WORKFLOW).read_bytes())
        result = self.rules()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("migration configuration missing", result.stderr)
        self.assertEqual(git(self.policy, "status", "--porcelain"), "")

    def test_transition_event_selection_stays_independent(self):
        (self.candidate / WORKFLOW).write_bytes((ROOT / WORKFLOW).read_bytes())
        subprocess.run(["git", "-C", str(self.candidate), "add", WORKFLOW], check=True)
        tree = git(self.candidate, "write-tree")
        candidate = subprocess.check_output(
            ["git", "-C", str(self.candidate), "commit-tree", tree, "-p", BASE],
            input="Disposable protected workflow transition\n", text=True).strip()
        program = ("import sys,json; from pathlib import Path; sys.path.insert(0, sys.argv[1]); "
                   "from select_gnatdoc_policy import select; "
                   "print(json.dumps(select(Path(sys.argv[2]), sys.argv[3], "
                   "json.loads(sys.argv[4]), sys.argv[5])))")
        events = {
            "pull_request": {"pull_request": {"base": {"sha": BASE}, "head": {"sha": candidate}}},
            "push": {"ref": "refs/heads/main", "before": BASE, "after": candidate},
            "workflow_dispatch": {"ref": "refs/heads/main"},
        }
        for event, payload in events.items():
            with self.subTest(event=event):
                result = subprocess.run(
                    [sys.executable, "-I", "-c", program, str(self.policy / "scripts"),
                     str(self.candidate), event, json.dumps(payload), candidate],
                    text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                selection = json.loads(result.stdout)
                self.assertEqual(selection["policy_revision"], BASE)
                self.assertFalse(selection["bootstrap_exploratory"])
                self.assertFalse(selection["policy_approved"])
                # Event routing never grants permission to replace the workflow.
                rejected = self.rules()
                self.assertNotEqual(rejected.returncode, 0)
                self.assertIn("migration configuration missing", rejected.stderr)


if __name__ == "__main__":
    unittest.main()