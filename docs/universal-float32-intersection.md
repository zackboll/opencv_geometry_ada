# Task 027: universal Float32 convex polygon intersection

**Status (Task 027A-R2): research prototype committed and pushed; public
integration pending; no PR opened.** Research commit `717a4866` added the
private compatibility header, the research probe and this document to branch
`feature/027-universal-float32-convex-intersection`; the corrective commit
that follows it is recorded in the branch history. The header was qualified
on OpenCV 4.10.0 only (smoke runs on 4.11.0, 4.13.0 and 5.0.0). There is no
`Intersect_Convex_Polygons_Extended_Float32`, no new C ABI export and no
change to any production file. The header is not included by the shim.

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
