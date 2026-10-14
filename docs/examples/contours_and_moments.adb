with OpenCV;
with OpenCV.Geometry;

--  Measures an L-shaped integer contour: area, length, moments, convexity,
--  hull, defects, approximation, bounding box, point location and matching.

procedure Contours_And_Moments is
   use OpenCV.Geometry;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Rect;

   --  Counterclockwise in OpenCV's convention (X right, Y up).
   Shape   : constant Contour :=
     [(X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 1),
      (X => 1, Y => 1),
      (X => 1, Y => 3),
      (X => 0, Y => 3)];
   Moments : constant Moments_Result := Compute_Moments (Shape);
   Hull    : constant Contour := Convex_Hull (Shape);
   Indices : constant Point_Index_Array := Convex_Hull_Indices (Shape);
   Defects : constant Convexity_Defect_Array := Convexity_Defects (Shape);
   Box     : constant OpenCV.Rect := Bounding_Rect (Shape);

   --  The same square outline with redundant midpoints on every side.
   Dense   : constant Contour :=
     [(X => 0, Y => 0),
      (X => 2, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 2),
      (X => 4, Y => 4),
      (X => 2, Y => 4),
      (X => 0, Y => 4),
      (X => 0, Y => 2)];
   Corners : constant Contour :=
     Approximate_Curve (Dense, Epsilon => 0.5, Closed => True);

   --  Shape moved by (10, 20): matching is translation invariant.
   Moved : Contour (Shape'Range);
begin
   pragma Assert (Contour_Area (Shape) = 6.0);
   pragma Assert (Arc_Length (Shape, Closed => True) = 14.0);
   pragma Assert (Moments.M_00 = 6.0);
   --  Centroid (M_10 / M_00, M_01 / M_00) of the two rectangles.
   pragma Assert (abs (Moments.M_10 / Moments.M_00 - 1.5) < 1.0E-12);
   pragma Assert (abs (Moments.M_01 / Moments.M_00 - 1.0) < 1.0E-12);

   pragma Assert (not Is_Convex (Shape));
   --  The concave vertex (1, 1) is not on the hull.
   pragma Assert (Hull'Length = 5 and then Hull'First = 0);
   pragma Assert (Indices'Length = Hull'Length);
   pragma Assert (for all Index of Indices => Index in Shape'Range);
   --  The notch at (1, 1), index 3 of Shape, is the deepest defect.
   pragma
     Assert
       (for some Defect of Defects =>
          Defect.Farthest_Index = 3 and then Defect.Depth in 1.6 .. 1.7);

   --  Inclusive integer extent: Width = 4 - 0 + 1, Height = 3 - 0 + 1.
   pragma Assert (Box = (X => 0, Y => 0, Width => 5, Height => 4));
   pragma Assert (Corners'Length = 4);

   pragma Assert (Locate_Point (Shape, (X => 0.5, Y => 2.0)) = Inside_Contour);
   pragma
     Assert (Locate_Point (Shape, (X => 2.0, Y => 0.0)) = On_Contour_Boundary);
   pragma
     Assert (Locate_Point (Shape, (X => 2.0, Y => 2.0)) = Outside_Contour);
   pragma
     Assert
       (abs (Signed_Distance_To_Contour (Shape, (X => 2.0, Y => 2.0)) + 1.0)
          < 1.0E-9);

   for Index in Shape'Range loop
      Moved (Index) := (X => Shape (Index).X + 10, Y => Shape (Index).Y + 20);
   end loop;
   pragma Assert (Match_Shapes (Shape, Moved, Log_Difference) < 1.0E-9);
end Contours_And_Moments;
