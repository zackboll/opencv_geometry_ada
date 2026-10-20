#!/usr/bin/env python3
"""Real Chromium Geometry shadow matrix; offline Core is not hosted Core proof."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import mimetypes
import os
from pathlib import Path
import threading
from urllib.parse import urlencode, urljoin, urlsplit

from qualify_shared_gnatdoc_shadow import (
    CORE, EVIDENCE, read, require, sha, regular, write, file_hashes, check_files,
)
from compare_shared_gnatdoc_geometry import compare
from investigate_shared_gnatdoc_types import sections


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


def qualify(workspace, executable=None):
    from playwright.sync_api import sync_playwright
    q = read(workspace / "qualification.json")
    comparison = compare(workspace)
    site = workspace / "first/_site"
    before = file_hashes(site)
    require(before == q["shadow_sha256"], "browser site differs from current qualification")
    spec = read(workspace / "first" / EVIDENCE / "core-0.5.0-input.json")
    core_site = workspace / "core-native"
    require(file_hashes(core_site) == spec["pristine_sha256"], "browser Core artifact differs")
    native = sections(workspace / "pristine-first")
    core_native = sections(core_site)
    oracle = read(workspace / "navigation-oracle.json")
    selections = [(package, category, item) for package, _, groups in oracle
                  for category, _, items in groups for item in items]
    allowed = {r["shared"]["href"].split("#")[0] for r in read(workspace / "type-link-occurrences.json")
               if not r["referenced_type"].startswith("opencv.geometry.")}
    approved_prefix = f"https://core.invalid/{CORE}/api/"
    allowed.add(approved_prefix + "gnatdoc.css")
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(site)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_port}/"
    report = {"status": "fail", "run_id": q["run_id"], "consumer_tested": q["consumer_tested"],
              "qualification_sha256": sha(regular(workspace / "qualification.json")),
              "tested_shadow_sha256": before, "core_native_sha256": spec["pristine_sha256"],
              "assertions": [], "history_traces": [], "production_https_verified": False}

    def check(condition, name, **details):
        require(condition, name)
        report["assertions"].append({"name": name, **details})

    def declaration(frame, package, item):
        dest = urlsplit(item["href"])
        h = frame.locator('h4[id="' + dest.fragment + '"]')
        h.wait_for(state="attached")
        check(h.count() == 1 and h.inner_text() == item["name"], "exact native fragment/label",
              package=package, href=item["href"])
        check(frame.locator("h1").inner_text() == package, "independent public package owner")
        expected = native[package, dest.fragment][2].text
        actual = h.locator("xpath=following-sibling::pre[1]").inner_text()
        check(" ".join(actual.split()) == " ".join(expected.split()), "complete source/native profile",
              profile=item["profile"], href=item["href"])

    def restored_frame(page, shell, item):
        # Successor-reviewed synchronization only: preserve every historical
        # assertion while waiting for actual state rather than a superseded
        # navigation event. No exception is swallowed or retried.
        page.wait_for_function("""expected => {
            const frame = document.querySelector('iframe[name="document-content"]');
            try {
                return frame.contentWindow.location.href === expected &&
                       frame.contentDocument.readyState === 'complete';
            } catch (_) { return false; }
        }""", arg=urljoin(shell, item["href"]))
        return page.frame(name="document-content")

    def intercept(route):
        url = route.request.url.split("#")[0]
        require(url in allowed, f"unapproved offline Core request: {url}")
        name = "api/" + url.removeprefix(approved_prefix)
        payload = regular(core_site / name)
        require(sha(payload) == spec["pristine_sha256"][name], "intercepted Core bytes differ")
        route.fulfill(status=200, body=payload,
                      content_type=mimetypes.guess_type(name)[0] or "application/octet-stream")

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=executable, headless=True)
            report["chromium"] = browser.version
            for width in (1280, 390):
                for theme in ("light", "dark"):
                    for javascript in (True, False):
                        dimensions = {"width": width, "theme": theme, "javascript": javascript}
                        context = browser.new_context(viewport={"width": width, "height": 900},
                                                      color_scheme=theme, java_script_enabled=javascript)
                        context.tracing.start(screenshots=True, snapshots=True, sources=True)
                        context.route("https://core.invalid/**", intercept)
                        context.route("**/favicon.ico", lambda r: r.fulfill(status=204))
                        page = context.new_page()
                        errors = []
                        page.on("pageerror", lambda error: errors.append(str(error)))
                        page.on("console", lambda message: errors.append(message.text)
                                if message.type == "error" else None)
                        shell = base + "api/index.html"
                        page.goto(shell)
                        if javascript:
                            page.locator('#package-navigation[data-ready="true"]').wait_for(state="visible")
                        check(page.locator(".operation-group").count() == 12, "all public categories", **dimensions)
                        check(page.locator('.operation-group a').count() == 130, "all navigation entries", **dimensions)
                        # Exercise every entry, including every source-order overload, in every matrix cell.
                        for package, category, item in selections:
                            link = page.locator('.operation-group[data-category="' + category + '"] a[href="' + item["href"] + '"]')
                            label = item["name"] + (f' ({item["overload"]})' if item["overload"] else "")
                            check(link.inner_text() == label, "source-order overload label", **dimensions)
                            link.focus()
                            page.keyboard.press("Enter")
                            frame = page.frame(name="document-content")
                            frame.wait_for_url(urljoin(shell, item["href"]))
                            declaration(frame, package, item)
                        if javascript:
                            search = page.locator("#package-search")
                            search.fill("voronoi_facets")
                            check(page.locator('.operation-group a:visible').count() == 2 and
                                  page.locator('.operation-group a:visible').all_inner_texts() ==
                                  ["Voronoi_Facets (1)", "Voronoi_Facets (2)"],
                                  "search correct cross-package operation", **dimensions)
                            page.locator("#package-clear").click()
                            check(search.input_value() == "" and search.evaluate("e=>e===document.activeElement"),
                                  "reset restores keyboard focus", **dimensions)
                            # Two within-package overloads, then an independent package.
                            sequence = [x for x in selections if x[2]["name"] == "Contour_Area"][:2]
                            sequence += [x for x in selections if x[2]["name"] == "Insert"][:1]
                            for package, _, item in sequence:
                                page.locator('.operation-group a[href="' + item["href"] + '"]').click()
                                declaration(restored_frame(page, shell, item), package, item)
                            for action, index in (("back", 1), ("back", 0), ("forward", 1), ("forward", 2)):
                                page.evaluate("history." + action + "()")
                                package, _, item = sequence[index]
                                expected = shell + "?" + urlencode({"package": package,
                                            "declaration": urlsplit(item["href"]).fragment})
                                page.wait_for_url(expected)
                                frame = restored_frame(page, shell, item)
                                declaration(frame, package, item)
                                report["history_traces"].append({"action": action, "package": package,
                                                               "href": item["href"], **dimensions})
                            page.reload()
                            declaration(page.frame(name="document-content"), sequence[-1][0], sequence[-1][2])
                        # Direct declaration bookmark and reload for each package.
                        for package in ("OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"):
                            item = next(i for p, _, i in selections if p == package)
                            page.goto(urljoin(shell, item["href"]))
                            declaration(page, package, item)
                            page.reload()
                            declaration(page, package, item)
                            check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"),
                                  "native responsive overflow", **dimensions)
                        # Follow one actual local link from each package; compare full target profile.
                        rows = read(workspace / "type-link-occurrences.json")
                        for package in ("OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"):
                            row = next(r for r in rows if r["package"] == package and
                                       r["referenced_type"].startswith("opencv.geometry."))
                            page.goto(base + "api/" + row["native_page"] + "#" + row["native_anchor"])
                            h = page.locator('h4[id="' + row["native_anchor"] + '"]')
                            link = h.locator("xpath=following-sibling::pre[1]").locator(
                                'a[data-type="' + row["referenced_type"] + '" i]').first
                            link.click()
                            owner = row["actual_native_declaration_owner"]
                            page.wait_for_url(base + "api/" + owner["page"] + "#" + owner["anchor"])
                            check(page.locator('h4[id="' + owner["anchor"] + '"]').count() == 1,
                                  "actual local type hyperlink navigation", **dimensions)
                        # Every approved external identity, served exclusively from verified native artifact.
                        external = {r["referenced_type"]: r for r in rows
                                    if not r["referenced_type"].startswith("opencv.geometry.")}
                        external["opencv.point_array"] = comparison["contour"]
                        for identity, row in external.items():
                            origin = base + "api/" + row["native_page"] + "#" + row["native_anchor"]
                            page.goto(origin)
                            h = page.locator('h4[id="' + row["native_anchor"] + '"]')
                            links = h.locator("xpath=following-sibling::pre[1]").locator(
                                'a[data-type="' + identity + '" i]')
                            if identity == "opencv.point_array":
                                check(links.count() == 1 and h.locator("xpath=following-sibling::pre[1]").inner_text().strip()
                                      == "subtype Contour is OpenCV.Point_Array;", "Contour exactly one source-verified base hyperlink",
                                      **dimensions)
                            check(links.first.get_attribute("href") == row["shared"]["href"],
                                  "qualified external identity and native destination", identity=identity, **dimensions)
                            links.first.click()
                            page.wait_for_url(row["shared"]["href"])
                            owner = row["actual_native_declaration_owner"]
                            target = page.locator('h4[id="' + owner["anchor"] + '"]')
                            target.wait_for(state="attached")
                            expected = core_native[owner["package"], owner["anchor"]][2].text
                            check(" ".join(target.locator("xpath=following-sibling::pre[1]").inner_text().split()) ==
                                  " ".join(expected.split()), "genuine Core native rendered profile", identity=identity, **dimensions)
                            page.reload()
                            target.wait_for(state="attached")
                            page.go_back()
                            page.wait_for_url(origin)
                            page.go_forward()
                            page.wait_for_url(row["shared"]["href"])
                        authored = read(workspace / "first" / EVIDENCE / "geometry-authored.json")
                        for name in ("index.html", *(g["path"] for g in authored["guides"])):
                            page.goto(base + name)
                            check(page.locator("h1").count() == 1, "authored heading", path=name, **dimensions)
                            check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"),
                                  "authored responsive overflow", path=name, **dimensions)
                            if name != "index.html":
                                check(page.locator('.guide-nav [aria-current="page"]').get_attribute("href") ==
                                      name.split("/")[-1], "authored guide navigation ownership", **dimensions)
                                api_links = page.locator('main a[href^="../api/"]').evaluate_all(
                                    "es=>es.map(e=>({href:e.getAttribute('href'),label:e.textContent}))")
                                check(len(api_links) >= 5, "authored genuine API links present", path=name, **dimensions)
                                for link in api_links:
                                    destination = urlsplit(link["href"])
                                    if destination.path == "../api/index.html" and not destination.fragment:
                                        check(True, "guide API browser navigation", path=name, **dimensions)
                                        continue
                                    owners = [(p, n, snippet) for (p, a), (filename, n, snippet) in native.items()
                                              if filename == Path(destination.path).name and a == destination.fragment]
                                    check(len(owners) == 1, "guide link uniquely owned native declaration",
                                          path=name, href=link["href"], **dimensions)
                                    page.goto(urljoin(base + name, link["href"]))
                                    owner_package, owner_name, snippet = owners[0]
                                    h = page.locator('h4[id="' + destination.fragment + '"]')
                                    check(h.inner_text() == owner_name and page.locator("h1").inner_text() == owner_package and
                                          " ".join(h.locator("xpath=following-sibling::pre[1]").inner_text().split()) ==
                                          " ".join(snippet.text.split()), "guide API link actual owner/profile", **dimensions)
                        check(not errors, "no unexpected JavaScript/console errors", errors=errors, **dimensions)
                        context.tracing.stop(path=str(workspace / f"chromium-{width}-{theme}-{javascript}.zip"))
                        context.close()
            browser.close()
        require(file_hashes(site) == before, "browser changed site bytes")
        report.update({"status": "pass", "executed": len(report["assertions"]), "matrix_cells": 8})
    except Exception as exc:
        report["failure"] = str(exc)
        raise
    finally:
        server.shutdown()
        server.server_close()
        write(workspace / "browser.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=lambda p: Path(p).absolute(), required=True)
    parser.add_argument("--chromium", default=os.environ.get("CHROME"))
    args = parser.parse_args()
    qualify(args.workspace, args.chromium)