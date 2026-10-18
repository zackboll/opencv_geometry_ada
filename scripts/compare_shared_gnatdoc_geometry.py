#!/usr/bin/env python3
"""Independent consumer source/native occurrence and navigation success gate.

The historical diagnostic remains unchanged. This comparator uses its small
HTML readers and the original Geometry source matcher, not shared resolution.
"""
from collections import Counter
import json
from pathlib import Path
import sys
from urllib.parse import parse_qs, urlsplit

from investigate_shared_gnatdoc_types import Navigation, regular, require, sections, sha
from enhance_gnatdoc_navigation import entries
from link_gnatdoc_types import Sources


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
    rows = []
    for (package, anchor), (page, name, before) in old.items():
        after = new[package, anchor][2]
        require(before.text == after.text == native[package, anchor][2].text,
                "complete native profile changed")
        declaration = sources.packages[package.lower()].match(after.text)
        left = {(x["offset"], x["end"]): x for x in before.links}
        right = {(x["offset"], x["end"]): x for x in after.links}
        require(len(left) == len(before.links) and len(right) == len(after.links),
                "duplicate type occurrence")
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
    keys = ("package", "declaration", "native_page", "native_anchor", "offset", "end",
            "referenced_type", "complete_source_profile", "exact_source_declaration", "source_line",
            "actual_native_declaration_owner", "legacy")
    require(len(history) == len(rows) and
            all(all(a[k] == b[k] for k in keys) for a, b in zip(history, rows)),
            "source occurrence ledger differs from reviewed historical identities")
    repaired = [r for r in rows if r["declaration"] == "Contour"]
    require(len(repaired) == 1 and repaired[0]["referenced_type"] == "opencv.point_array" and
            repaired[0]["exact_source_declaration"].strip().startswith(
                "subtype Contour is OpenCV.Point_Array;"), "Contour base proof differs")
    oracle = entries(pristine / "api", source / "src", source / "docs/api-categories.json")
    legacy_oracle = entries(source / "_site/api", source / "src", source / "docs/api-categories.json")
    require(oracle == legacy_oracle, "original navigation/profile oracle changed")
    require(json.loads(json.dumps(oracle)) == json.loads(regular(
                history_root / "docs/evidence/gnatdoc009/original-navigation.json")),
            "navigation differs from historical source-backed oracle")
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
              "tested_shadow_sha256": file_hashes(shadow)}
    write(workspace / "comparison.json", result)
    return result


def file_hashes(root):
    return {p.relative_to(root).as_posix(): sha(regular(p))
            for p in sorted(root.rglob("*")) if p.is_file()}


if __name__ == "__main__":
    print(json.dumps(compare(Path(sys.argv[1]).absolute()), indent=2))