#!/usr/bin/env python3
"""Base-owned routing and compatibility evidence; never grants policy approval.

No candidate Python is imported. Proposed verifiers execute only in a separate
read-only job, after this independent compatibility projection is qualified.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

# Isolated mode deliberately excludes cwd and PYTHONPATH; only this separately
# checked-out orchestration directory may supply local imports.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from select_gnatdoc_policy import full_sha, git, require, select

ROOT = Path(__file__).resolve().parents[1]
ENVIRONMENT = "documentation-policy-maintenance"
WORKFLOW = ".github/workflows/documentation.yml"
ACCEPTANCE = "Documentation policy acceptance"
PREFIXES = ("scripts/", ".github/", "tests/ci/", "docs/assets/", "docs/evidence/")
FILES = frozenset({
    "docs/requirements.txt", "alire.toml", "tests/alire.toml", "docs_api.gpr",
    "docs_internal.gpr", "docs/gnatdoc-enhancer.toml", "docs/gnatdoc-authored.json",
    "docs/gnatdoc-warning-baseline.txt", "docs/gnatdoc-coverage-baseline.txt",
    "docs/shared-gnatdoc-shadow.toml",
})


def protected(name):
    return name.startswith(PREFIXES) or name in FILES


def inventory(repository, base, candidate):
    # --no-renames includes BOTH sides of a rename, including deletions. NUL
    # delimiters prevent newline-containing paths from escaping classification.
    return sorted(filter(None, subprocess.check_output([
        "git", "-C", str(repository), "diff", "--no-renames", "--name-only", "-z",
        full_sha(base), full_sha(candidate), "--",
    ]).decode().split("\0")))


def route(repository, event_name, event, candidate):
    selection = select(repository, event_name, event, candidate)
    require(not selection["bootstrap_exploratory"], "legacy bootstrap is not maintenance approval")
    changed = inventory(repository, selection["base"], candidate)
    return {**selection, "changed": changed,
            "protected": [n for n in changed if protected(n)],
            "mode": "maintenance" if any(map(protected, changed)) else "ordinary"}


def compatibility(repository, selection, workspace, policy=ROOT):
    """Keep raw old-policy rejection, then qualify source with old verifier bytes.

    The projection is NOT the candidate and is never eligible for publication.
    Dependency inputs, historical evidence, assets and baselines are NOT replaced:
    security/input failures remain blocking, even during policy maintenance.
    """
    require(git(policy, "rev-parse", "HEAD") == selection["base"], "compatibility authority differs")
    require(not git(policy, "status", "--porcelain"), "compatibility authority dirty")
    require(not workspace.exists(), "compatibility workspace must be new")
    workspace.mkdir(parents=True)
    subprocess.run([sys.executable, "-I", policy / "scripts/validate_gnatdoc_inputs.py",
                    "--candidate", repository], check=True)
    def rules(candidate):
        program = ("import sys; from pathlib import Path; sys.path.insert(0,sys.argv[1]); "
                   "from additive_gnatdoc_policy import candidate_rules,ROOT; "
                   "candidate_rules(ROOT,Path(sys.argv[2]))")
        return subprocess.run([sys.executable, "-I", "-c", program, str(policy / "scripts"),
                               str(candidate)], text=True, capture_output=True)
    report = {"candidate": selection["candidate"], "base": selection["base"],
              "candidate_tree": git(repository, "rev-parse", selection["candidate"] + "^{tree}"),
              "non_deployable": True, "policy_approved": False}
    old = rules(repository)
    # Not a swallowed test failure: preserve the raw exit code and diagnostic.
    # The independent projected campaign below MUST still pass.
    report["old_policy"] = {"status": "rejected" if old.returncode else "compatible",
                            "exit": old.returncode, "stdout": old.stdout, "stderr": old.stderr}
    (workspace / "compatibility.json").write_text(json.dumps(report, indent=2) + "\n")
    projection = workspace / "projection"
    subprocess.run(["git", "clone", "--quiet", "--shared", str(repository), str(projection)], check=True)
    git(projection, "checkout", "--detach", selection["candidate"])
    # Use Git trees, not copy/rglob or a candidate manifest. This also restores
    # deleted verifiers and removes new executable verifier substitutions.
    paths = ("scripts", ".github", "tests/ci")
    git(projection, "restore", "--source=" + selection["base"], "--staged", "--worktree", "--", *paths)
    checked = rules(projection)
    require(checked.returncode == 0, "old-policy source/security compatibility failed: " + checked.stderr)
    tree = git(projection, "write-tree")
    env = {**os.environ, "GIT_AUTHOR_NAME": "Compatibility projection",
           "GIT_COMMITTER_NAME": "Compatibility projection",
           "GIT_AUTHOR_EMAIL": "projection@invalid.example",
           "GIT_COMMITTER_EMAIL": "projection@invalid.example",
           "GIT_AUTHOR_DATE": "2026-11-10T00:00:00Z", "GIT_COMMITTER_DATE": "2026-11-10T00:00:00Z"}
    revision = subprocess.check_output([
        "git", "-C", str(projection), "commit-tree", tree, "-p", selection["base"]],
        input="NON-DEPLOYABLE old-policy compatibility projection\n", text=True, env=env).strip()
    git(projection, "reset", "--hard", revision)
    report.update({"projection": revision, "projection_tree": tree,
                   "restored_paths": list(paths)})
    (workspace / "compatibility.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def accepted(mode, technical, approval, build):
    return (build == technical == "success" and
            ((mode == "ordinary" and approval == "skipped") or
             (mode == "maintenance" and approval == "success")))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--event", required=True)
    parser.add_argument("--event-path", type=Path, required=True)
    parser.add_argument("--policy-checkout", type=Path, required=True)
    parser.add_argument("--expected-mode", choices=("ordinary", "maintenance"))
    parser.add_argument("--compatibility-workspace", type=Path)
    args = parser.parse_args()
    require(git(args.repository, "rev-parse", "HEAD") == args.candidate, "candidate checkout differs")
    require(not git(args.repository, "status", "--porcelain"), "candidate checkout dirty")
    result = route(args.repository, args.event, json.loads(args.event_path.read_text()), args.candidate)
    if args.expected_mode:
        require(result["mode"] == args.expected_mode, "independent changed-file inventories disagree")
    require(git(args.policy_checkout, "rev-parse", "HEAD") == result["base"], "independent base differs")
    if args.compatibility_workspace:
        result["compatibility"] = compatibility(args.repository, result, args.compatibility_workspace,
                                                 args.policy_checkout)
    print(json.dumps(result, indent=2))
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write("mode=" + result["mode"] + "\n")
        output.write("base=" + result["base"] + "\n")
        output.write("candidate=" + args.candidate + "\n")
        if "compatibility" in result:
            output.write("projection=" + result["compatibility"]["projection"] + "\n")


if __name__ == "__main__":
    main()