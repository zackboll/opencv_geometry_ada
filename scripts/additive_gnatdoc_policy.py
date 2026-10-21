#!/usr/bin/env python3
"""Candidate GEOM-DOC-010 policy. Import only from the trusted policy checkout.

No candidate module is imported, no approval record is created. Callers supply
an independently selected policy revision and an exact candidate Git revision.
"""
from collections import Counter
import copy
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

from qualify_shared_gnatdoc_shadow import (
    ROOT, BASE, REVIEWED, EVIDENCE, CONFIG, TRANSITION, TRANSITION_SHA256,
    TRUSTED_SCRIPTS, check_files, git, read, regular, require, sha,
    registered_cases, aunit_results, trusted_inputs,
)
from link_gnatdoc_types import Sources, TOKEN, resolve, type_positions
from enhance_gnatdoc_navigation import entries, load_categories
from investigate_shared_gnatdoc_types import sections, Navigation
from compare_shared_gnatdoc_geometry import file_hashes, write
from check_doc_coverage import check_site

PREDECESSOR = "2f5239a0e264ca2bb4106cdb338d3eac25abf674"
PACKAGES = {"opencv.geometry", "opencv.geometry.subdiv2d"}
ADDITIONS = frozenset((
    "To_Mat", "Affine_From_Mat", "Perspective_From_Mat",
    "Get_Rotation_Affine_Transform_2D", "Compose",
    "Invert_Perspective_Transform",
))
GUIDE = "docs/guides/affine-and-perspective-geometry.md"
EXAMPLE = "docs/examples/affine_and_perspective.adb"
EVOLVING_AUTHORED = frozenset((GUIDE, EXAMPLE))


def inventory(source):
    """Complete source text, including aspects, defaults and record members."""
    sources = Sources(source / "src")
    require(set(sources.packages) == PACKAGES, "unexpected public package")
    result = {}
    for owner, package in sources.packages.items():
        rows = []
        for declaration in package.top:
            raw = "\n".join(package.lines[
                declaration["start"] - 1:declaration["end"]])
            # Unlike type-name tokenization, keep string literals: defaults,
            # constant values and contract messages are published source too.
            code = tuple(m.group() if m.group().startswith('"') else m.group().lower()
                         for m in TOKEN.finditer(raw) if not m.group().startswith("--"))
            rows.append({"name": declaration["name"], "code": code,
                         "profile": declaration["signature"],
                         "kind": code[0], "source_line": declaration["start"]})
        require(len({row["code"] for row in rows}) == len(rows),
                "duplicate public declaration")
        result[owner] = rows
    return result


def compatible(baseline, current, additions=ADDITIONS):
    require(baseline.keys() == current.keys(), "public package ownership changed")
    added = []
    for owner, old in baseline.items():
        new = current[owner]
        codes = [row["code"] for row in new]
        previous = -1
        for row in old:
            require(codes.count(row["code"]) == 1,
                    "published declaration removed or modified: " + row["name"])
            index = codes.index(row["code"])
            require(index > previous, "published declaration order changed")
            previous = index
        old_codes = {row["code"] for row in old}
        for index, row in enumerate(new):
            if row["code"] in old_codes:
                continue
            require(owner == "opencv.geometry" and row["name"] in additions
                    and row["kind"] == "function", "unapproved additive declaration")
            require(all(index > codes.index(before["code"]) for before in old
                        if before["name"].lower() == row["name"].lower()),
                    "existing overload identity/order changed")
            added.append({"package": owner, **row})
    return added


def categories(baseline, candidate, current):
    old = read(baseline / "docs/api-categories.json")
    new = read(candidate / "docs/api-categories.json")
    _, owners = load_categories(candidate / "docs/api-categories.json")
    expected = {(owner, row["name"]) for owner, rows in current.items()
                for row in rows}
    require({(p.lower(), n) for p, n in owners} == expected,
            "missing or unknown category declaration")
    require(len(old["packages"]) == len(new["packages"]), "category package changed")
    for left, right in zip(old["packages"], new["packages"]):
        require(left["package"] == right["package"] and
                len(left["categories"]) == len(right["categories"]),
                "category package ownership changed")
        for a, b in zip(left["categories"], right["categories"]):
            if left["package"] == "OpenCV.Geometry" and a["id"] == "transforms":
                require({k: v for k, v in a.items() if k != "declarations"} ==
                        {k: v for k, v in b.items() if k != "declarations"},
                        "transform category metadata changed")
                require([n for n in b["declarations"] if n in a["declarations"]]
                        == a["declarations"], "existing category assignment changed")
                require(set(a["declarations"]) <= set(b["declarations"]),
                        "existing category deletion")
            else:
                require(a == b, "unapproved category reassignment")
    return owners


def exact_snapshot(source, repository, revision, pins=False):
    require(re.fullmatch(r"[0-9a-f]{40}", revision) is not None,
            "candidate revision must be an exact SHA")
    names = git(repository, "ls-tree", "-r", "--name-only", revision).decode().splitlines()
    ignored = {"alire.toml", "tests/alire.toml"} if pins else set()
    for name in names:
        if name not in ignored:
            require(regular(source / name) == git(repository, "show", f"{revision}:{name}"),
                    "candidate snapshot changed: " + name)
    for prefix in ("src", "cpp", "tests/src", "docs/guides", "docs/examples", "scripts"):
        found = {p.relative_to(source).as_posix() for p in (source / prefix).rglob("*")
                 if p.is_file() and "__pycache__" not in p.parts}
        require(found == {n for n in names if n.startswith(prefix + "/")},
                "unexpected candidate file inventory: " + prefix)
    return git(repository, "rev-parse", revision + "^{tree}").decode().strip()


def policy_identity(revision):
    require(git(ROOT, "rev-parse", "HEAD").decode().strip() == revision,
            "executing verifier is not the selected policy revision")
    require(not git(ROOT, "status", "--porcelain"), "policy checkout is not clean")
    git(ROOT, "merge-base", "--is-ancestor", PREDECESSOR, revision)
    historical_inputs(ROOT)
    return git(ROOT, "rev-parse", revision + "^{tree}").decode().strip()


def historical_inputs(root):
    """Keep predecessor authority, but never freeze evolving scoped inputs."""
    check_files(root, {TRANSITION: TRANSITION_SHA256})
    authority = read(ROOT / TRANSITION)
    for name, digest in authority["baseline_files_sha256"].items():
        require(sha(git(ROOT, "show", f"{BASE}:{name}")) == digest,
                "historical Git authority differs: " + name)
    for prefix in ("docs/evidence/gnatdoc009", EVIDENCE):
        for name in git(ROOT, "ls-tree", "-r", "--name-only", REVIEWED,
                        "--", prefix).decode().splitlines():
            require(regular(root / name) == git(ROOT, "show", f"{REVIEWED}:{name}"),
                    "historical evidence modified: " + name)
    check_files(root / EVIDENCE, authority["contracts_sha256"])
    check_files(root, {CONFIG: authority["configuration_sha256"]})
    for name in TRUSTED_SCRIPTS:
        check_files(root, {name: authority["baseline_files_sha256"][name]})
    authored = read(ROOT / EVIDENCE / "geometry-authored.json")
    check_files(root, {n: d for n, d in authored["inputs"].items()
                      if n not in EVOLVING_AUTHORED})
    check_files(root, {n: d for n, d in authority["baseline_files_sha256"].items()
                      if n in ("docs_api.gpr", "docs_internal.gpr") or n.startswith("docs/assets/")})
    return authority


def candidate_rules(baseline, candidate, additions=ADDITIONS, qualification_pins=False):
    """Candidate hashes never select verifier code or authorize frozen inputs."""
    from validate_gnatdoc_inputs import validate
    validate(candidate, ROOT, qualification_pins)
    historical_inputs(candidate)
    # Protect every executable local verifier dependency, not a filename heuristic.
    for name in git(ROOT, "ls-files", "--", "scripts", ".github/workflows").decode().splitlines():
        require(regular(candidate / name) == regular(ROOT / name),
                "protected verification component changed: " + name)
    for prefix in ("scripts", ".github/workflows"):
        require({p.relative_to(candidate).as_posix() for p in (candidate / prefix).rglob("*")
                 if p.is_file() and "__pycache__" not in p.parts} ==
                set(git(ROOT, "ls-files", "--", prefix).decode().splitlines()),
                "unapproved verification file inventory")
    for name in (CONFIG, "docs_api.gpr", "docs_internal.gpr",
                 "docs/gnatdoc-warning-baseline.txt", "docs/gnatdoc-coverage-baseline.txt"):
        require(regular(candidate / name) == regular(ROOT / name),
                "protected documentation configuration changed")
    authored = read(ROOT / EVIDENCE / "geometry-authored.json")
    check_files(candidate, {n: d for n, d in authored["inputs"].items()
                            if n not in EVOLVING_AUTHORED})
    for name in git(ROOT, "ls-files", "--", "docs/assets").decode().splitlines():
        require(regular(candidate / name) == regular(ROOT / name), "authored asset modified")
    # The selected reviewed policy base is the evolving published baseline.
    # PREDECESSOR stays historical; future merged additions cannot be removed.
    old, current = inventory(ROOT), inventory(candidate)
    added = compatible(old, current, additions)
    categories(ROOT, candidate, current)
    old_cases, current_cases = registered_cases(ROOT), registered_cases(candidate)
    require(set(old_cases) <= set(current_cases), "existing AUnit registration disappeared")
    return {"declarations": sum(map(len, current.values())), "added": added,
            "aunit_registered": len(current_cases)}


def coverage(source, site, log):
    items, missing, errors = check_site(site, source)
    require(not missing and not errors, "current documentation gaps: " + str((missing, errors)))
    text = regular(log).decode()
    require(not re.search(r"warning:|error:|fatal:|ignore file due to", text, re.I),
            "current native diagnostics are not clean")
    return {"documented": len(items), "items": len(items), "missing": 0,
            "warnings": 0, "by_kind": dict(Counter(items.values()))}


def authored_contract(candidate, pristine):
    """Derivation only, rechecked against exact candidate source on every verify."""
    manifest = copy.deepcopy(read(ROOT / EVIDENCE / "geometry-authored.json"))
    for name in EVOLVING_AUTHORED:
        manifest["inputs"][name] = sha(regular(candidate / name))
    manifest["native_sha256"] = file_hashes(pristine)
    payload = (json.dumps(manifest, sort_keys=True, indent=2) + "\n").encode()
    config = regular(ROOT / CONFIG).replace(
        b'manifest = "docs/evidence/gnatdoc009b/geometry-authored.json"',
        b'manifest = "current-authored.json"').replace(
        read(ROOT / TRANSITION)["contracts_sha256"]["geometry-authored.json"].encode(),
        sha(payload).encode())
    return payload, config


def current_output(source, pristine, shadow, core):
    """Independent source matcher/resolver; no shared-tool inventory authority."""
    oracle = entries(pristine / "api", source / "src", source / "docs/api-categories.json")
    native, rendered = sections(pristine), sections(shadow)
    require({p.lower() for p, _ in native} == PACKAGES, "native package ownership changed")
    require(native.keys() == rendered.keys(), "native declaration inventory mismatch")
    require(len(native) == sum(map(len, inventory(source).values())),
            "source/native declaration correspondence differs")
    sources = Sources(source / "src")
    local = {(p + "." + n).lower(): {"page": page, "anchor": a, "package": p}
             for (p, a), (page, n, s) in native.items()
             if s.text.lstrip().startswith(("type ", "subtype "))}
    pages = {p.lower(): Path(page) for (p, _), (page, _, _) in native.items()}
    targets = {name: owner["anchor"] for name, owner in local.items()}
    rows = []
    for key, (page, name, snippet) in native.items():
        owner, anchor = key
        after = rendered[key][2]
        require(after.text == snippet.text, "source/native profile mismatch")
        package = sources.packages[owner.lower()]
        declaration = package.match(snippet.text)
        positions = list(type_positions(snippet.text))
        constant = re.match(r"\s*\w+\s*:\s*constant\s+([A-Za-z][A-Za-z0-9_.]*)", snippet.text, re.I)
        if constant:
            positions.append((constant[1].lower(), constant.start(1), constant.end(1)))
        expected = {}
        for spelling, start, end in positions:
            identity, _, _ = resolve(spelling, declaration, package, sources, pages,
                                      targets, core["types"])
            if identity:
                expected[start, end] = identity
        actual = {(link["offset"], link["end"]): link for link in after.links}
        require(len(actual) == len(after.links) and
                {pos: link["identity"] for pos, link in actual.items()} == expected,
                "type occurrences differ from independently resolved source: " + owner + "." + name
                + " expected=" + repr(expected) + " actual=" + repr(actual))
        for position, identity in expected.items():
            external = not identity.startswith("opencv.geometry.")
            destination = core["types"][identity] if external else local[identity]
            href = destination["page"] + "#" + destination["anchor"]
            if external:
                href = f'https://core.invalid/{core["revision"]}/api/' + href
            require(actual[position]["href"] == href, "wrong native type destination")
            rows.append({"package": owner, "declaration": name, "native_page": page,
                         "native_anchor": anchor, "offset": position[0], "end": position[1],
                         "referenced_type": identity, "shared": actual[position],
                         "complete_source_profile": declaration["signature"],
                         "actual_native_declaration_owner": destination})
    expected_nav = [[category, item["href"], item["name"] +
                     (f' ({item["overload"]})' if item["overload"] else "")]
                    for _, _, groups in oracle for category, _, group in groups for item in group]
    require(Navigation(regular(shadow / "api/index.html").decode()).entries == expected_nav,
            "source-backed navigation identity/order mismatch")
    return {"declarations": len(native), "occurrences": len(rows), "missing": 0,
            "local": sum(r["referenced_type"].startswith("opencv.geometry.") for r in rows),
            "external": sum(not r["referenced_type"].startswith("opencv.geometry.") for r in rows),
            "navigation": oracle, "type_references": rows}