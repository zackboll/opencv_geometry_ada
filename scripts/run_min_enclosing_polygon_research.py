#!/usr/bin/env python3
"""Opt-in research runner for cv::minEnclosingConvexPolygon.

Geometry does not bind minEnclosingConvexPolygon; see the Task 016 section
of docs/versioned-features-research.md. Nothing in the default build, the
AUnit suite, scripts/run_native_tests.sh or CI runs this script.

The runner never calls OpenCV itself. It builds
tests/native/research/min_enclosing_convex_polygon_probe.cpp against one
OpenCV installation, runs exactly one case per child process and classifies
each outcome:

  polygon             returned k vertices that pass every check below
  polygon_nonminimal  a valid polygon, but an enclosing competitor is
                      smaller, so it is provably not minimal
  polygon_invalid     a returned polygon failed a validity check
  empty               returned an empty polygon and area 0
  cv_exception        raised cv::Exception, contained by the probe
  std_exception, other_exception
  crash               a memory-safety failure: a fatal signal, an
                      AddressSanitizer or UndefinedBehaviorSanitizer report,
                      or a C++ library assertion
  timeout, output_limit, probe_error, identity_error

Children run with bounded concurrency, a wall-clock timeout that kills the
whole process group, no core dumps, and RLIMIT_FSIZE on their captured
output. LD_LIBRARY_PATH and LD_PRELOAD are removed, and every run checks
which loaded object defines cv::minEnclosingConvexPolygon.

Checks use exact rational arithmetic on the binary32 values: vertex count,
finiteness, convexity, enclosure of every input point, the reported area
against the exact area of the returned vertices, and that area against two
competitors. One is the smallest enclosing triangle whose sides lie on hull
edge lines (any k >= 3); the other is the minimum-area enclosing rectangle
(k >= 4). A cv::minEnclosingTriangle result, with --triangle-oracle, becomes
a third competitor only if its binary32 vertices exactly enclose the input.
A smaller competitor proves non-minimality, because the minimum area cannot
increase with k. A polygon no larger than every competitor proves nothing
about minimality. Tolerances are reporting heuristics, not contracts.

Subcommands: build, run, fuzz, freeze, self-test. Linux; Python 3.9+.
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import hashlib
import json
import math
import os
import re
import resource
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import urllib.parse
from fractions import Fraction
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Sequence, Tuple

REPOSITORY = Path(__file__).resolve().parent.parent
RESEARCH = REPOSITORY / "tests" / "native" / "research"
PROBE_SOURCE = RESEARCH / "min_enclosing_convex_polygon_probe.cpp"
STUB_DIRECTORY = RESEARCH / "stub"
DEFAULT_CORPUS = RESEARCH / "min_enclosing_convex_polygon_corpus.txt"

# Probe exit statuses; see the probe's header comment.
EXIT_RETURNED = 0
EXIT_EXCEPTIONS = {10: "cv_exception", 11: "std_exception",
                   12: "other_exception"}
PROBE_ERRORS = {64: "usage error", 65: "malformed input",
                66: "resource limit failure", 67: "probe failure"}

# Distinct sanitizer exit statuses, so that a report can never look like an
# ordinary probe exit. The first Task 016 ASan campaign under-counted
# crashes because ASan's default status 1 collided with a harness status.
ASAN_EXIT = 86
UBSAN_EXIT = 87
SANITIZER_OPTIONS = {
    "ASAN_OPTIONS": f"exitcode={ASAN_EXIT}:abort_on_error=0:detect_leaks=0",
    "UBSAN_OPTIONS": f"halt_on_error=1:exitcode={UBSAN_EXIT}"
                     ":print_stacktrace=1",
}

EXPECTABLE = ("polygon", "polygon_nonminimal", "polygon_invalid", "empty",
              "cv_exception", "crash")

# Reporting heuristics, not contracts.
RELATIVE_AREA_TOLERANCE = 1e-6
RELATIVE_ENCLOSURE_TOLERANCE = 1e-5
MAX_TRIANGLE_COMPETITOR_HULL = 64
# Bounds on one invocation; the probe accepts iterations up to MAX_ITERATION.
MAX_ITERATIONS_PER_SEED = 20000
MAX_FUZZ_JOBS = 200000
MAX_ITERATION = 1000000
MAX_PARALLEL = 64

Point = Tuple[Fraction, Fraction]


class ResearchError(Exception):
    """A configuration or input error that stops the runner."""


# --------------------------------------------------------------- corpus --

NAME_PATTERN = re.compile(r"[a-z0-9_]+\Z")
FAMILY_PATTERN = re.compile(r"[a-z0-9._-]+\Z")
POINT_PATTERN = re.compile(r"[0-9a-f]{8}:[0-9a-f]{8}\Z")
INTEGER_PATTERN = re.compile(r"-?[0-9]+\Z")


@dataclasses.dataclass
class Case:
    name: str
    line: int
    k: Optional[int] = None
    depth: str = "f32"
    origin: str = ""
    optimum: Optional[Fraction] = None
    optimum_reason: str = ""
    expect: Dict[str, str] = dataclasses.field(default_factory=dict)
    points: List[str] = dataclasses.field(default_factory=list)


def parse_corpus(text: str, source: str) -> List[Case]:
    """Parses the line-oriented corpus format described in its header."""
    cases: List[Case] = []
    by_name: Dict[str, Case] = {}
    current: Optional[Case] = None
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        keyword, _, rest = line.partition(" ")
        rest = rest.strip()
        where = f"{source}:{number}"
        if keyword == "case":
            if current is not None:
                raise ResearchError(f"{where}: {current.name} lacks end")
            if not NAME_PATTERN.match(rest) or rest in by_name:
                raise ResearchError(f"{where}: bad or duplicate name {rest!r}")
            current = Case(name=rest, line=number)
            continue
        if current is None:
            raise ResearchError(f"{where}: {keyword!r} outside a case")
        if keyword == "k":
            if not INTEGER_PATTERN.match(rest) or current.k is not None:
                raise ResearchError(f"{where}: bad or repeated k")
            current.k = int(rest)
            if not -2**31 <= current.k < 2**31:
                raise ResearchError(f"{where}: k is not a C int")
        elif keyword == "depth":
            if rest not in ("f32", "i32"):
                raise ResearchError(f"{where}: depth must be f32 or i32")
            current.depth = rest
        elif keyword == "origin":
            if not rest:
                raise ResearchError(f"{where}: empty origin")
            current.origin = (current.origin + " " + rest).strip()
        elif keyword == "optimum":
            value, _, reason = rest.partition(" ")
            try:
                current.optimum = Fraction(value)
            except ValueError as error:
                raise ResearchError(f"{where}: bad optimum") from error
            if not reason.strip():
                raise ResearchError(f"{where}: optimum needs a reason")
            current.optimum_reason = reason.strip()
        elif keyword == "expect":
            fields = rest.split()
            if (len(fields) != 2 or not FAMILY_PATTERN.match(fields[0])
                    or fields[1] not in EXPECTABLE
                    or fields[0] in current.expect):
                raise ResearchError(f"{where}: bad or repeated expect")
            current.expect[fields[0]] = fields[1]
        elif keyword == "points":
            for token in rest.split():
                if not POINT_PATTERN.match(token):
                    raise ResearchError(f"{where}: bad point {token!r}")
                current.points.append(token)
        elif keyword == "end":
            if current.k is None or not current.origin:
                raise ResearchError(f"{where}: {current.name} needs k and "
                                    "origin")
            cases.append(current)
            by_name[current.name] = current
            current = None
        else:
            raise ResearchError(f"{where}: unknown keyword {keyword!r}")
    if current is not None:
        raise ResearchError(f"{source}: {current.name} lacks end")
    return cases


def decode_binary32(bits: str) -> float:
    return struct.unpack(">f", bytes.fromhex(bits))[0]


def decode_binary64(bits: str) -> float:
    return struct.unpack(">d", bytes.fromhex(bits))[0]


def corpus_entry(name: str, origin: str, k: int, depth: str,
                 points: Sequence[str]) -> str:
    """Formats one corpus case, four points per line."""
    lines = [f"case {name}", f"origin {origin}", f"k {k}"]
    if depth != "f32":
        lines.append(f"depth {depth}")
    for first in range(0, len(points), 4):
        lines.append("points " + " ".join(points[first:first + 4]))
    lines.append("end")
    return "\n".join(lines) + "\n"


# ------------------------------------------------------- exact geometry --

def cross(o: Point, a: Point, b: Point) -> Fraction:
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def cross2(u: Point, v: Point) -> Fraction:
    return u[0] * v[1] - u[1] * v[0]


def twice_signed_area(polygon: Sequence[Point]) -> Fraction:
    total = Fraction(0)
    for index, a in enumerate(polygon):
        b = polygon[(index + 1) % len(polygon)]
        total += a[0] * b[1] - b[0] * a[1]
    return total


def convex_hull(points: Sequence[Point]) -> List[Point]:
    """Counterclockwise hull without collinear vertices (monotone chain)."""
    unique = sorted(set(points))
    if len(unique) <= 2:
        return unique
    lower: List[Point] = []
    for p in unique:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper: List[Point] = []
    for p in reversed(unique):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def flush_triangle_area(hull: Sequence[Point]) -> Optional[Fraction]:
    """Smallest enclosing triangle with sides on hull edge lines.

    For a counterclockwise hull, the left half-planes of three edge lines
    intersect in a bounded triangle containing the hull exactly when every
    turn between the three edge directions is less than half a turn.
    """
    count = len(hull)
    if count < 3:
        return None
    starts = list(hull)
    directions = [(hull[(i + 1) % count][0] - hull[i][0],
                   hull[(i + 1) % count][1] - hull[i][1])
                  for i in range(count)]
    turns = [[cross2(directions[i], directions[j]) for j in range(count)]
             for i in range(count)]
    corners: Dict[Tuple[int, int], Point] = {}

    def corner(i: int, j: int) -> Point:
        key = (i, j)
        if key not in corners:
            offset = (starts[j][0] - starts[i][0],
                      starts[j][1] - starts[i][1])
            t = cross2(offset, directions[j]) / turns[i][j]
            corners[key] = (starts[i][0] + t * directions[i][0],
                            starts[i][1] + t * directions[i][1])
        return corners[key]

    best: Optional[Fraction] = None
    for i in range(count):
        for j in range(i + 1, count):
            if turns[i][j] <= 0:
                continue
            for m in range(j + 1, count):
                if turns[j][m] <= 0 or turns[m][i] <= 0:
                    continue
                area = abs(cross(corner(i, j), corner(j, m),
                                 corner(m, i))) / 2
                if best is None or area < best:
                    best = area
    return best


def minimum_rectangle_area(hull: Sequence[Point]) -> Optional[Fraction]:
    """Exact minimum-area enclosing rectangle.

    Some minimum-area enclosing rectangle has a side on a hull edge
    (Freeman and Shapira, 1975), so trying every edge direction suffices.
    """
    count = len(hull)
    if count < 3:
        return None
    best: Optional[Fraction] = None
    for i in range(count):
        a = hull[i]
        b = hull[(i + 1) % count]
        d = (b[0] - a[0], b[1] - a[1])
        along = [(p[0] - a[0]) * d[0] + (p[1] - a[1]) * d[1] for p in hull]
        across = [cross2(d, (p[0] - a[0], p[1] - a[1])) for p in hull]
        area = ((max(along) - min(along)) * (max(across) - min(across))
                / (d[0] * d[0] + d[1] * d[1]))
        if best is None or area < best:
            best = area
    return best


@dataclasses.dataclass
class Enclosure:
    convex: bool
    collinear_vertices: int
    worst_outside: float


def check_enclosure(polygon: Sequence[Point],
                    hull: Sequence[Point]) -> Enclosure:
    """Convexity, and the worst edge half-plane violation by hull points."""
    orientation = twice_signed_area(polygon)
    sign = 1 if orientation > 0 else -1
    count = len(polygon)
    turns = [cross(polygon[i - 1], polygon[i], polygon[(i + 1) % count])
             * sign for i in range(count)]
    # All turns one way is not enough: a pentagram turns one way too.
    convex = (orientation != 0 and all(turn >= 0 for turn in turns)
              and abs(orientation)
              == abs(twice_signed_area(convex_hull(polygon))))
    worst = 0.0
    for i in range(count):
        a = polygon[i]
        b = polygon[(i + 1) % count]
        length2 = (b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2
        if length2 == 0:
            continue
        for q in hull:
            side = cross(a, b, q) * sign
            if side < 0:
                worst = max(worst, math.sqrt(float(side * side / length2)))
    return Enclosure(convex, sum(1 for turn in turns if turn == 0), worst)


def diameter(points: Sequence[Point]) -> float:
    xs = [float(p[0]) for p in points]
    ys = [float(p[1]) for p in points]
    return math.hypot(max(xs) - min(xs), max(ys) - min(ys))


# ---------------------------------------------------------- probe runs --

@dataclasses.dataclass
class Job:
    key: str
    arguments: List[str]
    stdin_text: str = ""
    case: Optional[Case] = None


@dataclasses.dataclass
class Finished:
    job: Job
    returncode: int
    timed_out: bool
    stdout: str
    stderr: str
    truncated: bool
    seconds: float


def child_environment() -> Dict[str, str]:
    environment = {key: value for key, value in os.environ.items()
                   if key not in ("LD_LIBRARY_PATH", "LD_PRELOAD")}
    environment.update(SANITIZER_OPTIONS)
    return environment


def read_limited(path: Path, limit: int) -> Tuple[str, bool]:
    with open(path, "rb") as stream:
        data = stream.read(limit + 1)
    return data[:limit].decode("utf-8", "replace"), len(data) > limit


def run_jobs(probe: Path, jobs: Sequence[Job], parallel: int,
             timeout: float, output_limit: int) -> Iterator[Finished]:
    """Runs each job in its own child process, at most parallel at once.

    No threads are used, so preexec_fn is safe. A child that outlives its
    timeout is killed together with its whole process group.
    """
    def limits() -> None:
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_FSIZE,
                           (output_limit, output_limit))

    environment = child_environment()
    pending = collections.deque(enumerate(jobs))
    running = []
    with tempfile.TemporaryDirectory(prefix="mecp-research-") as scratch:
        directory = Path(scratch)
        while pending or running:
            while pending and len(running) < parallel:
                index, job = pending.popleft()
                paths = [directory / f"{index}.{suffix}"
                         for suffix in ("in", "out", "err")]
                paths[0].write_text(job.stdin_text)
                with open(paths[0], "rb") as stdin, \
                        open(paths[1], "wb") as stdout, \
                        open(paths[2], "wb") as stderr:
                    start = time.monotonic()
                    process = subprocess.Popen(
                        [str(probe), *job.arguments], stdin=stdin,
                        stdout=stdout, stderr=stderr, env=environment,
                        preexec_fn=limits, start_new_session=True)
                running.append((process, job, start, paths))
            still_running = []
            for process, job, start, paths in running:
                returncode = process.poll()
                elapsed = time.monotonic() - start
                if returncode is None and elapsed < timeout:
                    still_running.append((process, job, start, paths))
                    continue
                timed_out = returncode is None
                if timed_out:
                    # The child is not yet reaped, so its process group
                    # still exists and cannot have been reused.
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    returncode = process.wait()
                stdout, cut_stdout = read_limited(paths[1], output_limit)
                stderr, cut_stderr = read_limited(paths[2], output_limit)
                for path in paths:
                    path.unlink()
                yield Finished(job, returncode, timed_out, stdout, stderr,
                               cut_stdout or cut_stderr, elapsed)
            running = still_running
            if running:
                time.sleep(0.002)


def parse_records(text: str) -> List[Tuple[str, Dict[str, str]]]:
    records = []
    for line in text.splitlines():
        fields = line.split(" ")
        if not fields[0]:
            continue
        values = {}
        for field in fields[1:]:
            key, separator, value = field.partition("=")
            if separator:
                values[key] = urllib.parse.unquote(value)
        records.append((fields[0], values))
    return records


def first_record(records, name: str) -> Optional[Dict[str, str]]:
    for record, values in records:
        if record == name:
            return values
    return None


def point_records(records, name: str) -> List[str]:
    return [f"{values['x']}:{values['y']}" for record, values in records
            if record == name]


ASAN_KIND = re.compile(r"ERROR: AddressSanitizer: ([\w-]+)")
ASAN_ACCESS = re.compile(r"(READ|WRITE) of size (\d+)")
ASAN_REGION = re.compile(r"located (\d+ bytes (?:before|after|inside) "
                         r"\d+-byte region)")
SANITIZER_FRAME = re.compile(r"^\s*#\d+ 0x[0-9a-f]+ in (.+?) (\S+:\d+)",
                             re.MULTILINE)
UBSAN_ERROR = re.compile(r"runtime error: (.+)")
LIBRARY_ASSERTION = re.compile(r"Assertion '(.+?)' failed")


def first_algorithm_frame(stderr: str) -> Optional[str]:
    for match in SANITIZER_FRAME.finditer(stderr):
        function = match.group(1)
        if not function.startswith(("std::", "__")):
            return f"{function} at {Path(match.group(2)).name}"
    return None


def signal_name(number: int) -> str:
    try:
        return signal.Signals(number).name
    except ValueError:
        return f"signal {number}"


@dataclasses.dataclass
class Outcome:
    kind: str
    detail: Dict[str, object]


def classify(finished: Finished, minimality: str,
             optimum: Optional[Fraction] = None) -> Outcome:
    """Classifies one finished child; see the module docstring."""
    code = finished.returncode
    stderr = finished.stderr
    records = parse_records(finished.stdout)
    detail: Dict[str, object] = {}
    if finished.timed_out:
        return Outcome("timeout", detail)
    if code < 0:
        detail["signal"] = signal_name(-code)
        if -code == signal.SIGXFSZ:
            return Outcome("output_limit", detail)
        assertion = LIBRARY_ASSERTION.search(stderr)
        if assertion:
            detail["mechanism"] = "library_assertion"
            detail["assertion"] = assertion.group(1)
        else:
            detail["mechanism"] = "signal"
        return Outcome("crash", detail)
    if code == ASAN_EXIT and "AddressSanitizer" in stderr:
        kind = ASAN_KIND.search(stderr)
        access = ASAN_ACCESS.search(stderr)
        region = ASAN_REGION.search(stderr)
        detail.update(mechanism="asan",
                      report=kind.group(1) if kind else "unknown",
                      access=" ".join(access.groups()) if access else None,
                      region=region.group(1) if region else None,
                      frame=first_algorithm_frame(stderr))
        return Outcome("crash", detail)
    if code == UBSAN_EXIT and "runtime error" in stderr:
        error = UBSAN_ERROR.search(stderr)
        detail.update(mechanism="ubsan",
                      report=error.group(1) if error else "unknown",
                      frame=first_algorithm_frame(stderr))
        return Outcome("crash", detail)
    if finished.truncated:
        return Outcome("output_limit", detail)
    if code in EXIT_EXCEPTIONS:
        result = first_record(records, "result") or {}
        for key in ("code", "function", "line", "message"):
            if key in result:
                detail[key] = result[key]
        return Outcome(EXIT_EXCEPTIONS[code], detail)
    if code != EXIT_RETURNED:
        detail["reason"] = PROBE_ERRORS.get(code, f"exit status {code}")
        detail["stderr"] = stderr.strip()[-500:]
        return Outcome("probe_error", detail)
    return classify_returned(records, minimality, optimum)


def classify_returned(records, minimality: str,
                      optimum: Optional[Fraction]) -> Outcome:
    detail: Dict[str, object] = {}
    result = first_record(records, "result")
    shape = first_record(records, "vertex_shape")
    source = first_record(records, "input")
    if (result is None or shape is None or source is None
            or result.get("outcome") != "returned"):
        detail["reason"] = "incomplete probe output"
        return Outcome("probe_error", detail)
    k = int(source["k"])
    area = decode_binary64(result["area_bits"])
    vertex_bits = point_records(records, "vertex")
    detail.update(area=area, count=int(shape["count"]),
                  rows=int(shape["rows"]), cols=int(shape["cols"]))
    if shape["empty"] == "1":
        if area != 0.0:
            detail["reason"] = "empty output with nonzero area"
            return Outcome("polygon_invalid", detail)
        return Outcome("empty", detail)
    problems = []
    if int(shape["count"]) != k or len(vertex_bits) != k:
        problems.append("vertex count differs from k")
    values = [decode_binary32(part) for token in vertex_bits
              for part in token.split(":")]
    if not math.isfinite(area) or not all(map(math.isfinite, values)):
        problems.append("non-finite area or vertex")
    if problems:
        detail["problems"] = problems
        return Outcome("polygon_invalid", detail)

    def exact(tokens: Sequence[str]) -> List[Point]:
        return [(Fraction(decode_binary32(token[:8])),
                 Fraction(decode_binary32(token[9:]))) for token in tokens]

    polygon = exact(vertex_bits)
    hull = convex_hull(exact(point_records(records, "point")))
    hull_area = abs(twice_signed_area(hull)) / 2 if len(hull) >= 3 else 0
    exact_area = abs(twice_signed_area(polygon)) / 2
    enclosure = check_enclosure(polygon, hull)
    scale = diameter(hull) or 1.0
    detail.update(exact_area=float(exact_area), hull_vertices=len(hull),
                  hull_area=float(hull_area), convex=enclosure.convex,
                  collinear_vertices=enclosure.collinear_vertices,
                  relative_outside=enclosure.worst_outside / scale)
    if exact_area:
        detail["area_error"] = abs(area - float(exact_area)) / float(
            exact_area)
    if not enclosure.convex:
        problems.append("not convex")
    if enclosure.worst_outside > RELATIVE_ENCLOSURE_TOLERANCE * scale:
        problems.append("an input point is outside")
    if exact_area == 0 or detail["area_error"] > RELATIVE_AREA_TOLERANCE:
        problems.append("reported area differs from vertex area")
    if exact_area < hull_area * (1 - Fraction(RELATIVE_AREA_TOLERANCE)):
        problems.append("area below hull area")

    competitors: Dict[str, Fraction] = {}
    if minimality == "all":
        if len(hull) > MAX_TRIANGLE_COMPETITOR_HULL:
            detail["triangle_competitor"] = "skipped: hull too large"
        else:
            triangle = flush_triangle_area(hull)
            if triangle is not None:
                competitors["flush_triangle"] = triangle
    if minimality in ("all", "rectangle") and k >= 4:
        rectangle = minimum_rectangle_area(hull)
        if rectangle is not None:
            competitors["minimum_rectangle"] = rectangle
    beaten = []
    for name, value in competitors.items():
        detail[name] = float(value)
        if exact_area > value * (1 + Fraction(RELATIVE_AREA_TOLERANCE)):
            beaten.append(name)
    if optimum is not None:
        detail["optimum"] = float(optimum)
        detail["optimum_ratio"] = float(exact_area / optimum)
        if exact_area > optimum * (1 + Fraction(RELATIVE_AREA_TOLERANCE)):
            beaten.append("optimum")
    oracle = first_record(records, "oracle")
    if oracle is not None:
        summary, exact_triangle = describe_oracle(records, oracle, hull,
                                                  scale)
        detail["triangle_oracle"] = summary
        if exact_triangle is not None and exact_area > exact_triangle * (
                1 + Fraction(RELATIVE_AREA_TOLERANCE)):
            beaten.append("triangle_oracle")
    if problems:
        detail["problems"] = problems
        return Outcome("polygon_invalid", detail)
    if beaten:
        detail["smaller"] = beaten
        return Outcome("polygon_nonminimal", detail)
    return Outcome("polygon", detail)


def describe_oracle(records, oracle: Dict[str, str],
                    hull: Sequence[Point], scale: float
                    ) -> Tuple[Dict[str, object], Optional[Fraction]]:
    """Exactly re-checks cv::minEnclosingTriangle; it is never trusted.

    Returns a summary and, only when the binary32 triangle is convex and
    every hull point lies inside or on it exactly, its exact area.
    """
    summary: Dict[str, object] = {"outcome": oracle.get("outcome")}
    if oracle.get("outcome") != "returned":
        summary.update({key: oracle[key] for key in ("reason", "code")
                        if key in oracle})
        return summary, None
    tokens = point_records(records, "oracle_vertex")
    triangle = [(Fraction(decode_binary32(token[:8])),
                 Fraction(decode_binary32(token[9:]))) for token in tokens]
    summary["area"] = decode_binary64(oracle["area_bits"])
    if len(triangle) != 3:
        summary["exact_enclosure"] = False
        return summary, None
    enclosure = check_enclosure(triangle, hull)
    exact_area = abs(twice_signed_area(triangle)) / 2
    summary["exact_area"] = float(exact_area)
    summary["relative_outside"] = enclosure.worst_outside / scale
    exact = enclosure.convex and enclosure.worst_outside == 0
    summary["exact_enclosure"] = exact
    return summary, exact_area if exact else None


# ---------------------------------------------------------------- build --

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def command_output(arguments: Sequence[str],
                   environment: Optional[Dict[str, str]] = None) -> str:
    return subprocess.run(arguments, check=True, capture_output=True,
                          text=True, env=environment).stdout.strip()


def find_pkgconfig(prefix: Path) -> Tuple[str, Path]:
    for libdir in ("lib", "lib64", "lib/x86_64-linux-gnu"):
        for package in ("opencv5", "opencv4"):
            if (prefix / libdir / "pkgconfig" / f"{package}.pc").is_file():
                return package, prefix / libdir / "pkgconfig"
    raise ResearchError(f"no opencv5.pc or opencv4.pc below {prefix}")


def repository_state() -> Dict[str, object]:
    try:
        head = command_output(["git", "-C", str(REPOSITORY), "rev-parse",
                               "HEAD"])
        dirty = bool(command_output(["git", "-C", str(REPOSITORY),
                                     "status", "--porcelain"]))
    except (OSError, subprocess.CalledProcessError):
        return {"head": None, "dirty": None}
    return {"head": head, "dirty": dirty}


def build(arguments: argparse.Namespace) -> int:
    prefix = Path(arguments.prefix).resolve()
    output = Path(arguments.output).resolve()
    package, pkgconfig = find_pkgconfig(prefix)
    environment = dict(os.environ, PKG_CONFIG_LIBDIR=str(pkgconfig))
    environment.pop("PKG_CONFIG_PATH", None)

    def query(*options: str) -> str:
        return command_output(["pkg-config", *options, package],
                              environment)

    version = query("--modversion")
    major, minor = (int(part) for part in version.split(".")[:2])
    if major > 5:
        raise ResearchError(f"OpenCV {version}: major versions after 5 are "
                            "unevaluated")
    if (major, minor) < (4, 13):
        raise ResearchError(f"OpenCV {version} has no "
                            "minEnclosingConvexPolygon")
    cflags = query("--cflags").split()
    libs = query("--libs").split()
    libdir = Path(query("--variable=libdir")).resolve()

    compiler = os.environ.get("CXX", "g++")
    variant = {"release": [],
               "asan": ["-fsanitize=address,undefined"],
               "asan-assert": ["-fsanitize=address,undefined",
                               "-D_GLIBCXX_ASSERTIONS"]}[arguments.variant]
    common = ["-std=c++17", "-O1", "-g", "-fno-omit-frame-pointer",
              *variant]
    output.parent.mkdir(parents=True, exist_ok=True)
    work = output.parent / (output.name + ".build")
    if work.exists():
        shutil.rmtree(work)
    work.mkdir()
    objects = [work / "probe.o"]
    commands = [[compiler, *common, "-Wall", "-Wextra", "-Wpedantic",
                 "-Werror", *cflags, "-c", str(PROBE_SOURCE), "-o",
                 str(objects[0])]]
    implementation = None
    if arguments.implementation_source:
        source = Path(arguments.implementation_source).resolve()
        copy = work / "min_enclosing_convex_polygon.cpp"
        shutil.copyfile(source, copy)
        implementation = {"path": str(source), "sha256": sha256(source)}
        objects.append(work / "implementation.o")
        # Upstream code is compiled unmodified, without -Werror. The stub
        # supplies OpenCV's private precomp.hpp from public headers.
        commands.append([compiler, *common, "-w", "-iquote",
                         str(STUB_DIRECTORY), *cflags, "-c", str(copy),
                         "-o", str(objects[-1])])
    commands.append([compiler, *common, *map(str, objects), "-o",
                     str(output), f"-Wl,-rpath,{libdir}", *libs, "-ldl"])
    for command in commands:
        print("+", " ".join(command), flush=True)
        subprocess.run(command, check=True)

    manifest = {
        "format": 1,
        "probe": str(output),
        "probe_sha256": sha256(output),
        "probe_source": str(PROBE_SOURCE.relative_to(REPOSITORY)),
        "probe_source_sha256": sha256(PROBE_SOURCE),
        "stub_sha256": sha256(STUB_DIRECTORY / "precomp.hpp"),
        "repository": repository_state(),
        "variant": arguments.variant,
        "compiler": command_output([compiler, "--version"]).splitlines()[0],
        "flags": common,
        "prefix": str(prefix),
        "package": package,
        "version": version,
        "libdir": str(libdir),
        "cflags": cflags,
        "libs": libs,
        "implementation_source": implementation,
    }
    manifest_path = Path(str(output) + ".json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"built {output} (OpenCV {version}, {arguments.variant}"
          f"{', implementation compiled in' if implementation else ''})")
    return 0


# ------------------------------------------------------------ reporting --

def load_manifest(probe: Path) -> Optional[Dict[str, object]]:
    path = Path(str(probe) + ".json")
    if not path.is_file():
        return None
    return json.loads(path.read_text())


def identity_problem(finished: Finished,
                     manifest: Optional[Dict[str, object]]) -> Optional[str]:
    runtime = first_record(parse_records(finished.stdout), "runtime")
    if runtime is None:
        return "no runtime record"
    if manifest is None:
        return None
    loaded = runtime.get("implementation_object", "unknown")
    if manifest.get("implementation_source"):
        if loaded != "main-executable":
            return f"implementation loaded from {loaded}, not the probe"
        return None
    libdir = Path(str(manifest["libdir"]))
    if Path(loaded).resolve().parent != libdir:
        return f"implementation loaded from {loaded}, not {libdir}"
    return None


# Failures that can occur before the probe reports its identity.
UNIDENTIFIED_OUTCOMES = ("timeout", "output_limit", "probe_error")


def checked_outcome(finished: Finished, outcome: Outcome,
                    manifest: Optional[Dict[str, object]],
                    points: Optional[List[str]] = None) -> Outcome:
    """Replaces outcome by identity_error if the wrong code was measured."""
    if outcome.kind in UNIDENTIFIED_OUTCOMES:
        return outcome
    problem = identity_problem(finished, manifest)
    echoed = point_records(parse_records(finished.stdout), "point")
    if problem is None and points is not None and echoed != points:
        problem = "probe input differs from the corpus"
    if problem is not None:
        return Outcome("identity_error", {"reason": problem})
    return outcome


class Reporter:
    """Prints one line per outcome and optionally writes JSON lines."""

    def __init__(self, path: Optional[str], header: Dict[str, object]):
        self.counts: Dict[str, int] = collections.Counter()
        self.objects: Dict[str, str] = {}
        self.stream = open(path, "w") if path else None
        self.write(dict(header, kind="header"))

    def write(self, record: Dict[str, object]) -> None:
        if self.stream:
            self.stream.write(json.dumps(record, default=str) + "\n")

    def object_identity(self, finished: Finished) -> Dict[str, str]:
        runtime = first_record(parse_records(finished.stdout),
                               "runtime") or {}
        identity = {key: runtime.get(key, "unknown") for key in
                    ("version", "implementation_object", "core_object")}
        for key in ("implementation_object", "core_object"):
            path = identity[key]
            if path.startswith("/") and path not in self.objects:
                self.objects[path] = sha256(Path(path))
        return identity

    def close(self, summary: Dict[str, object]) -> None:
        self.write(dict(summary, kind="summary",
                        loaded_objects=self.objects))
        if self.stream:
            self.stream.close()


def describe(outcome: Outcome) -> str:
    d = outcome.detail
    if outcome.kind == "crash":
        parts = [str(d.get("mechanism")), str(d.get("signal") or
                                              d.get("report"))]
        if d.get("frame"):
            parts.append(str(d["frame"]))
        if d.get("assertion"):
            parts.append(str(d["assertion"]))
        return " ".join(parts)
    if outcome.kind in EXIT_EXCEPTIONS.values():
        return f"code={d.get('code')} {d.get('message', '')}"
    if outcome.kind.startswith("polygon"):
        text = f"area={d.get('area'):.9g}"
        for key in ("optimum", "flush_triangle", "minimum_rectangle"):
            if key in d:
                text += f" {key}={d[key]:.9g}"
        if "smaller" in d:
            text += " smaller=" + ",".join(d["smaller"])
        if "problems" in d:
            text += " problems=" + ",".join(d["problems"])
        oracle = d.get("triangle_oracle")
        if isinstance(oracle, dict) and "exact_area" in oracle:
            text += (f" oracle={oracle['exact_area']:.9g}"
                     f"(exact_enclosure={oracle['exact_enclosure']})")
        return text
    return ", ".join(f"{key}={value}" for key, value in d.items())


def common_header(arguments: argparse.Namespace,
                  manifest: Optional[Dict[str, object]]) -> Dict[str, object]:
    return {"started": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "arguments": vars(arguments), "manifest": manifest,
            "runner_sha256": sha256(Path(__file__)),
            "python": sys.version.split()[0],
            "sanitizer_options": SANITIZER_OPTIONS}


def check_probe(arguments: argparse.Namespace):
    probe = Path(arguments.probe).resolve()
    if not os.access(probe, os.X_OK):
        raise ResearchError(f"{probe} is not an executable probe")
    if arguments.jobs > MAX_PARALLEL:
        raise ResearchError(f"--jobs must be at most {MAX_PARALLEL}")
    manifest = load_manifest(probe)
    if manifest is None:
        print(f"warning: {probe}.json is missing; loaded-library identity "
              "is reported but not checked", file=sys.stderr)
    elif (arguments.memory_limit_mb
          and manifest["variant"] != "release"):
        raise ResearchError("--memory-limit-mb needs a release probe: "
                            "sanitizers reserve large address ranges")
    limit_arguments = []
    if arguments.memory_limit_mb:
        limit_arguments = ["--address-space-mb",
                           str(arguments.memory_limit_mb)]
    return probe, manifest, limit_arguments


def run_corpus(arguments: argparse.Namespace) -> int:
    probe, manifest, limits = check_probe(arguments)
    if arguments.expect and (arguments.minimality != "all"
                             or not arguments.triangle_oracle):
        raise ResearchError("--expect needs the default --minimality all "
                            "and the triangle oracle: expectations were "
                            "recorded with them")
    corpus_path = Path(arguments.corpus)
    cases = parse_corpus(corpus_path.read_text(), str(corpus_path))
    if arguments.case:
        wanted = set(arguments.case)
        unknown = wanted - {case.name for case in cases}
        if unknown:
            raise ResearchError("unknown cases: " + ", ".join(sorted(unknown)))
        cases = [case for case in cases if case.name in wanted]
    jobs = []
    for case in cases:
        options = ["--case", "--input-depth", case.depth, *limits]
        if arguments.triangle_oracle:
            options.append("--triangle-oracle")
        jobs.append(Job(case.name, options,
                        f"{case.k}\n" + "\n".join(case.points) + "\n", case))
    header = common_header(arguments, manifest)
    header["corpus_sha256"] = sha256(corpus_path)
    reporter = Reporter(arguments.report, header)
    mismatches = errors = unchecked = 0
    results = {}
    for finished in run_jobs(probe, jobs, arguments.jobs, arguments.timeout,
                             arguments.output_limit_kib * 1024):
        case = finished.job.case
        outcome = checked_outcome(
            finished, classify(finished, arguments.minimality, case.optimum),
            manifest, case.points)
        verdict = "-"
        if arguments.expect:
            expected = case.expect.get(arguments.expect)
            if expected is None:
                unchecked += 1
            elif expected == outcome.kind:
                verdict = "as expected"
            else:
                verdict = f"MISMATCH, expected {expected}"
                mismatches += 1
        if outcome.kind in ("probe_error", "identity_error", "timeout",
                            "output_limit"):
            errors += 1
        reporter.counts[outcome.kind] += 1
        reporter.write({"kind": "case", "case": case.name, "k": case.k,
                        "depth": case.depth, "outcome": outcome.kind,
                        "detail": outcome.detail, "expectation": verdict,
                        "returncode": finished.returncode,
                        "seconds": round(finished.seconds, 4),
                        "identity": reporter.object_identity(finished)})
        results[case.name] = (outcome, verdict)
    for case in cases:
        outcome, verdict = results[case.name]
        print(f"{case.name}: {outcome.kind} [{verdict}] {describe(outcome)}")
    summary = {"counts": dict(reporter.counts), "mismatches": mismatches,
               "unchecked": unchecked, "errors": errors}
    reporter.close(summary)
    print("summary: " + " ".join(f"{key}={value}" for key, value in
                                 sorted(reporter.counts.items())))
    if reporter.objects:
        for path, digest in sorted(reporter.objects.items()):
            print(f"loaded {path} sha256={digest}")
    if arguments.expect:
        print(f"expectations ({arguments.expect}): {mismatches} mismatches, "
              f"{unchecked} unchecked")
    if errors:
        return 2
    return 1 if mismatches else 0


def run_fuzz(arguments: argparse.Namespace) -> int:
    probe, manifest, limits = check_probe(arguments)
    if not 1 <= arguments.iterations <= MAX_ITERATIONS_PER_SEED:
        raise ResearchError(f"--iterations must be 1 .. "
                            f"{MAX_ITERATIONS_PER_SEED}")
    last = arguments.first + arguments.iterations - 1
    if arguments.first < 0 or last > MAX_ITERATION:
        raise ResearchError(f"iterations must lie in 0 .. {MAX_ITERATION}")
    if any(not 0 <= seed < 2**32 for seed in arguments.seed):
        raise ResearchError("seeds must lie in 0 .. 2**32 - 1")
    if len(arguments.seed) * arguments.iterations > MAX_FUZZ_JOBS:
        raise ResearchError(f"at most {MAX_FUZZ_JOBS} cases per run")
    jobs = []
    for seed in arguments.seed:
        for iteration in range(arguments.first,
                               arguments.first + arguments.iterations):
            options = ["--fuzz", str(seed), str(iteration), *limits]
            if arguments.k is not None:
                options += ["--fuzz-k", str(arguments.k)]
            jobs.append(Job(f"{seed}:{iteration}", options))
    reporter = Reporter(arguments.report, common_header(arguments, manifest))
    by_seed: Dict[int, collections.Counter] = collections.defaultdict(
        collections.Counter)
    notable: List[Tuple[int, int, str]] = []
    errors = 0
    for finished in run_jobs(probe, jobs, arguments.jobs, arguments.timeout,
                             arguments.output_limit_kib * 1024):
        seed, iteration = (int(part) for part in finished.job.key.split(":"))
        outcome = checked_outcome(
            finished, classify(finished, arguments.minimality), manifest)
        source = first_record(parse_records(finished.stdout), "input") or {}
        by_seed[seed][outcome.kind] += 1
        reporter.counts[outcome.kind] += 1
        if outcome.kind in ("probe_error", "identity_error", "timeout",
                            "output_limit"):
            errors += 1
        if outcome.kind not in ("polygon", "empty"):
            notable.append((seed, iteration, outcome.kind))
        reporter.write({"kind": "fuzz", "seed": seed,
                        "iteration": iteration,
                        "input": {key: source.get(key) for key in
                                  ("n", "k", "shape", "scale")},
                        "outcome": outcome.kind, "detail": outcome.detail,
                        "returncode": finished.returncode,
                        "identity": reporter.object_identity(finished)})
    for seed in arguments.seed:
        counts = by_seed[seed]
        print(f"seed {seed}: " + " ".join(
            f"{key}={value}" for key, value in sorted(counts.items())))
    notable.sort()
    for seed, iteration, kind in notable[:arguments.show]:
        print(f"  {kind} seed={seed} iteration={iteration}")
    if len(notable) > arguments.show:
        print(f"  ... {len(notable) - arguments.show} more in the report")
    reporter.close({"counts": dict(reporter.counts),
                    "notable": notable, "errors": errors})
    print("total: " + " ".join(f"{key}={value}" for key, value in
                               sorted(reporter.counts.items())))
    for path, digest in sorted(reporter.objects.items()):
        print(f"loaded {path} sha256={digest}")
    return 2 if errors else 0


def freeze(arguments: argparse.Namespace) -> int:
    probe = Path(arguments.probe).resolve()
    if not NAME_PATTERN.match(arguments.name):
        raise ResearchError("--name must match [a-z0-9_]+")
    options = ["--generate-only"]
    if arguments.fuzz:
        options += ["--fuzz", *arguments.fuzz]
        if arguments.k is not None:
            options += ["--fuzz-k", str(arguments.k)]
    elif arguments.circle:
        options += ["--circle", *arguments.circle]
    else:
        options += ["--arc", *arguments.arc]
    finished = next(run_jobs(probe, [Job("freeze", options)], 1, 60.0,
                             1 << 20))
    records = parse_records(finished.stdout)
    source = first_record(records, "input")
    if finished.returncode != 0 or source is None:
        raise ResearchError("probe failed: " + finished.stderr.strip())
    print(corpus_entry(arguments.name, arguments.origin, int(source["k"]),
                       "f32", point_records(records, "point")), end="")
    return 0


# ------------------------------------------------------------ self-test --

def self_test(_: argparse.Namespace) -> int:
    """Checks the runner's own parsing, geometry and classification."""
    checks = 0

    def check(condition: bool, message: str) -> None:
        nonlocal checks
        if not condition:
            raise AssertionError(message)
        checks += 1

    sample = parse_corpus(
        "# comment\ncase square\norigin unit test\nk 3\n"
        "points 00000000:00000000 41200000:00000000\n"
        "points 41200000:41200000 00000000:41200000\n"
        "optimum 200 parallelogram bound\nexpect released crash\nend\n"
        "case again\norigin second\nk 4\ndepth i32\nend\n",
        "sample")
    check(len(sample) == 2 and len(sample[0].points) == 4
          and sample[1].depth == "i32" and not sample[1].points,
          "corpus parsing")
    check(sample[0].optimum == 200 and sample[0].expect == {
        "released": "crash"}, "optimum and expectation")
    for bad in ("case a\nk 3\nend\n", "case a\norigin x\nk 3\nend\n" * 2,
                "case a\norigin x\nk 3\npoints 0:0\nend\n",
                "k 3\n", "case a\norigin x\nk 3\n"):
        try:
            parse_corpus(bad, "bad")
        except ResearchError:
            checks += 1
        else:
            raise AssertionError(f"accepted malformed corpus {bad!r}")
    check(decode_binary32("41200000") == 10.0
          and decode_binary32("bf800000") == -1.0, "binary32 decoding")
    check(corpus_entry("x", "o", 3, "f32", ["00000000:00000000"] * 5)
          .count("\npoints ") == 2, "corpus entry wrapping")

    def points(*pairs: Tuple[int, int]) -> List[Point]:
        return [(Fraction(x), Fraction(y)) for x, y in pairs]

    square = points((0, 0), (10, 0), (10, 10), (0, 10))
    check(convex_hull(square + points((5, 5), (5, 0))) == square,
          "hull drops interior and collinear points")
    check(flush_triangle_area(square) is None,
          "a square has no triangle on three edge lines")
    hexagon = points((0, 0), (10, 0), (15, 10), (10, 20), (0, 20), (-5, 10))
    check(flush_triangle_area(hexagon) == 450, "hexagon flush triangle")
    diamond = points((0, -1), (1, 0), (0, 1), (-1, 0))
    check(minimum_rectangle_area(diamond) == 2, "diamond minimum rectangle")
    enclosed = check_enclosure(points((0, 0), (20, 0), (0, 20)), square)
    check(enclosed.convex and enclosed.worst_outside == 0,
          "enclosing triangle")
    small = check_enclosure(points((0, 0), (10, 0), (0, 10)), square)
    check(small.worst_outside > 7, "detects an outside point")
    star = points((0, 10), (6, -8), (-10, 3), (10, 3), (-6, -8))
    check(not check_enclosure(star, square).convex, "rejects a pentagram")

    def finished(code: int, stdout: str = "", stderr: str = "",
                 timed_out: bool = False) -> Finished:
        return Finished(Job("x", []), code, timed_out, stdout, stderr,
                        False, 0.0)

    returned = ("input source=case k=3 n=4 depth=f32\n"
                "point i=0 x=00000000 y=00000000\n"
                "point i=1 x=41200000 y=00000000\n"
                "point i=2 x=41200000 y=41200000\n"
                "point i=3 x=00000000 y=41200000\n"
                "result outcome=returned area=200 "
                "area_bits=4069000000000000\n"
                "vertex_shape rows=3 cols=1 type=13 empty=0 count=3\n"
                "vertex i=0 x=00000000 y=41a00000\n"
                "vertex i=1 x=41a00000 y=00000000\n"
                "vertex i=2 x=00000000 y=00000000\n")
    check(classify(finished(0, returned), "all", Fraction(200)).kind
          == "polygon", "optimal square triangle")
    check(classify(finished(0, returned), "all", Fraction(199)).kind
          == "polygon_nonminimal", "beaten by an optimum")
    check(classify(finished(-11), "all").kind == "crash", "signal")
    check(classify(finished(-signal.SIGXFSZ), "all").kind == "output_limit",
          "output limit")
    assertion = classify(finished(-6, stderr="Assertion '__n < this->"
                                             "size()' failed."), "all")
    check(assertion.detail["mechanism"] == "library_assertion",
          "library assertion")
    oracle = (returned
              + "oracle kind=triangle outcome=returned area=150 "
                "area_bits=4062c00000000000\n"
                "oracle_vertex_shape rows=3 cols=1 type=13 empty=0 count=3\n"
                "oracle_vertex i=0 x=00000000 y=00000000\n"
                "oracle_vertex i=1 x=41a00000 y=00000000\n"
                "oracle_vertex i=2 x=00000000 y=41700000\n")
    claimed = classify(finished(0, oracle), "none")
    check(claimed.kind == "polygon"
          and not claimed.detail["triangle_oracle"]["exact_enclosure"],
          "an oracle triangle that misses a point is not a competitor")
    larger = returned.replace("y=41a00000", "y=41c80000").replace(
        "area=200 area_bits=4069000000000000",
        "area=250 area_bits=406f400000000000")
    larger_oracle = larger + oracle[len(returned):].replace(
        "y=41700000", "y=41a00000")
    proved = classify(finished(0, larger_oracle), "none")
    check(proved.kind == "polygon_nonminimal"
          and proved.detail["smaller"] == ["triangle_oracle"],
          "an exactly enclosing oracle triangle proves non-minimality")
    asan = classify(finished(ASAN_EXIT, stderr=(
        "ERROR: AddressSanitizer: heap-buffer-overflow on address\n"
        "READ of size 8 at 0x1 thread T0\n"
        "    #0 0x1 in std::vector<int>::operator[](unsigned long) "
        "/usr/include/stl_vector.h:1131\n"
        "    #1 0x2 in ns::Chains::findKSides(int, int, int) "
        "/tmp/mecp.cpp:919\n")), "all")
    check(asan.kind == "crash" and asan.detail["frame"]
          == "ns::Chains::findKSides(int, int, int) at mecp.cpp:919",
          "AddressSanitizer report")
    check(classify(finished(1, stderr="AddressSanitizer"), "all").kind
          == "probe_error", "unknown status is a probe error")
    check(classify(finished(10, "result outcome=cv_exception code=-2\n"),
                   "all").detail["code"] == "-2", "cv::Exception")
    check(classify(finished(0, timed_out=True), "all").kind == "timeout",
          "timeout")
    check(checked_outcome(finished(-9, timed_out=True),
                          Outcome("timeout", {}), {"libdir": "/x"}).kind
          == "timeout", "a timeout before the runtime record stays a timeout")
    check(checked_outcome(finished(0, returned), Outcome("polygon", {}),
                          {"libdir": "/x"}).kind == "identity_error",
          "a result without a runtime record is an identity error")
    print(f"self-test: {checks} checks passed")
    return 0


# ------------------------------------------------------------------ main --

def positive(text: str) -> int:
    value = int(text)
    if value < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return value


def add_run_options(parser: argparse.ArgumentParser, minimality: str,
                    parallel: int) -> None:
    parser.add_argument("--probe", required=True,
                        help="probe built by the build subcommand")
    parser.add_argument("--jobs", type=positive, default=parallel,
                        help="maximum concurrent children")
    parser.add_argument("--timeout", type=float, default=60.0,
                        help="seconds before a child's process group is "
                             "killed")
    parser.add_argument("--output-limit-kib", type=positive, default=1024,
                        help="RLIMIT_FSIZE for each captured stream")
    parser.add_argument("--memory-limit-mb", type=positive, default=None,
                        help="RLIMIT_AS for release probes")
    parser.add_argument("--minimality", default=minimality,
                        choices=("all", "rectangle", "none"),
                        help="competitors to compare against")
    parser.add_argument("--report", help="write JSON lines here")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parallel = max(1, min(8, os.cpu_count() or 1))
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    builder = commands.add_parser("build", help="build the probe")
    builder.add_argument("--prefix", required=True,
                         help="OpenCV installation prefix")
    builder.add_argument("--output", required=True, help="probe path")
    builder.add_argument("--variant", default="release",
                         choices=("release", "asan", "asan-assert"))
    builder.add_argument("--implementation-source",
                         help="exact upstream min_enclosing_convex_polygon"
                              ".cpp to compile into the probe")
    builder.set_defaults(handler=build)

    runner = commands.add_parser("run", help="run the frozen corpus")
    add_run_options(runner, "all", parallel)
    runner.add_argument("--corpus", default=str(DEFAULT_CORPUS))
    runner.add_argument("--case", action="append",
                        help="run only this case; repeatable")
    runner.add_argument("--expect", help="compare with this family's "
                                         "expectations")
    runner.add_argument("--no-triangle-oracle", dest="triangle_oracle",
                        action="store_false",
                        help="do not run cv::minEnclosingTriangle on "
                             "integral input after a returned result")
    runner.set_defaults(handler=run_corpus)

    fuzzer = commands.add_parser("fuzz",
                                 help="replay the Task 016 generator")
    add_run_options(fuzzer, "rectangle", parallel)
    fuzzer.add_argument("--seed", type=int, action="append", required=True)
    fuzzer.add_argument("--first", type=int, default=0)
    fuzzer.add_argument("--iterations", type=int, default=100)
    fuzzer.add_argument("--k", type=int, help="override the generated k")
    fuzzer.add_argument("--show", type=int, default=20,
                        help="notable outcomes to list")
    fuzzer.set_defaults(handler=run_fuzz)

    freezer = commands.add_parser("freeze", help="print a corpus entry")
    freezer.add_argument("--probe", required=True)
    freezer.add_argument("--name", required=True)
    freezer.add_argument("--origin", required=True)
    source = freezer.add_mutually_exclusive_group(required=True)
    source.add_argument("--fuzz", nargs=2, metavar=("SEED", "ITERATION"))
    source.add_argument("--circle", nargs=3, metavar=("N", "RADIUS", "K"))
    source.add_argument("--arc", nargs=4,
                        metavar=("N", "RADIUS", "SPAN", "K"))
    freezer.add_argument("--k", type=int, help="with --fuzz, override k")
    freezer.set_defaults(handler=freeze)

    tester = commands.add_parser("self-test",
                                 help="check the runner without OpenCV")
    tester.set_defaults(handler=self_test)

    arguments = parser.parse_args(argv)
    try:
        return arguments.handler(arguments)
    except (ResearchError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())