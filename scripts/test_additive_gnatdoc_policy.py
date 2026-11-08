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
            for attack in ("reassign", "duplicate", "missing", "unknown", "wrong-package"):
                with self.subTest(attack=attack):
                    value = copy.deepcopy(original)
                    groups = value["packages"][0]["categories"]
                    if attack == "reassign":
                        groups[1]["declarations"].append(groups[0]["declarations"].pop())
                    elif attack == "duplicate":
                        groups[0]["declarations"].append(groups[0]["declarations"][0])
                    elif attack == "missing":
                        groups[0]["declarations"].pop()
                    elif attack == "wrong-package":
                        value["packages"][1]["categories"][0]["declarations"].append(
                            groups[0]["declarations"].pop())
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
            name = "Documentation_Category_Probe"
            self.assertNotIn(name.lower(), {r["name"].lower()
                             for rows in self.original.values() for r in rows})
            self.assertNotIn(name.lower(), {n.lower() for p in value["packages"]
                             for g in p["categories"] for n in g["declarations"]})
            group["declarations"].append(name)
            (candidate / "docs/api-categories.json").write_text(json.dumps(value))
            shutil.copytree(ROOT / "src", candidate / "src")
            spec = candidate / "src/opencv-geometry.ads"
            original = spec.read_text()
            marker = "end OpenCV.Geometry;"
            self.assertEqual(original.count(marker), 1)
            spec.write_text(original.replace(marker,
                f"--  Controlled documentation category fixture.\n"
                f"--  @return True for the fixture.\n"
                f"function {name} return Boolean;\n\n" + marker))
            current = inventory(candidate)
            added = compatible(self.original, current, {name})
            self.assertEqual([(row["package"], row["name"]) for row in added],
                             [("opencv.geometry", name)])
            owners = categories(ROOT, candidate, current)
            self.assertEqual(owners["OpenCV.Geometry", name], "transforms")
            self.assertEqual(set(owners) - set(categories(ROOT, ROOT, self.original)),
                             {("OpenCV.Geometry", name)})

    def test_exact_snapshot_rejects_source_tamper(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.copy(root)
            (root / "src/opencv-geometry.ads").write_text("forged")
            with self.assertRaisesRegex(ValueError, "snapshot changed"):
                exact_snapshot(root, ROOT, PREDECESSOR)

    def test_manifest_derivation_has_only_scoped_input_changes(self):
        from additive_gnatdoc_policy import EVOLVING_AUTHORED, sha, file_hashes
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "api").mkdir()
            (root / "api/index.html").write_text("fresh native")
            payload, config = authored_contract(ROOT, root)
            import json
            derived = json.loads(payload)
            original = read(ROOT / "docs/evidence/gnatdoc009b/geometry-authored.json")
            self.assertEqual(derived["native_sha256"], file_hashes(root))
            self.assertNotEqual(derived.pop("native_sha256"), original.pop("native_sha256"))
            for name in EVOLVING_AUTHORED:
                self.assertEqual(derived["inputs"].pop(name), sha(regular(ROOT / name)))
                original["inputs"].pop(name)
            self.assertEqual(derived, original)
            self.assertIn(b"current-authored.json", config)

    def test_each_protected_script_still_uses_historical_authority(self):
        from additive_gnatdoc_policy import TRUSTED_SCRIPTS, TRANSITION, check_files, BASE
        authority = read(ROOT / TRANSITION)
        self.assertEqual(len(TRUSTED_SCRIPTS), 23)
        for name in TRUSTED_SCRIPTS:
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory() as folder:
                    root = Path(folder)
                    target = root / name
                    target.parent.mkdir(parents=True)
                    target.write_bytes(git(ROOT, "show", f"{BASE}:{name}"))
                    expected = {name: authority["baseline_files_sha256"][name]}
                    check_files(root, expected)
                    target.write_bytes(target.read_bytes() + b"\n# unapproved\n")
                    with self.assertRaisesRegex(ValueError, "authority bytes differ"):
                        check_files(root, expected)

    def test_duplicate_overload_identity_rejected(self):
        changed = copy.deepcopy(self.original)
        row = next(r for r in changed["opencv.geometry"] if r["name"] == "Transform_Point")
        changed["opencv.geometry"].append(copy.deepcopy(row))
        with self.assertRaisesRegex(ValueError, "removed or modified"):
            compatible(self.original, changed)

    def test_current_contract_requires_exact_source_and_native_binding(self):
        import json
        import subprocess
        from additive_gnatdoc_policy import EVOLVING_AUTHORED, sha, file_hashes
        from gnatdoc_migration_policy import verify_current_commit
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source, native = root / "source", root / "native"
            subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(source)], check=True)
            revision = git(source, "rev-parse", "HEAD").decode().strip()
            exact_snapshot(source, ROOT, revision)
            verify_current_commit(source, revision)
            with self.assertRaisesRegex(ValueError, "stale/substituted"):
                verify_current_commit(source, PREDECESSOR)
            (native / "api").mkdir(parents=True)
            page = native / "api/index.html"
            page.write_text("controlled pristine native fixture")
            payload, config = authored_contract(source, native)
            expected = json.loads(payload)
            self.assertEqual(expected["native_sha256"], file_hashes(native))
            for name in sorted(EVOLVING_AUTHORED):
                with self.subTest(name=name):
                    path = source / name
                    original = path.read_bytes()
                    self.assertEqual(expected["inputs"][name], sha(original))
                    try:
                        path.write_bytes(original + b"\nUnauthorized content\n")
                        with self.assertRaisesRegex(ValueError, "snapshot changed"):
                            exact_snapshot(source, ROOT, revision)
                        self.assertNotEqual(authored_contract(source, native)[0], payload)
                        path.unlink()
                        substitute = root / "substitute"
                        substitute.write_bytes(original)
                        path.symlink_to(substitute)
                        with self.assertRaises(ValueError):
                            authored_contract(source, native)
                    finally:
                        if path.is_symlink():
                            path.unlink()
                        path.write_bytes(original)
                    exact_snapshot(source, ROOT, revision)
            page.write_text("incorrect native binding")
            rebound, rebound_config = authored_contract(source, native)
            self.assertNotEqual(rebound, payload)
            self.assertNotEqual(rebound_config, config)
            self.assertNotEqual(json.loads(rebound)["native_sha256"], expected["native_sha256"])
            # The derivation is not authorization: exact snapshot checks above and
            # qualify_additive_gnatdoc.verify's reconstructed-native check are mandatory.

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

    def test_attack_harness_rejects_unrelated_subprocess_failure(self):
        import subprocess
        from adversarial_additive_gnatdoc import expected_rejection
        for error in (subprocess.CalledProcessError(128, ["git", "status"]),
                      OSError("disk full"), ValueError("native generator failed")):
            with self.subTest(error=error), self.assertRaisesRegex(ValueError, "unrelated rejection"):
                expected_rejection(error, ("stale/substituted candidate commit",))
        self.assertEqual(expected_rejection(ValueError("stale/substituted candidate commit"),
                                           ("stale/substituted candidate commit",)),
                         "stale/substituted candidate commit")


class TrustedInputTests(unittest.TestCase):
    # Separate real disposable Git checkout; no candidate package manager runs.
    def setUp(self):
        import subprocess
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.candidate = Path(self.temp.name) / "candidate"
        subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(self.candidate)], check=True)
        AdditivePolicyTests.copy(self, self.candidate)

    def validate(self):
        return candidate_rules(ROOT, self.candidate)

    def test_unchanged_build_inputs_accepted(self):
        self.validate()

    def test_reviewed_version_only_release_accepted(self):
        from unittest.mock import patch
        import subprocess
        reviewed = Path(self.temp.name) / "reviewed"
        subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(reviewed)], check=True)
        AdditivePolicyTests.copy(self, reviewed)
        path = reviewed / "alire.toml"
        path.write_bytes(path.read_bytes().replace(b'0.3.3', b'0.3.2'))
        with patch("additive_gnatdoc_policy.ROOT", reviewed):
            self.validate()
        self.assertEqual((self.candidate / "alire.toml").read_bytes(), regular(ROOT / "alire.toml"))

    def test_substituted_requirements_symlink_rejected_and_restored(self):
        path = self.candidate / "docs/requirements.txt"
        original = path.read_bytes()
        before = self.validate()
        replacement = Path(self.temp.name) / "replacement.txt"
        replacement.write_bytes(original)
        try:
            path.unlink()
            path.symlink_to(replacement)
            with self.assertRaisesRegex(ValueError, "trusted build input is substituted: docs/requirements.txt"):
                self.validate()
        finally:
            path.unlink()
            path.write_bytes(original)
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(self.validate(), before)

    def test_only_exact_temporary_qualification_pins_accepted(self):
        from validate_gnatdoc_inputs import PINS
        originals = {name: (self.candidate / name).read_bytes() for name in PINS}
        before = self.validate()
        try:
            for name, pin in PINS.items():
                (self.candidate / name).write_bytes(originals[name] +
                    ("\n[[pins]]\nopencv_core = { path='" + pin + "' }\n").encode())
            self.assertEqual(candidate_rules(ROOT, self.candidate, qualification_pins=True), before)
            path = self.candidate / "alire.toml"
            pinned = path.read_bytes()
            path.write_bytes(pinned.replace(b"../core", b"../untrusted"))
            with self.assertRaisesRegex(ValueError, "qualification Core pin differs: alire.toml"):
                candidate_rules(ROOT, self.candidate, qualification_pins=True)
            path.write_bytes(pinned)
        finally:
            for name, original in originals.items():
                (self.candidate / name).write_bytes(original)
        self.assertTrue(all((self.candidate / n).read_bytes() == b for n, b in originals.items()))
        self.assertEqual(self.validate(), before)

    def test_production_bootstrap_preflight_before_execution(self):
        import os
        import subprocess
        import textwrap
        base = "aad0b1b65814ac472bf5a9ea1b266f47aa3baf06"
        policy = Path(self.temp.name) / "build-policy"
        subprocess.run(["git", "clone", "--quiet", "--shared", str(ROOT), str(policy)], check=True)
        subprocess.run(["git", "-C", str(policy), "checkout", "--quiet", "--detach", base], check=True)
        workflow = regular(ROOT / ".github/workflows/documentation.yml").decode()
        step = workflow.split("      - name: Preflight before candidate dependency installation or Alire actions\n", 1)[1]
        shell = textwrap.dedent(step.split("        run: |\n", 1)[1].split("      - name:", 1)[0])
        env = {**os.environ, "GITHUB_EVENT_NAME": "pull_request",
               "GITHUB_WORKSPACE": self.temp.name,
               "CANDIDATE_SHA": git(self.candidate, "rev-parse", "HEAD").decode().strip()}
        def run():
            return subprocess.run(["bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", shell],
                                  cwd=self.candidate, env=env, capture_output=True, text=True)
        # The script refers to geometry in the workspace, as Actions does.
        geometry = Path(self.temp.name) / "geometry"
        self.candidate.rename(geometry)
        self.candidate = geometry
        self.assertEqual(run().returncode, 0)
        for name, new in (("docs/requirements.txt", b"--index-url https://untrusted.invalid/\n"),
                          ("alire.toml", b'\n[[actions]]\ntype="pre-build"\ncommand=["false"]\n')):
            with self.subTest(name=name):
                path = geometry / name
                original = path.read_bytes()
                try:
                    path.write_bytes(original + new)
                    result = run()
                    self.assertEqual(result.returncode, 1)
                    self.assertIn(name, result.stdout + result.stderr)
                    self.assertTrue("differ" in result.stdout or "EOF" in result.stderr)
                finally:
                    path.write_bytes(original)
                self.assertEqual(path.read_bytes(), original)
                self.assertEqual(run().returncode, 0)
        preflight_position = workflow.index("Preflight before candidate")
        self.assertLess(preflight_position, workflow.index("alr -n pin"))
        self.assertLess(preflight_position, workflow.index("pip install -r"))
        self.assertIn("pip install -r ../build-policy/docs/requirements.txt", workflow)


def input_test(attack):
    def test(self):
        from gnatdoc_input_mutations import observe
        result = observe(self.candidate, self.validate, attack)
        self.assertTrue(result["restored_and_verified"])
    return test


from gnatdoc_input_mutations import ATTACKS
for _attack in ATTACKS:
    setattr(TrustedInputTests, "test_reject_" + _attack[0], input_test(_attack))


if __name__ == "__main__":
    unittest.main()