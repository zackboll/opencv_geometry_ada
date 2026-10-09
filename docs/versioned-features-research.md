# Optional native Geometry features: research gate

Status: approxPolyN is **deliberately deferred at its safety gate**; Task 013
pivoted to native capability plumbing and closest ellipse points. The
approxPolyN investigation is preserved below, not declared impossible.
minEnclosingConvexPolygon is likewise **deferred at its safety gate**
(Task 016): each examined release, 4.13.0, 4.14.0 and 5.0.0, reads out of
bounds for some finite input; see
[Task 016](#task-016-minenclosingconvexpolygon-safety-gate).

## Task 022: universal Float32 Subdiv2D bounds

Starting main: `264c483eafaf74d1cdb7fa437c63f2d7cd499921`, freshly fetched
after verifying PR #20 merged. No open PRs at startup. Isolated branch:
`feature/022-portable-subdiv2d-f32`. Baseline Linux OpenCV 4.10.0/imgproc:
525/525 AUnit tests and native allocation-failure tests passed.

### Source safety gate: established

Exact upstream tag checkouts inspected (not simulated version macros):

| Tag | Commit | Subdiv2D module |
| --- | --- | --- |
| 4.6.0 | `b0dc474160e389b9c9045da5db49d03ae17c6a6b` | imgproc |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` | imgproc |
| 4.11.0 | `1d3b34ddd080bbf3e3d3cec58e11038fca21dcfe` | imgproc |
| 4.12.0 | `49486f61fb25722cbcf586b7f4320921d46fb38e` | imgproc |
| 4.13.0 | `fe38fc608f6acb8b68953438a62305d8318f4fcd` | imgproc |
| 4.14.0 | `0654a42e19215ef25b1d367d822f3c630447e7c7` | imgproc |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` | geometry |

Declarations are in `modules/imgproc/include/opencv2/imgproc.hpp` or
`modules/geometry/include/opencv2/geometry/2d.hpp`; implementations are in
the corresponding `src/subdivision2d.cpp`. Upstream references are exact
tags, e.g. [4.6 declarations](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/include/opencv2/imgproc.hpp),
[4.11 implementation](https://github.com/opencv/opencv/blob/4.11.0/modules/imgproc/src/subdivision2d.cpp),
[4.13 initializer](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/src/subdivision2d.cpp#L548-L592),
and [5.0 implementation](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/src/subdivision2d.cpp).

- All required fields, nested Vertex/QuadEdge types, constructors and methods
  are protected or public. Nested constructors are exported. The shim uses
  ordinary C++ derivation, not private-member access, pointer casts, layout
  reinterpretation or cross-version object reuse. Each build must use matching
  native headers and libraries; this is not a universal binary shim.
- The block from `QuadEdge::QuadEdge()` up to `locate` in 4.6, 4.10, 4.11
  and 4.12 has SHA-256
  `b6646acba4cee0316d3e2e3f730554c41a65d2b37869fba79e0e778adf3cf654`.
  It includes slot construction, splice, endpoint setting, newEdge/newPoint
  and free-list handling. The newer versions retain these operations.
- The complete Rect2f initializer block in 4.13, 4.14 and 5.0 has SHA-256
  `97ba988da2acc45d04b68881d31c96016df10d76d44d8a5c52a44ee2510b3f50`.
  The backport preserves its arithmetic and mutation order: clear vectors,
  reset recentEdge/validGeometry, store bounds, create null slots, reset free
  lists, allocate A/B/C, create AB/BC/CA, set endpoints, splice, set recentEdge.
- After clearing storage, only four vertex and four quad-edge slots are
  constructed. Native signed-index multiplication is bounded by these tiny
  counts. Existing insertion/count guards remain unchanged. Vector allocation
  can throw at each growth; no pointer escapes and C++ unwinding destroys
  partially constructed members. Failed creation publishes null. Reset marks
  the handle unusable before rebuilding and publishes usable only on success.
  Recovery clears partial storage before recreating the state. Existing
  controlled Ada ownership and last-successful bounds publication are intact.
- Float expressions use `6.f * max(width,height)`, binary32 X+Width/Y+Height,
  and the native A/B/C expressions without integer conversion. Finite/positive
  fields, extent advance and finite super-triangle coordinates remain Ada
  policy. No stricter conditioning threshold is introduced. Native integer
  initialization is untouched: factor three through 4.11, six from 4.12.
- Insert, Locate, Find_Nearest, edge/triangle extraction and Voronoi still
  execute the native release's implementation. The compatibility path only
  creates the native initial state. It does not fix existing near-degenerate
  predicates or Find_Nearest liveness limitations; subnormal/extreme fixtures
  test initialization/storage only. Native tests use a 60-second hard timeout.
- Validation-boundary review: **No public semantic validation is duplicated
  in the C++ shim.** The changed guards reject null output, bounds and handle
  pointers. Allocation and ownership protection are not Ada semantic policy.

### License and provenance

The adapted initialization is from the exact 4.13.0 source above, which carries
the Intel Open Source Computer Vision Library license, Copyright (C) 2000 Intel
Corporation, with third-party copyrights reserved. Its copyright, conditions
and disclaimer are retained in `cpp/subdiv2d_compat_license.hpp`. Source
redistributions must retain them and binary redistributions must reproduce
them in documentation or accompanying materials. Intel's name must not be
used for endorsement without permission. The crate remains Apache-2.0.

### Qualification and equivalence

The AUnit suite retains 525 registered tests. Bounds cases previously skipped
on old versions now execute; unsupported expectations are replaced by positive
Create and semantic-rejection tests. Native capability matrix tests are
unchanged. Coverage includes exact fractional descriptors, half-open bounds,
binary32 collapse/advance, nonfinite/invalid bounds, subnormal/extreme storage,
cross-mode rejection and transition, repeated Reset, native integer factors,
duplicate insertion, navigation and identifiers, triangulation and Voronoi.
The existing allocation campaign now tests Float32 on every release.

`tests/native/subdiv2d_float32_equivalence.cpp` uses a deterministic,
well-conditioned four-site fixture with fractional origin/dimensions. It
checks duplicate insertion/location, nearest-site results, three triangles,
four facets, and exactly four vertex/edge slots after repeated Reset. It
prints hex-float super-triangle, canonical edge/triangle geometry and Voronoi
polygons, sorting coordinates instead of demanding identical IDs/walk order.
On 4.6, 4.10, 4.12, 4.13, 4.14 and 5.0 the complete canonical transcript is
byte-identical, SHA-256
`36bef2511ce50f6111898e526aede7b82f89cf111c1043e97ce804a3848b93d1`.
No numeric tolerance is needed for this binary-grid fixture on these GNU
builds; this observation is not a promise of cross-platform bit identity or
equivalence for ill-conditioned arbitrary inputs.

Linux qualification uses Alire 2.1.1, GNAT 16.1.0 and GPRbuild 26.0.0
(Alire toolchain crate 26.0.1). System 4.10 uses Debian g++ 14.2.0. Exact-tag
4.12/4.13/4.14 builds are shared Release libraries using GNU 14.2, fast math
and LTO disabled; 5.0 uses the existing real exact-tag shared GNU build.
Separate Geometry and Core storage prevents cross-version reuse, and `ldd`
confirms the actual imgproc/core or geometry/core libraries.
The 4.6 endpoint uses an isolated Debian 12 container, native packages
`4.6.0+dfsg-12`, GNU 12.2.0, the same GNAT/Alire toolchain, and a private
Core 0.3.0 checkout (`0e2753be8ea05fc972ec452c32b975f9e9b3912f`). Other
matrix entries use that same published Core revision in separate build
directories. Temporary harness-only pins/settings are not committed.

| Native version/backend | Normal AUnit | Validation AUnit | Native ASan/UBSan and faults |
| --- | --- | --- | --- |
| 4.6.0/imgproc | 525/525 | 525/525 | Pass |
| 4.10.0/imgproc | 525/525 | 525/525 | Pass |
| 4.11.0/imgproc | Not run: no built library available | Not run | Not run |
| 4.12.0/imgproc | 525/525 | 525/525 | Pass |
| 4.13.0/imgproc | 525/525 | 525/525 | Pass |
| 4.14.0/imgproc | 525/525 | 525/525 | Pass |
| 5.0.0/geometry | 525/525 | 525/525 | Pass |

Native tests compile the included shim and test code with
`-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer` and warnings as
errors. Linked OpenCV libraries are **not** sanitizer-instrumented: do not
claim this detects every internal OpenCV memory error. Each completed native
campaign reports zero failed checks and exercises seven Float32 creation and
six rebuilding allocation failures, recovery, destruction, and retained
capacity/no stale site behavior. Pathological liveness research is not rerun
or represented as repaired by this task. GNATprove is not run: the changed
Ada code removes a version guard in the non-SPARK foreign-object wrapper;
packing/proof utilities are unchanged. Runtime validity/assertion profiles
and testing, not formal proof, qualify native state.

Hosted Linux/macOS CI is checked separately for the final PR head. Windows
remains skipped on PRs by established policy; manual/main-push execution is
required for Windows portability evidence. Pending CI is not a pass.

## Task 021: portable closest ellipse points

Starting main: `05004664116fa85ac51d6a6e8ad4df7c94d3365a`.
Branch: `feature/021-portable-closest-ellipse`, in an isolated worktree.
Baseline OpenCV 4.10.0/imgproc build and AUnit: **524/524**. That baseline
skipped ellipse functionality on old releases; the updated suite does not.

### Exact upstream sources and license

The full `solveFast` and `getClosestEllipsePoints` implementations were
inspected in:

- [4.12.0 shapedescr.cpp](https://github.com/opencv/opencv/blob/4.12.0/modules/imgproc/src/shapedescr.cpp),
  tag commit `49486f61fb25722cbcf586b7f4320921d46fb38e`.
- [4.13.0 shapedescr.cpp](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/src/shapedescr.cpp),
  tag commit `fe38fc608f6acb8b68953438a62305d8318f4fcd`.
- [5.0.0 shapedescr.cpp](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/src/shapedescr.cpp).

The solver and ellipse transformations are identical in these three sources.
The extracted block from `static void solveFast` through the final
`closest_pts_list).convertTo` has SHA-256
`a312244d13f20c895dbf773a191b3f8b43a53473099e8c60e3859ae5a6d0abc5`
in all three versions.
The private `cpp/closest_ellipse_compat.hpp` adapts only the input/output
container plumbing: typed vectors replace InputArray/Mat/OutputArray, with
explicit integer-to-float conversion and no ABI storage reinterpretation.
No native objects cross the ABI. `CV_PI` substitutes the identical binary64
`M_PI` constant for strict cross-platform C++17 availability.

The upstream file carries the Intel Open Source Computer Vision Library
license, Copyright (C) 2000 Intel Corporation, with third-party copyrights
reserved. Its copyright, conditions and disclaimer are retained in the
backport header. Source redistributions must retain them; binary
redistributions must reproduce them in documentation or accompanying
materials. Intel's name cannot be used for endorsement without permission.
This task does not change the crate's Apache-2.0 license.

### Arithmetic, ownership and validation review

- Compile-time dispatch uses the backport before OpenCV 4.12, and native
  `cv::getClosestEllipsePoints` on 4.12+ and 5.x. No optional unresolved
  native symbol is referenced on old versions. Native capability reporting
  retains its exact 4.12 threshold, independent of portable availability.
- Both public overloads, postconditions, C symbols, layouts and status
  constants are unchanged. Only unsupported-operation gating is removed.
  Old versions now perform the same pointer/count/capacity checks as newer
  versions instead of returning Unsupported before inspecting arguments.
- The solver retains initial `0.707f`, exactly three iterations, binary32
  products/divisions, `hypotf`, min/max operand order and `copysign`.
  Angle calculation retains the upstream binary64 multiply/divide followed
  by conversion to float; transforms retain `Matx23f` multiplication.
  Semiaxes, swapping and the added 90-degree rotation remain unchanged.
- Integer coordinates convert individually to binary32 before arithmetic:
  no integer subtraction or multiplication can overflow in this algorithm.
  Low bits of large integers may be lost, exactly as in the native routine.
- Squaring large semiaxes, transform overflow, underflow and zero solver
  divisors can produce nonfinite results even with finite valid input.
  A circle-center query is one such case. No extra iteration, arbitrary
  coordinate restriction, improved solver or fallback result is introduced.
- Ada remains responsible for finite fields/queries, positive dimensions
  and finite results, translating failures to `OpenCV_Error`. Existing
  local validity-check suppression preserves this under validation builds.
- ABI checks reject negative counts/capacities, missing ellipse, invalid
  pointer/count pairs and insufficient capacity. The result-size guard is
  retained for buffer safety. Count is zero before failure; publication
  follows successful computation. Empty input returns without indexing.
  Temporary vectors are private RAII storage; allocation exceptions remain
  caught by the existing exception translator. Ada-owned results retain
  iteration order, cardinality, shifted/high/null ranges and immutability.

**No public semantic validation is duplicated in the C++ shim.** The new
preprocessor guards select implementation/helper availability, not semantic
policy. Existing pointer/count/capacity and result-size checks are ABI safety.

### Qualification evidence

The registered suite now has **525 tests**, including an additional native
golden fixture with translated, rotated, swapped semiaxes and fractional
queries. Existing ellipse tests execute unconditionally on older versions;
capability tests still assert the exact native version thresholds.

`tests/native/closest_ellipse_equivalence.cpp` compares deterministic grids,
INT32 extrema, signed zero, extreme finite queries, circles, both semiaxis
orders, translations, five rotations, and very large/tiny dimensions.
On each native release it compares **51,900 coordinates** and checks equal
finite/NaN/Infinity classifications. Observed maximum absolute error is
**zero** on 4.12.0, 4.13.0, 4.14.0 and 5.0.0. Its permitted relative error
is `2e-5 * max(1, abs(native))`, allowing compiler/libm rounding, not a
different solver. The Ada golden fixture permits `2e-5` absolute error.
These are empirical equivalence results, not a proof for all binary32 input.

| OpenCV / backend | Normal AUnit | Validation AUnit | Native ASan/UBSan |
|---|---|---|---|
| 4.6.0 / imgproc | PASS 525/525 | PASS 525/525 | PASS |
| 4.10.0 / imgproc | PASS 525/525 | PASS 525/525 | PASS |
| 4.12.0 / imgproc | PASS 525/525 | PASS 525/525 | PASS |
| 4.13.0 / imgproc | PASS 525/525 | PASS 525/525 | PASS |
| 4.14.0 / imgproc | PASS 525/525 | PASS 525/525 | PASS |
| 5.0.0 / geometry | PASS 525/525 | PASS 525/525 | PASS |

The 4.12/4.13/4.14 environments are exact-tag minimal core/imgproc Release
builds, not version-macro simulations. 4.10 is the installed native library;
5.0 is the preserved exact-tag native installation. Native sanitizer runs
instrument the shim/test code, not the prebuilt OpenCV libraries.
The initial 4.6 attempt failed linking stale shared-cache Core objects built
against newer OpenCV; a second attempt failed pinning an index manifest.
Qualification therefore rebuilds released Core 0.3.0 in isolated storage
with its original upstream manifest. Neither failed attempt is a PASS.
That corrected 4.6 run passed both full suites and the sanitizer harness;
its capability query is False while the portable/golden fixture tests run.
4.10 likewise reports False and executes the backport. The older native
harness prints zero compared coordinates because no native reference exists
there; this is ABI/sanitizer qualification, not a native equivalence claim.

Hosted Linux and macOS qualification will be checked on the feature PR.
Windows is intentionally skipped on PR/feature pushes, retained for main
pushes and manual workflow dispatch; no Windows PR pass is claimed.
The feature workflow will also be manually dispatched for Windows evidence.
No platform toolchain, backend or ownership architecture is changed.

The historical Task 013 unsupported behavior below is superseded only for
`Closest_Ellipse_Points` by this task; other versioned features are unchanged.

## Baseline

- Starting main: `40b1e25a3cc3dc96c8d1eca862727791034693f7`.
- Initial research branch: `feature/013-versioned-approx-poly-n`, renamed
  without discarding this note to `feature/013-versioned-closest-ellipse`.
- Local OpenCV: 4.10.0, native `imgproc` backend.
- Baseline `alr -n build`: passed.
- Baseline `alr -n -C tests run`: 482 run, 482 successful, zero failed
  assertions and zero unexpected errors.
- Workflow 37098212017 was `in_progress` at the initial single check.
  The user subsequently reported an independent completed SUCCESS on main;
  this continuation did not poll it again.
- The annotated `0.1.0` tag object remains
  `0ca4437eba8422a9a3ba8ce8c761ef06e13eac7d`; its target is
  `86a18b138acb74bddb4ddb18033c59d4341020a6`.

## Verified declaration matrix

| Native release | approxPolyN | getClosestEllipsePoints | minEnclosingConvexPolygon | Rect2f Subdiv2D / initDelaunay |
|---|---|---|---|---|
| 4.6.0 | No | No | No | No |
| 4.10.0 | No | No | No | No |
| 4.11.0 | Yes | No | No | No |
| 4.12.0 | Yes | Yes | No | No |
| 4.13.0 | Yes | Yes | Yes | Yes |
| 5.0.0 | Yes | Yes | Yes | Yes |

Evidence is the full headers, not an API-documentation version selector:

- [4.6.0 imgproc.hpp](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/include/opencv2/imgproc.hpp)
- [4.10.0 imgproc.hpp](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/include/opencv2/imgproc.hpp)
- [4.11.0 imgproc.hpp](https://github.com/opencv/opencv/blob/4.11.0/modules/imgproc/include/opencv2/imgproc.hpp):
  approxPolyN at lines 4085–4087; only integer Subdiv2D bounds.
- [4.12.0 imgproc.hpp](https://github.com/opencv/opencv/blob/4.12.0/modules/imgproc/include/opencv2/imgproc.hpp):
  approxPolyN at 4107; getClosestEllipsePoints at 4436; only integer
  Subdiv2D bounds; no minEnclosingConvexPolygon declaration.
- [4.13.0 imgproc.hpp](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/include/opencv2/imgproc.hpp):
  Rect2f constructor at 1132, Rect2f initDelaunay at 1150, approxPolyN at
  4167, minEnclosingConvexPolygon at 4305, getClosestEllipsePoints at 4521.
- [5.0.0 geometry/2d.hpp](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/include/opencv2/geometry/2d.hpp):
  Rect2f constructor at 77, Rect2f initDelaunay at 95, approxPolyN at 353,
  minEnclosingConvexPolygon at 439, getClosestEllipsePoints at 709.
  `geometry.hpp` includes this header; the declarations are not in the
  umbrella header itself.

The first released approxPolyN version among these releases is **4.11.0**.
History corroborates the source comparison:
[upstream PR 25607](https://github.com/opencv/opencv/pull/25607) merged on
2024-07-09 as `b9649435173dba9355164cde5d8a958e93fb9b91`. GitHub's compare
API reports that commit ahead of 4.10.0 (108 commits, zero behind), and
4.11.0 ahead of that commit (446 commits, zero behind).

This matrix concerns native availability, **not** which Ada APIs are bound.
The first binding is getClosestEllipsePoints; Task 014 also binds Float32
Subdiv2D bounds. approxPolyN remains unbound.
Major versions beyond 5 remain outside the supported architecture.

## Implementation comparison

Complete approxPolyN bodies and their `PointStatus`, `neighbours`, `changes`,
`recalculation`, and `update` helpers were retrieved and compared:

- [4.11.0 approx.cpp, lines 864–1098](https://github.com/opencv/opencv/blob/4.11.0/modules/imgproc/src/approx.cpp#L864-L1098)
- [4.12.0 approx.cpp](https://github.com/opencv/opencv/blob/4.12.0/modules/imgproc/src/approx.cpp)
- [4.13.0 approx.cpp, lines 871–1105](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/src/approx.cpp#L871-L1105)
- [5.0.0 approx.cpp, lines 303–537](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/src/approx.cpp#L303-L537)

The approxPolyN implementation and helpers are byte-identical across these
four tags. The entire 4.11 and 4.12 approx.cpp files are also identical.
Changes elsewhere in 4.13 approx.cpp concern approxPolyDP and its legacy
wrapper, not approxPolyN. Native dependencies, especially convexHull, can
still differ; identical approxPolyN bodies do not prove identical results.
There is no approxPolyN definition in 4.6.0 or 4.10.0 approx.cpp.

The upstream tests at
`modules/imgproc/test/test_approxpoly.cpp` in 4.11–4.13 and
`modules/geometry/test/test_approxpoly.cpp` in 5.0 exercise integer and
Float32 outputs, request four sides with area stopping disabled, and check
bad arguments. Their approxPolyN fixtures and cases remain unchanged.
They do not establish extreme-coordinate, sentinel, or non-finite safety.
Their image/contour extraction fixture is not suitable for copying into
Geometry's Ada tests.

## Native semantics established from the body

1. Accepted input depths are exactly CV_32S and CV_32F, in a point-vector
   representation. A fixed output must be CV_32SC2 or CV_32FC2. Otherwise
   output depth defaults to input depth.
2. `nsides > 2`. The post-hull curve must contain at least nsides points.
3. With ensure_convex true, OpenCV calls convexHull on the original input.
   Duplicate, concave, self-intersecting, and repeated-traversal inputs are
   therefore processed as point sets for the hull. The stopping threshold
   nevertheless uses contourArea of the **original ordered input**, not
   hull area. Self-intersections and repeated traversal can change that
   reference area.
4. With ensure_convex false, OpenCV asserts isContourConvex and uses the
   original order. That local-turn predicate is not a proof of simplicity
   or single traversal. A thick contract must independently require a
   simple strictly convex polygon, without importing intersection-specific
   grid or exact-difference rules.
5. Epsilon must be positive or exactly -1. The source imposes no upper
   bound. It multiplies epsilon directly by area: 0.1 means 10%, not 0.1%.
   -1 disables stopping, though the threshold expression is still evaluated.
6. Each contraction removes one active vertex. Disabled stopping reaches
   nsides; enabled stopping can return more than nsides, up to the original
   hull/polygon cardinality. The proposed caller capacity of source count
   follows from hull cardinality <= source count and contractions only
   decreasing active cardinality. Native numerical failure can invalidate
   geometric promises without changing this count argument.
7. Output scans the original hull/curve index order, skipping removed
   entries. Updated intersections occupy the retained predecessor's slot.
   It does not rotate the output to start at a newly selected extreme point.
8. The priority queue orders by area then vertex index. Removed entries
   are popped; dirty entries are popped and replaced; a contraction leaves
   its entry dirty for later recalculation. Each active vertex initially has
   an entry and replacement preserves that entry. With finite ordered
   candidate areas, this supplies a queue-nonempty argument while size is
   above nsides and a finite progress argument: dirty entries are refreshed,
   removed entries discarded, and clean entries either stop or contract.
   NaN candidate areas break the ordering premise and require separate
   investigation; no arbitrary timeout is a semantic safety contract.

## Integer output is unsuitable

Integer inputs are converted to Point2f **inside** approxPolyN after any
integer convexHull call. New points are supporting-line intersections;
they need not be source vertices and can lie outside source bounds.

The integer-output loop performs
`static_cast<int>(round(hull[i].point.x))` and the corresponding Y conversion.
It has no representability guard or saturation. Even a retained source
coordinate INT_MAX rounds to 2**31 when converted to binary32. A triangle
containing INT_MAX, with nsides equal to its hull size, can thus reach an
out-of-range conversion without any intersection construction. Constructed
intersections present an additional route beyond integer range.

Both planned Ada overloads should request fixed Point2f output. Integer
input must still enter native OpenCV as CV_32S; converting it in Ada changes
the hull path and can collapse distinct integer vertices before hull
construction. Float32 output also preserves subpixel constructed vertices.

## Arithmetic inventory and unresolved conditioning contract

All of the following approxPolyN expressions are binary32:

- Three edge differences: next - vertex, vertex - previous, and
  second-next - next.
- Two products and a subtraction for cross.
- Two products, a subtraction, and division by cross for t.
- Two products and coordinate additions for the intersection.
- Four coordinate differences, two products, a subtraction, absolute
  value, and multiplication by 0.5 for candidate area.
- Conversion of contourArea's double result to float and multiplication
  by epsilon; running `extra_area += base.area`.

Finite source values alone do not keep these intermediates finite. Finite
differences can yield infinite products; subtracting infinite products
can yield NaN. A small nonzero denominator can overflow t or the
intersection. Constructed coordinates feed subsequent recalculations, so
an initial-coordinate bound alone is not yet a proven bound for every
iteration. A final finite-result check is necessary but insufficient:
NaN may already have entered the priority queue comparator.

The absolute parallelism test is `abs(cross) < 1e-8`. It records area
FLT_MAX and intersection (-1,-1). **There is no sentinel exclusion in the
selection loop.** If all eligible candidates have that area, one can be
selected with area stopping disabled. A sufficiently large or infinite
threshold can also allow selection with stopping enabled. The selected
(-1,-1) is finite: a finite-output check cannot diagnose it. Tiny strictly
convex polygons can reach this absolute-scale threshold even though their
mathematical geometry is well conditioned.

Converting contourArea to float can overflow; multiplying a finite fraction
by a finite area can overflow; extra-area accumulation can overflow. An
infinite threshold changes stopping semantics, including FLT_MAX-sentinel
selection. An upper fraction limit of 1 is not justified by source.

Count expressions requiring review include curve.rows vector allocation,
i+1, i-1, size-1, size--, incrementing last_free, output creation, and the
dependent convexHull allocation `total + 2`. The ensure_convex false path
also calls isContourConvex, whose `(n-2+n) % n` can overflow signed int
and whose integer products/subtractions can overflow. Its Float32 path
uses binary32 differences and products. These are distinct from
approxPolyN's floating numerical behavior and need ABI-safety guards.

Float32 hull inputs require finite checks before sorting because NaN
violates std::sort's strict weak ordering. Hull binary32 span and signed
zero handling must follow the existing source-derived hull policy. The
integer hull's signed differences also require the existing range policy.

**Outstanding before production implementation:** derive a non-arbitrary
conditioning contract covering iterative constructed vertices, queue NaNs,
FLT_MAX selection, and stopping arithmetic; validate it with native probes
and boundary cases. Complete the dependency/version comparison, ABI guard
classification, and runtime evidence. No numerical restriction has yet been
selected, and no supported-runtime result is claimed by this note.

## approxPolyN safety contract

**Gate result: NOT ESTABLISHED. Do not implement the binding on the basis of
the candidate contracts below.** The earlier statement that no supported
runtime was exercised is superseded by the 4.11 evidence in this section.
Failure to establish a contract here is not a proof that no useful safe
contract exists.

### Frozen native model

Re-read and diffed all four tagged implementations again. The complete
helpers and body are identical, with these line mappings:

| Operation | 4.11 / 4.12 | 4.13 | 5.0 |
|---|---|---|---|
| queue ordering, area then vertex ID | 900–907 | 907–914 | 339–346 |
| recalculation | 913–942 | 920–949 | 352–381 |
| active-list update | 944–954 | 951–961 | 383–393 |
| threshold evaluation | 998 | 1005 | 437 |
| queue processing / stopping | 1030–1063 | 1037–1070 | 469–502 |
| integer output conversion | 1073–1085 | 1080–1092 | 512–524 |

### Support-line invariant: exact arithmetic only

Let the four active vertices be P, V, W, Q in cyclic order. A valid exact
contraction computes X = line(P,V) intersect line(W,Q), replaces V by X,
and removes W. Edges P-X and X-Q lie on the two surviving supporting lines;
V-W disappears. All other edges are unchanged. Induction therefore proves
that, **in exact arithmetic, for a valid nonparallel contraction**, every
active edge lies on an original support line and each constructed vertex
is an intersection of two surviving original support lines.

This is **false as an exact invariant of the binary32 implementation**.
For the strictly convex integer-valued polygon

```
(0,0), (4,0), (5,2), (3,5), (0,3)
Sides = 3, epsilon = -1, ensure_convex = false
```

the first selected contraction constructs `(6.3333330154418945,0)`.
The original edge from `(5,2)` to `(3,5)` has direction `(-2,3)`;
its exact determinant residual at that stored point is
`9.5367431640625e-7`, not zero. The residual is computed in binary64 from
exactly represented binary32 inputs, so this example is not a residual
measurement-rounding artifact. Native output agrees with the model:

```
(6.3333330154418945,0), (3,5), (-4.5,0)
```

Thus original support-line intersections do not exactly enumerate later
native vertices. A rounded-geometry error envelope is required before
all-pairs conditioning can be a sufficient precondition.

### Minimal sentinel reproducer and aftermath

```
CV_32F input: (0,0), (1,0), (1,1), (0,1)
std::vector<cv::Point2f> output;
cv::approxPolyN(input, output, 3, -1, false);
```

All four candidates have cross zero, area FLT_MAX, and intersection
(-1,-1). Vertex ID breaks the tie; candidate zero is selected. Both the
instrumented model and real 4.11 return
`(-1,-1), (1,1), (0,1)`. This finite polygon does not enclose `(1,0)`.
Four source vertices are minimal for an actual contraction with nsides >=3.
No coordinate upper bound can fix this example: it is already unit scale.

With epsilon 0.1, the square returns unchanged: adding FLT_MAX exceeds the
threshold before mutation. With epsilon FLT_MAX, the unit-square threshold
is FLT_MAX; equality does not stop, so the sentinel is selected. For a
square of side 2 and the same finite epsilon, the threshold overflows to
+Inf and the sentinel is also selected. Area limiting is not a general
sentinel-safety contract.

The five-point polygon
`(0,0),(2e-6,0),(3e-6,1e-6),(2e-6,2e-6),(0,2e-6)` has all initial
candidates below the absolute cross threshold. After selecting a sentinel,
later recalculations become finite again. Native 4.11 returns
`(9.5367431640625e-7,2.9802322387695312e-6),(2e-6,2e-6),(0,2e-6)`:
it has lost the lower source vertices. A sentinel need not remain visible
as an explicit (-1,-1) in the final result.

Sentinels can also remain unselected when finite candidates reach the
requested cardinality first (the thin-trapezoid probe demonstrates this).
Rejecting every inserted sentinel would exclude some successful cases, but
accepting one requires a proof it cannot later become selectable.

### Finite-input non-finite intermediates

All targeted cases use four or more vertices and request three sides.
The following distinguish hazards rather than asserting a single magnitude
cutoff:

| Hazard | Input / observed model fields |
|---|---|
| Difference overflow | Rectangle `(-3e38,0),(3e38,0),(3e38,1),(-3e38,1)`: horizontal edge becomes Inf; some cross/area keys become NaN. |
| Product overflow and Inf-Inf | Diamond `(0,-1e20),(1e20,0),(0,1e20),(-1e20,0)`: cross is Inf-Inf, numerator Inf, t NaN, area NaN. Real 4.11 returns a NaN vertex. |
| t overflow with finite numerator/cross | `(0,0),(2e-20,0),(1e26,1e12),(1e26,2e12)`: candidate 1 has cross about `2e-8`, numerator about `1e38`, t Inf, intersection `(Inf,NaN)`, area NaN. Real 4.11 returned finite output, but the unsafe key was already inserted. |
| Intersection overflow with finite t | `(0,0),(1e33,0),(1e33,1),(0,1.0000001192092896)`: candidate 1 has cross about `1.19209e26`, numerator about `1e33`, t `8388608`, intersection X Inf and area Inf. |
| Area overflow with finite constructed point | `(0,0),(1e19,0),(1e19,1e19),(0,1.0000001192092896e19)`: candidate 1 has finite cross/t and intersection X about `9.09495e25`, but area Inf. FLT_MAX sentinels sort before Inf and are selected. |

An infinite key remains ordered by the source comparator; a NaN key does
not. For finite keys A < B and a NaN key N, neither A nor B compares less
or greater than N, yet A and B are not equivalent. The induced equivalence
relation is not transitive: this violates strict weak ordering. All NaN
keys are effectively incomparable regardless of vertex ID because even
`area == elem.area` is false. `std::greater<changes>` uses operator> and
does not repair that ordering. Observed completion is not evidence of safe
use of the standard heap algorithms under these conditions.

### Epsilon and accumulation

For finite inputs and valid count, contourArea's binary64 sum is finite:
even a count near INT_MAX times binary32-coordinate products is far below
DBL_MAX. It is nonnegative when oriented=false. Its binary32 conversion
and multiplication by positive epsilon can overflow. In the default
round-to-nearest environment the binary32 overflow boundary is
`FLT_MAX + 2**103 = 2**128 - 2**103`; using FLT_MAX as a preflight ceiling
would avoid depending on that rounding boundary. This is an arithmetic
observation, **not an adopted public rule**.

Finite positive epsilon times nonnegative area cannot itself produce NaN
in this environment; it can produce +Inf. Disabled epsilon -1 can produce
a -Inf threshold, which is computed but ignored. A +Inf enabled threshold
does change behavior: FLT_MAX candidates and even an Inf accumulated area
are not greater than it. A large octagon at radius 1e19 with epsilon
FLT_MAX exhibited Inf threshold and Inf accumulation. Its model trace
also has non-finite candidate areas; **an isolated accumulation-overflow
example with exclusively finite nonsentinel candidates was not established**.
Finite positive additions can overflow in principle; an eventual contract
must bound every partial sum, including the attempted contraction which
triggers stopping. Positive FLT_MAX plus a sufficiently large positive
partial sum can also overflow. NaN candidate areas can infect accumulation;
preventing such keys must precede any argument about stopping.

### Count and capacity audit

- With hull construction, retain `count <= INT32_MAX - 2` before packing or
  allocating, because convexHull allocates `total + 2` in signed int.
- Without hull construction, the independent native isContourConvex
  expression `(n-2+n)` requires `n <= 1073741824` on these sources. Integer
  input additionally needs protection against its signed coordinate
  differences and products; count validation alone is insufficient.
- For validated n >= nsides >=3, initialization `i+1`, `i-1`, `size-1`,
  loop increments, `size--`, and last_free remain in int range. Output
  dimensions are `1,size`; active cardinality only decreases.
- The priority queue starts with n entries. Dirty-entry replacement pops
  then pushes; removed-entry handling only pops; contraction does not push.
  Its size never exceeds n. STL allocation failures remain exceptions to
  contain, not signed-int count expressions.
- List mutation preserves one entry per active vertex and cardinality
  accounting independently of coordinates, provided the heap processing
  is valid. Source capacity is sufficient: hull size <= source count;
  each accepted mutation removes exactly one active vertex. The probes
  found no empty queue or cardinality violation, but this does not legalize
  heap operations with NaN keys.

### Integer and Float32 findings

Real 4.11 with integer input and fixed Point2f output confirms subpixel
constructed vertices `(6.3333330154418945,0)` and `(-4.5,0)` for the
ordinary five-point polygon. Integer hull input remains CV_32S.

For `(INT_MAX-8,0),(INT_MAX,0),(INT_MAX,8),(INT_MAX-8,8)` and four sides,
all X coordinates become `2147483648` in Point2f output: distinct integer
vertices collapse after the integer hull. Requesting three sides selects
a sentinel. Fixed integer output on this build returned INT_MIN for every
X. That is observed manifestation of an out-of-range conversion, not a
portable conversion result. The rectangle ending at 2**24 converts exactly
but still fails reduction because opposite supports are parallel. Hence
±2**24 alone is not an approxPolyN safety policy.

All Float32 inputs must be finite before any sort. Local 4.11 calls with
all-zero points, either canonical zeros or mixed signed zeros, both raise
the post-hull cardinality assertion. This does not establish signed-zero
equivalence for all nondegenerate inputs or justify canonicalization as
an architectural change; the existing hull policy remains necessary.

### Bounded research campaign and limitations

Ephemeral artifacts (not installed or committed):

- `/tmp/geometry-version-research/probe.cpp`: binary32 Point2f model,
  active linked list, native queue ordering, instrumentation, original-line
  labels/residuals, per-candidate edge/cross/numerator/t/area logging.
- `/tmp/geometry-version-research/targeted-4.11.log`
- `/tmp/geometry-version-research/fuzz-4.11.log`
- `/tmp/geometry-opencv-4.11` and `/tmp/geometry-opencv-4.11-build`:
  exact-tag minimal core/imgproc build; no installation.

Harness compiled using GNU C++17, -O2, -ffp-contract=off, warnings as errors.
Native 4.11 was built with its normal Release settings and no optional
CPU dispatch. Targeted native calls run in forked children with a two-second
alarm; the complete campaign has a 120-second external timeout.

Seed 13013 generated 20,000 polygons of 3–128 vertices using logarithmic
power-of-two scales (exponents -120 through 120), thin ellipses, rotations,
large translations, and some rounded integer-valued Float32 inputs. After
hull construction and native isContourConvex filtering, 10,220 cases were
retained. This is a native-filtered population, not an exact mathematical
proof of strict convexity. Side counts varied from 3 through hull size;
epsilon alternated between -1 and 0.1.

Model classifications (overlapping):

- 8,000 had neither non-finite intermediates nor sentinel selection.
- 4,371 inserted a sentinel; 2,130 selected one.
- 87 inserted NaN area keys; 90 had non-finite recalculation fields.
- 7,313 departed from exact original support lines.
- 111 began with finite nonsentinel candidates but developed a sentinel
  or non-finite candidate during subsequent processing.
- No empty queue or invalid result cardinality was observed.
- 7,275 failed an **exact zero-tolerance enclosure check**, including
  non-finite results. This count mixes tiny ordinary rounding violations
  with genuine geometric failure; it is not a count of tolerance-qualified
  binding failures.

Every twentieth generated case that survived filtering was also passed
to real 4.11: 551 child calls, 547 finite results, four non-finite results,
zero exceptions and zero signals/timeouts. These aggregate runtime checks
classify finiteness, not model/native pointwise equality or enclosure.
Targeted cases logged native output directly. No OpenCV 5.0 runtime was
built or tested in this continuation. No proof is inferred from fuzzing.

The candidate all-original-support-pairs test required finite direction
differences/cross/numerator, |cross| >=1e-8, finite native-equivalent pair
intersection and finite triangle areas against original vertices. It
accepted 2,758 campaign cases, with zero later model failures. **This test
was not falsified by this campaign, but its sufficiency was not proved.**
It evaluates intersections from original endpoints; native recalculation
uses rounded current endpoints. It also does not cover every triangle
formed from future constructed vertices. Exact support-line drift prevents
using the exact-arithmetic induction as that missing proof.

### Policy alternatives and precise remaining proof obligation

No static or predictive policy is accepted yet:

1. Coordinate magnitude alone fails even for the unit square. Minimum
   scale alone does not fix exactly parallel surviving supports.
2. Finite original coordinates/differences/cross alone fail via t,
   intersection, and area overflow.
3. Checking only initial candidates fails in 111 campaign cases.
4. All-original-pairs conditioning remains a possible basis, **if** supplied
   with a conservative recurrence bound for rounded stored vertices and
   every possible selection sequence. No such bound was derived here.
5. A predictive Ada model would need to cover native floating contraction,
   compiler FMA contraction, rounding/subnormal behavior, hull differences,
   and queue-order changes near area ties. Replaying this one GNU binary32
   model is not a portable preflight proof. A branch-covering interval/error
   model might work but has not been designed, bounded, or proved practical.

The outstanding obligation is to establish an inductive reachable-state
envelope, valid across supported native toolchains, such that **every
candidate recalculation** has an ordered finite non-NaN area key; every
selectable clean candidate avoids the FLT_MAX sentinel; all stored
intersections are finite; and all area thresholds/partial sums preserve
documented stopping semantics. It must cover candidates that will never
be selected because they still enter the heap. Bounds must include
rounding drift at every contraction and possible tie-dependent sequences.

Post-success checks of count, finite coordinates, convexity and enclosure
would still be appropriate if a safe preflight is established. No portable
enclosure tolerance has yet been derived. Postchecks cannot prevent prior
NaN heap keys, and finiteness cannot catch the sentinel reproducer.

**Decision: stop, leave production unchanged, do not commit or open a feature
PR.** A safe static contract may be possible; this investigation neither
proves it impossible nor meets the required universal-contraction proof.

That decision applied to the approxPolyN continuation. The subsequent user
direction explicitly pivots the feature PR to closest ellipse points while
preserving this research. Conclusion: **Deferred: native approxPolyN can
develop sentinel and non-finite contraction candidates from finite convex
input. A portable contraction-wide safety precondition has not yet been
established.** No approxPolyN production entry point is added.

## getClosestEllipsePoints: accepted safety boundary

Exact tagged source:

- [4.12 shapedescr.cpp, 890–993](https://github.com/opencv/opencv/blob/4.12.0/modules/imgproc/src/shapedescr.cpp#L890-L993)
- [4.13 shapedescr.cpp, 836–939](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/src/shapedescr.cpp#L836-L939)
- [5.0 shapedescr.cpp, 802–905](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/src/shapedescr.cpp#L802-L905)

The solver and operation bodies are identical in all three tags. The full
tagged headers reconfirm absence in 4.11 and presence in 4.12 (declaration
at imgproc.hpp:4436), making **4.12** the first release. The native
capability matrix above was reconfirmed from all six tagged headers.

Input accepts only CV_32S/CV_32F continuous two-coordinate vectors. Native
asserts n>0 and returns n CV_32F points in source order. Integer coordinates
are explicitly cast to float before the transform; no exact-integer ±2**24
restriction is warranted. Output is always floating, with no float-to-int
conversion. Width/height are halved; if width is smaller, semiaxes are
swapped and angle increased by 90 degrees. Native does not validate sizes:
zero sizes divide by zero, negative sizes are not meaningful ellipses.
Ada therefore requires finite center, size and angle, strictly positive
dimensions and finite Float32 queries, without an upper magnitude limit.

solveFast starts tx=ty=0.707 and performs exactly three iterations. Products
a*a, b*b, evolute expressions, hypot, q/t division and fixed-size Matx
transforms can overflow or generate NaN. Even positive subnormal dimensions
can underflow during halving. std::min/max clamp NaN expressions toward zero
in this implementation; when both components are zero, t=0 and normalization
can generate NaN again. All of these remain floating arithmetic: no value
controls allocation, array indices, integer conversion, comparator ordering,
or loop bounds. The only data-dependent branch swaps semiaxes. Thus these
numerical failures cannot produce nontermination or invalid memory access
through this algorithm. Unlike approxPolyN, post-result finite validation is
a sufficient boundary for these numerical failures, not a preflight model.

Stable finite-input NaN reproducer, verified with real OpenCV 4.12:

```
ellipse: center=(0,0), width=height=2, angle=0
query: (0,0)
result: (NaN,NaN)
```

Here a=b=1 makes ex=ey=0, so q=0 on the first iteration. Both clamped
components become zero and t=0. A circle with size (1e20,1e20) and query
(1,1) also produces NaN through squared-semiaxis overflow. Both are public
regressions expecting OpenCV_Error, not Constraint_Error or leaked NaN.
The exact native three-iteration approximation is preserved; no extra
precision or uniqueness is promised for closest points inside an ellipse.

Count is constrained to signed 32-bit range before Ada packing/allocation.
Native reserves n entries and iterates i=0..n-1, with no multiplied signed
count expression or count-dependent geometry search. One push per query
proves cardinality n. The shim checks capacity before native work and checks
result size equals n before copying; out_count is published only after copy.
Neither STL nor Mat crosses the ABI. Native allocation/other exceptions are
contained by the established status translation.

Unsupported ordering: clear diagnostic, require out_count, zero it, then
return Error_Unsupported before inspecting any other argument. Supported
paths validate all pointer/count/capacity combinations. The public version
gate precedes empty handling; supported empty input returns its exact null
range without calling the native n>0 operation. Every nonempty result
coordinate is inspected as a raw C float before public conversion. Output
uses Points'Range and a proved positional offset rather than incrementing
an index past Natural'Last.

The capability query uses stable IDs 1..4 and CV_VERSION_MAJOR/MINOR only.
Unsupported is the new stable status 5; existing statuses are unchanged.
The native optional call exists only in the 4.12+/5.x preprocessor branch.
The capability enumeration intentionally includes unbound native features.
It is not a binding-coverage query or authorization to invoke approxPolyN.

### Task 013 validation evidence

- Local OpenCV 4.10/imgproc: normal build and 499/499 normal and
  validation-profile AUnit tests; unsupported public/raw paths exercised.
  Symbol inspection found no getClosestEllipsePoints/approxPolyN reference
  in the 4.10 shim object. All four native capabilities are False.
- Ephemeral exact-tag OpenCV 4.12/imgproc: full suite 496/496 before the
  final range tests, then 499/499 validation-profile tests. Real native
  closest-ellipse functional tests execute. Direct capability probe reports
  `(1,1,0,0)`, demonstrating native approxPolyN availability without a binding.
- Ephemeral exact-tag OpenCV 5.0/geometry: 499/499 normal and validation
  tests; direct capability probe reports `(1,1,1,1)`.
- Native Subdiv2D fault-injection suite: zero failed checks on 4.10 and 5.0.
- Established GNATprove scope: all 277 checks proved (baseline scope had
  270), including Positional_Offset range/reconstruction checks. Native
  behavior is tested/trusted, not formally proved through the foreign ABI.
- GNATformat check and whitespace check pass. Modified Ada stays within
  79 columns. No new production/development dependency was added.
- C++ validation-boundary review: **No public semantic validation is
  duplicated in the C++ shim.** The result-size guard protects caller-buffer
  bounds and positional publication; its ABI-safety reason is documented.

The temporary sources/builds/install prefixes are outside the repository.
The 4.6 endpoint and Apple-toolchain behavior remain PR CI checks; local
5.0 execution is Linux/GNU evidence, not macOS evidence.

## Task 014: Float32 Subdiv2D bounds

Starting main: `c668ba039d8c1ce6697580dcae6d822e7a65572c` (PR #13).
The declaration matrix above was rechecked against the six exact tags.
`Subdiv2D(Rect2f)` and `initDelaunay(Rect2f)` are absent through 4.12 and
present first in **4.13.0**, also in **5.0.0**. Exact declarations:

- 4.6.0 `imgproc.hpp`: integer constructor/init at 1078/1085.
- 4.10.0 and 4.11.0: integer constructor/init at 1111/1118.
- 4.12.0: integer constructor/init at 1113/1120.
- [4.13.0 imgproc.hpp, 1129–1150](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/include/opencv2/imgproc.hpp#L1129-L1150):
  `CV_WRAP Subdiv2D(Rect2f rect2f);` and
  `CV_WRAP_AS(initDelaunay2f) CV_WRAP void initDelaunay(Rect2f rect);`.
- [5.0.0 geometry/2d.hpp, 74–95](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/include/opencv2/geometry/2d.hpp#L74-L95):
  the same two signatures, in native Geometry rather than Imgproc.

### Implementation and integer audit

The complete subdivision implementations in
[4.13.0](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/src/subdivision2d.cpp)
and [5.0.0](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/src/subdivision2d.cpp)
are byte-identical: SHA256
`7863b0dec9896d99d9a4b75ab6deb330632fd5a17fe12691761eea5a3b7f3a40`.
The Rect2f constructor (121–130) initializes flags and calls
`initDelaunay(rect)`. Both overloads (integer 502–546, Float32 548–592)
independently implement initialization; integer does not delegate to Rect2f.

For Rect2f, native initialization computes and stores:

```
Big = binary32(6.f * max(width,height))
topLeft = (X,Y)
bottomRight = (binary32(X+Width), binary32(Y+Height))
A = (binary32(X+Big), Y)
B = (X, binary32(Y+Big))
C = (binary32(X-Big), binary32(Y-Big))
```

It clears vertex/edge vectors before rebuilding, creates null slots, then
three vertices in order A/B/C (IDs 1/2/3), creates edges AB/BC/CA, sets their
endpoints and splices them. The arithmetic has no semantic guard. `locate`
(297) rejects `pt.x < topLeft.x || pt.y < topLeft.y ||
pt.x >= bottomRight.x || pt.y >= bottomRight.y`: native half-open limits.

The integer bodies in [4.6.0](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/src/subdivision2d.cpp),
[4.10.0](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/subdivision2d.cpp),
and [4.11.0](https://github.com/opencv/opencv/blob/4.11.0/modules/imgproc/src/subdivision2d.cpp)
use `3.f * MAX(rect.width, rect.height)`; [4.12.0](https://github.com/opencv/opencv/blob/4.12.0/modules/imgproc/src/subdivision2d.cpp)
and newer use `6.f`. All explicitly cast X/Y to float; normal C++ arithmetic
converts width/height to float before multiplying/adding, **not** integer
addition of the origin and dimension. Shared Ada validation converts each
integer field separately and uses the actual native factor. Integer overloads
still call integer native Rect, never Rect2f.

Independent native probes, before implementing the correction, inspected
protected topLeft/bottomRight via a temporary derived class and inserted at
the left edge. On actual 4.10.0, preserved 4.12.0, exact-tag 4.13.0, and 5.0.0:

| Descriptor | Effective upper X | Insertion at `(2**24,5)` |
|---|---|---|
| integer X=2**24, width=1, height=10 | 2**24 (collapsed) | OpenCV StsOutOfRange (-211) |
| integer X=2**24, width=2, height=10 | 2**24+2 | accepted, vertex 4 |
| Rect2f same values (4.13 / 5.0) | identical collapse/advance | same stored upper limits |

The tagged 4.6/4.11 expressions have the same binary32 extent semantics;
runtime claims above are only for the listed installed builds. The temporary
probe and exact-tag minimal 4.13 core/imgproc build are under `/tmp`, not
globally installed or committed. Positive integer dimensions therefore did
require a correctness fix: absorbed effective widths/heights now raise
OpenCV_Error before any native initialization.

### Source-derived safety contract

Ada requires finite X/Y/Width/Height and strictly positive dimensions.
`Float32_Value` is Core's `Interfaces.IEEE_Float_32` subtype. Preflight uses
this type's arithmetic and `'Machine` rounding for each native-stored result,
not binary64 comparisons of mathematical bounds. It checks:

1. Big is finite and positive (factor 6 Float32; version-correct 3/6 integer).
2. Rounded X+Width and Y+Height are finite and strictly greater than X/Y.
3. Rounded X+Big, Y+Big, X-Big and Y-Big are finite.

These are initialization conditions, **not** a guarantee of well-conditioned
later native predicates. No arbitrary maximum coordinate, minimum spacing,
or general geometric restriction is introduced. Overflow/validity checks are
suppressed only in the arithmetic/finite-inspection procedure, so intended
OpenCV_Error replaces Inf/NaN-driven Constraint_Error under validation.

Distinctness/nondegeneracy needs no additional public test: an effective
positive dimension crosses the upward rounding midpoint at the origin.
The adjacent downward binary32 spacing is at most twice the upward spacing,
including binade boundaries. Rounded Big, at least a rounded factor 3 times
either positive dimension, crosses both rounding midpoints. Thus the stored
A.x > X, B.y > Y, C.x < X and C.y < Y. Write their exact real differences as
`a=A.x-X > 0`, `b=B.y-Y > 0`, `c=X-C.x > 0`, `d=Y-C.y > 0`.
The determinant of `(B-A,C-A)` is `a*b + a*d + b*c > 0`, so A/B/C are
distinguishable and non-collinear even after rounding. This argument also
covers subnormal spacing. It does not claim a later binary32 area computation
cannot overflow/underflow, or prove native search liveness.

### API, unsupported ordering, and state machine

Root/Core public specs were searched: no canonical axis-aligned binary32
rectangle exists. `Subdiv2D.Float32_Rectangle` is a small four-field value
record; not a rotated rectangle or a second owner. `Create_Float32` and
`Reset_Float32` accept it, with distinct names preserving the released integer
`Create` / `Reset` API and unqualified rectangle aggregate syntax.
`Bounds_Float32` preserves the exact successful descriptor; after integer
initialization it reports each field converted as native does. `Bounds`
retains original integer values, but raises after Float32 initialization
rather than silently rounding/enclosing. Both retain last-successful bounds
even if the handle becomes unusable. Integer clients, including calls with
unqualified record aggregates, need no source changes or type qualifications.

Two fixed POD C ABI symbols exist on every build, using four C floats.
The actual Rect2f constructor and init calls are entirely inside the
4.13+/5.x preprocessor branches. Raw Create clears diagnostics, requires
out_handle and sets it null, then returns Unsupported on old versions before
inspecting bounds. Raw Reset returns Unsupported before inspecting either
argument. Ada capability gating precedes semantic validation, including
nonfinite input. Diagnostic: "Subdiv2D Float32 bounds require OpenCV 4.13 or
newer". No fallback and no optional unresolved native call on older builds.

Preflight/unsupported rejection makes no native initialization call and
preserves points, readiness, last-successful descriptor and mode. On supported
`Reset_Float32` the shim marks the handle unusable before native clears its
vectors.
Native failure keeps it unusable; Ada raises before publishing new bounds.
Successful `Reset_Float32` alone publishes the mode/descriptor and restores
readiness.
The existing integer path obeys the same state machine.

The existing global-allocation fault harness covers Float32 construction and
rebuild without production hooks. A ready native object retains its vector
capacity across clear(), so its Reset performs **no allocation**; arming the
injector verifies this rather than claiming an injected ready-object failure.
Rebuilding an existing default native handle with no storage exercises six
failing allocation positions; constructor exercises seven. Failures publish
no create handle, leave reset handle unusable, and a subsequent Reset recovers.
Public stored-bounds preservation after a native allocation failure is
established by publication-after-success code review, not by forcing an Ada
failure on a ready object. Public preflight and unsupported preservation are
directly tested with existing points and exact descriptors.

No public semantic validation is duplicated in the C++ shim. New guards are
only version dispatch and null-pointer safety; numerical policy stays in Ada.

### Task 014 validation evidence

- PR #13 post-merge workflow 37102354378: initially in progress; the permitted
  final single check found SUCCESS on Linux, macOS and Windows MSYS2.
- Local OpenCV 4.10.0/imgproc: `alr -n build` passed; full normal and
  validation-profile suites **521/521**, zero failed assertions/errors.
- Preserved exact OpenCV 4.12.0/imgproc: full normal and validation suites
  **521/521**. Capability False, optional public/raw operations Unsupported;
  integer subdivisions remain usable.
- Ephemeral exact-tag OpenCV 4.13.0/imgproc: minimal core/imgproc build and
  Ada build passed; complete focused Subdiv2D suite **60/60** in release and
  validation profiles. Capability True, real Rect2f constructor/reset, exact
  vertices 1..3, fractional insert/locate/nearest/lists/navigation/Voronoi,
  half-open edges, mode switching, invalid-field and arithmetic regressions.
- Exact OpenCV 5.0.0/geometry: full normal and validation suites **521/521**;
  complete focused Subdiv2D suite passed. No native Imgproc backend dependency.
- Native fault injection under AddressSanitizer/UndefinedBehaviorSanitizer:
  zero failed checks on 4.10, 4.13 and 5.0. Float32 construction/rebuild paths
  actually fail seven/six allocation positions on supported releases.
- Symbol inspection on 4.10 and 4.12 found the two fixed Float32 shim symbols
  and **no Rect2f native constructor/init reference**.
- Established GNATprove scope through the tests Alire environment: **277/277
  checks proved**, level 2, timeout 30, checks-as-errors, invocation header.
  New stateful binary32 validation is runtime-checked and tested, not part
  of that proof claim. The foreign boundary remains trusted.
- GNATformat checks, 79-column Ada checks and `git diff --check` pass.
  No new warnings/dependencies, generators, Mat/STL ABI exposure, ownership
  model, compiler/runtime strategy, or native backend selection changes.
  Local tests restored to release profile with native OpenCV 4.10.

An exploratory full-suite 4.13 run (before the last two bounds tests) had
**513/519 successful**, six failed assertions and no unexpected errors.
All six failures are unchanged `Minimum_Area_Rectangle_Tests` expectations:
4.13 adopted the newer minAreaRect angle/size conventions, whereas those tests
recognize that convention only for major version 5. The tagged
[4.12–4.13 rotcalipers.cpp diff](https://github.com/opencv/opencv/compare/4.12.0...4.13.0)
confirms the native change (angle default -90, new width/height ordering).
This existing test compatibility issue is outside Task 014; no minAreaRect
binding or tests were changed to hide it. Threshold runtime evidence above
is explicitly the entire focused stateful family, not a full-suite 4.13 pass.

Release version remains 0.2.0-dev; the 0.1.0 tag object and Alire-index state
are unchanged. The sibling Core worktree's unrelated user changes were not
modified, staged, or committed.

### PR #14 source-compatibility correction

Reviewed starting head: `6d5fa462cd91cfd2b96a2f6646a595ff6300785d`.
The initial Float32 Create/Reset overloads made released integer source such
as `Create ((X => 0, Y => 0, Width => 100, Height => 100))` ambiguous.
Only the new public operations are renamed to `Create_Float32` and
`Reset_Float32`; `Float32_Rectangle` and `Bounds_Float32` stay unchanged.
Six qualification-only edits in pre-existing tests and one in the README
example are removed. The existing integer-bounds test additionally compiles
and runs successful unqualified Create **and** Reset aggregates, preserving
the registered **521** test count.

All Task 014 Float32 callers use the distinct names. The production body
change is solely the declaration/end names and Create_Float32's call to
Reset_Float32. C ABI, shim, native calls, factors, capability, threshold,
validation arithmetic, error precedence, bounds publication and readiness
rules are unchanged from the reviewed head.

Correction validation:

- Local OpenCV 4.10/imgproc: build passed, normal and validation **521/521**.
- Preserved 4.12/imgproc: normal and validation **521/521**.
- Preserved 4.13/imgproc: complete Subdiv2D family **60/60** in both profiles;
  the previously documented unrelated full-suite minAreaRect caveat remains.
- Preserved 5.0/geometry: normal and validation **521/521**.
- Native ASan/UBSan fault injection: PASS, zero failed checks on 4.10 and 5.0;
  supported Float32 constructor/rebuild still exercises seven/six failures.
- Established GNATprove scope: **277/277** checks proved, with invocation
  header, through the tests Alire environment; no expanded proof claim.
- GNATformat checks, 79-column Ada checks and `git diff --check` passed.
  The old unqualified aggregate source compiles in every rerun environment.

## Task 015: minAreaRect representation boundary

Starting Geometry main: `1cbbf2db933ccd5f29adbe6f3ea8dfccf774ce5c`.
The Task 014 full-suite caveat above is historical; this task addresses it.

### Exact tagged source evidence

Independently inspected `cv::minAreaRect` and its calipers in:

- [4.6.0 imgproc/rotcalipers.cpp](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/src/rotcalipers.cpp#L360-L407)
- [4.10.0 imgproc/rotcalipers.cpp](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/rotcalipers.cpp#L360-L407)
- [4.11.0 imgproc/rotcalipers.cpp](https://github.com/opencv/opencv/blob/4.11.0/modules/imgproc/src/rotcalipers.cpp#L360-L407)
- [4.12.0 imgproc/rotcalipers.cpp](https://github.com/opencv/opencv/blob/4.12.0/modules/imgproc/src/rotcalipers.cpp#L360-L407)
- [4.13.0 imgproc/rotcalipers.cpp](https://github.com/opencv/opencv/blob/4.13.0/modules/imgproc/src/rotcalipers.cpp#L361-L427)
- [5.0.0 geometry/rotcalipers.cpp](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/src/rotcalipers.cpp#L361-L427)

The first new convention among these releases is **4.13.0**, not 5.0.
The complete 4.10, 4.11 and 4.12 source files have the same Git blob
`3bec592c9be43c49412836f7661f05855560828c`; 4.6 has the same minAreaRect
branches. The 4.13 and 5.0 minAreaRect and calipers implementations are
identical; their file diff only removes the legacy `cvMinAreaRect2` C wrapper
in 5.0. This is not inferred from native major version.

Through 4.12:

- Hulls with more than two vertices use width = norm(out[1]),
  height = norm(out[2]), angle = atan2(out[1].y, out[1].x).
- Two vertices use dx/dy = hpoints[1] - hpoints[0], width = segment length,
  height = 0, angle = atan2(dy, dx).
- Empty and singleton results retain the default angle 0.

From 4.13, including 5.0:

- The default angle is -pi/2 (-90 degrees).
- More than two vertices use width = norm(out[2]), height = norm(out[1]),
  angle = -atan2(out[1].x, out[1].y). If out[1].x = 0 and out[1].y > 0,
  dimensions are swapped and the default -90 angle is retained.
- Two vertices use dx/dy = hpoints[0] - hpoints[1], initially width = 0,
  height = segment length. dx = 0 swaps dimensions, retaining -90;
  dy < 0 swaps dimensions and uses atan2(dy, dx); dy > 0 keeps them and
  uses -atan2(dx, dy). A horizontal segment retains -90 and length in height.
- Radians are converted to degrees and debug checks enforce `[-90, 0)`.
  Calipers now receive the known hull orientation rather than deriving it.

For ordinary nondegenerate inputs the tuple representation changes, not the
minimum-area region. Width need not identify the same physical side on each
release. `Box_Points` is the better way to obtain physical vertices; native
starting vertex/order is still not a cross-version contract. This does not
promise numerical equivalence for degenerate or nearly degenerate inputs.

### Reproduced baseline and native probes

The untouched main full suite on exact-tag 4.13 ran **521** tests:
**515 successful, six failed assertions, zero unexpected errors**.
AUnit stops each procedure at its first failed assertion:

| Registered test | First failure: native actual versus old expectation |
| --- | --- |
| Minimum area axis rectangle | angle -90 versus +90 |
| Minimum area diamond | angle -45 versus +45 (original message only said `diamond angle`; direct native probe confirms the values) |
| Minimum area empty and one point | singleton angle -90 versus 0; the empty assertion incorrectly passed |
| Minimum area two-point conventions | horizontal width 0 versus 6 |
| Minimum area collinear duplicates translation | collinear width 0 versus 4 |
| Minimum area nonzero bounds input unchanged | angle -90 versus +90 |

Direct C++ probes were compiled and run against real 4.10.0, 4.12.0,
4.13.0 and 5.0.0 libraries. They confirmed all existing integer fixtures and
the following exact binary32 fractional fixtures (tuple: center; size; angle):

| Fixture | Through 4.12 | 4.13 / 5.0 |
| --- | --- | --- |
| Empty integer or Float32 | (0,0); (0,0); 0 | (0,0); (0,0); -90 |
| Integer 6x4 rectangle | (3,2); (4,6); +90 | (3,2); (4,6); -90 |
| Integer horizontal (0,0)..(6,0) | (3,0); (6,0); 180 | (3,0); (0,6); -90 |
| Integer positive (0,0)..(3,4) | (1.5,2); (5,0); -126.869904 | (1.5,2); (0,5); -36.869896 |
| Integer negative (0,0)..(3,-4) | (1.5,-2); (5,0); +126.869904 | (1.5,-2); (5,0); -53.130104 |
| Float32 [0.5,3] x [0.25,1.75] | (1.75,1); (1.5,2.5); +90 | (1.75,1); (1.5,2.5); -90 |
| Float32 (0.5,0.25)..(2,2.25) | (1.25,1.25); (2.5,0); -126.869904 | (1.25,1.25); (0,2.5); -36.869896 |
| Float32 (0.5,0.25)..(2,-1.75) | (1.25,-0.75); (2.5,0); +126.869904 | (1.25,-0.75); (2.5,0); -53.130104 |

Empty runtime probes use a typed zero-count Mat with harmless backing
storage. A zero-row Mat without storage, like an empty point vector, fails
`checkVector` before reaching the native empty branch. The original shim
compatibility branches returned 0 on 4.13 in both overloads, while these
native probes returned -90. That is a real **empty-result fidelity defect**,
not a new safety defect. Correct only those two compile-time thresholds to
include 4.13. Nonempty native results, Ada bodies, C ABI and public types
are unchanged; no normalization or native algorithm replacement is added.

### Regression design and safety review

`Uses_New_Min_Area_Rectangle_Convention` reads existing internal major/minor
accessors and uses `Major >= 5 or else (Major = 4 and then Minor >= 13)`.
No public version API or support for future native major versions is added.
Existing integer rectangle, diamond, empty/singleton, four segment directions,
collinear/translated and nonzero-bound fixtures now follow this boundary.

Three new registered tests cover raw integer/Float32 and public Float32 empty
results, the fractional rectangle, and both fractional segment slopes. They
check centers, side placement, angles, binary32 fields, nonzero bounds and
unchanged inputs; the fractional rectangle also differs from the rounded
integer path. Existing unordered/tolerance-qualified Box_Points integration
now checks a rotated nonsquare rectangle with corners (0,0), (4,4), (2,6),
(-2,2), as well as its axis-aligned fixture.

Independent source review found no new uncovered signed/count overflow,
NaN/Inf, assertion-range or C ABI memory hazard in the 4.13 transition.
Signed `n*3` allocation and Float32 hull/span/non-finite risks predate it and
retain the current preflight/result checks. The changed shim branches are
empty-container native compatibility, not duplicated public rejection
policy; the two version guards only select the native default angle.
No new public semantic validation is duplicated in the C++ shim.

### Full-suite validation

The registered count is now **524** (521 baseline plus three focused tests).
All runs below are the complete AUnit executable, not a Subdiv2D filter:

| Native OpenCV / backend | Normal (Geometry release) | Validation |
| --- | --- | --- |
| Local 4.10.0 / imgproc | 524/524 | 524/524 |
| Preserved exact 4.12.0 / imgproc | 524/524 | 524/524 |
| Preserved exact-tag 4.13.0 / imgproc | **524/524** | **524/524** |
| Preserved exact-tag 5.0.0 / geometry | 524/524 | 524/524 |

Every run has zero failed assertions and zero unexpected errors. Integer
conventions, all new Float32 fixtures and both Box_Points geometric fixtures
pass on both convention families. Validation profiles preserve expected
non-finite error handling without unexpected Constraint_Error. Geometry and
test builds retain warnings-as-errors. The 5.0 executable links native
geometry/core, not imgproc; the 4.13 executable links imgproc/core.

During validation, unrelated in-progress edits appeared in the sibling Core
worktree. A local link failed on missing Core ROI shim symbols, so the final
matrix was rerun against an isolated clean copy of its committed main
`67a99990583a0c454324ce187a6b8945e6741d6d`, using temporary ignored local
lockfile paths only. No Core source was modified or reverted. Geometry
manifests and dependency requirements are unchanged.

Local 4.10 native Subdiv2D allocation-fault tests pass under AddressSanitizer
and UndefinedBehaviorSanitizer: **zero failed checks**, two on-edge and two
inside failures correctly mark the handle unusable. The Float32-bounds fault
paths are unsupported on that release, as expected. GNATformat checks,
79-column Ada checks and `git diff --check` pass. No release, tag, index,
platform compiler/runtime or native backend selection changes are made.

GNATprove through the tests Alire environment proves **277/277 checks**, level
2, timeout 30, checks-as-errors and an invocation header, in a fresh output
directory. The scope explicitly lists the same four Geometry helper bodies
plus Core's `opencv-internal-safe_arithmetic.adb` (266 Geometry checks and 11
Core checks). Explicitly listing the latter avoids relying on cached imported
unit accounting in the earlier combined summary. Native results and the
foreign boundary remain trusted/tested, not formally proved. The tests crate
is restored to the Geometry release profile and local OpenCV 4.10 afterwards.

## Task 016: minEnclosingConvexPolygon safety gate

Status: **deferred; the safety gate fails.** In each examined release,
4.13.0, 4.14.0 and 5.0.0, some finite input makes the native code read out
of bounds. No known input precondition prevents it unless Geometry
reimplements the algorithm. Production Ada, the C ABI, the C++ shim, the
AUnit tests, manifests and the version are unchanged.
`Minimum_Enclosing_Convex_Polygon_Feature` keeps reporting native API
availability (True on 4.13+ and 5.x), not a binding.

The first research commit, `eb77dd67c7424c03fd537b0e45a2b0c2e924ac8a`,
changed only this document, `README.md` and `docs/coverage.md`. A follow-up
audit tightened its claims and added an opt-in probe, runner and frozen
corpus ([tooling](#reproducible-research-tooling)). It also compared
upstream [PR 30111](#upstream-pr-30111-controlled-comparison) before and
after. Each fact below is labelled source-derived, measured on the stated
builds, or empirical.

### Baseline

- Starting main: `74f362ae621b14f7c35993ea022768842ba6c858` (PR #15 merge),
  unchanged when the audit fetched it. Branch:
  `feature/016-versioned-min-enclosing-convex-polygon`.
- Version `0.2.0-dev`. The annotated `0.1.0` tag object remains
  `0ca4437eba8422a9a3ba8ce8c761ef06e13eac7d` with target
  `86a18b138acb74bddb4ddb18033c59d4341020a6`; manifests and dependencies are
  unchanged.
- The first research run, local OpenCV 4.10.0 with native imgproc, reported
  `alr -n build` passing and `alr -n -C tests run` **524/524**, with zero
  failed assertions and errors. That working tree's Alire lockfile links
  `opencv_core` to the sibling Core checkout, so the run depended on whatever
  Core branch was checked out there. The audit's revalidation does not
  depend on it; see [Validation](#task-016-validation-evidence).
- PR #15 post-merge workflow 37141670018 completed with SUCCESS on Linux,
  macOS and Windows MSYS2.

### Exact tagged sources

Inspected at exact tags of `opencv/opencv`, not in documentation. All tags
are annotated. The table gives each tag object and the commit it targets,
both re-resolved through the GitHub API during the audit.

| Tag: tag object → commit | Implementation and its SHA-256 | Declaration |
|---|---|---|
| 4.6.0: `8a185195` → `b0dc4741` | none | none |
| 4.10.0: `67f3511f` → `71d3237a` | none | none |
| 4.11.0: `1d3b34dd` → `31b0eeea` | none | none |
| 4.12.0: `cbee6841` → `49486f61` | none | none |
| 4.13.0: `2e1f8da6` → `fe38fc608f6acb8b68953438a62305d8318f4fcd` | `modules/imgproc/src/min_enclosing_convex_polygon.cpp`, `d9be1d250fade8f0b56f633fc1dfcd42e69f583e0a9f9822db7186655dff821e` | `imgproc.hpp:4305` |
| 4.14.0: `ea8e6079` → `0654a42e19215ef25b1d367d822f3c630447e7c7` | same path, `3fd651cee9c7ab0f0e10902b10a4c28a4c28444633e06e1cb262a7d1a857e67c` | `imgproc.hpp:4314` |
| 5.0.0: `9e2ede96` → `40738fb16ceddb5fb3fea747585f7ce6abb0605b` | `modules/geometry/src/min_enclosing_convex_polygon.cpp`, same SHA-256 as 4.14.0 | `geometry/2d.hpp:439` |

Scope: these seven are the only releases examined. On 2026-10-04 the newest
`opencv/opencv` tags were 5.0.0 and 5.0.0-alpha. No claim is made about any
other release, branch or vendor build. The 4.x branch head fetched then,
`62587ae9976b28cfa61ad940d0e7f610b8742ee4`, has the 4.14.0 file byte for
byte.

4.14.0 was tagged after the earlier matrix was recorded. Its approxPolyN
(4176), getClosestEllipsePoints (4530) and Rect2f Subdiv2D (1132/1150)
declarations are also present, consistent with the existing thresholds.

The 4.14.0 and 5.0.0 implementations are byte-identical. They differ from
4.13.0 only by the added line `sides.reserve(k);` in `findKSides`, from
[upstream PR 28569](https://github.com/opencv/opencv/pull/28569), which fixed
a GCC `-Wstringop-overflow` false positive and changed no logic. That line
shifts the later line numbers by one. The bodies of the two helpers called
before the chain code were compared at each tag. The `convexHull` body is
identical in 4.13.0, 4.14.0 and 5.0.0. The `contourArea` body is identical
in all three, apart from the `cv::` qualification used in 4.x. It lives in
`imgproc/src/shapedescr.cpp` on 4.x and `geometry/src/geometry.cpp` on 5.0.0.

The upstream tests (`test_convhull.cpp`) are input_errors,
input_corner_cases, unit_circle (n=64, k=7), random_points (n=100, k=7, on
[1,101)) and pentagon (k=4). None covers k=3 with a larger hull or
sub-unit coordinate scales.

### Native contract derived from the body

```
n = checkVector(2); CV_Assert(!empty && n >= k)
CV_CheckGE(n, 3); CV_CheckGE(k, 3)
convexHull(points, std::vector<Point2f> ngon, clockwise = true)
hull <  k                     -> log warning, release output, return 0
hull == k                     -> copy hull, return contourArea(hull)
contourArea(hull) < 1e-6      -> log warning, release output, return 0
otherwise                     -> findMinAreaPolygon(ngon, kgon, k)
```

Here and below, n is the hull vertex count. `findMinAreaPolygon` builds
`Chains(ngon, k)`, fills the one-sided and h-sided chains, and calls
`minimumArea(n, k)`. That routine selects only pairs with
`single_sides[i][j].exists && middle_sides[k-3][j][i].exists`. When none
qualifies, it returns the default `Minimum{max, -1, -1}`.
`findMinAreaPolygon` then passes `min.i` and `min.j` to `findKSides`
**unchecked**, and `findKSides` immediately indexes `single_sides[i][j]`.
None of the examined releases, nor the 4.x head above, has a guard there.

- **k = 3, hull of more than 3 vertices, hull area ≥ 1e-6**
  (source-derived). `calcMiddleChains(0)` sets every
  `middle_sides[0][i][j].exists = false`, so `minimumArea` cannot select a
  pair. Every input on this path reaches `findKSides` with i = j = −1, and
  `single_sides[-1]` indexes outside the outer vector's storage. The read
  itself is certain. Its consequence is not: what it returns, and whether a
  fault follows, depends on the heap.
- **k = 3, observed consequences.** Every instrumented k = 3 run reported
  that read (ASan) or stopped at the libstdc++ bounds assertion. Release
  runs mostly stopped with SIGSEGV. Some release runs survived the read and
  then failed `CV_Assert(h != 0)` in `reconstructHSidedChain(0, …)`. That
  happened in 31 of the k = 3 fuzz cases below, which raised `cv::Exception`
  −215 only *after* the out-of-bounds read. That exception is not
  containment.
- **k ≥ 4.** The same sentinel occurs whenever no chain pair qualifies.
  Intersection and balanced-side tests compare cross products of binary32
  differences, evaluated in binary64 by `Point_::cross`, with the absolute
  `EPSILON = 1e-6`. Those products scale with squared coordinates.

Output shape also differs (measured). Mat output is k×1 `CV_32FC2` on
4.13.0 and 4.14.0 but 1×k on 5.0.0 and on both 5.x commits below. Any
future shim would have to accept both shapes through `checkVector(2)`.

#### Scale observations (empirical only)

These come from fixed inputs on the builds named here. They suggest where
the k ≥ 4 sentinel appears, but prove nothing. No threshold below is a
precondition.

- Regular 33-gon at k = 4: r = 0.004 and 0.005 read out of bounds;
  r = 0.009 and 0.01 return a polygon. The hull edge is 2r·sin(π/33), so L²
  is about 9.1e-7 at r = 0.005 and 3.6e-6 at r = 0.01.
- Regular 200-gon at k = 4: r = 0.03 (L² ≈ 8.9e-7) reads out of bounds;
  r = 0.04 (L² ≈ 1.6e-6) returns a polygon.
- 50-point arc of span 3.14159 at k = 8: r = 0.003 reads out of bounds. At
  k = 4 the same points return a polygon.

These boundaries are consistent with a squared hull-edge length near the
absolute EPSILON. However, short edges and near-parallel sides can occur at
any scale, and other tests in the dynamic program apply the same EPSILON to
other quantities. No coordinate or edge-length bound has been shown to be
sufficient.

Returned polygons also change with scale (release 4.13.0, re-measured in the
audit):

- For the arc at k = 4, area/r² is 1.73080 for r from 0.02 to 1e6, but
  2.46272 for r from 0.003 to 0.01. The arc's exact minimum-area enclosing
  rectangle is 1.99897·r², so the small-scale result is provably not
  minimal. The first research compared it with the 2·r² bounding box.
- For a regular 33-gon at k = 4, area/r² is 4.012427 for r from 0.01 to
  1e37 and 4.093854 at r = 0.009. Its exact minimum enclosing rectangle,
  3.98642·r², is smaller in both cases. So this k = 4 result is not minimal
  at any scale tested.

### Sanitizer and native evidence

All results here are from Linux x86-64 with g++ 14.2.0. Each version was
tested in three builds, using the runner described
[below](#reproducible-research-tooling):

- **release**: the probe linked to the unmodified installed libraries.
- **asan**: the exact upstream implementation file, unmodified, compiled
  into the probe with `-fsanitize=address,undefined` against a stub
  `precomp.hpp` of public headers only. It links that version's own OpenCV
  build for `convexHull`, `contourArea` and Core.
- **asan-assert**: the same, plus `-D_GLIBCXX_ASSERTIONS`.

The 4.14.0 file is linked against an exact-tag 4.14.0 build. The first
research had linked it against 4.13.0. Every case runs in its own child
process under a timeout.

| Input | k | 4.13.0 / 4.14.0 / 5.0.0 result |
|---|---|---|
| square (0,0),(10,0),(10,10),(0,10), and translated by (10,10) | 3 | out-of-bounds read in `findKSides` |
| upstream pentagon; PR 30111's pentagon; a hexagon | 3 | out-of-bounds read in `findKSides` |
| regular 33-gon, r = 0.004 / 0.005 (hull area 5.0e-5 / 7.8e-5) | 4 | out-of-bounds read |
| regular 200-gon, r = 0.03 (hull area 2.8e-3) | 4 | out-of-bounds read |
| 50-point arc, r = 0.003 (hull area 1.4e-5) | 8 | out-of-bounds read |
| triangle (0,0),(0,4),(4,0) | 3 | hull == k path: the hull, area 8 |
| upstream pentagon | 4 | area 90, the upstream test's vertices |
| regular 64-gon, r = 1 | 7 | area 3.36418049 |

All hull areas above exceed the native 1e-6 singularity threshold. The
first research used a 4 × 4 square at k = 3. The corpus uses PR 30111's
10 × 10 square instead, and keeps the 4 × 4 square at k = 4 (`square4_k4`).

- asan-assert: every out-of-bounds case stops at `Assertion '__n <
  this->size()' failed` (SIGABRT) inside `findKSides`.
- asan: ASan reports a `heap-buffer-overflow` READ of 8 bytes in
  `findKSides`, at line 919 of the 4.13.0 file and line 920 of the 4.14.0
  and 5.0.0 file. For the r = 0.005 33-gon the access is "24 bytes before
  792-byte region": index −1 of the array of 33 row vectors, each 24 bytes.
  For the k = 3 square, the access is "8 bytes after 96-byte region".
- In the first research, gdb on an instrumented build showed
  `findKSides(k=3, i=-1, j=-1)` for the 4 × 4 square, `(4, -1, -1)` for the
  r = 0.005 33-gon, and `(4, 24, 6)` for the r = 0.01 control.
- release: `libopencv_imgproc.so.413`, `.so.414` and
  `libopencv_geometry.so.500` stop with SIGSEGV for every out-of-bounds
  case in this table.
- UBSan reported nothing. No C++ exception is raised before the read, so
  exception containment in a shim cannot help.

Input depth: `std::vector<Point>` and `CV_32SC2` input raise
`cv::Exception` −215 on every build examined, because `convexHull` writes
CV_32S into the fixed `vector<Point2f>`. Only CV_32F input is accepted, so
integer `Contour` input would need an explicit Float32 conversion.

### Fuzz campaign

The generator is now in the probe as `--fuzz SEED ITERATION`. It produces
random clouds, circle samples, 1000:1 slivers, 7×7 integer grids and
regular polygons. Each case has n in 4..40, k in 4..n−1, and a scale of
1e-3, 1e-2, 1, 1e3 or 1e6. The generator uses libstdc++'s distributions, so
cases regenerate identically only with libstdc++. The corpus therefore
freezes the cases it uses as bit patterns.

The audit reran the whole campaign with the runner. Each case runs in its
own child process. Every returned polygon is checked with exact rational
arithmetic on its binary32 vertices:

- count = k and all values finite;
- convexity, and enclosure of every hull vertex;
- the reported area against the vertices' exact area;
- comparison with two independent competitor bounds:
  - the exact minimum-area enclosing rectangle when k = 4;
  - the smallest triangle on three hull-edge lines when k = 3.

A polygon is reported as "not minimal" when either competitor is strictly
smaller. Both competitors enclose the hull, so that conclusion is a proof.
The converse does not hold: passing these checks does not show minimality.

| Build | Cases | Polygon | Not minimal | Empty | Exception | Crash |
|---|---|---|---|---|---|---|
| release 4.13.0, 4.14.0, 5.0.0: each, seeds 1–4 | 6000 | 2795 | 102 | 2682 | 0 | **421 SIGSEGV** |
| asan 4.13.0, 5.0.0: each, seeds 1–2, iterations 0–599 | 1200 | 585 | 17 | 522 | 0 | **76 ASan** |

Outcomes, and every returned area, are identical case by case across the
three releases and the 5.x base below. The ASan crashes are exactly the
release crashes among those iterations. All 421 crashes are at scale 1e-3,
and all ASan reports are the `findKSides` heap-buffer-overflow. UBSan
reported nothing. No returned polygon failed a validity check.

The first research reported 2897 "valid" polygons because it did not test
minimality. Of those, 102 are not minimal, all at k = 4 and at every scale
(5, 24, 20, 22 and 31 cases from 1e-3 up to 1e6). Each is larger than the
exact minimum-area enclosing rectangle, by up to 75%.

The first research's initial ASan run under-counted crashes, because ASan's
default exit status 1 collided with that harness's "empty" status. The
runner uses distinct sanitizer exit statuses. The absence of crashes at
scales ≥ 1e-2 in this campaign is test evidence, not a contract.

**k = 3 variant.** This variant keeps each generated point set but passes
k = 3 (seeds 1–2, iterations 0–1499, 3000 cases). On release 4.13.0,
4.14.0, 5.0.0 and the 5.x base the results were:

- 2592 SIGSEGV;
- 31 `cv::Exception` −215 `h != 0`, raised after the out-of-bounds read;
- 353 empty (hull below k, or singular);
- 24 polygons, all with a 3-vertex hull, that is, on the hull == k path.

With library assertions, the 4.13.0 source stops at the assertion in all
2623 cases that reach `findKSides`.

### Cost and arithmetic audit

Storage, complexity and timing are separate claims with different evidence.

**Storage (source-derived; sizes measured).** `Chains(ngon, k)` allocates
four kinds of nested `std::vector` storage:

- `single_sides`: n² `Segment`s;
- `middle_sides`: k·n² `Segment`s;
- two n×n intersection caches.

With g++ 14.2.0 on x86-64, a `Segment` is 16 bytes, a cache entry 32 bytes,
and each row vector adds 24 bytes. The total is therefore about
(16k + 80)·n² bytes, all allocated up front before any result is known.
For n = 400, k = 49 that is about 138 MB.

**Complexity (source claim, not verified).** The source header cites
Aggarwal, Chang and Yap and states Θ(n² log n log k). The audit did not
check that bound against this implementation.

**Time and memory (empirical only).** Points on a radius-1000 circle, one
run per configuration, release 4.13.0, re-measured by the audit. The
PR 30111 head build was within 15% on every row.

| n | k | Wall time | Peak RSS |
|---|---|---|---|
| 200 | 4 / 16 / 49 | 0.08 / 0.09 / 0.10 s | 12 / 20 / 41 MB |
| 400 | 4 / 16 / 49 | 0.65 / 0.69 / 0.75 s | 29 / 59 / 143 MB |

Time grew about 8× from n = 200 to 400. Two sizes cannot establish an
exponent, so the first research's "roughly n³" is withdrawn. Under an
address-space limit of 60, 100 or 140 MB, n = 400 and k = 49 raised
`std::bad_alloc`; at 200 MB it returned. A shim would contain that
exception. However, address-space limits are not a portable defense.
Without one, a very large request can meet the OOM killer instead, which
the audit did not exercise.

**Integer arithmetic (source-derived).** Table dimensions are passed to the
vector constructors as `size_t`. The largest `int` intermediates are:

- `j1 + n + j2`, at most 3n − 2;
- `j + n - i`, `(e - 1 + n)` and `(i + h_floor + 1)`, below 2n + 1.

Every index is already in 0..n−1, apart from the −1 sentinel. So no signed
overflow occurs while 3n − 2 ≤ `INT_MAX`, that is n ≤ 715 827 883. That
limit is far beyond any feasible allocation. `n = (int)checkVector(2)`
narrows a `size_t`, which matters only above `INT_MAX` points; a binding
would pass an `int32_t` count.

### Why no defensible contract exists

A binding over the examined releases would need a preflight showing that
`minimumArea` will find a pair. None is available:

- **k = 3** with a hull of more than three vertices and area ≥ 1e-6 could
  be rejected exactly, since that path always reaches the read. But k = 3
  is the documented minimum, and rejecting it still leaves k ≥ 4 unsafe.
- **k ≥ 4.** Whether the sentinel occurs depends on EPSILON-thresholded
  tests across the whole chain dynamic program. The only known way to
  predict it exactly is to evaluate that program, and `.clinerules` forbids
  reimplementing it. The observed scale boundaries are not a proven
  sufficient condition; this is the same situation as approxPolyN. Nothing
  proves that no simpler sufficient precondition exists, but none has been
  found.
- **Containment.** A SIGSEGV cannot be contained by the shim, and process
  isolation would be an architectural change.
- **Substitution.** Silently substituting `minEnclosingTriangle` for k = 3
  is ruled out.

### Upstream PR 30111: controlled comparison

[PR 30111](https://github.com/opencv/opencv/pull/30111), "geometry: fix a
crash in minEnclosingConvexPolygon for k = 3", opened 2026-09-30, targets
5.x. Its state on 2026-10-04:

- open, not a draft, not merged, no reviews;
- its one CI run, `PR:5.x`, ended `action_required`, awaiting maintainer
  approval;
- it is in no release.

The commits compared:

- **Base:** `20e367198c7adde8f1efc0f525256b1e15798024`, the 5.x head at the
  time. Its implementation file is byte-identical to 4.14.0 and 5.0.0.
- **Head:** `01f4d0e5da231d00c1eca735a0880b492a69fdde`, a single commit. Its
  implementation file is
  `5f33b6169bfee0c0995e6f2704defd02d47ce096a0297e9f36b89082ab27fa91`. It also
  adds six tests to `test_convhull.cpp`.

The implementation diff changes four places (15 lines added, 3 removed):

1. `calcOneSidedChains` also computes the one-sided chain between each pair
   of adjacent sides: `findSingleE(i, i−1, i+1, i−2)`, indices mod n.
2. `calcMiddleChains(0)` sets `exists` from the flush intersection's
   validity instead of `false`, so zero-length chains can be selected.
3. `findKSides` calls `reconstructHSidedChain` only when k > 3, so
   `CV_Assert(h != 0)` is no longer reached for k = 3.
4. `findMinAreaPolygon` raises `CV_Error(StsError, "minEnclosingConvexPolygon:
   no valid enclosing polygon found")` when `min.i < 0 || min.j < 0`. This
   happens immediately after `minimumArea` and before any use of the indices.

**Guard placement (source-derived).** Change 4 covers the one sentinel this
research found, and `findKSides` is reached only from there. Deeper
reconstruction indices are not guarded. `reconstructHSidedChain` and
`findKVertices` index tables with stored `side` values. A chain that the
h ≥ 1 code marks as existing has a valid side. A zero-length chain made
selectable by change 2 has `side = −1`, but for k = 3 it is never used as
an index: `findKSides` then holds sides {i, j, s}, with s from
`single_sides[i][j]`, which change 1 makes valid for adjacent pairs. No
instrumented head run reported an out-of-bounds access. This is an
observation, not a proof that no other path exists.

**Builds.** Base and head were built from `git archive` trees into separate
prefixes, with the same CMake options:

- options file SHA-256 `f43b386f…`;
- Release, shared, `BUILD_LIST=core,geometry`;
- IPP, ITT, Eigen, LAPACK, OpenCL, CUDA, TBB, OpenMP and KleidiCV off;
- pkg-config files generated.

Exact-tag 4.14.0 was built with the same options except
`BUILD_LIST=core,imgproc`. The installed 4.13.0 and 5.0.0 builds from
earlier tasks were reused, and the system OpenCV was not touched. The
head's instrumented builds compile the head's implementation file against
the base libraries. That is sound because the extracted base and head trees
differ only in the implementation file and `test_convhull.cpp`.

| Evidence | Base, 4.13.0, 4.14.0, 5.0.0 | PR 30111 head |
|---|---|---|
| Frozen corpus, 33 cases; release, asan and asan-assert each | 14 crash | no crash: 11 `cv::Exception`, 13 polygon, 6 not minimal, 3 empty |
| k ≥ 4 fuzz, 6000 cases, release | 421 SIGSEGV | the same 421 cases raise `StsError`; every other outcome and returned area is identical |
| k ≥ 4 fuzz, seeds 1–2, 3000 cases; asan and asan-assert | 207 SIGSEGV (release base) | the same 207 raise `StsError`; no sanitizer report |
| k = 3 fuzz, 3000 cases; release, asan and asan-assert | 2592 SIGSEGV + 31 `h != 0` (release); 2623 assertion (asan-assert 4.13.0) | 2427 polygon, 220 `StsError`, 353 empty; no sanitizer report |

The head's 220 k = 3 exceptions are all at scales 1e-3 and 1e-2. The six
upstream head tests were not built, because upstream test infrastructure
was out of scope. With LeakSanitizer enabled, six spot checks of the head's
exception and k = 3 paths reported no leak.

**Geometric checks (exact arithmetic on the binary32 values).**

- **Square, k = 3.** The head returns (20,10), (0,−10), (0,10), area exactly
  200. The smallest triangle enclosing a parallelogram has twice its area,
  so 200 is optimal; `minEnclosingTriangle` also returns 200. The
  translated square gives 200 as well, and the first research's 4 × 4
  square gives 32, also optimal.
- **Rectangle competitor, k = 4.** The head does not change k ≥ 4 results.
  Its non-minimal k = 4 polygons are exactly the releases': 102 fuzz cases,
  plus the corpus's regular 33-gons at r = 0.009, 0.01 and 1e37, the
  200-gon at r = 0.04, and the r = 0.003 arc. The exact minimum-area
  enclosing rectangle beats each of them.
- **Triangle competitor, k = 3.** The smallest triangle whose sides lie on
  three hull-edge lines encloses the hull, so any larger result is provably
  not minimal. Of the head's 2427 k = 3 triangles in the fuzz run, 525 are
  larger than that competitor, by a median of 61% and up to 4.9×. PR 30111's
  own pentagon gives 169.02 against 131.73.
- **`minEnclosingTriangle` oracle, used cautiously.** It is an independent
  OpenCV algorithm, but it rounds its vertices to binary32. The runner
  therefore accepts its area as a bound only when those vertices exactly
  enclose the input. On the corpus it matched the head's area for the
  square and the hexagon, both with exact enclosure. On the upstream
  pentagon its triangle missed enclosure by a relative 2.3e-8, so it was not
  used there.

**Conclusion.** The head turns every observed out-of-bounds read into either
a result or a contained `cv::Exception`. That is necessary for a binding,
not sufficient. Every exception rejects valid input, since an enclosing
convex k-gon always exists. Many returned polygons are also provably not
minimal, at k = 3 and at k = 4. If an equivalent guard is released, these
facts would shape a binding's contract, not just its gate; see
[the binding gate](#future-binding-gate).

No upstream comment was posted. The non-minimal k = 3 results above may be
useful to the PR's reviewers; whether to share them is left to the
maintainer.

### Future binding gate

This is a design note, not an implementation. `Is_Natively_Supported` keeps
its current meaning, native API availability with threshold 4.13. No future
release or version number is assumed.

1. **Wait for a release.** Reconsider only when a tagged release contains a
   guard equivalent to change 4, on every major branch Geometry supports. A
   5.x fix does not cover 4.13 or 4.14.
2. **Gate on a separate safety boundary.** Below the first guarded release
   on each major branch, a binding would raise `OpenCV_Error` with a
   "requires OpenCV …" message, as the Subdiv2D Float32 bounds do. The
   feature query would still report declaration availability. Whether that
   boundary also becomes a distinct public query is a public-API decision
   for the user.
3. **Treat version numbers as a weak signal.** Distributions backport, and
   the shim cannot inspect native code. A gate based only on versions
   accepts that risk. The alternative, process isolation, is an
   architectural change.
4. **Rerun this corpus first.** Every `crash` expectation must become
   `cv_exception` or a validated polygon. This must hold under the release
   build and both sanitizer builds on Linux, and on macOS and Windows where
   their toolchains allow.
5. **Specify non-minimal results; do not hide them.** The public contract
   would state that results are OpenCV's and may not be minimal, and that
   `OpenCV_Error` can occur for valid input at small scales. Geometry should
   not post-check minimality, because that would require a reimplementation.
6. **Keep the ABI conventional:**
   - a caller-provided buffer of capacity k, filled in Ada iteration order;
   - k×1 and 1×k native output both accepted through `checkVector(2)`;
   - integer `Contour` input converted to Float32 in Ada;
   - large k·n² can raise `std::bad_alloc`, contained as `OpenCV_Error`;
   - Ada bounds the count by the ABI's `int32_t`.

### Reproducible research tooling

Nothing here is built by `alr`, the AUnit suite or CI.
`scripts/run_native_tests.sh` only globs `tests/native/*.cpp`, so it does
not build these files either.

- `tests/native/research/min_enclosing_convex_polygon_probe.cpp` runs one
  case per process. Input comes from bit patterns on standard input, the
  fuzz generator, or the circle and arc generators. The probe records:
  - the OpenCV version;
  - the loaded object that defines `cv::minEnclosingConvexPolygon`;
  - every input and output coordinate as a bit pattern.

  Everything before the native call is flushed first.
- `tests/native/research/stub/precomp.hpp` is a public-header stand-in used
  when compiling an exact upstream implementation file.
- `tests/native/research/min_enclosing_convex_polygon_corpus.txt` holds 33
  frozen cases. They include hand-written inputs, PR 30111's test inputs,
  the first research's fixtures, and five fuzz cases. Each case records
  expected outcomes for the families `released`, `pr30111-base` and
  `pr30111-head`.
- `scripts/run_min_enclosing_polygon_research.py` has subcommands `build`,
  `run`, `fuzz`, `freeze` and `self-test`.
  - **Child processes:** bounded concurrency; a timeout that kills the
    process group; core dumps off; captured output limited by
    `RLIMIT_FSIZE`; `LD_LIBRARY_PATH` and `LD_PRELOAD` removed; distinct
    sanitizer exit statuses.
  - **Identity checks:** each run confirms that the implementation came from
    the expected library, or from the probe itself for an instrumented
    build. It also reports SHA-256 hashes of the loaded objects.

```sh
python3 scripts/run_min_enclosing_polygon_research.py self-test
python3 scripts/run_min_enclosing_polygon_research.py build \
    --prefix /path/to/opencv-5.0.0 --output /tmp/probe-500
python3 scripts/run_min_enclosing_polygon_research.py run \
    --probe /tmp/probe-500 --expect released
python3 scripts/run_min_enclosing_polygon_research.py build \
    --prefix /path/to/opencv-5.0.0 --output /tmp/probe-500-asan \
    --variant asan-assert \
    --implementation-source /path/to/min_enclosing_convex_polygon.cpp
```

`run` exits 0 when every expectation matched, 1 on a mismatch, and 2 on a
configuration, identity or probe error. Every corpus expectation matched on
all 15 builds: release 4.13.0, 4.14.0, 5.0.0, base and head, each also as
asan and asan-assert. Three negative controls behaved as intended: the
wrong family, a mislabelled library and a forced timeout.

### Task 016 validation evidence

- **Repository validation.** A fresh clone of this branch was validated in
  `/var/tmp`. `alr -n build` passed, and `alr -n -C tests run` reported
  **524/524**, with zero failed assertions and errors, on OpenCV 4.10.0
  with native imgproc.
- **Core resolution.** With no lockfile, Alire resolved `opencv_core` to the
  indexed release 0.2.0, not to any Core checkout. The developer worktree's
  lockfile instead links the sibling Core checkout. Main's Linux CI job
  checks Core out but also deploys an indexed release (0.3.0).
- **No dependency changes.** This task changes no manifest, lockfile, Core
  file or Alire index entry.
- **GNATprove** was not rerun. No Ada, project or proof-scope file changed,
  so the 277-check result from main still applies.
- **Ephemeral artifacts**, not committed: `/tmp/geometry-016-research` and
  `/var/tmp/geometry-016-pr30111`. They hold the exact upstream sources, the
  OpenCV builds, the 15 probe builds and the JSON-lines reports.
