"""Consumer trust-boundary unit tests; synthetic results never establish readiness."""
from pathlib import Path
import shutil
import tempfile
import unittest
import json

from qualify_shared_gnatdoc_shadow import (
    ROOT, TRANSITION, REVIEWED, EVIDENCE, CONFIG, git, check_files, trusted_inputs,
    registered_cases, aunit_results, staged_contract,
    TRUSTED_SCRIPTS,
)


class TrustTests(unittest.TestCase):
    def trust_copy(self, root):
        transition = json.loads((ROOT / TRANSITION).read_text())
        names = set(transition["baseline_files_sha256"]) | {TRANSITION, CONFIG}
        names.update(git(ROOT, "ls-tree", "-r", "--name-only", REVIEWED, "--",
                         "docs/evidence/gnatdoc009", EVIDENCE).decode().splitlines())
        for name in names:
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)

    def test_current_implementation_changes_do_not_rewrite_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.trust_copy(root)
            (root / "cpp/opencv_geometry_shim.cpp").write_text("legitimate future source")
            (root / "src/opencv-geometry.adb").write_text("legitimate future implementation")
            trusted_inputs(root)

    def test_each_trusted_verifier_dependency_change_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.trust_copy(root)
            for name in TRUSTED_SCRIPTS:
                with self.subTest(name=name):
                    target = root / name
                    original = target.read_bytes()
                    try:
                        target.write_bytes(original + b"\n# unapproved verifier change\n")
                        with self.assertRaisesRegex(ValueError, "authority bytes differ: " + name):
                            trusted_inputs(root)
                    finally:
                        target.write_bytes(original)
            trusted_inputs(root)

    def test_additional_current_test_registration_is_not_frozen(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.trust_copy(root)
            suite = root / "tests/src/contour_geometry_tests.adb"
            text = suite.read_text()
            text = text.replace("      return Result'Access;", """      Result.Add_Test
        (Caller.Create ("Future legitimate regression", C_ABI_Validation'Access));
      return Result'Access;""", 1)
            suite.write_text(text)
            trusted_inputs(root)
            self.assertEqual(len(registered_cases(root)), len(registered_cases(ROOT)) + 1)

    def test_historical_ledger_and_reviewed_results_are_immutable(self):
        for name in ("docs/evidence/gnatdoc009/type-link-occurrences.json",
                     EVIDENCE + "/qualified/readiness.json"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                self.trust_copy(root)
                (root / name).write_text("forged historical evidence")
                with self.assertRaisesRegex(ValueError, "historical evidence"):
                    trusted_inputs(root)

    def test_authored_guides_remain_immutable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.trust_copy(root)
            (root / "docs/guides/delaunay-and-voronoi.md").write_text("tamper")
            with self.assertRaisesRegex(ValueError, "authority bytes"):
                trusted_inputs(root)

    def test_current_registrations_and_executed_cases(self):
        cases = registered_cases(ROOT)
        self.assertGreaterEqual(len(cases), 542)
        count = str(len(cases))
        output = "\n".join("OK " + case for case in cases) + (
            f"\nTotal Tests Run: {count}\nSuccessful Tests: {count}\n"
            "Failed Assertions: 0\nUnexpected Errors: 0\n")
        self.assertEqual(aunit_results(ROOT, output)["registered"], len(cases))
        for bad in (output.replace(count, str(len(cases) - 1)), output.replace("OK " + cases[0], "FAIL " + cases[0]),
                    output.replace("Unexpected Errors: 0", "Unexpected Errors: 1"),
                    output + f"Total Tests Run: {count}\n"):
            with self.assertRaises(ValueError):
                aunit_results(ROOT, bad)

    def test_run_local_contract_only_rebinds_native_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            pristine = Path(directory)
            (pristine / "api").mkdir()
            (pristine / "api/index.html").write_text("independent native output")
            payload, config = staged_contract(ROOT, pristine)
            current = json.loads(payload)
            history = json.loads((ROOT / EVIDENCE / "geometry-authored.json").read_text())
            self.assertNotEqual(current.pop("native_sha256"), history.pop("native_sha256"))
            self.assertEqual(current, history)
            self.assertIn(b'current-authored.json', config)

    def test_reviewed_contracts_and_baseline(self):
        transition = trusted_inputs()
        self.assertEqual(transition["historical_classification"]["BLOCKED-source-backed-reference-lost"], 1)

    def test_path_traversal_rejected(self):
        with self.assertRaisesRegex(ValueError, "path traversal"):
            check_files(ROOT, {"../outside": "0" * 64})

    def test_missing_transition_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "missing file"):
                trusted_inputs(Path(directory))

    def test_modified_transition_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / TRANSITION
            target.parent.mkdir(parents=True)
            shutil.copyfile(ROOT / TRANSITION, target)
            target.write_bytes(target.read_bytes() + b" ")
            with self.assertRaisesRegex(ValueError, "transition digest"):
                trusted_inputs(root)

    def test_readiness_missing_evidence_fails_closed(self):
        from record_shared_gnatdoc_shadow import record
        with tempfile.TemporaryDirectory() as directory:
            result = record(Path(directory))
            self.assertFalse(result["full_shadow_qualification"])
            self.assertEqual(result["disposition"], "PARTIAL_SHADOW_COMPATIBILITY")

    def test_readiness_records_early_failure_in_new_workspace(self):
        from record_shared_gnatdoc_shadow import record
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "not-created-yet"
            self.assertFalse(record(root)["full_shadow_qualification"])
            self.assertTrue((root / "readiness.json").is_file())

    def test_historical_blocked_report_cannot_qualify_new_enhancer(self):
        from record_shared_gnatdoc_shadow import record
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copyfile(ROOT / "docs/evidence/gnatdoc009/report.json", root / "qualification.json")
            self.assertFalse(record(root)["full_shadow_qualification"])

    def test_duplicate_authority_keys_rejected(self):
        from qualify_shared_gnatdoc_shadow import read
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "duplicate.json"
            target.write_text('{"revision":"old","revision":"new"}')
            with self.assertRaisesRegex(ValueError, "duplicate"):
                read(target)

    def test_history_occurrence_classification_is_still_blocked(self):
        report = json.loads((ROOT / "docs/evidence/gnatdoc009/report.json").read_text())
        self.assertEqual(report["classification_counts"], {
            "equivalent-verified-native-destination": 262, "shared-only-reference": 4,
            "BLOCKED-source-backed-reference-lost": 1})


if __name__ == "__main__":
    unittest.main()