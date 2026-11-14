#!/usr/bin/env python3
"""Execute old-policy negative tests against proposed modules, without privileges.

The test bytes and runner are base-owned. Candidate tests are supplementary,
never the only challenge to replacement verification code.
"""
import argparse
import importlib.util
from pathlib import Path
import sys
import unittest
import tempfile
from unittest.mock import patch

def challenge(candidate, policy):
    # Fixture construction belongs to the selected runner, not candidate modules.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from gnatdoc_test_fixtures import legacy_policy
    sys.path.insert(0, str(candidate / "scripts"))
    temporary = tempfile.TemporaryDirectory(prefix="baseline-migration-inputs-")
    legacy = legacy_policy(candidate, Path(temporary.name) / "legacy")
    suite = unittest.TestSuite()
    for name in ("test_gnatdoc_migration_policy", "test_additive_gnatdoc_policy",
                 "test_native_core_policy", "test_select_gnatdoc_policy"):
        spec = importlib.util.spec_from_file_location("independent_" + name,
                                                     policy / "scripts" / (name + ".py"))
        module = importlib.util.module_from_spec(spec)
        # Match normal import semantics: baseline fixtures patch module-local
        # inputs by __name__, which must resolve to this exact loaded module.
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        if hasattr(module, "ROOT"):
            # Old tests must construct their candidate fixtures from the exact
            # proposed tree, rather than inadvertently cloning the old base.
            module.ROOT = legacy if name == "test_gnatdoc_migration_policy" else candidate
        tests = unittest.defaultTestLoader.loadTestsFromModule(module)
        if name == "test_gnatdoc_migration_policy":
            class LegacyInputs(unittest.TestSuite):
                def run(self, result, debug=False):
                    with patch("additive_gnatdoc_policy.ROOT", legacy):
                        return super().run(result, debug)
            tests = LegacyInputs(tests)
        suite.addTests(tests)
    try:
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return result.wasSuccessful() and not result.skipped
    finally:
        temporary.cleanup()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--policy", type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(0 if challenge(args.candidate, args.policy) else 1)