#!/usr/bin/env python3
"""Opt-in Task 026 driver for the standalone upstream reproducers.

Not used by alr, AUnit or CI. Reuses run_risk_reassessment.py for process
isolation (own process group, hard timeout, core dumps off, bounded output,
identity parsing). The C++ reproducers under
tests/native/research/upstream_reproducers/ do not depend on this script.

  build     compile every reproducer against one OpenCV prefix
  run       run each case in its own child and print one JSON line per case
  self-test check classification and identity logic without OpenCV

A run is valid evidence only when the compile and runtime versions agree and
the library that defines the function under test lies under the intended
prefix (or is the system library when no --prefix is given). Linux only.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_risk_reassessment as base  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "tests" / "native" / "research" / "upstream_reproducers"
REPRODUCERS = {
    "a": ("repro_a_min_enclosing_triangle_signed_zero.cpp",
          ("control_square", "control_triangle", "signed_zero")),
    "b": ("repro_b_min_enclosing_triangle_non_return.cpp",
          ("square_1", "square_1e-1", "square_1e-3", "square_1e-5",
           "int_square", "int_hang")),
    "c": ("repro_c_approx_poly_n_enclosure.cpp",
          ("control_square_4", "unit_square")),
    "d": ("repro_d_min_enclosing_convex_polygon.cpp",
          ("unit_square_4", "unit_square_3")),
}


def all_cases():
    return [(key, case) for key, (_, cases) in REPRODUCERS.items()
            for case in cases]


def object_in_prefix(identity, prefix):
    """True if the defining library is under prefix/lib, or, when prefix is
    None, under a system library directory."""
    obj = identity.get("object", "")
    if prefix is None:
        return obj.startswith(("/lib/", "/usr/lib/"))
    return obj.startswith(str(Path(prefix).resolve() / "lib") + "/")


def build(args):
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    for key, (name, _) in REPRODUCERS.items():
        cmd = ["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-O1",
               "-g", "-o", str(out / ("repro_" + key)), str(DIR / name)]
        if args.prefix:
            prefix = Path(args.prefix)
            incs = sorted(p for p in (prefix / "include").iterdir()
                          if (p / "opencv2").is_dir())
            if not incs:
                raise SystemExit("no include/*/opencv2 under %s" % prefix)
            cmd += ["-I%s" % incs[0], "-L%s" % (prefix / "lib"),
                    "-Wl,-rpath,%s" % (prefix / "lib")]
        else:
            cmd += ["-I/usr/include/opencv4"]
        cmd += args.extra_flags
        cmd += ["-lopencv_" + args.backend, "-lopencv_core", "-ldl"]
        subprocess.run(cmd, check=True)


def run(args):
    out = Path(args.probes).resolve()
    libs = str(Path(args.prefix).resolve() / "lib") if args.prefix else ""
    selected = args.case or ["%s:%s" % kc for kc in all_cases()]
    results = []
    for item in selected:
        key, case = item.split(":", 1)
        r = base.run_case(str(out / ("repro_" + key)), case, libs,
                          args.timeout, stderr_limit=args.stderr_limit)
        r["reproducer"] = key
        r["identity"] = base.parse_identity(r["stdout"])
        r["library_ok"] = object_in_prefix(r["identity"], args.prefix)
        r["valid_evidence"] = r["identity"]["valid"] and r["library_ok"]
        if len(r["stdout"]) > args.stdout_keep:
            r["stdout"] = r["stdout"][:args.stdout_keep] + "...[cut]"
        results.append(r)
        print(json.dumps(r, sort_keys=True))
    bad = [r["reproducer"] + ":" + r["case"] for r in results
           if not r["valid_evidence"]]
    if bad:
        print("INVALID EVIDENCE: " + ", ".join(bad), file=sys.stderr)
        return 2
    return 0


class SelfTests(unittest.TestCase):
    def test_sources_exist_and_name_every_case(self):
        for _, (name, cases) in REPRODUCERS.items():
            text = (DIR / name).read_text()
            for case in cases:
                self.assertIn('"%s"' % case, text)

    def test_reproducers_are_standalone(self):
        for _, (name, _) in REPRODUCERS.items():
            text = (DIR / name).read_text()
            self.assertNotIn("precomp.hpp", text)
            self.assertNotIn("opencv_geometry_", text)
            self.assertNotIn("run_risk_reassessment", text)
            self.assertIn("#include <opencv2/core.hpp>", text)

    def test_object_in_prefix(self):
        ident = {"object": "/opt/x/lib/libopencv_imgproc.so.412"}
        self.assertTrue(object_in_prefix(ident, "/opt/x"))
        self.assertFalse(object_in_prefix(ident, "/opt/y"))
        self.assertFalse(object_in_prefix(ident, None))
        sysid = {"object": "/lib/x86_64-linux-gnu/libopencv_imgproc.so.410"}
        self.assertTrue(object_in_prefix(sysid, None))
        self.assertFalse(object_in_prefix({}, None))

    def test_prefix_is_not_a_string_prefix_match(self):
        ident = {"object": "/opt/x/lib2/libopencv_imgproc.so"}
        self.assertFalse(object_in_prefix(ident, "/opt/x"))

    def test_timeout_child_is_killed(self):
        hang = base.run_case("/bin/sleep", "30", "", 0.5)
        self.assertEqual(hang["outcome"], "timeout")
        self.assertLess(hang["seconds"], 5)

    def test_signal_classification(self):
        self.assertEqual(base.classify(-8, False), "signal_SIGFPE")
        self.assertEqual(base.classify(-11, False), "signal_SIGSEGV")
        self.assertEqual(base.classify(1, False), "exit_1")
        self.assertEqual(base.classify(13, False), "not_applicable")
        self.assertEqual(base.classify(10, False), "cv_exception")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build")
    b.add_argument("--prefix")
    b.add_argument("--output", required=True)
    b.add_argument("--backend", choices=("imgproc", "geometry"),
                   required=True)
    b.add_argument("--extra-flag", action="append", default=[],
                   dest="extra_flags",
                   help="compiler flag, repeatable: --extra-flag=-fsanitize=address")
    r = sub.add_parser("run")
    r.add_argument("--probes", required=True)
    r.add_argument("--prefix")
    r.add_argument("--timeout", type=float, default=10.0)
    r.add_argument("--case", action="append",
                   help="reproducer:case, e.g. a:signed_zero")
    r.add_argument("--stderr-limit", type=int, default=4096)
    r.add_argument("--stdout-keep", type=int, default=4000)
    sub.add_parser("self-test")
    args = p.parse_args()
    if args.command == "build":
        build(args)
        return 0
    if args.command == "run":
        return run(args)
    res = unittest.TextTestRunner(verbosity=1).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(SelfTests))
    return 0 if res.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
