with OpenCV;
with OpenCV.Geometry;

procedure Example is
   use type OpenCV.Float64_Value;
   Rectangle : constant OpenCV.Geometry.Contour :=
     [(X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3)];
   Perimeter : constant OpenCV.Float64_Value :=
     OpenCV.Geometry.Arc_Length (Rectangle, Closed => True);
   Hull      : constant OpenCV.Geometry.Contour :=
     OpenCV.Geometry.Convex_Hull (Rectangle);
begin
   pragma Assert (OpenCV.Geometry.Contour_Area (Rectangle) = 12.0);
   pragma Assert (Perimeter = 14.0);
   pragma Assert (OpenCV.Geometry.Is_Convex (Rectangle));
   pragma Assert (Hull'Length = 4);
end Example;
