#!/usr/bin/env python3
"""Reproduce GNATDOC-009's independent type-link gate; never deploy a site.

This diagnostic stops on lost source-backed references. Historical authorities
come from the exact merged enhancer commit, not newly observed input hashes.
It is not the complete shadow qualification or a production migration runner.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
from html.parser import HTMLParser
import importlib.metadata
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlsplit

BASE = "8690927853ffa74729206d8997b09046ad3d2246"
ENHANCER = "53a321915da2c5a02a54581040673b61f8595b25"
CORE = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
AUTHORITIES = {
    "docs/evidence/gnatdoc005/core-0.5.0-input.json":
        "4abd944e932116582efee29adb3eec767da762f67436cba5dddd82377fadcbbb",
    "docs/evidence/gnatdoc005/core-0.5.0-types.json":
        "70fa9a9e5de8ad038bf0bc4bdf6c76ec8ecbe5f201027d18554275f7d9ed7f7f",
    "docs/evidence/gnatdoc007/geometry-authored.json":
        "62a5cacfb86ece2017045e6354d6a9ce47b3d9706dd16873c2437b854dcb59ea",
}
PUBLIC = ("src/opencv-geometry.ads", "src/opencv-geometry-subdiv2d.ads")
SECTION = re.compile(
    r"<h4 id=([^ >]+)>([^<]+)</h4>"
    r"<pre class=ada-code-snippet><code>(.*?)</code></pre>", re.S)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def regular(path):
    require(not any(p.is_symlink() for p in (path, *path.parents)),
            f"unsafe symlink: {path}")
    require(path.is_file(), f"missing file: {path}")
    return path.read_bytes()


def write(path, data):
    path.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


class Snippet(HTMLParser):
    """Independent occurrence offsets in decoded native declaration text."""

    def __init__(self, raw):
        super().__init__(convert_charrefs=True)
        self.text = ""
        self.links = []
        self.active = None
        self.feed(raw)
        self.close()
        require(self.active is None, "unclosed type reference")

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a":
            require(self.active is None, "nested type references")
            require(attrs.get("class") == "type-reference", "unknown link")
            self.active = {"offset": len(self.text), "href": attrs["href"],
                           "identity": attrs["data-type"].lower(),
                           "target": attrs.get("target")}
        else:
            require(tag == "span", f"unknown snippet markup: {tag}")

    def handle_endtag(self, tag):
        if tag == "a":
            require(self.active is not None, "unmatched reference")
            self.active["end"] = len(self.text)
            self.active["spelling"] = self.text[self.active["offset"]:]
            self.links.append(self.active)
            self.active = None

    def handle_data(self, data):
        self.text += data


class Navigation(HTMLParser):
    """Read published labels directly, without the shared destination resolver."""

    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.category = None
        self.current = None
        self.entries = []
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "section" and attrs.get("class") == "operation-group":
            self.category = attrs["data-category"]
        if tag == "a" and self.category:
            require(self.current is None, "nested navigation entry")
            self.current = [self.category, attrs["href"], ""]

    def handle_data(self, data):
        if self.current is not None:
            self.current[2] += data

    def handle_endtag(self, tag):
        if tag == "a" and self.current is not None:
            self.entries.append(self.current)
            self.current = None
        if tag == "section":
            self.category = None


def sections(site):
    result = {}
    for path in sorted((site / "api").glob("*.html")):
        text = regular(path).decode()
        headings = re.findall(r"<h1>([^<]+)</h1>", text)
        if not headings:
            require(path.name == "index.html", "unknown API page")
            continue
        require(len(headings) == 1, "ambiguous package")
        for match in SECTION.finditer(text):
            key = (headings[0], match[1])
            require(key not in result, "duplicate declaration destination")
            result[key] = (path.name, match[2], Snippet(match[3]))
    return result


def provenance(enhancer):
    require(git(enhancer, "rev-parse", "HEAD").decode().strip() == ENHANCER,
            "wrong enhancer revision")
    require(not git(enhancer, "status", "--porcelain",
                    "--untracked-files=no"), "modified enhancer source")
    git(enhancer, "merge-base", "--is-ancestor", ENHANCER, "origin/main")
    dist = importlib.metadata.distribution("ada-gnatdoc-enhancer")
    direct = json.loads(dist.read_text("direct_url.json"))
    require(unquote(urlsplit(direct["url"]).path) == str(enhancer) and
            not direct.get("dir_info", {}).get("editable"),
            "enhancer must be installed non-editably from the exact checkout")
    source = enhancer / "src/ada_gnatdoc_enhancer"
    installed = Path(dist.locate_file("ada_gnatdoc_enhancer"))
    files = {p.relative_to(source).as_posix(): sha(regular(p))
             for p in source.rglob("*")
             if p.is_file() and "__pycache__" not in p.parts}
    actual = {p.relative_to(installed).as_posix(): sha(regular(p))
              for p in installed.rglob("*")
              if p.is_file() and "__pycache__" not in p.parts}
    require(actual == files, "installed enhancer modules/assets differ")
    require(importlib.metadata.version("markdown-it-py") == "3.0.0" and
            importlib.metadata.version("mdurl") == "0.1.2",
            "wrong Markdown dependencies")
    return {"revision": ENHANCER, "direct_url": direct,
            "installed_sha256": files}


def investigate(args):
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.external_types import inventory
    from ada_gnatdoc_enhancer.pipeline import enhance, verify
    from ada_gnatdoc_enhancer.qualification import hashes, preserve_native
    from ada_gnatdoc_enhancer.qualification import identities

    require(not args.workspace.exists(), "workspace must not exist")
    args.workspace.mkdir(parents=True)
    tool = provenance(args.enhancer)
    require(git(args.source, "rev-parse", "HEAD").decode().strip() == BASE,
            "wrong Geometry source revision")
    require(git(args.core, "rev-parse", "HEAD").decode().strip() == CORE,
            "wrong Core dependency source (browser fixture is not dependency)")
    require(not git(args.core, "status", "--porcelain",
                    "--untracked-files=no"), "modified Core source")
    resolved = subprocess.check_output(
        ["alr", "-n", "exec", "--", "printenv", "OPENCV_CORE_ALIRE_PREFIX"],
        cwd=args.source).decode().strip()
    require(Path(resolved).resolve() == args.core.resolve(),
            "actual Alire Core source is not the qualified checkout")
    records = {}
    for name, expected in AUTHORITIES.items():
        payload = regular(args.enhancer / name)
        require(sha(payload) == expected, f"changed reviewed authority: {name}")
        records[Path(name).name] = json.loads(payload)
    authored = records["geometry-authored.json"]
    core_spec = records["core-0.5.0-input.json"]
    expected_types = records["core-0.5.0-types.json"]
    require(hashes(args.pristine) == authored["native_sha256"],
            "native bytes differ from independently qualified acquisition")
    require(hashes(args.pristine) == hashes(args.second_pristine),
            "two genuine native acquisitions are nondeterministic")

    root = args.workspace / "inputs"
    root.mkdir()
    for name, expected in authored["inputs"].items():
        payload = regular(args.source / name)
        require(sha(payload) == expected, f"authored authority changed: {name}")
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    for name in (*PUBLIC, "docs/api-categories.json"):
        payload = regular(args.source / name)
        require(payload == git(args.source, "show", f"{BASE}:{name}"),
                f"changed authoritative Geometry source: {name}")
        path = root / ("qualification-public/" + name if name in PUBLIC else name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    core_source = root / "dependency/source"
    for name, expected in core_spec["source_sha256"].items():
        require(not Path(name).is_absolute() and ".." not in Path(name).parts,
                "unsafe authority path")
        payload = regular(args.core / name)
        require(sha(payload) == expected and
                payload == git(args.core, "show", f"{CORE}:{name}"),
                f"Core source authority changed: {name}")
        path = core_source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    # Full independent reconstruction, including all 195 public Core units.
    observed_types = inventory(core_spec, core_source, args.core_native)
    require(observed_types == expected_types, "Core inventory reconstruction failed")
    shutil.copytree(args.core_native, root / "dependency/native")
    for name, data in records.items():
        write(root / name, data)
        require(regular(root / name) == regular(args.enhancer / next(
            p for p in AUTHORITIES if Path(p).name == name)),
            "authority serialization changed")

    # Include Point_Array explicitly: an omission here must not manufacture the
    # missing Contour base reference. Its unique Core native owner is verified.
    core_names = ["OpenCV.Angle_Unit", "OpenCV.Core.Mat", "OpenCV.Float32_Point",
                  "OpenCV.Float32_Value", "OpenCV.Float64_Value", "OpenCV.Rect",
                  "OpenCV.Rotated_Rect", "OpenCV.Point_Array"]
    config_text = '''schema_version = 1
project = "opencv_geometry_ada"
[gnatdoc]
version = "26.0.0"
[sources]
directories = ["qualification-public"]
packages = ["OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"]
comment_style = "leading"
[navigation]
mode = "operations"
categories = "docs/api-categories.json"
[presentation]
theme = true
syntax_highlighting = true
type_links = true
[guides]
mode = "authored-markdown"
manifest = "geometry-authored.json"
sha256 = "62a5cacfb86ece2017045e6354d6a9ce47b3d9706dd16873c2437b854dcb59ea"
[security]
external_hosts = ["core.invalid", "github.com", "zackboll.github.io"]
[[external_dependencies]]
repository = "https://github.com/zackboll/opencv_core_ada"
revision = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
manifest = "core-0.5.0-types.json"
manifest_sha256 = "70fa9a9e5de8ad038bf0bc4bdf6c76ec8ecbe5f201027d18554275f7d9ed7f7f"
acquisition = "core-0.5.0-input.json"
acquisition_sha256 = "4abd944e932116582efee29adb3eec767da762f67436cba5dddd82377fadcbbb"
source = "dependency/source"
site = "dependency/native"
base_url = "https://core.invalid/f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f/api/"
publication = "offline-test"
'''
    config_text += "types = " + json.dumps(core_names) + "\n"
    (root / "qualification.toml").write_text(config_text)
    config = load(root, "qualification.toml")
    sites = []
    for ordinal, pristine in enumerate((args.pristine, args.second_pristine), 1):
        site = args.workspace / f"shadow-{ordinal}"
        shutil.copytree(pristine, site)
        before = hashes(site)
        enhance(config, site, dry_run=True)
        require(hashes(site) == before, "dry-run modified native input")
        enhance(config, site)
        publication = verify(config, site)
        state = hashes(site)
        enhance(config, site)
        require(hashes(site) == state, "enhancement not byte-idempotent")
        preserve_native(identities(pristine), site)
        sites.append(site)
    require(hashes(sites[0]) == hashes(sites[1]), "nondeterministic enhancement")
    parity = {}
    for name in ["index.html", "guides/gnatdoc-guides.css",
                 *(g["path"] for g in authored["guides"])]:
        require(regular(args.legacy / name) == regular(sites[0] / name),
                f"authored byte parity failed: {name}")
        parity[name] = sha(regular(sites[0] / name))

    # Use the unchanged Geometry matcher, never the enhancer destination resolver.
    sys.path.insert(0, str(args.source / "scripts"))
    from link_gnatdoc_types import Sources
    from enhance_gnatdoc_navigation import entries
    source = Sources(args.source / "src")
    old, new = sections(args.legacy), sections(sites[0])
    require(set(old) == set(new) and len(old) == 130,
            "legacy/shadow declaration identity mismatch")
    local_owners = {}
    for (package, anchor), (page, name, snippet) in new.items():
        if re.match(r"\s*(type|subtype)\b", snippet.text):
            local_owners[(package + "." + name).lower()] = {
                "package": package, "page": page, "anchor": anchor}
    rows = []
    for (package, anchor), (page, name, legacy) in old.items():
        shared = new[(package, anchor)][2]
        require(legacy.text == shared.text, "native profile changed")
        declaration = source.packages[package.lower()].match(legacy.text)
        a = {(x["offset"], x["end"]): x for x in legacy.links}
        b = {(x["offset"], x["end"]): x for x in shared.links}
        for position in sorted(a.keys() | b.keys()):
            left, right = a.get(position), b.get(position)
            identity = (left or right)["identity"]
            require(not left or not right or left["identity"] == right["identity"],
                    "different source-owned type identity")
            external = not identity.startswith("opencv.geometry.")
            owner = observed_types["types"].get(identity) if external else local_owners[identity]
            require(owner is not None, "unqualified declaration owner")
            if right:
                url = urlsplit(right["href"])
                require(url.path.split("/")[-1] == owner["page"] and
                        url.fragment == owner["anchor"], "wrong existing native destination")
            classification = ("equivalent-verified-native-destination" if left and right
                              else "shared-only-reference" if right
                              else "BLOCKED-source-backed-reference-lost")
            reason = ("Same source-owned type and verified native destination; "
                      "symbol-router versus offline-native URLs are distinct contracts."
                      if left and right and external else
                      "Same source-owned local type and verified native destination."
                      if left and right else
                      "Typed constant: legacy type_positions declines declarations "
                      "not starting with function, procedure, type or subtype."
                      if right else
                      "Ordinary subtype base is absent from shared TYPE_MARK; "
                      "explicit dependency configuration includes this verified type.")
            source_profile = "\n".join(source.packages[package.lower()].lines[
                declaration["start"] - 1:declaration["end"]])
            rows.append({"package": package, "declaration": name,
                         "complete_source_profile": declaration["signature"],
                         "exact_source_declaration": source_profile,
                         "source_line": declaration["start"],
                         "native_page": page, "native_anchor": anchor,
                         "offset": position[0], "end": position[1],
                         "referenced_type": identity, "legacy": left, "shared": right,
                         "actual_native_declaration_owner": owner,
                         "qualified_external_core_owner": owner if external else None,
                         "classification": classification, "reason": reason})
    navigation = entries(args.pristine / "api", args.source / "src",
                         args.source / "docs/api-categories.json")
    expected_navigation = [
        [category, item["href"], item["name"] +
         (f' ({item["overload"]})' if item["overload"] else "")]
        for _, _, groups in navigation for category, _, items in groups for item in items]
    published_navigation = Navigation(regular(sites[0] / "api/index.html").decode()).entries
    require(published_navigation == expected_navigation,
            "unchanged consumer navigation oracle and published labels differ")
    write(args.workspace / "original-navigation.json", navigation)
    write(args.workspace / "type-link-occurrences.json", rows)
    report = {"disposition": "BLOCKED_BY_SHARED_TOOL" if any(
        r["shared"] is None for r in rows) else "PARTIAL_SHADOW_COMPATIBILITY",
        "consumer": BASE, "core_dependency": CORE, "tool": tool,
        "authority_sha256": AUTHORITIES, "configuration_sha256": sha(config_text.encode()),
        "publication": publication, "authored_byte_parity": parity,
        "pristine_sha256": hashes(args.pristine),
        "shadow_sha256": hashes(sites[0]), "native_identities": identities(args.pristine),
        "classification_counts": dict(Counter(r["classification"] for r in rows)),
        "legacy_local": sum(x["identity"].startswith("opencv.geometry.")
                            for _, _, s in old.values() for x in s.links),
        "legacy_external": sum(not x["identity"].startswith("opencv.geometry.")
                               for _, _, s in old.values() for x in s.links),
        "original_navigation_declarations": sum(len(items) for _, _, groups in navigation
                                                for _, _, items in groups),
        "published_navigation_matches_unchanged_oracle": True,
        "actual_alire_core_source": resolved,
        "native_deterministic": True, "enhanced_deterministic": True,
        "byte_idempotent": True, "production_https_verified": False,
        "non_deployable": True}
    write(args.workspace / "report.json", report)
    print(report["disposition"])
    print(json.dumps(report["classification_counts"], sort_keys=True))
    return 2 if report["disposition"] == "BLOCKED_BY_SHARED_TOOL" else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "legacy", "pristine", "second-pristine", "core",
                 "core-native", "enhancer", "workspace"):
        parser.add_argument("--" + name, required=True,
                            type=lambda p: Path(p).absolute())
    return investigate(parser.parse_args())


if __name__ == "__main__":
    sys.exit(main())