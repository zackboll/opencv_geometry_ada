# OpenCV Geometry binding coverage

This table is maintained by hand. It maps each native OpenCV Geometry
operation to its thick Ada binding, or records why there is none. Its
reference releases are OpenCV 4.6 and 4.10, where the operations live in
`imgproc` (`opencv2/imgproc.hpp`, `libopencv_imgproc`), and OpenCV 5.0, where
they live in `geometry` (`opencv2/geometry.hpp`, `libopencv_geometry`). The
binding also builds against other OpenCV 4.x releases; notes below name the
releases where behavior changes. The public Ada package is `OpenCV.Geometry`
on every release. The native lists come from the upstream headers of the
reference releases. Update this file with every change to the public API.

Status values:

- **Bound**: every mode common to the reference releases has a thick
  binding.
- **Partial**: the listed modes are bound. The others are listed under
  [Unbound modes](#unbound-modes-of-bound-operations) with the reason.
- **Deferred**: not bound yet, for the stated reason.
- **Excluded**: deliberately outside this crate.

## Free functions common to 4.6, 4.10, and 5.0

Every one of these 26 native names has a thick binding. For each row the
OpenCV 4 backend is `imgproc` and the OpenCV 5 backend is `geometry`. Point
sets are Ada-owned `Contour` values (`OpenCV.Point_Array`) unless noted.

| Native operation | Public Ada operation | Status | Version notes |
| --- | --- | --- | --- |
| `contourArea` | `Contour_Area` | Bound, both `oriented` modes | |
| `arcLength` | `Arc_Length` | Bound, open and closed | |
| `moments` | `Compute_Moments` | Partial: point sets | Raster-image mode unbound |
| `HuMoments` (2 overloads) | `Hu_Moments` | Bound | Both overloads compute the same seven values |
| `matchShapes` | `Match_Shapes` | Partial: contours, I1/I2/I3 | 5.x declares `CONTOURS_MATCH_*` in `imgproc.hpp`, not `geometry.hpp`; OpenCV ignores its `parameter` |
| `convexHull` | `Convex_Hull`, `Convex_Hull_Indices` | Bound: points and indices, both orientations | Among duplicate hull points, 4.x and 5.x may return different indices |
| `convexityDefects` | `Convexity_Defects` (2 overloads) | Bound | |
| `isContourConvex` | `Is_Convex` | Bound | |
| `approxPolyDP` | `Approximate_Curve` | Bound, open and closed | |
| `boundingRect` | `Bounding_Rect` | Partial: point sets | Grayscale-image mode unbound |
| `pointPolygonTest` | `Locate_Point`, `Signed_Distance_To_Contour` | Bound, both `measureDist` modes | |
| `minAreaRect` | `Minimum_Area_Rectangle` | Bound | 4.x and 5.x may represent the same rectangle differently |
| `boxPoints` | `Box_Points` | Bound | Native vertex order is preserved; the 4.12+ and 5.0 documentation's start vertex is not guaranteed |
| `minEnclosingCircle` | `Minimum_Enclosing_Circle` | Bound | |
| `minEnclosingTriangle` | `Minimum_Enclosing_Triangle` | Bound | |
| `fitEllipse` | `Fit_Ellipse` | Bound | Exactly five points use `fitEllipseDirect`. From 4.12, the singular-system fallback for more points perturbs with `cv::theRNG`, so results need not repeat |
| `fitEllipseAMS` | `Fit_Ellipse_AMS` | Bound | From 4.12, fallback perturbation uses `cv::theRNG` |
| `fitEllipseDirect` | `Fit_Ellipse_Direct` | Bound | From 4.12, fallback perturbation uses `cv::theRNG` |
| `fitLine` | `Fit_Line_2D` | Partial: 2D, all six supported distances | 3D mode unbound |
| `intersectConvexConvex` | `Intersect_Convex_Polygons` | Bound, both `handleNested` modes | Before 4.11 non-convex input can overflow a native buffer, so Ada validates it; 4.11+ and 5.x report non-convergence as a negative area |
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
| `Subdiv2D(Rect2f)`, `initDelaunay(Rect2f)` | none | Deferred: 4.13+ and 5.x only | |

`Is_Ready` and `Bounds` report Ada-side state and have no native counterpart.

## Operations missing from OpenCV 4.6 and 4.10 (deferred)

These operations are in OpenCV 5.0 `geometry` and in 4.x releases newer than
4.10, but not in the reference releases 4.6 and 4.10. So no binding of them
would work on every supported OpenCV 4 release, and the binding has no
fallback that fakes them there. Binding them needs a cross-version strategy
for the releases that lack them.

| Native operation | First 4.x release | Status |
| --- | --- | --- |
| `approxPolyN` | 4.11 | Deferred |
| `getClosestEllipsePoints` | 4.12 | Deferred |
| `minEnclosingConvexPolygon` | 4.13 | Deferred |
| `Subdiv2D(Rect2f)`, `Subdiv2D::initDelaunay(Rect2f)` | 4.13 | Deferred |

## Unbound modes of bound operations

| Native mode | Status | Reason |
| --- | --- | --- |
| `moments` of a raster image (`binaryImage`) | Excluded | Needs image input. Geometry takes Ada point collections and has no image or Mat input API. |
| `boundingRect` of a grayscale image | Excluded | Needs image input, as above. |
| `matchShapes` of grayscale images | Excluded | Needs image input, as above. |
| Point sets of `Point2f` (`CV_32F`) in the contour operations | Deferred | Contours are integer `OpenCV.Point_Array` values. A float point-set family would need per-operation decisions on validation and semantics. |
| `fitLine` on 3D point sets | Deferred | Needs a new public 3D point type, a design decision for this 2D crate. |
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
