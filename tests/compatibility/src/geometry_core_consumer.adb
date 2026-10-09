with Ada.Text_IO;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry;

procedure Geometry_Core_Consumer is
   use type OpenCV.Float64_Value;

   Points : constant OpenCV.Point_Array (7 .. 10) :=
     ((0, 0), (4, 0), (4, 3), (0, 3));
   Copy   : OpenCV.Core.Mat;
begin
   pragma Assert (OpenCV.Geometry.Contour_Area (Points) = 12.0);
   declare
      Rotation : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D ((0.0, 0.0), 0.0);
   begin
      Copy := Rotation;
   end;
   --  The returned Core-owned Mat survives the original header's lifetime.
   pragma Assert (Copy.Rows = 2 and then Copy.Columns = 3);
   pragma Assert (OpenCV.Core.Float64_Access.Get (Copy, 0, 0) = 1.0);
   OpenCV.Core.Float64_Access.Set (Copy, 0, 2, 5.0);
   pragma Assert (OpenCV.Core.Float64_Access.Get (Copy, 0, 2) = 5.0);
   Ada.Text_IO.Put_Line ("PASS Geometry / Core 0.4.1 consumer");
end Geometry_Core_Consumer;
