with OpenCV.Core;

package OpenCV.Geometry is

   subtype Contour is OpenCV.Core.Point_Array;

   --  Calculates the OpenCV polygon area of Points. When Oriented is False,
   --  the result is nonnegative; otherwise it retains OpenCV's orientation
   --  sign. Empty and degenerate contours return zero. Points is unchanged.
   function Contour_Area
     (Points : Contour; Oriented : Boolean := False)
      return OpenCV.Core.Float64_Value;

   --  Calculates the OpenCV curve length of Points. Closed includes the
   --  segment from the final point to the first. Empty and one-point contours
   --  return zero. Points is unchanged.
   function Arc_Length
     (Points : Contour; Closed : Boolean) return OpenCV.Core.Float64_Value;

   --  Spatial, central, and normalized central moments through third order
   --  for an Ada-owned contour. For ordinary non-self-intersecting contours,
   --  M_00 is the polygon area. A centroid, when meaningful, is
   --  (M_10 / M_00, M_01 / M_00); callers must handle M_00 = 0.0 themselves.
   --  Self-intersecting contours may have surprising moments because OpenCV
   --  uses Green's formula. Empty contours return an all-zero result. Points
   --  is unchanged.
   type Moments_Result is record
      M_00 : OpenCV.Core.Float64_Value := 0.0;
      M_10 : OpenCV.Core.Float64_Value := 0.0;
      M_01 : OpenCV.Core.Float64_Value := 0.0;
      M_20 : OpenCV.Core.Float64_Value := 0.0;
      M_11 : OpenCV.Core.Float64_Value := 0.0;
      M_02 : OpenCV.Core.Float64_Value := 0.0;
      M_30 : OpenCV.Core.Float64_Value := 0.0;
      M_21 : OpenCV.Core.Float64_Value := 0.0;
      M_12 : OpenCV.Core.Float64_Value := 0.0;
      M_03 : OpenCV.Core.Float64_Value := 0.0;

      Mu_20 : OpenCV.Core.Float64_Value := 0.0;
      Mu_11 : OpenCV.Core.Float64_Value := 0.0;
      Mu_02 : OpenCV.Core.Float64_Value := 0.0;
      Mu_30 : OpenCV.Core.Float64_Value := 0.0;
      Mu_21 : OpenCV.Core.Float64_Value := 0.0;
      Mu_12 : OpenCV.Core.Float64_Value := 0.0;
      Mu_03 : OpenCV.Core.Float64_Value := 0.0;

      Nu_20 : OpenCV.Core.Float64_Value := 0.0;
      Nu_11 : OpenCV.Core.Float64_Value := 0.0;
      Nu_02 : OpenCV.Core.Float64_Value := 0.0;
      Nu_30 : OpenCV.Core.Float64_Value := 0.0;
      Nu_21 : OpenCV.Core.Float64_Value := 0.0;
      Nu_12 : OpenCV.Core.Float64_Value := 0.0;
      Nu_03 : OpenCV.Core.Float64_Value := 0.0;
   end record;

   function Compute_Moments (Points : Contour) return Moments_Result;

   --  Convex hull of Points as an Ada-owned contour of hull points, not
   --  source-point indices. Orientation uses OpenCV's convention: X
   --  increases rightward and Y increases upward. Image coordinates often
   --  increase Y downward, so the visual winding may appear reversed.
   --  Empty input returns an empty contour. Points is unchanged.
   type Hull_Orientation is (Counterclockwise, Clockwise);

   function Convex_Hull
     (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
      return Contour;

   --  Approximates Points with Douglas-Peucker. Epsilon is the maximum
   --  distance between the original curve and the result and must be
   --  in the range 0.0 <= Epsilon < 1.0E30. Closed connects the last
   --  vertex to the first. The result is an Ada-owned contour. Empty
   --  input returns an empty contour. Points is unchanged.
   function Approximate_Curve
     (Points : Contour; Epsilon : OpenCV.Core.Float64_Value; Closed : Boolean)
      return Contour;

end OpenCV.Geometry;
