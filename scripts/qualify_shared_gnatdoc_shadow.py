#!/usr/bin/env python3
"""Isolated Geometry GNATDOC-009B qualification, never production publication.

No authority creation/update command exists. Trust changes require code review.
Temporary Alire pins are confined to newly cloned disposable build checkouts.
"""
from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib
from urllib.parse import unquote, urlsplit
import uuid

from investigate_shared_gnatdoc_types import regular, require, sha, git
from compare_shared_gnatdoc_geometry import compare, file_hashes, write

ROOT = Path(__file__).absolute().parents[1]
BASE = "ec4d689eac748b7837abd4c3754c3090ca4bf814"
ENHANCER = "426f38852ef7dfff264f73ad01aab458f5e12b23"
CORE = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
EVIDENCE = "docs/evidence/gnatdoc009b"
TRANSITION = EVIDENCE + "/authority-transition.json"
TRANSITION_SHA256 = "ddf461928a5fc7a3ab4fc9ed0248c237aa465e581249708a5390496b7b447cb5"
CONFIG = "docs/shared-gnatdoc-shadow.toml"
GNATDOC = "GNATdoc 26.0.0 (20260415)"
EXAMPLES = ("contours_and_moments", "fitting_and_intersections", "affine_and_perspective",
            "delaunay_and_voronoi", "compatibility_and_safety")


def safe(path):
    path = Path(path).absolute()
    require(not any(p.is_symlink() for p in (path, *path.parents)), "unsafe symlink path")
    if path.is_dir():
        require(not any(p.is_symlink() for p in path.rglob("*")), "unsafe nested symlink")
    return path


def read(path):
    def unique(items):
        result = {}
        for k, v in items:
            require(k not in result, "duplicate trust/evidence key")
            result[k] = v
        return result
    return json.loads(regular(path), object_pairs_hook=unique)


def check_files(root, expected):
    for name, digest in expected.items():
        require(not Path(name).is_absolute() and ".." not in Path(name).parts,
                "unsafe authority path traversal")
        require(sha(regular(root / name)) == digest, f"authority bytes differ: {name}")


def trusted_inputs(root=ROOT):
    require(sha(regular(root / TRANSITION)) == TRANSITION_SHA256, "authority transition digest differs")
    transition = read(root / TRANSITION)
    require(transition["geometry_baseline"] == BASE and transition["enhancer_merge"] == ENHANCER
            and transition["core_source"] == CORE and
            transition["publication"] == "shadow-only / offline-test / non-deployable",
            "authority transition identity differs")
    check_files(root, transition["baseline_files_sha256"])
    check_files(root / EVIDENCE, transition["contracts_sha256"])
    check_files(root, {CONFIG: transition["configuration_sha256"]})
    return transition


class Session:
    def __init__(self, workspace):
        self.workspace, self.commands = workspace, []

    def run(self, argv, cwd, accepted=(0,), env=None):
        argv = [str(a) for a in argv]
        result = subprocess.run(argv, cwd=cwd, env={**os.environ, "DOC_PYTHON": sys.executable,
                                **(env or {})}, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        log = self.workspace / f"command-{len(self.commands):03}.log"
        log.write_text(result.stdout)
        self.commands.append({"argv": argv, "cwd": str(cwd), "exit": result.returncode,
                              "log": log.name, "sha256": sha(regular(log))})
        write(self.workspace / "commands.json", self.commands)
        require(result.returncode in accepted, f"command failed: {argv}; see {log}")
        return result.stdout.strip()

    def clone(self, repository, revision, target):
        self.run(["git", "clone", "--no-hardlinks", "--no-checkout", repository, target], self.workspace)
        self.run(["git", "checkout", "--detach", revision], target)
        require(self.run(["git", "rev-parse", "HEAD"], target) == revision, "clone identity differs")


def provenance(enhancer):
    require(git(enhancer, "rev-parse", "HEAD").decode().strip() == ENHANCER, "wrong enhancer commit")
    require(not git(enhancer, "status", "--porcelain", "--untracked-files=no"), "modified enhancer")
    git(enhancer, "merge-base", "--is-ancestor", ENHANCER, "origin/main")
    origin = git(enhancer, "remote", "get-url", "origin").decode().strip().removesuffix(".git")
    require(origin in ("https://github.com/zackboll/ada-gnatdoc-enhancer",
                       "git@github.com:zackboll/ada-gnatdoc-enhancer"), "wrong enhancer repository")
    dist = importlib.metadata.distribution("ada-gnatdoc-enhancer")
    direct = json.loads(dist.read_text("direct_url.json"))
    require(unquote(urlsplit(direct["url"]).path) == str(enhancer) and
            not direct.get("dir_info", {}).get("editable"), "wrong installed enhancer origin")
    def package_hashes(root):
        return {p.relative_to(root).as_posix(): sha(regular(p)) for p in root.rglob("*")
                if p.is_file() and "__pycache__" not in p.parts}
    expected = package_hashes(enhancer / "src/ada_gnatdoc_enhancer")
    require(package_hashes(Path(dist.locate_file("ada_gnatdoc_enhancer"))) == expected,
            "modified installed enhancer asset/module")
    require(importlib.metadata.version("markdown-it-py") == "3.0.0" and
            importlib.metadata.version("mdurl") == "0.1.2", "wrong Markdown dependencies")
    return {"revision": ENHANCER, "direct_url": direct, "installed_sha256": expected}


def resolved_core(session, checkout, core):
    resolved = session.run(["alr", "-n", "exec", "--", "printenv", "OPENCV_CORE_ALIRE_PREFIX"], checkout)
    require(Path(resolved).absolute() == core.absolute(), "incorrect Alire Core resolution")
    states = tomllib.loads(regular(checkout / "alire/alire.lock").decode())["solution"]["state"]
    states = [s for s in states if s["crate"] == "opencv_core"]
    require(len(states) == 1 and states[0]["fulfilment"] == "linked" and
            (checkout / states[0]["link"]["path"]).resolve() == core.resolve(), "incorrect Core lock")
    require(git(core, "rev-parse", "HEAD").decode().strip() == CORE and
            not git(core, "status", "--porcelain", "--untracked-files=no"), "incorrect Core source")
    return {"resolved": resolved, "state": states[0], "revision": CORE}


def gates(session, source, site, log):
    coverage = session.run([sys.executable, "scripts/check_doc_coverage.py", "--fail-on-removed",
                            "docs/gnatdoc-coverage-baseline.txt", site], source)
    warnings = session.run([sys.executable, "scripts/compare_gnatdoc_warnings.py", "--fail-on-removed",
                            "docs/gnatdoc-warning-baseline.txt", log], source)
    require(coverage == "Documentation coverage: 452/452 items (100.0%); 0 newly undocumented, 0 newly documented"
            and warnings == "GNATdoc warning delta: 0 added, 0 removed", "original ratchet failed")
    return {"coverage": coverage, "warnings": warnings}


def native(session, source, gnatdoc, output, log):
    for name in ("obj/docs", "obj/docs-internal"):
        (source / name).mkdir(parents=True, exist_ok=True)
    text = session.run(["alr", "exec", "--", gnatdoc, "-P", "docs_api.gpr", "--backend", "html",
                        "--generate", "public", "--style", "leading", "--warnings", "-O", output / "api"], source)
    require(not re.search(r"(^|\s)(error:|fatal:|ignore file due to)", text, re.I), "partial native generation")
    log.write_text(text + "\n")


def verify_publication(workspace, enhancer=None):
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.pipeline import verify
    from ada_gnatdoc_enhancer.qualification import bind_pristine, identities, preserve_native
    trusted_inputs()
    if enhancer is not None:
        provenance(enhancer)
    root = workspace / "first"
    transition = trusted_inputs(root)
    require(file_hashes(workspace / "pristine-first") == transition["pristine_sha256"],
            "pristine input no longer matches reviewed authority")
    authored = read(root / EVIDENCE / "geometry-authored.json")
    check_files(root, authored["inputs"])
    for name in ("src/opencv-geometry.ads", "src/opencv-geometry-subdiv2d.ads"):
        require(regular(root / "qualification-public" / name) == regular(root / name), "staged source changed")
    site = root / "_site"
    publication = verify(load(root, CONFIG), site)
    bind_pristine(workspace / "pristine-first", site)
    preserved = preserve_native(identities(workspace / "pristine-first"), site)
    require(preserved["packages"] == 2 and preserved["declarations"] == 130, "native declaration loss")
    check_files(site, transition["authored_output_sha256"])
    return {"publication": publication, "native": preserved, "comparison": compare(workspace)}


def qualify(args):
    workspace = safe(args.workspace)
    require(not workspace.exists() and not workspace.is_relative_to(ROOT), "workspace must be new and isolated")
    workspace.mkdir(parents=True)
    s = Session(workspace)
    report = {"run_id": str(uuid.uuid4()), "consumer_tested": args.expected_head, "consumer_start": BASE,
              "enhancer": ENHANCER, "core": CORE, "authority_transition_sha256": TRANSITION_SHA256,
              "non_deployable": True, "disposition": "PARTIAL_SHADOW_COMPATIBILITY"}
    try:
        require(git(ROOT, "rev-parse", "HEAD").decode().strip() == args.expected_head, "Geometry exact HEAD differs")
        require(not git(ROOT, "status", "--porcelain"), "Geometry snapshot is not clean")
        git(ROOT, "merge-base", "--is-ancestor", BASE, "HEAD")
        transition = trusted_inputs()
        report["tool"] = provenance(safe(args.enhancer))
        for name, path in transition["contract_provenance"].items():
            require(regular(ROOT / EVIDENCE / name) == git(args.enhancer, "show", f"{ENHANCER}:{path}"),
                    "reviewed enhancer authority provenance differs")
        require(s.run(["alr", "--version"], ROOT) == "alr 2.1.1", "wrong Alire")
        s.run([sys.executable, "-m", "pip", "check"], ROOT)
        legacy, source, core = (workspace / n for n in ("legacy", "source", "core"))
        for target in (legacy, source):
            s.clone(ROOT, args.expected_head, target)
            check_files(target, transition["baseline_files_sha256"])
        s.clone(safe(args.core), CORE, core)
        core_spec = read(ROOT / EVIDENCE / "core-0.5.0-input.json")
        check_files(core, core_spec["source_sha256"])
        for target in (legacy, source):
            s.run(["alr", "-n", "pin", "opencv_core", "--use=../core"], target)
            s.run(["alr", "-n", "build"], target)
            report.setdefault("core_resolution", {})[target.name] = resolved_core(s, target, core)
        compiler = s.run(["alr", "exec", "--", "gnat", "--version"], source)
        builder = s.run(["alr", "exec", "--", "gprbuild", "--version"], source)
        require(compiler.splitlines()[0] == "GNAT 16.1.0" and
                builder.startswith("GPRBUILD 26.0.0 (2026-04-15)"), "wrong compiler/project tools")
        report["compiler"], report["gprbuild"] = compiler, builder
        if args.gnatdoc_prefix:
            prefix = safe(args.gnatdoc_prefix)
        else:
            prefix = workspace / "gnatdoc"
            s.run(["alr", "-n", "install", f"--prefix={prefix}", "gnatdoc_bin=26.0.0"], source)
        gnatdoc = prefix / "bin/gnatdoc"
        require(s.run([gnatdoc, "--version"], source, (0, 1)) == GNATDOC, "wrong GNATdoc")
        report["gnatdoc"] = {"version": GNATDOC, "binary_sha256": sha(regular(gnatdoc))}
        s.run(["sh", "scripts/generate_docs.sh"], legacy, env={"GNATDOC_PREFIX": str(prefix)})
        legacy_first = file_hashes(legacy / "_site")
        s.run(["sh", "scripts/generate_docs.sh"], legacy, env={"GNATDOC_PREFIX": str(prefix)})
        require(file_hashes(legacy / "_site") == legacy_first, "legacy fresh generation is nondeterministic")
        for script in ("install_gnatdoc_theme.py", "link_gnatdoc_types.py", "highlight_gnatdoc_ada.py",
                       "enhance_gnatdoc_navigation.py"):
            options = ["--core", core] if script in ("link_gnatdoc_types.py", "highlight_gnatdoc_ada.py") else []
            s.run([sys.executable, "scripts/" + script, legacy / "_site/api", *options], legacy)
        s.run([sys.executable, "scripts/render_gnatdoc_guides.py", legacy / "_site"], legacy)
        require(file_hashes(legacy / "_site") == legacy_first, "legacy enhancement is not idempotent")
        report["legacy_deterministic"] = report["legacy_byte_idempotent"] = True
        # Execute the exact merged baseline suite. New shadow tests run separately
        # on the unpinned PR checkout, not a disposable modified Alire manifest.
        modules = sorted(Path(n).stem for n in transition["baseline_files_sha256"]
                         if n.startswith("scripts/test_") and n.endswith(".py"))
        tests = s.run([sys.executable, "-m", "unittest", "-v", *modules], legacy,
                      env={"PYTHONPATH": str(legacy / "scripts")})
        count = re.search(r"Ran (\d+) tests", tests)
        require(count is not None and int(count[1]) >= 232, "incomplete original documentation tests")
        report["documentation_tests"] = {"executed": int(count[1]), "status": "pass"}
        report["legacy_gates"] = gates(s, legacy, legacy / "_site", legacy / "obj/docs/gnatdoc.log")
        examples = []
        for project, folder, mains in (("docs/example.gpr", "docs-example", ("example",)),
                                       ("docs/examples/examples.gpr", "docs-examples", EXAMPLES)):
            s.run(["alr", "exec", "--", "gprbuild", "-P", project], legacy)
            for main in mains:
                s.run([legacy / "obj" / folder / main], legacy)
                examples.append({"project": project, "main": main, "build_exit": 0, "run_exit": 0})
        report["examples"] = examples
        s.run(["alr", "-n", "pin", "opencv_core", "--use=../../core"], legacy / "tests")
        aunit = s.run(["alr", "-n", "run"], legacy / "tests")
        require(re.search(r"Total Tests Run:\s+542", aunit) and
                re.search(r"Successful Tests:\s+542", aunit) and
                re.search(r"Failed Assertions:\s+0", aunit) and
                re.search(r"Unexpected Errors:\s+0", aunit), "AUnit baseline differs")
        report["aunit"] = {"executed": 542, "successful": 542}
        for label in ("first", "second"):
            native(s, source, gnatdoc, workspace / f"pristine-{label}", workspace / f"native-{label}.log")
            require(file_hashes(workspace / f"pristine-{label}") == transition["pristine_sha256"],
                    "native acquisition differs from reviewed authority")
        report["pristine_sha256"] = file_hashes(workspace / "pristine-first")
        from ada_gnatdoc_enhancer.qualification import identities
        write(workspace / "native-identities.json", identities(workspace / "pristine-first"))
        report["native_gates"] = gates(s, source, workspace / "pristine-first", workspace / "native-first.log")
        native(s, core, gnatdoc, workspace / "core-native", workspace / "core-native.log")
        require(file_hashes(workspace / "core-native") == core_spec["pristine_sha256"], "Core acquisition differs")
        from ada_gnatdoc_enhancer.external_types import inventory
        snapshot = workspace / "core-snapshot"
        for name in core_spec["source_sha256"]:
            target = snapshot / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(regular(core / name))
        manifest = inventory(core_spec, snapshot, workspace / "core-native")
        require(manifest == read(ROOT / EVIDENCE / "core-0.5.0-types.json"), "Core inventory differs")
        from ada_gnatdoc_enhancer.config import load
        from ada_gnatdoc_enhancer.inventory import packages
        from ada_gnatdoc_enhancer.pipeline import enhance
        outputs = []
        for label in ("first", "second"):
            root = workspace / label
            root.mkdir()
            for name in {*transition["baseline_files_sha256"], CONFIG, TRANSITION,
                         *(EVIDENCE + "/" + n for n in transition["contracts_sha256"])}:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(regular(ROOT / name))
            for name in ("src/opencv-geometry.ads", "src/opencv-geometry-subdiv2d.ads"):
                target = root / "qualification-public" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(regular(ROOT / name))
            for name in core_spec["source_sha256"]:
                target = root / "dependency/source" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(regular(core / name))
            shutil.copytree(workspace / "core-native", root / "dependency/native")
            shutil.copytree(workspace / f"pristine-{label}", root / "_site")
            config = load(root, CONFIG)
            packages(config)
            before = file_hashes(root / "_site")
            enhance(config, root / "_site", dry_run=True)
            require(file_hashes(root / "_site") == before, "dry-run mutated native input")
            enhance(config, root / "_site")
            state = file_hashes(root / "_site")
            enhance(config, root / "_site")
            require(file_hashes(root / "_site") == state, "not byte-idempotent")
            outputs.append(state)
        require(outputs[0] == outputs[1], "two-copy nondeterminism")
        report["verification"] = verify_publication(workspace, args.enhancer)
        report["shadow_gates"] = gates(s, source, workspace / "first/_site", workspace / "native-first.log")
        require(git(ROOT, "rev-parse", "HEAD").decode().strip() == args.expected_head and
                not git(ROOT, "status", "--porcelain"), "Geometry snapshot changed during qualification")
        report.update({"shadow_sha256": outputs[0], "legacy_sha256": file_hashes(legacy / "_site"),
                       "deterministic": True, "byte_idempotent": True,
                       "disposition": "HOSTED_CI_PENDING"})
    except Exception as exc:
        report["failure"] = {"type": type(exc).__name__, "reason": str(exc)}
        raise
    finally:
        report["commands_sha256"] = sha(regular(workspace / "commands.json")) if s.commands else None
        write(workspace / "qualification.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "enhancer", "core"):
        parser.add_argument("--" + name, type=lambda p: Path(p).absolute(), required=True)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--gnatdoc-prefix", type=lambda p: Path(p).absolute())
    qualify(parser.parse_args())