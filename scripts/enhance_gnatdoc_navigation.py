#!/usr/bin/env python3
"""Package- and operation-level API browser for the Geometry reference.

Core's browser searches 195 packages and Imgproc's the 314 declarations of
one package. Geometry publishes two packages, `OpenCV.Geometry` and
`OpenCV.Geometry.Subdiv2D`, so the browser groups every declaration by
package and then by category. Only the native GNATdoc 26.0.0 index changes,
and only by:

- one hidden search control group, revealed by the script;
- a static list, per package, of every visible-part declaration, grouped in
  collapsible categories, each entry a link to its verified native anchor in
  the documentation frame, so navigation works without JavaScript;
- one deferred repository-owned script (search, selection, bookmarks).

Entries derive from the public specifications (names, kinds, profiles and
overload order), the reviewed category manifest `docs/api-categories.json`
(every public declaration name of each package in exactly one category of
that package, no unknown names) and anchors discovered from source-matched
native sections. No filename or anchor is computed. The native index must
match the pinned serialization before it is augmented; repeat enhancement is
byte-idempotent.
"""

import argparse
import html
import json
import re
import sys
from collections import Counter
from pathlib import Path

from link_gnatdoc_types import SECTION, Sources, plain, require

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "docs/assets/gnatdoc-navigation.js"
CATEGORIES = ROOT / "docs/api-categories.json"
SCRIPT = '<script src="gnatdoc-navigation.js" defer></script>'
CONTROL = (
    '<div id=api-search-controls hidden><label for=api-search>Search packages, '
    'operations and types</label><input id=api-search type=search '
    'autocomplete=off spellcheck=false aria-describedby=api-results><button '
    'id=api-clear type=button>Clear</button><p id=api-results role=status '
    'aria-live=polite></p></div>')
INDEX_START = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=main><div class=side-navigation><ul class=tab-bar>"
    "<li class=tab><a href=#compilation-units>Compilation Units</a>"
    "<li class=tab><a href=#tagged-types>Tagged Types</a></ul>"
    "<div class=content-column><h2 id=compilation-units>Compilation Units</h2><ul>")
INDEX_END = (
    "</ul><h2 id=tagged-types>Tagged types</h2><ul></ul></div></div>"
    "<div class=document-content><iframe name=document-content></iframe></div>")


def load_categories(path=CATEGORIES):
    """Return [(package, [category])] and {(package, name): category id}."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    require(data.get("version") == 1, "unexpected category manifest version")
    packages = data.get("packages")
    require(isinstance(packages, list) and packages, "empty category manifest")
    owner, identities, result = {}, set(), []
    for package in packages:
        name = package.get("package", "")
        require(re.fullmatch(r"OpenCV(?:\.[A-Z][A-Za-z0-9_]*)+", name),
                "invalid package name in category manifest")
        require(name not in [item[0] for item in result],
                f"package listed twice: {name}")
        categories = package.get("categories")
        require(isinstance(categories, list) and categories,
                f"package without categories: {name}")
        for category in categories:
            identity = category.get("id", "")
            require(re.fullmatch(r"[a-z][a-z-]*", identity), "invalid category id")
            require(identity not in identities, f"duplicate category id: {identity}")
            identities.add(identity)
            require(category.get("title") and category.get("declarations"),
                    f"incomplete category: {identity}")
            for declaration in category["declarations"]:
                require((name, declaration) not in owner,
                        f"declaration in two categories: {name}.{declaration}")
                owner[(name, declaration)] = identity
        result.append((name, categories))
    return result, owner


def _package_pages(api):
    pages = {}
    for path in sorted(Path(api).glob("*.html")):
        if path.name == "index.html":
            continue
        require(re.fullmatch(r"[0-9a-f]{64}\.html", path.name),
                "unsupported native package page set")
        headings = re.findall(r"<h1>([^<]+)</h1>", path.read_text(encoding="utf-8"))
        require(len(headings) == 1, f"noncanonical native package heading: {path.name}")
        require(headings[0] not in pages, f"duplicate package page: {headings[0]}")
        pages[headings[0]] = path
    return pages


def entries(api, source_root=ROOT / "src", categories_path=CATEGORIES):
    """Return [(package, page name, [(category id, title, entries)])]."""
    from highlight_gnatdoc_ada import strip_highlighting
    sources = Sources(Path(source_root))
    manifest, owner = load_categories(categories_path)
    pages = _package_pages(api)
    canonical = {package.lower(): package for package in pages}
    require(set(canonical) == set(sources.packages),
            "public source/page coverage mismatch")
    require([package for package, _ in manifest] == sorted(pages, key=str.lower),
            "category manifest packages do not match the public packages")
    names = {(canonical[identity], d["name"])
             for identity, package in sources.packages.items() for d in package.top}
    require(set(owner) == names,
            "category manifest does not match the public declarations: missing "
            f"{sorted(names - set(owner))}, unknown {sorted(set(owner) - names)}")
    result = []
    for package_name, categories in manifest:
        source = sources.packages[package_name.lower()]
        page = pages[package_name]
        text = page.read_text(encoding="utf-8")
        anchors = {}
        for section in SECTION.finditer(text):
            declaration = source.match(plain(strip_highlighting(section[3])))
            require(section[2] == declaration["name"], "section heading/source mismatch")
            key = (declaration["start"], declaration["name"])
            require(key not in anchors, "duplicate native section")
            anchors[key] = section[1]
        require(len(anchors) == len(source.top), "native section coverage mismatch")
        totals = Counter(d["name"] for d in source.top)
        seen = Counter()
        grouped = {category["id"]: [] for category in categories}
        titles = {category["id"]: category["title"] for category in categories}
        for declaration in source.top:
            name = declaration["name"]
            seen[name] += 1
            kind = declaration["signature"].split()[0]
            kind = kind if kind in ("function", "procedure", "type", "subtype") \
                else "constant"
            profile = " ".join(declaration["signature"].split()).replace(" : =", " :=")
            category = owner[(package_name, name)]
            grouped[category].append({
                "package": package_name, "name": name, "kind": kind,
                "profile": profile.rstrip(";"),
                "overload": seen[name] if totals[name] > 1 else 0,
                "overloads": totals[name],
                "href": f"{page.name}#{anchors[(declaration['start'], name)]}",
                "category": titles[category],
            })
        for category in categories:
            grouped[category["id"]].sort(key=lambda e: (e["name"].lower(), e["overload"]))
        result.append((package_name, page.name,
                       [(c["id"], c["title"], grouped[c["id"]]) for c in categories]))
    return result


def _entry(item):
    detail = item["kind"]
    if item["overload"]:
        detail += f", overload {item['overload']} of {item['overloads']}"
    search = " ".join([item["package"], item["name"], item["kind"], item["category"],
                       item["profile"]]).lower()
    attributes = f' data-package="{item["package"]}" data-op="{item["name"]}"'
    if item["overload"]:
        attributes += f' data-overload="{item["overload"]}"'
    return (f'<li{attributes} data-search="{html.escape(search)}">'
            f'<a href={item["href"]} target=document-content '
            f'title="{html.escape(item["profile"])}">{item["name"]}'
            f'<span class=entry-detail> {detail}</span></a>')


def browser(packages):
    parts = ['<nav id=api-browser aria-labelledby=api-browser-heading>',
             CONTROL, '<h2 id=api-browser-heading>Public API</h2>']
    for package, page, groups in packages:
        parts.append(f'<section class=api-package data-package="{package}">'
                     f'<h3><a href={page} target=document-content>{package}</a>'
                     '</h3>')
        for identity, title, items in groups:
            parts.append(f'<details class=api-category data-category={identity}>'
                         f'<summary>{html.escape(title)} <span class=api-count>'
                         f'({len(items)})</span></summary><ul>')
            parts.extend(_entry(item) for item in items)
            parts.append('</ul></details>')
        parts.append('</section>')
    parts.append('</nav>')
    return "".join(parts)


def native_index(api):
    packages = entries(api)
    units = "".join(f"<li><a href={page} target=document-content>{package}</a>"
                    for package, page, _ in packages)
    return INDEX_START + units + INDEX_END, packages


def augmented(text, api):
    """The approved navigation index for a native (themed) index text."""
    _, packages = native_index(api)
    marker = "<h2 id=compilation-units>"
    require(text.count(marker) == 1 and text.count("<body class=main>") == 1,
            "unsupported native index structure")
    return (text.replace(marker, browser(packages) + marker, 1)
                .replace("<body class=main>", SCRIPT + "<body class=main>", 1))


def check_navigation(api):
    from install_gnatdoc_theme import themed
    native, packages = native_index(api)
    require((api / "index.html").read_text(encoding="utf-8") ==
            augmented(themed(native), api),
            "unapproved navigation shell, links, controls or scripts")
    require((api / "gnatdoc-navigation.js").read_bytes() == ASSET.read_bytes(),
            "navigation asset differs from repository script")
    return sum(len(items) for _, _, groups in packages for _, _, items in groups)


def enhance(api):
    from install_gnatdoc_theme import themed
    api = Path(api).resolve()
    native, packages = native_index(api)
    path = api / "index.html"
    current = path.read_text(encoding="utf-8")
    expected = augmented(themed(native), api)
    if current != expected:
        require(current == themed(native), "unsupported native index structure")
        path.write_text(expected, encoding="utf-8")
        (api / "gnatdoc-navigation.js").write_bytes(ASSET.read_bytes())
    count = check_navigation(api)
    print(f"Navigation: {count} declarations of {len(packages)} packages in "
          "browsable categories; native anchors verified")
    return count


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("api", type=Path)
    args = parser.parse_args(argv)
    from link_gnatdoc_types import CrossReferenceError
    try:
        enhance(args.api)
    except (CrossReferenceError, OSError, ValueError) as error:
        print(f"error: navigation: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
