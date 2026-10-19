#!/usr/bin/env python3
"""Independent consumer source/native occurrence and navigation success gate.

The historical diagnostic remains unchanged. This comparator uses its small
HTML readers and the original Geometry source matcher, not shared resolution.
"""
from collections import Counter
import json
from pathlib import Path
import re
import sys
from urllib.parse import parse_qs, urlsplit

from investigate_shared_gnatdoc_types import Navigation, regular, require, sections, sha
from enhance_gnatdoc_navigation import entries
from link_gnatdoc_types import Sources, resolve, type_positions


def write(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def compare(workspace):
    source = workspace / "legacy"
    pristine = workspace / "pristine-first"
    shadow = workspace / "first/_site"
    core = json.loads(regular(workspace / "first/docs/evidence/gnatdoc009b/core-0.5.0-types.json"))
    old, new, native = (sections(p) for p in (source / "_site", shadow, pristine))
    require(old.keys() == new.keys() == native.keys() and len(new) == 130,
            "declaration inventory differs")
    require({k[0] for k in new} == {"OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"},
            "public package ownership differs")
    sources = Sources(source / "src")
    local = {(p + "." + n).lower(): {"page": page, "anchor": a, "package": p}
             for (p, a), (page, n, s) in native.items()
             if s.text.lstrip().startswith(("type ", "subtype "))}
    pages = {p.lower(): Path(page) for (p, _), (page, _, _) in native.items()}
    targets = {name: owner["anchor"] for name, owner in local.items()}
    rows = []
    for (package, anchor), (page, name, before) in old.items():
        after = new[package, anchor][2]
        require(before.text == after.text == native[package, anchor][2].text,
                "complete native profile changed")
        declaration = sources.packages[package.lower()].match(after.text)
        expected_types = {}
        for spelling, start, end in type_positions(after.text):
            identity, _, _ = resolve(spelling, declaration, sources.packages[package.lower()],
                                      sources, pages, targets, core["types"])
            if identity:
                expected_types[start, end] = identity
        constant = re.match(r"\s*\w+\s*:\s*constant\s+([A-Za-z][A-Za-z0-9_.]*)", after.text, re.I)
        if constant:
            spelling = constant[1].lower()
            identity, _, _ = resolve(spelling, declaration, sources.packages[package.lower()],
                                      sources, pages, targets, core["types"])
            require(identity is not None, "unresolved constant source type")
            expected_types[constant.start(1), constant.end(1)] = identity
        left = {(x["offset"], x["end"]): x for x in before.links}
        right = {(x["offset"], x["end"]): x for x in after.links}
        require(len(left) == len(before.links) and len(right) == len(after.links),
                "duplicate type occurrence")
        require({position: link["identity"] for position, link in right.items()} == expected_types,
                "type references differ from independently resolved source positions")
        for position in sorted(left.keys() | right.keys()):
            a, b = left.get(position), right.get(position)
            require(b is not None, "missing source-backed type occurrence")
            identity = b["identity"]
            require(not a or a["identity"] == identity, "forged source-owned type identity")
            external = not identity.startswith("opencv.geometry.")
            owner = core["types"][identity] if external else local[identity]
            target = urlsplit(b["href"])
            require(target.fragment == owner["anchor"] and
                    target.path.split("/")[-1] == owner["page"],
                    "wrong-but-existing native destination")
            if external:
                require(b["href"] == f'https://core.invalid/{core["revision"]}/api/' +
                        owner["page"] + "#" + owner["anchor"], "forged external URL")
                if a:
                    legacy_url = urlsplit(a["href"])
                    require(legacy_url.netloc == "zackboll.github.io" and
                            legacy_url.path == "/opencv_core_ada/api/index.html" and
                            parse_qs(legacy_url.query).get("symbol", [""])[0].lower() == identity,
                            "unverified legacy symbol-router identity")
            else:
                require(not target.scheme and not target.netloc and target.path == owner["page"],
                        "forged local URL")
            rows.append({"package": package, "declaration": name, "native_page": page,
                         "native_anchor": anchor, "complete_source_profile": declaration["signature"],
                         "exact_source_declaration": "\n".join(sources.packages[package.lower()].lines[
                             declaration["start"] - 1:declaration["end"]]),
                         "source_line": declaration["start"], "offset": position[0], "end": position[1],
                         "referenced_type": identity, "legacy": a, "shared": b,
                         "actual_native_declaration_owner": owner,
                         "classification": "equivalent-verified-native-destination" if a else
                                           "shared-only-reference"})
    counts = dict(Counter(r["classification"] for r in rows))
    require(counts == {"equivalent-verified-native-destination": 263, "shared-only-reference": 4},
            "unexplained occurrence classification")
    additions = {r["declaration"]: r["referenced_type"] for r in rows if not r["legacy"]}
    require(additions == {"Identity_Affine_Transform": "opencv.geometry.affine_transform_2d",
                          "Identity_Perspective_Transform": "opencv.geometry.perspective_transform_2d",
                          "No_Edge": "opencv.geometry.subdiv2d.edge_id",
                          "No_Vertex": "opencv.geometry.subdiv2d.vertex_id"},
            "shared-only reference ownership differs")
    require(sum(r["referenced_type"].startswith("opencv.geometry.") for r in rows) == 171,
            "local type count differs")
    history_root = Path(__file__).absolute().parents[1]
    history = json.loads(regular(history_root / "docs/evidence/gnatdoc009/type-link-occurrences.json"))
    # Historical line numbers belong to historical source. Current profiles,
    # occurrences and destinations have just been resolved from current source
    # and two independently generated native sites; history is not their oracle.
    historical_profiles = {(a["package"], a["native_anchor"]): a["complete_source_profile"]
                           for a in history}
    changes = [r["native_anchor"] for r in rows if historical_profiles.get(
        (r["package"], r["native_anchor"])) != r["complete_source_profile"]]
    repaired = [r for r in rows if r["declaration"] == "Contour"]
    require(len(repaired) == 1 and repaired[0]["referenced_type"] == "opencv.point_array" and
            repaired[0]["exact_source_declaration"].strip().startswith(
                "subtype Contour is OpenCV.Point_Array;"), "Contour base proof differs")
    oracle = entries(pristine / "api", source / "src", source / "docs/api-categories.json")
    legacy_oracle = entries(source / "_site/api", source / "src", source / "docs/api-categories.json")
    require(oracle == legacy_oracle, "original navigation/profile oracle changed")
    expected = [[category, item["href"], item["name"] +
                 (f' ({item["overload"]})' if item["overload"] else "")]
                for _, _, groups in oracle for category, _, items in groups for item in items]
    actual = Navigation(regular(shadow / "api/index.html").decode()).entries
    require(actual == expected and len(actual) == 130, "source-order navigation parity differs")
    write(workspace / "type-link-occurrences.json", rows)
    write(workspace / "navigation-oracle.json", oracle)
    result = {"status": "pass", "classification_counts": counts, "missing": 0, "total": 267,
              "local_type_links": 171, "external_type_links": 96, "navigation_entries": 130,
              "contour": repaired[0], "shared_only_owners": additions,
              "current_profiles_changed_from_history": sorted(set(changes)),
              "tested_shadow_sha256": file_hashes(shadow)}
    write(workspace / "comparison.json", result)
    return result


def file_hashes(root):
    return {p.relative_to(root).as_posix(): sha(regular(p))
            for p in sorted(root.rglob("*")) if p.is_file()}


if __name__ == "__main__":
    print(json.dumps(compare(Path(sys.argv[1]).absolute()), indent=2))