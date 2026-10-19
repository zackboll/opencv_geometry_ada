#!/usr/bin/env python3
"""Unprivileged two-track review campaign. Run from a separately checked out policy.

The first policy PR is necessarily exploratory; only independent review/merge
can make its revision a future verifier authority. No release/deploy action.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys

from additive_gnatdoc_policy import ROOT, PREDECESSOR, git, require, write
from qualify_shared_gnatdoc_shadow import Session


def run(args):
    require(not args.workspace.exists(), "campaign workspace must be new")
    args.workspace.mkdir(parents=True)
    session = Session(args.workspace)
    predecessor = args.workspace / "predecessor"
    historical = args.workspace / "historical-qualification"
    session.clone(args.candidate_repository, PREDECESSOR, predecessor)
    env = {"TMPDIR": str(args.workspace / "tmp")}
    (args.workspace / "tmp").mkdir()
    # Environment is inherited by renderer/native subprocesses too.
    os.environ.update(env)
    python = sys.executable
    session.run([python, "scripts/qualify_shared_gnatdoc_shadow.py",
                 "--workspace", historical, "--expected-head", PREDECESSOR,
                 "--enhancer", args.enhancer, "--core", args.core,
                 "--gnatdoc-prefix", args.gnatdoc_prefix], predecessor)
    session.run([python, "scripts/qualify_original_gnatdoc_browser.py", "--workspace", historical,
                 "--core-repository", args.core, "--gnatdoc-prefix", historical / "gnatdoc",
                 "--playwright-module", args.playwright_module, "--chromium", args.chromium], predecessor)
    session.run([python, "scripts/qualify_shared_gnatdoc_adversarial.py", "--workspace", historical,
                 "--enhancer", args.enhancer], predecessor)
    session.run([python, "scripts/qualify_shared_gnatdoc_browser.py", "--workspace", historical,
                 "--chromium", args.chromium], predecessor)
    session.run([python, "scripts/record_shared_gnatdoc_shadow.py", "--workspace", historical], predecessor)
    policy_revision = git(ROOT, "rev-parse", "HEAD").decode().strip()
    from additive_gnatdoc_fixture import create
    fixture_repository = args.workspace / "fixture-repository"
    fixture_revision = create(fixture_repository, policy_revision)
    current = args.workspace / "current"
    fixture = args.workspace / "fixture"
    for repository, revision, output, flags in (
        (args.candidate_repository, args.candidate_revision, current,
         ["--policy-review"] if args.policy_review else []),
        (fixture_repository, fixture_revision, fixture, ["--synthetic"]),
    ):
        common = ["--workspace", output, "--candidate-repository", repository,
                  "--candidate-revision", revision, "--policy-revision", policy_revision]
        session.run([python, "scripts/qualify_additive_gnatdoc.py", *common,
                     "--core", args.core, "--enhancer", args.enhancer,
                     "--gnatdoc-prefix", args.gnatdoc_prefix,
                     "--historical-workspace", historical, *flags], ROOT)
        session.run([python, "scripts/browser_additive_gnatdoc.py", "--workspace", output,
                     "--chromium", args.chromium], ROOT)
        session.run([python, "scripts/adversarial_additive_gnatdoc.py", *common,
                     *(["--synthetic"] if output == fixture else [])], ROOT)
    for repository, revision, output in ((fixture_repository, fixture_revision, fixture),
                                         (args.candidate_repository, args.candidate_revision, current)):
        session.run([python, "scripts/record_additive_gnatdoc.py", "--workspace", output,
                     "--candidate-repository", repository, "--candidate-revision", revision,
                     "--policy-revision", policy_revision, "--historical-workspace", historical,
                     *(["--fixture-workspace", fixture] if output == current else [])], ROOT)
    write(args.workspace / "campaign.json", {
        "status": "pass", "policy_approved": False, "non_deployable": True,
        "candidate": args.candidate_revision, "policy_revision": policy_revision,
        "policy_review": args.policy_review,
        "disposition": "HOSTED_CI_PENDING",
    })


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "candidate-repository", "enhancer", "core",
                 "gnatdoc-prefix", "playwright-module"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--candidate-revision", required=True)
    parser.add_argument("--chromium", required=True)
    parser.add_argument("--policy-review", action="store_true")
    args = parser.parse_args()
    try:
        run(args)
    except Exception as error:
        args.workspace.mkdir(parents=True, exist_ok=True)
        write(args.workspace / "campaign.json", {
            "status": "fail", "policy_approved": False, "non_deployable": True,
            "disposition": "SUCCESSOR_TRUST_POLICY_NOT_ESTABLISHED", "failure": str(error)})
        raise