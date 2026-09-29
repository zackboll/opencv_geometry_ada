with OpenCV.Core;

package OpenCV.Geometry is

   subtype Contour is OpenCV.Point_Array;

   --  Calculates the OpenCV polygon area of Points. When Oriented is False,
   --  the result is nonnegative; otherwise it retains OpenCV's orientation
   --  sign. Empty and degenerate contours return zero. Points is unchanged.
   function Contour_Area
     (Points : Contour; Oriented : Boolean := False)
      return OpenCV.Float64_Value;

   --  Calculates the OpenCV curve length of Points. Closed includes the
   --  segment from the final point to the first. Empty and one-point contours
   --  return zero. Points is unchanged.
   function Arc_Length
     (Points : Contour; Closed : Boolean) return OpenCV.Float64_Value;

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

   --  Seven Hu invariants of Moments in OpenCV order, indexed 1 .. 7.
   --  The values are the raw invariants, not logarithmically transformed
   --  Match_Shapes scores. They are invariant to translation, scale,
   --  rotation, and reflection except the seventh, whose sign changes
   --  under reflection. Rasterized-image transforms can differ slightly.
   --  Compose with Compute_Moments as Hu_Moments (Compute_Moments (Points)).
   --  Moments is unchanged.
   --  If native Hu computation produces a non-finite value that cannot
   --  be represented by Float64_Value, Hu_Moments raises OpenCV_Error.
   type Hu_Moment_Index is range 1 .. 7;

   type Hu_Moments_Result is array (Hu_Moment_Index) of OpenCV.Float64_Value;

   function Hu_Moments (Moments : Moments_Result) return Hu_Moments_Result;

   --  Convex hull of Points as an Ada-owned contour of hull points, not
   --  source-point indices. Orientation uses OpenCV's convention: X
   --  increases rightward and Y increases upward. Image coordinates often
   --  increase Y downward, so the visual winding may appear reversed.
   --  Empty input returns an empty contour. Points is unchanged.
   type Hull_Orientation is (Counterclockwise, Clockwise);

   function Convex_Hull
     (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
      return Contour;

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
   --  arithmetic raise OpenCV_Error.
   type Point_Index_Array is array (Natural range <>) of Natural;

   function Convex_Hull_Indices
     (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
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
   --  negative size components raise OpenCV.OpenCV_Error.
   function Fit_Ellipse (Points : Contour) return OpenCV.Rotated_Rect;

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

   --  Approximates Points with Douglas-Peucker. Epsilon is the maximum
   --  distance between the original curve and the result and must be
   --  in the range 0.0 <= Epsilon < 1.0E30. Closed connects the last
   --  vertex to the first. The result is an Ada-owned contour. Empty
   --  input returns an empty contour. Points is unchanged.
   function Approximate_Curve
     (Points : Contour; Epsilon : OpenCV.Float64_Value; Closed : Boolean)
      return Contour;

   --  Minimal upright axis-aligned bounding rectangle of Points. Integer
   --  extent is inclusive, so Width = X_Max - X_Min + 1 and Height =
   --  Y_Max - Y_Min + 1. Empty input returns (0, 0, 0, 0). Origins may be
   --  negative because OpenCV.Rect uses signed Point_Coordinate X/Y.
   --  Inclusive extents that cannot be represented as signed 32-bit width
   --  or height raise OpenCV.OpenCV_Error. Points is unchanged.
   function Bounding_Rect (Points : Contour) return OpenCV.Rect;

   --  Tests whether Points is a convex contour. The contour is expected to
   --  be simple (non-self-intersecting); OpenCV leaves the result for
   --  non-simple contours undefined. Convexity does not depend on winding
   --  direction. Empty, one-point, two-point, and collinear contours are
   --  not convex. Points is unchanged.
   function Is_Convex (Points : Contour) return Boolean;

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

   --  Classifies Query relative to the polygon defined by Points.
   --  Query coordinates are binary32 and may be fractional. Empty
   --  contours are Outside_Contour. Points is unchanged.
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

   --  Smallest circle enclosing Points. Center and Radius are binary32
   --  OpenCV results, including the native EPS added to radii. Empty
   --  contours return center (0, 0) and radius 0. One-point contours
   --  return that point as Center and the native EPS as Radius. Points
   --  is unchanged. Integer contours whose native signed-32-bit pair
   --  addition or subtraction would overflow raise OpenCV_Error. If a
   --  native center or radius component is non-finite, or if a successful
   --  native radius is negative, Minimum_Enclosing_Circle raises
   --  OpenCV_Error.
   type Enclosing_Circle is record
      Center : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      Radius : OpenCV.Float32_Value := 0.0;
   end record;

   function Minimum_Enclosing_Circle
     (Points : Contour) return Enclosing_Circle;

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
   --  OpenCV.OpenCV_Error.
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

end OpenCV.Geometry;
