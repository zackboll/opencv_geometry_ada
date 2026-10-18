"""Consumer trust-boundary unit tests; synthetic results never establish readiness."""
from pathlib import Path
import shutil
import tempfile
import unittest

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


if __name__ == "__main__":
    unittest.main()