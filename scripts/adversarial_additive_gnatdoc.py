#!/usr/bin/env python3
"""Sequential observed successor attacks, followed by independent restoration."""
import argparse
import copy
import json
from pathlib import Path

from additive_gnatdoc_policy import (
    ROOT, EVIDENCE, GUIDE, EXAMPLE, TRANSITION, TRUSTED_SCRIPTS,
    regular, read, require, sha, write, file_hashes, inventory, compatible,
    candidate_rules, aunit_results,
)
from qualify_additive_gnatdoc import verify


def qualify(workspace, repository, revision, policy_revision, synthetic=False):
    q = read(workspace / "qualification.json")
    require(q["status"] == "pass", "cannot attack failed qualification")
    initial = verify(workspace, repository, revision, policy_revision, synthetic)
    site = workspace / "first/_site"
    original = file_hashes(site)
    report = {"status": "fail", "run_id": q["run_id"], "candidate": revision,
              "qualification_sha256": sha(regular(workspace / "qualification.json")),
              "site_sha256": original, "attacks": []}

    def check():
        return verify(workspace, repository, revision, policy_revision, synthetic)

    def mutation(name, changes, reject=check):
        backups = {path: regular(path) for path in changes}
        observed = {}
        try:
            for path, change in changes.items():
                after = change(backups[path])
                require(after != backups[path], "unobserved attack: " + name)
                path.write_bytes(after)
                require(regular(path) == after, "attack not installed")
                observed[str(path.relative_to(workspace))] = sha(after)
            try:
                reject()
            except (ValueError, OSError, KeyError) as error:
                reason = str(error)
            else:
                raise AssertionError("attack accepted: " + name)
        finally:
            for path, before in backups.items():
                path.write_bytes(before)
        require(file_hashes(site) == original, "incomplete attack restoration")
        require(check() == initial, "independent restored verification differs")
        report["attacks"].append({"name": name, "observed_sha256": observed,
                                   "rejection": reason, "restored_and_verified": True})

    source = workspace / "source"
    root = workspace / "first"
    spec = source / "src/opencv-geometry.ads"
    try:
        mutation("published signature modification", {spec: lambda b: b.replace(
            b"type Affine_Row_Index is range 1 .. 2;", b"type Affine_Row_Index is range 1 .. 3;")})
        mutation("published declaration removal", {spec: lambda b: b.replace(
            b"   type Affine_Row_Index is range 1 .. 2;\n", b"")})
        mutation("duplicate declaration", {spec: lambda b: b.replace(
            b"   type Affine_Row_Index is range 1 .. 2;",
            b"   type Affine_Row_Index is range 1 .. 2;\n   type Affine_Row_Index is range 1 .. 2;")})
        mutation("staged source/native mismatch", {root / "qualification-public/src/opencv-geometry.ads":
            lambda b: b.replace(b"type Affine_Row_Index is range 1 .. 2;", b"type Affine_Row_Index is range 1 .. 4;")})
        categories = root / "docs/api-categories.json"
        mutation("missing category entry", {categories: lambda b: b.replace(b'"Contour",', b"", 1)})
        mutation("duplicate category entry", {categories: lambda b: b.replace(b'"Contour",', b'"Contour", "Contour",', 1)})
        mutation("unapproved category reassignment", {categories: lambda b: b.replace(
            b'"Contour",', b'"Affine_Transform_2D",', 1).replace(b'"Affine_Transform_2D",\n            "Get_Affine',
            b'"Contour",\n            "Get_Affine', 1)})
        mutation("unapproved guide modification", {root / "docs/guides/delaunay-and-voronoi.md":
            lambda b: b + b"\nUnapproved authored change.\n"})
        mutation("approved path changed after snapshot", {root / GUIDE: lambda b: b + b"\nSubstituted guide.\n"})
        mutation("unapproved example modification", {root / "docs/examples/delaunay_and_voronoi.adb":
            lambda b: b + b"\n-- unapproved example\n"})
        mutation("approved example changed after snapshot", {root / EXAMPLE: lambda b: b + b"\n-- substituted\n"})
        mutation("forged authored-input manifest", {root / "current-authored.json": lambda b: b + b" "})
        mutation("modified historical authority", {root / TRANSITION: lambda b: b + b" "})
        mutation("modified historical evidence", {root / EVIDENCE / "qualified/readiness.json": lambda b: b + b" "})
        mutation("protected historical verifier", {root / TRUSTED_SCRIPTS[0]: lambda b: b + b"\n# forged\n"})
        mutation("substituted successor verifier", {root / "scripts/additive_gnatdoc_policy.py":
            lambda b: b + b"\n# candidate tries to approve itself\n"})
        mutation("falsified AUnit execution", {workspace / "aunit.log": lambda b: b.replace(b"OK ", b"FORGED ", 1)})
        mutation("falsified AUnit totals", {workspace / "aunit.log": lambda b: b.replace(
            b"Failed Assertions: 0", b"Failed Assertions: 1")})
        comparison = initial["comparison"]
        row = next(r for r in comparison["type_references"] if r["referenced_type"] == "opencv.point_array")
        page = site / "api" / row["native_page"]
        other = next(r for r in comparison["type_references"] if r["referenced_type"] == "opencv.rect")
        mutation("wrong Core type destination", {page: lambda b: b.replace(
            row["shared"]["href"].encode(), other["shared"]["href"].encode(), 1)})
        mutation("wrong-but-valid native anchor", {site / "api/index.html": lambda b: b.replace(
            row["native_anchor"].encode(), other["native_anchor"].encode(), 1)})
        mutation("native profile tamper", {page: lambda b: b.replace(b"Point_Array", b"Wrong_Array", 1)})
        manifest = site / "api/presentation.json"

        def forged(data):
            value = json.loads(data)
            value["output_sha256"]["api/" + row["native_page"]] = sha(regular(page))
            return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()

        mutation("coordinated output and matching forged manifest", {
            page: lambda b: b + b"<!-- forged output -->",
            manifest: forged})
        mutation("forged current native acquisition", {workspace / "pristine-first/api/index.html":
            lambda b: b + b"<!-- forged native -->"})
        # These probes exercise the compatibility parser independent of the
        # stronger exact-snapshot rejection used for on-disk mutations above.
        before = inventory(workspace / "baseline")
        changed = copy.deepcopy(before)
        rows = changed["opencv.geometry"]
        indexes = [i for i, r in enumerate(rows) if r["name"] == "Transform_Point"]
        rows[indexes[0]], rows[indexes[1]] = rows[indexes[1]], rows[indexes[0]]
        try:
            compatible(before, changed)
        except ValueError as error:
            report["attacks"].append({"name": "incorrect existing overload identity",
                "observed": True, "rejection": str(error), "restored_and_verified": check() == initial})
        else:
            raise AssertionError("overload substitution accepted")
        try:
            verify(workspace, repository, "0" * 40, policy_revision, synthetic)
        except (ValueError, OSError) as error:
            report["attacks"].append({"name": "stale/substituted candidate commit", "observed": True,
                "rejection": str(error), "restored_and_verified": check() == initial})
        else:
            raise AssertionError("stale candidate accepted")
        require(check() == initial, "final independent restoration differs")
        report.update({"status": "pass", "restored_and_verified": True,
                       "executed": len(report["attacks"])})
    except Exception as error:
        report["failure"] = str(error)
        raise
    finally:
        write(workspace / "negative.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("workspace", "candidate-repository"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("candidate-revision", "policy-revision"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--synthetic", action="store_true")
    args = parser.parse_args()
    qualify(args.workspace, args.candidate_repository, args.candidate_revision,
            args.policy_revision, args.synthetic)