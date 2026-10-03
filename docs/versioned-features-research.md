# Optional native Geometry features: research gate

Status: approxPolyN is **deliberately deferred at its safety gate**; Task 013
pivoted to native capability plumbing and closest ellipse points. The
approxPolyN investigation is preserved below, not declared impossible.

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
The first binding is getClosestEllipsePoints; approxPolyN remains unbound.
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