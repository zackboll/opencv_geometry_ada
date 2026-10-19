#!/usr/bin/env python3
"""Read-only successor review driver; candidate code never supplies validators."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile
import uuid

from additive_gnatdoc_policy import (
    ROOT, PREDECESSOR, EVIDENCE, GUIDE, EXAMPLE, candidate_rules,
    exact_snapshot, policy_identity, authored_contract, current_output, coverage,
    read, regular, require, sha, git, file_hashes, write, aunit_results,
)
from qualify_shared_gnatdoc_shadow import (
    Session, CORE, GNATDOC_SHA256, native, provenance, resolved_core, EXAMPLES,
    check_files,
)


def source_rules(baseline, source, synthetic):
    if synthetic:
        from additive_gnatdoc_fixture import validate, NAME
        validate(source, ROOT)
        from additive_gnatdoc_policy import ADDITIONS
        return candidate_rules(baseline, source, ADDITIONS | {NAME})
    return candidate_rules(baseline, source)


def verify(workspace, repository, revision, policy_revision, synthetic=False):
    policy_tree = policy_identity(policy_revision)
    git(repository, "merge-base", "--is-ancestor", policy_revision, revision)
    source = workspace / "source"
    require(git(source, "rev-parse", "HEAD").decode().strip() == revision,
            "stale/substituted candidate commit")
    tree = exact_snapshot(source, repository, revision, pins=True)
    for name, pin in (("alire.toml", "../core"), ("tests/alire.toml", "../../core")):
        original = git(repository, "show", f"{revision}:{name}")
        expected = original + ("\n[[pins]]\nopencv_core = { path='" + pin + "' }\n").encode()
        require(regular(source / name) == expected, "unauthorized build-clone manifest mutation")
    exact_snapshot(workspace / "baseline", repository, PREDECESSOR)
    rules = source_rules(workspace / "baseline", source, synthetic)
    require(not git(source, "diff", "--name-only", "--", ".", ":(exclude)alire.toml",
                    ":(exclude)tests/alire.toml"), "tracked candidate files changed")
    require(sha(regular(workspace / "gnatdoc/bin/gnatdoc")) == GNATDOC_SHA256,
            "native generator changed")
    require(file_hashes(workspace / "pristine-first") == file_hashes(workspace / "pristine-second"),
            "native acquisitions differ")
    # Reconstruct native output independently of all claimed manifests.
    with tempfile.TemporaryDirectory(prefix="additive-native-recheck-") as folder:
        temp = Path(folder)
        native(Session(temp), source, workspace / "gnatdoc/bin/gnatdoc",
               temp / "native", temp / "native.log")
        require(file_hashes(temp / "native") == file_hashes(workspace / "pristine-first"),
                "fresh native reconstruction differs")
    root = workspace / "first"
    exact_snapshot(root, repository, revision)
    source_rules(workspace / "baseline", root, synthetic)
    payload, config = authored_contract(source, workspace / "pristine-first")
    require(regular(root / "current-authored.json") == payload and
            regular(root / "current-shadow.toml") == config, "forged authored input contract")
    for name in ("opencv-geometry.ads", "opencv-geometry-subdiv2d.ads"):
        require(regular(root / "qualification-public/src" / name) == regular(source / "src" / name),
                "staged source/native mismatch")
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.pipeline import verify as verify_site
    from ada_gnatdoc_enhancer.qualification import bind_pristine, identities, preserve_native
    site = root / "_site"
    verify_site(load(root, "current-shadow.toml"), site)
    bind_pristine(workspace / "pristine-first", site)
    preserved = preserve_native(identities(workspace / "pristine-first"), site)
    require(preserved["packages"] == 2 and preserved["declarations"] == rules["declarations"],
            "current native declaration loss")
    core = read(ROOT / EVIDENCE / "core-0.5.0-types.json")
    comparison = current_output(source, workspace / "pristine-first", site, core)
    cov = coverage(source, site, workspace / "native-first.log")
    executed = aunit_results(source, regular(workspace / "aunit.log").decode())
    require(executed["registered"] == rules["aunit_registered"], "AUnit source/execution mismatch")
    return {"policy_revision": policy_revision, "policy_tree": policy_tree,
            "candidate": revision, "candidate_tree": tree, "rules": rules,
            "coverage": cov, "aunit": executed, "comparison": comparison}


def historical_verify(workspace, historical_workspace):
    """Execute the immutable predecessor recorder, never accept a ready boolean."""
    baseline = workspace / "baseline"
    exact_snapshot(baseline, ROOT, PREDECESSOR)
    import subprocess
    completed = subprocess.run(
        [sys.executable, str(baseline / "scripts/record_shared_gnatdoc_shadow.py"),
         "--workspace", str(historical_workspace)], cwd=baseline,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    require(completed.returncode == 0, "historical independent recorder failed: " + completed.stdout)
    history = read(historical_workspace / "readiness.json")
    require(history["full_shadow_qualification"] and history["consumer_tested"] == PREDECESSOR,
            "historical predecessor identity differs")
    attacks = read(historical_workspace / "negative.json")
    require(attacks["executed"] >= 30 and attacks["restored_and_verified"],
            "historical attack threshold differs")
    return sha(regular(historical_workspace / "qualification.json"))


def qualify(args):
    workspace = args.workspace.absolute()
    require(not workspace.exists() and not workspace.is_relative_to(ROOT),
            "workspace must be new and separate from policy")
    policy_identity(args.policy_revision)
    require(args.candidate_revision != args.policy_revision or args.policy_review,
            "candidate cannot serve as its own policy authority")
    workspace.mkdir(parents=True)
    session = Session(workspace)
    report = {"status": "fail", "disposition": "SUCCESSOR_TRUST_POLICY_NOT_ESTABLISHED",
              "policy_approved": False, "non_deployable": True,
              "run_id": str(uuid.uuid4()), "candidate": args.candidate_revision,
              "policy_revision": args.policy_revision, "policy_review": args.policy_review}
    try:
        provenance(args.enhancer)
        predecessor = read(args.historical_workspace / "qualification.json")
        require(predecessor["consumer_tested"] == PREDECESSOR and not predecessor.get("failure"),
                "predecessor baseline is absent/stale")
        require(predecessor["historical"]["aunit"]["registered"] == 542 and
                predecessor["aunit"]["registered"] == 547, "predecessor AUnit identity differs")
        report["predecessor"] = {"revision": PREDECESSOR,
                                  "qualification_sha256": sha(regular(args.historical_workspace / "qualification.json")),
                                  "historical": predecessor["historical"]}
        baseline, source = workspace / "baseline", workspace / "source"
        session.clone(args.candidate_repository, PREDECESSOR, baseline)
        session.clone(args.candidate_repository, args.candidate_revision, source)
        exact_snapshot(source, args.candidate_repository, args.candidate_revision)
        source_rules(baseline, source, args.synthetic)
        core = workspace / "core"
        session.clone(args.core, CORE, core)
        spec = read(ROOT / EVIDENCE / "core-0.5.0-input.json")
        check_files(core, spec["source_sha256"])
        for target, pin in ((source, "../core"), (source / "tests", "../../core")):
            session.run(["alr", "-n", "pin", "opencv_core", "--use=" + pin], target)
        session.run(["alr", "-n", "build"], source)
        compiler = session.run(["alr", "exec", "--", "gnat", "--version"], source)
        builder = session.run(["alr", "exec", "--", "gprbuild", "--version"], source)
        require(compiler.splitlines()[0] == "GNAT 16.1.0" and
                builder.startswith("GPRBUILD 26.0.0 (2026-04-15)"),
                "unqualified compiler/project tools")
        report["compiler"], report["gprbuild"] = compiler, builder
        resolved_core(session, source, core)
        shutil.copytree(args.gnatdoc_prefix, workspace / "gnatdoc")
        require(sha(regular(workspace / "gnatdoc/bin/gnatdoc")) == GNATDOC_SHA256,
                "wrong GNATdoc bytes")
        for label in ("first", "second"):
            native(session, source, workspace / "gnatdoc/bin/gnatdoc",
                   workspace / ("pristine-" + label), workspace / ("native-" + label + ".log"))
        native(session, core, workspace / "gnatdoc/bin/gnatdoc",
               workspace / "core-native", workspace / "core-native.log")
        require(file_hashes(workspace / "core-native") == spec["pristine_sha256"],
                "Core native evidence differs")
        for project, folder, mains in (("docs/example.gpr", "docs-example", ("example",)),
                                      ("docs/examples/examples.gpr", "docs-examples", EXAMPLES)):
            session.run(["alr", "exec", "--", "gprbuild", "-P", project], source)
            for main in mains:
                session.run([source / "obj" / folder / main], source)
        output = session.run(["alr", "-n", "run"], source / "tests")
        (workspace / "aunit.log").write_text(output + "\n")
        from ada_gnatdoc_enhancer.config import load
        from ada_gnatdoc_enhancer.pipeline import enhance
        results = []
        for label in ("first", "second"):
            root = workspace / label
            session.clone(args.candidate_repository, args.candidate_revision, root)
            for name in ("src/opencv-geometry.ads", "src/opencv-geometry-subdiv2d.ads"):
                dest = root / "qualification-public" / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(regular(source / name))
            for name in spec["source_sha256"]:
                dest = root / "dependency/source" / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(regular(core / name))
            shutil.copytree(workspace / "core-native", root / "dependency/native")
            shutil.copytree(workspace / ("pristine-" + label), root / "_site")
            payload, config = authored_contract(source, workspace / ("pristine-" + label))
            (root / "current-authored.json").write_bytes(payload)
            (root / "current-shadow.toml").write_bytes(config)
            configuration = load(root, "current-shadow.toml")
            before = file_hashes(root / "_site")
            enhance(configuration, root / "_site", dry_run=True)
            require(file_hashes(root / "_site") == before, "dry run modified native output")
            enhance(configuration, root / "_site")
            state = file_hashes(root / "_site")
            enhance(configuration, root / "_site")
            require(state == file_hashes(root / "_site"), "non-idempotent current output")
            results.append(state)
        require(results[0] == results[1], "two-copy current output differs")
        report["verification"] = verify(workspace, args.candidate_repository,
                                        args.candidate_revision, args.policy_revision, args.synthetic)
        report["synthetic_not_for_release"] = args.synthetic
        report["shadow_sha256"] = results[0]
        report["status"] = "pass"
        # This is deliberately not readiness: browsers, attacks and independent
        # execution evidence must still be verified by a separate recorder.
        report["disposition"] = "LOCAL_COMPONENT_QUALIFIED_NOT_READY"
    except Exception as error:
        report["failure"] = {"type": type(error).__name__, "reason": str(error)}
        raise
    finally:
        report["commands_sha256"] = sha(regular(workspace / "commands.json")) if session.commands else None
        write(workspace / "qualification.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "candidate-repository", "core", "enhancer",
                 "gnatdoc-prefix", "historical-workspace"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("candidate-revision", "policy-revision"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--policy-review", action="store_true",
                        help="exploratory policy-PR execution, never approval")
    parser.add_argument("--synthetic", action="store_true",
                        help="accept only the exact policy-owned disposable fixture")
    qualify(parser.parse_args())