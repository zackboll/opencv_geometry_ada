# Task 026: upstream OpenCV reproducer drafts

Research and drafting only. **Nothing here has been posted** to GitHub, and no
upstream issue, comment or pull request was created. No production Ada, C++
shim, C ABI, public API, manifest, dependency or release file changed.
Deferred/Excluded status in [coverage](coverage.md) is unchanged, and no
native safety gate is claimed satisfied. This is evidence for a maintainer to
decide on, not an approved native contract.

Prior work is linked, not repeated: Tasks 013/016/020 in
[versioned-features-research](versioned-features-research.md),
[float32-research](float32-research.md) and
[fit-line-3d-research](fit-line-3d-research.md); Task 025 in
[native-risk-reassessment](native-risk-reassessment.md).

## Environment and sources

Starting `origin/main`: `753df5f9e0afffe6d0f5390c50969110ec5dd140` (PR #24
merged; no open Geometry PRs). Branch `research/026-upstream-reproducer-drafts`.
Linux x86-64, g++ 14.2.0 (Debian), `-std=c++17`.

Exact upstream tags (peeled commit of each annotated tag, from
`git ls-remote https://github.com/opencv/opencv.git`):

| Tag | Commit |
|---|---|
| 4.11.0 | `31b0eeea0b44b370fd0712312df4214d4ae1b158` |
| 4.12.0 | `49486f61fb25722cbcf586b7f4320921d46fb38e` |
| 4.13.0 | `fe38fc608f6acb8b68953438a62305d8318f4fcd` |
| 4.14.0 | `0654a42e19215ef25b1d367d822f3c630447e7c7` |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` |
| (4.6.0) | not fetched; Debian package only, source not inspected |

The 4.10.0 column and the 4.6.0 spot check ran against Debian-packaged
libraries (not exact-tag builds). The 4.10.0 source was read from the exact
tag, and a separate exact-tag 4.10.0 Release build was also made (see
Reproducer A). Every other runtime is an exact-tag build made for this task
(`core,imgproc` for 4.x; `core,imgproc,geometry` for 5.0.0), Release, no
IPP/TBB/OpenCL. The PR 30111 comparison uses the Task 016 builds of the PR
base and head (version string `5.1.0-dev`, not a release).

`min_enclosing_triangle.cpp` has SHA-256 prefix `53a4117560c1f67c` in
4.10.0, 4.11.0, 4.12.0, 4.13.0, 4.14.0 and 5.0.0 (in `modules/geometry` for
5.0.0). The `approxPolyN` code block (`struct changes` through
`cv::approxPolyN`) is byte-identical in 4.11.0 to 5.0.0. Identical source does
**not** establish identical behaviour, so every conclusion below rests on a
run, and the failure mechanism is shown per version where it was examined.

## Evidence labels

- **Source**: read in the exact tag.
- **Runtime**: executed, uninstrumented library, one hazardous call per
  child (own process group, hard timeout, core dumps off, bounded output).
- **Sanitizer**: executed with the *library itself* built with
  `-fsanitize=address,undefined`.
- Identity: each run prints `compile` (`CV_VERSION`), `runtime`
  (`cv::getVersionString()`), `object` (shared object that defines the
  function) and `runtime_object` (defines `getVersionString`). The driver
  marks a run invalid if compile and runtime differ, or the defining object
  is not under the intended prefix. All runs reported here were valid.

## Outcome matrix (runtime, hard timeout 8 s)

`R` returned, `SIGFPE`/`SIGSEGV` signal, `TO` terminated by the controller
at the timeout, `X1` returned with the exit code 1 meaning "enclosure check
failed", `N/A` function absent from that release's headers, `--` not run.
Controls (`ctl`) are benign inputs.

| Case | 4.6.0 | 4.10.0 | 4.11.0 | 4.12.0 | 4.13.0 | 4.14.0 | 5.0.0 |
|---|---|---|---|---|---|---|---|
| A ctl square / triangle | R (square only) | R | R | R | R | R | R |
| **A signed zero** | SIGFPE | SIGFPE | SIGSEGV | SIGSEGV | SIGSEGV | SIGSEGV | SIGSEGV |
| B ctl 1, 1e-1 squares | -- | R | R | R | R | R | R |
| B square 1e-3 | -- | R (no triangle) | R (no triangle) | R (no triangle) | R (no triangle) | R (no triangle) | R (no triangle) |
| **B square 1e-5** | -- | TO | TO | TO | TO | TO | TO |
| B int ctl square | -- | R | R | R | R | R | R |
| **B int_hang** | -- | TO | TO | TO | TO | TO | TO |
| C ctl 4 sides | N/A | N/A | R | R | R | R | R |
| **C unit square, 3** | N/A | N/A | X1 | X1 | X1 | X1 | X1 |
| D ctl k=4 | N/A | N/A | N/A | N/A | R | R | R |
| **D unit square, k=3** | N/A | N/A | N/A | N/A | SIGSEGV | SIGSEGV | SIGSEGV |

4.6.0: only A (square control and signed zero), C and D were run, with the
library and headers taken from a stored Debian 4.6.0 container layer. The
A triangle control and all of B were not run on 4.6.0.
The 4.10.0 column is the Debian package (`libopencv_imgproc.so.410`). An
**exact-tag 4.10.0 Release build gave SIGSEGV, not SIGFPE**, for the same
source file and input. The signal therefore depends on the build, not only
on the version (see Reproducer A). The `minEnclosingConvexPolygon`
declaration is absent from the 4.10.0, 4.11.0 and 4.12.0 headers checked;
4.13.0 is the first 4.x tag examined that declares it.

The previously recorded observations were reproduced on these builds:
A SIGFPE (4.10.0 Debian) and SIGSEGV (4.12.0, 4.13.0, 4.14.0, 5.0.0);
B non-return within the timeout; C's finite non-enclosing output; D's crash
on 4.13.0, 4.14.0 and 5.0.0. 4.12.0 and 4.13.0 for A, which Task 025 did not
repeat, were run here.

## Commands

Standalone sources are in `tests/native/research/upstream_reproducers/`.
Each builds with one `g++` line (see the file header) and needs only stock
OpenCV headers; for OpenCV 4 use `-lopencv_imgproc`, for 5.x
`-lopencv_geometry`, plus `-lopencv_core -ldl`.

```sh
python3 scripts/run_upstream_reproducers.py self-test
# system OpenCV (here Debian 4.10.0)
python3 scripts/run_upstream_reproducers.py build --output /tmp/p-410 --backend imgproc
python3 scripts/run_upstream_reproducers.py run --probes /tmp/p-410 --timeout 8
# an installed prefix
python3 scripts/run_upstream_reproducers.py build --prefix /opt/opencv-4.13.0 \
    --output /tmp/p-413 --backend imgproc
python3 scripts/run_upstream_reproducers.py run --probes /tmp/p-413 \
    --prefix /opt/opencv-4.13.0 --timeout 8
# 5.x
python3 scripts/run_upstream_reproducers.py build --prefix /opt/opencv-5.0.0 \
    --output /tmp/p-500 --backend geometry
```

`run` exits 2 if any case has invalid identity. The controller is only a
convenience: each `.cpp` runs on its own, for example
`./repro_a signed_zero`. Wrap hazardous cases in `timeout -s KILL 10`.

## Reproducer A: `minEnclosingTriangle` with a signed-zero pair

File: `repro_a_min_enclosing_triangle_signed_zero.cpp`.

```cpp
const float pos_zero = float_from_bits(0x00000000u);   // +0.0f
const float neg_zero = float_from_bits(0x80000000u);   // -0.0f
std::vector<cv::Point2f> points{{pos_zero, pos_zero}, {neg_zero, pos_zero}};
std::vector<cv::Point2f> output;
cv::minEnclosingTriangle(points, output);
```

The input bits are printed (`x=0x80000000` for the second point), so the sign
cannot be lost to a literal or the optimizer. Controls (unit square, 3-4-5
triangle) return normally on every runtime.

### Observed (runtime)

| Build | Signal | Defining object |
|---|---|---|
| 4.6.0 Debian | SIGFPE | `libopencv_imgproc.so.406` |
| 4.10.0 Debian | SIGFPE | `/lib/x86_64-linux-gnu/libopencv_imgproc.so.410` |
| 4.10.0 exact tag, Release | **SIGSEGV** | `install-rel-4.10.0/lib/libopencv_imgproc.so.410` |
| 4.11.0, 4.12.0, 4.13.0, 4.14.0 exact tags | SIGSEGV | respective `libopencv_imgproc.so.41x` |
| 5.0.0 | SIGSEGV | `libopencv_geometry.so.500` |

### Where it fails

1. `convexHull` of the two points returns **zero** points for the
   signed-zero pair, but one point for two identical +0 points
   (`probe_a_convex_hull_signed_zero.cpp`, same on 4.10.0, 4.12.0, 4.13.0,
   4.14.0 and 5.0.0). Why `convexHull` treats the pair differently from
   identical points was not investigated, and no claim is made about that
   code. On the Task 016 PR-head build (5.1.0-dev) the same pair gives a hull
   of size 1, and `repro_a` returns an all-zero triangle instead of
   crashing. That build's `convexHull` source differs from 5.0.0's (it is the
   templated `convexHull_` form of merged PR 29714). That PR is the likely
   source of the change, but no bisection was done, so it is not established
   which edit alters the signed-zero result.
2. With an empty hull, `findMinEnclosingTriangle` takes the
   `polygon.size() <= 3` branch into `returnMinimumAreaEnclosingTriangle`
   (`min_enclosing_triangle.cpp:341-345`, `:422-431` in 4.10.0 and 4.13.0):

   ```cpp
   unsigned int nrOfPoints = static_cast<unsigned int>(polygon.size());
   for (int i = 0; i < 3; i++) {
       triangle.push_back(polygon[i % nrOfPoints]);   // line 427
   }
   ```

   With `nrOfPoints == 0` the `%` is an integer remainder by zero, and
   `polygon[...]` would index an empty vector in any case.
3. **Sanitizer, library instrumented** (below): on exact-tag 4.10.0 and
   4.13.0 builds of the *OpenCV library itself*, UBSan reports
   `min_enclosing_triangle.cpp:427:38: runtime error: division by zero`
   and ASan then reports `FPE` at the same line, both from
   `returnMinimumAreaEnclosingTriangle`. The division is the first finding
   and the fatal one. UBSan does not check `std::vector::operator[]` bounds,
   and ASan never got past the FPE, so a later out-of-bounds read of the empty
   vector was neither observed nor excluded.

The classification is therefore **division/modulo by zero on an empty hull**,
established on 4.10.0 and 4.13.0 with an instrumented library. It is not an
out-of-bounds read, native assertion or OpenCV exception on those two
builds. The SIGSEGV seen in uninstrumented Release builds is consistent with
the compiler treating the undefined remainder as unreachable and then
reading an empty vector: gdb on the 4.13.0 and 4.10.0 Release builds stops in
`std::vector<Point2f>::_M_realloc_append` called from
`findMinEnclosingTriangle`, not at a `div`. That optimization-dependence is
inferred from the stacks, and no disassembly comparison was made. The Debian
4.10.0 package stops with SIGFPE inside `libopencv_imgproc.so.410` (gdb frame
#1 is `cv::minEnclosingTriangle`; the faulting frame has no symbol).
Compiler and optimization level, not only OpenCV version, determine whether
a build reports SIGFPE or SIGSEGV. Instrumented 4.12.0, 4.14.0 and 5.0.0
builds were not made. For those, the same file hash and the same crash
signal are consistent with the same defect but do not prove it.

PR 30111 does not touch this file (`min_enclosing_triangle.cpp` in its head
is byte-identical to 5.0.0). The Task 016 PR-head build does not crash on
this input; since `min_enclosing_triangle.cpp` is identical there, the
difference lies elsewhere (the `convexHull` result above), and the
`returnMinimumAreaEnclosingTriangle` code still has no guard for an empty
polygon.

### Expected behavior

A defined result: either a triangle enclosing both points (degenerate, area
0) or a documented `cv::Exception`. A signed zero is numerically equal to
zero and should not change whether a pair of equal coordinates is accepted.
(The exact choice is for maintainers.)

## Reproducer B: `minEnclosingTriangle` did not return

File: `repro_b_min_enclosing_triangle_non_return.cpp`.

```cpp
std::vector<cv::Point2f> points{{0.0f, 0.0f}, {side, 0.0f},
                                {side, side}, {0.0f, side}};   // side = 1e-5f
std::vector<cv::Point2f> output;
cv::minEnclosingTriangle(points, output);
```

`1e-5f` is the binary32 value `0x3727c5ac` (9.99999975e-06); the program
prints the exact bits. The integer-input control `int_hang` is separate:
`{(0,0), (1,0), (100001,1), (100000,1)}` as `std::vector<cv::Point>`.

### Observed (runtime)

Each call ran in its own child under a hard wall-clock limit enforced by the
controller (process group `SIGKILL`).

| Case | Result on 4.10.0 Debian, 4.11.0, 4.12.0, 4.13.0, 4.14.0, 5.0.0 |
|---|---|
| side 1, 1e-1 | returned |
| side 1e-3 | returned, **no triangle** (`area` = `DBL_MAX`, empty output) |
| **side 1e-5** | **did not return within 8 s on every listed runtime; on 4.13.0 also not within 60 s. Child terminated by the controller.** |
| integer square (0,0)-(10,10) | returned |
| **`int_hang`** | **did not return within 8 s; child terminated by the controller** |

Precise statement: the call had not returned after 8 seconds (60 seconds in
one 4.13.0 run) and the controller killed the child. **No proof of an
infinite loop is claimed**, and no claim is made that any larger limit would
also fail. The 1e-3 result is notable on its own: the function returns
normally but yields no triangle and leaves `area` at `DBL_MAX`. 4.6.0 was
not run for B. No universal safe minimum scale is claimed. Only the listed
sizes were run.

### Source inspection

The sampled stacks, from gdb attached to a running child on the instrumented
4.13.0 build (four samples for 1e-5 and five for `int_hang`), were all inside
the same call chain:
`findMinimumAreaEnclosingTriangle` → `advanceBToRightChain`
(`min_enclosing_triangle.cpp:445`) → `height` → `distanceFromPointToLine`
(`:1264-1268`). The other samples were inside sanitizer runtime code,
because the build was instrumented. Samples are a few points in time, not a
proof the loop never exits.

That loop is, in 4.13.0 (identical file hash in all versions listed above):

```cpp
while (greaterOrEqual(height(successor(b, nrOfPoints), polygon, nrOfPoints, c),
                      height(b, polygon, nrOfPoints, c))) {
    advance(b, nrOfPoints);          // b = (b + 1) % nrOfPoints
}
```

`greaterOrEqual(x, y)` is `x > y || |x - y| <= 1e-5 * max(1, |x|, |y|)`
(`:1512-1523`, `EPSILON` is `1E-5` at `:97`). `b` advances modulo
`nrOfPoints`, and no iteration counter bounds the loop. The only exits are
the condition becoming false. If all heights stay within the **absolute**
tolerance `1e-5` of each other, the condition stays true for every `b`. For
a square whose side is `1e-5`, every vertex height from a side is at most
`1e-5`, which makes that plausible. The sampled stacks match it, but this
mechanism is a hypothesis from source plus samples. It was not demonstrated
by instrumenting `b` and the heights. It also does not obviously explain
`int_hang`, whose coordinates are large; the same loop was sampled there.

### Expected behavior

The call returns (a triangle, or an exception for input it cannot handle).
At minimum, a bounded loop.


## Reproducer C: `approxPolyN` returns a triangle that does not enclose the input

File: `repro_c_approx_poly_n_enclosure.cpp`. `approxPolyN` is absent from
OpenCV 4.10.0 and earlier (the program reports `not_applicable`, exit 13).

```cpp
std::vector<cv::Point2f> points{{0.0f, 0.0f}, {1.0f, 0.0f},
                                {1.0f, 1.0f}, {0.0f, 1.0f}};
std::vector<cv::Point2f> output;
cv::approxPolyN(points, output, 3, -1.0f, false);
```

### Observed (runtime, identical on 4.11.0, 4.12.0, 4.13.0, 4.14.0, 5.0.0)

```
output 3
  (-1, -1)   x=0xbf800000 y=0xbf800000
  (1, 1)     x=0x3f800000 y=0x3f800000
  (0, 1)     x=0x00000000 y=0x3f800000
```

The program checks enclosure exactly (integer cross products in `int64_t`,
valid because every coordinate is a small integer exactly representable in
binary32). It orients by the output's signed area (2 × area = 2) and finds,
for the edge `(-1,-1) → (1,1)`, `cross = -2` for input point `(1, 0)`:
**`(1, 0)` lies outside the returned triangle**. The other three points are
inside. The same call with 4 sides (the control) returns the square and the
check passes. Exit code 1 means "returned, enclosure fails".

### Three separate things

1. **Incorrect finite output (reproduced here).** The function documents
   an *approximating polygon that bounds the contour*, but returns finite
   coordinates for a triangle that misses a vertex.
2. **Sentinel intersection selection (source reading, consistent with the
   output).** In `recalculation` (`approx.cpp:920-949` in 4.13.0), when
   `|cross| < 1e-8` the code sets `area_ = FLT_MAX` and returns the
   *sentinel* intersection `(-1, -1)`. In the unit square, for every vertex,
   the previous and next edges are antiparallel, so `cross == 0` and all four
   candidates carry `FLT_MAX`. Ties break on vertex index
   (`changes::operator>`, `:911-914`), so vertex 0 is contracted, at
   `base.intersection = (-1, -1)` (`:1067`). That reproduces the observed
   output exactly: vertex 1 `(1, 0)` removed, vertex 0 replaced by
   `(-1,-1)`. A sentinel that is also a legal coordinate, selected because
   it is the cheapest of equal `FLT_MAX` keys, is the mechanism proposed
   here. It was not confirmed by a debugger or an instrumented build.
3. **NaN priority-queue ordering (separate, not reproduced here).**
   Task 013 showed finite inputs that give NaN `area` keys (see
   [versioned-features-research](versioned-features-research.md)). The
   comparator's NaN ordering then violates strict weak ordering. This
   reproducer's inputs produce only finite keys. It neither exercises
   nor settles the NaN concern, and **no heap-safety conclusion follows from
   it in either direction.** The NaN campaign was not rerun in Task 026.

### Source identity

The block from `struct changes` through `cv::approxPolyN` has the identical
hash in 4.11.0, 4.12.0, 4.13.0, 4.14.0 and 5.0.0. Behaviour was nonetheless
run on each build and was identical.

### Expected behavior

Either a polygon that encloses the input, or an exception, rather than a
finite polygon that excludes an input vertex.


## Reproducer D: `minEnclosingConvexPolygon` crash at k = 3 and PR 30111

File: `repro_d_min_enclosing_convex_polygon.cpp`. The function is declared
from 4.13.0 (imgproc) and in 5.x (geometry). It is absent from the 4.10.0,
4.11.0 and 4.12.0 headers (`not_applicable`, exit 13).

```cpp
std::vector<cv::Point2f> points{{0.0f, 0.0f}, {1.0f, 0.0f},
                                {1.0f, 1.0f}, {0.0f, 1.0f}};
std::vector<cv::Point2f> output;
cv::minEnclosingConvexPolygon(points, output, 3);
```

### Observed

| Build | k = 3 | k = 4 control |
|---|---|---|
| 4.13.0, 4.14.0, 5.0.0 (released, Release) | **SIGSEGV** | returned, encloses |
| 4.13.0 with the library instrumented (ASan+UBSan) | `heap-buffer-overflow`, READ of size 8, in `std::vector<Segment>::operator[]` called from `Chains::findKSides` (`min_enclosing_convex_polygon.cpp:919`) via `findMinAreaPolygon` (`:999`); address is 8 bytes past a 96-byte region | returned, encloses; no sanitizer report |
| Task 016 PR **base** build (`5.1.0-dev`) | SIGSEGV | returned, encloses |
| Task 016 PR **head** `01f4d0e5` build (`5.1.0-dev`) | returned: area 2, triangle (2,1), (0,-1), (0,1); encloses all four points (exact check) | returned, encloses |

The sanitizer run is on 4.13.0 only. 4.14.0 and 5.0.0 have the identical
crash signal, and 4.14.0 and 5.0.0 share one source file (hash
`3fd651cee9c7ab0f`), but they were not instrumented. The 4.13.0 file
(`d9be1d250fade8f0`) differs from them.

### PR 30111 (checked 2026-10-12)

- `https://github.com/opencv/opencv/pull/30111`, "geometry: fix a crash in
  minEnclosingConvexPolygon for k = 3": **open, unmerged**, base `5.x`,
  head `01f4d0e5da231d00c1eca735a0880b492a69fdde`, one commit, mergeable,
  last updated 2026-10-09, no CI check results listed yet.
- One review (member, "COMMENTED", `01f4d0e5`) that found no additional
  correctness issue and says final acceptance should wait for CI; one author
  comment (2026-10-02) asking for the CI run to be approved.
- The diff makes four changes: an extra `findSingleE` for the adjacent-side
  chain; `one.exists = itrs.intersection.position` instead of `false` for the
  zero-length middle chain; `if (k > 3)` around the `reconstructHSidedChain`
  call; and a `CV_Error` when `min.i < 0 || min.j < 0`. It also adds the
  regression tests `regression_k3`, `regression_k3_convex_pentagon` and
  `enclosing_polygon_properties`.
- Related earlier work: PR 28569 (merged, a GCC warning) and PR 29128
  (closed unmerged, input validation). No open issue was found that reports
  the k = 3 crash.

### Comparison, with its limits

- For this reproducer the head returns a triangle of area 2 that encloses
  all four points (exact check). Twice the square's area is the known
  minimum for a triangle around a square, and the PR's own test asserts the
  same relation on a 10 × 10 square. This reproducer's unit square is not
  that test's input.
- The head source tree used here is byte-identical to a fresh download of
  commit `01f4d0e5` (`diff -rq` of `modules/geometry`: no differences).
- **Do not read the head result as evidence that any release is fixed.** The
  head is an unreleased `5.1.0-dev` build with other 5.x changes (for
  example the `convexHull` rewrite noted in Reproducer A).
- **Do not read a crash fix as a correctness fix.** The Task 016 corpus
  (33 cases) still has, on the head build, 11 contained `cv::Exception`s
  (Task 016 found that some valid inputs raise; which of the 11 are valid
  was not re-audited here) and 6 non-minimal polygons (for example the k = 4
  result for a regular 33-gon, whose exact minimum enclosing rectangle is
  smaller);
  see [native-risk-reassessment](native-risk-reassessment.md#minenclosingconvexpolygon)
  and [versioned-features-research](versioned-features-research.md). Those
  were not re-run in Task 026.
- 4.13.0, 4.14.0 and 5.0.0 releases still contain the defect. A backport to
  the 4.x branch is not part of the PR (it targets `5.x`).

### Recommendation on filing

Do **not** open a new issue duplicating PR 30111. A review comment on the PR
(draft below) that adds the sanitizer location, the k = 3 square on exact
tags, and the remaining correctness limits would be more useful. A separate
issue is reasonable only for the non-minimal results and the exceptions on
valid input, which the PR does not claim to fix; that needs the Task 016 corpus
and was not prepared here.


## Sanitizer investigation

### Scope: what was and was not instrumented

| Build | Library instrumented | Probe instrumented | Cases run |
|---|---|---|---|
| exact tag 4.10.0, Debug `-O1`, ASan+UBSan (`install-asan-4.10.0`) | **yes** (core and imgproc) | yes | A control, A signed zero |
| exact tag 4.13.0, same flags (`install-asan-4.13.0`) | **yes** (core and imgproc) | yes | A control, A signed zero, C unit square, B int square, D k=3 and k=4 |
| 4.11.0, 4.12.0, 4.14.0, 5.0.0 | no | no | not sanitizer-run |
| PR 30111 head | no | no | not sanitizer-run |

Both instrumented builds were configured with
`-DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g -O1"`
(recorded in each `CMakeCache.txt`), `BUILD_LIST=core,imgproc`, no precompiled
headers, and linked with the same sanitizer flags. The probe was compiled
with the same flags and run with `LD_LIBRARY_PATH` pointing at the
instrumented install. The driver confirmed for every run that
`object` was the instrumented `libopencv_imgproc.so.41x` under the intended
prefix, and the library contains ASan/UBSan runtime symbols
(108 `__asan*`/`__ubsan*` dynamic symbols in each). The reports name the
upstream source lines in the exact-tag trees, so the instrumented
implementation was the one running.

This is **two exact-tag builds on one compiler (g++ 14.2.0)**, not full upstream
memory-safety qualification, and not a statement about any other version.
Runs used `detect_leaks=0` and ran one case per process with core dumps off.
Bounded traces (about 10 KB in total, paths shortened to `<src>`, `<repo>`
and `<work>`) are committed under
`tests/native/research/upstream_reproducers/evidence/`; the essential lines
are below.

### ASan faults and UBSan findings, kept apart

| Case | UBSan finding | ASan fault |
|---|---|---|
| A signed zero, 4.10.0 and 4.13.0 | `min_enclosing_triangle.cpp:427:38: runtime error: division by zero` (non-halting run shows it first) | `FPE` at the same line (SIGFPE trap) after the UBSan report |
| D k=3, 4.13.0 | none | `heap-buffer-overflow`, READ of size 8, `std::vector<Segment>::operator[]` from `Chains::findKSides` (`min_enclosing_convex_polygon.cpp:919`) |
| D k=4, B int square, A control, C unit square, 4.13.0 | none | none |

Concretely, for A on 4.13.0 (`UBSAN_OPTIONS=halt_on_error=0`):

```
min_enclosing_triangle.cpp:427:38: runtime error: division by zero
  #0 returnMinimumAreaEnclosingTriangle  min_enclosing_triangle.cpp:427
  #1 findMinEnclosingTriangle            min_enclosing_triangle.cpp:344
  #2 findMinEnclosingTriangle            min_enclosing_triangle.cpp:324
  #3 cv::minEnclosingTriangle            min_enclosing_triangle.cpp:301
AddressSanitizer: FPE ... SUMMARY: AddressSanitizer: FPE
  min_enclosing_triangle.cpp:427 in returnMinimumAreaEnclosingTriangle
```

C (`approxPolyN`) shows **no** sanitizer finding on 4.13.0: the enclosure
failure is a wrong result, not a memory or arithmetic fault, and a
sanitizer-clean run says nothing about the separate NaN ordering concern.
The B non-return cases were not sanitizer-run for a verdict; only stack
samples were taken on the instrumented 4.13.0 build.

### Not done

- No instrumented 4.11.0, 4.12.0, 4.14.0 or 5.0.0, and no instrumented
  PR 30111 head.
- No `-D_GLIBCXX_ASSERTIONS` run in this task (Task 016 used it).
- The compiler is a single version; another compiler might report a
  different signal for A.


## Upstream existence checks (2026-10-12, GitHub search through `gh`)

Searched `opencv/opencv` issues and pull requests for `minEnclosingTriangle`,
`approxPolyN`, `minEnclosingConvexPolygon` and the failure words (crash,
SIGFPE, hang, freeze, infinite loop, signed zero, NaN, wrong). GitHub search
is keyword-based and may miss reports. **Absence below means only "not
found by these searches".**

| Topic | Result |
|---|---|
| A signed zero | No issue found. Related, closed: #11116 (crash at certain points, 3.4.1, an exception, not this fault), #20890, #17585, #4992. |
| B non-return | No issue found. |
| C `approxPolyN` | Only #26345 (open, Python binding missing on macOS 4.10.0, unrelated) and PRs #25607 (merged, added the function), #27808 (docstring). No wrong-output report found. |
| D k = 3 crash | PR #30111 (open, the fix). Related: #28568 (closed, GCC warning), PR #28569 (merged), PR #29128 (closed unmerged, input validation). No issue for the crash itself. |
| `convexHull` | #26952 (open: strict-aliasing UB, separate topic) and PR #29714 (merged to 5.x). Not the same fault, but PR 29714 changes `convexHull` and may affect A (see above). |

## Issue and comment drafts (NOT POSTED)

Each draft is self-contained. Nothing below was submitted anywhere. All
versions listed were run in this study; "not tested" means exactly that.
Commit SHAs are in the table at the top of this document.

### Draft 1: `minEnclosingTriangle` division by zero on a signed-zero pair

**Title:** `imgproc/geometry: minEnclosingTriangle crashes (modulo by zero on an empty hull) for the points (0,0) and (-0,0)`

**Function / module:** `cv::minEnclosingTriangle`, `modules/imgproc`
(4.x) and `modules/geometry` (5.x), file `min_enclosing_triangle.cpp`.

**Tested:** 4.6.0 (Debian), 4.10.0 (Debian, and exact tag
`71d3237a093b60a27601c20e9ee6c3e52154e8b1`), 4.11.0, 4.12.0, 4.13.0, 4.14.0,
5.0.0 (exact tags). Linux x86-64, g++ 14.2.0.

**Reproducer** (single file; the second point is built from bits `0x80000000`):

```cpp
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>      // OpenCV 5: <opencv2/geometry.hpp>
#include <cstdint>
#include <cstring>
#include <vector>
int main() {
    std::uint32_t nzb = 0x80000000u; float nz; std::memcpy(&nz, &nzb, 4);
    std::vector<cv::Point2f> points{{0.0f, 0.0f}, {nz, 0.0f}};   // (0,0), (-0,0)
    std::vector<cv::Point2f> out;
    cv::minEnclosingTriangle(points, out);
}
```

Build: `g++ -std=c++17 repro.cpp -o repro $(pkg-config --cflags --libs opencv4)`
(for 5.x use `opencv5`). The full version with identity output and benign
controls is `repro_a_min_enclosing_triangle_signed_zero.cpp`.

**Expected:** a defined result (a degenerate triangle) or a documented
exception.

**Actual:** the process dies by signal. 4.6.0 and the Debian 4.10.0 package:
SIGFPE. Exact-tag 4.10.0, 4.11.0, 4.12.0, 4.13.0, 4.14.0 and 5.0.0 (Release):
SIGSEGV. Benign controls (a unit square and a 3-4-5 triangle) return
normally on the exact-tag builds; on 4.6.0 only the square was run.
`minEnclosingTriangle` was not run on two identical `+0` points.

**Analysis:** `cv::convexHull` returns an empty hull for the signed-zero pair
(size 0 on 4.10.0, 4.12.0, 4.13.0, 4.14.0 and 5.0.0; size 1 for two
identical `+0` points). `findMinEnclosingTriangle` then calls
`returnMinimumAreaEnclosingTriangle` with `polygon.size() == 0`, and
`triangle.push_back(polygon[i % nrOfPoints])` (`min_enclosing_triangle.cpp:427`)
takes a remainder by zero. With the library built with
`-fsanitize=address,undefined` (exact tags 4.10.0 and 4.13.0), UBSan reports
`min_enclosing_triangle.cpp:427:38: runtime error: division by zero`,
followed by an ASan `FPE` at the same line. Why the hull is empty for `-0`
versus `+0` was not investigated. The file is identical (SHA-256 prefix
`53a4117560c1f67c`) in all tags listed, but identical source alone does not
show the same failure everywhere; only 4.10.0 and 4.13.0 were instrumented.

**Differences:** SIGFPE versus SIGSEGV depends on the build (the same
exact-tag 4.10.0 source gave SIGSEGV in a Release build). A build of the
PR 30111 head tree (5.1.0-dev) returns an all-zero triangle for this input
and its hull has one point; `min_enclosing_triangle.cpp` is unchanged there.

**Related:** none found for this fault. #11116 is an older, different crash.

**Limits:** no fix is proposed. Two plausible places are the hull of equal
points and a guard for an empty polygon. Not tested on other compilers or
platforms.

---

### Draft 2: `minEnclosingTriangle` does not return for a small float square

**Title:** `minEnclosingTriangle did not return within 60 s for the float square with side 1e-5 (no result, no exception)`

**Tested:** 4.10.0 (Debian), 4.11.0, 4.12.0, 4.13.0, 4.14.0, 5.0.0 (exact
tags), Linux x86-64, g++ 14.2.0. 4.6.0 not tested.

**Reproducer:**

```cpp
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>      // OpenCV 5: <opencv2/geometry.hpp>
#include <vector>
int main() {
    const float s = 1e-5f;                       // bits 0x3727c5ac
    std::vector<cv::Point2f> points{{0, 0}, {s, 0}, {s, s}, {0, s}};
    std::vector<cv::Point2f> out;
    cv::minEnclosingTriangle(points, out);       // had not returned when killed
}
```

Run under an external limit, for example `timeout -s KILL 10 ./repro`.

**Expected:** a triangle, or an exception.

**Actual:** the call had not returned after 8 s on every version above, and
not after 60 s on 4.13.0; the controller terminated the child. **This does
not prove an infinite loop.** Side 1 and 0.1 returned. Side 1e-3 returned
**no triangle** (`area` = `DBL_MAX`, empty output). A separate integer case,
`std::vector<cv::Point>{{0,0},{1,0},{100001,1},{100000,1}}`, also had not
returned after 8 s.

**Analysis (partly a hypothesis):** stack samples (gdb, instrumented 4.13.0
build) were in `advanceBToRightChain` at `min_enclosing_triangle.cpp:445`
→ `height` → `distanceFromPointToLine` for both the float and integer cases.
The loop is
`while (greaterOrEqual(height(successor(b)), height(b))) advance(b)`
with no iteration bound, and `greaterOrEqual` uses `almostEqual` with an
*absolute* `EPSILON = 1E-5` floor. For a polygon whose heights are all within
1e-5 of each other the condition could stay true. That was not confirmed by
instrumenting the indices, and it does not obviously explain the integer case.

**Related:** none found. **Limits:** no universal safe minimum scale is
claimed; only the sizes above were run.

---

### Draft 3: `approxPolyN` returns a triangle that excludes an input vertex

**Title:** `approxPolyN(unit square, 3, -1, false) returns (-1,-1),(1,1),(0,1), which does not enclose (1,0)`

**Tested:** 4.11.0, 4.12.0, 4.13.0, 4.14.0, 5.0.0 (identical output). The
function does not exist in 4.10.0 or earlier.

**Reproducer:**

```cpp
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>      // OpenCV 5: <opencv2/geometry.hpp>
#include <iostream>
#include <vector>
int main() {
    std::vector<cv::Point2f> points{{0,0},{1,0},{1,1},{0,1}};
    std::vector<cv::Point2f> out;
    cv::approxPolyN(points, out, 3, -1.0f, false);
    for (auto& p : out) std::cout << p << "\n";   // (-1,-1) (1,1) (0,1)
}
```

**Expected:** a triangle containing all four square vertices (the smallest
such triangle has area 2, for example `(0,-1),(0,1),(2,1)`), or an error.

**Actual:** `(-1,-1), (1,1), (0,1)`. For the edge `(-1,-1)→(1,1)` the cross
product with `(1,0)` is `-2` while the triangle's signed area is positive, so
`(1,0)` is outside. The full reproducer checks this with integer arithmetic.

**Analysis (source reading, not debugger-confirmed):** `recalculation`
(`approx.cpp`) sets `area_ = FLT_MAX` and the intersection to the sentinel
`(-1, -1)` when `|cross| < 1e-8`. In the unit square all four vertices have
antiparallel neighbouring edges, so every candidate gets `FLT_MAX`; the tie
is broken by vertex index (`changes::operator>`), and vertex 0 is replaced
by the sentinel `(-1,-1)`, which is a legal coordinate. The block is
byte-identical in all versions listed.

**Separate concern, not shown here:** non-finite (NaN) `area` keys can break
the strict weak ordering of the `std::priority_queue` comparator for other
inputs (a finding from earlier work in this repository, not rerun). This
reproducer produces only finite keys and says nothing about that concern.

**Related:** none found. PR #25607 introduced the function.

---

### Draft 4: review comment for PR 30111 (preferred over a new issue)

**Where:** a comment on https://github.com/opencv/opencv/pull/30111
(head `01f4d0e5da231d00c1eca735a0880b492a69fdde` when checked).

> Independent data for this PR, from separate builds.
>
> **Released versions crash at k = 3.** Unit square
> `(0,0),(1,0),(1,1),(0,1)` with `k = 3`: SIGSEGV on exact-tag 4.13.0, 4.14.0
> and 5.0.0 builds (Release). With the 4.13.0 library built under
> `-fsanitize=address,undefined`, ASan reports a `heap-buffer-overflow`
> (READ of size 8) in `std::vector<Segment>::operator[]` called from
> `Chains::findKSides` (`min_enclosing_convex_polygon.cpp:919`) via
> `findMinAreaPolygon` (`:999`). `k = 4` on the same input is fine.
>
> **This PR's head fixes that case.** A build of `01f4d0e5` (5.1.0-dev)
> returns a 3-vertex polygon of area 2 for the unit square, and an exact
> integer check shows all four points inside. The base build crashes.
>
> **Caveat (not a request to change this PR):** removing the crash does not
> make results minimal. An earlier 33-case study found that on this head 6
> results were not minimal and 11 inputs raised `cv::Exception`. Separately,
> on release 4.13.0 a regular 33-gon at `k = 4` gave area/r² = 4.012 while
> the exact minimum enclosing rectangle is 3.986·r². The 33-gon figure is
> from the release build, not the head. None of these numbers were rerun
> for this comment.
>
> This PR targets `5.x`; 4.13 and 4.14 contain the same crash.
>
> Environment: Linux x86-64, g++ 14.2.0.

If posted, re-check the PR state first; it may have changed.


## Remaining unknowns and limits

- Root cause of the empty hull for `(+0, -0)`: not investigated.
- Instrumented 4.11, 4.12, 4.14 and 5.0 were not built, so division by zero is
  established only for 4.10.0 and 4.13.0. 4.6.0 ran uninstrumented only.
- B: the mechanism is a hypothesis; the loop was sampled, not instrumented.
- C: the NaN priority-queue concern was not rerun.
- D: head behaviour checked on the unit square only; the Task 016 corpus and
  `-D_GLIBCXX_ASSERTIONS` runs were not repeated.
- GitHub search is keyword based and may miss related reports.
- One compiler (g++ 14.2.0) and one platform. Debian 4.10.0 and 4.6.0 are
  distro builds, so patches or flags are unknown.
- These drafts are evidence for maintainers. They do not make any deferred
  Geometry binding safe, and no Deferred or Excluded status changed.
