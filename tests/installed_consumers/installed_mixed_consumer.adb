with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with Geometry_Consumer_Checks;

--  Independent mixed Ada/C++ application. Its own C++ code calls OpenCV
--  directly; only plain values cross between the two languages.
procedure Installed_Mixed_Consumer is
   use type Interfaces.C.double;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;

   type Coordinates is array (Positive range <>) of Interfaces.C.int
   with Convention => C;

   function Application_Contour_Area
     (XY : Coordinates; Count : Interfaces.C.int) return Interfaces.C.double
   with Import, Convention => C, External_Name => "application_contour_area";

   Pentagon : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 8, Y => 0), (X => 10, Y => 6), (X => 4, Y => 10),
      (X => -2, Y => 6));
   Shared   : constant Natural := Geometry_Consumer_Checks.Run;
   XY       : Coordinates (1 .. 2 * Pentagon'Length);
   Next     : Positive := XY'First;
   Native   : Interfaces.C.double;
begin
   Ada.Text_IO.Put_Line ("shared check failures:" & Natural'Image (Shared));
   for Vertex of Pentagon loop
      XY (Next) := Interfaces.C.int (Vertex.X);
      XY (Next + 1) := Interfaces.C.int (Vertex.Y);
      Next := Next + 2;
   end loop;
   Native := Application_Contour_Area (XY, Pentagon'Length);
   Geometry_Consumer_Checks.Check
     (Native >= 0.0
      and then OpenCV.Geometry.Contour_Area (Pentagon)
               = OpenCV.Float64_Value (Native),
      "Contour_Area equals the application's own cv::contourArea");
   if Geometry_Consumer_Checks.Failures = 0 then
      Ada.Text_IO.Put_Line ("consumer PASS installed mixed Ada/C++");
   else
      Ada.Text_IO.Put_Line ("consumer FAIL installed mixed Ada/C++");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Installed_Mixed_Consumer;
