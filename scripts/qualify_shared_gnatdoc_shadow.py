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
import tempfile
import tomllib
from urllib.parse import unquote, urlsplit
import uuid

from investigate_shared_gnatdoc_types import regular, require, sha, git
from compare_shared_gnatdoc_geometry import compare, file_hashes, write

ROOT = Path(__file__).absolute().parents[1]
BASE = "ec4d689eac748b7837abd4c3754c3090ca4bf814"
REVIEWED = "2101e5c8757898b6904becfb899247e9f685c25b"
ENHANCER = "426f38852ef7dfff264f73ad01aab458f5e12b23"
CORE = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
EVIDENCE = "docs/evidence/gnatdoc009b"
TRANSITION = EVIDENCE + "/authority-transition.json"
TRANSITION_SHA256 = "ddf461928a5fc7a3ab4fc9ed0248c237aa465e581249708a5390496b7b447cb5"
CONFIG = "docs/shared-gnatdoc-shadow.toml"
GNATDOC = "GNATdoc 26.0.0 (20260415)"
GNATDOC_SHA256 = "d256f0ece2f181046dfeb3ce490d7aa5c994992550c78da14e9065d453aa52c5"
EXAMPLES = ("contours_and_moments", "fitting_and_intersections", "affine_and_perspective",
            "delaunay_and_voronoi", "compatibility_and_safety")

# Independent reference machinery, not evolving Geometry inputs. Hashes come
# only from the immutable historical transition below. Legitimate changes to
# this inventory or its components require a reviewed trust-policy transition;
# current HEAD and generated manifests cannot approve replacement bytes.
TRUSTED_SCRIPTS = (
    "scripts/check_comment_only.py",
    "scripts/check_doc_coverage.py",
    "scripts/compare_gnatdoc_warnings.py",
    "scripts/enhance_gnatdoc_navigation.py",
    "scripts/generate_docs.sh",
    "scripts/highlight_gnatdoc_ada.py",
    "scripts/install_gnatdoc_theme.py",
    "scripts/investigate_shared_gnatdoc_types.py",
    "scripts/link_gnatdoc_types.py",
    "scripts/render_gnatdoc_guides.py",
    "scripts/validate_docs.py",
    "scripts/test_check_comment_only.py",
    "scripts/test_check_doc_coverage.py",
    "scripts/test_compare_gnatdoc_warnings.py",
    "scripts/test_gnatdoc_guides.py",
    "scripts/test_gnatdoc_navigation.py",
    "scripts/test_investigate_shared_gnatdoc_types.py",
    "scripts/test_link_gnatdoc_types.py",
    "scripts/test_validate_docs.py",
    "scripts/test_core_type_links_browser.cjs",
    "scripts/test_gnatdoc_guides_browser.cjs",
    "scripts/test_gnatdoc_navigation_browser.cjs",
    "scripts/test_gnatdoc_presentation_browser.cjs",
)


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
    # Immutable Git objects, not today's implementation, own historical bytes.
    for name, digest in transition["baseline_files_sha256"].items():
        require(sha(git(ROOT, "show", f"{BASE}:{name}")) == digest,
                "historical source authority differs: " + name)
    for name in git(ROOT, "ls-tree", "-r", "--name-only", REVIEWED, "--",
                    "docs/evidence/gnatdoc009", EVIDENCE).decode().splitlines():
        require(regular(root / name) == git(ROOT, "show", f"{REVIEWED}:{name}"),
                "historical evidence differs: " + name)
    check_files(root / EVIDENCE, transition["contracts_sha256"])
    check_files(root, {CONFIG: transition["configuration_sha256"]})
    authored = read(root / EVIDENCE / "geometry-authored.json")
    check_files(root, authored["inputs"])
    check_files(root, {name: transition["baseline_files_sha256"][name]
                       for name in TRUSTED_SCRIPTS})
    # The production documentation machinery and authored navigation stay fixed.
    fixed = {n: d for n, d in transition["baseline_files_sha256"].items()
             if n in ("docs_api.gpr", "docs_internal.gpr", "docs/api-categories.json") or
             n.startswith(("docs/assets/", "docs/guides/", "docs/examples/"))}
    check_files(root, fixed)
    return transition


def check_current_sources(root, revision):
    """Bind staged/current inputs directly to the checkout's immutable HEAD."""
    names = git(ROOT, "ls-tree", "-r", "--name-only", revision).decode().splitlines()
    inputs = [n for n in names if n.startswith(("src/", "cpp/", "tests/src/"))]
    for name in inputs:
        require(regular(root / name) == git(ROOT, "show", f"{revision}:{name}"),
                "current source differs from exact HEAD: " + name)
    for prefix in ("src", "cpp", "tests/src"):
        actual = {p.relative_to(root).as_posix() for p in (root / prefix).rglob("*") if p.is_file()}
        require(actual == {n for n in inputs if n.startswith(prefix + "/")},
                "current source inventory differs: " + prefix)


def registered_cases(source):
    """Fail on unsupported suite construction, rather than guess a denominator."""
    from compare_gnatdoc_warnings import code_tokens
    main = "\n".join(code_tokens(line) for line in regular(source / "tests/src/tests.adb").decode().splitlines())
    suites = re.findall(r"\b([A-Za-z0-9_]+_Tests)\.Suite\b", main, re.I)
    require(suites and len(suites) == len(set(s.lower() for s in suites)), "duplicate/missing AUnit suites")
    cases = []
    for suite in suites:
        text = regular(source / "tests/src" / (suite.lower() + ".adb")).decode()
        # Preserve string literals; comments cannot supply fake registrations.
        text = re.sub(r'"(?:[^"\n]|"")*"|--[^\n]*',
                      lambda m: "" if m[0].startswith("--") else m[0], text)
        body = re.search(r"\bfunction\s+Suite\s+return\b(.*?)\bend\s+Suite\s*;", text, re.S | re.I)
        require(body is not None and not re.search(r"\b(if|loop|case|goto)\b",
                re.sub(r'"(?:[^"\n]|"")*"', '""', body[1]), re.I),
                "unsupported AUnit suite construction: " + suite)
        calls = re.findall(r'Caller\.Create\s*\(\s*"((?:[^"\n]|"")*)"\s*,\s*\w+\s*\'Access\s*\)',
                           body[1], re.I)
        require(len(calls) == len(re.findall(r"\bAdd_Test\b", body[1], re.I)) > 0,
                "unaccounted AUnit registration: " + suite)
        cases.extend(c.replace('""', '"') for c in calls)
    require(len(cases) >= 542 and len(cases) == len(set(cases)), "AUnit registration regression/duplicates")
    return cases


def aunit_results(source, output):
    cases = registered_cases(source)
    successful = re.findall(r"^OK (.+)$", output, re.M)
    require(sorted(successful) == sorted(cases), "AUnit executed cases differ from registrations")
    for label, expected in (("Total Tests Run", len(cases)), ("Successful Tests", len(cases)),
                            ("Failed Assertions", 0), ("Unexpected Errors", 0)):
        require(re.findall(r"^" + label + r":\s*(\d+)\s*$", output, re.M) == [str(expected)],
                "AUnit totals differ: " + label)
    return {"registered": len(cases), "executed": len(successful), "successful": len(successful),
            "failed_assertions": 0, "unexpected_errors": 0, "cases": cases}


def staged_contract(root, pristine):
    """Only native bindings vary; immutable authored policy/inputs never do."""
    authored = read(ROOT / EVIDENCE / "geometry-authored.json")
    authored["native_sha256"] = file_hashes(pristine)
    payload = (json.dumps(authored, sort_keys=True, indent=2) + "\n").encode()
    config = regular(ROOT / CONFIG).replace(
        b'manifest = "docs/evidence/gnatdoc009b/geometry-authored.json"',
        b'manifest = "current-authored.json"').replace(
        read(ROOT / TRANSITION)["contracts_sha256"]["geometry-authored.json"].encode(), sha(payload).encode())
    return payload, config


def historical_references(workspace):
    """Recheck the reviewed ledger/oracle against their own source and native."""
    from investigate_shared_gnatdoc_types import sections
    from link_gnatdoc_types import Sources
    from enhance_gnatdoc_navigation import entries
    source, site = workspace / "historical", workspace / "historical-first"
    native_sections = sections(site)
    sources = Sources(source / "src")
    ledger = read(ROOT / "docs/evidence/gnatdoc009/type-link-occurrences.json")
    require(len(ledger) == 267 and len(native_sections) == 130, "historical reference inventory differs")
    for row in ledger:
        page, name, snippet = native_sections[row["package"], row["native_anchor"]]
        package = sources.packages[row["package"].lower()]
        declaration = package.match(snippet.text)
        require(page == row["native_page"] and name == row["declaration"] and
                declaration["signature"] == row["complete_source_profile"] and
                declaration["start"] == row["source_line"] and
                "\n".join(package.lines[declaration["start"] - 1:declaration["end"]]) ==
                row["exact_source_declaration"], "historical source-backed occurrence differs")
    oracle = entries(site / "api", source / "src", source / "docs/api-categories.json")
    require(json.loads(json.dumps(oracle)) == read(
        ROOT / "docs/evidence/gnatdoc009/original-navigation.json"), "historical navigation differs")
    return {"occurrences": 267, "navigation_entries": 130, "revision": BASE}


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
    source = enhancer / "src/ada_gnatdoc_enhancer"
    tracked = git(enhancer, "ls-tree", "-r", "--name-only", ENHANCER,
                  "--", "src/ada_gnatdoc_enhancer").decode().splitlines()
    expected = {Path(n).relative_to("src/ada_gnatdoc_enhancer").as_posix():
                sha(git(enhancer, "show", f"{ENHANCER}:{n}")) for n in tracked}
    require(package_hashes(source) == expected, "enhancer package inventory differs from immutable Git tree")
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
    revision = git(ROOT, "rev-parse", "HEAD").decode().strip()
    require(not git(ROOT, "status", "--porcelain"), "Geometry snapshot is not clean")
    check_current_sources(root, revision)
    source = workspace / "source"
    trusted_inputs(source)
    check_current_sources(source, revision)
    trusted_inputs(workspace / "legacy")
    check_current_sources(workspace / "legacy", revision)
    require(file_hashes(workspace / "historical-first") == transition["pristine_sha256"] ==
            file_hashes(workspace / "historical-second"), "historical native evidence differs")
    # The only permitted tracked mutation in build clones is Alire's Core pin.
    check_files(workspace / "historical", {n: d for n, d in transition["baseline_files_sha256"].items()
                                         if n not in ("alire.toml", "tests/alire.toml")})
    historical_references(workspace)
    require(sha(regular(workspace / "gnatdoc/bin/gnatdoc")) == GNATDOC_SHA256,
            "native generator bytes differ")
    # Reexecute native generation, not a hash claim in qualification.json or
    # presentation.json. Even coordinated pristine/output/manifest forgery fails.
    with tempfile.TemporaryDirectory(prefix="geometry-native-verification-") as directory:
        temp = Path(directory)
        native(Session(temp), source, workspace / "gnatdoc/bin/gnatdoc",
               temp / "native", temp / "native.log")
        require(file_hashes(temp / "native") == file_hashes(workspace / "pristine-first") ==
                file_hashes(workspace / "pristine-second"), "fresh native reconstruction differs")
    payload, config = staged_contract(root, workspace / "pristine-first")
    require(regular(root / "current-authored.json") == payload and
            regular(root / "current-shadow.toml") == config, "derived current contract differs")
    authored = read(root / EVIDENCE / "geometry-authored.json")
    check_files(root, authored["inputs"])
    for name in ("src/opencv-geometry.ads", "src/opencv-geometry-subdiv2d.ads"):
        require(regular(root / "qualification-public" / name) == regular(root / name), "staged source changed")
    site = root / "_site"
    publication = verify(load(root, "current-shadow.toml"), site)
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
        tracked = git(ROOT, "ls-tree", "-r", "--name-only", args.expected_head).decode().splitlines()
        expected_ada = {n for n in transition["baseline_files_sha256"]
                        if Path(n).suffix.lower() in (".ads", ".adb")}
        require({n for n in tracked if Path(n).suffix.lower() in (".ads", ".adb")} == expected_ada,
                "Ada source inventory changed")
        for prefix_name in ("src/", "cpp/", "docs/guides/", "docs/examples/", "docs/assets/"):
            require({n for n in tracked if n.startswith(prefix_name)} ==
                    {n for n in transition["baseline_files_sha256"] if n.startswith(prefix_name)},
                    "production source/authored inventory changed: " + prefix_name)
        report["tool"] = provenance(safe(args.enhancer))
        for name, path in transition["contract_provenance"].items():
            require(regular(ROOT / EVIDENCE / name) == git(args.enhancer, "show", f"{ENHANCER}:{path}"),
                    "reviewed enhancer authority provenance differs")
        require(s.run(["alr", "--version"], ROOT) == "alr 2.1.1", "wrong Alire")
        s.run([sys.executable, "-m", "pip", "check"], ROOT)
        legacy, source, core = (workspace / n for n in ("legacy", "source", "core"))
        for target in (legacy, source):
            s.clone(ROOT, args.expected_head, target)
            check_current_sources(target, args.expected_head)
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
            prefix = workspace / "gnatdoc"
            shutil.copytree(safe(args.gnatdoc_prefix), prefix)
        else:
            prefix = workspace / "gnatdoc"
            s.run(["alr", "-n", "install", f"--prefix={prefix}", "gnatdoc_bin=26.0.0"], source)
        gnatdoc = prefix / "bin/gnatdoc"
        require(sha(regular(gnatdoc)) == GNATDOC_SHA256, "wrong native generator bytes")
        require(s.run([gnatdoc, "--version"], source, (0, 1)) == GNATDOC, "wrong GNATdoc")
        report["gnatdoc"] = {"version": GNATDOC, "binary_sha256": sha(regular(gnatdoc))}
        historical = workspace / "historical"
        s.clone(ROOT, BASE, historical)
        check_files(historical, transition["baseline_files_sha256"])
        s.run(["alr", "-n", "pin", "opencv_core", "--use=../core"], historical)
        s.run(["alr", "-n", "build"], historical)
        for label in ("first", "second"):
            native(s, historical, gnatdoc, workspace / ("historical-" + label),
                   workspace / ("historical-" + label + ".log"))
            require(file_hashes(workspace / ("historical-" + label)) == transition["pristine_sha256"],
                    "historical native acquisition differs from reviewed authority")
        s.run(["alr", "-n", "pin", "opencv_core", "--use=../../core"], historical / "tests")
        history_aunit = aunit_results(historical, s.run(["alr", "-n", "run"], historical / "tests"))
        require(history_aunit["registered"] == 542, "historical AUnit baseline differs")
        report["historical"] = {"revision": BASE, "aunit": history_aunit,
                                "pristine_sha256": transition["pristine_sha256"],
                                "references": historical_references(workspace)}
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
        report["aunit"] = aunit_results(legacy, aunit)
        for label in ("first", "second"):
            native(s, source, gnatdoc, workspace / f"pristine-{label}", workspace / f"native-{label}.log")
        require(file_hashes(workspace / "pristine-first") == file_hashes(workspace / "pristine-second"),
                "independent current native acquisitions differ")
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
            current_files = git(ROOT, "ls-tree", "-r", "--name-only", args.expected_head).decode().splitlines()
            for name in {*current_files, CONFIG, TRANSITION,
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
            payload, config_bytes = staged_contract(root, workspace / f"pristine-{label}")
            (root / "current-authored.json").write_bytes(payload)
            (root / "current-shadow.toml").write_bytes(config_bytes)
            config = load(root, "current-shadow.toml")
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