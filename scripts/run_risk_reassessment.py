#!/usr/bin/env python3
"""Opt-in Task 025 research runner. Not used by alr, AUnit or CI.

build: compile tests/native/research/risk_reassessment_probe.cpp against one
       OpenCV prefix (or the system install with --system).
run:   run every named case in its own child process with a hard wall-time
       limit, process-group kill, no core dumps, bounded output and an
       explicit loaded-library identity. Prints one JSON line per case.
self-test: checks classification logic without OpenCV.

A timeout is research protection, never a liveness contract.
Linux, Python 3.9+, standard library only.
"""
import argparse
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tests" / "native" / "research" / "risk_reassessment_probe.cpp"
CASES = (
    "apn_unit_square_3", "apn_unit_square_4", "apn_pentagon_3",
    "apn_pentagon_4", "apn_octagon_r10_4", "apn_circle16_r100_6",
    "apn_square_2e-6_pent",
    "met32_unit_square", "met32_pentagon", "met32_ngon32_r100",
    "met32_square_1e-1", "met32_square_1e-3", "met32_square_1e-5",
    "met32_square_1e-6", "met32_square_1e3", "met32_ngon32_r1e-4",
    "met32_thin_sliver", "met_i32_hang_a", "met_i32_unit_square",
    "met32_signed_zero", "met32_signed_zero_tri",
    "ict_triangles_0p1", "ict_ngon62_61_r1000", "ict_ngon62_61_r1",
    "ict_ngon_grid_p2",
)
EXIT_NAMES = {0: "returned", 10: "cv_exception", 11: "std_exception",
              12: "other_exception", 13: "not_applicable",
              64: "usage_error"}


def classify(returncode, timed_out):
    """Map a child's status to an outcome name."""
    if timed_out:
        return "timeout"
    if returncode < 0:
        return "signal_" + signal.Signals(-returncode).name
    return EXIT_NAMES.get(returncode, "exit_%d" % returncode)


def child_limits(output_bytes):
    def apply():
        os.setsid()
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_FSIZE, (output_bytes, output_bytes))
    return apply


def run_case(probe, case, env_libs, timeout, output_limit=1 << 20):
    env = {"PATH": "/usr/bin:/bin", "LD_LIBRARY_PATH": env_libs,
           "ASAN_OPTIONS": "detect_leaks=0:abort_on_error=1",
           "UBSAN_OPTIONS": "halt_on_error=1"}
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        start = time.monotonic()
        proc = subprocess.Popen([probe, case], stdout=out, stderr=err,
                                env=env, preexec_fn=child_limits(output_limit))
        timed_out = False
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
        seconds = time.monotonic() - start
        out.seek(0)
        err.seek(0)
        stdout = out.read(output_limit).decode("utf-8", "replace")
        stderr = err.read(4096).decode("utf-8", "replace")
    return {"case": case, "outcome": classify(proc.returncode, timed_out),
            "returncode": proc.returncode, "seconds": round(seconds, 3),
            "stdout": stdout, "stderr": stderr}


def build(args):
    cmd = ["g++", "-std=c++17", "-O1", "-g", "-o", args.output, str(SOURCE)]
    if args.prefix:
        prefix = Path(args.prefix)
        incs = [p for p in (prefix / "include").iterdir() if p.is_dir()]
        libs = prefix / "lib"
        cmd += ["-I%s" % incs[0], "-L%s" % libs,
                "-Wl,-rpath,%s" % libs]
    else:
        cmd += ["-I/usr/include/opencv4"]
    major5 = args.backend == "geometry"
    cmd += ["-lopencv_geometry"] if major5 else ["-lopencv_imgproc"]
    cmd += ["-lopencv_core", "-ldl"]
    subprocess.run(cmd, check=True)


def run(args):
    results = []
    for case in (args.case or CASES):
        r = run_case(str(Path(args.probe).resolve()), case, "",
                     args.timeout)
        identity = [ln for ln in r["stdout"].splitlines()
                    if ln.startswith(("object ", "runtime "))]
        r["identity"] = identity
        results.append(r)
        print(json.dumps(r, sort_keys=True))
    if args.report:
        Path(args.report).write_text(
            "".join(json.dumps(r, sort_keys=True) + "\n" for r in results))
    return 0


class SelfTests(unittest.TestCase):
    def test_classify(self):
        self.assertEqual(classify(0, False), "returned")
        self.assertEqual(classify(10, False), "cv_exception")
        self.assertEqual(classify(-11, False), "signal_SIGSEGV")
        self.assertEqual(classify(-9, True), "timeout")
        self.assertEqual(classify(3, False), "exit_3")

    def test_cases_unique(self):
        self.assertEqual(len(CASES), len(set(CASES)))

    def test_source_names_every_case(self):
        text = SOURCE.read_text()
        for case in CASES:
            self.assertIn('"%s"' % case, text)

    def test_timeout_and_signal_children(self):
        sleeper = run_case("/bin/sleep", "30", "", 0.5)
        self.assertEqual(sleeper["outcome"], "timeout")
        self.assertLess(sleeper["seconds"], 5)
        crash = run_case("/bin/sh", "-c", "", 2)
        self.assertIn(crash["outcome"], ("returned", "exit_2", "exit_127"))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build")
    b.add_argument("--prefix")
    b.add_argument("--output", required=True)
    b.add_argument("--backend", choices=("imgproc", "geometry"),
                   required=True)
    r = sub.add_parser("run")
    r.add_argument("--probe", required=True)
    r.add_argument("--timeout", type=float, default=10.0)
    r.add_argument("--case", action="append")
    r.add_argument("--report")
    sub.add_parser("self-test")
    args = p.parse_args()
    if args.command == "build":
        build(args)
    elif args.command == "run":
        return run(args)
    else:
        res = unittest.TextTestRunner(verbosity=1).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(SelfTests))
        return 0 if res.wasSuccessful() else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())