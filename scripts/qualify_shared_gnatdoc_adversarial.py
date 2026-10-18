#!/usr/bin/env python3
"""Observed, sequential mutations; restore and hash-verify every test workspace.

Never run concurrently with Chromium on the same workspace. Trusted inputs and
the installed enhancer are never tampered: enhancer mutations use disposable
clones and package-byte comparison through a mocked distribution locator.
"""
from __future__ import annotations

import argparse
import importlib.metadata
from pathlib import Path
import shutil
import subprocess
import tempfile
from unittest.mock import patch

from qualify_shared_gnatdoc_shadow import (
    ROOT, BASE, CORE, ENHANCER, CONFIG, EVIDENCE, TRANSITION, Session, check_files,
    file_hashes, provenance, read, regular, require, resolved_core, sha, trusted_inputs,
    verify_publication, write,
)


def qualify(workspace, enhancer):
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.pipeline import enhance
    q = read(workspace / "qualification.json")
    site = workspace / "first/_site"
    original = file_hashes(site)
    require(original == q["shadow_sha256"], "adversarial starting output differs")
    root = workspace / "first"
    report = {"status": "fail", "run_id": q["run_id"], "consumer_tested": q["consumer_tested"],
              "qualification_sha256": sha(regular(workspace / "qualification.json")),
              "tested_shadow_sha256": original, "mutations": []}
    verify = lambda: verify_publication(workspace, enhancer)

    def mutation(name, path, change, reject=verify):
        before = regular(path)
        after = change(before)
        require(after != before, "mutation did not change bytes: " + name)
        path.write_bytes(after)
        require(regular(path) == after and sha(after) != sha(before), "mutation was not observed")
        rejection = None
        try:
            reject()
        except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as exc:
            rejection = str(exc)
        finally:
            path.write_bytes(before)
        require(file_hashes(site) == original, "incomplete output restoration: " + name)
        verify()
        require(rejection is not None, "mutation was accepted: " + name)
        report["mutations"].append({"name": name, "observed_sha256": sha(after),
                                    "original_sha256": sha(before), "rejection": rejection,
                                    "restored_output_sha256": original})

    rows = read(workspace / "type-link-occurrences.json")
    contour = next(r for r in rows if r["declaration"] == "Contour")
    page = site / "api" / contour["native_page"]
    anchor = contour["actual_native_declaration_owner"]["anchor"]
    owner = contour["actual_native_declaration_owner"]
    core_types = read(root / EVIDENCE / "core-0.5.0-types.json")["types"]
    other_anchor = next(t["anchor"] for t in core_types.values()
                        if t["page"] == owner["page"] and t["anchor"] != anchor)
    try:
        mutation("modified authority transition", root / TRANSITION, lambda b: b + b" ")
        transition = root / TRANSITION
        backup = regular(transition)
        transition.unlink()
        require(not transition.exists(), "authority removal not observed")
        try:
            try:
                verify()
            except ValueError as exc:
                report["mutations"].append({"name": "missing authority transition", "observed": True,
                                            "rejection": str(exc)})
            else:
                raise AssertionError("missing authority accepted")
        finally:
            transition.write_bytes(backup)
        verify()
        mutation("altered historical occurrence ledger", root / "docs/evidence/gnatdoc009/type-link-occurrences.json",
                 lambda b: b.replace(b"equivalent-verified-native-destination", b"forged", 1))
        mutation("Core 0.5.1 substitution", root / CONFIG, lambda b: b.replace(CORE.encode(), b"0.5.1"))
        mutation("browser fixture substituted for Core source", root / CONFIG,
                 lambda b: b.replace(CORE.encode(), b"ccc2190f9bf0712d65a2b9d2983cde7ce68b4bae"))
        mutation("altered public Ada declaration", root / "qualification-public/src/opencv-geometry.ads",
                 lambda b: b.replace(b"subtype Contour is OpenCV.Point_Array;", b"subtype Contour is OpenCV.Rect;"))
        mutation("wrong-but-existing native Core anchor", page,
                 lambda b: b.replace(anchor.encode(), other_anchor.encode(), 1))
        other_page = next(r["native_page"] for r in rows if r["package"] == "OpenCV.Geometry.Subdiv2D")
        mutation("cross-package declaration substitution", site / "api/index.html",
                 lambda b: b.replace(contour["native_page"].encode(), other_page.encode(), 1))
        mutation("forged type identity", page,
                 lambda b: b.replace(b'data-type="opencv.point_array"', b'data-type="opencv.rect"', 1))
        mutation("forged external URL", page,
                 lambda b: b.replace(b"https://core.invalid/", b"https://unapproved.invalid/", 1))
        categories = root / "docs/api-categories.json"
        mutation("missing category assignment", categories, lambda b: b.replace(b'"Contour",', b"", 1))
        mutation("duplicated category assignment", categories,
                 lambda b: b.replace(b'"Contour",', b'"Contour", "Contour",', 1))
        mutation("wrong overload full profile", page,
                 lambda b: b.replace(b"Oriented : Boolean := False", b"Oriented : Boolean := True", 1))
        mutation("altered authored guide", root / "docs/guides/delaunay-and-voronoi.md", lambda b: b + b"tamper\n")
        mutation("altered executable source", root / "docs/example.adb", lambda b: b + b"-- tamper\n")
        mutation("changed compiled-example ownership", root / EVIDENCE / "geometry-authored.json",
                 lambda b: b.replace(b'"landing_example": "docs/example.adb"',
                                     b'"landing_example": "docs/examples/delaunay_and_voronoi.adb"'))
        # A rewritten output manifest cannot confer authority on a modified site.
        manifest = site / "api/presentation.json"
        def forged_manifest(data):
            import json
            value = read(manifest)
            value["output_sha256"]["api/" + contour["native_page"]] = "0" * 64
            return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()
        mutation("output manifest rewritten to authorize tampering", manifest, forged_manifest)
        # Change both generated bytes and their manifest claim. The verifier must
        # reconstruct from independently trusted source/native input regardless.
        original_page, original_manifest = regular(page), regular(manifest)
        altered_page = original_page.replace(anchor.encode(), other_anchor.encode(), 1)
        require(altered_page != original_page, "coordinated output tamper not observed")
        page.write_bytes(altered_page)
        value = read(manifest)
        value["output_sha256"]["api/" + contour["native_page"]] = sha(altered_page)
        write(manifest, value)
        require(read(manifest)["output_sha256"]["api/" + contour["native_page"]] == sha(regular(page)),
                "rewritten manifest authorization not observed")
        try:
            try:
                verify()
            except ValueError as exc:
                report["mutations"].append({"name": "coordinated output and manifest authorization forgery",
                                            "observed": True, "rejection": str(exc)})
            else:
                raise AssertionError("rewritten manifest authorized tampering")
        finally:
            page.write_bytes(original_page)
            manifest.write_bytes(original_manifest)
        require(file_hashes(site) == original, "coordinated mutation restoration differs")
        verify()
        mutation("nondeterministic generated asset", site / "api/gnatdoc-navigation.js", lambda b: b + b"/* random */")
        unexpected = site / "unexpected.html"
        unexpected.write_text("unapproved")
        require(unexpected.is_file(), "unexpected file not observed")
        try:
            try:
                verify()
            except ValueError as exc:
                report["mutations"].append({"name": "unexpected generated file", "observed": True,
                                            "rejection": str(exc)})
            else:
                raise AssertionError("unexpected file accepted")
        finally:
            unexpected.unlink()
        verify()
        symlink = site / "escape"
        symlink.symlink_to(workspace.parent)
        require(symlink.is_symlink(), "symlink not observed")
        try:
            try:
                verify()
            except ValueError as exc:
                report["mutations"].append({"name": "invalid symlink", "observed": True, "rejection": str(exc)})
            else:
                raise AssertionError("symlink accepted")
        finally:
            symlink.unlink()
        verify()
        mutation("path traversal in dependency configuration", root / CONFIG,
                 lambda b: b.replace(b'source = "dependency/source"', b'source = "../outside"'))
        # Failed enhancement must preserve every byte of its pristine caller-owned tree.
        with tempfile.TemporaryDirectory(prefix="geometry-negative-") as directory:
            staging = Path(directory) / "native"
            shutil.copytree(workspace / "pristine-first", staging)
            (staging / "unexpected.html").write_text("partial publication probe")
            initial = file_hashes(staging)
            try:
                enhance(load(root, CONFIG), staging)
            except ValueError as exc:
                require(file_hashes(staging) == initial, "partial publication after failed enhancement")
                report["mutations"].append({"name": "partial publication after failed enhancement",
                                            "observed": True, "rejection": str(exc), "restored": True})
            else:
                raise AssertionError("unexpected pristine input accepted")
        # Verify installed-module comparison independently, without altering the real installation.
        with tempfile.TemporaryDirectory(prefix="geometry-tool-negative-") as directory:
            package = Path(directory) / "ada_gnatdoc_enhancer"
            dist = importlib.metadata.distribution("ada-gnatdoc-enhancer")
            shutil.copytree(Path(dist.locate_file("ada_gnatdoc_enhancer")), package)
            asset = next(package.rglob("gnatdoc-navigation.js"))
            asset.write_bytes(regular(asset) + b"/* modified installed asset */")
            require(asset.read_bytes().endswith(b"/* modified installed asset */"), "installed mutation not observed")
            class AlteredDistribution:
                def read_text(self, name):
                    return dist.read_text(name)
                def locate_file(self, name):
                    return package
            with patch("importlib.metadata.distribution", return_value=AlteredDistribution()):
                try:
                    provenance(enhancer)
                except ValueError as exc:
                    report["mutations"].append({"name": "modified installed asset", "observed": True,
                                                "rejection": str(exc)})
                else:
                    raise AssertionError("modified installed asset accepted")
        with tempfile.TemporaryDirectory(prefix="geometry-tool-commit-") as directory:
            clone = Path(directory) / "enhancer"
            s = Session(Path(directory))
            s.clone(enhancer, "53a321915da2c5a02a54581040673b61f8595b25", clone)
            require(subprocess.check_output(["git", "-C", str(clone), "rev-parse", "HEAD"]).decode().strip()
                    != ENHANCER, "old enhancer substitution not observed")
            try:
                provenance(clone)
            except ValueError as exc:
                report["mutations"].append({"name": "old/wrong enhancer commit", "observed": True,
                                            "rejection": str(exc)})
            else:
                raise AssertionError("old enhancer accepted")
        # Actual Alire resolution rejects a browser fixture path, independent of config checks.
        fake = workspace / "not-core"
        fake.mkdir()
        try:
            try:
                resolved_core(Session(fake), workspace / "source", fake)
            except ValueError as exc:
                report["mutations"].append({"name": "incorrect Alire resolution", "observed": fake.is_dir(),
                                            "rejection": str(exc)})
            else:
                raise AssertionError("wrong Alire resolution accepted")
        finally:
            shutil.rmtree(fake)
        require(file_hashes(site) == original, "final adversarial restoration differs")
        verify()
        report.update({"status": "pass", "executed": len(report["mutations"]),
                       "restored_and_verified": True, "restored_shadow_sha256": original})
    except Exception as exc:
        report["failure"] = str(exc)
        raise
    finally:
        write(workspace / "negative.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=lambda p: Path(p).absolute())
    parser.add_argument("--enhancer", required=True, type=lambda p: Path(p).absolute())
    args = parser.parse_args()
    qualify(args.workspace, args.enhancer)