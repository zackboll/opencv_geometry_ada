#!/usr/bin/env python3
"""Reexecute all unchanged original Chromium suites with a separately built router."""
import argparse
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
import threading

from qualify_shared_gnatdoc_browser import QuietHandler
from qualify_shared_gnatdoc_shadow import (
    Session, file_hashes, git, read, regular, require, sha, write,
)

ROUTER = "ccc2190f9bf0712d65a2b9d2983cde7ce68b4bae"


def qualify(workspace, repository, prefix, playwright_module, chromium):
    q = read(workspace / "qualification.json")
    require(file_hashes(workspace / "first/_site") == q["shadow_sha256"], "shadow changed before original browser")
    report = {"status": "fail", "run_id": q["run_id"], "consumer_tested": q["consumer_tested"],
              "qualification_sha256": sha(regular(workspace / "qualification.json")),
              "tested_shadow_sha256": q["shadow_sha256"], "suites": {}, "router_fixture": ROUTER}
    logs = workspace / "original-browser-logs"
    logs.mkdir()
    session = Session(logs)
    router = workspace / "core-router"
    session.clone(repository, ROUTER, router)
    session.run(["sh", "scripts/generate_docs.sh"], router,
                env={"GNATDOC_PREFIX": str(prefix)})
    require(git(router, "rev-parse", "HEAD").decode().strip() == ROUTER, "wrong separate router fixture")
    legacy = workspace / "legacy"
    servers = [ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(site)))
               for site in (legacy / "_site", router / "_site")]
    for server in servers:
        threading.Thread(target=server.serve_forever, daemon=True).start()
    evidence = workspace / "original-chromium"
    env = {"DOC_URL": f"http://127.0.0.1:{servers[0].server_port}/",
           "CORE_DOC_URL": f"http://127.0.0.1:{servers[1].server_port}/",
           "DOC_EVIDENCE": str(evidence), "DOC_TRACE": "1",
           "PLAYWRIGHT_MODULE": str(playwright_module), "CHROME": str(chromium)}
    original = file_hashes(legacy / "_site")
    try:
        for name, script in (("core_symbol_router", "test_core_type_links_browser.cjs"),
                             ("presentation", "test_gnatdoc_presentation_browser.cjs"),
                             ("navigation", "test_gnatdoc_navigation_browser.cjs"),
                             ("guides", "test_gnatdoc_guides_browser.cjs")):
            session.run(["node", "scripts/" + script], legacy, env=env)
            report["suites"][name] = {"status": "pass", "script_sha256": sha(regular(legacy / "scripts" / script))}
        require(file_hashes(legacy / "_site") == original == q["legacy_sha256"], "original browser site changed")
        report.update({"status": "pass", "tested_legacy_sha256": original,
                       "router_site_sha256": file_hashes(router / "_site")})
    except Exception as exc:
        report["failure"] = str(exc)
        raise
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        write(workspace / "original-browser.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "core-repository", "gnatdoc-prefix", "playwright-module", "chromium"):
        parser.add_argument("--" + name, type=lambda p: Path(p).absolute(), required=True)
    args = parser.parse_args()
    qualify(args.workspace, args.core_repository, args.gnatdoc_prefix, args.playwright_module, args.chromium)