#!/usr/bin/env python3
"""Git-based technical routing and independent baseline compatibility checks."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

# Isolated mode deliberately excludes cwd and PYTHONPATH; only this separately
# checked-out orchestration directory may supply local imports.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from select_gnatdoc_policy import full_sha, git, require

ROOT = Path(__file__).resolve().parents[1]
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
    full_sha(candidate)
    if event_name == "pull_request":
        require(event["pull_request"]["head"]["sha"] == candidate, "substituted PR candidate")
        base = full_sha(event["pull_request"]["base"]["sha"])
    else:
        require(event_name in ("push", "workflow_dispatch") and event["ref"] == "refs/heads/main",
                "technical publication qualification is main-only")
        if event_name == "push":
            require(event["after"] == candidate, "substituted main candidate")
            base = full_sha(event["before"])
        else:
            base = git(repository, "rev-parse", candidate + "^1")
    git(repository, "merge-base", "--is-ancestor", base, candidate)
    changed = inventory(repository, base, candidate)
    mode = "maintenance" if any(map(protected, changed)) else "ordinary"
    # PR policy changes test the proposed verifier; ordinary PRs remain strict.
    # Main always tests its actual merged policy, not its predecessor's envelope.
    policy = candidate if mode == "maintenance" or event_name != "pull_request" else base
    return {"event": event_name, "base": base, "candidate": candidate,
            "policy_revision": policy, "changed": changed,
            "protected": [n for n in changed if protected(n)],
            "mode": mode}


def compatibility(repository, selection, workspace, policy=ROOT):
    """Keep raw old-policy rejection, then qualify source with old verifier bytes.

    The projection is NOT the candidate and is never eligible for publication.
    Dependency inputs, historical evidence, assets and baselines are NOT replaced:
    security/input failures remain blocking, even during policy maintenance.
    """
    require(git(policy, "rev-parse", "HEAD") == selection["base"], "compatibility authority differs")
    require(not git(policy, "status", "--porcelain"), "compatibility authority dirty")
    require(git(repository, "rev-parse", "HEAD") == selection["candidate"], "compatibility candidate differs")
    require(not git(repository, "status", "--porcelain"), "compatibility candidate dirty")
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
              "non_deployable": True}
    old = rules(repository)
    # The raw envelope verdict is diagnostic, not a technical test result.
    # Only known protected-file/envelope rejection may be expected. Crashes and
    # unrelated failures remain blocking, even if a projection would pass.
    report["old_policy"] = {"status": "rejected" if old.returncode else "compatible",
                            "exit": old.returncode, "stdout": old.stdout, "stderr": old.stderr}
    (workspace / "compatibility.json").write_text(json.dumps(report, indent=2) + "\n")
    if old.returncode:
        require(old.returncode == 1 and any(message in old.stderr for message in (
            "ValueError: unapproved migration verification files:",
            "ValueError: migration includes unrelated files:",
            "ValueError: migration configuration missing",
            "ValueError: production documentation workflow security structure differs",
            "ValueError: protected verification component changed:",
            "ValueError: unapproved verification file inventory")),
            "unexpected baseline failure: " + old.stderr)
    projection = workspace / "projection"
    subprocess.run(["git", "clone", "--quiet", "--shared", str(repository), str(projection)], check=True)
    git(projection, "checkout", "--detach", selection["candidate"])
    # Use Git trees, not copy/rglob or a candidate manifest. This also restores
    # deleted verifiers and removes new executable verifier substitutions.
    paths = ["scripts", ".github", "tests/ci"]
    # The production migration's executable configuration is tested by the
    # actual preview, not by pretending its generator is still the old one.
    tracked = set(git(projection, "ls-files").splitlines())
    paths += [name for name in ("docs/gnatdoc-enhancer.toml", "docs/gnatdoc-authored.json")
              if name in tracked]
    git(projection, "restore", "--source=" + selection["base"], "--staged", "--worktree", "--", *paths)
    checked = rules(projection)
    require(checked.returncode == 0, "old-policy source/security compatibility failed: " + checked.stderr)
    report.update({"projection_tree": git(projection, "write-tree"),
                   "restored_paths": list(paths), "baseline_compatibility": "pass"})
    (workspace / "compatibility.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def accepted(build, technical):
    return build == technical == "success"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--event", required=True)
    parser.add_argument("--event-path", type=Path, required=True)
    parser.add_argument("--policy-checkout", type=Path, required=True)
    parser.add_argument("--compatibility-workspace", type=Path)
    args = parser.parse_args()
    require(git(args.repository, "rev-parse", "HEAD") == args.candidate, "candidate checkout differs")
    require(not git(args.repository, "status", "--porcelain"), "candidate checkout dirty")
    result = route(args.repository, args.event, json.loads(args.event_path.read_text()), args.candidate)
    require(git(args.policy_checkout, "rev-parse", "HEAD") == result["base"], "independent base differs")
    if args.compatibility_workspace:
        result["compatibility"] = compatibility(args.repository, result, args.compatibility_workspace,
                                                 args.policy_checkout)
    print(json.dumps(result, indent=2))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            for name in ("mode", "base", "candidate", "policy_revision"):
                output.write(name + "=" + result[name] + "\n")


if __name__ == "__main__":
    main()