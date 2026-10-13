# Task 027: universal Float32 convex polygon intersection

**Status (Task 027C3): implemented, qualified and submitted for pull-request
review; not released.** `Intersect_Convex_Polygons_Extended_Float32` and its
C ABI export `opencv_geometry_intersect_convex_convex_extended_f32` are
integrated (Task 027B), qualified on Linux against seven exact-tag OpenCV
builds with both Core versions (Task 027C1), and certified in hosted CI on
Linux, macOS and Windows MSYS2 (Task 027C2). The final state and evidence
limits are in the "Task 027C2" section at the end.

Earlier status (Task 027A-R2, historical): research commit `717a4866` added
the private compatibility header, the research probe and this document. At
that point the header was qualified on OpenCV 4.10.0 only, there was no
public operation or C ABI export, and the shim did not include the header.

Reading guide: the sections from "Provenance" through "Not done" are the
original Task 027 source review (Phases 0-3), written before anything was
run. Where they say "probable defect", "BLOCKED" or "safety gate not
passed", that was the state of the review at the time. They are historical.
The sections "Task 027A" and "Review corrections" at the end are
authoritative; the open items are listed under "Remaining obligations".

## Provenance (Phase 0)

- Starting `origin/main`: `5b0d47fe01a3a8c4748e2fc9dd6d372a4660671e`
  (PR #25 merged `2026-10-12T00:27:21Z`). No open PRs.
- Branch `feature/027-universal-float32-convex-intersection`, worktree
  `/home/zboll/git/opencv/geometry-task027`, clean at start.
- Baseline: `alr -n build` succeeded; `alr -n -C tests run`: 531 run,
  531 passed, 0 failed, 0 errors.
- Environment: Debian system OpenCV 4.10.0 (`imgproc` backend), gcc 14.2.0,
  GNAT 16.1.0, GNATprove FSF 16.1.0 (Why3 1.8.2+git), alr 2.1.1.
- Not installed here: exact builds of 4.6.0, 4.11.0, 4.12.0 and 4.13.0.
  Candidates found but not yet verified: 4.14.0 and a `5.1.0-dev` build
  under `/var/tmp/geometry-016-pr30111`, and sources for 4.10.0 and 5.0.0
  under `/tmp/opencv-src`.

## Upstream source identities (Phase 2)

Fetched from `raw.githubusercontent.com/opencv/opencv/<tag>`;
`geometry.cpp` is in `modules/imgproc/src` for 4.x and
`modules/geometry/src` for 5.0.0. SHA-256 prefixes:

| Tag | Lines | SHA-256 prefix |
|---|---|---|
| 4.6.0 | 596 | c580bdff8a3c2a67 |
| 4.10.0 | 929 | 2ebda012aaed5566 |
| 4.11.0 | 948 | e2fd96ac9a1ee930 |
| 4.12.0 | 948 | 5cb89d282eaff805 |
| 4.13.0 | 885 | 05ec6cfba5ad82ac |
| 4.14.0 | 885 | 05ec6cfba5ad82ac |
| 5.0.0 | 1032 | a659e962e7bb5693 |

Differences found by `diff` of the algorithm region:

- 4.10 to 4.11 (PR 25725): `intersectConvexConvex_` gains `result_size`;
  the loop gains `&& (int)(result - result0) <= result_size`; after the loop
  `nr > result_size` returns -1 with area -1; the caller allocates
  `n + m + n+m+1+3` instead of `n*2 + m*2 + 1` and returns -1 on a
  negative result. `areaSign`, `between`, `parallelInt`, `inOut`,
  `advance` and `addSharedSeg` are unchanged.
- 4.11 to 4.12: `intersectLineSegments` forms its differences in binary64
  (`(double)a.x - b.x`) instead of binary32 differences widened afterwards.
- 4.12 to 4.14: no algorithm difference. 4.13 and 4.14 have the same hash.
- 4.14 to 5.0.0: same algorithm; only the file layout differs.
- 4.6.0 against 4.10.0: no algorithm difference in the compared region
  other than the header comment. The 4.6 allocation is also
  `n*2 + m*2 + 1`.

A backport must pick the 4.11 or the 4.12+ `intersectLineSegments`
explicitly. They can differ numerically, because the binary32 difference
in 4.11 can round where the binary64 difference does not. This choice is
not yet made.

Dependencies of a self-contained backport: `cv::Point2f`, `cross`,
`ddot`, `cv::Mat` and `flip` for orientation, `pointPolygonTest` and
`contourArea` for the nested case, all public API. No private header is
needed. Notices to keep: the Intel License Agreement header and the
Joseph O'Rourke 1997 copyright block (it requires that the notice not be
removed).

## Native safety review (Phase 3), from source

These conclusions are from reading 4.11.0. I have not run them.

**A. Count and allocation.** The allocation is `2*(n+m)+4` Point2f in a
signed `int`. The existing `Maximum_Input_Count` (`(2**31 - 1 - 4) / 2`)
covers it. Resolved by reuse, provided the new C ABI repeats the check.
An allocation of that size is not worth testing.

**B. Output capacity (4.11 form).** The result region has
`result_size + 3` slots and `result_size = n + m + 1`. The loop continues
only while the count is at most `result_size`, so a new iteration starts
with at most `result_size` written. Within one iteration:

- the first-intersection block writes at most 1, and the `inOut` write
  that follows is then suppressed because the point equals `result[-1]`;
- `inOut` writes at most 1;
- `advance` writes at most 1, and each branch calls it once;
- an overlap iteration skips the intersection block, and `addSharedSeg`
  writes 2 and returns.

The worst case is 3, so the count after an iteration is at most
`result_size + 3`, which fits. The sentinel is slot 0 and is counted.
Established by reading for the 4.11 form. 4.6 and 4.10 have no bound,
which is the known corruption. This depends on my reading of every writer,
so it must be confirmed by a bounded-write assertion in the compatibility
build rather than trusted from this paragraph.

**C. Indexing.**

- `result[-1]` in `inOut`, `advance` and `addSharedSeg` is valid: the
  sentinel is written first and `result` never moves back.
- `result0[nr-1]` is valid because `nr >= 1`.
- `if (result0[nr-2] == result0[0] && nr > 1)` reads `result0[-1]` when
  `nr == 1`. This looks reachable: `nr == 1` occurs when the loop ends, or
  the "parallel and separated" return fires, before any vertex was written
  (disjoint polygons). The read lands in `fp2[m-1]`, since the result
  region follows `fp2` in the same buffer, so it stays inside the
  allocation but depends on adjacent data. If that value equalled the
  sentinel, `nr` would become 0 and the call would return -1, reported as
  non-convergence. The layout is the same in 4.6 and 4.10.
  **Superseded by Task 027A-R2:** the scenario "`nr` becomes 0 and the call
  returns -1" is impossible, because `nr > 1` is false at `nr == 1` and
  prevents the decrement. The verdict "native path excluded" and the
  wording "probable defect" are withdrawn. See "Corrected indexing
  assessment" below.

**D. Float32 arithmetic.**

- `areaSign` forms binary32 differences, widens, and multiplies in
  binary64: finite when coordinates are bounded.
- `intersectLineSegments` casts a binary64 value to `float` before the
  range test on `s` and `t`. For near-parallel segments `s` can be outside
  binary32, and the narrowing is then undefined in C++. `p` is unused when
  the code is `LS_NO_INTERSECTION`, so testing `s` and `t` first and
  casting only when both lie in `[0, 1]` changes no consumed result. This is
  a planned hardening, not yet written or run.
- A magnitude limit of 2**30 would keep binary32 differences finite and
  binary64 products below 2**62. These are paper bounds; subnormal and
  signed-zero behavior is untested.
- The absolute `1e-5` tolerance in `areaSign` is not scale-free. Thin or
  nearly collinear polygons below it are classified as collinear, which can
  cause non-convergence. The accepted conditioning rule is unresolved.

**E. Nested handling.** `pointPolygonTest` calls `cvRound` on the point,
which is undefined outside the 32-bit range. The 2**30 limit used by the
existing Float32 overload keeps every call defined. Resolved on paper.

**F. Sentinel.** `(FLT_MAX, FLT_MAX)` cannot be a vertex or an intersection
point when input magnitudes are at most 2**30, because intersection points
lie on input segments. Resolved on paper.

**G. Termination.** Each loop iteration either returns or increments `aa`
or `ba`: the generic and collinear branches each call `advance` once, and
`advance` increments its counter. The loop ends when `aa >= 2n` or
`ba >= 2m`, or when both have reached `n` and `m`. `aa` and `ba` are reset
once, on the first intersection, so the iteration count is bounded by
about `4(n + m)`. This is a source argument, not a run, and it says the
call returns, not that the answer is correct for poorly conditioned input.

## Obligation status

| | Obligation | Status |
|---|---|---|
| A | Count/allocation | Resolved by existing bound |
| B | Output capacity | Argued for the 4.11 form; needs a checked build |
| C | Indexing | (historical) Superseded: no count change is possible at `nr == 1`; compat tests `k >= 1` first. See "Corrected indexing assessment" |
| D | Float32 arithmetic | Cast fix implemented in compat; conditioning rule still unresolved |
| E | Nested conversions | Resolved on paper with a 2**30 bound |
| F | Sentinel | Resolved on paper with a 2**30 bound |
| G | Termination | Argued from source; not run |

## Consequence for backend selection

(Historical.) This section assumed C was a defect that disqualifies native
4.11+. Task 027A withdrew that premise. The native-versus-compat decision
for 4.11+ is open and rests on the lack of a write bound before 4.11, the
cast order, and vertex-level comparison, not on indexing.

## Not done

(Historical, as of Phase 3.) At that point nothing existed beyond this
review. Since then the compatibility header, native probes, reference
fixtures and 4.10 sanitizer runs were done (Task 027A). Still not done: the
C ABI, the Ada API and tests, GNATprove runs, the OpenCV x Core matrix
(4.6, 4.11 to 4.13, Core 0.3.0 and 0.4.1), macOS and Windows runs, README
and coverage updates, and the PR. The safety gate for public integration
has not been passed; see "Remaining obligations".


## Task 027A: private compatibility implementation

New files, none included by any production file:
`cpp/convex_intersection_compat.hpp` and
`tests/native/research/convex_intersection_compat_probe.cpp`. No change to
production Ada, the C++ shim, the C ABI, README or coverage.

### Recovered OpenCV builds

Task 026 left exact-tag builds in `/var/tmp/geometry-026`. Versions were
checked from `version.hpp` and from the probe's identity line (compile
`CV_VERSION`, runtime `cv::getVersionString()`, and the object that
`dladdr` reports), not from directory names.

| Prefix | Verified | Notes |
|---|---|---|
| `install-rel-4.10.0` | 4.10.0 | Release, `core,imgproc` |
| `install-asan-4.10.0` | 4.10.0 | library built with `-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1`; 54 undefined `__asan`/`__ubsan` symbols in `libopencv_imgproc`, 0 in the release build |
| `install-4.11.0`, `-4.13.0`, `-5.0.0` | 4.11.0, 4.13.0, 5.0.0 | smoke runs and one comparison only |
| `prefix-4.6.0` | headers say 4.6.0 | no `libopencv_imgproc` found there, so **4.6 was not run** |

`install-4.12.0`, `-4.14.0` and `-asan-4.13.0` exist and were not used.

### Corrected indexing assessment

The earlier text called `result0[nr-2]` a probable defect. Separated:

1. Invalid logical result indexing: **yes**. With `nr == 1`, `result0[-1]`
   is not a result element, and the index is read before `nr > 1` is tested.
2. Access to an unintended earlier element: **yes, by layout**. Upstream
   has `result = fp2 + m` in one `AutoBuffer`, so `result0[-1]` is
   `fp2[m-1]`, a polygon vertex.
3. Access outside the allocation: **no, by source reading**. That element
   is inside the same block for every `m >= 2`, the only case that reaches
   the code. I found no path in 4.10 that reads outside the block.
4. Uninitialized data: **no**; `fp2` is filled by `convertTo` first.
5. Undefined pointer arithmetic: formally yes, in practice benign, since
   `result0 - 1` stays inside the same array object.

It is not a heap-buffer-overflow, and no run showed one. The `nr == 1`
state is reachable: `disjoint_nr1`, `disjoint_normal_exit`,
`disjoint_normal_exit_heap` and `nested_heap_buffer` all end with only the
sentinel written. The last two have `n + m` above 136, so the native
`AutoBuffer` is a heap block. The 4.10 build with an ASan/UBSan-instrumented
OpenCV ran these native calls with no report.

**No result change is possible at `nr == 1` (Task 027A-R2 correction).**
The upstream statement is `if (result0[nr-2] == result0[0] && nr > 1) nr--;`.
C++ evaluates the left operand first, so `result0[-1]` is read and compared.
But the right operand `nr > 1` is then false, so the whole condition is
false whatever the comparison gave, and `nr` is not decremented. The
comparison result is discarded. My earlier text said the comparison "could
change a result if `fp2[m-1]` equalled the sentinel"; that was wrong, and
the "returns -1" scenario in the Phase 3 review cannot occur. Three things
must be kept apart:
- *Logical indexing*: `result0[-1]` is not an element of the logical result.
  That is a code-quality defect.
- *Pointer validity*: `result0 - 1` is `fp2 + m - 1`, a valid element
  address of the same array object (for `m >= 2`). The pointer is valid.
- *Allocation bounds*: the read stays inside the single `AutoBuffer` block.
  I observed no out-of-bounds access, no uninitialized read and no
  sanitizer report in any run, and make no claim of a fault.
The hardened tail avoids even the harmless read by testing `k >= 1` first.
**This finding does not exclude the 4.11+ native path**, and the earlier
statement that it does is withdrawn. What separates native from compat is
the lack of any write bound in 4.6/4.10 and the cast-before-range-test
order. The 4.11+ native decision is left to a later milestone.

Compat tail: it works on a copy with the sentinel dropped (`e`, `k` =
count - 1) and tests `k >= 1 && e[k-1] == e[0]`. Upstream after its shift
tests `result0[nr-2] == result0[0]`, the same two elements for `nr >= 2`.
For `k == 1` the single vertex equals itself and is dropped, as upstream
does when its expression is true. I did not prove equivalence for every
`nr`; vertex-level agreement was checked on the cases below.
`result0[nr-1]` is safe because `count >= 1`, and the loop is skipped for
`k == 0`.

### Compatibility choices

- Structure from 4.11.0 (`result_size`, capacity `n + m + n+m+1 + 3` =
  `result_size + 3`, a negative return on overflow).
- `intersectLineSegments` expressions from 4.12.0 (binary64 differences),
  identical in 4.13.0, 4.14.0 and 5.0.0. This is a later numerical
  implementation than 4.11.0 and is not bit-for-bit equal to 4.10 or 4.11.
- Departures from upstream, also listed in the header:
  1. Writes go through `scratch::push`, which refuses a write past the
     capacity and flags it. Refusals observed: 0.
  2. `result[-1]` is `scratch::last()` after the sentinel; the tail test is
     reordered as above.
  3. Counts are checked in 64-bit arithmetic before allocation, after a
     finite and magnitude-at-most-2**30 envelope check.
  4. `intersect_line_segments` rejects non-finite `denom`, `s` and `t`, and
     narrows to `float` only after `s` and `t` are in `[0, 1]` and the
     binary64 point is finite and at most `FLT_MAX`; otherwise it reports a
     numeric failure instead of clamping.
  5. The post-loop bound also covers the early returns.
  6. An iteration cap of `4*(n+m)+8`, reported as non-convergence. It was
     not reached in any run; a hit would mean the termination argument is
     wrong.
  7. `flip` is `std::reverse`; early-return results drop the sentinel.


### Memory-safety obligations (compatibility code)

- Allocation: `result_size + 3 = n + m + 4` slots, plus input copies of `n`
  and `m`; guarded by `n + m <= (2**31 - 1 - 4) / 2`. I did not run large
  allocations.
- Writes per iteration: at most 3, by the argument in the source comment
  (first-intersection push, `in_out`, `advance`, or `add_shared_seg`).
  Measured maximum was **1** over 15000 convex-sweep pairs and **2** over
  60000 random non-convex pairs. 3 was never observed, so the bound rests
  on the argument and the last slots are unexercised.
- Early returns: overlap writes at most 2 in its iteration; the
  separated-parallel return writes nothing in its iteration.
- Result indexing: sentinel-first keeps `count >= 1`.
- Count arithmetic: `int64_t` throughout.
- Finite conversions: as in departure 4. The remaining narrowing is
  `(float)area`, checked with `isfinite`. With coordinates at most 2**30
  the binary64 area is far below `FLT_MAX`.
- Native dependencies: `pointPolygonTest` runs only on the nested path and
  applies `cvRound` to a float, defined below 2**31; the envelope gives at
  most 2**30. I read the 4.10 and 5.0 source for this; I did not read
  4.11 to 4.14 exhaustively. `contourArea` and `Point2f::cross/ddot` are
  public.
- Termination: the argument under "G. Termination" above, plus the cap. Not
  formally proved.

### What was run

Probe `convex_intersection_compat_probe.cpp`: 31 named cases, the
`segment_extreme` case, seeded `sweep` and `chaos` runs. One process per
case, `timeout -s KILL`, `ulimit -c 0`, output through `head`.

*Task 027A-R2 changes to the probe.* (1) Identity: compile-time and
runtime versions are printed on separate lines. `dladdr` plus `realpath`
then finds the file that provides `cv::getVersionString`,
`cv::pointPolygonTest`, `cv::contourArea` and, for `native` runs,
`cv::intersectConvexConvex`. Each file must be a `libopencv_` object whose
resolved name ends in `.so.<CV_VERSION>`, the algorithm symbols must not
come from Core, all files must share one directory, and
`T027_EXPECT_LIBDIR` pins that directory. Any failure prints
`IDENTITY REJECTED` and exits 65 before any case. Checked: a wrong
`T027_EXPECT_LIBDIR` exits 65. The imgproc/geometry identity comes from its
own file name, not from Core. (2) Expectations: every well-formed convex
case is `area_ref`, which now requires status ok, an exact or bounded vertex
count, the reference area, and an output polygon whose own shoelace area
equals the reported area. Contact and sub-tolerance cases require status
ok, a pinned count, and area 0. The hexagon pins all 12 vertices, count 12,
and area within 1e-6 of the reference. (3) The convex sweep reports
`compared`, `non_ok`, `early_skipped` and `tiny_ref_skipped` separately and
prints `accuracy_claim SUPPORTED` only if `non_ok` is 0 and at least one
pair was compared; otherwise it exits non-zero.

- Release build (g++ 14.2.0, `-O1 -Wall -Wextra -Werror`) on OpenCV 4.10.0:
  32 of 32 expectations met.
- Compat code compiled with `-fsanitize=address,undefined,float-cast-overflow
  -fno-sanitize-recover=undefined -fno-omit-frame-pointer -g -O1`, linked to
  (a) release OpenCV 4.10.0: 32 of 32, no report; and (b) the 4.10.0
  library built with `-fsanitize=address,undefined`: 32 of 32, no report.
  In (a) only the probe and the compat header are instrumented. In (b)
  OpenCV 4.10 imgproc and core are too. Nothing newer than 4.10 was
  instrumented.
- Sweeps: `sweep` seeds 1, 2, 3, 11, 12 x 3000 convex pairs; `chaos` seeds
  1, 2, 3 x 20000 non-convex pairs. Release and both sanitizer builds
  printed identical numbers: 0 refused writes, 0 over-capacity, 0 numeric
  failures, 636/659/668 non-convergence reports in the chaos runs (so the
  path is reachable and controlled). Largest relative area difference from
  the independent binary64 Sutherland-Hodgman reference: 1.6e-7.
- Smoke only: the 32 cases compiled and ran (exit 0) against 4.11.0,
  4.13.0 and 5.0.0 (re-run in Task 027A-R2 with the stricter expectations
  and provider checks: 32 of 32 each; `pointPolygonTest`, `contourArea`
  and `intersectConvexConvex` resolved to `libopencv_imgproc.so.<version>`,
  or `libopencv_geometry.so.5.0.0` for 5.0.0). That is not qualification of
  those versions.

Compat against the independent reference, tolerance 2e-5 relative: the
fractional triangle and square, decimal-0.1 triangle and square, all four
winding combinations (same polygon up to reversal), nested True and False,
swapped nesting, large coordinates near 2**29, signed zero, and a 40-gon
pair met it. Contact cases returned 3, 1 and 2 vertices with area 0; native
4.10 returned 4, 2 and 3 because it leaves the sentinel in the early-return
result.

### Reproducers

- **Rounded integer hexagon: exact input recovered** from the AUnit test.
  Native 4.10.0 returned 14 vertices, including extra points such as
  `(-15767146, -1608887.62)` and `(15750646, 1762985.25)` that lie close to
  true vertices. The compat code returned 12, with the same area
  (5.38046559e+14). Native **4.13.0** returned exactly the same 12 vertices
  as compat, in the same order. So 4.10's 14 is the inconsistent-predicate
  behavior already documented, not a sentinel effect, and compat agrees
  with 4.13 here. The 4.6 overflow (14 points into a 13-slot region) was
  not re-run: no 4.6 library. The 4.10 native call returned without a
  sanitizer report.
- **62/61-vertex pair: not recoverable.** No coordinates exist in the
  repository, git history or the research files I searched. The
  `ngon_62_61_standin_*` cases are regular n-gons that Task 025 already
  showed do not reproduce the corruption on 4.10; they prove nothing about
  the original. **This reproducer is unchecked.**

### Extreme segment

`segment_extreme`: edges (0,1000)-(1e9,1000) and (0,0)-(1000,1e-40) give a
binary64 `s` of about 1e37 and an unused point coordinate of about 1e46.
The hardened function returned `LS_NO_INTERSECTION`, no numeric flag, point
unmodified. The upstream order (`segment_extreme_upstream`) printed
`cast inf`. No sanitizer report was expected: see "Review corrections"
below, where the earlier explanation of this result is corrected.

### Remaining obligations before any public integration

1. Compare compat against native vertex by vertex on every case and every
   available version (done above only for the hexagon).
2. Run the probe on 4.6.0 (needs a library build), 4.12.0 and 4.14.0.
3. Obtain or construct the original 62/61 pair, or state publicly that it
   could not be recovered.
4. Establish the accepted conditioning domain: the absolute `1e-5`
   tolerance in `area_sign` and what convex input avoids non-convergence.
   The probe shows non-convergence is reported on non-convex input; it does
   not define the safe convex domain.
5. ~~Read 4.11 to 4.14 `pointPolygonTest` for the envelope claim.~~ Done in
   Task 027A-R2 for the direct `cvRound` input only (see "Review
   corrections" item 3); broader numerical qualification is not claimed.
6. Decide native versus compat on 4.11+ from item 1.
7. Everything in the Task 027 "Not done" list: C ABI, Ada API, AUnit
   tests, SPARK, the version and Core matrix, macOS and Windows, hosted
   CI, the PR.

### Disposition for this milestone

The compatibility header exists, compiles warning-free against 4.10.0, and
met all focused expectations in release and under both sanitizer
configurations. It is **not** ready for public integration: items 1 to 4
and 6 are open. The research files are committed and pushed (`717a4866`
and the corrective commit after it); no PR has been opened.


## Review corrections (Task 027A-R)

These supersede any earlier wording in this file.

1. **`float-cast-overflow` scope.** `-fsanitize=float-cast-overflow`
   checks floating-point to **integer** conversions. It does not check a
   `double` to `float` narrowing, so its silence on `segment_extreme_upstream`
   says nothing about that cast. The hardened code therefore does not rely
   on any sanitizer: `intersect_line_segments` tests that `denom`, `s`, `t`
   are finite, that `s` and `t` are in `[0, 1]`, and that the binary64 point
   is finite and at most `FLT_MAX` in magnitude, **before** it narrows to
   `float`. Whether the upstream `double` to `float` out-of-range cast is
   undefined behavior is not decided here: the standard's rule depends on
   whether the target type can represent the value, and binary32 has
   infinity. The observed result was `inf`. I make no undefined-behavior
   claim and no sanitizer claim about it. The explicit checks stay because
   a silent `inf` would otherwise reach vertex output and orientation tests.
2. **`nr == 1` upstream.** The read of `result0[-1]` is an invalid logical
   index that lands on preceding initialized storage (`fp2[m-1]`) in the
   same allocation. The following `nr > 1` is false, so `nr` is not changed
   and no result can differ. It is not an observed heap overflow, and no
   run reported one. See "Corrected indexing assessment".
3. **The 2**30 envelope.** It protects the **direct** `cvRound` inputs of
   `pointPolygonTest` (`cvRound(pt.x)`, `cvRound(pt.y)`, computed
   unconditionally at function entry). It is not a claim about other arithmetic in
   `pointPolygonTest`, `contourArea` or the intersection loop; those are
   assessed separately above (finite checks, binary64 magnitudes) and
   remain open obligations where marked.
4. **Non-convergence is a documented result.** On non-convex or
   badly conditioned input the function returns `non_convergence`
   in a controlled way (636, 659 and 668 times in the chaos runs). That is
   an intended result, not a safety failure. What would be a failure is a
   refused write, a write past capacity, a crash, a hang or a sanitizer
   report; none was observed.
5. **62/61-vertex fixture.** The original pair was **not recovered**. The
   `ngon_62_61_standin_*` cases are unrelated regular polygons and do not
   reproduce, represent or substitute for it.
   *Source inspection (Task 027A-R2).* In the fetched `geometry.cpp` of
   4.11.0, 4.12.0, 4.13.0 and 4.14.0 the body of `cv::pointPolygonTest` is
   byte-identical (same hash over the function), and the body in 5.0.0 is
   identical to 4.14.0 (empty `diff` of the extracted functions). In all of
   them the only float-to-integer conversion on the caller's point is
   `Point ip(cvRound(pt.x), cvRound(pt.y));` (line 109 in 4.x, line 59 in
   5.0.0), executed before the contour is looked at. The compat code calls
   it only with vertices already inside the 2**30 envelope. This confirms
   the direct `cvRound` behavior only; it is not a numerical qualification
   of the rest of the function or of 4.11-4.14 and 5.0 intersection.
6. **Research probes are not default tests.** `scripts/run_native_tests.sh`
   compiles only `tests/native/*.cpp`; the probe lives in
   `tests/native/research/`. It is not referenced by any `.gpr`, Alire
   manifest, script or workflow, and the header is included only by the
   probe.

## Task 027B: integration of `Intersect_Convex_Polygons_Extended_Float32`

Status: **implemented and locally qualified on OpenCV 4.10.0; not released,
not certified across the version matrix (Task 027C), no PR.** The research
sections above are historical.

### Interfaces

Public Ada, in `OpenCV.Geometry`:

```ada
function Intersect_Convex_Polygons_Extended_Float32
  (Left, Right : Float32_Point_Array; Handle_Nested : Boolean := True)
   return Convex_Polygon_Intersection;
```

Raw C ABI (`cpp/opencv_geometry_shim.h`), imported in
`OpenCV.Geometry.Internal.C_API` as `Intersect_Convex_Convex_Extended_F32`:

```c
opencv_geometry_status opencv_geometry_intersect_convex_convex_extended_f32(
    const opencv_geometry_point_f32 *left_points,  int32_t left_count,
    const opencv_geometry_point_f32 *right_points, int32_t right_count,
    int32_t handle_nested,
    opencv_geometry_point_f32 *out_vertices, int32_t out_capacity,
    int32_t *out_count, float *out_area);
```

The existing integer and Float32 overloads, their exports and their
restrictions are unchanged. No existing test expectation was edited.

### Execution path and backend

Ada checks at least three vertices, a safe combined count, finite
coordinates and magnitude at most 2**30, then calls the export. The export,
for every caller: clears the error; zeroes `*out_count` and `*out_area`;
checks pointers, counts (3 .. 4096 each), the selector (0 or 1) and the
capacity; copies the points to `std::vector<cv::Point2f>`; runs
`validate_strictly_convex_f32` (`cpp/strict_convex_validation.hpp`) on each
polygon; runs `opencv_geometry_compat::intersect_convex_convex_f32`; maps
the status; checks the whole result (count at most `left_count +
right_count`, area finite and nonnegative, every vertex finite and not the
sentinel, count at most the capacity); and only then copies and publishes.
Exceptions are translated by the existing `translate_current_exception`.

The backend is the private compatibility engine on **every** OpenCV version;
the export never calls `cv::intersectConvexConvex`. In the shim the only two
call sites of that function are in `opencv_geometry_intersect_convex_convex`
and `..._f32` (checked with grep), not in the extended export. The native
calls the engine can reach are `cv::pointPolygonTest` and `cv::contourArea`
on its nested-polygon path, with inputs inside the 2**30 envelope.

The implementation is the same on every version, but results are **not**
claimed to be identical across versions: the nested path uses the installed
OpenCV's functions, and cross-version numerical qualification is pending
(Task 027C).

Task 027B-R1 corrections: the export now zeroes each non-null output before
rejecting a missing one, and the Ada function rejects more than 4096
vertices per polygon before scanning, packing or allocating.

### Strict convexity validation

Written for this project; no upstream code. For each directed edge
`(p[i], p[i+1])` and every other vertex `p[k]`, the orientation must be
provably nonzero and of one sign for the whole polygon. A vertex strictly on
one side of every edge line makes each edge line a supporting line that
meets the vertex set only in that edge's endpoints. So every edge joins
adjacent hull vertices, every vertex is a hull vertex, and the n distinct
directed edges are the n hull edges in one rotational sense: a simple convex
polygon traversed once, in either winding. Repeated vertices, redundant
collinear vertices, concave corners, bowties, stars and repeated traversals
give a zero or mixed-sign orientation. `cv::isContourConvex` is not used.

The sign is Shewchuk's error-bounded filter for the double formula
`(a-c)x(b-c)`: binary32 widens exactly to binary64, and a determinant larger
than `(3 + 16 eps) eps (|detleft| + |detright|)` has a proven sign. An
undecided case is **rejected**, never guessed. At magnitudes up to 2**30 the
formula cannot overflow, and nonzero binary32 differences cannot underflow
in binary64. I did not machine-check this argument; it is a paper argument
plus the tests below.

Conditioning policy: each (edge, vertex) orientation is also computed the
way the engine's `area_sign` does, from binary32 differences, and must have
the same sign and a magnitude above `1.0E-4` (10 times the engine's
absolute `1.0E-5` tolerance); so must each turn between consecutive edge
vectors. This is a **policy, not a convergence proof**. It rejects features
below that scale (for example a square of side 1.0E-3). Orientation tests
*between* the two polygons cannot be checked per polygon; only the engine's
controlled non-convergence and numeric-failure statuses cover them.

Cost is O(n**2) orientation evaluations per polygon, about 1.7e7 at the
limit of 4096 vertices; larger inputs are rejected by count before any work.
This is a **new input limit**: the older overloads accept more vertices.


### Accepted domain, status mapping and caller obligations

Each polygon: 3 to 4096 vertices; finite coordinates of magnitude at most
2**30; simple, strictly convex, traversed once, either winding, any Ada
lower bound; orientations above `1.0E-4`. There is no power-of-two-grid
requirement. Output: at most `left + right` vertices, indexed `1 ..
Vertex_Count`, in the engine's order, not normalized or deduplicated, no
sentinel, area finite and nonnegative. Contact results can have one to three
vertices and area 0 and need not form a polygon. A failed call raises
`OpenCV_Error`, returns no partial result and, at the C ABI, leaves
`*out_count` and `*out_area` at 0.

Input, validation, non-convergence, numeric-failure, internal-bound and
capacity failures return `OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT` with a
specific message. `cv::Exception`, `std::exception` and unknown exceptions
map to `ERROR_OPENCV`, `ERROR_STD` and `ERROR_UNKNOWN`. Ada raises
`OpenCV_Error` for every non-success status; its range and finiteness checks
run with validity checks suppressed, so NaN and infinities raise
`OpenCV_Error`, not `Constraint_Error`.

The export cannot discover whether a non-null pointer refers to the stated
amount of memory. Callers must provide readable `left_count` and
`right_count` points and a writable buffer of `out_capacity` points. The
shim reads exactly the stated counts and writes at most `out_capacity`
points, and nothing when the result does not fit.

### Local results (OpenCV 4.10.0, g++ 14.2.0, GNAT 16.1.0)

| Check | Result |
|---|---|
| `alr -n build` | success |
| `alr -n -C tests run`, baseline | 531 of 531 (start of Task 027) |
| `alr -n -C tests run`, final | **542 of 542**; 11 new AUnit tests |
| validation profile | 542 of 542; no `Constraint_Error` |
| release profile again | 542 of 542 |
| `scripts/run_native_tests.sh` | all 4 native programs pass under ASan+UBSan, including the new `extended_convex_intersection.cpp` |
| research probe, exact-identity checks | 32 of 32; sweep `accuracy_claim SUPPORTED` |
| `gnatformat` | applied to the test file (only added lines changed); library files already conform |

New AUnit coverage: fractional triangle, square and 0.1 overlaps (the old
overload still rejects the triangles); integer-valued and power-of-two-grid
input equal to the old overload; four winding combinations and differing
nonzero lower bounds; nested with both selectors, disjoint, shared-edge and
vertex contact; a thin sliver and a 5.0E8 polygon; the exact recovered
rounded hexagon (all 12 vertices and the area); empty, one-, two-vertex,
duplicate, collinear, concave, bowtie, star, pentagram and repeated-traversal
input; NaN, +/-Inf and out-of-envelope coordinates; a tiny and a
near-collinear polygon; 4097 vertices; and the raw export (null count, area,
points and output pointers, negative and oversized counts, invalid selector,
negative capacity, concave, repeated, bowtie, repeated traversal, NaN,
out-of-envelope, a valid call with guard slots proving nothing is written
beyond the result, capacity equal to and one below the count, and a disjoint
pair with zero capacity).

**Not reproduced:** a deterministic non-convergence or numeric failure from
the production export. The 4000-pair native sweep had 0 controlled failures.
Non-convergence was reproduced only in the research probe's chaos sweep, on
non-convex polygons that the production validator now rejects first. So the
status mapping for those two cases is untested at the production export.

### Sanitizer coverage

`extended_convex_intersection.cpp` includes the shim source and is built
with `-fsanitize=address,undefined -fno-sanitize-recover=undefined`, so the
export, the validator and the engine are instrumented, with exact-size heap
buffers. It ran against (a) the system OpenCV 4.10.0 and (b) the 4.10.0
library built with ASan/UBSan (`/var/tmp/geometry-026/install-asan-4.10.0`,
libraries confirmed with `ldd`): no report either way. The Ada test program
itself is not sanitizer instrumented.

### Cross-version smoke results (not qualification)

The same native program built against `/var/tmp/geometry-026` prefixes for
4.11.0, 4.12.0, 4.13.0, 4.14.0 and 5.0.0 (providers confirmed with `ldd`:
`libopencv_imgproc.so.<v>`, `libopencv_geometry.so.500` for 5.0.0) printed
PASS, each with 4000 of 4000 sweep pairs succeeding. The Ada suite ran only
against 4.10.0. 4.6.0 was not run: no imgproc library exists. Other Core
releases, macOS and Windows were not run.

### Research probe

`convex_intersection_compat_probe.cpp` now requires the exact module
(`imgproc` for 4.x, `geometry` for 5.x) and the exact version suffix in each
resolved library file name, with the Core and module directories equal.

### SPARK

No SPARK-mode code was added or changed, and the reused helpers
(`Is_Safe_Input_Count`, `Output_Capacity`) are unchanged. GNATprove was
**not** rerun, so no new proof result is claimed; the recorded baseline is
277 of 277.

### Remaining Task 027C obligations

1. The OpenCV 4.6 to 5.x and Core 0.3.0/0.4.1 matrix with the Ada suite;
   4.6 needs a library build.
2. macOS and Windows runs.
3. The original 62/61-vertex fixture remains unrecovered.
4. A deterministic production-export test for non-convergence and numeric
   failure, if a reproducible input exists.
5. Whether to relax the 4096 vertex limit with an O(N log N) validator.
6. Native-versus-compat dispatch is deliberately not done.
7. README, release notes and the PR.

## Task 027C1 — Linux Exact-Tag Qualification

Result: **Linux matrix qualified on Geometry source
`0ec378f1a8927029b103cd1775c49575965649f1`.** Windows, macOS beyond hosted CI,
and the documentation gate remain (Task 027C2). Every number below comes from
a program that ran in this task. Logs are outside the repository
(`/var/tmp/geometry-027c1/logs`); the matrix is `qualification-027c1-matrix.csv`.

### Identity

Geometry source for every cell: `0ec378f1a8927029b103cd1775c49575965649f1`
(a fresh `git clone -s` plus `checkout` of that SHA in each cell; the SHA was
asserted before building). Core 0.3.0 is
`0e2753be8ea05fc972ec452c32b975f9e9b3912f` and Core 0.4.1 is
`386c5360ac51f2b62e522853d94290aec4ee14a0`, selected with
`alr pin opencv_core --use=../core` as in the CI workflow, and verified by the
tests crate's `OPENCV_CORE_ALIRE_PREFIX` checkout SHA in every cell.
Toolchain: alr 2.1.1, g++ Debian 14.2.0-19, GNAT FSF 16.1.0 (gnatprove FSF
16.1.0, Why3 1.8.2+git).

| OpenCV | Prefix | Source identity |
|---|---|---|
| 4.6.0 | `/var/tmp/geometry-027c1/install-4.6.0` (built in this task) | tarball sha256 `1ec1cba6…2239277`, embedded commit `b0dc4741…`, equal to the peeled `4.6.0` tag on github.com/opencv/opencv |
| 4.10.0 | `/var/tmp/geometry-026/install-rel-4.10.0` | sha256 `b2171af5…`, commit `71d3237a093b` |
| 4.11.0 | `/var/tmp/geometry-026/install-4.11.0` | sha256 `9a7c11f9…`, commit `31b0eeea0b44` |
| 4.12.0 | `/var/tmp/geometry-026/install-4.12.0` | sha256 `44c106d5…`, commit `49486f61fb25` |
| 4.13.0 | `/var/tmp/geometry-026/install-4.13.0` | sha256 `1d40ca01…`, commit `fe38fc608f6a` |
| 4.14.0 | `/var/tmp/geometry-026/install-4.14.0` | sha256 `ee8fb9b3…`, commit `0654a42e1921` |
| 5.0.0 | `/var/tmp/geometry-026/install-5.0.0` | sha256 `b0528f5a…`, commit `40738fb16ced` |

The Task 026 prefixes were reused, not rebuilt. Their tarball hashes and
embedded commits are as recorded on disk; I did not re-verify them against
github. `prefix-4.6.0` under Task 026 holds only copied system headers and was
not used. All prefixes are Release, shared, `BUILD_LIST=core,imgproc`
(`core,imgproc,geometry` modules as built for 5.0.0), IPP off.

**OpenCV 4.6.0 build:** configured with the same options as the Task 026
builds (Ninja, Release, shared, core and imgproc only, tests, examples, docs
and apps off), built with 16 jobs, installed to its own prefix. No OpenCV
source was patched and no toolchain workaround was needed. Smoke result: the
4.6.0 headers define 4.6.0; `libopencv_imgproc.so.4.6.0` resolves
`libopencv_core.so.406` in the same prefix; the runtime version string is
4.6.0.

### Matrix procedure and cell checks

`scripts/run_linux_matrix_027c1.sh <opencv> <core>` runs one cell in a fresh
directory with `PKG_CONFIG_LIBDIR` set to the exact prefix, `PKG_CONFIG_PATH`
unset and `LD_LIBRARY_PATH` set to the prefix library directory. It checks,
per cell: both SHAs; the generated `config/opencv_geometry_install.gpr`
(version, `-L` prefix, and `-lopencv_imgproc` for 4.x or `-lopencv_geometry`
for 5.x); the shared libraries the test program actually loads
(`LD_DEBUG=libs`, resolved with `realpath`, all required to be inside the
prefix, with Core and the backend module present); the release-profile suite;
`scripts/run_native_tests.sh`; and last the validation-profile suite, after
which it restores the release profile. The 5.0.0 cells also load
`libopencv_flann.so.5.0.0` from the same prefix.

### Matrix: 14 of 14 cells

All cells: Geometry `0ec378f1…`, `config_ok=1`, `loaded_ok=1` (all libraries
from the selected prefix), release `542/542` with 0 failed assertions and 0
unexpected errors (exit 0), validation `542/542`, 0 and 0 (exit 0), native
tests exit 0 with 0 AddressSanitizer or UBSan reports, 0 `CONSTRAINT_ERROR`
lines. Correction (Task 027C2): the CSV's `native_pass=3` counted lines
beginning `PASS`, not successful programs. All four native programs ran in
every cell; see [Task 027C2](#task-027c2--runner-correction-and-final-certification).

| OpenCV \ Core | 0.3.0 | 0.4.1 |
|---|---|---|
| 4.6.0 | pass | pass |
| 4.10.0 | pass | pass |
| 4.11.0 | pass | pass |
| 4.12.0 | pass | pass |
| 4.13.0 | pass | pass |
| 4.14.0 | pass | pass |
| 5.0.0 | pass | pass |

The native suite built here is the one in `scripts/run_native_tests.sh`
(closest-ellipse equivalence, Subdiv2D fault injection and equivalence, and
the extended raw C ABI program), compiled with ASan and UBSan against the
cell's own prefix. The sanitizer instrumentation covers the shim and the
private headers; the OpenCV libraries of these cells are ordinary release
builds, apart from the separate ASan/UBSan 4.10.0 library below. No failing
cell occurred, so no comparison with `main` was needed. The independent Core
0.4.1 consumer step of the hosted workflow (`tests/compatibility`) was not
part of this local runner.


### Cross-version numerical comparison

`tests/native/research/extended_cross_version_compare.cpp` includes the shim
source and runs 84 inputs, each with `Handle_Nested` true and false (168
lines), through the **production export** against each exact-tag prefix. It
prints the status, count, area bits, every vertex as binary32 hex in result
order, whether the engine reached its nested path, and the area of an
independent binary64 Sutherland-Hodgman clip. Identity lines record the
compile version, the runtime version and the shared object providing
`getVersionString`, `pointPolygonTest` and `contourArea`; each was the prefix's
`libopencv_core` or `libopencv_imgproc` (`libopencv_geometry` for 5.0.0) of
the same version. The native `intersectConvexConvex` is never called.

Corpus: fractional triangles in both orders, triangles near 0.1, a fractional
square overlap, all four winding combinations, nested polygons with the outer
first, inner first and reversed, both nested selectors, disjoint, shared edge
(full and partial), single-vertex contact, the recovered rounded hexagons in
both orders, a thin 100 by 0.01 polygon, a polygon near 5e8, a polygon whose
maximum coordinate is exactly 2**30, 24 n-gon pairs (3 to 33 vertices) and
40 pairs with crossing boundaries.

Findings:

- **Exact match across all seven versions.** The 168 result lines (status,
  count, area bits, vertex bits and order, nested-path flag, reference) are
  byte-identical for 4.6.0, 4.10.0, 4.11.0, 4.12.0, 4.13.0, 4.14.0 and 5.0.0
  (the same md5 of the body). This establishes bit-identity **over this corpus
  on these builds**, not in general. Categories C (version-dependent nested
  behavior) and D (different contact vertex order or count) were not observed.
- 168 of 168 returned success; no non-convergence (E) in the corpus.
- 26 inputs (all with `Handle_Nested` true) reached the nested path, where the
  engine calls the installed `pointPolygonTest` and `contourArea`; they were
  identical across versions too.
- Against the binary64 reference, the worst relative area error over the
  results that are non-empty or have nesting off was 5.6e-8
  (`cross_19_32_18`); none exceeded 1e-5. The 26 nested-input results with
  `Handle_Nested` false are empty by design while the reference area is the
  full overlap, so they are not area errors.
- The recovered hexagons give the same 12 vertices and area 5.38046559e14
  (reference 5.38046573e14) on every version; thin, large and 2**30-edge cases
  agree with the reference at binary32 rounding level.
- Contact: shared edge returned 3 vertices, partial shared edge 2, vertex
  contact 1, all with area 0 and the same bits on every version. They are
  contact points, not polygons.
- An early run misreported four nested/winding cases as errors because my
  reference helper reversed a vector in place; I fixed the helper and reran
  everything. The engine's output did not change.


### 4096-vertex contract

`extended_boundary_and_search.cpp boundary` drives the production export, built
with ASan and UBSan against the ASan/UBSan 4.10.0 library, and also in release:

- 3-vertex input accepted.
- 4096-gon pairs, counterclockwise and clockwise, circumradius 300, 1000,
  1e5 and 1e8: accepted with 4096 vertices out, 0.11 to 0.19 s per call in
  release and about 0.2 s under ASan (the O(n**2) validator). Circumradius 5
  and 170: rejected by the validator as below the 1e-4 conditioning limit,
  because 4096 vertices on a small circle have tiny turns. **Acceptance of a
  4096-gon depends on its geometry and size, not on the count alone.**
- A 4096-gon against a triangle: accepted in 0.04 s.
- 4097, 5000 and 100000 vertices on either side: rejected with the 4096
  diagnostic in well under 1 ms, before any validation, with count and area 0.
- The Ada preflight rejection of 4097 before the coordinate scan and any
  allocation is covered by the Task 027B-R1 AUnit test (a NaN inside the
  oversized array still gives the 4096 diagnostic), which passed in all 14
  cells.

Timing is a measurement on this machine, not a guarantee.

### Non-convergence investigation

Two bounded, deterministic campaigns used the production export, so strict
validation always ran first. Neither found a failure.

| Campaign | Pairs | Engine reached | Non-convergence | Numeric failure | Validator rejected |
|---|---|---|---|---|---|
| 6 modes: near-equal, near-parallel, 1e-1 vs 1e6 extents, near contact, 1e7 extents, near tangency | 60000 | 60000 | 0 | 0 | 0 |
| thin rectangles (length to 1e4, width 1e-3 to 1, tilt 1e-7 to 1e-2) | 200000 | 200000 | 0 | 0 | 0 |

Rerun under ASan/UBSan against the ASan/UBSan 4.10.0 library (60000 and
100000 pairs): same outcome, no sanitizer output. **No production-domain
reproducer was found**, so no regression test was added. The `non_convergence`
and `numeric_failure` mappings in the export are verified only by reading the
source and are untested at the production boundary. The validator's 1e-4
margin may contribute, but I have not shown that, and the search is not
exhaustive. The validator was not changed.

### GNATprove

Run in a disposable clone of `0ec378f1…` with Core 0.3.0 pinned and OpenCV
4.14.0, with the invocation documented in `docs/release-0.2.0.md`:
`alr -n -C tests exec -- gnatprove -P opencv_geometry.gpr
--subdirs=task017-proof -j2 --level=2 --timeout=30 --checks-as-errors=on
--output-header -u` on `opencv-geometry-internal-float32_points.adb`,
`-convexity.adb`, `-intersection.adb`, `-transforms.adb` and
`opencv-internal-safe_arithmetic.adb`. GNATprove FSF 16.1.0, Why3 1.8.2+git,
exit 0: **"all checks proved (277 checks)"**: 92 flow plus 185 prover checks
(data dependencies 47, initialization 2, run-time checks 105, assertions 43,
functional contracts 37, termination 43), 0 unproved, 0 justified, no
warnings. Provers used: CVC5, Z3, Alt-Ergo and trivial. This matches the
277/277 baseline with the same scope. It covers only those five Ada units,
not the C++ engine, the validator or the public Ada body, and no SPARK source
changed in Task 027.

### Original 62/61 reproducer

`ORIGINAL_62_61_FIXTURE_UNRECOVERED`. The regular 62- and 61-gon stand-ins are
not equivalent, and the unsafe native 4.6/4.10 path was not run. The
rounded-hexagon fixture is preserved and passes on every version above.

### Failures

None. No cell, native test, proof or comparison failed, and no source
correction was needed: the Geometry source under test is unchanged from
`0ec378f1…`.

### Remaining gates (Task 027C2)

Windows MSYS2 execution (only on `main` pushes or manual dispatch); README,
release notes and the PR; and the evidence limits above (the unrecovered
62/61 fixture and the untested non-convergence mapping). The hosted workflow
must also pass on the exact commit that carries this document.

## Task 027C2 — runner correction and final certification

### Runner failure detection

Review found that `step()` in the Task 027C1 runner recorded each exit status
and then always returned 0. A failed pin, build or test run could therefore
still produce a row and a zero exit. The 14 historical cells were not
affected: every cell's `summary.txt` shows `rc=0` for every step, the totals
in the CSV were parsed from the logs, and every driver invocation exited 0.
The runner was still unsafe as a gate.

The corrected `scripts/run_linux_matrix_027c1.sh`:

- Every required stage is fatal. That covers clone and checkout, the Geometry
  and Core SHAs, pkg-config resolving the requested version, the native
  program inventory, pin, both dependency solves, Core SHA inside Alire, the
  build, the generated configuration, release tests and their totals,
  library identity, each native program, the validation build, the validation
  tests and their totals, `CONSTRAINT_ERROR` lines, sanitizer reports, and
  profile restoration.
- Totals must all be present and numeric. `Total Tests Run` and
  `Successful Tests` must both equal the expected count, and failures and
  errors must both be 0.
- A failure logs `FAIL [stage]`, appends a `FAIL` row naming the stage, keeps
  that stage's log and exits 1. A failed restoration of the release profile
  is reported and recorded in the row.
- The sanitizer scan treats grep's zero-match status as zero findings and
  fails only on a match or an unreadable log.
- Each run uses a fresh timestamped directory under `/var/tmp/geometry-027c2`
  and writes `results-v2.csv`, so Task 027C1 logs and results are never
  overwritten.

### Native test counting

The four programs are `closest_ellipse_equivalence`,
`extended_convex_intersection`, `subdiv2d_fault_injection` and
`subdiv2d_float32_equivalence`. The old runner counted output lines beginning
`PASS`. `closest_ellipse_equivalence` prints `... ABI checks passed` instead,
so the count was 3. The corrected runner checks that `tests/native/*.cpp` is
exactly this set. It then builds and runs each program separately, with the
same flags as `scripts/run_native_tests.sh`, and records `native_run` and
`native_pass` from exit statuses. Every cell's historical `native.log` shows
four `Running` lines, and `run_native_tests.sh` (`set -eu`) exited 0. So all
four programs ran and succeeded in all 14 cells. The historical CSV is kept
unchanged as the record of that run.

### Runner validation

`scripts/test_run_linux_matrix_027c1.sh --end-to-end` passes 30 of 30 checks
in a temporary directory. It covers:

- a successful and a failing command;
- missing, empty, truncated and malformed AUnit logs;
- a failed assertion, an unexpected error, and 541 tests run where 542 are
  expected;
- a configuration from another prefix, another version, and with the
  OpenCV 4 module on OpenCV 5;
- Core loaded from outside the prefix, a missing backend library, and no
  OpenCV library loaded;
- zero sanitizer findings (passes), an ASan report, a UBSan report, and an
  unreadable sanitizer log;
- a missing and an unexpected native program;
- end to end, an unreachable Core repository (`FAIL,clone_core`, exit 1) and
  OpenCV 4.6.0 requested with the 4.14.0 prefix (`FAIL,pkg_config`, exit 1).

A real 4.6.0/Core 0.3.0 cell run with `EXPECTED_TESTS=543` also failed
closed (`FAIL,tests_release_totals`, exit 1).

Two real cells were rerun with the corrected runner on the same qualified
source `0ec378f1…`:

| OpenCV / Core | Status | Release | Validation | Native run/pass | Sanitizer | Libraries loaded from |
|---|---|---|---|---|---|---|
| 4.6.0 / 0.3.0 (`0e2753be…`) | PASS | 542/542, 0, 0 | 542/542, 0, 0 | 4/4 | 0 | `install-4.6.0` (core, imgproc) |
| 5.0.0 / 0.4.1 (`386c5360…`) | PASS | 542/542, 0, 0 | 542/542, 0, 0 | 4/4 | 0 | `install-5.0.0` (core, geometry, flann) |

These match the historical rows. The other 12 cells were not rerun because
the production source is unchanged.

### Source identity

Changes since the Linux-qualified commit `0ec378f1…` fall into three groups:

1. Production algorithm and API source. Executable code in `cpp/` and `src/`
   is unchanged, as are `tests/src/`, `tests/native/*.cpp`, both
   `alire.toml` files, the GPR files and `config/`. Task 027C3 corrected two
   stale comments, in `cpp/convex_intersection_compat.hpp` and
   `src/opencv-geometry.ads`; the diff against `0ec378f1…` is comment-only.
2. Qualification scripts and documentation: the corrected matrix runner, its
   self-test, the README, `docs/coverage.md` and this document.
3. The Windows CI workflow, `.github/workflows/cross-platform.yml`, changed
   only to repair the MSYS2 dependency installation (see below).

The Linux matrix, the cross-version comparison and the GNATprove result
therefore all apply to the executable source being submitted.

### Windows MSYS2 certification

The Windows job runs only on `main` pushes and manual dispatch. Its first
manual runs on `91f86fb…` (run 38323681853) failed in "Install MSYS2 OpenCV
and C++ toolchain", before any Geometry build. The step ran
`pacman -Sy --needed` on Alire's cached MSYS2, a partial upgrade: pacman
selected `libgcc` and `libstdc++` 16.2.0-5 while the installed `cc-libs`,
`libgfortran` and `libquadmath` required exactly 16.2.0-4. One rerun failed
the same way, and another on a mirror download timeout. Commit `5f5bf99…`
replaced the step with a full `pacman -Syu` (two passes, for the MSYS2
core update), then `pacman -S --needed`, then a log of the resolved package
versions and a `pacman -Dk` dependency check. No dependency checks were
disabled and no packages were forced or downgraded. This was a CI
environment correction, not a Geometry algorithm defect.

Both workflows on `5f5bf99ea2b98b77bcc662344e865c0e71710079` passed:

- [Manual run 38326589381](https://github.com/zackboll/opencv_geometry_ada/actions/runs/38326589381):
  the Windows x86_64 MSYS2 job ran (not skipped) on Geometry `5f5bf99…` and
  Core 0.4.1 `386c5360ac51f2b62e522853d94290aec4ee14a0`, with OpenCV 5.0.0
  and MinGW GCC 16.2.0-5. The full upgrade succeeded and dependencies
  resolved consistently. Geometry built, the shim DLL and its import library
  were present, the DLL imports the OpenCV geometry DLL and neither Imgproc
  nor the Core shim, and AUnit passed 542/542, including all 11 Extended
  Float32 tests, with zero failed assertions and zero unexpected errors. Its
  four Linux and macOS jobs also passed.
- [Push run 38326582686](https://github.com/zackboll/opencv_geometry_ada/actions/runs/38326582686):
  Linux x86_64 and macOS ARM64, each with Core 0.3.0 and 0.4.1, passed;
  Windows was skipped by policy.

### Evidence limits carried forward

- `ORIGINAL_62_61_FIXTURE_UNRECOVERED`. The rounded-hexagon regression
  remains.
- The production non-convergence and numeric-failure mappings exist in source
  and return an error without publishing outputs. Bounded campaigns found no
  accepted input that reaches them, so they are not dynamically exercised.
- The 4096-vertex limit and the O(n**2) validator are unchanged. The 0.11
  to 0.19 s per 4096-gon call is a measurement on one development machine,
  not a performance guarantee.
- Numerical identity is established for the 168-result tested corpus on
  seven exact-tag builds only, not for every input or future release.
- Windows certifies OpenCV 5.0.0 with Core 0.4.1 only. Windows with Core
  0.3.0 was not tested. The hosted-CI runs for the final submitted head are
  recorded in the pull request.
