with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces.C;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Hu_Moments_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type OpenCV.Core.Float64_Value;
   use type OpenCV.Core.Point_Coordinate;
   use type OpenCV.Geometry.Hu_Moment_Index;

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

   Native_L_Hu : constant OpenCV.Geometry.Hu_Moments_Result :=
     (1 => 0.27006172839506176,
      2 => 0.01924487501905198,
      3 => 0.009643591668689451,
      4 => 0.00079971247984254,
      5 => -1.2989965729901028E-06,
      6 => -6.3303311766766415E-05,
      7 => -1.8013342596489417E-06);

   function Close (Left, Right : OpenCV.Core.Float64_Value) return Boolean is
      Difference : constant OpenCV.Core.Float64_Value := abs (Left - Right);
      Scale      : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Value'Max (abs (Left), abs (Right));
   begin
      return
        Difference <= Absolute_Tolerance
        or else Difference <= Relative_Tolerance * Scale;
   end Close;

   procedure Assert_Close
     (Actual, Expected : OpenCV.Core.Float64_Value; Message : String) is
   begin
      AUnit.Assertions.Assert (Close (Actual, Expected), Message);
   end Assert_Close;

   procedure Assert_Hu
     (Actual, Expected : OpenCV.Geometry.Hu_Moments_Result; Message : String)
   is
   begin
      for Index in OpenCV.Geometry.Hu_Moment_Index loop
         Assert_Close
           (Actual (Index),
            Expected (Index),
            Message & ": Hu_" & OpenCV.Geometry.Hu_Moment_Index'Image (Index));
      end loop;
   end Assert_Hu;

   function Same_Moments
     (Left, Right : OpenCV.Geometry.Moments_Result) return Boolean is
   begin
      return
        Left.M_00 = Right.M_00
        and then Left.M_10 = Right.M_10
        and then Left.M_01 = Right.M_01
        and then Left.M_20 = Right.M_20
        and then Left.M_11 = Right.M_11
        and then Left.M_02 = Right.M_02
        and then Left.M_30 = Right.M_30
        and then Left.M_21 = Right.M_21
        and then Left.M_12 = Right.M_12
        and then Left.M_03 = Right.M_03
        and then Left.Mu_20 = Right.Mu_20
        and then Left.Mu_11 = Right.Mu_11
        and then Left.Mu_02 = Right.Mu_02
        and then Left.Mu_30 = Right.Mu_30
        and then Left.Mu_21 = Right.Mu_21
        and then Left.Mu_12 = Right.Mu_12
        and then Left.Mu_03 = Right.Mu_03
        and then Left.Nu_20 = Right.Nu_20
        and then Left.Nu_11 = Right.Nu_11
        and then Left.Nu_02 = Right.Nu_02
        and then Left.Nu_30 = Right.Nu_30
        and then Left.Nu_21 = Right.Nu_21
        and then Left.Nu_12 = Right.Nu_12
        and then Left.Nu_03 = Right.Nu_03;
   end Same_Moments;

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

   procedure Result_Shape (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Zero : constant OpenCV.Geometry.Moments_Result := (others => <>);
      Hu   : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (Zero);
   begin
      AUnit.Assertions.Assert
        (Hu'First = 1 and then Hu'Last = 7 and then Hu'Length = 7,
         "Hu result must be indexed 1 .. 7");
   end Result_Shape;

   procedure All_Zero_Moments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Zero : constant OpenCV.Geometry.Moments_Result := (others => <>);
      Hu   : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (Zero);
   begin
      for Index in OpenCV.Geometry.Hu_Moment_Index loop
         AUnit.Assertions.Assert
           (Hu (Index) = 0.0, "all-zero moments must yield zero Hu values");
      end loop;
   end All_Zero_Moments;

   procedure Synthetic_Normalized_Moments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Moments  : constant OpenCV.Geometry.Moments_Result :=
        (Nu_20  => 0.1,
         Nu_11  => 0.2,
         Nu_02  => 0.3,
         Nu_30  => 0.4,
         Nu_21  => 0.5,
         Nu_12  => 0.6,
         Nu_03  => 0.7,
         others => <>);
      Expected : constant OpenCV.Geometry.Hu_Moments_Result :=
        (1 => 0.40000000000000002,
         2 => 0.20000000000000001,
         3 => 2.5999999999999996,
         4 => 2.4399999999999999,
         5 => 6.1456,
         6 => 1.048,
         7 => -0.035200000000001008);
   begin
      Assert_Hu
        (OpenCV.Geometry.Hu_Moments (Moments),
         Expected,
         "synthetic Nu fields must produce OpenCV Hu order and values");
   end Synthetic_Normalized_Moments;

   procedure Simple_Nu20_Case (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Moments : constant OpenCV.Geometry.Moments_Result :=
        (Nu_20 => 1.0, others => <>);
      Hu      : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (Moments);
   begin
      Assert_Close (Hu (1), 1.0, "nu20-only Hu_1 must be 1");
      Assert_Close (Hu (2), 1.0, "nu20-only Hu_2 must be 1");
      for Index in OpenCV.Geometry.Hu_Moment_Index range 3 .. 7 loop
         Assert_Close (Hu (Index), 0.0, "nu20-only remaining Hu must be 0");
      end loop;
   end Simple_Nu20_Case;

   procedure Compute_Moments_Integration (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Moments : constant OpenCV.Geometry.Moments_Result :=
        OpenCV.Geometry.Compute_Moments (L_Shape);
      Hu      : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (Moments);
   begin
      Assert_Hu (Hu, Native_L_Hu, "L-shape Hu must match native OpenCV");
      AUnit.Assertions.Assert
        (abs (Hu (7)) > 1.0E-7,
         "L-shape seventh invariant must be meaningfully nonzero");
   end Compute_Moments_Integration;

   procedure Translation_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (L_Shape));
      Shifted  : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 1,
           Swap  => False,
           Neg_X => False,
           Neg_Y => False,
           DX    => -11,
           DY    => 8);
      Moved    : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (Shifted));
   begin
      Assert_Hu (Moved, Original, "translated L-shape Hu must match");
   end Translation_Invariance;

   procedure Scale_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (L_Shape));
      Scaled   : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 3,
           Swap  => False,
           Neg_X => False,
           Neg_Y => False,
           DX    => 0,
           DY    => 0);
      Grown    : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (Scaled));
   begin
      Assert_Hu (Grown, Original, "scaled L-shape Hu must match");
   end Scale_Invariance;

   procedure Rotation_Invariance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (L_Shape));
      Rotated  : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 1,
           Swap  => True,
           Neg_X => True,
           Neg_Y => False,
           DX    => 0,
           DY    => 0);
      Turned   : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (Rotated));
   begin
      Assert_Hu (Turned, Original, "90-degree rotated L-shape Hu must match");
   end Rotation_Invariance;

   procedure Reflection_Seventh_Sign (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original  : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (L_Shape));
      Mirror    : constant OpenCV.Geometry.Contour :=
        Transformed
          (L_Shape,
           Scale => 1,
           Swap  => False,
           Neg_X => True,
           Neg_Y => False,
           DX    => 0,
           DY    => 0);
      Reflected : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (Mirror));
   begin
      for Index in OpenCV.Geometry.Hu_Moment_Index range 1 .. 6 loop
         Assert_Close
           (Reflected (Index),
            Original (Index),
            "reflected Hu_1..6 must match");
      end loop;
      Assert_Close
        (Reflected (7),
         -Original (7),
         "seventh Hu invariant must change sign under reflection");
      AUnit.Assertions.Assert
        (Original (7) /= 0.0, "reference seventh invariant must be nonzero");
   end Reflection_Seventh_Sign;

   procedure Degenerate_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty   : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
      Line    : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
      Hu      : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (Empty));
      Line_Hu : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (Line));
   begin
      for Index in OpenCV.Geometry.Hu_Moment_Index loop
         AUnit.Assertions.Assert
           (Hu (Index) = 0.0, "empty contour Hu must be zero");
         AUnit.Assertions.Assert
           (Line_Hu (Index) = 0.0, "zero-area contour Hu must be zero");
      end loop;
   end Degenerate_Contour;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Moments_Result :=
        OpenCV.Geometry.Compute_Moments (L_Shape);
      pragma Warnings (Off, "could be declared constant");
      Moments  : OpenCV.Geometry.Moments_Result := Original;
      pragma Warnings (On, "could be declared constant");
      Hu       : constant OpenCV.Geometry.Hu_Moments_Result :=
        OpenCV.Geometry.Hu_Moments (Moments);
   begin
      AUnit.Assertions.Assert
        (Same_Moments (Moments, Original),
         "Hu_Moments must leave the input Moments_Result unchanged");
      Assert_Hu (Hu, Native_L_Hu, "unchanged input must still produce L Hu");
   end Input_Unchanged;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Output : aliased C_API.C_Hu_Result :=
        (Hu_1 => -1.0,
         Hu_2 => -1.0,
         Hu_3 => -1.0,
         Hu_4 => -1.0,
         Hu_5 => -1.0,
         Hu_6 => -1.0,
         Hu_7 => -1.0);
      Input  : aliased C_API.C_Moments :=
        (Nu20   => 0.1,
         Nu11   => 0.2,
         Nu02   => 0.3,
         Nu30   => 0.4,
         Nu21   => 0.5,
         Nu12   => 0.6,
         Nu03   => 0.7,
         others => 0.0);
      Status : C_API.Status;

      procedure Assert_C_Zero (Value : C_API.C_Hu_Result; Message : String) is
      begin
         AUnit.Assertions.Assert
           (Value.Hu_1 = 0.0
            and then Value.Hu_2 = 0.0
            and then Value.Hu_3 = 0.0
            and then Value.Hu_4 = 0.0
            and then Value.Hu_5 = 0.0
            and then Value.Hu_6 = 0.0
            and then Value.Hu_7 = 0.0,
            Message);
      end Assert_C_Zero;
   begin
      Status := C_API.Hu_Moments (null, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "input")
                  /= 0,
         "null Hu moments input pointer must be rejected");
      Assert_C_Zero (Output, "null input must initialize Hu output to zero");

      Status := C_API.Hu_Moments (Input'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null Hu moments output pointer must be rejected");

      Output :=
        (Hu_1 => -1.0,
         Hu_2 => -1.0,
         Hu_3 => -1.0,
         Hu_4 => -1.0,
         Hu_5 => -1.0,
         Hu_6 => -1.0,
         Hu_7 => -1.0);
      Status := C_API.Hu_Moments (Input'Access, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "valid Hu moments ABI call must succeed");
      AUnit.Assertions.Assert
        (Output.Hu_1 = 0.40000000000000002
         and then Output.Hu_2 = 0.20000000000000001
         and then Output.Hu_3 = 2.5999999999999996
         and then Output.Hu_4 = 2.4399999999999999
         and then Output.Hu_5 = 6.1456
         and then Output.Hu_6 = 1.048
         and then Output.Hu_7 = -0.035200000000001008,
         "C ABI must return raw Hu values in OpenCV order");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Hu moments result shape", Result_Shape'Access));
      Result.Add_Test
        (Caller.Create ("Hu moments all-zero input", All_Zero_Moments'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments synthetic normalized moments",
            Synthetic_Normalized_Moments'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments simple nu20 case", Simple_Nu20_Case'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments Compute_Moments integration",
            Compute_Moments_Integration'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments translation invariance",
            Translation_Invariance'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments scale invariance", Scale_Invariance'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments rotation invariance", Rotation_Invariance'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments reflection seventh sign",
            Reflection_Seventh_Sign'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments degenerate contour", Degenerate_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments leaves input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Hu moments C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Hu_Moments_Tests;
