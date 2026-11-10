#!/usr/bin/env python3
"""SHA-bound, non-publishing production preview from a separate policy checkout.

Run with the official wheel's non-editable Python environment. The historical
campaign still uses its own immutable enhancer environment. No approval record
is emitted, no branch is pushed, and PR #58 is never checked out or changed.
"""
import argparse
import json
import os
from pathlib import Path
import threading
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import sys

from gnatdoc_migration_policy import (
    ROOT, CONFIGURATION, WORKFLOW, installed_wheel, migration_generator,
    staged_public, validate_migration_site, envelope, regular, git, require, migration_workflow,
)
from additive_gnatdoc_policy import policy_identity, candidate_rules, exact_snapshot, coverage
from compare_shared_gnatdoc_geometry import file_hashes, write
from qualify_shared_gnatdoc_shadow import Session, CORE, EXAMPLES, native, aunit_results

MAIN = "05c6680cdf4f9fe544cfbbab21cf13eab41d0112"
MIGRATION = "02b8b2f1b3d6ba1bdca8582b1c09f6bd5f1d1935"
ADAPTER = '''    if enhanced and (root / "docs/gnatdoc-enhancer.toml").is_file():
        # Local release-format validation is not independent policy approval.
        from gnatdoc_migration_policy import validate_local_site
        try:
            return validate_local_site(root, site, core)
        except (ValueError, OSError, KeyError, ImportError) as error:
            raise DocumentationError(f"released enhancer integrity: {error}") from error
'''


def run(args):
    tree = policy_identity(args.policy_revision)
    require(not args.workspace.exists(), "preview workspace must be new")
    args.workspace.mkdir(parents=True)
    session = Session(args.workspace)
    report = {"status": "fail", "policy_approved": False, "non_deployable": True,
              "policy": args.policy_revision, "policy_tree": tree,
              "migration": MIGRATION, "main": MAIN}
    try:
        report["enhancer"] = installed_wheel(args.wheel)
        source, core = args.workspace / "candidate", args.workspace / "core"
        session.clone(ROOT, args.policy_revision, source)
        session.clone(args.core, CORE, core)
        git(ROOT, "merge-base", "--is-ancestor", MAIN, args.policy_revision)
        for name in sorted(CONFIGURATION | {"docs/documentation.md"}):
            (source / name).write_bytes(git(ROOT, "show", MIGRATION + ":" + name))
        # Apply the approved migration bodies to the CURRENT security skeleton;
        # a historical migration PR must not undo later publication controls.
        (source / WORKFLOW).write_text(migration_workflow(regular(ROOT / WORKFLOW).decode()))
        (source / "scripts/generate_docs.sh").write_text(
            migration_generator(regular(ROOT / "scripts/generate_docs.sh").decode()))
        path = source / "scripts/validate_docs.py"
        text = path.read_text()
        marker = "    errors = []\n    expected = public_specifications(root)"
        require(text.count(marker) == 1, "preview validator adapter boundary changed")
        path.write_text(text.replace(marker, ADAPTER + marker))
        session.run(["git", "add", "."], source)
        # A reproducible commit object bound to both the policy and migration.
        session.run(["git", "-c", "user.name=Geometry preview",
                     "-c", "user.email=preview@invalid.example", "commit", "-m",
                     "Disposable production preview of " + MIGRATION], source,
                    env={"GIT_AUTHOR_DATE": "2026-11-08T00:00:00Z",
                         "GIT_COMMITTER_DATE": "2026-11-08T00:00:00Z"})
        report["candidate"] = git(source, "rev-parse", "HEAD").decode().strip()
        report["candidate_tree"] = git(source, "rev-parse", "HEAD^{tree}").decode().strip()
        report["files"] = sorted(envelope(ROOT, source))
        report["source_rules"] = candidate_rules(ROOT, source)
        exact_snapshot(source, source, report["candidate"])
        for target, pin in ((source, "../core"), (source / "tests", "../../core")):
            session.run(["alr", "-n", "pin", "opencv_core", "--use=" + pin], target)
        env = {"DOC_PYTHON": sys.executable, "GNATDOC_PREFIX": str(args.gnatdoc_prefix)}
        os.environ["PRODUCTION_DOC_WHEEL"] = str(args.wheel)
        first = None
        for label in ("first", "second"):
            session.run(["sh", "scripts/generate_docs.sh"], source, env=env)
            staged_public(source)
            hashes = file_hashes(source / "_site")
            require(first is None or hashes == first, "production regeneration differs")
            first = hashes
            if label == "first":
                # Must not survive deterministic regeneration; not committed input.
                (source / "qualification-public/stale.ads").write_text("stale")
        report["production_sha256"] = first
        native(session, source, args.gnatdoc_prefix / "bin/gnatdoc",
               args.workspace / "native", args.workspace / "native.log")
        session.run(["alr", "-n", "build"], core)
        native(session, core, args.gnatdoc_prefix / "bin/gnatdoc",
               args.workspace / "core-native", args.workspace / "core-native.log")
        result = validate_migration_site(source, args.workspace / "native", source / "_site",
                                         core, args.workspace / "core-native")
        write(args.workspace / "independent-validation.json", result)
        write(args.workspace / "referenced-types.json", json.loads(regular(
            ROOT / "docs/evidence/geometry-gnatdoc-003r1/referenced-types.json")))
        write(args.workspace / "occurrences.json", [
            {"identity": row["referenced_type"], "href": row["shared"]["href"],
             "package": row["package"], "native_page": row["native_page"],
             "native_anchor": row["native_anchor"]}
            for row in result["comparison"]["type_references"]])
        report["publisher"] = result["publisher"]
        report["comparison"] = {k: v for k, v in result["comparison"].items()
                                if k not in ("type_references", "navigation")}
        report["coverage"] = coverage(source, source / "_site", source / "obj/docs/gnatdoc.log")
        require(file_hashes(source / "_site") == first, "validation mutated site")
        for project, folder, mains in (("docs/example.gpr", "docs-example", ("example",)),
                                      ("docs/examples/examples.gpr", "docs-examples", EXAMPLES)):
            session.run(["alr", "exec", "--", "gprbuild", "-P", project], source)
            for main in mains:
                session.run([source / "obj" / folder / main], source)
        report["examples"] = 6
        output = session.run(["alr", "-n", "run"], source / "tests")
        report["aunit"] = aunit_results(source, output)
        exact_snapshot(source, source, report["candidate"], pins=True)
        session.run([sys.executable, "-m", "unittest", "-v", "test_migration_preview"], ROOT,
                    env={"PYTHONPATH": str(ROOT / "scripts"),
                         "GEOMETRY_MIGRATION_PREVIEW": str(args.workspace)})
        if args.playwright_module:
            browser_env = {"PLAYWRIGHT_MODULE": str(args.playwright_module),
                           "CORE_LINK_WORKSPACE": str(args.workspace)}
            session.run(["node", ROOT / "scripts/test_native_core_links_browser.cjs"], ROOT,
                        env=browser_env)
            report["native_browser"] = json.loads(regular(args.workspace / "focused-browser.json"))
            server = ThreadingHTTPServer(("127.0.0.1", 0), partial(
                SimpleHTTPRequestHandler, directory=str(source / "_site")))
            threading.Thread(target=server.serve_forever, daemon=True).start()
            try:
                session.run(["node", ROOT / "scripts/test_gnatdoc_guides_browser.cjs"], ROOT,
                            env={**browser_env, "CHROME": "/usr/bin/google-chrome",
                                 "DOC_URL": f"http://127.0.0.1:{server.server_port}/",
                                 "DOC_EVIDENCE": str(args.workspace / "authored-browser")})
            finally:
                server.shutdown()
                server.server_close()
            report["authored_browser_cells"] = 8
        report["status"] = "pass"
        report["disposition"] = "PRODUCTION_PREVIEW_ONLY_NOT_BOOTSTRAP_APPROVAL"
    except Exception as error:
        report["failure"] = {"type": type(error).__name__, "reason": str(error)}
        raise
    finally:
        write(args.workspace / "preview.json", report)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "core", "gnatdoc-prefix", "wheel"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--policy-revision", required=True)
    parser.add_argument("--playwright-module", type=Path,
                        help="existing Playwright 1.64.1 module; requires /usr/bin/google-chrome")
    run(parser.parse_args())