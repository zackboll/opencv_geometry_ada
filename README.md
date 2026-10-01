# OpenCV Geometry for Ada

Thick Ada binding to OpenCV Geometry, published as `opencv_geometry`.
Repository: https://github.com/zackboll/opencv_geometry_ada

The only production Ada dependency is `opencv_core`. The public package is
`OpenCV.Geometry` on both OpenCV versions:

| Native OpenCV | Header | Native implementation |
| --- | --- | --- |
| 4.x | `opencv2/imgproc.hpp` | `libopencv_imgproc` |
| 5.x | `opencv2/geometry.hpp` | `libopencv_geometry` |

Both link native OpenCV Core. There is no Ada Imgproc dependency.
Configuration searches pkg-config packages `opencv5`, `opencv4`, then `opencv`,
reports the actual version/backend and generates the install GPR configuration.

Operations: `Contour_Area`, `Arc_Length`, `Compute_Moments`,
`Convex_Hull`, `Convex_Hull_Indices`, `Convexity_Defects`,
`Approximate_Curve`, `Bounding_Rect`, `Is_Convex`,
`Hu_Moments`, `Match_Shapes`, `Locate_Point`,
`Signed_Distance_To_Contour`, `Minimum_Enclosing_Circle`,
`Minimum_Enclosing_Triangle`, `Minimum_Area_Rectangle`, `Fit_Ellipse`,
`Fit_Ellipse_AMS`, `Fit_Ellipse_Direct`, `Fit_Line_2D`, `Box_Points`,
`Intersect_Convex_Polygons`, `Intersect_Rotated_Rectangles`,
`Get_Rotation_Matrix_2D`, `Get_Affine_Transform`, `Invert_Affine_Transform`,
`Get_Perspective_Transform`, and `Transform_Point`. The child package
`OpenCV.Geometry.Subdiv2D` provides planar subdivisions. Every Geometry
operation common to OpenCV 4.6, 4.10, and 5.0 has a thick binding, some for
only a subset of the native modes; `docs/coverage.md` maps each native
operation to its Ada binding and records the unbound modes, the operations
missing from OpenCV 4.6 and 4.10, and the exclusions.

Point sets come in two forms. `Contour` holds integer points, for exact
integer geometry such as pixel outlines. `Float32_Point_Array` holds binary32
points, for native subpixel geometry: `Contour_Area`, `Arc_Length`,
`Compute_Moments`, `Match_Shapes`, `Is_Convex`, `Locate_Point`,
`Signed_Distance_To_Contour`, `Bounding_Rect`, `Convex_Hull`,
`Convex_Hull_Indices`, `Approximate_Curve`, `Minimum_Area_Rectangle`,
`Minimum_Enclosing_Circle`, the three `Fit_Ellipse` functions, and
`Fit_Line_2D` have overloads that call OpenCV's `CV_32F` path without
rounding coordinates to integers; Float32 results such as hulls and
approximations are Float32 point sets. Float32 coordinates must be finite.
OpenCV evaluates Float32 point sets partly in binary32, so near-degenerate or
extreme inputs can give results that differ from exact integer geometry, and
some overloads limit coordinate spans or sums where binary32 overflow would
otherwise make OpenCV fail or answer wrongly. Each overload documents the
native arithmetic, and `docs/coverage.md` lists which operations have a
Float32 mode and why the others do not. `Convexity_Defects` is integer-only
because OpenCV requires `CV_32S`, and `Minimum_Enclosing_Triangle` has no
Float32 overload because OpenCV's search can fail to return.

```ada
Outline : constant OpenCV.Geometry.Float32_Point_Array :=
  ((X => 0.5, Y => 0.25), (X => 3.75, Y => 0.25), (X => 0.5, Y => 2.5));
Area    : constant OpenCV.Float64_Value :=
  OpenCV.Geometry.Contour_Area (Outline);  --  3.65625
```

`Contour` is a subtype of `OpenCV.Point_Array`; storage stays
Ada-owned. `Convex_Hull` returns
hull points, not source indices. `Hull_Orientation` defaults to
counterclockwise using OpenCV's convention (X right, Y up); image coordinates
that increase Y downward may look reversed. `Approximate_Curve` applies
Douglas-Peucker; `Epsilon` is the maximum deviation in the range
`0.0 <= Epsilon < 1.0E30` and `Closed` connects the last vertex to the first.
Empty input yields an empty Ada-owned contour. `Bounding_Rect` returns an
upright axis-aligned `OpenCV.Rect`. Integer extent is inclusive, so a
point set spanning X=0..4 and Y=0..3 has Width=5 and Height=4. Empty input
returns (0, 0, 0, 0). Negative native origins are preserved as signed
`OpenCV.Rect` X/Y values. Inclusive extents that
cannot be represented as signed 32-bit width or height are rejected.
`Is_Convex` tests contour convexity and does not depend on winding direction.
The contour is expected to be simple; OpenCV leaves the result for
self-intersecting contours undefined. Empty, one-point, two-point, and
collinear contours are not convex. Integer contours whose native signed-32-bit
edge or cross-product arithmetic would overflow are rejected.

Moments include all 24 spatial, central and normalized fields through order 3.
Handle zero `M_00` before deriving a centroid; self-intersecting contours can
produce surprising results under Green's formula.
`Hu_Moments` takes an existing `Moments_Result` and returns the seven raw Hu
invariants indexed `1 .. 7`, not logarithmically transformed values.
Compose as `Hu_Moments (Compute_Moments (Points))`. The invariants are
unchanged by translation, scale, rotation, and reflection except the seventh,
whose sign changes under reflection.
If native Hu computation produces a non-finite value that cannot be represented
by `Float64_Value`, `Hu_Moments` raises `OpenCV_Error`.
`Match_Shapes` compares two contours with OpenCV Hu-moment matching.
Lower scores indicate more similar shapes. `Reciprocal_Log_Difference`,
`Log_Difference`, and `Relative_Log_Difference` select OpenCV I1, I2, and I3.
Relative comparison is directional because the Left contour supplies the
denominator. The unused native OpenCV parameter is not exposed. If native
matching produces a non-finite value that cannot be represented by
`Float64_Value`, `Match_Shapes` raises `OpenCV_Error`.
`Locate_Point` classifies a binary32 query as inside, on the boundary, or
outside a contour. `Signed_Distance_To_Contour` returns OpenCV's signed
distance: positive inside, zero on the boundary, negative outside. Empty
contours are outside and return the largest finite negative distance.
`Minimum_Enclosing_Circle` returns the smallest enclosing circle as a
binary32 center and radius, including OpenCV's native EPS. Empty input is
center (0, 0) and radius 0. Integer contours whose native signed-32-bit pair
addition or subtraction would overflow are rejected.
`Minimum_Enclosing_Triangle` returns the smallest-area enclosing triangle as
an Ada-owned `Enclosing_Triangle`. `Area` is OpenCV's native double result.
`Vertices` are the three native binary32 (`CV_32F`) triangle vertices. Vertex
ordering is native OpenCV output and should not be relied upon unless upstream
guarantees a cyclic start or winding. Empty input is rejected by OpenCV.
One-point, two-point, collinear, and repeated-point inputs may return repeated
vertices and zero area. Integer contours whose native convex-hull arithmetic
would overflow are rejected. Non-finite or negative native area, or a
non-finite vertex component, raises `OpenCV_Error`. OpenCV's search loops have
no iteration bound: in OpenCV 4.6, 4.10, and 5.0 they fail to return for some
nearly degenerate hulls, such as long thin slivers, which the binding cannot
detect in advance.

```ada
Triangle : constant OpenCV.Geometry.Enclosing_Triangle :=
  OpenCV.Geometry.Minimum_Enclosing_Triangle (Points);
```

`Minimum_Area_Rectangle` returns `OpenCV.Rotated_Rect`, preserving native
binary32 center, size, and angle-in-degrees fields. OpenCV 4.x and 5.x may use
different width/height/angle representations for the same rectangle; no output
normalization is applied. Inputs unsafe for native integer convex-hull
arithmetic are rejected.
`Fit_Ellipse` fits a least-squares ellipse to an Ada-owned contour through
`cv::fitEllipse`. This is a fitted ellipse, not a minimum enclosing ellipse.
The result is an `OpenCV.Rotated_Rect` describing the rectangle in which the
ellipse is inscribed. Native binary32 center, full-axis size, and
angle-in-degrees fields are preserved without normalization. Fewer than five
points raise `OpenCV.OpenCV_Error`. Repeated, collinear, or otherwise
degenerate five-or-more-point sets may still produce a finite native result,
including a zero-sized rectangle. Native failures and non-finite or negative
size components raise `OpenCV_Error`.

```ada
Ellipse : constant OpenCV.Rotated_Rect :=
  OpenCV.Geometry.Fit_Ellipse (Points);
```

`Fit_Ellipse_AMS` (`cv::fitEllipseAMS`, Approximate Mean Square) and
`Fit_Ellipse_Direct` (`cv::fitEllipseDirect`, Direct least squares) return the
same representation. AMS returns the Direct fit when it finds a parabola or
hyperbola, and falls back to OpenCV's classic `fitEllipseNoDirect` when its
system is numerically singular, as can happen for points exactly on one conic,
such as any five points. Direct falls back to `fitEllipseNoDirect` when its own
checks fail after one perturbed retry. OpenCV 4.12 and later, including 5.x,
draw perturbations from `cv::theRNG`, so such results need not repeat; before
4.12, AMS falls back without perturbing and Direct perturbs
deterministically. Both need at least five and at most
`Integer_32'Last / 13` points, because every native path can reach
`fitEllipseNoDirect`'s signed 32-bit `13 * n` allocation.

`Box_Points` converts an `OpenCV.Rotated_Rect` to exactly four Ada-owned
binary32 (`OpenCV.Float32_Point`) vertices. It is directly useful with the
rotated rectangle returned by `Minimum_Area_Rectangle` and the rectangle in
which `Fit_Ellipse` is inscribed. Coordinates are preserved without integer
rounding, normalization, or reordering. Zero and negative finite dimensions,
and unusual finite angles, are forwarded to OpenCV unchanged. Non-finite
rectangle fields and non-finite native coordinates raise `OpenCV_Error`.

Vertices preserve the active native OpenCV order without normalization. OpenCV
4.x and 5.0 `boxPoints` both delegate to `RotatedRect::points`, which lists
the corners in a fixed sequence attached to the rectangle, so the starting
vertex moves as the angle changes. The OpenCV 4.12+ and 5.0 `boxPoints`
documentation states a start at the greatest-Y vertex, using the rightmost
vertex for a greatest-Y tie, but the implementation does not consistently
satisfy that convention for arbitrary rectangles; an unrotated (angle 0)
rectangle, for example, starts at its greatest-Y leftmost vertex. Portable
callers must not depend on a particular starting vertex.

```ada
Box : constant OpenCV.Rotated_Rect :=
  OpenCV.Geometry.Minimum_Area_Rectangle (Points);

Corners : constant OpenCV.Geometry.Box_Vertices :=
  OpenCV.Geometry.Box_Points (Box);
```

## Convexity analysis

```ada
type Point_Index_Array is array (Natural range <>) of Natural;

function Convex_Hull_Indices
  (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
   return Point_Index_Array;

function Convexity_Defects
  (Points : Contour; Hull : Point_Index_Array) return Convexity_Defect_Array;

function Convexity_Defects (Points : Contour) return Convexity_Defect_Array;
```

Hull indices and defect indices are Ada indices in `Points'Range`, never
native zero-based offsets, so a contour declared as `Contour (10 .. 14)`
yields indices in `10 .. 14`. `Convex_Hull_Indices` describes the same hull
as `Convex_Hull`. When several points share a hull vertex's coordinates,
OpenCV 4.x and 5.x may return different indices among them; each returned
index still selects a hull vertex.

A `Convexity_Defect` records the bounding hull vertices (`Start_Index`,
`End_Index`), the contour point farthest inside that hull edge
(`Farthest_Index`), and `Depth`, OpenCV's 8-fractional-bit fixed-point depth
divided by `256.0`. A caller-supplied `Hull` must be strictly increasing or
strictly decreasing; out-of-range, repeated, or non-monotonic indices raise
`OpenCV_Error`. Both directions give the same defects: the closing edge from
the largest to the smallest hull index first, then ascending edges. Contours
of at most three points, and hulls of fewer than three indices, have no
defects. The single-argument form uses `Convex_Hull_Indices (Points)` and
reports a non-monotonic hull as a self-intersecting contour.

OpenCV stores `cvRound (Depth * 256)` in a signed 32-bit integer, and no
depth exceeds the bounding-box diagonal. When defects are computed, the X and
Y spans of `Points` must therefore satisfy
`Width**2 + Height**2 <= 8_388_607**2`, where
`8_388_607 = Integer_32'Last / 256`. The bound also keeps OpenCV's signed
32-bit coordinate subtraction from overflowing. Larger spans raise
`OpenCV_Error` before native code runs.

## Line fitting

```ada
type Line_Fit_Distance is (L2, L1, L12, Fair, Welsch, Huber);

function Fit_Line_2D
  (Points          : Contour;
   Distance        : Line_Fit_Distance := L2;
   Parameter       : OpenCV.Float64_Value := 0.0;
   Radius_Accuracy : OpenCV.Float64_Value := 0.01;
   Angle_Accuracy  : OpenCV.Float64_Value := 0.01) return Fitted_Line_2D;
```

`Fit_Line_2D` binds the 2D form of `cv::fitLine`. The result holds OpenCV's
unit `Direction` (vx, vy) and a `Point` (x0, y0) on the line in native binary32
values. The direction's sign is OpenCV's and is not normalized; the opposite
direction describes the same line. `L2` is orthogonal least squares; the other
distances are robust M-estimators that OpenCV solves by reweighting from
fixed-seed random subsets, so results repeat for the same input order.
`Parameter` is the constant of `Fair`, `Welsch`, and `Huber` (0.0 selects
OpenCV's defaults); the accuracies end each robust reweighting early (0.0
selects OpenCV's defaults 1.0 and 0.01). All three must be finite,
nonnegative, and at most `Float32_Value'Last`. At least one point is required,
and more than `Integer_32'Last / 2` points are rejected because OpenCV computes
`2 * n` in signed 32-bit arithmetic.

## Polygon and rotated-rectangle intersection

```ada
function Intersect_Convex_Polygons
  (Left, Right : Contour; Handle_Nested : Boolean := True)
   return Convex_Polygon_Intersection;   --  Area and Vertices

function Intersect_Rotated_Rectangles
  (Left, Right : OpenCV.Rotated_Rect)
   return Rotated_Rectangle_Intersection;  --  Kind and Vertices
```

Both return Ada-owned binary32 vertices (`Float32_Point_Array`, indexed from
1) in native OpenCV order without normalization.

`Intersect_Convex_Polygons` requires each polygon to be simple and strictly
convex with at least three vertices, traversed once in either direction:
every vertex must be a convex hull vertex, visited in hull order as
`Convex_Hull_Indices` reports it. `Is_Convex` alone is not enough: OpenCV
leaves its result for non-simple contours undefined, and it may accept
self-intersecting stars and repeated traversals. OpenCV does not
check convexity, and OpenCV 4.x releases before 4.11 (including 4.6 and 4.10)
can overflow an internal buffer on such input (OpenCV issue #25259). Vertex
coordinates must lie in `-2**24 .. 2**24`, where OpenCV's binary32 conversion
is exact. `Handle_Nested` defaults to `True` as in OpenCV. OpenCV 4.6, 4.10,
and 5.0 can emit an internal `(FLT_MAX, FLT_MAX)` sentinel as the first or last
vertex of some disjoint and contact results; it is omitted. OpenCV 4.11+ and
5.x report a non-converging intersection with a negative area, which raises
`OpenCV_Error`.

`Intersect_Rotated_Rectangles` returns `No_Intersection`,
`Partial_Intersection`, or `Full_Intersection` (OpenCV `INTERSECT_NONE`,
`INTERSECT_PARTIAL`, `INTERSECT_FULL`) with at most eight vertices. A rectangle
with zero or negative width or height intersects nothing. Non-finite fields
raise `OpenCV_Error`. Touching rectangles can be reported as a partial
intersection with one or two contact vertices; OpenCV 4.6 uses different
contact tolerances from 4.10 and 5.0.

## Rotation matrix

API:

```ada
function Get_Rotation_Matrix_2D
  (Center : OpenCV.Float32_Point;
   Angle  : OpenCV.Float64_Value;
   Scale  : OpenCV.Float64_Value := 1.0;
   Units  : OpenCV.Angle_Unit := OpenCV.Degrees)
   return OpenCV.Core.Mat;
```

`Get_Rotation_Matrix_2D` is a transform generator. It does not warp an
image. The returned Mat is always:

```text
Rows     = 2
Columns  = 3
Depth    = Float64
Channels = 1
```

and is suitable for affine warping operations such as
`OpenCV.Image_Processing.Warp_Affine`. There is no Ada Imgproc dependency;
callers that already use Imgproc can pass this Core Mat through.

`Angle` may be supplied in `Degrees` or `Radians`. `Degrees` is the default
because that matches `cv::getRotationMatrix2D`. Finite angles are reduced
modulo one full turn before any radians-to-degrees conversion, so large
finite values cannot overflow the conversion. There is no OpenCV unit flag.

Positive angles are counter-clockwise according to OpenCV's image-coordinate
convention (origin at the top-left). The rotation center maps to itself.

`Scale` is isotropic and defaults to `1.0`. Finite zero and negative Scale
values are mathematically defined by OpenCV and remain accepted.

`Center.X`, `Center.Y`, `Angle`, and `Scale` must all be finite. NaN and
`+/-Infinity` raise `OpenCV.OpenCV_Error`.

OpenCV 4 implements the native call from the legacy Imgproc header;
OpenCV 5 implements it from Geometry. The public Ada API does not expose
that split.

The `opencv_core` crate still distributes the parent package. `OpenCV.Core`
continues to own `Mat`. Geometry does not redeclare `Point`,
`Point_Array`, `Size`, `Rect`, `Scalar`, `Float32_Point`,
`Rotated_Rect`, `Angle_Unit`, or `Float64_Value`.

This relocation is source-breaking. Callers that previously wrote
`OpenCV.Core.Point_Array` or `OpenCV.Core.Rect` must update
qualification to the root `OpenCV` package.

`Contour` remains a subtype of the shared point array:

```ada
subtype Contour is OpenCV.Point_Array;
```

Architecture: thick Ada -> thin Ada C interop -> C ABI -> C++ shim -> OpenCV.
No STL, C++ exceptions or native objects cross the C ABI. Native errors become
`OpenCV.OpenCV_Error`. No Core module bridge or Core shim is used by this shim.

Linux uses GNU g++, libstdc++ and a static-PIC shim. macOS and Windows build
the C++ shim outside GPRbuild so it cannot inherit Core's Ada C++ shim:
macOS uses Apple clang++, libc++ and a dylib; Windows uses a MinGW
DLL/import library from the same prefix as OpenCV, not GNAT's g++.

## Affine and perspective transforms

```ada
type Affine_Transform_2D is
  array (Affine_Row_Index, Transform_Column_Index) of OpenCV.Float64_Value;
type Perspective_Transform_2D is
  array (Perspective_Row_Index, Transform_Column_Index)
  of OpenCV.Float64_Value;

function Get_Affine_Transform
  (Source, Destination : Float32_Point_Array) return Affine_Transform_2D;
function Invert_Affine_Transform
  (Transform : Affine_Transform_2D) return Affine_Transform_2D;
function Get_Perspective_Transform
  (Source, Destination : Float32_Point_Array;
   Method              : Perspective_Solve_Method := LU_Decomposition)
   return Perspective_Transform_2D;
function Transform_Point
  (Transform : Affine_Transform_2D; Point : OpenCV.Float32_Point)
   return OpenCV.Float32_Point;
function Transform_Point
  (Transform : Perspective_Transform_2D; Point : OpenCV.Float32_Point)
   return OpenCV.Float32_Point;
```

Transforms are Geometry-owned value matrices with 1-based indices:
`T (R, C)` is OpenCV's `M(R-1, C-1)`. No Mat crosses the C ABI; the shim
exchanges fixed plain C point and coefficient records.
`Get_Rotation_Matrix_2D` keeps returning a Core Mat.

`Get_Affine_Transform` takes exactly three and `Get_Perspective_Transform`
exactly four finite corresponding points; array bounds may differ and points
pair in iteration order. OpenCV ignores a singular solve: when its absolute
pivot test (about `2.2E-14`) finds the affine system singular, as for
collinear or repeated source points, the result is the all-zero transform,
while a degenerate triangle that passes the test can give very large finite
coefficients. `Invert_Affine_Transform` returns the all-zero transform when
its binary64 determinant is exactly zero (including underflow) or overflows
to infinity. None of these cases raises an exception.

`Perspective_Solve_Method` offers `LU_Decomposition` (default),
`Singular_Value_Decomposition`, and `QR_Decomposition`. OpenCV's EIG and
Cholesky decompositions assume a symmetric system and the NORMAL flag has no
effect here, so they are not offered. Results are native coefficients without
normalization. OpenCV before 4.12 always returns `T (3, 3) = 1.0` and, when
LU or QR finds the system singular, the matrix whose only nonzero coefficient
is `T (3, 3)`. OpenCV 4.12+ and 5.x accept the `T (3, 3) = 1.0` solution only
when the absolute residual of the 8x8 linear system is below `1.0E-8`, and
otherwise return a unit-norm least-squares homogeneous solution with
arbitrary sign whose `T (3, 3)` need not be `1.0`. Non-finite native
coefficients raise `OpenCV_Error`.

`Transform_Point` is Ada arithmetic, not an OpenCV call. It evaluates in
binary64 and rounds to binary32, rejecting non-finite input, coefficients
above `1.0E+269` in magnitude, results outside binary32 range, and
perspective points that map to infinity; unlike `cv::perspectiveTransform`,
it divides by every nonzero W. Those requirements are checked at run time,
and within them GNATprove proves that the evaluation cannot overflow
binary64.

Image warping (`warpAffine`, `warpPerspective`) is image processing and is
not part of this binding.

## Planar subdivision (Subdiv2D)

`OpenCV.Geometry.Subdiv2D` binds `cv::Subdiv2D`, an incremental Delaunay
triangulation of points inside an integer bounding rectangle:

```ada
declare
   Mesh : Subdivision :=
     Create ((X => 0, Y => 0, Width => 100, Height => 100));
   Near : Nearest_Result;
begin
   Insert (Mesh, Points);
   case Locate (Mesh, (X => 50.0, Y => 20.0)).Kind is
      when Inside_Facet | On_Edge | On_Vertex => null;
   end case;
   Near := Find_Nearest (Mesh, (X => 52.0, Y => 43.0));
end;
```

`Subdivision` is the only Geometry type that owns a native object. It is
limited, so assignment cannot duplicate ownership, and finalization releases
the native object. The opaque C handle stays private. A declared but never
initialized `Subdivision` is not ready; `Create` or `Reset` initializes it,
and `Reset` also discards every point. If a modification fails in a way that
may have left the native triangulation inconsistent, such as an allocation
failure during insertion, the object stops being ready, and every operation
except `Bounds` raises `OpenCV_Error` until `Reset`. Ordinary
OpenCV rejections, such as a point outside the bounds, leave it ready. A
native fault-injection test (`sh scripts/run_native_tests.sh`) checks this
state by failing individual allocations inside OpenCV.

Bounds are half-open: OpenCV accepts `X` from `Bounds.X` up to but excluding
`Bounds.X + Bounds.Width`, and likewise for `Y`. A point outside raises
`OpenCV_Error`; OpenCV reports it by raising an error rather than returning
its `PTLOC_OUTSIDE_RECT` classification. Duplicate insertions return the
existing vertex. Vertex and edge identifiers are native OpenCV identifiers,
meaningful only for their subdivision and not dense. An inserted point's
vertex identifier lasts until the next `Reset`; an edge identifier lasts only
until the next `Insert` or `Reset`, because insertion flips edges and reuses
edge slots. OpenCV reserves vertex identifiers 1..3 for the initial bounding
super-triangle vertices (not Voronoi virtual vertices); Voronoi computation
can create virtual vertices in other slots.

A `Subdivision` must not be used by more than one task at a time. OpenCV
mutates internal state in `Locate`, and in `Find_Nearest` and
`Voronoi_Facets`, which compute Voronoi data. Distinct subdivisions are
independent. The binary32 `Rect2f`
initialization that only OpenCV 4.13+ and 5.x provide is not bound.

OpenCV's `Subdiv2D` predicates use absolute tolerances near `FLT_EPSILON`.
Numerical behavior depends on coordinate scale and geometric conditioning,
not just pairwise spacing (the smallest distance between inserted points).
In specific random-point and jittered-grid probe/stress fixtures on OpenCV
4.10 and 5.0, the following behavior was observed:

| Spacing (units) | Behavior |
| --- | --- |
| about 0.03 or more | No `Find_Nearest` failures observed in these fixtures |
| 0.01 or less | A few percent of `Find_Nearest` answers were not nearest; some reported no vertex and raised `OpenCV_Error` |
| 0.003 or less | Up to about 30% of `Find_Nearest` answers were wrong |
| about 0.0001 | `Insert` and `Locate` sometimes failed to locate points; `Find_Nearest` sometimes failed to return |

These measurements are empirical guidance for the tested distributions, not
a guaranteed safe minimum spacing: near-collinear, nearly cocircular, and
other ill-conditioned sets can behave differently. Scale geometry so distinct
features are comfortably separated relative to OpenCV's binary32 predicates.
`Find_Nearest` enters native OpenCV synchronously. Some numerically
pathological triangulations can cause `cv::Subdiv2D::findNearest`'s unbounded
facet walk not to return; the Ada binding cannot interrupt or recover from a
native call that does not return. `Reset` can recover an unusable object after
a returned failure, but cannot help while execution is stuck inside OpenCV.
Callers requiring a hard liveness or deadline guarantee should not rely on
`Find_Nearest` for untrusted or poorly conditioned geometry.

### Extraction and navigation

`Edge_List`, `Leading_Edge_List`, and `Triangle_List` return Ada-owned arrays
in native order, indexed from 1. `Edge_List` contains copied edge segments and
`Triangle_List` contains copied triangles; both remain valid independently of
later changes to the subdivision. `Leading_Edge_List` storage remains safely
allocated, but its `Edge_Id` elements are valid only until the next `Insert`
or `Reset` of that subdivision. Buffer capacities come from the native
quad-edge count, using bounds read from the OpenCV list functions. GNATprove
shows only that the capacity arithmetic cannot overflow; the shim enforces the
capacity at run time, failing rather than writing past it. `Edge_List`
includes edges to the super-triangle vertices, which lie outside the bounds,
and `Triangle_List` keeps only triangles whose three vertices lie in the
bounds. Near the convex hull the reported triangles can differ between
releases, because OpenCV 4.12+ and 5.x use a super-triangle twice as large,
so tests check invariants rather than exact lists.

`Navigate` takes a strongly typed `Edge_Navigation`, one of the eight
`getEdge` choices from `Next_Around_Origin` to `Previous_Around_Right`.
`Rotate` takes an `Edge_Rotation` (`Same_Edge`, `Rotated_Edge`,
`Reversed_Edge`, `Reversed_Rotated_Edge`). Both are mapped explicitly to
OpenCV's encodings; neither depends on Ada enumeration positions. `Next_Edge`,
`Symmetric_Edge`, `Origin`, `Destination`, `Vertex_Point`, and `First_Edge`
complete the quad-edge queries.

Release builds of OpenCV check vertex and edge identifiers only with debug
assertions, so an invalid identifier would read outside native storage. The
shim therefore bounds every identifier against the native storage sizes before
OpenCV sees it, and thick Ada also rejects `No_Vertex`, free vertex slots, and
OpenCV's reserved null edge. A dual Voronoi edge runs from the facet on its
primal edge's right to the facet on its left, and its endpoints are those
facets' Voronoi vertices once `Find_Nearest` or `Voronoi_Facets` has computed
Voronoi data. An
endpoint is `No_Vertex` before that, and for a facet OpenCV gives no Voronoi
vertex: the facet outside the super-triangle, and a degenerate facet.

### Voronoi facets

`Voronoi_Facets (Mesh)` returns the Voronoi facet of every inserted point, in
increasing vertex order, and `Voronoi_Facets (Mesh, Sites)` returns the facets
of the listed vertices, in order and once per occurrence. A `Voronoi_Diagram`
holds `Facets`, each with its `Site`, `Site_Point`, and a `First .. Last`
slice of the shared `Points`; `Facet_Points` returns one facet's polygon
indexed from 1. Unlike OpenCV's `getVoronoiFacetList`, which treats an empty
index list as every vertex, empty `Sites` give an empty diagram. Listed sites
must be inserted points: OpenCV reads its index list without bounds checks
and silently skips free and Voronoi slots, so `No_Vertex`, the super-triangle
vertices, free slots, Voronoi vertices, and identifiers beyond native storage
raise `OpenCV_Error`.

OpenCV computes the Voronoi diagram of the inserted points together with the
three super-triangle vertices. A facet whose true Voronoi region reaches
beyond the super-triangle, as the region of every point on the convex hull
and of some points near it does, is therefore closed by circumcenters of
triangles with a super-triangle vertex. Those lie far outside the bounds and
differ between releases. In the tested well-spaced fixtures, each Voronoi
facet point was nearest to its site among the inserted points (up to
rounding). Spacing of about 0.03 units was an empirical observation in
those fixtures, not a guaranteed safe threshold: conditioning, including
near-collinear and nearly cocircular configurations, also matters.

OpenCV can fail to create a Voronoi vertex for a facet, for example when
degenerate or ill-conditioned geometry makes a circumcenter impossible to
compute or represent within its accepted finite binary32 range. Probes
observed missing vertices among closely spaced points about 0.0001 to 0.003
units apart, depending on the distribution; these are not universal
thresholds. OpenCV reports the origin in place of a missing vertex. The shim
detects this for each facet, and `Voronoi_Facet.Complete` is `False` when its
polygon contains such placeholder points; the other facets are unaffected.

The C ABI adds a count query that sizes both buffers. Repeated sites make the
point count unbounded by anything Ada knows beforehand, and one query serves
both overloads, although a quad-edge bound would suffice for every-vertex
diagrams. Ada allocates the buffers, and the shim fills them from vectors it
owns for the call, publishing nothing if the native result would not fit.

Validation boundary: thick Ada checks listed sites and every returned count,
offset, and site at run time; the shim bounds identifiers and verifies the
site pairing at run time; the facet contents themselves are OpenCV's and are
covered by tests, including nearest-site checks in well-spaced fixtures;
nothing here is proved by GNATprove.

## Development

Place Core at `/home/zboll/git/opencv/core` alongside this repository at
`/home/zboll/git/opencv/geometry` (or use the same sibling layout elsewhere).
Install Alire, a native Ada/GPRbuild toolchain, OpenCV development files and
pkg-config. From the Geometry repository run:

```sh
alr -n build
alr -n -C tests run
```

Cross-platform CI validates Ubuntu OpenCV 4 and Homebrew OpenCV 5 on pull
requests and pushes. MSYS2 OpenCV 5 runs after a push/merge to `main` or
on manual dispatch, not as a PR gate. CI checks native shim dependencies.
Licensed under Apache-2.0.
