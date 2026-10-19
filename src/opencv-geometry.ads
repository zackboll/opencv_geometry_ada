with OpenCV.Core;

--  Computational geometry on Ada-owned point sets, backed by native OpenCV:
--  contour area, length and moments; convex hulls, hull indices and
--  convexity defects; curve approximation, convexity tests, bounding
--  rectangles, point location and shape matching; minimum-area rectangles
--  and enclosing circles and triangles; ellipse and line fitting; convex
--  polygon and rotated-rectangle intersections; and affine and perspective
--  transforms. Planar Delaunay and Voronoi subdivisions are in the child
--  package OpenCV.Geometry.Subdiv2D.
--
--  Point sets: a Contour is an OpenCV.Point_Array of integer points, passed
--  to OpenCV as CV_32S. Overloads that take a Float32_Point_Array use
--  OpenCV's binary32 CV_32F path without rounding to integers. Input arrays
--  may have any bounds and are read in index order; each declaration states
--  the bounds of its result.
--
--  Ownership: every operation here is a function whose inputs are not
--  modified. Results are Ada-owned values, arrays and records; none refers
--  to native storage. The one exception is Get_Rotation_Matrix_2D, which
--  returns an OpenCV.Core.Mat with Core's ordinary Mat ownership.
--
--  Errors: input that the binding rejects, failures reported by OpenCV and
--  non-finite native results raise OpenCV.OpenCV_Error, as each declaration
--  describes. Where native arithmetic or memory safety requires it, an
--  operation checks documented limits before calling OpenCV; each
--  declaration states its own.
--
--  Native backend and versions: on OpenCV 4 these operations call the
--  native imgproc library, and on OpenCV 5 the native geometry library. The
--  Ada declarations are the same on every supported release, OpenCV 4.6 and
--  later 4.x releases and 5.x; where native results differ between
--  releases, the declaration says so. Is_Natively_Supported reports what
--  the linked OpenCV provides, not what this package binds: native
--  approxPolyN and minEnclosingConvexPolygon remain unbound, as do 3-D line
--  fitting, the raster-image modes of moments, boundingRect and matchShapes,
--  and Float32 enclosing triangles. Image processing, including extracting
--  contours from images, belongs to the OpenCV Imgproc binding.

package OpenCV.Geometry is

   --  Availability in the linked native OpenCV, NOT Ada binding coverage.
   --  Approximate_Convex_Polygon and Minimum_Enclosing_Convex_Polygon remain
   --  unbound even when supported here. Every feature is available natively
   --  on OpenCV 5.x and from the 4.x release named below; earlier releases,
   --  including 4.6 and 4.10, report all four as unsupported.
   --  @enum Approximate_Convex_Polygon_Feature Native cv::approxPolyN, from
   --    4.11; no Ada operation binds it.
   --  @enum Closest_Ellipse_Points_Feature Native
   --    cv::getClosestEllipsePoints, from 4.12. Closest_Ellipse_Points works
   --    on every supported release regardless.
   --  @enum Minimum_Enclosing_Convex_Polygon_Feature Native
   --    cv::minEnclosingConvexPolygon, from 4.13; no Ada operation binds it.
   --  @enum Float32_Subdivision_Bounds_Feature Native cv::Rect2f bounds for
   --    cv::Subdiv2D, from 4.13. OpenCV.Geometry.Subdiv2D accepts Float32
   --    bounds on every supported release regardless.
   type Native_Feature is
     (Approximate_Convex_Polygon_Feature,
      Closest_Ellipse_Points_Feature,
      Minimum_Enclosing_Convex_Polygon_Feature,
      Float32_Subdivision_Bounds_Feature);

   --  Whether the OpenCV release this binding was built against provides
   --  Feature natively. The answer is fixed by the native version at shim
   --  build time; it never reports whether an Ada operation exists, and a
   --  True result does not bind an unbound native function.
   --  @param Feature The native capability to query.
   --  @return True when the linked native OpenCV provides Feature.
   --  @exception OpenCV_Error A failure reported by the shim query.
   function Is_Natively_Supported (Feature : Native_Feature) return Boolean;

   --  An integer contour or point set, for integer-coordinate geometry: an
   --  OpenCV.Point_Array passed to OpenCV as CV_32S points in index order.
   --  Inputs may have any bounds. Contour results are zero-based, or the
   --  null range 1 .. 0 when empty.
   subtype Contour is OpenCV.Point_Array;

   --  Ada-owned sequence of binary32 points: a point set for native subpixel
   --  geometry (OpenCV CV_32F, Point2f), an intersection region returned by
   --  OpenCV, or one side of a transform correspondence.
   --
   --  Operations overloaded for Float32_Point_Array call OpenCV's native
   --  CV_32F path, so coordinates are never rounded to integers. Every
   --  coordinate passed to them must be finite: NaN and infinities raise
   --  OpenCV_Error. Iteration order is native order, and bounds may be any
   --  Natural range. OpenCV computes coordinate differences, and for some
   --  operations their products, in binary32, so results can differ from
   --  those of integer-coordinate contours with the same shape; each overload
   --  states the native arithmetic that matters.
   type Float32_Point_Array is
     array (Natural range <>) of OpenCV.Float32_Point;

   --  One approximate closest ellipse point per query, preserving
   --  Points'Range (including null and Natural'Last-adjacent ranges).
   --  Native on OpenCV 4.12+ and 5.x; a private compatibility implementation
   --  is used on 4.6--4.11. Empty input returns the same null range.
   --  Ellipse fields and Float32 queries must be finite; both ellipse
   --  dimensions must be positive. Native arithmetic has three fixed
   --  iterations: extreme inputs can produce non-finite output, rejected
   --  with OpenCV_Error. No arbitrary coordinate limit is imposed.
   --  Integer queries enter CV_32S and OpenCV converts them to Point2f,
   --  possibly losing low bits. Both overloads return Float32 points.
   --  Ellipse and Points are unchanged.
   --  @param Ellipse The ellipse as the rotated rectangle in which it is
   --    inscribed (full axis lengths, angle in degrees); every field finite,
   --    width and height positive.
   --  @param Points Query points, with any bounds, including a null range.
   --  @return For each query, at the same index, its approximate closest
   --    point on the ellipse: the result has exactly the bounds of Points
   --    (the postcondition), and every coordinate is finite.
   --  @exception OpenCV_Error A non-finite Ellipse field, a nonpositive
   --    width or height, more than Integer_32'Last points, a non-finite
   --    native point, or a failure reported by OpenCV.
   function Closest_Ellipse_Points
     (Ellipse : OpenCV.Rotated_Rect; Points : Contour)
      return Float32_Point_Array
   with
     Post =>
       Closest_Ellipse_Points'Result'First = Points'First
       and then Closest_Ellipse_Points'Result'Last = Points'Last;

   --  Closest_Ellipse_Points for binary32 queries, which reach OpenCV as
   --  CV_32F without rounding, with the same native and compatibility
   --  implementations, Ellipse rules and empty-input result as the integer
   --  overload. Every query coordinate must be finite. Ellipse and Points
   --  are unchanged.
   --  @param Ellipse The ellipse as the rotated rectangle in which it is
   --    inscribed; every field finite, width and height positive.
   --  @param Points Query points, with any bounds; every coordinate finite.
   --  @return For each query, at the same index, its approximate closest
   --    point on the ellipse: the result has exactly the bounds of Points
   --    (the postcondition), and every coordinate is finite.
   --  @exception OpenCV_Error A non-finite Ellipse field or query
   --    coordinate, a nonpositive width or height, more than
   --    Integer_32'Last points, a non-finite native point, or a failure
   --    reported by OpenCV.
   function Closest_Ellipse_Points
     (Ellipse : OpenCV.Rotated_Rect; Points : Float32_Point_Array)
      return Float32_Point_Array
   with
     Post =>
       Closest_Ellipse_Points'Result'First = Points'First
       and then Closest_Ellipse_Points'Result'Last = Points'Last;

   --  Calculates the OpenCV polygon area of Points with cv::contourArea.
   --  When Oriented is False, the result is nonnegative; otherwise it
   --  retains OpenCV's orientation sign. Empty and degenerate contours
   --  return zero. Points is unchanged.
   --  @param Points Polygon vertices in traversal order, with any bounds; may
   --    be empty.
   --  @param Oriented False for the absolute area; True for OpenCV's signed
   --    area, whose sign depends on the traversal direction.
   --  @return The area in binary64, as OpenCV computes it.
   --  @exception OpenCV_Error More than Integer_32'Last points, or a failure
   --    reported by OpenCV.
   function Contour_Area
     (Points : Contour; Oriented : Boolean := False)
      return OpenCV.Float64_Value;

   --  Contour_Area of a Float32 point set. OpenCV accumulates the cross
   --  products of the binary32 coordinates in binary64, so the result is
   --  always finite. Points is unchanged.
   --  @param Points Polygon vertices in traversal order, with any bounds;
   --    every coordinate must be finite. May be empty.
   --  @param Oriented False for the absolute area; True for OpenCV's signed
   --    area, whose sign depends on the traversal direction.
   --  @return The area in binary64, as OpenCV computes it.
   --  @exception OpenCV_Error A NaN or infinite coordinate, more than
   --    Integer_32'Last points, or a failure reported by OpenCV.
   function Contour_Area
     (Points : Float32_Point_Array; Oriented : Boolean := False)
      return OpenCV.Float64_Value;

   --  Calculates the OpenCV curve length of Points with cv::arcLength.
   --  Closed includes the segment from the final point to the first. Empty
   --  and one-point contours return zero. Points is unchanged.
   --  @param Points Curve vertices in order, with any bounds; may be empty.
   --  @param Closed True to include the closing segment from the last point
   --    back to the first.
   --  @return The nonnegative length in binary64, as OpenCV computes it.
   --  @exception OpenCV_Error More than Integer_32'Last points, or a failure
   --    reported by OpenCV.
   function Arc_Length
     (Points : Contour; Closed : Boolean) return OpenCV.Float64_Value;

   --  Arc_Length of a Float32 point set. OpenCV computes each segment's
   --  coordinate differences, their squares, and the segment length in
   --  binary32 and sums the lengths in binary64. A segment longer than about
   --  1.8E+19 overflows binary32 and makes the native length infinite, which
   --  raises OpenCV_Error; segment components below about 1.0E-19 lose
   --  precision as their squares underflow. Points is unchanged.
   --  @param Points Curve vertices in order, with any bounds; every
   --    coordinate must be finite. May be empty.
   --  @param Closed True to include the closing segment from the last point
   --    back to the first.
   --  @return The nonnegative, finite length in binary64.
   --  @exception OpenCV_Error A NaN or infinite coordinate, more than
   --    Integer_32'Last points, an infinite native length, or a failure
   --    reported by OpenCV.
   function Arc_Length
     (Points : Float32_Point_Array; Closed : Boolean)
      return OpenCV.Float64_Value;

   --  Spatial, central, and normalized central moments through third order,
   --  the 24 fields of cv::Moments, copied field by field. Central moments
   --  are taken about the centroid (M_10 / M_00, M_01 / M_00), and OpenCV
   --  defines each normalized moment as `Nu_pq = Mu_pq / M_00**(1 + (p+q)/2)`.
   --  Every field defaults to 0.0.
   --  @field M_00 Spatial moment m00; for an ordinary non-self-intersecting
   --    contour, its polygon area.
   --  @field M_10 Spatial moment m10, first order in X.
   --  @field M_01 Spatial moment m01, first order in Y.
   --  @field M_20 Spatial moment m20, second order in X.
   --  @field M_11 Spatial moment m11, first order in X and in Y.
   --  @field M_02 Spatial moment m02, second order in Y.
   --  @field M_30 Spatial moment m30, third order in X.
   --  @field M_21 Spatial moment m21, second order in X, first in Y.
   --  @field M_12 Spatial moment m12, first order in X, second in Y.
   --  @field M_03 Spatial moment m03, third order in Y.
   --  @field Mu_20 Central moment mu20, about the centroid.
   --  @field Mu_11 Central moment mu11, about the centroid.
   --  @field Mu_02 Central moment mu02, about the centroid.
   --  @field Mu_30 Central moment mu30, about the centroid.
   --  @field Mu_21 Central moment mu21, about the centroid.
   --  @field Mu_12 Central moment mu12, about the centroid.
   --  @field Mu_03 Central moment mu03, about the centroid.
   --  @field Nu_20 Normalized central moment nu20, scale invariant.
   --  @field Nu_11 Normalized central moment nu11, scale invariant.
   --  @field Nu_02 Normalized central moment nu02, scale invariant.
   --  @field Nu_30 Normalized central moment nu30, scale invariant.
   --  @field Nu_21 Normalized central moment nu21, scale invariant.
   --  @field Nu_12 Normalized central moment nu12, scale invariant.
   --  @field Nu_03 Normalized central moment nu03, scale invariant.
   type Moments_Result is record
      M_00 : OpenCV.Float64_Value := 0.0;
      M_10 : OpenCV.Float64_Value := 0.0;
      M_01 : OpenCV.Float64_Value := 0.0;
      M_20 : OpenCV.Float64_Value := 0.0;
      M_11 : OpenCV.Float64_Value := 0.0;
      M_02 : OpenCV.Float64_Value := 0.0;
      M_30 : OpenCV.Float64_Value := 0.0;
      M_21 : OpenCV.Float64_Value := 0.0;
      M_12 : OpenCV.Float64_Value := 0.0;
      M_03 : OpenCV.Float64_Value := 0.0;

      Mu_20 : OpenCV.Float64_Value := 0.0;
      Mu_11 : OpenCV.Float64_Value := 0.0;
      Mu_02 : OpenCV.Float64_Value := 0.0;
      Mu_30 : OpenCV.Float64_Value := 0.0;
      Mu_21 : OpenCV.Float64_Value := 0.0;
      Mu_12 : OpenCV.Float64_Value := 0.0;
      Mu_03 : OpenCV.Float64_Value := 0.0;

      Nu_20 : OpenCV.Float64_Value := 0.0;
      Nu_11 : OpenCV.Float64_Value := 0.0;
      Nu_02 : OpenCV.Float64_Value := 0.0;
      Nu_30 : OpenCV.Float64_Value := 0.0;
      Nu_21 : OpenCV.Float64_Value := 0.0;
      Nu_12 : OpenCV.Float64_Value := 0.0;
      Nu_03 : OpenCV.Float64_Value := 0.0;
   end record;

   --  Spatial, central, and normalized central moments through third order
   --  of the polygon Points, computed by cv::moments. For ordinary
   --  non-self-intersecting contours, M_00 is the polygon area. A centroid,
   --  when meaningful, is (M_10 / M_00, M_01 / M_00); callers must handle
   --  M_00 = 0.0 themselves. Self-intersecting contours may have surprising
   --  moments because OpenCV uses Green's formula. Empty contours return an
   --  all-zero result. Points is unchanged.
   --  @param Points Polygon vertices in traversal order, with any bounds; may
   --    be empty.
   --  @return The native moments of the polygon.
   --  @exception OpenCV_Error More than Integer_32'Last points, or a failure
   --    reported by OpenCV.
   function Compute_Moments (Points : Contour) return Moments_Result;

   --  Compute_Moments of a Float32 point set. OpenCV evaluates Green's
   --  formula in binary64 from the binary32 coordinates. When the magnitude
   --  of OpenCV's computed doubled area is at most FLT_EPSILON
   --  (`2.0**(-23)`), that is, for an absolute area of at most about 6.0E-8,
   --  every field is 0.0; an integer contour never has such a nonzero area,
   --  but a small Float32 one can. Non-finite native moments, which extreme
   --  coordinates can produce, for example in a self-intersecting contour
   --  whose net area is tiny, raise OpenCV_Error. Points is unchanged.
   --  @param Points Polygon vertices in traversal order, with any bounds;
   --    every coordinate must be finite. May be empty.
   --  @return The native moments, every field finite.
   --  @exception OpenCV_Error A NaN or infinite coordinate, more than
   --    Integer_32'Last points, a non-finite native moment, or a failure
   --    reported by OpenCV.
   function Compute_Moments
     (Points : Float32_Point_Array) return Moments_Result;

   --  Position of a Hu invariant: index I holds OpenCV's hu[I - 1].
   type Hu_Moment_Index is range 1 .. 7;

   --  The seven Hu invariants, indexed in OpenCV order.
   type Hu_Moments_Result is array (Hu_Moment_Index) of OpenCV.Float64_Value;

   --  Seven Hu invariants of Moments in OpenCV order, indexed 1 .. 7, by
   --  cv::HuMoments. The values are the raw invariants, not logarithmically
   --  transformed Match_Shapes scores. They are invariant to translation,
   --  scale, rotation, and reflection except the seventh, whose sign changes
   --  under reflection. Rasterized-image transforms can differ slightly.
   --  Compose with Compute_Moments as Hu_Moments (Compute_Moments (Points)).
   --  Moments is unchanged.
   --  @param Moments Moments, normally from Compute_Moments; OpenCV uses its
   --    normalized central moments. Every field must be finite: a
   --    non-finite field, which only invalid data can hold, raises
   --    OpenCV_Error.
   --  @return The seven finite invariants.
   --  @exception OpenCV_Error A non-finite field of Moments, a native Hu
   --    value that is not finite and so cannot be represented by
   --    Float64_Value, or a failure reported by OpenCV.
   function Hu_Moments (Moments : Moments_Result) return Hu_Moments_Result;

   --  Orientation of a convex hull result, in OpenCV's convention: X
   --  increases rightward and Y increases upward. Image coordinates often
   --  increase Y downward, so the visual winding may appear reversed.
   --  @enum Counterclockwise Counterclockwise order, OpenCV's default
   --    (clockwise = false).
   --  @enum Clockwise Clockwise order (OpenCV clockwise = true).
   type Hull_Orientation is (Counterclockwise, Clockwise);

   --  Convex hull of Points as an Ada-owned contour of hull points, not
   --  source-point indices, computed by cv::convexHull. Empty input returns
   --  an empty contour. Points is unchanged. More than Integer_32'Last - 2
   --  points raise OpenCV_Error because native convexHull computes total + 2
   --  in signed int before stack allocation, and so do inputs whose native
   --  signed 32-bit hull arithmetic would overflow.
   --  @param Points The point set, with any bounds; may be empty.
   --  @param Orientation Winding of the result, counterclockwise by default.
   --  @return The hull vertices, copied from Points, in the requested
   --    winding: zero-based, or the null range 1 .. 0 for empty input.
   --  @exception OpenCV_Error Too many points, coordinates that would
   --    overflow native hull arithmetic, or a failure reported by OpenCV.
   function Convex_Hull
     (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
      return Contour;

   --  Convex hull of a Float32 point set as an Ada-owned Float32 point set,
   --  zero-based like the integer result; empty input returns the null
   --  range 1 .. 0. Hull points are copies of input points, never rounded,
   --  except that OpenCV receives each -0.0 coordinate as +0.0: native
   --  convexHull compares its extreme points bitwise, so a set of equal
   --  points mixing +0.0 and -0.0 would otherwise yield an empty hull. The
   --  orientation convention is the integer overload's. OpenCV compares
   --  binary32 coordinate differences through binary64 cross products, and
   --  OpenCV 5.x first normalizes those differences to unit vectors, so
   --  nearly collinear points can be kept or dropped differently by OpenCV
   --  4.x and 5.x. So that no difference overflows, the X span and the Y
   --  span of Points, computed in binary64, must each be at most
   --  Float32_Value'Last; wider sets raise OpenCV_Error. Points is
   --  unchanged. More than Integer_32'Last - 2 points raise OpenCV_Error
   --  because native convexHull computes total + 2 in signed int.
   --  @param Points The point set, with any bounds; every coordinate must be
   --    finite. May be empty.
   --  @param Orientation Winding of the result, counterclockwise by default.
   --  @return The hull vertices in the requested winding.
   --  @exception OpenCV_Error A NaN or infinite coordinate, too many points,
   --    an X or Y span above Float32_Value'Last, a non-finite native vertex,
   --    or a failure reported by OpenCV.
   function Convex_Hull
     (Points      : Float32_Point_Array;
      Orientation : Hull_Orientation := Counterclockwise)
      return Float32_Point_Array;

   --  Indices into a point set, such as a convex hull given as positions in
   --  Points'Range.
   type Point_Index_Array is array (Natural range <>) of Natural;

   --  Convex hull of Points as indices into Points. Every value is an index
   --  in Points'Range, not a native zero-based offset, so shifted and other
   --  nonzero Points bounds are preserved. The indices describe the same
   --  hull as Convex_Hull with the same Orientation. OpenCV cyclically
   --  shifts the sequence to be strictly increasing or strictly decreasing
   --  when possible, which holds for simple contours; a self-intersecting
   --  contour may yield a sequence that is neither. When several points
   --  share one hull vertex's coordinates, any of their indices may be
   --  returned, and OpenCV 4.x and 5.x can choose differently. Points is
   --  unchanged. Inputs that would overflow native integer convex-hull
   --  arithmetic raise OpenCV_Error, including more than Integer_32'Last - 2
   --  points because native convexHull computes total + 2 in signed int.
   --  @param Points The point set, with any bounds; may be empty.
   --  @param Orientation Winding of the hull, counterclockwise by default.
   --  @return The hull as indices in Points'Range, at most Points'Length of
   --    them (the postcondition): zero-based, or the null range 1 .. 0 for
   --    empty input.
   --  @exception OpenCV_Error Too many points, coordinates that would
   --    overflow native hull arithmetic, a native index outside Points, or a
   --    failure reported by OpenCV.
   function Convex_Hull_Indices
     (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
      return Point_Index_Array
   with
     Post =>
       Convex_Hull_Indices'Result'Length <= Points'Length
       and then (for all Index of Convex_Hull_Indices'Result =>
                   Index in Points'Range);

   --  Convex hull of a Float32 point set as indices in Points'Range,
   --  describing the same hull as the Float32 Convex_Hull with the same
   --  Orientation, under the same count limit (Integer_32'Last - 2 points,
   --  due to native signed total + 2), rules for signed zeros and spans,
   --  and OpenCV 4.x and 5.x differences. Among points with equal coordinates,
   --  any index may be returned. Points is unchanged.
   --  @param Points The point set, with any bounds; every coordinate must be
   --    finite. May be empty.
   --  @param Orientation Winding of the hull, counterclockwise by default.
   --  @return The hull as indices in Points'Range, at most Points'Length of
   --    them (the postcondition): zero-based, or the null range 1 .. 0 for
   --    empty input.
   --  @exception OpenCV_Error A NaN or infinite coordinate, too many points,
   --    an X or Y span above Float32_Value'Last, a native index outside
   --    Points, or a failure reported by OpenCV.
   function Convex_Hull_Indices
     (Points      : Float32_Point_Array;
      Orientation : Hull_Orientation := Counterclockwise)
      return Point_Index_Array
   with
     Post =>
       Convex_Hull_Indices'Result'Length <= Points'Length
       and then (for all Index of Convex_Hull_Indices'Result =>
                   Index in Points'Range);

   --  A region where Points departs inward from one hull edge. Start_Index
   --  and End_Index are the hull vertices bounding that edge, and
   --  Farthest_Index is the contour point between them farthest from the
   --  edge's line; all three are indices in Points'Range. Depth is that
   --  distance at OpenCV's 1/256 fixed-point resolution: the native
   --  fixed-point value divided by 256.0, which is exactly representable.
   --  Depth is nonnegative; a defect shallower than 1/512 reports 0.0.
   --  @field Start_Index Index in Points'Range of the hull vertex where the
   --    defect begins.
   --  @field End_Index Index in Points'Range of the hull vertex where the
   --    defect ends.
   --  @field Farthest_Index Index in Points'Range of the contour point
   --    farthest from the hull edge.
   --  @field Depth Distance of that point from the edge's line, a multiple
   --    of 1/256.
   type Convexity_Defect is record
      Start_Index    : Natural := 0;
      End_Index      : Natural := 0;
      Farthest_Index : Natural := 0;
      Depth          : OpenCV.Float64_Value := 0.0;
   end record;

   --  Convexity defects in the order OpenCV reports them.
   type Convexity_Defect_Array is array (Natural range <>) of Convexity_Defect;

   --  Convexity defects of Points relative to Hull, a sequence of indices in
   --  Points'Range such as the result of Convex_Hull_Indices. Hull must be
   --  strictly increasing or strictly decreasing; out-of-range, repeated,
   --  or otherwise non-monotonic indices raise OpenCV_Error. Hull is not
   --  checked to be the convex hull of Points: defects are measured against
   --  the edges between consecutive Hull indices, including the closing
   --  edge. Both Hull directions give the same result, ordered by OpenCV:
   --  the closing edge from the largest to the smallest Hull index first,
   --  then edges in ascending index order. Points should be a simple
   --  contour. After Hull is validated, a Points of at most three points or
   --  a Hull of fewer than three indices yields an empty result. Otherwise
   --  the X and Y spans of Points, Width and Height, must satisfy
   --  `Width**2 + Height**2 <= 8_388_607**2`, where 8_388_607 is
   --  Integer_32'Last / 256: OpenCV stores Depth * 256 rounded in a signed
   --  32-bit integer, and no Depth exceeds the bounding-box diagonal. This
   --  also keeps native signed 32-bit coordinate subtraction from
   --  overflowing. Larger spans raise OpenCV_Error before native code runs.
   --  Points and Hull are unchanged.
   --  @param Points A simple contour, with any bounds.
   --  @param Hull Strictly monotonic indices in Points'Range, normally
   --    Convex_Hull_Indices (Points).
   --  @return The defects, ordered by OpenCV, with every index in
   --    Points'Range and at most Hull'Length defects (the postcondition):
   --    zero-based, or the null range 1 .. 0 when there are none.
   --  @exception OpenCV_Error A Hull index outside Points'Range, a repeated
   --    or non-monotonic Hull, spans beyond the fixed-point depth range,
   --    more than Integer_32'Last points, a native index outside Points, or
   --    a failure reported by OpenCV.
   function Convexity_Defects
     (Points : Contour; Hull : Point_Index_Array) return Convexity_Defect_Array
   with
     Post =>
       Convexity_Defects'Result'Length <= Hull'Length
       and then (for all Defect of Convexity_Defects'Result =>
                   Defect.Start_Index in Points'Range
                   and then Defect.End_Index in Points'Range
                   and then Defect.Farthest_Index in Points'Range);

   --  Convexity defects of Points relative to its own convex hull. Points
   --  of at most three points yield an empty result. Otherwise this is
   --  Convexity_Defects (Points, Convex_Hull_Indices (Points)), except that
   --  a hull whose indices are not monotonic, which indicates that Points is
   --  self-intersecting, raises OpenCV_Error with that diagnosis. Points is
   --  unchanged.
   --  @param Points A simple contour, with any bounds; may be empty.
   --  @return The defects, ordered by OpenCV, with every index in
   --    Points'Range and at most Points'Length defects (the postcondition):
   --    zero-based, or the null range 1 .. 0 when there are none.
   --  @exception OpenCV_Error A non-monotonic computed hull, spans beyond the
   --    fixed-point depth range, or any failure of Convex_Hull_Indices or of
   --    the native defect computation.
   function Convexity_Defects (Points : Contour) return Convexity_Defect_Array
   with
     Post =>
       Convexity_Defects'Result'Length <= Points'Length
       and then (for all Defect of Convexity_Defects'Result =>
                   Defect.Start_Index in Points'Range
                   and then Defect.End_Index in Points'Range
                   and then Defect.Farthest_Index in Points'Range);

   --  Returns OpenCV's native minimum-area rotated rectangle. Center, Size,
   --  and Angle_Degrees are binary32 native results; Angle_Degrees is in
   --  degrees. OpenCV 4.13 introduced the convention also used by 5.x:
   --  angles in [-90, 0), with changed width/height assignment; 4.12 and
   --  earlier use the older representation. For ordinary nondegenerate
   --  inputs this changes the representation, not the minimum-area region.
   --  Width need not identify the same physical side across releases. Use
   --  Box_Points for geometric vertices, without assuming a starting vertex.
   --  Empty and degenerate contours preserve the native representation; no
   --  cross-version numerical equivalence is promised for degenerate cases.
   --  Points is unchanged. Inputs that would overflow native integer
   --  convex-hull arithmetic raise OpenCV_Error. More than Integer_32'Last / 3
   --  points are rejected before packing: native rotating calipers allocates
   --  three binary32 values per hull vertex using signed count arithmetic.
   --  @param Points The point set, with any bounds; may be empty.
   --  @return The native minimum-area rotated rectangle, every field finite
   --    and Size nonnegative.
   --  @exception OpenCV_Error Too many points or coordinates that would
   --    overflow native hull arithmetic, a non-finite or negative native
   --    field, or a failure reported by OpenCV.
   function Minimum_Area_Rectangle
     (Points : Contour) return OpenCV.Rotated_Rect;

   --  Minimum_Area_Rectangle of a Float32 point set, with the native version
   --  convention described above and without integer rounding. OpenCV uses
   --  binary32 rotating calipers over the hull that the Float32 Convex_Hull
   --  describes, with the same handling of signed zeros and the same
   --  coordinate span limit. OpenCV allocates three binary32 values per
   --  hull vertex in signed 32-bit arithmetic, and every Float32 point can
   --  be a hull vertex, so more than Integer_32'Last / 3 points raise
   --  OpenCV_Error. OpenCV compares candidate areas in binary32, starting
   --  from FLT_MAX: when every candidate rectangle's area exceeds
   --  Float32_Value'Last (sides of about 1.8E+19 and more), it computes a
   --  non-finite rectangle, which raises OpenCV_Error, as do other
   --  non-finite or negative native fields. Points is unchanged.
   --  @param Points The point set, with any bounds; every coordinate finite.
   --    May be empty.
   --  @return The native minimum-area rotated rectangle, every field finite
   --    and Size nonnegative.
   --  @exception OpenCV_Error A NaN or infinite coordinate, more than
   --    Integer_32'Last / 3 points, an X or Y span above Float32_Value'Last,
   --    a non-finite or negative native field, or a failure reported by
   --    OpenCV.
   function Minimum_Area_Rectangle
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect;

   --  Least-squares ellipse fitted to Points by cv::fitEllipse. This is a
   --  fitted ellipse, not a minimum enclosing ellipse. The result is the
   --  rotated rectangle in which that ellipse is inscribed. Center, Size,
   --  and Angle_Degrees are native binary32 values; Angle_Degrees is in
   --  degrees. Size.Width and Size.Height are full axis lengths, not
   --  radii. Native width, height, and angle fields are preserved without
   --  normalization, axis swapping, or a preferred orientation. Negative
   --  centers are preserved. Points is unchanged. Fewer than five points
   --  raise OpenCV.OpenCV_Error. Five or more points need not be convex,
   --  uniquely ordered, or enclose nonzero area. Repeated, collinear, and
   --  other degenerate sets may still produce a finite native result,
   --  including a zero-sized rectangle. Native failures and non-finite or
   --  negative size components raise OpenCV.OpenCV_Error. OpenCV fits
   --  exactly five points with fitEllipseDirect, and more with its classic
   --  method, which perturbs the points and retries when its system is
   --  singular, as for points exactly on one conic. OpenCV 4.12 and later,
   --  including 5.x, draw that perturbation from cv::theRNG, so such
   --  results need not repeat; earlier releases perturb deterministically.
   --  @param Points At least five points, with any bounds.
   --  @return The native rotated rectangle of the fitted ellipse.
   --  @exception OpenCV_Error Fewer than five or more than
   --    Integer_32'Last / 13 points (the native classic fit sizes a buffer as
   --    `13 * n` doubles in signed 32-bit arithmetic), a non-finite or
   --    negative native field, or a failure reported by OpenCV.
   function Fit_Ellipse (Points : Contour) return OpenCV.Rotated_Rect;

   --  Ellipse fitted to Points by cv::fitEllipseAMS, the Approximate Mean
   --  Square method of Taubin. The result has Fit_Ellipse's representation:
   --  the rotated rectangle in which the ellipse is inscribed, with native
   --  binary32 center, full-axis Size, and Angle_Degrees in degrees, preserved
   --  without normalization. When AMS yields a parabola or hyperbola rather
   --  than an ellipse, OpenCV returns Fit_Ellipse_Direct's result instead.
   --  When its system is numerically singular, as can happen for points
   --  lying exactly on one conic, such as any five points, OpenCV falls back
   --  to its classic least-squares fitEllipseNoDirect. OpenCV 4.12 and later,
   --  including 5.x, first retry such a system with random perturbations
   --  from cv::theRNG, so results for such sets need not repeat, and on those
   --  releases every call advances that generator. Fewer than five points
   --  raise OpenCV_Error. Because every native path can reach
   --  fitEllipseNoDirect, which sizes a buffer as 13 * n doubles in signed
   --  32-bit arithmetic, more than Integer_32'Last / 13 points raise
   --  OpenCV_Error. Repeated, collinear, and other degenerate sets may still
   --  produce a finite native result, including a zero-sized rectangle.
   --  Native failures and non-finite or negative size components raise
   --  OpenCV_Error. Points is unchanged.
   --  @param Points At least five points, with any bounds.
   --  @return The native rotated rectangle of the fitted ellipse.
   --  @exception OpenCV_Error Fewer than five or more than
   --    Integer_32'Last / 13 points, a non-finite or negative native field,
   --    or a failure reported by OpenCV.
   function Fit_Ellipse_AMS (Points : Contour) return OpenCV.Rotated_Rect;

   --  Ellipse fitted to Points by cv::fitEllipseDirect, the Direct least
   --  squares method of Fitzgibbon, Pilu, and Fisher, which constrains the
   --  fit to an ellipse. The result has Fit_Ellipse's representation. When
   --  the system is numerically singular, or in OpenCV 4.14 and later
   --  (including 5.x) its solution is not meaningfully elliptical, OpenCV
   --  retries once with perturbed points and then falls back to its classic
   --  least-squares fitEllipseNoDirect. The perturbation is deterministic
   --  before OpenCV 4.12 and drawn from cv::theRNG in 4.12 and later,
   --  including 5.x, where every call also advances that generator. Fewer
   --  than five, or more than Integer_32'Last / 13, points raise
   --  OpenCV_Error, as for Fit_Ellipse_AMS. Degenerate sets may still produce
   --  a finite native result, including a zero-sized rectangle. Native
   --  failures and non-finite or negative size components raise OpenCV_Error.
   --  Points is unchanged.
   --  @param Points At least five points, with any bounds.
   --  @return The native rotated rectangle of the fitted ellipse.
   --  @exception OpenCV_Error Fewer than five or more than
   --    Integer_32'Last / 13 points, a non-finite or negative native field,
   --    or a failure reported by OpenCV.
   function Fit_Ellipse_Direct (Points : Contour) return OpenCV.Rotated_Rect;

   --  Fit_Ellipse, Fit_Ellipse_AMS, and Fit_Ellipse_Direct of a Float32
   --  point set: the same native algorithms, dispatch, fallbacks, random
   --  perturbation, point counts, and result representation as the integer
   --  overloads, applied to the binary32 coordinates without rounding.
   --  OpenCV's classic and AMS fits, which all three can reach, sum the
   --  coordinates in binary32 to find their mean. An overflowing sum would
   --  hand NaN to OpenCV's solver, which without LAPACK then takes time
   --  quadratic in the number of points, so the absolute X coordinates and
   --  the absolute Y coordinates must each sum to at most `2.0**103` (about
   --  1.0E+31); larger sets raise OpenCV_Error. Native failures and
   --  non-finite or negative size components raise OpenCV_Error. Points is
   --  unchanged.
   --  @param Points At least five points, with any bounds; every coordinate
   --    finite, within the coordinate-sum bound.
   --  @return The native rotated rectangle of the fitted ellipse.
   --  @exception OpenCV_Error Fewer than five or more than
   --    Integer_32'Last / 13 points, a NaN or infinite coordinate, a
   --    coordinate sum beyond the bound, a non-finite or negative native
   --    field, or a failure reported by OpenCV.
   function Fit_Ellipse
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect;

   --  Fit_Ellipse_AMS of a Float32 point set, with the integer overload's
   --  algorithm and fallbacks and the Float32 Fit_Ellipse rules for
   --  coordinates, counts and results. Points is unchanged.
   --  @param Points At least five points, with any bounds; every coordinate
   --    finite, within the coordinate-sum bound.
   --  @return The native rotated rectangle of the fitted ellipse.
   --  @exception OpenCV_Error Fewer than five or more than
   --    Integer_32'Last / 13 points, a NaN or infinite coordinate, a
   --    coordinate sum beyond the bound, a non-finite or negative native
   --    field, or a failure reported by OpenCV.
   function Fit_Ellipse_AMS
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect;

   --  Fit_Ellipse_Direct of a Float32 point set, with the integer
   --  overload's algorithm and fallbacks and the Float32 Fit_Ellipse rules
   --  for coordinates, counts and results. Points is unchanged.
   --  @param Points At least five points, with any bounds; every coordinate
   --    finite, within the coordinate-sum bound.
   --  @return The native rotated rectangle of the fitted ellipse.
   --  @exception OpenCV_Error Fewer than five or more than
   --    Integer_32'Last / 13 points, a NaN or infinite coordinate, a
   --    coordinate sum beyond the bound, a non-finite or negative native
   --    field, or a failure reported by OpenCV.
   function Fit_Ellipse_Direct
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect;

   --  Distance model of Fit_Line_2D (OpenCV DistanceTypes). L2 is orthogonal
   --  (total) least squares, solved in closed form as the principal axis of
   --  the points; L1, L12, Fair, Welsch, and Huber are robust M-estimators
   --  that OpenCV solves by iteratively reweighted least squares.
   --  @enum L2 DIST_L2: orthogonal least squares, in closed form.
   --  @enum L1 DIST_L1: robust, least absolute distances.
   --  @enum L12 DIST_L12: robust L1-L2 estimator.
   --  @enum Fair DIST_FAIR: robust, with constant C (default 1.3998).
   --  @enum Welsch DIST_WELSCH: robust, with constant C (default 2.9846).
   --  @enum Huber DIST_HUBER: robust, with constant C (default 1.345).
   type Line_Fit_Distance is (L2, L1, L12, Fair, Welsch, Huber);

   --  A fitted 2D line in native binary32 values. Direction is OpenCV's unit
   --  direction (vx, vy) and Point is OpenCV's point (x0, y0) on the line.
   --  @field Direction Unit direction vector (vx, vy), with OpenCV's sign.
   --  @field Point A point (x0, y0) on the line.
   type Fitted_Line_2D is record
      Direction : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      Point     : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
   end record;

   --  Fits a line to Points with the 2D form of cv::fitLine. Direction is a
   --  unit vector whose sign is OpenCV's; the opposite direction describes
   --  the same line, and no sign normalization is applied. Point is the
   --  centroid of Points for L2 and a weighted centroid for the robust
   --  distances. Parameter is the constant C of Fair, Welsch, and Huber;
   --  0.0 selects OpenCV's defaults 1.3998, 2.9846, and 1.345, and the other
   --  distances ignore it. A robust fit runs up to 20 restarts from subsets
   --  drawn by OpenCV's fixed-seed internal generator, each reweighting at
   --  most 30 times, and returns the best candidate it found by summed
   --  distance.
   --  A restart's reweighting stops early once the direction changes by
   --  less than Angle_Accuracy radians and each coordinate of Point by less
   --  than Radius_Accuracy; 0.0 selects OpenCV's defaults 0.01 and 1.0, and
   --  L2 ignores both. The Ada defaults of 0.01 follow OpenCV's documented
   --  recommendation. The accuracies end reweighting early; they do not
   --  bound the error of the result. Parameter, Radius_Accuracy, and
   --  Angle_Accuracy must be finite, nonnegative, and at most
   --  Float32_Value'Last; other values raise OpenCV_Error. OpenCV narrows
   --  them to binary32, so positive values too small for binary32 become 0.0
   --  and select the defaults. Robust results repeat for the same Points,
   --  but subsets are drawn by position, so reordering Points can change
   --  them slightly. OpenCV converts coordinates to binary32, exactly for
   --  magnitudes up to 2**24, and L2 squares them in binary32, so it loses
   --  accuracy for points far from the origin relative to their spread. At
   --  least one point is required; with fewer than two distinct points the
   --  direction is arbitrary. More than Integer_32'Last / 2 points raise
   --  OpenCV_Error, because OpenCV computes 2 * n in signed 32-bit
   --  arithmetic. Non-finite native results raise OpenCV_Error. Points is
   --  unchanged.
   --  @param Points At least one point, with any bounds.
   --  @param Distance The distance model; L2 by default.
   --  @param Parameter Constant C of Fair, Welsch and Huber, or 0.0 for
   --    OpenCV's default; ignored by the other distances.
   --  @param Radius_Accuracy Early-stop threshold for changes of Point, or
   --    0.0 for OpenCV's default 1.0; ignored by L2.
   --  @param Angle_Accuracy Early-stop threshold, in radians, for changes of
   --    Direction, or 0.0 for OpenCV's default 0.01; ignored by L2.
   --  @return The fitted line, every field finite.
   --  @exception OpenCV_Error No points, more than Integer_32'Last / 2
   --    points, a Parameter or accuracy that is not finite, negative or above
   --    Float32_Value'Last, a non-finite native field, or a failure reported
   --    by OpenCV.
   function Fit_Line_2D
     (Points          : Contour;
      Distance        : Line_Fit_Distance := L2;
      Parameter       : OpenCV.Float64_Value := 0.0;
      Radius_Accuracy : OpenCV.Float64_Value := 0.01;
      Angle_Accuracy  : OpenCV.Float64_Value := 0.01) return Fitted_Line_2D;

   --  Fit_Line_2D of a Float32 point set, with the integer overload's
   --  distances, parameters, scalar validation, and restarts, but
   --  fitting the binary32 coordinates themselves, so subpixel positions
   --  are kept. OpenCV's L2 fit sums the coordinates in binary64 but
   --  forms each product `X*X`, `Y*Y`, and `X*Y` in binary32 before
   --  summing, and does not first subtract the mean, so points far from the
   --  origin relative to their spread lose direction accuracy. A product
   --  above Float32_Value'Last overflows, and when only the X or only the Y
   --  products do, OpenCV returns a finite but wrong direction. So every
   --  coordinate must have magnitude at most `2.0**63`, which keeps the
   --  products finite; other sets raise OpenCV_Error. Non-finite native
   --  results, and the all-zero line with which OpenCV's robust fit starts
   --  and which it keeps when no candidate has a finite error, also raise
   --  OpenCV_Error. Points is unchanged.
   --  L2 accepts the ordinary C ABI count limit, Integer_32'Last. Robust
   --  distances (L1, L12, Fair, Welsch, Huber) require at most
   --  Integer_32'Last / 2 points: native fitLine allocates `count*2` floats
   --  after the L2 early return. Larger counts raise OpenCV_Error.
   --  @param Points At least one point, with any bounds; every coordinate
   --    finite and of magnitude at most `2.0**63`.
   --  @param Distance The distance model; L2 by default.
   --  @param Parameter Constant C of Fair, Welsch and Huber, or 0.0 for
   --    OpenCV's default; ignored by the other distances.
   --  @param Radius_Accuracy Early-stop threshold for changes of Point, or
   --    0.0 for OpenCV's default 1.0; ignored by L2.
   --  @param Angle_Accuracy Early-stop threshold, in radians, for changes of
   --    Direction, or 0.0 for OpenCV's default 0.01; ignored by L2.
   --  @return The fitted line, every field finite and Direction nonzero.
   --  @exception OpenCV_Error No points, too many points for the distance, a
   --    NaN, infinite or too large coordinate, a Parameter or accuracy that
   --    is not finite, negative or above Float32_Value'Last, a non-finite
   --    native field, an all-zero native direction, or a failure reported
   --    by OpenCV.
   function Fit_Line_2D
     (Points          : Float32_Point_Array;
      Distance        : Line_Fit_Distance := L2;
      Parameter       : OpenCV.Float64_Value := 0.0;
      Radius_Accuracy : OpenCV.Float64_Value := 0.01;
      Angle_Accuracy  : OpenCV.Float64_Value := 0.01) return Fitted_Line_2D;

   --  Position of a rotated-rectangle vertex in native order.
   type Box_Vertex_Index is range 1 .. 4;

   --  The four vertices of a rotated rectangle, in native order.
   type Box_Vertices is array (Box_Vertex_Index) of OpenCV.Float32_Point;

   --  Converts Box to four native CV_32F rectangle vertices. Vertices are
   --  returned in the active OpenCV backend's native order without rounding,
   --  reordering, or normalization. OpenCV 4.x and 5.0 compute them with
   --  RotatedRect::points, a fixed corner sequence attached to the rectangle,
   --  so the starting vertex moves as Angle_Degrees changes. OpenCV 4.12+
   --  and 5.0 document a start at the greatest-Y vertex, rightmost on a tie,
   --  but the implementation does not provide that for arbitrary rectangles;
   --  an unrotated rectangle, for example, starts at its greatest-Y leftmost
   --  vertex. Portable callers must not depend on the starting vertex. Box
   --  is unchanged.
   --  @param Box The rotated rectangle; every field must be finite.
   --  @return The four vertices, consecutive around the rectangle, from a
   --    native starting vertex; every coordinate finite.
   --  @exception OpenCV_Error A non-finite field of Box, a non-finite native
   --    vertex, or a failure reported by OpenCV.
   function Box_Points (Box : OpenCV.Rotated_Rect) return Box_Vertices;

   --  Intersection of two convex polygons. Area is OpenCV's nonnegative
   --  binary32 intersection area, and Vertices is the native binary32
   --  intersection polygon in native order without normalization. Vertices
   --  is indexed 1 .. Vertex_Count, because its bounds follow the
   --  discriminant. An empty intersection has Vertex_Count = 0 and Area 0.0.
   --  @field Vertex_Count Number of intersection vertices returned.
   --  @field Area Nonnegative, finite binary32 area of the intersection.
   --  @field Vertices The intersection vertices, indexed 1 .. Vertex_Count.
   type Convex_Polygon_Intersection (Vertex_Count : Natural) is record
      Area     : OpenCV.Float32_Value;
      Vertices : Float32_Point_Array (1 .. Vertex_Count);
   end record;

   --  Intersects convex polygons Left and Right with
   --  cv::intersectConvexConvex. Left and Right must each be a simple,
   --  strictly convex polygon of at least three vertices, traversed once in
   --  either direction: every vertex must be a vertex of its convex hull,
   --  visited in hull order, as Convex_Hull_Indices reports it. Repeated or
   --  collinear vertices, self-intersecting stars, and repeated traversals
   --  raise OpenCV_Error; Is_Convex, whose result OpenCV leaves undefined
   --  for non-simple contours, may accept the latter two. OpenCV does not
   --  check any of this, and OpenCV 4.x releases before 4.11 can overflow an
   --  internal buffer on such input. Every vertex coordinate must also lie
   --  in `-2**24 .. 2**24`, where OpenCV's binary32 conversion is exact, and
   --  the X span and the Y span of Left and Right together must each be at
   --  most `2**24`, or `2**25` when every coordinate is even, so that every
   --  binary32 coordinate difference is exact too; other polygons raise
   --  OpenCV_Error.
   --  With rounded differences OpenCV's orientation tests can disagree, and
   --  OpenCV 4.6 and 4.10 can then write past their result buffer even for
   --  valid convex polygons, such as two hexagons spanning about 3.1E+7. The
   --  rule applies on every release, so that the accepted inputs do not
   --  depend on the OpenCV version. When one polygon lies strictly inside
   --  the other, so that their boundaries do not touch, Handle_Nested True
   --  returns the inner polygon and its area, and Handle_Nested False
   --  returns an empty result. OpenCV documents that polygons sharing an
   --  edge, or with a vertex on the other's edge, are not treated as nested
   --  and are intersected regardless of Handle_Nested. Polygons that touch
   --  only from outside return zero or near-zero Area with the contact
   --  points, possibly repeated as OpenCV emits them. OpenCV
   --  4.6, 4.10, and 5.0 also emit an internal (FLT_MAX, FLT_MAX) sentinel as
   --  the first or last vertex of some disjoint and contact results; it is
   --  not a vertex and is omitted. The result has at most Left'Length +
   --  Right'Length vertices. OpenCV 4.11+ and 5.x report an intersection
   --  that did not converge with a negative area; that raises OpenCV_Error.
   --  Left and Right are unchanged.
   --  @param Left First simple, strictly convex polygon, with any bounds and
   --    at least three vertices in the coordinate range above.
   --  @param Right Second polygon, with the same requirements.
   --  @param Handle_Nested Whether a polygon strictly inside the other is
   --    returned as the intersection (True) or gives an empty result.
   --  @return The intersection polygon and its area, with at most
   --    Left'Length + Right'Length vertices.
   --  @exception OpenCV_Error Fewer than three vertices, more than
   --    `(Integer_32'Last - 4) / 2` vertices together (the native scratch
   --    buffer size), a polygon that is not simple and strictly convex,
   --    coordinates or joint spans beyond the exact limits, a negative
   --    (non-converged) or non-finite native area, a non-finite native
   --    vertex, or a failure reported by OpenCV.
   function Intersect_Convex_Polygons
     (Left, Right : Contour; Handle_Nested : Boolean := True)
      return Convex_Polygon_Intersection;

   --  Intersect_Convex_Polygons of Float32 polygons, with the same rules for
   --  convexity, nesting, contact, the sentinel, and the result, computed by
   --  OpenCV's CV_32F path. On valid convex binary32 polygons whose
   --  coordinate differences round, OpenCV 4.6 and 4.10 can corrupt their
   --  heap (probed with two polygons of about 60 vertices), and 4.11 and
   --  later can report non-convergence. Accepted input therefore keeps every
   --  native test exact: for some K in -8 .. 6, every coordinate of Left and
   --  Right must be an integer multiple of `2.0**K`, and Left and Right
   --  divided by `2.0**K` must be integer polygons that the integer overload
   --  accepts, so of magnitude at most `2.0**(24 + K)` and of joint X and Y
   --  spans at most `2.0**(24 + K)`, or twice that when every coordinate is
   --  a multiple of `2.0**(K + 1)`. Examples are integer polygons within
   --  those limits and polygons whose coordinates are multiples of 0.25 with
   --  magnitude and joint spans at most 4194304.0. Other finite polygons,
   --  including most with decimal fractions such as 0.1, raise OpenCV_Error,
   --  as do non-finite coordinates. K >= -8 keeps every nonzero native
   --  orientation above OpenCV's absolute 1.0E-5 tolerance, and K <= 6 keeps
   --  coordinate magnitudes at most `2.0**30`, below the `2.0**31` at which
   --  the cvRound in OpenCV's nested-polygon test overflows.
   --  On accepted input OpenCV returns the result it computes for the
   --  integer polygons, scaled by `2.0**K`: both run the same binary32 and
   --  binary64 operations, which commute with power-of-two scaling in this
   --  range. The rule applies on every release, so that the accepted inputs
   --  do not depend on the OpenCV version. Left and Right are unchanged.
   --  @param Left First polygon, with any bounds and at least three finite
   --    vertices, on one binary grid with Right as described above.
   --  @param Right Second polygon, with the same requirements.
   --  @param Handle_Nested Whether a polygon strictly inside the other is
   --    returned as the intersection (True) or gives an empty result.
   --  @return The intersection polygon and its area, with at most
   --    Left'Length + Right'Length vertices.
   --  @exception OpenCV_Error Fewer than three vertices, too many vertices
   --    together, a NaN or infinite coordinate, coordinates on no accepted
   --    grid, scaled polygons that the integer overload would reject, a
   --    negative (non-converged) or non-finite native area, a non-finite
   --    native vertex, or a failure reported by OpenCV.
   function Intersect_Convex_Polygons
     (Left, Right : Float32_Point_Array; Handle_Nested : Boolean := True)
      return Convex_Polygon_Intersection;

   --  Opt-in extension of the Float32 intersection to ordinary fractional
   --  polygons such as coordinates near 0.1, which the overload above
   --  rejects. It never calls OpenCV's intersectConvexConvex: on every
   --  supported OpenCV release it runs the same private hardened copy of the
   --  bounded OpenCV 4.11 algorithm (with the 4.12 binary64 segment
   --  expressions). Its nested-polygon path still calls the installed
   --  OpenCV's pointPolygonTest and contourArea. Seven exact-tag OpenCV
   --  releases, 4.6.0 and 4.10.0 through 5.0.0, gave bit-identical results
   --  on the tested corpus only; identical output on every input or on
   --  future releases is not guaranteed. The existing overloads are
   --  unchanged.
   --
   --  Accepted input, for each of Left and Right (either winding, any lower
   --  bound): 3 .. 4096 vertices (more is rejected before any allocation);
   --  every coordinate finite with magnitude at most 2.0**30; strictly
   --  convex and traversed once, meaning that every
   --  other vertex lies provably strictly on one side of the line through
   --  each edge, by an orientation above 1.0E-4 (ten times OpenCV's absolute
   --  1.0E-5 orientation tolerance). Duplicate vertices, redundant collinear
   --  vertices, concave polygons, bowties, stars, repeated traversals, and
   --  polygons with features below that conditioning limit raise
   --  OpenCV_Error. The conditioning limit is a policy, not a proof that
   --  every accepted pair converges: an intersection that does not
   --  converge, or that needs a value Float32 cannot represent, also raises
   --  OpenCV_Error and returns no partial result. The result is not an exact
   --  intersection for ill-conditioned polygons.
   --
   --  Nesting, contact and Handle_Nested follow the overload above. The
   --  result has at most Left'Length + Right'Length vertices, in the order
   --  the private implementation produces (not normalized, sorted or
   --  deduplicated), without OpenCV's internal sentinel, with Area finite
   --  and nonnegative. Polygons that only touch can give one, two or three
   --  vertices and Area 0.0; those vertices are contact points and need not
   --  form a polygon. An empty result has no vertices and Area 0.0.
   --  Left and Right are unchanged. Strict convexity is checked by the C++
   --  layer, so direct C ABI callers cannot bypass it.
   --  @param Left First polygon: 3 .. 4096 finite vertices of magnitude at
   --    most `2.0**30`, strictly convex and traversed once, with any bounds.
   --  @param Right Second polygon, with the same requirements.
   --  @param Handle_Nested Whether a polygon strictly inside the other is
   --    returned as the intersection (True) or gives an empty result.
   --  @return The intersection, with at most Left'Length + Right'Length
   --    vertices and a finite, nonnegative Area.
   --  @exception OpenCV_Error Fewer than three or more than 4096 vertices in
   --    either polygon, a NaN, infinite or too large coordinate, a polygon
   --    that is not strictly convex beyond the conditioning limit, an
   --    intersection that does not converge or needs a value binary32
   --    cannot represent, or another failure of the private implementation.
   function Intersect_Convex_Polygons_Extended_Float32
     (Left, Right : Float32_Point_Array; Handle_Nested : Boolean := True)
      return Convex_Polygon_Intersection;

   --  OpenCV's rotated-rectangle intersection classification:
   --  INTERSECT_NONE, INTERSECT_PARTIAL, and INTERSECT_FULL. OpenCV documents
   --  INTERSECT_FULL as one rectangle lying wholly within the other.
   --  @enum No_Intersection INTERSECT_NONE: the rectangles do not
   --    intersect.
   --  @enum Partial_Intersection INTERSECT_PARTIAL: a partial intersection,
   --    neither rectangle containing the other.
   --  @enum Full_Intersection INTERSECT_FULL: one rectangle lies wholly
   --    within the other.
   type Rectangle_Intersection_Kind is
     (No_Intersection, Partial_Intersection, Full_Intersection);

   --  OpenCV 4.6, 4.10, and 5.0 reduce the region to at most eight vertices.
   subtype Rectangle_Intersection_Vertex_Count is Natural range 0 .. 8;

   --  Vertices is indexed 1 .. Vertex_Count.
   --  @field Vertex_Count Number of intersection vertices, 0 .. 8.
   --  @field Kind OpenCV's classification of the intersection.
   --  @field Vertices The intersection region's vertices in native order.
   type Rotated_Rectangle_Intersection
     (Vertex_Count : Rectangle_Intersection_Vertex_Count := 0)
   is record
      Kind     : Rectangle_Intersection_Kind := No_Intersection;
      Vertices : Float32_Point_Array (1 .. Vertex_Count);
   end record;

   --  Intersects Left and Right with cv::rotatedRectangleIntersection. Kind
   --  is OpenCV's classification, and Vertices is the native binary32
   --  intersection region, at most eight points in native order without
   --  normalization. No_Intersection has no vertices. A rectangle whose
   --  width or height is zero or negative intersects nothing. Rectangles
   --  that only touch can be reported with one or two contact vertices, and
   --  OpenCV 4.6 uses different numerical tolerances from 4.10 and 5.0 for
   --  such near-degenerate contacts. Every Left and Right field must be
   --  finite; non-finite fields, and non-finite native vertices, raise
   --  OpenCV_Error. Left and Right are unchanged.
   --  @param Left First rotated rectangle; every field must be finite.
   --  @param Right Second rotated rectangle; every field must be finite.
   --  @return The classification and at most eight intersection vertices.
   --  @exception OpenCV_Error A non-finite field, a non-finite native vertex,
   --    or a failure reported by OpenCV.
   function Intersect_Rotated_Rectangles
     (Left, Right : OpenCV.Rotated_Rect) return Rotated_Rectangle_Intersection;

   --  Approximates Points with Douglas-Peucker. Epsilon is the maximum
   --  distance between the original curve and the result and must be
   --  in the range 0.0 <= Epsilon < 1.0E30. Closed connects the last
   --  vertex to the first. The result is an Ada-owned contour. Empty
   --  input returns an empty contour. Points is unchanged. OpenCV 4.x
   --  measures each point's distance to the line through a chord, while
   --  OpenCV 5.x measures it to the chord itself, so the two can keep
   --  different vertices.
   --  @param Points Curve vertices in order, with any bounds; may be empty.
   --  @param Epsilon Approximation accuracy, the maximum distance between
   --    the curve and its approximation; `0.0 <= Epsilon < 1.0E30`.
   --  @param Closed True when the curve is closed (the last vertex connects
   --    to the first).
   --  @return Points kept by cv::approxPolyDP, in order: zero-based, or the
   --    null range 1 .. 0 for empty input.
   --  @exception OpenCV_Error An Epsilon outside its range or NaN, more than
   --    Integer_32'Last points, or a failure reported by OpenCV.
   function Approximate_Curve
     (Points : Contour; Epsilon : OpenCV.Float64_Value; Closed : Boolean)
      return Contour;

   --  Approximate_Curve of a Float32 point set, with the same Epsilon,
   --  Closed, and version semantics. The result is an Ada-owned Float32
   --  point set of input points in input order, cyclically for a closed
   --  curve, whose start OpenCV chooses; it is zero-based, and empty input
   --  returns the null range 1 .. 0. OpenCV takes coordinate differences
   --  in binary32. If one overflowed, its distances would become NaN, and
   --  OpenCV 4.6, 4.10, and 5.0 would then drop points at any distance or,
   --  for Epsilon 0.0, read outside the curve without terminating. So the X
   --  span and the Y span of Points, computed in binary64, must each be at
   --  most Float32_Value'Last; wider sets raise OpenCV_Error. OpenCV 5.x
   --  also squares some differences in binary32, so beyond about 1.8E+19
   --  it can keep vertices that 4.x drops. Points is unchanged.
   --  @param Points Curve vertices in order, with any bounds; every
   --    coordinate must be finite. May be empty.
   --  @param Epsilon Approximation accuracy, the maximum distance between
   --    the curve and its approximation; `0.0 <= Epsilon < 1.0E30`.
   --  @param Closed True when the curve is closed (the last vertex connects
   --    to the first).
   --  @return Points kept by OpenCV, in input order.
   --  @exception OpenCV_Error An Epsilon outside its range or NaN, a NaN or
   --    infinite coordinate, an X or Y span above Float32_Value'Last, more
   --    than Integer_32'Last points, a non-finite native point, or a failure
   --    reported by OpenCV.
   function Approximate_Curve
     (Points  : Float32_Point_Array;
      Epsilon : OpenCV.Float64_Value;
      Closed  : Boolean) return Float32_Point_Array;

   --  Minimal upright axis-aligned bounding rectangle of Points, computed by
   --  cv::boundingRect. Integer extent is inclusive, so Width = X_Max -
   --  X_Min + 1 and Height = Y_Max - Y_Min + 1. Empty input returns (0, 0,
   --  0, 0). Origins may be negative because OpenCV.Rect uses signed
   --  Point_Coordinate X/Y. Inclusive extents that cannot be represented as
   --  signed 32-bit width or height raise OpenCV.OpenCV_Error. Points is
   --  unchanged.
   --  @param Points The point set, with any bounds; may be empty.
   --  @return The bounding rectangle, with nonnegative Width and Height.
   --  @exception OpenCV_Error An extent beyond Integer_32'Last, more than
   --    Integer_32'Last points, or a failure reported by OpenCV.
   function Bounding_Rect (Points : Contour) return OpenCV.Rect;

   --  Minimal upright integer rectangle containing a Float32 point set, as
   --  OpenCV computes it from the floors of the extreme coordinates:
   --  X = Floor (Min X), Width = Floor (Max X) - X + 1, and likewise Y and
   --  Height. Every point P therefore satisfies X <= P.X < X + Width. For
   --  integer-valued coordinates the result is the integer overload's.
   --  OpenCV converts the floors to signed 32-bit integers, which is
   --  undefined outside `-2.0**31 .. 2.0**31`, so every coordinate must be
   --  at least `-2.0**31` and less than `2.0**31`, and Width and Height must
   --  not exceed Integer_32'Last; other inputs raise OpenCV_Error. Empty
   --  input returns (0, 0, 0, 0). Points is unchanged.
   --  @param Points The point set, with any bounds; every coordinate must be
   --    finite and in the range above. May be empty.
   --  @return The integer rectangle, with nonnegative Width and Height.
   --  @exception OpenCV_Error A NaN, infinite or out-of-range coordinate, an
   --    extent beyond Integer_32'Last, more than Integer_32'Last points, or
   --    a failure reported by OpenCV.
   function Bounding_Rect (Points : Float32_Point_Array) return OpenCV.Rect;

   --  Tests whether Points is a convex contour with cv::isContourConvex.
   --  The contour is expected to be simple (non-self-intersecting); OpenCV
   --  leaves the result for non-simple contours undefined. Convexity does
   --  not depend on winding direction. Empty, one-point, two-point, and
   --  collinear contours are not convex. Points is unchanged.
   --  @param Points Contour vertices in traversal order, with any bounds;
   --    may be empty.
   --  @return True when OpenCV finds the contour convex.
   --  @exception OpenCV_Error More than Integer_32'Last points, or a failure
   --    reported by OpenCV.
   function Is_Convex (Points : Contour) return Boolean;

   --  Is_Convex of a Float32 point set. Unlike the integer-coordinate test,
   --  OpenCV computes each edge's coordinate differences and the cross
   --  products of consecutive edges in binary32, so nearly collinear
   --  vertices are classified by rounded products, which can differ from
   --  exact geometry. So that no difference or product overflows, the X
   --  span and the Y span of Points, computed in binary64, must each be at
   --  most Float32_Value'Last and their product at most
   --  Float32_Value'Last / 2; other sets raise OpenCV_Error. Points is
   --  unchanged.
   --  @param Points Contour vertices in traversal order, with any bounds;
   --    every coordinate must be finite. May be empty.
   --  @return True when OpenCV finds the contour convex.
   --  @exception OpenCV_Error A NaN or infinite coordinate, spans or a span
   --    product beyond the limits above, more than Integer_32'Last points,
   --    or a failure reported by OpenCV.
   function Is_Convex (Points : Float32_Point_Array) return Boolean;

   --  OpenCV's Hu-moment shape comparison methods. Each compares the
   --  log-scaled Hu invariants `m = sign (h) * log |h|` of the two shapes,
   --  A (Left) and B (Right).
   --  @enum Reciprocal_Log_Difference CONTOURS_MATCH_I1: the sum of
   --    `|1/mA - 1/mB|`.
   --  @enum Log_Difference CONTOURS_MATCH_I2: the sum of `|mA - mB|`.
   --  @enum Relative_Log_Difference CONTOURS_MATCH_I3: the largest
   --    `|(mA - mB) / mA|`, so Left supplies the denominator.
   type Shape_Match_Method is
     (Reciprocal_Log_Difference, Log_Difference, Relative_Log_Difference);

   --  Compares Left and Right using OpenCV Hu-moment matching
   --  (cv::matchShapes). Lower scores indicate more similar shapes;
   --  identical or equivalent contours normally approach zero, though
   --  floating-point evaluation can leave a tiny residual. Relative
   --  comparison is directional: the Left contour supplies the
   --  denominator. The unused native OpenCV parameter is not exposed.
   --  Left and Right are unchanged. If native matching produces a
   --  non-finite value that cannot be represented by Float64_Value,
   --  Match_Shapes raises OpenCV_Error.
   --  @param Left First contour, with any bounds; for
   --    Relative_Log_Difference, the reference shape.
   --  @param Right Second contour, with any bounds.
   --  @param Method The comparison formula.
   --  @return The nonnegative, finite dissimilarity score.
   --  @exception OpenCV_Error A non-finite native score, more than
   --    Integer_32'Last points in either contour, or a failure reported by
   --    OpenCV.
   function Match_Shapes
     (Left, Right : Contour; Method : Shape_Match_Method)
      return OpenCV.Float64_Value;

   --  Match_Shapes of two Float32 point sets, compared through their OpenCV
   --  moments as computed by the Float32 Compute_Moments and their Hu
   --  moments. OpenCV's matching silently skips non-finite Hu moments, so
   --  non-finite moments or Hu moments of either set raise OpenCV_Error. A
   --  set whose area is so small that its moments are all 0.0 has all-zero
   --  Hu moments. OpenCV scores two sets with all-zero Hu moments 0.0, and
   --  such a set against one with a nonzero Hu moment Float64_Value'Last.
   --  Left and Right are unchanged.
   --  @param Left First point set, with any bounds; every coordinate must be
   --    finite. For Relative_Log_Difference, the reference shape.
   --  @param Right Second point set, with any bounds; every coordinate must
   --    be finite.
   --  @param Method The comparison formula.
   --  @return The nonnegative, finite dissimilarity score.
   --  @exception OpenCV_Error A NaN or infinite coordinate, non-finite
   --    moments or Hu moments of either set, a non-finite native score, more
   --    than Integer_32'Last points, or a failure reported by OpenCV.
   function Match_Shapes
     (Left, Right : Float32_Point_Array; Method : Shape_Match_Method)
      return OpenCV.Float64_Value;

   --  Where a query point lies relative to a polygon, as reported by
   --  cv::pointPolygonTest without distance measurement.
   --  @enum Outside_Contour Outside the polygon (native result -1).
   --  @enum On_Contour_Boundary On an edge or vertex (native result 0).
   --  @enum Inside_Contour Strictly inside the polygon (native result +1).
   type Contour_Point_Location is
     (Outside_Contour, On_Contour_Boundary, Inside_Contour);

   --  Classifies Query relative to the polygon defined by Points, by
   --  cv::pointPolygonTest. Query coordinates are binary32 and may be
   --  fractional. Empty contours are Outside_Contour. For nonempty Points,
   --  OpenCV rounds Query to a signed 32-bit integer point, so a Query
   --  coordinate that is not finite, or not in `-2.0**31 .. 2.0**31`
   --  (excluding `2.0**31`), raises OpenCV_Error. For an integer-valued
   --  Query, OpenCV classifies in signed 32-bit integer arithmetic, and
   --  input whose coordinate differences on the edges it examines would
   --  overflow raises OpenCV_Error. Points is unchanged.
   --  @param Points Polygon vertices in traversal order, with any bounds;
   --    may be empty.
   --  @param Query The point to classify; ignored when Points is empty.
   --  @return The location of Query.
   --  @exception OpenCV_Error For nonempty Points, a Query outside the
   --    range above, overflowing native integer arithmetic, more than
   --    Integer_32'Last points, or a failure reported by OpenCV.
   function Locate_Point
     (Points : Contour; Query : OpenCV.Float32_Point)
      return Contour_Point_Location;

   --  Signed distance from Query to the nearest edge of Points, by
   --  cv::pointPolygonTest with distance measurement. Positive is inside,
   --  zero is on the boundary, and negative is outside. Empty contours
   --  follow OpenCV and return the largest finite negative Float64_Value.
   --  Points is unchanged. If native computation produces a non-finite
   --  value that cannot be represented by Float64_Value,
   --  Signed_Distance_To_Contour raises OpenCV_Error.
   --  @param Points Polygon vertices in traversal order, with any bounds;
   --    may be empty.
   --  @param Query The point to measure; for nonempty Points, its
   --    coordinates must be finite and in the cvRound range of Locate_Point.
   --  @return The signed binary64 distance, or -Float64_Value'Last for empty
   --    Points.
   --  @exception OpenCV_Error For nonempty Points, a Query outside that
   --    range; a non-finite native distance, more than Integer_32'Last
   --    points, or a failure reported by OpenCV.
   function Signed_Distance_To_Contour
     (Points : Contour; Query : OpenCV.Float32_Point)
      return OpenCV.Float64_Value;

   --  Locate_Point and Signed_Distance_To_Contour for a Float32 polygon,
   --  with fractional edges and Query. Points and Query must be finite,
   --  even when Points is empty; for empty Points, Query is Outside_Contour
   --  at distance -Float64_Value'Last. OpenCV computes coordinate
   --  differences in binary32 and the crossing and distance tests in
   --  binary64. So that no difference overflows, the X span and the Y span
   --  of Points, computed in binary64, must each be at most
   --  Float32_Value'Last. For nonempty Points, OpenCV also rounds Query to a
   --  signed 32-bit integer point on every path, so each Query coordinate
   --  must be at least `-2.0**31` and less than `2.0**31`. Other inputs raise
   --  OpenCV_Error. OpenCV starts its nearest-edge search at a squared
   --  distance of FLT_MAX and cannot report a farther edge, so a distance of
   --  at least Sqrt (Float32_Value'Last), about 1.8447E+19, raises
   --  OpenCV_Error rather than being clamped; integer contours cannot reach
   --  it. Points is unchanged.
   --  @param Points Polygon vertices in traversal order, with any bounds;
   --    every coordinate must be finite. May be empty.
   --  @param Query The point to classify; always required to be finite.
   --  @return The location of Query.
   --  @exception OpenCV_Error A NaN or infinite coordinate of Points or
   --    Query, an X or Y span above Float32_Value'Last, for nonempty Points
   --    a Query outside the cvRound range, more than Integer_32'Last points,
   --    or a failure reported by OpenCV.
   function Locate_Point
     (Points : Float32_Point_Array; Query : OpenCV.Float32_Point)
      return Contour_Point_Location;

   --  Signed distance from Query to the nearest edge of a Float32 polygon:
   --  positive inside, zero on the boundary, negative outside. Points and
   --  Query must be finite, even when Points is empty; for empty Points the
   --  result is -Float64_Value'Last. The span and Query rules are those of
   --  the Float32 Locate_Point above. OpenCV starts its nearest-edge search
   --  at a squared distance of FLT_MAX and cannot report a farther edge, so
   --  for nonempty Points a distance of at least Sqrt (Float32_Value'Last),
   --  about 1.8447E+19, raises OpenCV_Error rather than being clamped.
   --  Points is unchanged.
   --  @param Points Polygon vertices in traversal order, with any bounds;
   --    every coordinate must be finite. May be empty.
   --  @param Query The point to measure; always required to be finite.
   --  @return The signed binary64 distance, below the search limit in
   --    magnitude, or -Float64_Value'Last for empty Points.
   --  @exception OpenCV_Error A NaN or infinite coordinate of Points or
   --    Query, an X or Y span above Float32_Value'Last, for nonempty Points
   --    a Query outside the cvRound range or a distance at the search limit,
   --    a non-finite native distance, more than Integer_32'Last points, or a
   --    failure reported by OpenCV.
   function Signed_Distance_To_Contour
     (Points : Float32_Point_Array; Query : OpenCV.Float32_Point)
      return OpenCV.Float64_Value;

   --  A circle in native binary32 values.
   --  @field Center The circle's center.
   --  @field Radius The circle's nonnegative radius.
   type Enclosing_Circle is record
      Center : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      Radius : OpenCV.Float32_Value := 0.0;
   end record;

   --  Smallest circle enclosing Points, by cv::minEnclosingCircle. Center
   --  and Radius are binary32 OpenCV results, including the native EPS added
   --  to radii. Empty contours return center (0, 0) and radius 0. One-point
   --  contours return that point as Center and the native EPS as Radius.
   --  Points is unchanged. Integer contours whose native signed-32-bit pair
   --  addition or subtraction would overflow raise OpenCV_Error. If a
   --  native center or radius component is non-finite, or if a successful
   --  native radius is negative, Minimum_Enclosing_Circle raises
   --  OpenCV_Error. OpenCV finds the circle through three points from
   --  binary32 dot products of absolute coordinates, so points far from the
   --  origin relative to their spread can get a circle that misses one of
   --  them: OpenCV 4.10 leaves a vertex of a triangle with sides of about 8
   --  near (10_000_000, 10_000_000) 41% of the radius outside. The native
   --  circle is returned as computed.
   --  @param Points The point set, with any bounds; may be empty.
   --  @return The native circle, every field finite and Radius nonnegative.
   --  @exception OpenCV_Error Coordinates whose native pair arithmetic would
   --    overflow, a non-finite or negative native field, more than
   --    Integer_32'Last points, or a failure reported by OpenCV.
   function Minimum_Enclosing_Circle
     (Points : Contour) return Enclosing_Circle;

   --  Minimum_Enclosing_Circle of a Float32 point set, with the same empty,
   --  one-point, and result rules, and the same loss of precision far from
   --  the origin. OpenCV works in binary32 with absolute tolerances: it adds
   --  1.0E-4 to radii and treats three points as collinear when its binary32
   --  cross product of their edges is at most 1.0E-4 in magnitude. Integer
   --  triangles never fall below that bound, but small Float32 sets can. In
   --  the tested OpenCV 4.6, 4.10, and 5.0 equilateral-triangle fixture with
   --  sides of 0.01, one vertex lies about 0.0036 outside the circle. The
   --  native circle is returned as computed. OpenCV's circle through three
   --  points also forms binary32 products of three coordinates; when they
   --  overflow, OpenCV 4.x keeps a previous circle that misses a point. So
   --  for three or more points every coordinate must have magnitude at most
   --  `2.0**41`, keeping those products finite; other such sets raise
   --  OpenCV_Error. Zero, one, and two points cannot reach the three-point
   --  construction and have no such magnitude limit. Coordinates and native
   --  center/radius must still be finite for every cardinality, or raise
   --  OpenCV_Error. OpenCV 5.x shuffles more than ten points, with a
   --  generator seeded from the points, before its incremental search, and
   --  keeps the previous circle for such a collinear triple where 4.x uses
   --  the triple's farthest pair; results can therefore differ between
   --  them, in rounding or, near degeneracy, more. Points is unchanged.
   --  @param Points The point set, with any bounds; every coordinate finite,
   --    and of magnitude at most `2.0**41` when there are three or more.
   --  @return The native circle, every field finite and Radius nonnegative.
   --  @exception OpenCV_Error A NaN or infinite coordinate, a coordinate
   --    beyond the magnitude limit, a non-finite or negative native field,
   --    more than Integer_32'Last points, or a failure reported by OpenCV.
   function Minimum_Enclosing_Circle
     (Points : Float32_Point_Array) return Enclosing_Circle;

   --  Position of a triangle vertex in native order.
   type Triangle_Vertex_Index is range 1 .. 3;

   --  The three vertices of a triangle, in native order.
   type Triangle_Vertices is
     array (Triangle_Vertex_Index) of OpenCV.Float32_Point;

   --  An enclosing triangle and its area, as OpenCV computes them.
   --  @field Area The nonnegative, finite binary64 area OpenCV reports.
   --  @field Vertices The three binary32 vertices in native order.
   type Enclosing_Triangle is record
      Area     : OpenCV.Float64_Value := 0.0;
      Vertices : Triangle_Vertices := (others => (X => 0.0, Y => 0.0));
   end record;

   --  Smallest-area triangle enclosing Points, by cv::minEnclosingTriangle.
   --  Area is OpenCV's native double result. Vertices are the three native
   --  CV_32F triangle vertices in native order; callers must not assume a
   --  cyclic start or winding. Fractional and negative coordinates are
   --  preserved. Empty input is rejected by OpenCV. One-point, two-point,
   --  collinear, and repeated-point inputs may return repeated vertices and
   --  zero area. Points is unchanged. Inputs that would overflow native
   --  integer convex-hull arithmetic raise OpenCV.OpenCV_Error. If a native
   --  area or vertex component is non-finite, or if a successful native area
   --  is negative, Minimum_Enclosing_Triangle raises OpenCV.OpenCV_Error.
   --
   --  OpenCV's search loops in 4.6, 4.10, and 5.0 have no iteration bound
   --  and can fail to return for some nearly degenerate hulls, such as the
   --  long thin quadrilateral (0, 0), (1, 0), (100001, 1), (100000, 1), or
   --  nearly collinear vertices; the binding cannot detect those inputs in
   --  advance, nor interrupt a native call that does not return. There is no
   --  Float32 overload: binary32 point sets add more such inputs, including
   --  any hull smaller than OpenCV's absolute tolerance, and signed zeros
   --  that make OpenCV divide by zero.
   --  @param Points A nonempty point set, with any bounds.
   --  @return The native triangle and its area, every value finite and the
   --    area nonnegative, when the native search returns.
   --  @exception OpenCV_Error Empty input or another failure reported by
   --    OpenCV, coordinates that would overflow native hull arithmetic, more
   --    than Integer_32'Last - 2 points (native hull allocation), or a
   --    non-finite or negative native value.
   function Minimum_Enclosing_Triangle
     (Points : Contour) return Enclosing_Triangle;

   --  Get_Rotation_Matrix_2D generates a 2x3 Float64 C1 affine transform
   --  that rotates around Center and applies an isotropic Scale. This
   --  function does not warp an image; the returned Mat may be passed
   --  directly to affine warping operations such as
   --  OpenCV.Image_Processing.Warp_Affine. Angle may be supplied in
   --  Degrees or Radians. Degrees is the default because that matches
   --  cv::getRotationMatrix2D. Radians are reduced modulo a full turn
   --  and converted to degrees in Ada before the C ABI is called.
   --  Positive angles are counter-clockwise according to OpenCV's
   --  image-coordinate convention (origin at the top-left). The rotation
   --  center maps to itself. Scale defaults to 1.0. Finite zero and
   --  negative Scale values are mathematically defined by OpenCV and
   --  remain accepted. Center.X, Center.Y, Angle, and Scale must all be
   --  finite; NaN and +/-Infinity raise OpenCV.OpenCV_Error. The returned
   --  Mat always has Rows = 2, Columns = 3, Depth = Float64, and
   --  Channels = 1, and owns ordinary Core Mat lifetime. Contract
   --  violations and failures reported by OpenCV raise OpenCV.OpenCV_Error.
   --  @param Center The rotation center, which maps to itself; finite.
   --  @param Angle The rotation angle in Units, positive counter-clockwise
   --    in OpenCV's convention; finite. It is reduced modulo a full turn in
   --    Ada, in either unit, before the native call.
   --  @param Scale The isotropic scale factor; finite, 1.0 by default.
   --  @param Units Degrees (the default, as in OpenCV) or Radians.
   --  @return A new 2x3 Float64, one-channel Mat holding the transform.
   --  @exception OpenCV_Error A non-finite Center coordinate, Angle or
   --    Scale, a native coefficient that is not finite, or a failure
   --    reported by OpenCV.
   function Get_Rotation_Matrix_2D
     (Center : OpenCV.Float32_Point;
      Angle  : OpenCV.Float64_Value;
      Scale  : OpenCV.Float64_Value := 1.0;
      Units  : OpenCV.Angle_Unit := OpenCV.Degrees) return OpenCV.Core.Mat;

   --  Row index of an Affine_Transform_2D: row R is OpenCV's row R - 1.
   type Affine_Row_Index is range 1 .. 2;

   --  Row index of a Perspective_Transform_2D: row R is OpenCV's row R - 1.
   type Perspective_Row_Index is range 1 .. 3;

   --  Column index of a transform matrix: column C is OpenCV's column C - 1.
   type Transform_Column_Index is range 1 .. 3;

   --  A Geometry-owned 2x3 affine transform with value semantics.
   --  Transform (R, C) is OpenCV's M (R - 1, C - 1). An affine transform T
   --  maps (X, Y) to
   --  (`T (1, 1) * X + T (1, 2) * Y + T (1, 3)`,
   --  `T (2, 1) * X + T (2, 2) * Y + T (2, 3)`).
   type Affine_Transform_2D is
     array (Affine_Row_Index, Transform_Column_Index) of OpenCV.Float64_Value;

   --  A Geometry-owned 3x3 perspective transform (homography) with value
   --  semantics. Transform (R, C) is OpenCV's M (R - 1, C - 1). It maps
   --  (X, Y) to (U / W, V / W), where (U, V, W) is the product of T and the
   --  column (X, Y, 1).
   type Perspective_Transform_2D is
     array (Perspective_Row_Index, Transform_Column_Index)
     of OpenCV.Float64_Value;

   --  The affine transform that maps every point to itself.
   Identity_Affine_Transform : constant Affine_Transform_2D :=
     ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0));

   --  The perspective transform that maps every point to itself.
   Identity_Perspective_Transform : constant Perspective_Transform_2D :=
     ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0));

   --  Affine transform that maps each Source point to the Destination point
   --  at the same position, computed by cv::getAffineTransform. Source and
   --  Destination must each contain exactly three points. Their bounds may
   --  differ; points are paired in iteration order. Every coordinate must be
   --  finite. OpenCV solves the 6x6 linear system by LU decomposition and
   --  ignores a singular result. When its absolute pivot test (a pivot below
   --  about 2.2E-14) finds the system singular, as for collinear or repeated
   --  Source points, the result is therefore the all-zero transform rather
   --  than an error. A degenerate or nearly degenerate triangle that passes
   --  that test can instead yield very large finite coefficients. The zero
   --  transform is also the correct result when every Destination point is
   --  the origin, so callers that need a non-degenerate mapping must check
   --  the Source triangle themselves. Source and Destination are unchanged.
   --  Wrong point counts, non-finite coordinates, non-finite native
   --  coefficients, and failures reported by OpenCV raise
   --  OpenCV.OpenCV_Error.
   --  @param Source Exactly three finite points, with any bounds.
   --  @param Destination Exactly three finite points, paired with Source in
   --    iteration order.
   --  @return The native affine coefficients, every one finite; all zero
   --    when OpenCV finds the system singular.
   --  @exception OpenCV_Error A point count other than three, a NaN or
   --    infinite coordinate, a non-finite native coefficient, or a failure
   --    reported by OpenCV.
   function Get_Affine_Transform
     (Source, Destination : Float32_Point_Array) return Affine_Transform_2D;

   --  Inverse of an affine transform, computed by cv::invertAffineTransform
   --  in binary64. Every coefficient must be finite. OpenCV evaluates the
   --  determinant D = T (1, 1) * T (2, 2) - T (1, 2) * T (2, 1) and uses
   --  1.0 / D, or 0.0 when D is exactly 0.0. A singular linear part, a D that
   --  underflows to 0.0, and a D that overflows to infinity (for example
   --  diagonal coefficients above about 1.3E+154 in magnitude) all give the
   --  all-zero transform (some coefficients may be negative zero) rather than
   --  an error, and this function returns it unchanged. A nearly singular
   --  transform can yield very large coefficients. A nonzero D so small that
   --  the inverse overflows, or a D that evaluates to NaN (infinity minus
   --  infinity), yields non-finite coefficients, which raise
   --  OpenCV.OpenCV_Error.
   --  Transform is unchanged. Non-finite coefficients and failures reported
   --  by OpenCV also raise OpenCV.OpenCV_Error.
   --  @param Transform The affine transform to invert; every coefficient
   --    finite.
   --  @return The native inverse coefficients, every one finite; all zero
   --    for the singular cases above.
   --  @exception OpenCV_Error A non-finite coefficient of Transform or of
   --    the native inverse, or a failure reported by OpenCV.
   function Invert_Affine_Transform
     (Transform : Affine_Transform_2D) return Affine_Transform_2D;

   --  Solver for the 8x8 linear system of Get_Perspective_Transform:
   --  OpenCV DECOMP_LU (the default), DECOMP_SVD, and DECOMP_QR.
   --  LU_Decomposition and QR_Decomposition detect a singular system;
   --  Singular_Value_Decomposition returns a least-squares solution and
   --  never reports one. OpenCV's DECOMP_EIG and DECOMP_CHOLESKY assume a
   --  symmetric matrix, which this system is not, and DECOMP_NORMAL has no
   --  effect on a square system, so none of them is offered.
   --  @enum LU_Decomposition DECOMP_LU: Gaussian elimination, OpenCV's
   --    default solver.
   --  @enum Singular_Value_Decomposition DECOMP_SVD: a least-squares
   --    solution, never reported singular.
   --  @enum QR_Decomposition DECOMP_QR: QR factorization.
   type Perspective_Solve_Method is
     (LU_Decomposition, Singular_Value_Decomposition, QR_Decomposition);

   --  Perspective transform that maps each Source point to the Destination
   --  point at the same position, computed by cv::getPerspectiveTransform
   --  with Method. Source and Destination must each contain exactly four
   --  points. Their bounds may differ; points are paired in iteration order.
   --  Every coordinate must be finite. OpenCV solves for eight coefficients
   --  with T (3, 3) fixed at 1.0, and this function returns the native
   --  coefficients without further normalization:
   --  - OpenCV before 4.12 always returns T (3, 3) = 1.0. When
   --    LU_Decomposition or QR_Decomposition finds the system singular (a
   --    pivot below about 2.2E-14), for example with three collinear Source
   --    points, the result is the matrix whose only nonzero coefficient is
   --    T (3, 3) = 1.0. QR_Decomposition can instead produce non-finite
   --    coefficients, for example when every Source X is 0.
   --    Singular_Value_Decomposition returns a least-squares solution that
   --    need not map the points.
   --  - OpenCV 4.12 and later, including 5.x, accept that solution only when
   --    the solver reports success and the absolute residual of the 8x8
   --    linear system is below 1.0E-8; this is not a reprojection error.
   --    Otherwise, for example for degenerate correspondences or some
   --    coordinates of magnitude 1.0E+7 and above, they return a least-squares
   --    solution of the homogeneous system with unit Frobenius norm and
   --    arbitrary sign. That solution is not unique for degenerate input, and
   --    its T (3, 3) need not be 1.0 and can be negative or zero.
   --  Source and Destination are unchanged. Wrong point counts, non-finite
   --  coordinates, non-finite native coefficients, and failures reported by
   --  OpenCV raise OpenCV.OpenCV_Error.
   --  @param Source Exactly four finite points, with any bounds.
   --  @param Destination Exactly four finite points, paired with Source in
   --    iteration order.
   --  @param Method The solver for the 8x8 system; LU by default.
   --  @return The native homography coefficients, every one finite, as
   --    described above.
   --  @exception OpenCV_Error A point count other than four, a NaN or
   --    infinite coordinate, a non-finite native coefficient, or a failure
   --    reported by OpenCV.
   function Get_Perspective_Transform
     (Source, Destination : Float32_Point_Array;
      Method              : Perspective_Solve_Method := LU_Decomposition)
      return Perspective_Transform_2D;

   --  Maps Point through Transform with Ada arithmetic: each coordinate is
   --  (T (R, 1) * X + T (R, 2) * Y) + T (R, 3), evaluated in binary64 and
   --  then rounded to the nearest binary32 value. Point must be finite, and
   --  every coefficient must be finite with magnitude at most 1.0E+269.
   --  These requirements are checked at run time, and within them SPARK
   --  proves that no binary64 intermediate overflows. Violations, and
   --  results outside binary32 range, raise OpenCV.OpenCV_Error.
   --  @param Transform The affine transform; every coefficient finite, of
   --    magnitude at most 1.0E+269.
   --  @param Point The point to map; finite.
   --  @return The mapped point, rounded to binary32.
   --  @exception OpenCV_Error A non-finite Point, a coefficient that is not
   --    finite or exceeds the bound, or a result outside binary32 range.
   function Transform_Point
     (Transform : Affine_Transform_2D; Point : OpenCV.Float32_Point)
      return OpenCV.Float32_Point;

   --  Maps Point through a perspective Transform with Ada arithmetic. U, V,
   --  and W are evaluated like the affine rows, the result is (U / W, V / W)
   --  in binary64, and each coordinate is then rounded to the nearest
   --  binary32 value. The Point and coefficient requirements are those of
   --  the affine Transform_Point. W = 0.0, which maps Point to infinity, and
   --  results outside binary32 range raise OpenCV.OpenCV_Error. Unlike
   --  cv::perspectiveTransform, which maps a point with |W| <= FLT_EPSILON
   --  to the origin and multiplies by 1 / W, this divides by every nonzero W.
   --  @param Transform The homography; every coefficient finite, of
   --    magnitude at most 1.0E+269.
   --  @param Point The point to map; finite.
   --  @return The mapped point (U / W, V / W), rounded to binary32.
   --  @exception OpenCV_Error A non-finite Point, a coefficient that is not
   --    finite or exceeds the bound, W = 0.0, or a result outside binary32
   --    range.
   function Transform_Point
     (Transform : Perspective_Transform_2D; Point : OpenCV.Float32_Point)
      return OpenCV.Float32_Point;

   --  Maps Points in Ada index order using the corresponding Transform_Point
   --  arithmetic and checks above (binary64 evaluation, binary32 results).
   --  Coefficients are validated even for empty input. A valid empty input
   --  retains its original null range. Bounds, order and cardinality are
   --  preserved; neither input is modified. Any failed mapping raises
   --  OpenCV.OpenCV_Error and no incomplete result is returned.
   --  @param Transform The affine transform; every coefficient finite, of
   --    magnitude at most 1.0E+269, checked even when Points is empty.
   --  @param Points The points to map, with any bounds; each finite.
   --  @return The mapped points at the same indices: exactly the bounds of
   --    Points (the postcondition).
   --  @exception OpenCV_Error An invalid coefficient, or any point whose
   --    mapping Transform_Point would reject; no partial result is returned.
   function Transform_Points
     (Transform : Affine_Transform_2D; Points : Float32_Point_Array)
      return Float32_Point_Array
   with
     Post =>
       Transform_Points'Result'First = Points'First
       and then Transform_Points'Result'Last = Points'Last;

   --  As above, with perspective Transform_Point semantics: divide by every
   --  nonzero W, including negative and very small W; reject W = 0 rather
   --  than applying the native cv::perspectiveTransform epsilon policy.
   --  @param Transform The homography; every coefficient finite, of
   --    magnitude at most 1.0E+269, checked even when Points is empty.
   --  @param Points The points to map, with any bounds; each finite.
   --  @return The mapped points at the same indices: exactly the bounds of
   --    Points (the postcondition).
   --  @exception OpenCV_Error An invalid coefficient, or any point whose
   --    mapping Transform_Point would reject, including W = 0.0; no partial
   --    result is returned.
   function Transform_Points
     (Transform : Perspective_Transform_2D; Points : Float32_Point_Array)
      return Float32_Point_Array
   with
     Post =>
       Transform_Points'Result'First = Points'First
       and then Transform_Points'Result'Last = Points'Last;

end OpenCV.Geometry;
