#!/usr/bin/env python3
"""Current-source eight-cell browser qualification, using independent inventory."""
import argparse
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
import threading
from urllib.parse import urlencode, urljoin, urlsplit

from additive_gnatdoc_policy import (
    ROOT, EVIDENCE, current_output, read, regular, require, file_hashes, sha, write,
)
from investigate_shared_gnatdoc_types import sections
from qualify_shared_gnatdoc_browser import QuietHandler


def qualify(workspace, executable):
    from playwright.sync_api import sync_playwright
    q = read(workspace / "qualification.json")
    require(q["status"] == "pass", "component qualification failed")
    source, site = workspace / "source", workspace / "first/_site"
    core = read(ROOT / EVIDENCE / "core-0.5.0-types.json")
    comparison = current_output(source, workspace / "pristine-first", site, core)
    native = sections(workspace / "pristine-first")
    selections = [(package, group, item) for package, _, groups in comparison["navigation"]
                  for group, _, items in groups for item in items]
    before = file_hashes(site)
    require(before == q["shadow_sha256"], "browser input changed")
    spec = read(ROOT / EVIDENCE / "core-0.5.0-input.json")
    require(file_hashes(workspace / "core-native") == spec["pristine_sha256"],
            "offline Core native changed")
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(site)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_port}/"
    shell = base + "api/index.html"
    report = {"status": "fail", "candidate": q["candidate"], "run_id": q["run_id"],
              "qualification_sha256": sha(regular(workspace / "qualification.json")),
              "site_sha256": before, "cells": [], "history": [], "assertions": 0}

    def check(value, message):
        require(value, message)
        report["assertions"] += 1

    def declaration(frame, package, item):
        anchor = urlsplit(item["href"]).fragment
        heading = frame.locator('h4[id="' + anchor + '"]')
        heading.wait_for(state="attached")
        check(heading.count() == 1 and heading.inner_text() == item["name"],
              "wrong-but-existing native anchor/label")
        check(frame.locator("h1").inner_text() == package, "native package ownership")
        check(" ".join(heading.locator("xpath=following-sibling::pre[1]").inner_text().split()) ==
              " ".join(native[package, anchor][2].text.split()), "complete native profile")

    def restored_frame(page, item):
        # History restoration uses location.replace and can supersede an
        # in-flight iframe load. Wait for the actual destination/document, not
        # Playwright's next navigation event (which can be the aborted old one).
        # No error is swallowed and all owner/anchor/profile checks still run.
        destination = urljoin(shell, item["href"])
        page.wait_for_function("""expected => {
            const frame = document.querySelector('iframe[name="document-content"]');
            try {
                return frame.contentWindow.location.href === expected &&
                       frame.contentDocument.readyState === 'complete';
            } catch (_) { return false; }
        }""", arg=destination)
        return page.frame(name="document-content")

    prefix = f'https://core.invalid/{core["revision"]}/api/'
    allowed = {r["shared"]["href"].split("#")[0] for r in comparison["type_references"]
               if not r["referenced_type"].startswith("opencv.geometry.")}
    allowed.add(prefix + "gnatdoc.css")

    def intercept(route):
        url = route.request.url.split("#")[0]
        require(url in allowed, "unapproved offline Core browser request")
        path = workspace / "core-native/api" / url.removeprefix(prefix)
        route.fulfill(status=200, body=regular(path),
                      content_type="text/css" if path.suffix == ".css" else "text/html")

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=executable, headless=True)
            report["chromium"] = browser.version
            for width in (1280, 390):
                for theme in ("light", "dark"):
                    for javascript in (True, False):
                        cell = {"width": width, "theme": theme, "javascript": javascript,
                                "visited": []}
                        context = browser.new_context(viewport={"width": width, "height": 900},
                                                      color_scheme=theme, java_script_enabled=javascript)
                        context.tracing.start(screenshots=True, snapshots=True, sources=True)
                        context.route("https://core.invalid/**", intercept)
                        context.route("**/favicon.ico", lambda route: route.fulfill(status=204))
                        page = context.new_page()
                        errors = []
                        page.on("pageerror", lambda error: errors.append(str(error)))
                        page.goto(shell)
                        if javascript:
                            page.locator('#package-navigation[data-ready="true"]').wait_for()
                        links = page.locator(".operation-group a")
                        check(links.count() == len(selections), "derived navigation total")
                        check(page.locator(".operation-group").count() ==
                              sum(len(groups) for _, _, groups in comparison["navigation"]),
                              "category inventory")
                        for package, group, item in selections:
                            link = page.locator('.operation-group a[href="' + item["href"] + '"]')
                            check(link.count() == 1, "unique current navigation entry")
                            label = item["name"] + (f' ({item["overload"]})' if item["overload"] else "")
                            check(link.inner_text() == label, "source-order overload identity")
                            link.focus()
                            page.keyboard.press("Enter")
                            frame = page.frame(name="document-content")
                            frame.wait_for_url(urljoin(shell, item["href"]))
                            declaration(frame, package, item)
                            cell["visited"].append([package, item["profile"], item["href"]])
                        if javascript:
                            search = page.locator("#package-search")
                            search.fill("voronoi_facets")
                            expected = [i for p, _, i in selections if i["name"] == "Voronoi_Facets"]
                            check(page.locator(".operation-group a:visible").count() == len(expected),
                                  "source-derived search results")
                            page.locator("#package-clear").click()
                            check(search.input_value() == "" and links.count() == len(selections),
                                  "reset restores derived inventory")
                            sequence = [(p, i) for p, _, i in selections if i["name"] == "Contour_Area"][:2]
                            sequence += [(p, i) for p, _, i in selections if i["name"] == "Insert"][:1]
                            for package, item in sequence:
                                page.locator('.operation-group a[href="' + item["href"] + '"]').click()
                                declaration(restored_frame(page, item), package, item)
                            for action, index in (("back", 1), ("back", 0), ("forward", 1), ("forward", 2)):
                                page.evaluate("history." + action + "()")
                                package, item = sequence[index]
                                page.wait_for_url(shell + "?" + urlencode({"package": package,
                                                   "declaration": urlsplit(item["href"]).fragment}))
                                frame = restored_frame(page, item)
                                declaration(frame, package, item)
                                report["history"].append({**cell, "visited": [], "action": action,
                                                          "href": item["href"]})
                            page.reload()
                            declaration(page.frame(name="document-content"), *sequence[-1])
                        for package in ("OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"):
                            item = next(i for p, _, i in selections if p == package)
                            page.goto(urljoin(shell, item["href"]))
                            declaration(page, package, item)
                            page.reload()
                            declaration(page, package, item)
                            check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"),
                                  "native responsive layout")
                        for external in (False, True):
                            row = next(r for r in comparison["type_references"]
                                       if (not r["referenced_type"].startswith("opencv.geometry.")) == external)
                            page.goto(base + "api/" + row["native_page"] + "#" + row["native_anchor"])
                            link = page.locator('h4[id="' + row["native_anchor"] + '"] + pre a[data-type="' +
                                                row["referenced_type"] + '"]').first
                            check(link.get_attribute("href") == row["shared"]["href"], "source-backed type href")
                            link.click()
                            destination = row["actual_native_declaration_owner"]
                            page.wait_for_url(urljoin(base + "api/", row["shared"]["href"]))
                            check(page.locator('h4[id="' + destination["anchor"] + '"]').count() == 1,
                                  "type actual native destination")
                        authored = read(workspace / "first/current-authored.json")
                        for guide in authored["guides"]:
                            page.goto(base + guide["path"])
                            check(page.locator("h1").count() == 1, "authored heading")
                            for href in page.locator('main a[href^="../api/"]').evaluate_all(
                                    "es => es.map(e => e.getAttribute('href'))"):
                                destination = urlsplit(href)
                                if not destination.fragment:
                                    continue
                                owners = [(p, a, name) for (p, a), (filename, name, _) in native.items()
                                          if filename == Path(destination.path).name and a == destination.fragment]
                                check(len(owners) == 1, "guide current native anchor")
                            check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"),
                                  "guide responsive layout")
                        check(not errors, "browser JavaScript errors")
                        report["cells"].append(cell)
                        context.tracing.stop(path=str(workspace / f"current-{width}-{theme}-{javascript}.zip"))
                        context.close()
            browser.close()
        require(file_hashes(site) == before, "browser changed documentation")
        report["status"] = "pass"
    except Exception as error:
        report["failure"] = str(error)
        raise
    finally:
        server.shutdown()
        server.server_close()
        write(workspace / "browser.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--chromium", required=True)
    args = parser.parse_args()
    qualify(args.workspace, args.chromium)