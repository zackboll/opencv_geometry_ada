"""Consumer trust-boundary unit tests; synthetic results never establish readiness."""
from pathlib import Path
import shutil
import tempfile
import unittest
import json

from qualify_shared_gnatdoc_shadow import ROOT, TRANSITION, check_files, trusted_inputs


class TrustTests(unittest.TestCase):
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