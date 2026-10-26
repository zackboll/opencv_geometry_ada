with Ada.Text_IO;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry;

procedure Geometry_Core_Consumer is
   use type OpenCV.Float64_Value;
   use OpenCV.Geometry;

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
   declare
      Rotation    : constant Affine_Transform_2D :=
        Get_Rotation_Affine_Transform_2D ((0.0, 0.0), 90.0);
      Translation : constant Affine_Transform_2D :=
        ((1.0, 0.0, 5.0), (0.0, 1.0, 7.0));
      Combined    : constant Affine_Transform_2D :=
        Compose (Rotation, Translation);
      Homography  : constant Perspective_Transform_2D :=
        ((2.0, 0.0, 4.0), (0.0, 3.0, 6.0), (0.0, 0.0, 2.0));
      Inverse     : constant Perspective_Transform_2D :=
        Invert_Perspective_Transform (Homography);
      Identity    : constant Perspective_Transform_2D :=
        Compose (Homography, Inverse);
   begin
      pragma Assert (Affine_From_Mat (To_Mat (Combined)) = Combined);
      pragma Assert (Perspective_From_Mat (To_Mat (Homography)) = Homography);
      for R in Identity'Range (1) loop
         for C in Identity'Range (2) loop
            pragma
              Assert
                (abs (Identity (R, C) - Identity_Perspective_Transform (R, C))
                   < 1.0E-10);
         end loop;
      end loop;
   end;
   Ada.Text_IO.Put_Line ("PASS Geometry / Core 0.5.0 consumer");
end Geometry_Core_Consumer;
