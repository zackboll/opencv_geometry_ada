with OpenCV;
with OpenCV.Geometry;

--  Fits and encloses well-conditioned point sets, then intersects convex
--  polygons and rotated rectangles. Checks use tolerances where OpenCV
--  computes in binary32, and never a native vertex order.

procedure Fitting_And_Intersections is
   use OpenCV.Geometry;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;

   function Near (Left, Right, Tolerance : OpenCV.Float32_Value) return Boolean
   is (abs (Left - Right) <= Tolerance);

   --  A 4 x 2 axis-aligned rectangle, possibly reported rotated by 90
   --  degrees, depending on the OpenCV release's angle convention.
   Corners   : constant Contour :=
     [(X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 2), (X => 0, Y => 2)];
   Rectangle : constant OpenCV.Rotated_Rect :=
     Minimum_Area_Rectangle (Corners);
   Vertices  : constant Box_Vertices := Box_Points (Rectangle);

   --  Eight points on two concentric circles around (5, 5), not on one
   --  conic, so the ellipse fit needs no random perturbation.
   Ring    : constant Contour :=
     [(X => 15, Y => 5),
      (X => 12, Y => 12),
      (X => 5, Y => 15),
      (X => -2, Y => 12),
      (X => -5, Y => 5),
      (X => -2, Y => -2),
      (X => 5, Y => -5),
      (X => 12, Y => -2)];
   Ellipse : constant OpenCV.Rotated_Rect := Fit_Ellipse (Ring);

   --  Overloaded operations need a qualified aggregate.
   Line   : constant Fitted_Line_2D :=
     Fit_Line_2D
       (Contour'
          [(X => 0, Y => 1),
           (X => 2, Y => 3),
           (X => 4, Y => 5),
           (X => 6, Y => 7)]);
   Circle : constant Enclosing_Circle :=
     Minimum_Enclosing_Circle
       (Contour'
          [(X => 0, Y => 0),
           (X => 4, Y => 0),
           (X => 4, Y => 4),
           (X => 0, Y => 4)]);

   Overlap  : constant Convex_Polygon_Intersection :=
     Intersect_Convex_Polygons
       (Left  =>
          Contour'
            [(X => 0, Y => 0),
             (X => 4, Y => 0),
             (X => 4, Y => 4),
             (X => 0, Y => 4)],
        Right =>
          Contour'
            [(X => 2, Y => 2),
             (X => 6, Y => 2),
             (X => 6, Y => 6),
             (X => 2, Y => 6)]);
   Crossing : constant Rotated_Rectangle_Intersection :=
     Intersect_Rotated_Rectangles
       ((Center        => (X => 0.0, Y => 0.0),
         Size          => (Width => 4.0, Height => 4.0),
         Angle_Degrees => 0.0),
        (Center        => (X => 2.0, Y => 0.0),
         Size          => (Width => 4.0, Height => 4.0),
         Angle_Degrees => 0.0));
begin
   --  The area is version independent; Width and Height may be swapped.
   pragma
     Assert (Near (Rectangle.Size.Width * Rectangle.Size.Height, 8.0, 1.0E-4));
   pragma Assert (Near (Rectangle.Center.X, 2.0, 1.0E-4));
   pragma Assert (Near (Rectangle.Center.Y, 1.0, 1.0E-4));
   --  Every box vertex is a rectangle corner, whatever the starting vertex.
   pragma
     Assert
       (for all Vertex of Vertices =>
          (for some Corner of Corners =>
             Near (Vertex.X, OpenCV.Float32_Value (Corner.X), 1.0E-4)
             and then Near
                        (Vertex.Y, OpenCV.Float32_Value (Corner.Y), 1.0E-4)));

   --  Full axis lengths, not radii.
   pragma Assert (Near (Ellipse.Center.X, 5.0, 0.1));
   pragma Assert (Near (Ellipse.Center.Y, 5.0, 0.1));
   pragma Assert (Ellipse.Size.Width in 19.0 .. 21.0);
   pragma Assert (Ellipse.Size.Height in 19.0 .. 21.0);

   --  A unit direction along Y = X + 1, through the centroid (3, 4).
   pragma Assert (Near (abs Line.Direction.X, 0.70710677, 1.0E-5));
   pragma Assert (Near (Line.Direction.X, Line.Direction.Y, 1.0E-5));
   pragma Assert (Near (Line.Point.X, 3.0, 1.0E-4));
   pragma Assert (Near (Line.Point.Y, 4.0, 1.0E-4));

   --  The circumscribed circle of the square, radius 2 * Sqrt (2) plus
   --  OpenCV's small EPS.
   pragma Assert (Near (Circle.Center.X, 2.0, 1.0E-3));
   pragma Assert (Near (Circle.Center.Y, 2.0, 1.0E-3));
   pragma Assert (Near (Circle.Radius, 2.828427, 1.0E-3));

   --  The two squares overlap in the square (2, 2) .. (4, 4).
   pragma Assert (Near (Overlap.Area, 4.0, 1.0E-4));
   pragma Assert (Overlap.Vertex_Count in 4 .. 8);
   pragma
     Assert
       (for all Vertex of Overlap.Vertices =>
          Vertex.X in 2.0 .. 4.0 and then Vertex.Y in 2.0 .. 4.0);

   pragma Assert (Crossing.Kind = Partial_Intersection);
   pragma Assert (Crossing.Vertex_Count >= 3);
end Fitting_And_Intersections;
