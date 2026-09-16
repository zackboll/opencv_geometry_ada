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

   --  Returns OpenCV's native minimum-area rotated rectangle. Center, Size,
   --  and Angle_Degrees are binary32 native results; Angle_Degrees is in
   --  degrees. OpenCV 4.x and 5.x can encode an equivalent rectangle with
   --  different width, height, and angle fields, so callers must not assume
   --  one cross-version angle range. Empty and degenerate contours preserve
   --  the active backend representation. Points is unchanged. Inputs that
   --  would overflow native integer convex-hull arithmetic raise OpenCV_Error.
   function Minimum_Area_Rectangle
     (Points : Contour) return OpenCV.Rotated_Rect;

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
