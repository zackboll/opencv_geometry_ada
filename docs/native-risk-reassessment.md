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
| Self-tests | `run_fit_line_3d_research.py` 8 tests OK; `run_min_enclosing_polygon_research.py` 29 checks OK; `run_risk_reassessment.py` 4 tests OK (9 after the identity correction below) |

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

4.6.0 and 4.11.0 were **not** re-run here. Their results below come from
earlier tasks (labelled).

#### Probe version identity (corrected)

The historical Task 025 results below were produced by the previous probe
version. That version printed `runtime <CV_VERSION>`, but `CV_VERSION` is a
compile-time header macro, so the historical "runtime" field reflected the
headers used to compile, not a runtime query. The loaded library-object path
was also recorded for every case and remains the evidence of which library
provided the symbol. The historical results are **not** retroactively
claimed to have used the corrected query.

The corrected probe prints separate fields: `compile` (`CV_VERSION`),
`runtime` (`cv::getVersionString()`, answered by the linked OpenCV Core
library), `object` (library providing the algorithm symbol) and
`runtime_object` (library providing `getVersionString`). The runner
parses only the leading identity block. A run is valid evidence only when
`compile`, `runtime` and `object` are present and `compile` equals
`runtime`; a mismatch is recorded as `identity_mismatch`, a missing field as
`identity_missing`, a repeated field as `identity_malformed`, and each makes
the runner exit nonzero with the case marked `valid_evidence: false`.

Focused rerun with the corrected probe (benign cases only, 4 second limit,
each in its own child). The dangerous corpus was **not** rerun.

| Build | Cases | Outcome | compile / runtime | Symbol object |
|---|---|---|---|---|
| 4.10.0 (Debian) | `met32_unit_square`, `ict_ngon_grid_p2` returned; `apn_pentagon_3` `not_applicable` | valid evidence | 4.10.0 / 4.10.0 | `/lib/x86_64-linux-gnu/libopencv_imgproc.so.410` |
| 4.14.0 (exact tag) | `met32_unit_square`, `apn_pentagon_3` returned | valid evidence | 4.14.0 / 4.14.0 | `/tmp/geometry021-matrix/install-4.14.0/lib/libopencv_imgproc.so.414` |
| 5.0.0 (exact tag) | `met32_unit_square`, `ict_ngon_grid_p2`, `apn_pentagon_3` returned | valid evidence | 5.0.0 / 5.0.0 | `/tmp/features-008a-install500/lib/libopencv_geometry.so.500` |

The `runtime_object` field named the matching `libopencv_core` in each
build. 4.12.0, 4.13.0, 4.6.0 and 4.11.0 were not rerun with the corrected
probe.

A real mismatch could not be produced: the probes are linked with an rpath,
which takes precedence over `LD_LIBRARY_PATH`. Rejection was instead shown
with a stub probe script that printed `compile 4.14.0` and `runtime 4.12.0`
through the real runner: the case was recorded `identity_mismatch`,
`valid_evidence: false`, and the runner exited 2. The runner self-tests
cover the same paths. This demonstrates the runner logic, not a naturally
occurring mismatch.

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
| `approxPolyN` | Observed numerical behavior: **DOCUMENTABLE_NUMERICAL_RISK**. Overall in-process binding readiness: **INSUFFICIENT_EVIDENCE** | Wrong but finite polygons on unit-scale input; finite inputs can create NaN queue keys (Task 013) that break comparator ordering; no memory fault was observed, which does not establish safety |
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

Assessment. Two conclusions are kept separate.

1. Observed numerical behavior: `DOCUMENTABLE_NUMERICAL_RISK`.
   - Incorrect finite output is reproducible.
   - Unit-scale input can select sentinel intersections (the unit square
     above).
   - A scale bound does not help, because the unit square is already a
     counterexample.
2. Overall synchronous in-process binding readiness:
   `INSUFFICIENT_EVIDENCE`.
   - Task 013 established that finite inputs can generate NaN area keys in
     the native priority queue.
   - The OpenCV comparator uses floating comparisons and does not provide a
     strict weak ordering for NaN keys. That is a potential violation of the
     C++ `priority_queue` heap precondition, which is undefined behavior
     under the C++ library contract.
   - No memory fault was observed in the completed probes. This is not
     evidence of memory safety. Successful native execution without a crash
     does not establish the absence of undefined behavior, and no
     memory-corruption event is claimed here.
   - The NaN-key problem arises before any output postvalidation. Checking
     afterwards whether a NaN candidate was selected is insufficient,
     because insertion into the heap already matters.
   - No input contract that excludes every problematic intermediate heap
     key has been established.

The function therefore is not classified as safely documentable on the
strength of its numerical inaccuracies alone. Binding would also need a
stated "result may not enclose the input" contract, which would make the
operation of little use. Coverage status remains Deferred.

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
(Task 016). Current practical disposition for an unrestricted native
binding: `UPSTREAM_FIX_REQUIRED`.

Subset conclusion: **no useful and sufficiently qualified safe input subset
has yet been established.**

- Unit-scale square inputs can crash for k = 3, so simple
  coordinate-magnitude limits are insufficient.
- The Task 016 and Task 025 corpora show multiple unsafe input families.
- These findings do not mathematically prove that every possible restricted
  input domain is unsafe. They show only that none has been qualified.
- The released native implementations (4.13.0, 4.14.0, 5.0.0) remain
  unsuitable for an unrestricted ordinary in-process Ada binding.
- Upstream PR 30111 is not part of any certified release.

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

- Observed test behavior: in the fixtures, spacing of about 0.03 or more did
  not show the failures. That value is an empirical observation from those
  specific fixtures, not a validated universal safety threshold.
- Documented numerical-conditioning sensitivity: Delaunay predicates lose
  reliability as points approach collinearity or cocircularity, whatever the
  absolute spacing.
- Unproven: safety across arbitrary near-collinear or nearly cocircular
  arrangements. No universal safe minimum spacing has been established.
- Existing possibility: wrong answers, exceptions or non-return remain
  possible in pathological cases, as the README and spec state.
- By contrast, the Float32 `minEnclosingTriangle` hang appears at a plain
  1e-5-side square, and `minEnclosingConvexPolygon` crashes on a unit
  square, so those do not even have a plausible empirical region.
- The accepted risk covers a stateful `Subdiv2D`. The deferred functions
  would be stateless calls on plain arrays, where callers expect them to
  return.

The existing `Find_Nearest` binding is not an exception to the
memory-safety requirements for new operations and is not a precedent for
them. It is unchanged here and not modified by this task. This comparison
does not argue for or against a different policy.

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