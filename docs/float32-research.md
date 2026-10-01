# Float32 (CV_32F) point sets: native research

This note records the source research behind the `Float32_Point_Array`
overloads of `OpenCV.Geometry`. It answers, for each candidate native
operation, whether OpenCV 4.6.0, 4.10.0, and 5.0.0 provide a portable
`CV_32F` / `Point2f` path, and what arithmetic and safety properties that path
has. `docs/coverage.md` records the resulting bindings; this file keeps the
evidence.

## Method

- Upstream sources at the exact tags `4.6.0`, `4.10.0`, and `5.0.0`
  (`modules/imgproc/src` for 4.x, `modules/geometry/src` for 5.0, and the
  relevant `modules/core` headers). Function bodies were diffed across the
  three tags.
- Probes compiled against OpenCV 4.10.0 (Debian) and against minimal local
  builds of 4.6.0 and 5.0.0 from the same tags, run with timeouts and, where
  useful, AddressSanitizer and UndefinedBehaviorSanitizer on the probe.
- "Native" below means the OpenCV implementation, not the shim. A function
  "accepts CV_32F" only when its source asserts or dispatches on
  `depth == CV_32F`; an `InputArray` parameter alone proves nothing.

## Facts shared by every Float32 path

- The shim passes a `std::vector<cv::Point2f>`, which OpenCV sees as a
  continuous `CV_32FC2` array, so every operation below takes its `is_float`
  or `CV_32F` branch and reads the binary32 values unchanged.
- An empty `std::vector<cv::Point2f>` reaches OpenCV as an empty `Mat` whose
  depth is not `CV_32F`, so `checkVector` fails for it. As for integer
  contours, the shim returns each operation's documented empty result
  without calling OpenCV.
- No operation below rounds `CV_32F` input to integers, except where it
  explicitly converts a coordinate with `cvRound` or `cvFloor`
  (`pointPolygonTest`, `boundingRect`). Those conversions are undefined
  outside `[-2**31, 2**31)` and for NaN.
- `convexHull` sorts point pointers with `std::sort` and a coordinate
  comparator. NaN breaks the comparator's strict weak ordering, which is
  undefined behavior for `std::sort`. Infinities do not.
- `convexHull` compares the first and last sorted points bitwise through an
  integer `Point*` view, but `Sklansky_` compares them as floats. A set whose
  points are all equal as floats but mix `+0.0` and `-0.0` therefore yields an
  empty hull in 4.6, 4.10, and 5.0 (probed). Integer input cannot reach this.
- OpenCV computes most coordinate differences in binary32, even when it
  stores them in `double`. A difference overflows to infinity only when the
  exact difference exceeds `FLT_MAX` by at least `2**103`; spans of at most
  `FLT_MAX` therefore keep every difference finite.

## Per-operation findings

Line references are to 4.10.0 unless noted; "same" means the function body
is identical apart from error-macro spelling.

### contourArea (`Contour_Area`)

1. CV_32F: accepted (`depth == CV_32F || depth == CV_32S`).
2. Portable: same in 4.6, 4.10, and 5.0.
3. Output: `double`.
4. Counts: any; empty returns 0.
5. Arithmetic: `(double)prev.x * p.y - (double)prev.y * p.x`, accumulated in
   binary64. Integer input is first converted to `Point2f`, so integer-valued
   binary32 input gives the integer result.
6. Hazards: none. Every product of two binary32 values is exact in binary64
   and the sum stays finite.
7. Float-specific: none beyond fractional values being kept.
8. ABI: separate `_f32` entry point.

### arcLength (`Arc_Length`)

1. CV_32F: accepted. 2. Same in all three. 3. `double`. 4. Any; fewer than two
points return 0.
5. Arithmetic: `float dx = p.x - prev.x`, `dx*dx + dy*dy` and its `sqrt` in
   binary32; the segment lengths are summed in binary64.
6. Non-finite output from finite input: a segment longer than about
   `1.8E+19` overflows the binary32 square, so the result is `+Inf` (probed:
   `{(-1e19,0),(1e19,0),(0,1e19)}`). No undefined behavior.
7. Float-specific: integer contours cannot reach that length.
8. ABI: separate `_f32` entry point; Ada rejects the infinite result.

### moments (`Compute_Moments`) and matchShapes (`Match_Shapes`)

1. CV_32F: `contourMoments` and `matchShapes` (through `moments`) accept it.
2. Same in all three. 4.10 and 5.0 first consult an optional
   `cv_hal_polygonMoments` hook, which no in-tree HAL implements; 4.6 has
   none.
3. `cv::Moments` of `double`; `double` score.
4. Any; empty input has all-zero moments (`moments` returns before
   `checkVector`).
5. Green's formula in binary64 from the binary32 coordinates; central
   moments divide by `m00`.
6. Non-finite output from finite input: yes. A self-intersecting contour
   whose signed areas nearly cancel, at large coordinates, has a tiny `m00`
   and a huge first moment, so `mu30` overflows (computed example: a bowtie
   at `1e36` followed by a `1e-3` loop at the origin). Integer contours keep
   `|m00| >= 0.5` and cannot overflow. No undefined behavior.
7. Float-specific: `contourMoments` returns all-zero moments when its doubled
   area satisfies `|a00| <= FLT_EPSILON`. A nonempty Float32 contour can have
   such a nonzero area (probed: legs of `1e-4`); its Hu moments are then
   zero, so `matchShapes` reports `DBL_MAX` against an ordinary shape.
   `matchShapes` also skips every Hu term for which `fabs(h) > eps` is false,
   which includes NaN, and I1 turns an infinite term into 0, so finite scores
   can hide non-finite moments (independent review: a sliver
   `(0,0),(1e30,0),(1e30,1e-36)` scores finitely under I1 and I3 although its
   fifth Hu moment is not finite).
8. ABI: separate `_f32` entry points; Ada checks each set's moments and Hu
   moments before matching and rejects non-finite moments and scores.

### isContourConvex (`Is_Convex`)

1. CV_32F: accepted. 2. Same in all three. 3. `bool`. 4. Any; empty is false.
5. `isContourConvex_<float>` computes edge differences **and** the cross
   products `dx * dy0`, `dy * dx0` in binary32, then compares them.
6. Hazards: no undefined behavior, and the loop is bounded. But a difference
   or product above `FLT_MAX` becomes infinite, equal infinite products
   compare as collinear, and the classification is then silently wrong.
   Products are bounded by the product of the X and Y spans.
7. Float-specific: unlike the exact `int` path, rounding can classify nearly
   collinear vertices either way.
8. ABI: separate `_f32` entry point with no arithmetic guard, unlike the
   integer path's signed-overflow guard. Ada requires spans of at most
   `FLT_MAX` and a span product of at most `FLT_MAX / 2`, which keep every
   difference and product finite.

### pointPolygonTest (`Locate_Point`, `Signed_Distance_To_Contour`)

1. CV_32F: accepted. 2. 4.10 and 5.0 identical; 4.6 differs only by an unused
   local. 3. `double`. 4. Any; empty returns `-1` or `-DBL_MAX`.
5. `Point ip(cvRound(pt.x), cvRound(pt.y))` runs for every nonempty contour
   before the depth test, even though the float path never uses `ip`.
   Coordinate differences are binary32; crossing and distance tests are
   binary64.
6. Unsafe conversion: `cvRound` of a query outside `[-2**31, 2**31)` or NaN,
   as for integer contours. Saturation: the nearest-edge search starts at
   `min_dist_num = FLT_MAX` and only accepts smaller squared distances, so a
   distance of at least `sqrt(FLT_MAX)` is reported as `-1.8446743523953730E+19`
   (probed in all three releases with a contour near `3e19`). Overflow: an
   edge difference above `FLT_MAX` becomes infinite and the crossing and
   distance tests then answer wrongly without failing (independent review:
   the triangle `(-2e38,0),(2e38,10),(2e38,0)` reports the inside query
   `(0,1)` as outside).
7. Float-specific: integer contours cannot reach that distance or overflow.
8. ABI: separate `_f32` entry point with the same `cvRound` guard. Ada
   requires X and Y spans of at most `FLT_MAX` and raises at the saturation
   value instead of returning a clamped distance.

### boundingRect (`Bounding_Rect`)

1. CV_32F: accepted by `pointSetBoundingRect`.
2. 4.6 and 4.10 floor only the extreme coordinates (SIMD or scalar); 5.0
   applies `cvFloor` to every coordinate. Results agree because floor is
   monotonic.
3. `cv::Rect` of `int`: `Rect(xmin, ymin, xmax - xmin + 1, ymax - ymin + 1)`
   with `xmin = cvFloor(min x)`, `xmax = cvFloor(max x)`.
4. Any; empty returns `Rect()`.
5. `cvFloor` to `int`, then signed `int` extent arithmetic.
6. Unsafe conversion and signed overflow: `cvFloor` of a coordinate outside
   `[-2**31, 2**31)` or NaN, and `xmax - xmin + 1` above `INT_MAX` (probed:
   `{(-2**31,0),(2147483520,0)}` returns width `-127`; `{(3e9,0)}` returns
   garbage that differs between 4.x and 5.0).
7. A point with an integral maximum coordinate lies in the last column, as for
   integers; fractional input is floored, not rounded.
8. ABI: separate `_f32` entry point whose guard rejects those coordinates and
   extents; Ada applies the same rule as public policy.

### convexHull (`Convex_Hull`, `Convex_Hull_Indices`)

1. CV_32F: accepted; points are returned as `CV_32FC2` bitwise copies of the
   input.
2. 4.6 and 4.10 identical. 5.0 normalizes the two edge vectors to unit
   length before its binary64 cross product when `_Tp` is floating point, and
   re-selects duplicate-point indices; nearly collinear Float32 input can
   therefore give a different hull in 5.0.
3. Points (`CV_32FC2`) or zero-based `int` indices.
4. Any; empty input is rejected by `checkVector` (shim returns empty).
5. 4.x: binary32 differences, binary64 cross products. 5.0: binary32
   differences, normalized in binary64 and narrowed to binary32.
6. Undefined behavior: NaN in `std::sort`. Count arithmetic:
   `AutoBuffer<int> _stack(total + 2)` cannot overflow in practice, because
   `checkVector` already rejects `2**30` or more points (observed by the
   independent review on all three releases). The Sklansky loop terminates
   structurally, but an overflowing difference makes its cross products
   infinite or NaN and the hull silently wrong.
7. Signed zeros as above.
8. ABI: separate `_f32` entry points that reject NaN (sort safety). Ada passes
   `-0.0` as `+0.0` and requires spans of at most `FLT_MAX`.

### convexityDefects

`convexityDefects` calls `points.checkVector(2, CV_32S)` and asserts a
nonnegative result in 4.6, 4.10, and 5.0, so a `CV_32F` contour is rejected.
There is no native Float32 mode to bind.

### approxPolyDP (`Approximate_Curve`)

1. CV_32F: accepted; output is `CV_32FC2` points copied from the input.
2. 4.6 and 4.10 same. 5.0 measures each point's distance to the **segment**
   (projection clamped to the end points) instead of to the infinite line, so
   results can differ from 4.x for both integer and Float32 input.
3. Points of the input depth. 4. Any; empty returns empty.
5. Binary32 differences (`pt.x - start_pt.x`) stored in binary64; distances in
   binary64 (5.0 also squares some binary32 differences in binary32).
6. Nontermination and out-of-bounds reads: if a segment's binary32 difference
   overflows, its distances become NaN; with `epsilon = 0` the comparison
   `max_dist * max_dist <= eps * (dx*dx + dy*dy)` is then false while no
   split point was found, so the stale `right_slice.start` (initially
   `count`) is pushed and `src_contour[count]` is read. Probed:
   `{(-3e38,0),(0,0),(3e38,0)}` with `epsilon = 0` does not return in 4.6,
   4.10, or 5.0. With `epsilon > 0` the same overflow silently drops points.
   Spans of at most `FLT_MAX` keep every difference finite and avoid both.
7. Float-specific: integer spans cannot overflow binary32. Within the span
   limit, 5.0 still squares some differences in binary32, so beyond about
   `1.8e19` it can keep vertices that 4.x drops (independent review:
   `(0,0), (-2e19,1), (1e20,0)` with epsilon `1e25`). A closed result is a
   cyclic subsequence of the input starting where OpenCV's farthest-point
   search lands, not necessarily at the first point.
8. ABI: separate `_f32` entry point with a span guard.

### minAreaRect (`Minimum_Area_Rectangle`)

1. CV_32F: accepted; the float hull goes straight to `rotatingCalipers`.
2. Representation differs between 4.x and 5.0 as for integer input.
3. `RotatedRect` of `float`. 4. Any.
5. Rotating calipers in binary32.
6. Count arithmetic: `AutoBuffer<float> abuf(n*3)` in signed `int`, where `n`
   is the hull size. Integer lattice hulls cannot approach `INT_MAX / 3`
   vertices, but every Float32 point can be a hull vertex. Loops are bounded
   by `n`. The calipers compare candidate areas `width * height` in binary32
   against an initial `FLT_MAX` and record a candidate only when
   `area <= minarea`; when every area overflows (sides of about `1.8e19`
   and more, probed at `1e20`), nothing is recorded and the zeroed buffer
   yields a NaN center. Integer spans cannot reach that area.
7. Signed zeros and NaN as for `convexHull`.
8. ABI: separate `_f32` entry point that rejects NaN and more than
   `INT_MAX / 3` points. Ada applies the hull rules; the non-finite
   rectangle raises.

### minEnclosingCircle (`Minimum_Enclosing_Circle`)

1. CV_32F: accepted. 2. 4.6 and 4.10 same. 5.0 copies and shuffles the
   points with a seeded `cv::RNG` for more than 10 points, and for a
   degenerate triple keeps the previous circle instead of using the farthest
   pair. 3. Center and radius of `float`.
5. Binary32 throughout, with absolute tolerances `EPS = 1e-4` (added to every
   radius, and used as the determinant threshold for degenerate triples).
6. Non-finite output when coordinate sums or differences overflow binary32.
   Loops are bounded; the 5.0 source notes that without its shuffle, as in
   4.x, sorted input makes the algorithm cubic in time.
7. Float-specific: the absolute tolerances matter at small scales. Probed in
   all three releases: an equilateral triangle with sides `0.01` (cross
   product below `1e-4`) gets a circle that leaves one vertex about `0.0036`
   outside, and with sides `0.001` about `0.00027` outside; sides of `0.1`
   and more are enclosed. Integer triangles have cross products of at
   least 1.
   Far from the origin, `findCircle3pts` loses precision in its binary32
   dot products of absolute coordinates: an **integer** triangle with sides
   of about 8 near `(1e7, 1e7)` gets a circle that misses a vertex by 41% of
   the radius on 4.10 (a 0.1 behavior, now documented for both overloads).
   Its products of three coordinates, about `16 * M**3`, overflow binary32
   near `M = 3e12`; 4.x then rejects the NaN radius (`new_radius > 0`) and
   silently keeps a circle that misses the point (independent review: a
   vertex 73% of the radius outside for equilateral triangles with sides
   `3e13`; random sets at `±8e12` fail about 3% of the time).
8. ABI: separate `_f32` entry point with no arithmetic guard. Ada requires
   coordinates of magnitude at most `2**41`, which keeps those products
   below `2**127`; with the determinant above the `1e-4` tolerance, an
   overflowing center or radius is then infinite and raises. The binding
   documents the small-scale and far-from-origin behavior and returns the
   native circle.

### minEnclosingTriangle

Native support exists (CV_32F hull, `vector<Point2f>` output), but the
implementation is not safe for arbitrary finite input in 4.6, 4.10, or 5.0
(byte-identical source):

- `advanceBToRightChain` and `searchForBTangency` loop until a tolerance-based
  comparison fails, with no iteration bound. Probed hangs in all three
  releases: the **integer** contour `(0,0),(1,0),(100001,1),(100000,1)`, the
  integer near-collinear contour
  `(137248944,-29186162),(269187968,-57243160),(1221462912,-259745664),
  (547006528,-116321648)`, and the Float32 square of side `1e-6` (all heights
  within the absolute tolerance `1e-5`).
- Float32-only: a signed-zero set such as `{(0,0),(-0,0)}` produces an empty
  hull and then `i % 0` (SIGFPE, probed); coordinate spans above `FLT_MAX`
  produce infinite heights and further hangs.

Decision: no Float32 overload. Signed zeros and spans could be excluded, but
hulls smaller than the absolute tolerance, which are ordinary Float32 input,
and the geometric hangs shared with integer input cannot be excluded by any
input check short of re-implementing OpenCV's loop logic. The integer
overload stays bound, and its documentation now names the hang.

### fitEllipse, fitEllipseAMS, fitEllipseDirect (`Fit_Ellipse*`)

1. CV_32F: accepted; read directly. 2. 4.6 and 4.10 same. 5.0 draws its
   perturbation from `cv::theRNG`, loops AMS and Direct twice, and replaces
   Direct's determinant check with an ellipse condition.
3. `RotatedRect` of `float`. 4. At least five points; exactly five use
   `fitEllipseDirect` in `fitEllipse`.
5. NoDirect and AMS sum the points in binary32 to find the centroid; Direct
   sums in binary64. Later work is binary64.
6. Count arithmetic: unchanged from the integer path (`n*12+n` and others).
   Non-finite and very slow paths: if the binary32 centroid sum overflows,
   NaN reaches the SVD, and OpenCV's built-in Jacobi SVD (used without LAPACK)
   then runs all `max(n, 30)` sweeps, which is quadratic in `n`; 5.0
   `fitEllipseDirect` can also throw `StsNoConv`. Integer sums cannot overflow
   binary32.
7. Binding: separate `_f32` entry points with the integer count limits. Ada
   requires the absolute X and Y coordinates each to sum to at most `2**103`.
   A binary32 running sum exceeds the sum of absolute values by at most a
   factor `(1 + 2**-24)**(n-1)`, below `2**23.1` for the fewer than `2**28`
   points allowed, so every partial sum and every difference from the mean
   stays below `2**126.2`, and NoDirect's 4.x binary32 `|dx| + |dy|` below
   `2**127.2`.

### fitLine 2D (`Fit_Line_2D`)

1. CV_32F: accepted; a continuous `vector<Point2f>` skips the `convertTo` that
   integer input goes through.
2. Behavior identical in all three releases.
3. `Vec4f`. 4. At least one point.
5. `fitLine2D_wods` sums `x`, `y` in binary64 but forms `x*x`, `y*y`, `x*y`
   in binary32, without centering, before subtracting in binary64. Large
   coordinates relative to the spread therefore lose the direction (probed:
   offset `(1e4, 2e4)`, spread 0.5, gives a direction off by about 60
   degrees in all releases); integer input converted to binary32 behaves the
   same way.
6. Non-finite or degenerate output: binary32 products overflow above about
   `1.8E+19`, giving a NaN direction (L2) or, for the robust distances, the
   initial all-zero line when no candidate has a finite error. Loops are
   bounded (20 restarts, 30 reweightings). Count arithmetic as for integers.
   When only one axis overflows, `dx2` is infinite and `atan2(2 * dxy, +Inf)`
   is 0, so the direction is a finite but wrong `(1, 0)` (independent review:
   the vertical line `x = 2e19` on all three releases).
7. Binding: separate `_f32` entry point with the integer count limit. Ada
   requires coordinates of magnitude at most `2**63`, which keeps every
   product at most `2**126` (robust weights start at 1 and are then
   normalized, so weighted products stay finite too), and rejects
   non-finite fields and the all-zero direction.

### intersectConvexConvex (`Intersect_Convex_Polygons`)

1. CV_32F: accepted; integer input is converted to `CV_32F` first, so both
   modes run the same binary32 code.
2. 4.6 and 4.10 differ in `intersectLineSegments`; 4.11 and 5.0 bound the
   output and return `-1` on overflow.
5. `areaSign` uses binary32 differences, binary64 products, and an absolute
   tolerance `1e-5`.
6. 4.6 and 4.10 write their result without a bound into an `n + m + 1` slot
   region. Rounded differences or the absolute tolerance can make the
   predicates inconsistent for **valid** strictly convex polygons, so the
   output can exceed that region (reported by the research probes for
   fractional Float32 polygons and for integer polygons near `2**24`, whose
   coordinate differences are not exact in binary32). The `(FLT_MAX,
   FLT_MAX)` early-exit sentinel is unambiguous only while no input or
   computed vertex can equal it.

## Pre-existing integer findings

The research also found native hazards reachable through the 0.1 integer
overloads:

- `Minimum_Enclosing_Triangle` can fail to return (examples above).
- `Intersect_Convex_Polygons` on OpenCV 4.6 and 4.10 relies on exact
  binary32 predicates, which the `-2**24 .. 2**24` coordinate limit does not
  guarantee for coordinate differences.

They are recorded here because the Float32 decisions depend on them; their
handling is described with the operations concerned.
