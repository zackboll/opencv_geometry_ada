with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Subdiv2D;

--  Native capability queries, portable operations that work on every
--  supported OpenCV release, and the binding's error model.

procedure Compatibility_And_Safety is
   use OpenCV.Geometry;
   use type OpenCV.Float32_Value;
   use type OpenCV.Size_Coordinate;

   --  Native availability in the linked OpenCV, NOT Ada binding coverage:
   --  4.11 adds approxPolyN, 4.12 getClosestEllipsePoints, 4.13
   --  minEnclosingConvexPolygon and Rect2f subdivision bounds; 5.x has all.
   Polygon_N     : constant Boolean :=
     Is_Natively_Supported (Approximate_Convex_Polygon_Feature);
   Ellipse_Point : constant Boolean :=
     Is_Natively_Supported (Closest_Ellipse_Points_Feature);
   Enclosing     : constant Boolean :=
     Is_Natively_Supported (Minimum_Enclosing_Convex_Polygon_Feature);
   Float_Bounds  : constant Boolean :=
     Is_Natively_Supported (Float32_Subdivision_Bounds_Feature);

   --  Works on every release: native on 4.12+ and 5.x, a private
   --  compatibility implementation on 4.6 .. 4.11.
   Closest : constant Float32_Point_Array :=
     Closest_Ellipse_Points
       (Ellipse =>
          (Center        => (X => 0.0, Y => 0.0),
           Size          => (Width => 4.0, Height => 2.0),
           Angle_Degrees => 0.0),
        Points  => Float32_Point_Array'[(X => 10.0, Y => 0.0)]);

   Raised : Boolean;
begin
   --  The thresholds only grow with the release.
   pragma Assert (if Enclosing then Ellipse_Point and Polygon_N);
   pragma Assert (if Ellipse_Point then Polygon_N);
   pragma Assert (Float_Bounds = Enclosing);

   --  The point of the 4 x 2 ellipse (semi-axes 2 and 1) nearest (10, 0).
   pragma Assert (Closest'First = 0 and then Closest'Last = 0);
   pragma Assert (abs (Closest (0).X - 2.0) < 1.0E-3);
   pragma Assert (abs Closest (0).Y < 1.0E-3);

   --  Float32 subdivision bounds also work on every release.
   declare
      use OpenCV.Geometry.Subdiv2D;
      Plane : constant Subdivision :=
        Create_Float32 ((X => 0.5, Y => 0.5, Width => 9.0, Height => 9.0));
   begin
      pragma Assert (Bounds_Float32 (Plane).X = 0.5);
      --  Integer Bounds would have to round, so it raises instead.
      begin
         Raised := Bounds (Plane).Width = 0;
         Raised := False;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      pragma Assert (Raised);
   end;

   --  Rejected input raises OpenCV.OpenCV_Error; no partial result.
   begin
      Raised :=
        Fit_Ellipse (Contour'[(X => 0, Y => 0), (X => 1, Y => 1)]).Size.Width
        < 0.0;
      Raised := False;
   exception
      when OpenCV.OpenCV_Error =>
         Raised := True;
   end;
   pragma Assert (Raised);

   --  A declared but never created subdivision is not ready.
   declare
      use OpenCV.Geometry.Subdiv2D;
      Unused : Subdivision;
   begin
      pragma Assert (not Is_Ready (Unused));
      Raised := Insert (Unused, (X => 1.0, Y => 1.0)) = No_Vertex;
      Raised := False;
   exception
      when OpenCV.OpenCV_Error =>
         Raised := True;
   end;
   pragma Assert (Raised);
end Compatibility_And_Safety;
