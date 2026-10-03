with OpenCV.Core;

package OpenCV.Geometry is

   --  Availability in the linked native OpenCV, NOT Ada binding coverage.
   --  Approximate_Convex_Polygon, Minimum_Enclosing_Convex_Polygon and
   --  Float32 subdivision bounds remain unbound even when supported here.
   type Native_Feature is
     (Approximate_Convex_Polygon_Feature,
      Closest_Ellipse_Points_Feature,
      Minimum_Enclosing_Convex_Polygon_Feature,
      Float32_Subdivision_Bounds_Feature);

   function Is_Natively_Supported (Feature : Native_Feature) return Boolean;

   --  An integer contour, for integer-coordinate geometry. CV_32S points.
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

   --  One native approximate closest ellipse point per query, preserving
   --  Points'Range (including null and Natural'Last-adjacent ranges).
   --  Requires OpenCV 4.12+ or 5.x; older versions raise OpenCV_Error even
   --  for empty input. On supported versions, empty input returns empty.
   --  Ellipse fields and Float32 queries must be finite; both ellipse
   --  dimensions must be positive. Native arithmetic has three fixed
   --  iterations: extreme inputs can produce non-finite output, rejected
   --  with OpenCV_Error. No arbitrary coordinate limit is imposed.
   --  Integer queries enter CV_32S and OpenCV converts them to Point2f,
   --  possibly losing low bits. Both overloads return Float32 points.
   --  Ellipse and Points are unchanged.
   function Closest_Ellipse_Points
     (Ellipse : OpenCV.Rotated_Rect; Points : Contour)
      return Float32_Point_Array
   with
     Post =>
       Closest_Ellipse_Points'Result'First = Points'First
       and then Closest_Ellipse_Points'Result'Last = Points'Last;

   function Closest_Ellipse_Points
     (Ellipse : OpenCV.Rotated_Rect; Points : Float32_Point_Array)
      return Float32_Point_Array
   with
     Post =>
       Closest_Ellipse_Points'Result'First = Points'First
       and then Closest_Ellipse_Points'Result'Last = Points'Last;

   --  Calculates the OpenCV polygon area of Points. When Oriented is False,
   --  the result is nonnegative; otherwise it retains OpenCV's orientation
   --  sign. Empty and degenerate contours return zero. Points is unchanged.
   function Contour_Area
     (Points : Contour; Oriented : Boolean := False)
      return OpenCV.Float64_Value;

   --  Contour_Area of a Float32 point set. OpenCV accumulates the cross
   --  products of the binary32 coordinates in binary64, so the result is
   --  always finite. Points is unchanged.
   function Contour_Area
     (Points : Float32_Point_Array; Oriented : Boolean := False)
      return OpenCV.Float64_Value;

   --  Calculates the OpenCV curve length of Points. Closed includes the
   --  segment from the final point to the first. Empty and one-point contours
   --  return zero. Points is unchanged.
   function Arc_Length
     (Points : Contour; Closed : Boolean) return OpenCV.Float64_Value;

   --  Arc_Length of a Float32 point set. OpenCV computes each segment's
   --  coordinate differences, their squares, and the segment length in
   --  binary32 and sums the lengths in binary64. A segment longer than about
   --  1.8E+19 overflows binary32 and makes the native length infinite, which
   --  raises OpenCV_Error; segment components below about 1.0E-19 lose
   --  precision as their squares underflow. Points is unchanged.
   function Arc_Length
     (Points : Float32_Point_Array; Closed : Boolean)
      return OpenCV.Float64_Value;

   --  Spatial, central, and normalized central moments through third order
   --  for an Ada-owned contour. For ordinary non-self-intersecting contours,
   --  M_00 is the polygon area. A centroid, when meaningful, is
   --  (M_10 / M_00, M_01 / M_00); callers must handle M_00 = 0.0 themselves.
   --  Self-intersecting contours may have surprising moments because OpenCV
   --  uses Green's formula. Empty contours return an all-zero result. Points
   --  is unchanged.
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

   function Compute_Moments (Points : Contour) return Moments_Result;

   --  Compute_Moments of a Float32 point set. OpenCV evaluates Green's
   --  formula in binary64 from the binary32 coordinates. When the magnitude
   --  of OpenCV's computed doubled area is at most FLT_EPSILON (2.0**(-23)),
   --  that is, for an absolute area of at most about 6.0E-8, every field is
   --  0.0; an integer contour never has such a nonzero area, but a small
   --  Float32 one can. Non-finite native moments, which extreme coordinates
   --  can produce, for example in a self-intersecting contour whose net area
   --  is tiny, raise OpenCV_Error. Points is unchanged.
   function Compute_Moments
     (Points : Float32_Point_Array) return Moments_Result;

   --  Seven Hu invariants of Moments in OpenCV order, indexed 1 .. 7.
   --  The values are the raw invariants, not logarithmically transformed
   --  Match_Shapes scores. They are invariant to translation, scale,
   --  rotation, and reflection except the seventh, whose sign changes
   --  under reflection. Rasterized-image transforms can differ slightly.
   --  Compose with Compute_Moments as Hu_Moments (Compute_Moments (Points)).
   --  Moments is unchanged. Every field of Moments must be finite: a
   --  non-finite field, which only invalid data can hold, raises
   --  OpenCV_Error. If native Hu computation produces a non-finite value
   --  that cannot be represented by Float64_Value, Hu_Moments raises
   --  OpenCV_Error.
   type Hu_Moment_Index is range 1 .. 7;

   type Hu_Moments_Result is array (Hu_Moment_Index) of OpenCV.Float64_Value;

   function Hu_Moments (Moments : Moments_Result) return Hu_Moments_Result;

   --  Convex hull of Points as an Ada-owned contour of hull points, not
   --  source-point indices. Orientation uses OpenCV's convention: X
   --  increases rightward and Y increases upward. Image coordinates often
   --  increase Y downward, so the visual winding may appear reversed.
   --  Empty input returns an empty contour. Points is unchanged.
   --  More than Integer_32'Last - 2 points raise OpenCV_Error because native
   --  convexHull computes total + 2 in signed int before stack allocation.
   type Hull_Orientation is (Counterclockwise, Clockwise);

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
   function Convex_Hull
     (Points      : Float32_Point_Array;
      Orientation : Hull_Orientation := Counterclockwise)
      return Float32_Point_Array;

   --  Convex hull of Points as indices into Points. Every value is an index
   --  in Points'Range, not a native zero-based offset, so shifted and other
   --  nonzero Points bounds are preserved. The indices describe the same
   --  hull as Convex_Hull with the same Orientation. OpenCV cyclically
   --  shifts the sequence to be strictly increasing or strictly decreasing
   --  when possible, which holds for simple contours; a self-intersecting
   --  contour may yield a sequence that is neither. When several points
   --  share one hull vertex's coordinates, any of their indices may be
   --  returned, and OpenCV 4.x and 5.x can choose differently. The result is
   --  zero-based; empty input returns the null range 1 .. 0. Points is
   --  unchanged. Inputs that would overflow native integer convex-hull
   --  arithmetic raise OpenCV_Error, including more than Integer_32'Last - 2
   --  points because native convexHull computes total + 2 in signed int.
   type Point_Index_Array is array (Natural range <>) of Natural;

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
   --  any index may be returned. The result is zero-based; empty input
   --  returns the null range 1 .. 0. Points is unchanged.
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
   type Convexity_Defect is record
      Start_Index    : Natural := 0;
      End_Index      : Natural := 0;
      Farthest_Index : Natural := 0;
      Depth          : OpenCV.Float64_Value := 0.0;
   end record;

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
   --  Width**2 + Height**2 <= 8_388_607**2, where 8_388_607 is
   --  Integer_32'Last / 256: OpenCV stores Depth * 256 rounded in a signed
   --  32-bit integer, and no Depth exceeds the bounding-box diagonal. This
   --  also keeps native signed 32-bit coordinate subtraction from
   --  overflowing. Larger spans raise OpenCV_Error before native code runs.
   --  The result is zero-based, with the null range 1 .. 0 when empty, and
   --  has at most Hull'Length defects. Points and Hull are unchanged.
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
   --  self-intersecting, raises OpenCV_Error with that diagnosis.
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
   --  degrees. OpenCV 4.x and 5.x can encode an equivalent rectangle with
   --  different width, height, and angle fields, so callers must not assume
   --  one cross-version angle range. Empty and degenerate contours preserve
   --  the active backend representation. Points is unchanged. Inputs that
   --  would overflow native integer convex-hull arithmetic raise OpenCV_Error.
   function Minimum_Area_Rectangle
     (Points : Contour) return OpenCV.Rotated_Rect;

   --  Minimum_Area_Rectangle of a Float32 point set, computed by OpenCV's
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
   function Fit_Ellipse_Direct (Points : Contour) return OpenCV.Rotated_Rect;

   --  Fit_Ellipse, Fit_Ellipse_AMS, and Fit_Ellipse_Direct of a Float32
   --  point set: the same native algorithms, dispatch, fallbacks, random
   --  perturbation, point counts, and result representation as the integer
   --  overloads, applied to the binary32 coordinates without rounding.
   --  OpenCV's classic and AMS fits, which all three can reach, sum the
   --  coordinates in binary32 to find their mean. An overflowing sum would
   --  hand NaN to OpenCV's solver, which without LAPACK then takes time
   --  quadratic in the number of points, so the absolute X coordinates and
   --  the absolute Y coordinates must each sum to at most 2.0**103 (about
   --  1.0E+31); larger sets raise OpenCV_Error. Native failures and
   --  non-finite or negative size components raise OpenCV_Error. Points is
   --  unchanged.
   function Fit_Ellipse
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect;

   function Fit_Ellipse_AMS
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect;

   function Fit_Ellipse_Direct
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect;

   --  Distance model of Fit_Line_2D (OpenCV DistanceTypes). L2 is orthogonal
   --  (total) least squares, solved in closed form as the principal axis of
   --  the points; L1, L12, Fair, Welsch, and Huber are robust M-estimators
   --  that OpenCV solves by iteratively reweighted least squares.
   type Line_Fit_Distance is (L2, L1, L12, Fair, Welsch, Huber);

   --  A fitted 2D line in native binary32 values. Direction is OpenCV's unit
   --  direction (vx, vy) and Point is OpenCV's point (x0, y0) on the line.
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
   --  forms each product X*X, Y*Y, and X*Y in binary32 before summing, and
   --  does not first subtract the mean, so points far from the origin
   --  relative to their spread lose direction accuracy. A product above
   --  Float32_Value'Last overflows, and when only the X or only the Y
   --  products do, OpenCV returns a finite but wrong direction. So every
   --  coordinate must have magnitude at most 2.0**63, which keeps the
   --  products finite; other sets raise OpenCV_Error. Non-finite native
   --  results, and the all-zero line with which OpenCV's robust fit starts
   --  and which it keeps when no candidate has a finite error, also raise
   --  OpenCV_Error. Points is unchanged.
   --  L2 accepts the ordinary C ABI count limit, Integer_32'Last. Robust
   --  distances (L1, L12, Fair, Welsch, Huber) require at most
   --  Integer_32'Last / 2 points: native fitLine allocates count*2 floats
   --  after the L2 early return. Larger counts raise OpenCV_Error.
   function Fit_Line_2D
     (Points          : Float32_Point_Array;
      Distance        : Line_Fit_Distance := L2;
      Parameter       : OpenCV.Float64_Value := 0.0;
      Radius_Accuracy : OpenCV.Float64_Value := 0.01;
      Angle_Accuracy  : OpenCV.Float64_Value := 0.01) return Fitted_Line_2D;

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
   type Box_Vertex_Index is range 1 .. 4;

   type Box_Vertices is array (Box_Vertex_Index) of OpenCV.Float32_Point;

   function Box_Points (Box : OpenCV.Rotated_Rect) return Box_Vertices;

   --  Intersection of two convex polygons. Area is OpenCV's nonnegative
   --  binary32 intersection area, and Vertices is the native binary32
   --  intersection polygon in native order without normalization. Vertices
   --  is indexed 1 .. Vertex_Count, because its bounds follow the
   --  discriminant. An empty intersection has Vertex_Count = 0 and Area 0.0.
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
   --  internal buffer on such input. Every vertex coordinate must also lie in
   --  -2**24 .. 2**24, where OpenCV's binary32 conversion is exact, and the X
   --  span and the Y span of Left and Right together must each be at most
   --  2**24, or 2**25 when every coordinate is even, so that every binary32
   --  coordinate difference is exact too; other polygons raise OpenCV_Error.
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
   --  Right must be an integer multiple of 2.0**K, and Left and Right divided
   --  by 2.0**K must be integer polygons that the integer overload accepts,
   --  so of magnitude at most 2.0**(24 + K) and of joint X and Y spans at
   --  most 2.0**(24 + K), or twice that when every coordinate is a multiple
   --  of 2.0**(K + 1). Examples are integer polygons within those limits and
   --  polygons whose coordinates are multiples of 0.25 with magnitude and
   --  joint spans at most 4194304.0. Other finite polygons, including most
   --  with decimal fractions such as 0.1, raise OpenCV_Error, as do
   --  non-finite coordinates. K >= -8 keeps every nonzero native orientation
   --  above OpenCV's absolute 1.0E-5 tolerance, and K <= 6 keeps coordinate
   --  magnitudes at most 2.0**30, below the 2.0**31 at which the cvRound in
   --  OpenCV's nested-polygon test overflows.
   --  On accepted input OpenCV returns the result it computes for the
   --  integer polygons, scaled by 2.0**K: both run the same binary32 and
   --  binary64 operations, which commute with power-of-two scaling in this
   --  range. The rule applies on every release, so that the accepted inputs
   --  do not depend on the OpenCV version. Left and Right are unchanged.
   function Intersect_Convex_Polygons
     (Left, Right : Float32_Point_Array; Handle_Nested : Boolean := True)
      return Convex_Polygon_Intersection;

   --  OpenCV's rotated-rectangle intersection classification:
   --  INTERSECT_NONE, INTERSECT_PARTIAL, and INTERSECT_FULL. OpenCV documents
   --  INTERSECT_FULL as one rectangle lying wholly within the other.
   type Rectangle_Intersection_Kind is
     (No_Intersection, Partial_Intersection, Full_Intersection);

   --  OpenCV 4.6, 4.10, and 5.0 reduce the region to at most eight vertices.
   subtype Rectangle_Intersection_Vertex_Count is Natural range 0 .. 8;

   --  Vertices is indexed 1 .. Vertex_Count.
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
   function Approximate_Curve
     (Points  : Float32_Point_Array;
      Epsilon : OpenCV.Float64_Value;
      Closed  : Boolean) return Float32_Point_Array;

   --  Minimal upright axis-aligned bounding rectangle of Points. Integer
   --  extent is inclusive, so Width = X_Max - X_Min + 1 and Height =
   --  Y_Max - Y_Min + 1. Empty input returns (0, 0, 0, 0). Origins may be
   --  negative because OpenCV.Rect uses signed Point_Coordinate X/Y.
   --  Inclusive extents that cannot be represented as signed 32-bit width
   --  or height raise OpenCV.OpenCV_Error. Points is unchanged.
   function Bounding_Rect (Points : Contour) return OpenCV.Rect;

   --  Minimal upright integer rectangle containing a Float32 point set, as
   --  OpenCV computes it from the floors of the extreme coordinates:
   --  X = Floor (Min X), Width = Floor (Max X) - X + 1, and likewise Y and
   --  Height. Every point P therefore satisfies X <= P.X < X + Width. For
   --  integer-valued coordinates the result is the integer overload's.
   --  OpenCV converts the floors to signed 32-bit integers, which is
   --  undefined outside -2.0**31 .. 2.0**31, so every coordinate must be
   --  at least -2.0**31 and less than 2.0**31, and Width and Height must
   --  not exceed Integer_32'Last; other inputs raise OpenCV_Error. Empty
   --  input returns (0, 0, 0, 0). Points is unchanged.
   function Bounding_Rect (Points : Float32_Point_Array) return OpenCV.Rect;

   --  Tests whether Points is a convex contour. The contour is expected to
   --  be simple (non-self-intersecting); OpenCV leaves the result for
   --  non-simple contours undefined. Convexity does not depend on winding
   --  direction. Empty, one-point, two-point, and collinear contours are
   --  not convex. Points is unchanged.
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
   function Is_Convex (Points : Float32_Point_Array) return Boolean;

   --  Compares Left and Right using OpenCV Hu-moment matching. Lower scores
   --  indicate more similar shapes; identical or equivalent contours
   --  normally approach zero, though floating-point evaluation can leave
   --  a tiny residual. Reciprocal_Log_Difference, Log_Difference, and
   --  Relative_Log_Difference select OpenCV I1, I2, and I3. Relative
   --  comparison is directional: the Left contour supplies the
   --  denominator. The unused native OpenCV parameter is not exposed.
   --  Left and Right are unchanged. If native matching produces a
   --  non-finite value that cannot be represented by Float64_Value,
   --  Match_Shapes raises OpenCV_Error.
   type Shape_Match_Method is
     (Reciprocal_Log_Difference, Log_Difference, Relative_Log_Difference);

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
   function Match_Shapes
     (Left, Right : Float32_Point_Array; Method : Shape_Match_Method)
      return OpenCV.Float64_Value;

   --  Classifies Query relative to the polygon defined by Points.
   --  Query coordinates are binary32 and may be fractional. Empty
   --  contours are Outside_Contour. For nonempty Points, OpenCV rounds
   --  Query to a signed 32-bit integer point, so a Query coordinate that
   --  is not finite, or not in -2.0**31 .. 2.0**31 (excluding 2.0**31),
   --  raises OpenCV_Error. Points is unchanged.
   type Contour_Point_Location is
     (Outside_Contour, On_Contour_Boundary, Inside_Contour);

   function Locate_Point
     (Points : Contour; Query : OpenCV.Float32_Point)
      return Contour_Point_Location;

   --  Signed distance from Query to the nearest edge of Points.
   --  Positive is inside, zero is on the boundary, and negative is
   --  outside. Empty contours follow OpenCV and return the largest
   --  finite negative Float64_Value. Points is unchanged. If native
   --  computation produces a non-finite value that cannot be
   --  represented by Float64_Value, Signed_Distance_To_Contour raises
   --  OpenCV_Error.
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
   --  must be at least -2.0**31 and less than 2.0**31. Other inputs raise
   --  OpenCV_Error. OpenCV starts its nearest-edge search at a squared
   --  distance of FLT_MAX and cannot report a farther edge, so a distance of
   --  at least Sqrt (Float32_Value'Last), about 1.8447E+19, raises
   --  OpenCV_Error rather than being clamped; integer contours cannot reach
   --  it. Points is unchanged.
   function Locate_Point
     (Points : Float32_Point_Array; Query : OpenCV.Float32_Point)
      return Contour_Point_Location;

   function Signed_Distance_To_Contour
     (Points : Float32_Point_Array; Query : OpenCV.Float32_Point)
      return OpenCV.Float64_Value;

   --  Smallest circle enclosing Points. Center and Radius are binary32
   --  OpenCV results, including the native EPS added to radii. Empty
   --  contours return center (0, 0) and radius 0. One-point contours
   --  return that point as Center and the native EPS as Radius. Points
   --  is unchanged. Integer contours whose native signed-32-bit pair
   --  addition or subtraction would overflow raise OpenCV_Error. If a
   --  native center or radius component is non-finite, or if a successful
   --  native radius is negative, Minimum_Enclosing_Circle raises
   --  OpenCV_Error. OpenCV finds the circle through three points from
   --  binary32 dot products of absolute coordinates, so points far from the
   --  origin relative to their spread can get a circle that misses one of
   --  them: OpenCV 4.10 leaves a vertex of a triangle with sides of about 8
   --  near (10_000_000, 10_000_000) 41% of the radius outside. The native
   --  circle is returned as computed.
   type Enclosing_Circle is record
      Center : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      Radius : OpenCV.Float32_Value := 0.0;
   end record;

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
   --  2.0**41, keeping those products finite; other such sets raise
   --  OpenCV_Error. Zero, one, and two points cannot reach the three-point
   --  construction and have no such magnitude limit. Coordinates and native
   --  center/radius must still be finite for every cardinality, or raise
   --  OpenCV_Error. OpenCV 5.x shuffles more than ten points, with a
   --  generator seeded from the points, before its incremental search, and
   --  keeps the previous circle for such a collinear triple where 4.x uses
   --  the triple's farthest pair; results can therefore differ between
   --  them, in rounding or, near degeneracy, more. Points is unchanged.
   function Minimum_Enclosing_Circle
     (Points : Float32_Point_Array) return Enclosing_Circle;

   --  Smallest-area triangle enclosing Points. Area is OpenCV's native
   --  double result. Vertices are the three native CV_32F triangle
   --  vertices in native order; callers must not assume a cyclic start
   --  or winding. Fractional and negative coordinates are preserved.
   --  Empty input is rejected by OpenCV. One-point, two-point, collinear,
   --  and repeated-point inputs may return repeated vertices and zero
   --  area. Points is unchanged. Inputs that would overflow native
   --  integer convex-hull arithmetic raise OpenCV.OpenCV_Error. If a
   --  native area or vertex component is non-finite, or if a successful
   --  native area is negative, Minimum_Enclosing_Triangle raises
   --  OpenCV.OpenCV_Error. OpenCV's search loops in 4.6, 4.10, and 5.0
   --  have no iteration bound and can fail to return for some nearly
   --  degenerate hulls, such as the long thin quadrilateral (0, 0), (1, 0),
   --  (100001, 1), (100000, 1), or nearly collinear vertices; the binding
   --  cannot detect those inputs in advance. There is no Float32 overload:
   --  binary32 point sets add more such inputs, including any hull smaller
   --  than OpenCV's absolute tolerance, and signed zeros that make OpenCV
   --  divide by zero.
   type Triangle_Vertex_Index is range 1 .. 3;

   type Triangle_Vertices is
     array (Triangle_Vertex_Index) of OpenCV.Float32_Point;

   type Enclosing_Triangle is record
      Area     : OpenCV.Float64_Value := 0.0;
      Vertices : Triangle_Vertices := (others => (X => 0.0, Y => 0.0));
   end record;

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
   function Get_Rotation_Matrix_2D
     (Center : OpenCV.Float32_Point;
      Angle  : OpenCV.Float64_Value;
      Scale  : OpenCV.Float64_Value := 1.0;
      Units  : OpenCV.Angle_Unit := OpenCV.Degrees) return OpenCV.Core.Mat;

   --  Geometry-owned transform matrices with value semantics. Indices are
   --  1-based: Transform (R, C) is OpenCV's M (R - 1, C - 1). An affine
   --  transform maps (X, Y) to
   --    (T (1, 1) * X + T (1, 2) * Y + T (1, 3),
   --     T (2, 1) * X + T (2, 2) * Y + T (2, 3)).
   --  A perspective transform (homography) maps (X, Y) to (U / W, V / W),
   --  where (U, V, W) is the product of T and the column (X, Y, 1).
   type Affine_Row_Index is range 1 .. 2;
   type Perspective_Row_Index is range 1 .. 3;
   type Transform_Column_Index is range 1 .. 3;

   type Affine_Transform_2D is
     array (Affine_Row_Index, Transform_Column_Index) of OpenCV.Float64_Value;

   type Perspective_Transform_2D is
     array (Perspective_Row_Index, Transform_Column_Index)
     of OpenCV.Float64_Value;

   Identity_Affine_Transform : constant Affine_Transform_2D :=
     ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0));

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
   function Invert_Affine_Transform
     (Transform : Affine_Transform_2D) return Affine_Transform_2D;

   --  Solver for the 8x8 linear system of Get_Perspective_Transform:
   --  OpenCV DECOMP_LU (the default), DECOMP_SVD, and DECOMP_QR.
   --  LU_Decomposition and QR_Decomposition detect a singular system;
   --  Singular_Value_Decomposition returns a least-squares solution and
   --  never reports one. OpenCV's DECOMP_EIG and DECOMP_CHOLESKY assume a
   --  symmetric matrix, which this system is not, and DECOMP_NORMAL has no
   --  effect on a square system, so none of them is offered.
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
   function Transform_Point
     (Transform : Perspective_Transform_2D; Point : OpenCV.Float32_Point)
      return OpenCV.Float32_Point;

end OpenCV.Geometry;
