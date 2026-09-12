with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Match_Shapes_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Float64_Value;
   use type OpenCV.Core.Point_Coordinate;
   use type OpenCV.Core.Point;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Absolute_Tolerance : constant OpenCV.Core.Float64_Value := 1.0E-12;
   Relative_Tolerance : constant OpenCV.Core.Float64_Value := 1.0E-9;

   L_Shape : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 6, Y => 0),
      (X => 6, Y => 2),
      (X => 2, Y => 2),
      (X => 2, Y => 5),
      (X => 0, Y => 5));

   T_Shape : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 8, Y => 0),
      (X => 8, Y => 2),
      (X => 5, Y => 2),
      (X => 5, Y => 6),
      (X => 3, Y => 6),
      (X => 3, Y => 2),
      (X => 0, Y => 2));

   Native_L_Vs_T_I1 : constant OpenCV.Core.Float64_Value :=
     0.39635522664611955;
   Native_L_Vs_T_I2 : constant OpenCV.Core.Float64_Value := 2.6179131665323814;
   Native_L_Vs_T_I3 : constant OpenCV.Core.Float64_Value :=
     0.60893324608629362;
   Native_T_Vs_L_I3 : constant OpenCV.Core.Float64_Value :=
     0.37847017430183305;

   function Close (Left, Right : OpenCV.Core.Float64_Value) return Boolean is
      Difference : constant OpenCV.Core.Float64_Value := abs (Left - Right);
      Scale      : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Value'Max (abs (Left), abs (Right));
   begin
      return
        Difference <= Absolute_Tolerance
        or else Difference <= Relative_Tolerance * Scale;
   end Close;

   function C_Close (Left, Right : Interfaces.C.double) return Boolean is
      Difference : constant Interfaces.C.double := abs (Left - Right);
      Scale      : constant Interfaces.C.double :=
        Interfaces.C.double'Max (abs (Left), abs (Right));
   begin
      return
        Difference <= Interfaces.C.double (Absolute_Tolerance)
        or else Difference <= Interfaces.C.double (Relative_Tolerance) * Scale;
   end C_Close;

   procedure Assert_Close
     (Actual, Expected : OpenCV.Core.Float64_Value; Message : String) is
   begin
      AUnit.Assertions.Assert (Close (Actual, Expected), Message);
   end Assert_Close;

   procedure Assert_C_Close
     (Actual, Expected : Interfaces.C.double; Message : String) is
   begin
      AUnit.Assertions.Assert (C_Close (Actual, Expected), Message);
   end Assert_C_Close;

   function Same_Contour (Left, Right : OpenCV.Geometry.Contour) return Boolean
   is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      if Left'Length = 0 then
         return True;
      end if;
      for Offset in 0 .. Left'Length - 1 loop
         if Left (Left'First + Offset) /= Right (Right'First + Offset) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Contour;

   function Transformed
     (Points : OpenCV.Geometry.Contour;
      Scale  : OpenCV.Core.Point_Coordinate;
      Swap   : Boolean;
      Neg_X  : Boolean;
      Neg_Y  : Boolean;
      DX, DY : OpenCV.Core.Point_Coordinate) return OpenCV.Geometry.Contour
   is
      Result : OpenCV.Geometry.Contour (Points'Range);
   begin
      for Index in Points'Range loop
         declare
            X : OpenCV.Core.Point_Coordinate := Points (Index).X * Scale;
            Y : OpenCV.Core.Point_Coordinate := Points (Index).Y * Scale;
            T : OpenCV.Core.Point_Coordinate;
         begin
            if Swap then
               T := X;
               X := Y;
               Y := T;
            end if;
            if Neg_X then
               X := -X;
            end if;
            if Neg_Y then
               Y := -Y;
            end if;
            Result (Index) := (X => X + DX, Y => Y + DY);
         end;
      end loop;
      return Result;
   end Transformed;

   procedure Identical_Shape (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, L_Shape, OpenCV.Geometry.Reciprocal_Log_Difference),
         0.0,
         "identical I1 score must be zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, L_Shape, OpenCV.Geometry.Log_Difference),
         0.0,
         "identical I2 score must be zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, L_Shape, OpenCV.Geometry.Relative_Log_Difference),
         0.0,
         "identical I3 score must be zero");
   end Identical_Shape;

   procedure Distinct_Shapes (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, T_Shape, OpenCV.Geometry.Reciprocal_Log_Difference),
         Native_L_Vs_T_I1,
         "L vs T I1 must match native OpenCV");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, T_Shape, OpenCV.Geometry.Log_Difference),
         Native_L_Vs_T_I2,
         "L vs T I2 must match native OpenCV");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, T_Shape, OpenCV.Geometry.Relative_Log_Difference),
         Native_L_Vs_T_I3,
         "L vs T I3 must match native OpenCV");
   end Distinct_Shapes;

   procedure Translation_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 1,
           Swap  => False,
           Neg_X => False,
           Neg_Y => False,
           DX    => -20,
           DY    => -7);
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Shifted, OpenCV.Geometry.Reciprocal_Log_Difference),
         0.0,
         "translated I1 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Shifted, OpenCV.Geometry.Log_Difference),
         0.0,
         "translated I2 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Shifted, OpenCV.Geometry.Relative_Log_Difference),
         0.0,
         "translated I3 must approach zero");
   end Translation_Invariance;

   procedure Scale_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Scaled : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 3,
           Swap  => False,
           Neg_X => False,
           Neg_Y => False,
           DX    => 0,
           DY    => 0);
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Scaled, OpenCV.Geometry.Reciprocal_Log_Difference),
         0.0,
         "scaled I1 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Scaled, OpenCV.Geometry.Log_Difference),
         0.0,
         "scaled I2 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Scaled, OpenCV.Geometry.Relative_Log_Difference),
         0.0,
         "scaled I3 must approach zero");
   end Scale_Invariance;

   procedure Rotation_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Rotated : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 1,
           Swap  => True,
           Neg_X => True,
           Neg_Y => False,
           DX    => 0,
           DY    => 0);
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Rotated, OpenCV.Geometry.Reciprocal_Log_Difference),
         0.0,
         "rotated I1 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Rotated, OpenCV.Geometry.Log_Difference),
         0.0,
         "rotated I2 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Rotated, OpenCV.Geometry.Relative_Log_Difference),
         0.0,
         "rotated I3 must approach zero");
   end Rotation_Invariance;

   procedure Reflection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Mirror : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 1,
           Swap  => False,
           Neg_X => True,
           Neg_Y => False,
           DX    => 0,
           DY    => 0);
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Mirror, OpenCV.Geometry.Reciprocal_Log_Difference),
         0.0,
         "reflected I1 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Mirror, OpenCV.Geometry.Log_Difference),
         0.0,
         "reflected I2 must approach zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Mirror, OpenCV.Geometry.Relative_Log_Difference),
         0.0,
         "reflected I3 must approach zero");
   end Reflection;

   procedure Relative_Directionality (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Forward  : constant OpenCV.Core.Float64_Value :=
        OpenCV.Geometry.Match_Shapes
          (L_Shape, T_Shape, OpenCV.Geometry.Relative_Log_Difference);
      Backward : constant OpenCV.Core.Float64_Value :=
        OpenCV.Geometry.Match_Shapes
          (T_Shape, L_Shape, OpenCV.Geometry.Relative_Log_Difference);
   begin
      Assert_Close (Forward, Native_L_Vs_T_I3, "L vs T I3 direction");
      Assert_Close (Backward, Native_T_Vs_L_I3, "T vs L I3 direction");
      AUnit.Assertions.Assert
        (not Close (Forward, Backward),
         "Relative_Log_Difference must be directional");
   end Relative_Directionality;

   procedure Symmetric_I1_I2 (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, T_Shape, OpenCV.Geometry.Reciprocal_Log_Difference),
         OpenCV.Geometry.Match_Shapes
           (T_Shape, L_Shape, OpenCV.Geometry.Reciprocal_Log_Difference),
         "I1 must be symmetric");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, T_Shape, OpenCV.Geometry.Log_Difference),
         OpenCV.Geometry.Match_Shapes
           (T_Shape, L_Shape, OpenCV.Geometry.Log_Difference),
         "I2 must be symmetric");
   end Symmetric_I1_I2;

   procedure Both_Degenerate (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
      Line  : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (Empty, Empty, OpenCV.Geometry.Reciprocal_Log_Difference),
         0.0,
         "empty vs empty I1 must be zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (Empty, Empty, OpenCV.Geometry.Log_Difference),
         0.0,
         "empty vs empty I2 must be zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (Empty, Empty, OpenCV.Geometry.Relative_Log_Difference),
         0.0,
         "empty vs empty I3 must be zero");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (Line, Empty, OpenCV.Geometry.Reciprocal_Log_Difference),
         0.0,
         "two all-zero Hu contours I1 must be zero");
   end Both_Degenerate;

   procedure One_Degenerate (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
      Line  : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Match_Shapes
           (Empty, L_Shape, OpenCV.Geometry.Reciprocal_Log_Difference)
         = OpenCV.Core.Float64_Value'Last,
         "empty vs ordinary I1 must be DBL_MAX");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Match_Shapes
           (L_Shape, Empty, OpenCV.Geometry.Log_Difference)
         = OpenCV.Core.Float64_Value'Last,
         "ordinary vs empty I2 must be DBL_MAX");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Match_Shapes
           (Line, L_Shape, OpenCV.Geometry.Relative_Log_Difference)
         = OpenCV.Core.Float64_Value'Last,
         "zero-area vs ordinary I3 must be DBL_MAX");
   end One_Degenerate;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left  : constant OpenCV.Geometry.Contour (5 .. 10) := L_Shape;
      Right : constant OpenCV.Geometry.Contour (2 .. 9) := T_Shape;
   begin
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (Left, Right, OpenCV.Geometry.Reciprocal_Log_Difference),
         Native_L_Vs_T_I1,
         "nonzero bounds I1 must match ordinary arrays");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (Left, Right, OpenCV.Geometry.Log_Difference),
         Native_L_Vs_T_I2,
         "nonzero bounds I2 must match ordinary arrays");
      Assert_Close
        (OpenCV.Geometry.Match_Shapes
           (Left, Right, OpenCV.Geometry.Relative_Log_Difference),
         Native_L_Vs_T_I3,
         "nonzero bounds I3 must match ordinary arrays");
   end Nonzero_Array_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original_Left  : constant OpenCV.Geometry.Contour := L_Shape;
      Original_Right : constant OpenCV.Geometry.Contour := T_Shape;
      pragma Warnings (Off, "could be declared constant");
      Left           : OpenCV.Geometry.Contour := Original_Left;
      Right          : OpenCV.Geometry.Contour := Original_Right;
      pragma Warnings (On, "could be declared constant");
      Score          : constant OpenCV.Core.Float64_Value :=
        OpenCV.Geometry.Match_Shapes
          (Left, Right, OpenCV.Geometry.Log_Difference);
   begin
      AUnit.Assertions.Assert
        (Same_Contour (Left, Original_Left),
         "Match_Shapes must leave Left unchanged");
      AUnit.Assertions.Assert
        (Same_Contour (Right, Original_Right),
         "Match_Shapes must leave Right unchanged");
      Assert_Close (Score, Native_L_Vs_T_I2, "unchanged inputs still match");
   end Input_Unchanged;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left   : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => 0),
         (X => 6, Y => 0),
         (X => 6, Y => 2),
         (X => 2, Y => 2),
         (X => 2, Y => 5),
         (X => 0, Y => 5));
      Right  : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => 0),
         (X => 8, Y => 0),
         (X => 8, Y => 2),
         (X => 5, Y => 2),
         (X => 5, Y => 6),
         (X => 3, Y => 6),
         (X => 3, Y => 2),
         (X => 0, Y => 2));
      Score  : aliased Interfaces.C.double := -1.0;
      Status : C_API.Status;

      procedure Assert_Rejected
        (Call_Status : C_API.Status; Needle : String; Message : String) is
      begin
         AUnit.Assertions.Assert
           (Call_Status = C_API.Error_Invalid_Argument, Message & ": status");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Needle) /= 0,
            Message & ": diagnostic");
         AUnit.Assertions.Assert (Score = 0.0, Message & ": score reset");
      end Assert_Rejected;
   begin
      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           -1,
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           C_API.Match_Shapes_Log_Difference,
           Score'Access);
      Assert_Rejected (Status, "left", "negative left count");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           -1,
           C_API.Match_Shapes_Log_Difference,
           Score'Access);
      Assert_Rejected (Status, "right", "negative right count");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (null,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           C_API.Match_Shapes_Log_Difference,
           Score'Access);
      Assert_Rejected (Status, "left", "null left pointer");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           null,
           Interfaces.Integer_32 (Right'Length),
           C_API.Match_Shapes_Log_Difference,
           Score'Access);
      Assert_Rejected (Status, "right", "null right pointer");

      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           C_API.Match_Shapes_Log_Difference,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "null output pointer must be rejected");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output") /= 0,
         "null output diagnostic must mention output");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           -1,
           Score'Access);
      Assert_Rejected (Status, "method", "invalid method -1");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           3,
           Score'Access);
      Assert_Rejected (Status, "method", "invalid method 3");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           C_API.Match_Shapes_Reciprocal_Log_Difference,
           Score'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "ABI I1 must succeed");
      Assert_C_Close
        (Score,
         Interfaces.C.double (Native_L_Vs_T_I1),
         "ABI I1 must match native OpenCV");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           C_API.Match_Shapes_Log_Difference,
           Score'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "ABI I2 must succeed");
      Assert_C_Close
        (Score,
         Interfaces.C.double (Native_L_Vs_T_I2),
         "ABI I2 must match native OpenCV");

      Score := -1.0;
      Status :=
        C_API.Match_Shapes
          (Left (Left'First)'Access,
           Interfaces.Integer_32 (Left'Length),
           Right (Right'First)'Access,
           Interfaces.Integer_32 (Right'Length),
           C_API.Match_Shapes_Relative_Log_Difference,
           Score'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "ABI I3 must succeed");
      Assert_C_Close
        (Score,
         Interfaces.C.double (Native_L_Vs_T_I3),
         "ABI I3 must match native OpenCV");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Match shapes identical shape", Identical_Shape'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes distinct shapes", Distinct_Shapes'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes translation invariance",
            Translation_Invariance'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes scale invariance", Scale_Invariance'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes rotation invariance", Rotation_Invariance'Access));
      Result.Add_Test
        (Caller.Create ("Match shapes reflection", Reflection'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes relative directionality",
            Relative_Directionality'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes I1 I2 symmetry", Symmetric_I1_I2'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes both degenerate", Both_Degenerate'Access));
      Result.Add_Test
        (Caller.Create ("Match shapes one degenerate", One_Degenerate'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes nonzero array bounds", Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes leaves input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Match shapes C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Match_Shapes_Tests;
