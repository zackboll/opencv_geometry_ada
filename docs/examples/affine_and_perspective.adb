with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry;

--  Builds affine and perspective transforms from correspondences, maps and
--  inverts points, and inspects a rotation matrix returned as a Core Mat.

procedure Affine_And_Perspective is
   use OpenCV.Geometry;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;

   function Near (Left, Right, Tolerance : OpenCV.Float64_Value) return Boolean
   is (abs (Left - Right) <= Tolerance);

   --  Scale X by 2 and Y by 3, then translate by (10, 20).
   Affine   : constant Affine_Transform_2D :=
     Get_Affine_Transform
       (Source      =>
          [(X => 0.0, Y => 0.0), (X => 1.0, Y => 0.0), (X => 0.0, Y => 1.0)],
        Destination =>
          [(X => 10.0, Y => 20.0),
           (X => 12.0, Y => 20.0),
           (X => 10.0, Y => 23.0)]);
   Inverse  : constant Affine_Transform_2D := Invert_Affine_Transform (Affine);
   Mapped   : constant OpenCV.Float32_Point :=
     Transform_Point (Affine, (X => 1.0, Y => 1.0));
   Restored : constant OpenCV.Float32_Point :=
     Transform_Point (Inverse, Mapped);

   --  A batch keeps the bounds of its input, here 5 .. 6.
   Batch   : constant Float32_Point_Array (5 .. 6) :=
     [(X => 0.0, Y => 0.0), (X => 2.0, Y => 1.0)];
   Results : constant Float32_Point_Array := Transform_Points (Affine, Batch);

   --  The unit square onto a trapezoid.
   Homography : constant Perspective_Transform_2D :=
     Get_Perspective_Transform
       (Source      =>
          [(X => 0.0, Y => 0.0),
           (X => 1.0, Y => 0.0),
           (X => 1.0, Y => 1.0),
           (X => 0.0, Y => 1.0)],
        Destination =>
          [(X => 0.0, Y => 0.0),
           (X => 4.0, Y => 0.0),
           (X => 3.0, Y => 2.0),
           (X => 1.0, Y => 2.0)]);
   Corner     : constant OpenCV.Float32_Point :=
     Transform_Point (Homography, (X => 1.0, Y => 1.0));

   --  A 90 degree rotation about the origin, as a 2 x 3 Float64 Mat.
   Rotation           : constant OpenCV.Core.Mat :=
     Get_Rotation_Matrix_2D (Center => (X => 0.0, Y => 0.0), Angle => 90.0);
   Rotation_Value     : constant Affine_Transform_2D :=
     Get_Rotation_Affine_Transform_2D ((0.0, 0.0), 90.0);
   --  Apply rotation first, then the scale-and-translate mapping.
   Combined           : constant Affine_Transform_2D :=
     Compose (Rotation_Value, Affine);
   Warp_Matrix        : constant OpenCV.Core.Mat := To_Mat (Combined);
   Homography_Inverse : constant Perspective_Transform_2D :=
     Invert_Perspective_Transform (Homography);
   Identity           : constant Perspective_Transform_2D :=
     Compose (Homography, Homography_Inverse);
begin
   pragma Assert (Affine_From_Mat (Rotation) = Rotation_Value);
   pragma Assert (Affine_From_Mat (Warp_Matrix) = Combined);
   pragma Assert (Perspective_From_Mat (To_Mat (Homography)) = Homography);
   for R in Identity'Range (1) loop
      for C in Identity'Range (2) loop
         pragma
           Assert
             (Near
                (Identity (R, C),
                 Identity_Perspective_Transform (R, C),
                 1.0E-10));
      end loop;
   end loop;
   pragma Assert (Near (Affine (1, 1), 2.0, 1.0E-9));
   pragma Assert (Near (Affine (2, 2), 3.0, 1.0E-9));
   pragma Assert (Near (Affine (1, 3), 10.0, 1.0E-9));
   pragma Assert (Near (Affine (2, 3), 20.0, 1.0E-9));
   pragma Assert (Near (Affine (1, 2), 0.0, 1.0E-9));
   pragma Assert (Mapped = (X => 12.0, Y => 23.0));
   pragma Assert (abs (Restored.X - 1.0) < 1.0E-5);
   pragma Assert (abs (Restored.Y - 1.0) < 1.0E-5);

   pragma Assert (Results'First = 5 and then Results'Last = 6);
   pragma Assert (Results (5) = (X => 10.0, Y => 20.0));
   pragma Assert (Results (6) = (X => 14.0, Y => 23.0));

   --  The mapping holds whatever overall scale OpenCV gives the solution.
   pragma Assert (abs (Corner.X - 3.0) < 1.0E-4);
   pragma Assert (abs (Corner.Y - 2.0) < 1.0E-4);

   pragma
     Assert
       (OpenCV.Core.Rows (Rotation) = 2
          and then OpenCV.Core.Columns (Rotation) = 3);
   pragma
     Assert
       (Near (OpenCV.Core.Float64_Access.Get (Rotation, 0, 0), 0.0, 1.0E-12));
   pragma
     Assert
       (Near (OpenCV.Core.Float64_Access.Get (Rotation, 0, 1), 1.0, 1.0E-12));
   pragma
     Assert
       (Near (OpenCV.Core.Float64_Access.Get (Rotation, 1, 0), -1.0, 1.0E-12));
end Affine_And_Perspective;
