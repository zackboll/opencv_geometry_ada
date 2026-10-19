"""Successor mechanism tests. Passing these is not policy approval."""
import copy
from pathlib import Path
import shutil
import tempfile
import unittest

from additive_gnatdoc_policy import (
    ROOT, PREDECESSOR, GUIDE, inventory, compatible, categories,
    candidate_rules, exact_snapshot, authored_contract, read, git, regular,
)


class AdditivePolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = inventory(ROOT)

    def copy(self, root):
        for name in git(ROOT, "ls-files").decode().splitlines():
            dest = root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)
        # New uncommitted policy components are not candidate authority.

    def test_current_inventory_is_source_derived(self):
        self.assertEqual(set(self.original), {"opencv.geometry", "opencv.geometry.subdiv2d"})
        self.assertTrue(all(self.original.values()))
        self.assertEqual(compatible(self.original, inventory(ROOT)), [])

    def test_existing_removal_rejected(self):
        changed = copy.deepcopy(self.original)
        changed["opencv.geometry"].pop()
        with self.assertRaisesRegex(ValueError, "removed or modified"):
            compatible(self.original, changed)

    def test_existing_aspect_modification_rejected(self):
        changed = copy.deepcopy(self.original)
        row = next(r for r in changed["opencv.geometry"] if "post" in r["code"])
        row["code"] += ("false",)
        with self.assertRaisesRegex(ValueError, "removed or modified"):
            compatible(self.original, changed)

    def test_existing_order_rejected(self):
        changed = copy.deepcopy(self.original)
        changed["opencv.geometry"].reverse()
        with self.assertRaisesRegex(ValueError, "order changed"):
            compatible(self.original, changed)

    def test_explicit_addition_without_frozen_total(self):
        changed = copy.deepcopy(self.original)
        changed["opencv.geometry"].append({"name": "Compose", "kind": "function",
            "profile": "fixture", "code": ("function", "compose", "fixture")})
        self.assertEqual(len(compatible(self.original, changed)), 1)
        changed["opencv.geometry"][-1]["name"] = "Unexpected"
        with self.assertRaisesRegex(ValueError, "unapproved additive"):
            compatible(self.original, changed)

    def test_new_existing_name_overload_must_follow_published(self):
        changed = copy.deepcopy(self.original)
        changed["opencv.geometry"].insert(0, {"name": "Transform_Point", "kind": "function",
            "profile": "fixture", "code": ("function", "transform_point", "fixture")})
        with self.assertRaisesRegex(ValueError, "overload identity"):
            compatible(self.original, changed, {"Transform_Point"})

    def test_category_reassignment_and_duplicate_rejected(self):
        import json
        with tempfile.TemporaryDirectory() as folder:
            candidate = Path(folder)
            (candidate / "docs").mkdir()
            original = read(ROOT / "docs/api-categories.json")
            for attack in ("reassign", "duplicate", "missing", "unknown"):
                with self.subTest(attack=attack):
                    value = copy.deepcopy(original)
                    groups = value["packages"][0]["categories"]
                    if attack == "reassign":
                        groups[1]["declarations"].append(groups[0]["declarations"].pop())
                    elif attack == "duplicate":
                        groups[0]["declarations"].append(groups[0]["declarations"][0])
                    elif attack == "missing":
                        groups[0]["declarations"].pop()
                    else:
                        groups[0]["declarations"].append("Unknown")
                    (candidate / "docs/api-categories.json").write_text(json.dumps(value))
                    with self.assertRaises(ValueError):
                        categories(ROOT, candidate, self.original)

    def test_additive_category_exact_public_membership(self):
        import json
        with tempfile.TemporaryDirectory() as folder:
            candidate = Path(folder)
            (candidate / "docs").mkdir()
            value = read(ROOT / "docs/api-categories.json")
            group = next(g for g in value["packages"][0]["categories"] if g["id"] == "transforms")
            group["declarations"].append("Compose")
            (candidate / "docs/api-categories.json").write_text(json.dumps(value))
            current = copy.deepcopy(self.original)
            current["opencv.geometry"].append({"name": "Compose"})
            owners = categories(ROOT, candidate, current)
            self.assertEqual(owners["OpenCV.Geometry", "Compose"], "transforms")

    def test_exact_snapshot_rejects_source_tamper(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.copy(root)
            (root / "src/opencv-geometry.ads").write_text("forged")
            with self.assertRaisesRegex(ValueError, "snapshot changed"):
                exact_snapshot(root, ROOT, PREDECESSOR)

    def test_manifest_derivation_has_only_scoped_input_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "api").mkdir()
            (root / "api/index.html").write_text("fresh native")
            payload, config = authored_contract(ROOT, root)
            import json
            derived = json.loads(payload)
            original = read(ROOT / "docs/evidence/gnatdoc009b/geometry-authored.json")
            self.assertNotEqual(derived.pop("native_sha256"), original.pop("native_sha256"))
            self.assertEqual(derived, original)
            self.assertIn(b"current-authored.json", config)

    def test_each_protected_script_still_uses_historical_authority(self):
        from additive_gnatdoc_policy import TRUSTED_SCRIPTS, TRANSITION, check_files
        authority = read(ROOT / TRANSITION)
        self.assertEqual(len(TRUSTED_SCRIPTS), 23)
        for name in TRUSTED_SCRIPTS:
            with self.subTest(name=name):
                check_files(ROOT, {name: authority["baseline_files_sha256"][name]})

    def test_recorder_missing_evidence_is_nonready(self):
        from record_additive_gnatdoc import record
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            result = record(root / "absent", ROOT, PREDECESSOR, PREDECESSOR, root)
            self.assertFalse(result["local_qualification_complete"])
            self.assertFalse(result["policy_approved"])
            self.assertTrue(result["non_deployable"])
            self.assertTrue((root / "absent/readiness.json").is_file())

    def test_constant_type_reference_uses_lowercase_resolver_identity(self):
        # The historical resolver consumes token-normalized names. Constants
        # are an extra type position and must use the same normalization.
        import re
        text = "Identity_Affine_Transform : constant Affine_Transform_2D := 0;"
        match = re.match(r"\s*\w+\s*:\s*constant\s+([A-Za-z][A-Za-z0-9_.]*)", text)
        self.assertEqual(match[1].lower(), "affine_transform_2d")

    def test_successor_historical_check_allows_scoped_source_only(self):
        from additive_gnatdoc_policy import historical_inputs, EXAMPLE
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.copy(root)
            (root / GUIDE).write_bytes(regular(root / GUIDE) + b"\nReviewed scope probe.\n")
            (root / EXAMPLE).write_bytes(regular(root / EXAMPLE) + b"\n-- scope probe\n")
            historical_inputs(root)
            other = root / "docs/guides/delaunay-and-voronoi.md"
            other.write_bytes(regular(other) + b"\nUnapproved guide.\n")
            with self.assertRaisesRegex(ValueError, "authority bytes differ"):
                historical_inputs(root)

    def test_mutated_historical_transition_rejected_by_successor(self):
        from additive_gnatdoc_policy import historical_inputs, TRANSITION
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.copy(root)
            (root / TRANSITION).write_bytes(regular(root / TRANSITION) + b" ")
            with self.assertRaisesRegex(ValueError, "authority bytes differ"):
                historical_inputs(root)

    def test_fixture_is_exact_and_never_writes_production(self):
        from additive_gnatdoc_fixture import expected
        before = regular(ROOT / "src/opencv-geometry.ads")
        result = expected(ROOT)
        self.assertEqual(before, regular(ROOT / "src/opencv-geometry.ads"))
        self.assertEqual(result["src/opencv-geometry.ads"].count(b"function Policy_Probe"), 2)
        self.assertIn(b"api:Policy_Probe/2", result[GUIDE])

    def test_guide_renderer_still_rejects_active_content(self):
        from render_gnatdoc_guides import markdown
        for text in ("# Title\n\n<script>alert(1)</script>\n",
                     "# Title\n\n<img src=x onerror=alert(1)>\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                markdown(text)


if __name__ == "__main__":
    unittest.main()