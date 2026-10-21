#!/usr/bin/env python3
"""Select a policy from event-bound Git ancestry, never an editable manifest.

On ordinary PRs this file is executed from the independently checked-out base.
The first policy's workflow additionally enforces its literal base/tree allowlist
before loading this candidate implementation for exploratory execution only.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


PREDECESSOR = "2f5239a0e264ca2bb4106cdb338d3eac25abf674"
SDK_BASE = "5f71c9a6d5291adb032eb1a43954c5f9aaf047e6"
RELEASE_BASE = "aad0b1b65814ac472bf5a9ea1b266f47aa3baf06"
CROSS_BASE = "e90da6ec345099a9e4833d4bed11be204602c5ac"
BOOTSTRAP_TREES = {
    PREDECESSOR: "c440b9901e1003f06ae555b3a8a80d9874229680",
    SDK_BASE: "cc8487634f66be422e835b95c2ee8cd57e952d45",
    RELEASE_BASE: "be543978b6fe33cc7bb18c4c1ca58328ae741ee6",
}
SDK_PARENTS = (PREDECESSOR, "43e7a398a5c154ef7d63e44d12c5251d6647dc3e")
SDK_BLOBS = {
    ".github/workflows/macos-standalone-sdk.yml": "c45906f474ab58bf65e9599e16bc12eda83a2e20",
    "docs/geom-index-031r-qualification.md": "1d0072692f382a814b33425abf9b3d6618c6ea9b",
    "opencv_geometry.gpr": "0662cc7e6be7e6933a0fb8cf57a5cb794928fe72",
    "opencv_geometry_shim.gpr": "a372198921dbfb3b90b548f3327ebf74ad1eb6de",
    "tests/macos/qualify_standalone_sdk.sh": "4cc6e7cebbad9988b7430a15cb584d2333fe454e",
}
MARKER = "scripts/run_additive_gnatdoc_review.py"
RELEASE_BLOBS = {
    "README.md": "f8e1027fb59e6f52b07128a07bd41e683ad7fb86",
    "alire.toml": "494af4cb323712ef13d4cf2c6650eb5210f82ae0",
    "docs/cross-install-geometry.md": "96bdd09ce9e3a79360629a4babd335e70d312ed5",
    "docs/release-0.3.3-preparation.md": "385fb546b90d265029653bad0ae256f743a948b9",
    "scripts/cross_geometry.py": "7b40645e25038f38124b0e1bd7c8f1b78ef3e64c",
    "scripts/cross_install_geometry.py": "01a6b312fa08b8a2b8c54c409f3db2dd79f71fde",
    "scripts/cross_install_geometry.sh": "171389b51111912e3114d1ee6c13aba76a91c8f9",
    "tests/cross/qualify_geometry_cross_install.sh": "80aa76391efb0c5d2768b80f458b119e790a3a77",
    "tests/cross/qualify_reference_consumers.py": "494c368961d9344bb7c8701b66bbd45c736ec31f",
    "tests/cross/test_cross_geometry.py": "22e16eb08396f2b273ee27d1f036f9b9669f51c1",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def full_sha(value):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None,
            "event identity must be a full commit SHA")
    return value


def has_policy(repository, revision):
    return MARKER in git(repository, "ls-tree", "-r", "--name-only", revision, "--", MARKER).splitlines()


def reviewed_bootstrap(repository, revision):
    require(revision in BOOTSTRAP_TREES, "unreviewed first-policy bootstrap base")
    require(git(repository, "rev-parse", revision + "^{tree}") == BOOTSTRAP_TREES[revision],
            "reviewed bootstrap tree differs")
    if revision == RELEASE_BASE:
        reviewed_bootstrap(repository, SDK_BASE)
        for commit, parents in (
            (CROSS_BASE, (SDK_BASE, "ff4089671cb11837416fe1aa9892018c5fa24fda")),
            (RELEASE_BASE, (CROSS_BASE, "22dd0c08f849d0da6c7befe11e6a70a0ce76728c")),
        ):
            require(tuple(git(repository, "show", "-s", "--format=%P", commit).split()) == parents,
                    "PR 55/56 merge ancestry differs")
        require(set(git(repository, "diff", "--name-only", SDK_BASE, revision).splitlines()) ==
                set(RELEASE_BLOBS), "PR 55/56 changed-file inventory differs")
        for name, blob in RELEASE_BLOBS.items():
            require(git(repository, "rev-parse", revision + ":" + name) == blob,
                    "PR 55/56 reviewed bytes differ: " + name)
    elif revision == SDK_BASE:
        require(tuple(git(repository, "show", "-s", "--format=%P", revision).split()) == SDK_PARENTS,
                "PR 54 merge ancestry differs")
        require(set(git(repository, "diff", "--name-only", PREDECESSOR, revision).splitlines()) ==
                set(SDK_BLOBS), "PR 54 changed-file inventory differs")
        for name, blob in SDK_BLOBS.items():
            require(git(repository, "rev-parse", revision + ":" + name) == blob,
                    "PR 54 reviewed bytes differ: " + name)


def select(repository, event_name, event, candidate):
    full_sha(candidate)
    require(git(repository, "rev-parse", candidate + "^{commit}") == candidate,
            "candidate is not the exact event commit")
    parents = git(repository, "show", "-s", "--format=%P", candidate).split()
    if event_name == "pull_request":
        require(event["pull_request"]["head"]["sha"] == candidate, "substituted PR candidate")
        base = full_sha(event["pull_request"]["base"]["sha"])
    elif event_name == "push":
        require(event.get("ref") == "refs/heads/main" and event.get("after") == candidate,
                "push must identify exact main candidate")
        base = full_sha(event["before"])
        require(parents and parents[0] == base, "push before is not candidate first parent")
    elif event_name == "workflow_dispatch":
        require(event.get("ref") == "refs/heads/main" and parents,
                "manual qualification must target main")
        base = parents[0]
    else:
        raise ValueError("unsupported policy-selection event")
    git(repository, "merge-base", "--is-ancestor", base, candidate)
    bootstrap = not has_policy(repository, base)
    policy = base
    if bootstrap:
        reviewed_bootstrap(repository, base)
        if event_name == "pull_request":
            require(has_policy(repository, candidate), "first policy candidate has no verifier")
            policy = candidate
        else:
            require(len(parents) == 2 and parents[0] == base,
                    "first policy main transition requires a two-parent merge")
            policy = parents[1]
            require(has_policy(repository, policy), "merge second parent has no successor policy")
            git(repository, "merge-base", "--is-ancestor", base, policy)
            # A merge may combine the reviewed base's build fixes, but cannot
            # introduce new verifier bytes absent from the reviewed policy PR.
            require(not git(repository, "diff", "--name-only", policy, candidate, "--",
                            "scripts", ".github/workflows", "docs/evidence",
                            "docs/requirements.txt", "alire.toml", "tests/alire.toml"),
                    "first main merge substituted verifier/workflow/evidence")
    require(policy != candidate or bootstrap, "candidate cannot select itself as ordinary policy")
    return {"event": event_name, "candidate": candidate, "base": base,
            "base_tree": git(repository, "rev-parse", base + "^{tree}"),
            "policy_revision": policy,
            "policy_tree": git(repository, "rev-parse", policy + "^{tree}"),
            "bootstrap_exploratory": bootstrap, "policy_approved": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--policy-checkout", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--event", required=True)
    parser.add_argument("--event-path", type=Path, required=True)
    args = parser.parse_args()
    result = select(args.repository, args.event, json.loads(args.event_path.read_text()), args.candidate)
    require(not git(args.policy_checkout, "status", "--porcelain"), "policy selection checkout is dirty")
    git(args.policy_checkout, "checkout", "--detach", result["policy_revision"])
    require(not git(args.policy_checkout, "status", "--porcelain"), "selected policy checkout is dirty")
    print(json.dumps(result, sort_keys=True))
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write("POLICY_REVIEW_FLAG=" + ("--policy-review" if result["bootstrap_exploratory"] else "") + "\n")
        output.write("TRUSTED_POLICY_SHA=" + result["policy_revision"] + "\n")


if __name__ == "__main__":
    main()