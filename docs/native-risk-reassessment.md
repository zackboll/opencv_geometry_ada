# Task 025: native risk reassessment

Research only. No production Ada, C++ shim, C ABI, public API, manifest,
dependency or release file changed. Every deferred feature stays
**Deferred** or **Excluded** in [coverage](coverage.md). Nothing here is a
binding proposal for a feature that is not safe.

## Baseline

| Item | Value |
|---|---|
| Base | `origin/main` `6134f2f2af494b452392a2d5ce9b79197f617e50` (PR #23, Task 024, merged 2026-10-09) |
| Branch | `research/025-native-risk-reassessment`, worktree `geometry-task025` |
| Geometry manifest | `opencv_core = ">=0.2.0 & <0.5.0"`, unchanged |
| Native OpenCV (development build) | 4.10.0, imgproc backend, Debian `libopencv_imgproc.so.410` |
| `alr -n build` | passed |
| `alr -n -C tests run` | **531/531**, 0 failed assertions, 0 errors |
| Self-tests | `run_fit_line_3d_research.py` 8 tests OK; `run_min_enclosing_polygon_research.py` 29 checks OK; `run_risk_reassessment.py` 4 tests OK |

Core note, recorded separately from safety: Core `main` has shared 3-D point
types that published Core 0.4.1 lacks. That is an ownership and packaging
matter for `Fit_Line_3D`, not evidence about native safety. Core and
Geometry's dependency were not touched.

## How to read the evidence

Each claim carries one label.

- **Source**: read in an exact tagged or local source tree.
- **Runtime**: observed in an uninstrumented OpenCV build, in a child
  process (hard wall-time limit, process-group kill, core dumps off, bounded
  output, fixed inputs).
- **Sanitizer**: observed with ASan/UBSan against instrumented code.
- **Model-only**: derived by reasoning or an earlier model, not rerun here.
- **Untested**: not examined for that version.

A sanitizer run against an uninstrumented prebuilt OpenCV says nothing about
upstream memory safety and none is claimed. Sanitizer results quoted below
come from earlier tasks and from the fully instrumented builds those tasks
record. They were not repeated in Task 025.

### Runtime builds used in this task

| Version | Object that provided the symbol | Source |
|---|---|---|
| 4.10.0 | `/lib/x86_64-linux-gnu/libopencv_imgproc.so.410` (host Debian) | distro |
| 4.12.0 | `/tmp/geometry021-matrix/install-4.12.0/lib/libopencv_imgproc.so.412` | exact-tag build, Task 021 |
| 4.13.0 | `/tmp/geometry021-matrix/install-4.13.0/...imgproc.so.413` | exact-tag build |
| 4.14.0 | `/tmp/geometry021-matrix/install-4.14.0/...imgproc.so.414` | exact-tag build |
| 5.0.0 | `/tmp/features-008a-install500/lib/libopencv_geometry.so.500` | exact-tag build |
| 4.14.0 / 5.x PR 30111 head | `/var/tmp/geometry-016-pr30111/install-head` | build of `01f4d0e5` |

The probe prints the loaded object path and `CV_VERSION` for every case and
the runner stores them. 4.6.0 and 4.11.0 were **not** re-run here. Their
results below come from earlier tasks (labelled).

### Source identity (SHA-256 prefixes, this task)

| File | 4.12.0 | 4.13.0 | 4.14.0 | 5.0.0 |
|---|---|---|---|---|
| `min_enclosing_triangle.cpp` | 53a41175 | 53a41175 | 53a41175 | 53a41175 |
| `min_enclosing_convex_polygon.cpp` | absent | d9be1d25 | 3fd651ce | 3fd651ce |
| `geometry.cpp` (`intersectConvexConvex`) | 5cb89d28 | 05ec6cfb | 05ec6cfb | a659e962 |

`minEnclosingTriangle` is byte-identical across 4.12 to 5.0 (and, per
[float32-research.md](float32-research.md), 4.6, 4.10 and 5.0). The 4.14.0
`intersectConvexConvex_` has the `result_size` bound and the `-1` return.
4.13 and 4.14 hash identically. Between 4.12 and 4.14 the first diff hunk
is at line 713, the SIMD `boundingRect` code, after `intersectConvexConvex`;
the 4.12 file contains the same bound (checked by grep, not diffed in full).
The 5.0.0 file differs from 4.14 in other regions that this task did not
diff for `intersectConvexConvex`.

## Summary by feature

| Feature | Outcome | One-line reason |
|---|---|---|
| `Fit_Line_3D` | **INSUFFICIENT_EVIDENCE** (numerics) plus a separate ownership blocker | No ordinary-input memory or liveness fault found; the arithmetic envelope through both Eigen backends is unproven |
| `approxPolyN` | **DOCUMENTABLE_NUMERICAL_RISK** for results; memory safety **not reproduced as a fault** | Wrong but finite polygons on unit-scale input; no crash, hang or sanitizer report |
| Float32 `minEnclosingTriangle` | **ISOLATION_REQUIRED** | Hang at ordinary small scale and SIGSEGV/SIGFPE on a two-point signed-zero set; shared with the already-bound integer overload |
| Unrestricted Float32 `intersectConvexConvex` | **UPSTREAM_FIX_REQUIRED** on 4.6/4.10; **DOCUMENTABLE_NUMERICAL_RISK** on 4.11+ | Heap corruption on valid input in 4.6/4.10 (earlier task); 4.11+ bounds writes |
| `minEnclosingConvexPolygon` | **UPSTREAM_FIX_REQUIRED** | SIGSEGV on 14 of 33 corpus cases in 4.13.0, 4.14.0 and 5.0.0; PR 30111 head removes every crash |
| `Find_Nearest` (policy comparison) | Unchanged, no action | Documented, bound, not a template for the above |

## approxPolyN

Runtime, 4.12.0, 4.13.0, 4.14.0 and 5.0.0, seven cases each: **all returned**.
There were no signals, timeouts or exceptions. On 4.10.0 the symbol does not
exist (`approxPolyN` arrived in 4.11), so the probe reports `not_applicable`.

- Unit square, three sides, epsilon -1: returns `(-1,-1) (1,1) (0,1)`. This
  finite triangle does not enclose `(1,0)`. Identical on 4.12.0 and 5.0.0.
  The `(-1,-1)` is the sentinel intersection described in the earlier
  approxPolyN research. Reproduced.
- Strictly convex pentagon `(0,0) (4,0) (5,2) (3,5) (0,3)`, three sides:
  returns `(6.33333302,0) (3,5) (-4.5,0)`, matching the earlier model's
  `(6.3333330154418945,0)` (`40caaaaa`). The constructed vertex is not on the
  original support line. Reproduced.

Source: the earlier research in
[versioned-features-research.md](versioned-features-research.md#approxpolyn-safety-contract)
reports the body identical in 4.11, 4.12, 4.13 and 5.0. This task did not
re-diff it.

Assessment. The risk is wrong output, not a memory or liveness fault, in
everything examined here. The earlier research also found NaN heap keys from non-finite
intermediates; that is a possible ordering hazard with no memory fault
observed. A contract needs a proof that no sentinel or NaN key is ever
selected, and none exists. This is `DOCUMENTABLE_NUMERICAL_RISK` for
results. It does not become a qualified subset: the unit square is already
a counterexample, so no scale bound helps. Not safe to bind without a stated
"result may not enclose the input" contract, which would make the
operation of little use. Remains Deferred.

Unreproduced: the earlier NaN-key campaign was not rerun.

## Float32 minEnclosingTriangle

Runtime, 15 case-by-version results compared across five builds:

| Case | 4.10.0 | 4.12.0 | 4.13.0 | 4.14.0 | 5.0.0 |
|---|---|---|---|---|---|
| unit square, 1e-1, 1e-3, 1e3 sides | returned | returned | returned | returned | returned |
| 32-gon, r=100 and r=1e-4 | returned | returned | returned | returned | returned |
| thin sliver 100 x 1e-4 | returned | returned | returned | returned | returned |
| square side **1e-5** | **timeout** | timeout | timeout | timeout | timeout |
| square side **1e-6** | **timeout** | timeout | timeout | timeout | timeout |
| integer `(0,0),(1,0),(100001,1),(100000,1)` | **timeout** | timeout | timeout | timeout | timeout |
| `{(0,0),(-0,0)}` Float32 | **SIGFPE** | **SIGSEGV** | **SIGSEGV** | **SIGSEGV** | **SIGSEGV** |
| 4 points including `(-0,0)` | returned | returned | returned | returned | returned |

Timeouts are 4 seconds with the process group killed. A timeout shows the
call did not return in that time. It does not prove an infinite loop; the
source shows loops with no iteration bound (see
[float32-research.md](float32-research.md); the file is byte-identical).

New in this task: the two-point signed-zero set faults differently by
version. SIGFPE on 4.10 matches the earlier `i % 0` finding. On 4.12.0,
4.13.0, 4.14.0 and 5.0.0 it is SIGSEGV. The source is byte-identical from
4.12 to 5.0, so the 4.10 difference may come from the build or compiler
rather than the source; this was not investigated. No sanitizer run was
made, so the faulting access is unknown.

Assessment. The hang appears at side 1e-5, an ordinary Float32 scale, and
the 1e-1 to 1e3 range returned. Input checks cannot predict the hang except
by reimplementing the tolerance logic, and the integer overload hangs the
same way. A magnitude floor would be a numerical heuristic, not a proof.
**ISOLATION_REQUIRED.** Process isolation is an architectural decision and
is not proposed here.

## Unrestricted Float32 intersectConvexConvex

Runtime, all five builds, four cases each (two triangles near 0.1, 62-gon
against 61-gon at r=1000 and r=1, and two axis-aligned grid squares): **all
returned, no signals, no exceptions, no timeouts**.

That does not contradict the earlier finding. [float32-research.md](float32-research.md)
records, on **4.6.0 and 4.10**, `malloc(): corrupted top size` for a pair of
valid 62- and 61-vertex binary32 polygons. This task's 62/61-gon cases did
not reproduce it on 4.10.0. The inputs differ (these are regular n-gons with
a fixed offset, not the earlier pair), so this is **not** a refutation.

Status by version:

| Version | Evidence | Label |
|---|---|---|
| 4.6.0 | heap corruption on valid input | earlier task, runtime; not rerun |
| 4.10.0 | heap corruption on valid input; write of 14 points into a 13-slot region on a rounded integer hexagon | earlier task, runtime; this task's 4 cases returned |
| 4.11 to 5.0 | writes bounded by `result_size`, `-1` on overflow | source, confirmed here for 4.12/4.14/5.0 file hashes |

The development environment is 4.10.0, which is in the affected range.
4.11+ remains numerically unreliable (consistency of binary32 predicates
and the `(FLT_MAX, FLT_MAX)` sentinel) but is bounded. The existing
power-of-two-grid restriction is **not** removed. `UPSTREAM_FIX_REQUIRED`
for the 4.x versions Geometry supports.

## minEnclosingConvexPolygon

The Task 016 frozen corpus (33 cases) was rebuilt and rerun on 4.13.0,
4.14.0, 5.0.0 and the PR 30111 head. Expectations were checked by the runner.

| Build | Outcome counts | Mismatches with frozen expectation |
|---|---|---|
| 4.13.0 | crash 14, cv_exception 4, empty 3, polygon 7, polygon_nonminimal 5 | 0 |
| 4.14.0 | identical | 0 |
| 5.0.0 | identical | 0 |
| PR 30111 head | crash 0, cv_exception 11, empty 3, polygon 13, polygon_nonminimal 6 | 0 |

Reproduced: all 14 crashes are SIGSEGV, including the unit-scale square at
k=3, a regular hexagon at k=3, 33- and 200-gons at small radius with k=4, and
three fuzz cases. The head converts all 14 into a result or a contained
`cv::Exception` (11 exceptions).

Upstream status checked 2026-10-09 through the GitHub API: PR 30111 is
**open, unmerged**, one commit, head `01f4d0e5da231d00c1eca735a0880b492a69fdde`,
base 5.x, last update 2026-10-02. The newest tags are 5.0.0 and 4.14.0, so no
release contains it. The 5.x file history shows only the module-split merge
commit as the latest change to this file. Task 025 added no sanitizer runs for
this feature; Task 016's ASan builds with assertions are the sanitizer
evidence.

Even after the head, many results are not minimal and some valid input raises
(Task 016). `UPSTREAM_FIX_REQUIRED`. No qualified subset exists, because the
smallest crash is a unit-scale square.

## Fit_Line_3D

Not re-run. The Task 020 corpus and probe remain, and the runner self-test
passes. Carried forward:

- No ordinary-finite-input memory or liveness fault was found. Instrumented
  4.10 and 5.0 campaigns showed no sanitizer reports.
- A complete rounding-aware arithmetic envelope through both Eigen backends
  is not established. 480 cross-version direction divergences exist.
- Non-finite coordinates give 45 finite but all-zero directions per
  runtime, so preflight rejection would be essential.

This is the closest feature to a safe subset, but the open premise is a
numerical proof, not a missing test. **INSUFFICIENT_EVIDENCE.** A research
campaign cannot close it. The ownership question (shared 3-D types in Core)
is separate and still open until Core publishes them.

## Numerical risk versus safety risk

| Feature | Wrong or unstable result | Memory fault | Non-return |
|---|---|---|---|
| `approxPolyN` | yes (reproduced) | not observed | not observed |
| Float32 `minEnclosingTriangle` | not the issue | SIGSEGV/SIGFPE, 2-point set (reproduced) | yes, side 1e-5 (reproduced) |
| Float32 `intersectConvexConvex` | yes | 4.6/4.10 only (earlier task) | not observed |
| `minEnclosingConvexPolygon` | yes (nonminimal) | SIGSEGV, 14/33 (reproduced) | not observed |
| `Fit_Line_3D` | yes (ill-conditioned) | not observed | not observed |

Only the right-hand two columns block a binding. The first column alone
would be documentable.

## Find_Nearest comparison

`Find_Nearest` is bound, and its README and spec state that for closely
spaced points (about 0.01 units and below in the fixtures) it may return a
wrong vertex, raise `OpenCV_Error`, or fail to return; it must not be relied
on for untrusted or poorly conditioned geometry. It is unchanged here.
This task did not re-measure it.

Why it is not a precedent for the others:

- The caller can avoid the hazard by keeping point spacing at about 0.03 or
  more. The Float32 `minEnclosingTriangle` hang appears at a plain
  1e-5-side square, and `minEnclosingConvexPolygon` crashes on a unit
  square.
- Its failures were observed and bounded by fixtures. The crashes here are
  at unit scale, so there is no input region to document as safe.
- The accepted risk covers a stateful `Subdiv2D`. The deferred functions
  would be stateless calls on plain arrays, where callers expect them to
  return.

A numerical risk the caller can avoid is documentable. A crash or hang at
ordinary scale is not. This supports leaving `Find_Nearest` as is. It does
not argue for or against a different policy.

## Ranked opportunities

1. **Upstream issue drafts** for the three reproduced native faults
   (`minEnclosingTriangle` signed-zero fault and small-scale hang;
   `approxPolyN` sentinel enclosure failure; the `minEnclosingConvexPolygon`
   non-minimal results for PR 30111's reviewers). Cheapest, and the only
   route to `UPSTREAM_FIX_REQUIRED` becoming a fix. Nothing may be posted
   without the maintainer's decision.
2. **Watch PR 30111** and rerun the Task 016 corpus when a release contains
   an equivalent guard. The runner is ready.
3. **`Fit_Line_3D` arithmetic proof.** Requires an interval-arithmetic study
   of both Eigen backends. Large effort, uncertain result.
4. **Process isolation for hang-prone calls.** Architectural, needs a user
   decision; not recommended now.

## Proposed Task 026

**Prepare upstream reproducer drafts, no posting.** Write
`docs/upstream-reproducers.md` with minimal standalone C++ reproducers and
expected outcomes for: the two-point signed-zero `minEnclosingTriangle`
fault on 4.10, 4.14 and 5.0; the 1e-5-side square non-return; the unit
square `approxPolyN` sentinel result; and the unit-square k=3
`minEnclosingConvexPolygon` crash with the PR 30111 comparison. Before that,
run 4.12.0 and 4.13.0 for the signed-zero case and one ASan build of
`minEnclosingTriangle` to identify the faulting access. No production code
changes. Acceptance: each reproducer builds against stock headers,
reproduces the stated outcome in an isolated child, and states which
versions were and were not run.

## Limits of this reassessment

- 4.6.0 and 4.11.0 were not rebuilt or rerun in Task 025.
- No sanitizer-instrumented OpenCV was built; sanitizer statements are
  inherited from earlier tasks.
- Float32 `intersectConvexConvex` heap corruption was not reproduced on
  4.10.0 with this task's inputs.
- OpenCV 4.6 and 4.11 values for `approxPolyN` and `minEnclosingTriangle`
  rest on earlier documents.
- The timeout cases show non-return within 4 seconds only.
- Distribution backports are not covered.

## Reproducing

Opt-in, outside the default native test glob and CI:

```sh
python3 scripts/run_risk_reassessment.py self-test
python3 scripts/run_risk_reassessment.py build --output /tmp/rr-410 \
    --backend imgproc
python3 scripts/run_risk_reassessment.py build --prefix /path/to/opencv-5.0.0 \
    --output /tmp/rr-500 --backend geometry
python3 scripts/run_risk_reassessment.py run --probe /tmp/rr-410 --timeout 4
```

Each case runs in its own process group with a hard timeout, core dumps
off, bounded output and the loaded library recorded. The probe is
`tests/native/research/risk_reassessment_probe.cpp`. It is not built by
`alr`, AUnit or `scripts/run_native_tests.sh`.