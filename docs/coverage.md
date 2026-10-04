# OpenCV Geometry binding coverage

This table is maintained by hand. It maps each native OpenCV Geometry
operation to its thick Ada binding, or records why there is none. Its
reference releases are OpenCV 4.6, 4.10, and 4.14.0, where operations live in
`imgproc` (`opencv2/imgproc.hpp`, `libopencv_imgproc`), and OpenCV 5.0, where
they live in `geometry` (`opencv2/geometry.hpp`, `libopencv_geometry`). The
binding also builds against other OpenCV 4.x releases; notes below name the
releases where behavior changes. The public Ada package is `OpenCV.Geometry`
on every release. The native lists come from the upstream headers of the
reference releases. Update this file with every change to the public API.

The 0.2.0 release audit rechecked exact 4.14.0 `imgproc.hpp` and exact 5.0.0
`geometry.hpp` / `geometry/2d.hpp` against both public Ada specs. No additional
in-scope contour, shape, transform, or public Subdiv2D operation was found:
the common free functions, version-gated rows, and explicitly unbound modes
below account for the intended 2-D surface. This is not a claim to cover
image processing or the 3-D/segmentation/MST families. See the
[release evidence](release-0.2.0.md) for source identities and certification.

Status values:

- **Bound**: every mode common to the reference releases has a thick
  binding.
- **Partial**: the listed modes are bound. The others are listed under
  [Unbound modes](#unbound-modes-of-bound-operations) with the reason.
- **Deferred**: not bound yet, for the stated reason.
- **Excluded**: deliberately outside this crate.
- **Not applicable**: OpenCV itself provides no such mode.

## Free functions common to 4.6, 4.10, and 5.0

Every one of these 26 native names has a thick binding. For each row the
OpenCV 4 backend is `imgproc` and the OpenCV 5 backend is `geometry`. Point
sets are Ada-owned integer `Contour` values (`OpenCV.Point_Array`, native
`CV_32S`); where noted they are also `Float32_Point_Array` values (native
`CV_32F`), as detailed in [Float32 point sets](#float32-cv_32f-point-sets).

| Native operation | Public Ada operation | Status | Version notes |
| --- | --- | --- | --- |
| `contourArea` | `Contour_Area` | Bound, both `oriented` modes, integer and Float32 | |
| `arcLength` | `Arc_Length` | Bound, open and closed, integer and Float32 | |
| `moments` | `Compute_Moments` | Partial: integer and Float32 point sets | Raster-image mode unbound |
| `HuMoments` (2 overloads) | `Hu_Moments` | Bound | Both overloads compute the same seven values |
| `matchShapes` | `Match_Shapes` | Partial: integer and Float32 point sets, I1/I2/I3 | 5.x declares `CONTOURS_MATCH_*` in `imgproc.hpp`, not `geometry.hpp`; OpenCV ignores its `parameter` |
| `convexHull` | `Convex_Hull`, `Convex_Hull_Indices` | Bound: points and indices, both orientations, integer and Float32 | Among duplicate hull points, 4.x and 5.x may return different indices |
| `convexityDefects` | `Convexity_Defects` (2 overloads) | Bound | OpenCV accepts only `CV_32S` contours |
| `isContourConvex` | `Is_Convex` | Bound, integer and Float32 | |
| `approxPolyDP` | `Approximate_Curve` | Bound, open and closed, integer and Float32 | 5.0 measures distance to the segment, 4.x to its line |
| `boundingRect` | `Bounding_Rect` | Partial: integer and Float32 point sets | Grayscale-image mode unbound |
| `pointPolygonTest` | `Locate_Point`, `Signed_Distance_To_Contour` | Bound, both `measureDist` modes, integer and Float32 | |
| `minAreaRect` | `Minimum_Area_Rectangle` | Bound, integer and Float32 | 4.13 introduced the 5.x width/height/angle convention (`[-90, 0)`); 4.12 and earlier use the older representation. Width may identify a different physical side; use `Box_Points` for vertices, without assuming their order. Degenerate numerical equivalence is not guaranteed |
| `boxPoints` | `Box_Points` | Bound | Native vertex order is preserved; the 4.12+ and 5.0 documentation's start vertex is not guaranteed |
| `minEnclosingCircle` | `Minimum_Enclosing_Circle` | Bound, integer and Float32 | 5.x shuffles more than ten points first. Binary32 arithmetic on absolute coordinates can miss a point far from the origin, even for integer input |
| `minEnclosingTriangle` | `Minimum_Enclosing_Triangle` | Bound, integer only | OpenCV's search loops have no iteration bound and fail to return for some nearly degenerate hulls in 4.6, 4.10, and 5.0; see [Float32 point sets](#float32-cv_32f-point-sets) |
| `fitEllipse` | `Fit_Ellipse` | Bound, integer and Float32 | Exactly five points use `fitEllipseDirect`. From 4.12, the singular-system fallback for more points perturbs with `cv::theRNG`, so results need not repeat |
| `fitEllipseAMS` | `Fit_Ellipse_AMS` | Bound, integer and Float32 | From 4.12, fallback perturbation uses `cv::theRNG` |
| `fitEllipseDirect` | `Fit_Ellipse_Direct` | Bound, integer and Float32 | From 4.12, fallback perturbation uses `cv::theRNG` |
| `fitLine` | `Fit_Line_2D` | Partial: 2D, integer and Float32, all six supported distances | 3D mode unbound |
| `intersectConvexConvex` | `Intersect_Convex_Polygons` | Bound, both `handleNested` modes, integer and Float32 | Before 4.11 non-convex input, and convex input whose binary32 tests round, can overflow a native buffer, so Ada validates convexity and keeps the tests exact; 4.11+ and 5.x report non-convergence as a negative area |
| `rotatedRectangleIntersection` | `Intersect_Rotated_Rectangles` | Bound | 4.6 uses different contact tolerances |
| `getRotationMatrix2D`, `getRotationMatrix2D_` | `Get_Rotation_Matrix_2D` | Bound | Returns an `OpenCV.Core.Mat` built through Core's public Ada API; Geometry's C ABI carries only six doubles |
| `getAffineTransform` (2 overloads) | `Get_Affine_Transform` | Bound | A degenerate triangle yields an all-zero matrix |
| `invertAffineTransform` | `Invert_Affine_Transform` | Bound | A singular matrix inverts to zeros |
| `getPerspectiveTransform` (2 overloads) | `Get_Perspective_Transform` | Partial: `DECOMP_LU`, `DECOMP_SVD`, `DECOMP_QR` | 4.12+ and 5.x check the residual and can return an SVD solution with `T (3, 3) /= 1.0` |

`Transform_Point` (affine and perspective overloads) is an Ada value helper
with no native call. It applies a transform to one point in binary64
arithmetic, and SPARK proves that no intermediate overflows. It divides by
every nonzero W, unlike `cv::perspectiveTransform`, which maps
|W| <= `FLT_EPSILON` to the origin.

## Float32 (CV_32F) point sets

Integer `Contour` values suit integer-coordinate geometry, not necessarily
exact native arithmetic (some operations convert to Point2f). Many point-set
operations also have a native `CV_32F` (`Point2f`) mode for subpixel geometry,
bound as overloads that take `Float32_Point_Array`. Each mode was checked in
the 4.6, 4.10, and 5.0 sources rather than inferred from an `InputArray`
parameter; `docs/float32-research.md` records the evidence. Every Float32
overload rejects NaN and infinite coordinates with `OpenCV_Error` and calls the
native `CV_32F` path, so coordinates are never rounded to integers.

| Native operation | Float32 binding | Status | Notes |
| --- | --- | --- | --- |
| `contourArea` | `Contour_Area` | Bound | Binary64 accumulation; always finite |
| `arcLength` | `Arc_Length` | Bound | Binary32 segment lengths; a segment above about 1.8E+19 overflows and raises |
| `moments` | `Compute_Moments` | Bound | All-zero moments when the doubled area is at most `FLT_EPSILON`; non-finite native moments raise |
| `matchShapes` | `Match_Shapes` | Bound | Through the Float32 moments; non-finite moments or Hu moments raise, since OpenCV would skip them |
| `isContourConvex` | `Is_Convex` | Bound | Binary32 differences and cross products, kept finite by span limits |
| `pointPolygonTest` | `Locate_Point`, `Signed_Distance_To_Contour` | Bound | Spans of at most `FLT_MAX`; query in `cvRound` range; a distance of at least `sqrt(FLT_MAX)` raises instead of being clamped |
| `boundingRect` | `Bounding_Rect` | Bound | Coordinates in `[-2**31, 2**31)` and extents within `Integer_32`, as `cvFloor` and the native extent arithmetic require |
| `convexHull` | `Convex_Hull`, `Convex_Hull_Indices` | Bound | At most `Integer_32'Last - 2` points for native signed `total + 2` (integer overloads too); hull points are input copies; `-0.0` is passed as `+0.0`; spans of at most `FLT_MAX`; 5.x normalizes edge vectors, so nearly collinear points can differ from 4.x |
| `approxPolyDP` | `Approximate_Curve` | Bound | Spans of at most `FLT_MAX`: an overflowing difference makes OpenCV drop points or, at epsilon 0, read past the curve without terminating |
| `minAreaRect` | `Minimum_Area_Rectangle` | Bound | Hull rules as above; at most `Integer_32'Last / 3` points (binary32 calipers buffer); areas above `FLT_MAX` give a non-finite native rectangle, which raises |
| `minEnclosingCircle` | `Minimum_Enclosing_Circle` | Bound | For three or more points, coordinates of magnitude at most `2**41` keep native three-point products finite. Zero/one/two points have no triple-product bound; all inputs and native outputs must still be finite. In the tested OpenCV 4.6, 4.10, and 5.0 small equilateral-triangle fixture (sides 0.01), the circle misses a vertex; points far from the origin can also lose precision, as for integer input |
| `minEnclosingTriangle` | none | Deferred | OpenCV's unbounded search loops already fail to return for some integer hulls; binary32 input adds hulls below its absolute tolerance, overflowing spans, and signed zeros that make it divide by zero. No input validation excludes them all |
| `fitEllipse`, `fitEllipseAMS`, `fitEllipseDirect` | `Fit_Ellipse`, `Fit_Ellipse_AMS`, `Fit_Ellipse_Direct` | Bound | Absolute X and Y coordinates must each sum to at most `2**103`, so OpenCV's binary32 mean cannot overflow into NaN, which its LAPACK-free SVD processes in quadratic time |
| `fitLine` (2D) | `Fit_Line_2D` | Bound | L2: ordinary `Integer_32'Last` count limit; robust distances: `Integer_32'Last / 2` for signed `count*2` allocation after L2 returns. Binary32 products without centering; coordinates of magnitude at most `2**63`; non-finite results and the robust fits' all-zero line raise, but identical finite points can produce a valid unit direction |
| `intersectConvexConvex` | `Intersect_Convex_Polygons` | Bound | Polygons must be an exact power-of-two scaling, by `2**K` with `-8 <= K <= 6`, of integer polygons the integer overload accepts. Rounded binary32 tests can corrupt the 4.6 and 4.10 heap even for valid convex polygons; on accepted input OpenCV returns its result for the integer polygons, scaled by `2**K` |
| `convexityDefects` | none | Not applicable | OpenCV 4.6, 4.10, and 5.0 call `checkVector(2, CV_32S)` and reject `CV_32F` contours |

## Stateful family: `cv::Subdiv2D`

`OpenCV.Geometry.Subdiv2D` binds the class as one owned object, not as free
functions. `Subdivision` is a limited controlled type that exclusively owns a
native `cv::Subdiv2D` through an opaque handle. It is the only Geometry type
with object identity. The OpenCV 4 backend is `imgproc` and the OpenCV 5
backend is `geometry`.

Two notes apply to the whole family:

- From 4.12, including 5.x, the bounding super-triangle is twice as large (6
  instead of 3 times the larger bounds dimension). That changes the positions
  of vertices 1 .. 3, edges to them, hull triangles, and the far vertices of
  hull Voronoi facets.
- OpenCV's predicates use absolute binary32-scale tolerances. Behavior
  depends on coordinate scale and geometric conditioning, not just pairwise
  spacing (the smallest distance between inserted points). In the specific
  random-point and jittered-grid fixtures tested on OpenCV 4.10 and 5.0, no
  `Find_Nearest` failures were observed at spacings around 0.03 units or
  greater. This is empirical guidance, not a guaranteed safe minimum:
  near-collinear, nearly cocircular, and other ill-conditioned sets may behave
  differently at any pairwise spacing. At smaller tested spacings,
  `Find_Nearest` could return the wrong vertex or no vertex, `Insert` and
  `Locate` could fail, and at pathological scales native `findNearest` could
  fail to return. The package documentation gives the measured details.

| Native member | Public Ada operation | Status | Version notes |
| --- | --- | --- | --- |
| `Subdiv2D()`, `Subdiv2D(Rect)` | declared `Subdivision`, `Create` | Bound | A declared object is not ready until `Create` or `Reset` |
| `initDelaunay(Rect)` | `Reset` | Bound | |
| `insert(Point2f)`, `insert(vector)` | `Insert` (function and procedure) | Bound | |
| `locate` | `Locate` | Bound | `PTLOC_*` map to `Point_Location_Kind`; outside and error locations raise |
| `findNearest` | `Find_Nearest` | Bound | For closely spaced points it can be wrong, raise, or hang (see above) |
| `getEdgeList` | `Edge_List` | Bound | Super-triangle change |
| `getLeadingEdgeList` | `Leading_Edge_List` | Bound | |
| `getTriangleList` | `Triangle_List` | Bound | Super-triangle change |
| `getVoronoiFacetList` | `Voronoi_Facets` (all and listed) | Bound | An empty `Sites` selects nothing; facets with uncomputed Voronoi vertices report `Complete = False`; super-triangle change |
| `getVertex` | `Vertex_Point`, `First_Edge` | Bound | Super-triangle change for vertices 1 .. 3 |
| `getEdge` | `Navigate` | Bound: all eight `*_AROUND_*` choices as `Edge_Navigation` | |
| `nextEdge`, `rotateEdge`, `symEdge` | `Next_Edge`, `Rotate`, `Symmetric_Edge` | Bound | |
| `edgeOrg`, `edgeDst` | `Origin`, `Destination` | Bound | Positions via `Vertex_Point` |
| `Subdiv2D(Rect2f)`, `initDelaunay(Rect2f)` | `Create_Float32`, `Reset_Float32` with `Float32_Rectangle` | Bound, version-gated, OpenCV 4.13+ | Exact binary32 descriptor; no integer fallback; distinct names preserve integer aggregate source compatibility |

`Is_Ready`, `Bounds`, and `Bounds_Float32` report state and have no native
counterpart. `Bounds` retains the original integer descriptor and raises
after Float32 initialization. `Bounds_Float32` returns the exact supplied
Float32 descriptor, or native conversions of the integer fields. Failed
`Reset` / `Reset_Float32` never publishes new bounds. Ada preflight rejects
non-finite fields, nonpositive dimensions, binary32-absorbed extents (including
positive integer dimensions), and non-finite native initialization coordinates.
See the
[source-derived contract and probes](versioned-features-research.md#task-014-float32-subdiv2d-bounds).

## Version-gated native operations

The Ada declarations and C ABI are stable on every supported version.
`Is_Natively_Supported (Feature : Native_Feature)` reports native API
availability, **not Ada binding coverage**. It knows the four thresholds
below even when an operation remains deliberately unbound. For example,
approxPolyN capability is True on 4.11+ although no Ada binding exists.
Calling a bound optional operation on an older version raises OpenCV_Error
with an unsupported-version diagnostic; there is no algorithm fallback.

| Native operation | First 4.x release | Status |
| --- | --- | --- |
| `approxPolyN` | 4.11 | Deferred: unresolved contraction-wide numerical-safety contract; finite convex input can develop sentinel and NaN heap candidates. See [research](versioned-features-research.md). |
| `getClosestEllipsePoints` | 4.12 | Bound, version-gated: `Closest_Ellipse_Points`, integer and Float32 input, Float32 output with identical cardinality and Ada range. Older versions report unsupported. |
| `minEnclosingConvexPolygon` | 4.13 | Deferred: in each examined release (4.13.0, 4.14.0, 5.0.0), finite input can make the native code read out of bounds. Every k = 3 call whose hull has more than three vertices and area of at least 1e-6 does; so does some small-scale k ≥ 4 input. No known preflight avoids reimplementing the algorithm. Upstream PR 30111, open and unreleased, turns the observed reads into `cv::Exception` but still returns non-minimal polygons. See [research](versioned-features-research.md#task-016-minenclosingconvexpolygon-safety-gate). |
| `Subdiv2D(Rect2f)`, `Subdiv2D::initDelaunay(Rect2f)` | 4.13 | Bound, version-gated, OpenCV 4.13+: `Subdiv2D.Create_Float32` / `Reset_Float32` with `Float32_Rectangle`. Older versions report unsupported before semantic validation. |

## Unbound modes of bound operations

| Native mode | Status | Reason |
| --- | --- | --- |
| `moments` of a raster image (`binaryImage`) | Excluded | Needs image input. Geometry takes Ada point collections and has no image or Mat input API. |
| `boundingRect` of a grayscale image | Excluded | Needs image input, as above. |
| `matchShapes` of grayscale images | Excluded | Needs image input, as above. |
| Point sets of `Point2f` (`CV_32F`) in `minEnclosingTriangle` | Deferred | OpenCV's search can fail to return; see [Float32 point sets](#float32-cv_32f-point-sets). |
| Point sets of `Point2f` (`CV_32F`) in `convexityDefects` | Not applicable | OpenCV requires `CV_32S` contours. |
| Float32 `intersectConvexConvex` input off a binary grid | Excluded | Its binary32 tests can round, which on 4.6 and 4.10 can corrupt the native heap; see [Float32 point sets](#float32-cv_32f-point-sets). |
| `fitLine` on 3D point sets | Deferred | Task 019 stopped at the type-ownership gate: shared root OpenCV 3-D point values require a separately approved Core task/release. Native arithmetic/liveness certification remains pending. See [ownership and source research](fit-line-3d-research.md). |
| `fitLine` with `DIST_C` or `DIST_USER` | Not applicable | OpenCV's `fitLine` rejects both as unknown distance types. |
| `getPerspectiveTransform` with `DECOMP_EIG` or `DECOMP_CHOLESKY`, or the `DECOMP_NORMAL` flag | Not applicable | EIG and Cholesky assume a symmetric matrix, which the perspective system is not; `DECOMP_NORMAL` has no effect on a square system. |

## Excluded native operations

These are not Geometry operations. On OpenCV 5 they remain in `imgproc`, and
they belong in an image-processing binding:

- `findContours`, and `findContoursLinkRuns` (4.10+)
- `connectedComponents`, `connectedComponentsWithStats`
- `createGeneralizedHoughBallard`, `createGeneralizedHoughGuil`, and the
  `GeneralizedHough` classes
- image warping such as `warpAffine` and `warpPerspective`, and every other
  image-processing operation
- the drawing helpers `clipLine` and `ellipse2Poly`

These OpenCV 5 `geometry` headers are also out of scope. None of them is in
4.x `imgproc`:

- `geometry/3d.hpp`: 3D vision, which is `calib3d` on 4.x;
- `geometry/segment.hpp`: point-cloud sampling and segmentation;
- `geometry/mst.hpp`: minimum spanning trees.
