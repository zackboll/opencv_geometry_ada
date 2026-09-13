with Ada.Numerics;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Rotation_Matrix_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type OpenCV.Core.Channel_Count;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Float64_Value;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Core.Float32_Value);

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Core.Float64_Value);

   NaN_Bits_32   : constant Interfaces.Unsigned_32 := 16#7FC0_0000#;
   Inf_Bits_32   : constant Interfaces.Unsigned_32 := 16#7F80_0000#;
   Infinity_Bits : constant Interfaces.Unsigned_64 := 16#7FF0_0000_0000_0000#;
   Neg_Inf_Bits  : constant Interfaces.Unsigned_64 := 16#FFF0_0000_0000_0000#;
   NaN_Bits      : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;
   Coeff_Tol     : constant OpenCV.Core.Float64_Value := 1.0E-12;

   function Nearly_Equal
     (Left, Right : OpenCV.Core.Float64_Value;
      Tolerance   : OpenCV.Core.Float64_Value := Coeff_Tol) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Nearly_Equal;

   procedure Assert_Raises_OpenCV_Error
     (Attempt : not null access procedure; Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;

      AUnit.Assertions.Assert (Raised, Message);
   end Assert_Raises_OpenCV_Error;

   procedure Assert_Is_2x3_Float64_C1
     (Transform : OpenCV.Core.Mat; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Transform.Rows = 2
         and then Transform.Columns = 3
         and then Transform.Channels = 1
         and then Transform.Depth = OpenCV.Core.Float64,
         Message);
   end Assert_Is_2x3_Float64_C1;

   function Is_Finite_Coefficient
     (Transform : OpenCV.Core.Mat; Row, Column : Integer) return Boolean
   is
      Value : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Access.Get (Transform, Row, Column);
   begin
      return
        Value = Value
        and then Value >= OpenCV.Core.Float64_Value'First
        and then Value <= OpenCV.Core.Float64_Value'Last;
   end Is_Finite_Coefficient;

   procedure Assert_All_Coefficients_Finite
     (Transform : OpenCV.Core.Mat; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Is_Finite_Coefficient (Transform, 0, 0)
         and then Is_Finite_Coefficient (Transform, 0, 1)
         and then Is_Finite_Coefficient (Transform, 0, 2)
         and then Is_Finite_Coefficient (Transform, 1, 0)
         and then Is_Finite_Coefficient (Transform, 1, 1)
         and then Is_Finite_Coefficient (Transform, 1, 2),
         Message);
   end Assert_All_Coefficients_Finite;

   procedure Assert_Coefficients
     (Transform                    : OpenCV.Core.Mat;
      M00, M01, M02, M10, M11, M12 : OpenCV.Core.Float64_Value;
      Message                      : String) is
   begin
      AUnit.Assertions.Assert
        (Nearly_Equal (OpenCV.Core.Float64_Access.Get (Transform, 0, 0), M00)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 0, 1), M01)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 0, 2), M02)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 1, 0), M10)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 1, 1), M11)
         and then Nearly_Equal
                    (OpenCV.Core.Float64_Access.Get (Transform, 1, 2), M12),
         Message);
   end Assert_Coefficients;

   procedure Assert_Matrices_Match
     (Left, Right : OpenCV.Core.Mat; Message : String) is
   begin
      Assert_Coefficients
        (Left,
         OpenCV.Core.Float64_Access.Get (Right, 0, 0),
         OpenCV.Core.Float64_Access.Get (Right, 0, 1),
         OpenCV.Core.Float64_Access.Get (Right, 0, 2),
         OpenCV.Core.Float64_Access.Get (Right, 1, 0),
         OpenCV.Core.Float64_Access.Get (Right, 1, 1),
         OpenCV.Core.Float64_Access.Get (Right, 1, 2),
         Message);
   end Assert_Matrices_Match;

   procedure Identity_At_Origin (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D ((X => 0.0, Y => 0.0), 0.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform,
         "identity Get_Rotation_Matrix_2D must return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         1.0,
         0.0,
         0.0,
         0.0,
         1.0,
         0.0,
         "identity Get_Rotation_Matrix_2D must be [1 0 0; 0 1 0]");
   end Identity_At_Origin;

   procedure Zero_Angle_Nonzero_Center_Is_Identity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          ((X => 10.0, Y => 20.0), 0.0, 1.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform,
         "zero-angle rotation about a nonzero center must remain 2x3 Float64");
      Assert_Coefficients
        (Transform,
         1.0,
         0.0,
         0.0,
         0.0,
         1.0,
         0.0,
         "zero-angle Scale 1 must not invent a translation");
   end Zero_Angle_Nonzero_Center_Is_Identity;

   procedure Ninety_Degree_Coefficients (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Center    : constant OpenCV.Core.Float32_Point := (X => 10.0, Y => 20.0);
      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D (Center, 90.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "90-degree rotation must return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         0.0,
         1.0,
         -10.0,
         -1.0,
         0.0,
         30.0,
         "90-degree rotation must match the documented alpha/beta formula");
   end Ninety_Degree_Coefficients;

   procedure Scale_Around_Nonzero_Center (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          ((X => 10.0, Y => 20.0), 0.0, 2.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "scaled identity must remain a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         2.0,
         0.0,
         -10.0,
         0.0,
         2.0,
         -20.0,
         "Scale 2 about a nonzero center must scale around that center");
   end Scale_Around_Nonzero_Center;

   procedure Negative_Angle_Flips_Beta (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Center   : constant OpenCV.Core.Float32_Point := (X => 10.0, Y => 20.0);
      Positive : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D (Center, 90.0);
      Negative : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D (Center, -90.0);
      Pos_Beta : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Access.Get (Positive, 0, 1);
      Neg_Beta : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Access.Get (Negative, 0, 1);
   begin
      AUnit.Assertions.Assert
        (Pos_Beta > 0.0, "positive 90 degrees must produce a positive beta");
      AUnit.Assertions.Assert
        (Neg_Beta < 0.0, "negative 90 degrees must produce a negative beta");
      AUnit.Assertions.Assert
        (Nearly_Equal (Neg_Beta, -Pos_Beta),
         "negating the angle must negate beta");
   end Negative_Angle_Flips_Beta;

   procedure Radians_Match_Degrees (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Center  : constant OpenCV.Core.Float32_Point := (X => 7.5, Y => 3.25);
      Degrees : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          (Center, 90.0, 1.0, OpenCV.Core.Degrees);
      Radians : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          (Center,
           OpenCV.Core.Float64_Value (Ada.Numerics.Pi / 2.0),
           1.0,
           OpenCV.Core.Radians);
   begin
      Assert_Matrices_Match
        (Radians, Degrees, "pi/2 radians must match 90 degrees");
   end Radians_Match_Degrees;

   procedure Zero_Scale_Is_Accepted (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          ((X => 4.0, Y => 8.0), 0.0, 0.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "zero Scale must still return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         0.0,
         0.0,
         4.0,
         0.0,
         0.0,
         8.0,
         "zero Scale about a center must map that center to itself");
   end Zero_Scale_Is_Accepted;

   procedure Negative_Scale_Is_Accepted (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          ((X => 5.0, Y => 6.0), 0.0, -1.0);
   begin
      Assert_Is_2x3_Float64_C1
        (Transform, "negative Scale must still return a 2x3 Float64 C1 Mat");
      Assert_Coefficients
        (Transform,
         -1.0,
         0.0,
         10.0,
         0.0,
         -1.0,
         12.0,
         "negative finite Scale must remain accepted");
   end Negative_Scale_Is_Accepted;

   procedure Large_Finite_Angles_Are_Reduced (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Center         : constant OpenCV.Core.Float32_Point :=
        (X => 3.0, Y => 4.0);
      Large_Degrees  : constant OpenCV.Core.Float64_Value :=
        360.0 * 1.0E12 + 90.0;
      Reduced_Deg    : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Value'Remainder (Large_Degrees, 360.0);
      Two_Pi         : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Value (2.0)
        * OpenCV.Core.Float64_Value (Ada.Numerics.Pi);
      Large_Radians  : constant OpenCV.Core.Float64_Value :=
        Two_Pi
        * OpenCV.Core.Float64_Value (1.0E12)
        + OpenCV.Core.Float64_Value (Ada.Numerics.Pi / 2.0);
      Reduced_Rad    : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Value'Remainder (Large_Radians, Two_Pi);
      From_Large_Deg : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D (Center, Large_Degrees);
      From_Reduced_D : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D (Center, Reduced_Deg);
      From_Large_Rad : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          (Center, Large_Radians, 1.0, OpenCV.Core.Radians);
      From_Reduced_R : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          (Center, Reduced_Rad, 1.0, OpenCV.Core.Radians);
   begin
      Assert_Is_2x3_Float64_C1
        (From_Large_Deg, "large finite degrees must return 2x3 Float64 C1");
      Assert_All_Coefficients_Finite
        (From_Large_Deg, "large finite degrees must stay finite");
      Assert_Matrices_Match
        (From_Large_Deg,
         From_Reduced_D,
         "large finite degrees must match the reduced equivalent");

      Assert_Is_2x3_Float64_C1
        (From_Large_Rad, "large finite radians must return 2x3 Float64 C1");
      Assert_All_Coefficients_Finite
        (From_Large_Rad, "large finite radians must stay finite");
      Assert_Matrices_Match
        (From_Large_Rad,
         From_Reduced_R,
         "large finite radians must match the reduced equivalent");
   end Large_Finite_Angles_Are_Reduced;

   procedure Rejects_Invalid_Public_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Discard : OpenCV.Core.Mat;

      procedure Nan_Center_X is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (NaN_Bits_32);
         Discard :=
           OpenCV.Geometry.Get_Rotation_Matrix_2D
             ((X => Value, Y => 0.0), 0.0);
      end Nan_Center_X;

      procedure Inf_Center_Y is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float32_Value;
      begin
         Value := Bits_To_Float32 (Inf_Bits_32);
         Discard :=
           OpenCV.Geometry.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => Value), 0.0);
      end Inf_Center_Y;

      procedure Nan_Angle is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         Discard :=
           OpenCV.Geometry.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), Value);
      end Nan_Angle;

      procedure Inf_Angle is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Infinity_Bits);
         Discard :=
           OpenCV.Geometry.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), Value);
      end Inf_Angle;

      procedure Nan_Scale is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (NaN_Bits);
         Discard :=
           OpenCV.Geometry.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), 0.0, Value);
      end Nan_Scale;

      procedure Inf_Scale is
         pragma Suppress (Validity_Check);
         Value : OpenCV.Core.Float64_Value;
      begin
         Value := Bits_To_Float64 (Neg_Inf_Bits);
         Discard :=
           OpenCV.Geometry.Get_Rotation_Matrix_2D
             ((X => 0.0, Y => 0.0), 0.0, Value);
      end Inf_Scale;
   begin
      Assert_Raises_OpenCV_Error
        (Nan_Center_X'Access,
         "Get_Rotation_Matrix_2D must reject a NaN Center.X");
      Assert_Raises_OpenCV_Error
        (Inf_Center_Y'Access,
         "Get_Rotation_Matrix_2D must reject an infinite Center.Y");
      Assert_Raises_OpenCV_Error
        (Nan_Angle'Access, "Get_Rotation_Matrix_2D must reject a NaN Angle");
      Assert_Raises_OpenCV_Error
        (Inf_Angle'Access,
         "Get_Rotation_Matrix_2D must reject an infinite Angle");
      Assert_Raises_OpenCV_Error
        (Nan_Scale'Access, "Get_Rotation_Matrix_2D must reject a NaN Scale");
      Assert_Raises_OpenCV_Error
        (Inf_Scale'Access,
         "Get_Rotation_Matrix_2D must reject an infinite Scale");
   end Rejects_Invalid_Public_Inputs;

   procedure C_ABI_Rejects_Malformed_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);

      function Is_Zeroed (Output : C_API.C_Affine_2x3_F64) return Boolean is
      begin
         return
           Output.M00 = 0.0
           and then Output.M01 = 0.0
           and then Output.M02 = 0.0
           and then Output.M10 = 0.0
           and then Output.M11 = 0.0
           and then Output.M12 = 0.0;
      end Is_Zeroed;

      procedure Check
        (Center_X      : Interfaces.C.C_float;
         Center_Y      : Interfaces.C.C_float;
         Angle_Degrees : Interfaces.C.double;
         Scale         : Interfaces.C.double)
      is
         pragma Suppress (Validity_Check);
         Output : aliased C_API.C_Affine_2x3_F64;
         Status : C_API.Status;
      begin
         Output :=
           (M00 => 9.0,
            M01 => 9.0,
            M02 => 9.0,
            M10 => 9.0,
            M11 => 9.0,
            M12 => 9.0);
         Status :=
           C_API.Get_Rotation_Matrix_2D
             (Center_X, Center_Y, Angle_Degrees, Scale, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "malformed Get_Rotation_Matrix_2D C ABI input must return"
            & " invalid argument");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "finite") /= 0,
            "malformed Get_Rotation_Matrix_2D C ABI input must mention"
            & " finite");
         AUnit.Assertions.Assert
           (Is_Zeroed (Output),
            "malformed Get_Rotation_Matrix_2D C ABI input must zero output");
      end Check;

      procedure Check_Bits
        (Center_X_Bits : Interfaces.Unsigned_32;
         Center_Y_Bits : Interfaces.Unsigned_32;
         Angle_Bits    : Interfaces.Unsigned_64;
         Scale_Bits    : Interfaces.Unsigned_64)
      is
         pragma Suppress (Validity_Check);
         Center_X : constant Interfaces.C.C_float :=
           Interfaces.C.C_float (Bits_To_Float32 (Center_X_Bits));
         Center_Y : constant Interfaces.C.C_float :=
           Interfaces.C.C_float (Bits_To_Float32 (Center_Y_Bits));
         Angle    : constant Interfaces.C.double :=
           Interfaces.C.double (Bits_To_Float64 (Angle_Bits));
         Scale    : constant Interfaces.C.double :=
           Interfaces.C.double (Bits_To_Float64 (Scale_Bits));
      begin
         Check (Center_X, Center_Y, Angle, Scale);
      end Check_Bits;

      Output  : aliased C_API.C_Affine_2x3_F64;
      Status  : C_API.Status;
      Zero_32 : constant Interfaces.Unsigned_32 := 0;
      One_64  : constant Interfaces.Unsigned_64 := 16#3FF0_0000_0000_0000#;
   begin
      Status := C_API.Get_Rotation_Matrix_2D (0.0, 0.0, 0.0, 1.0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null output status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "null") /= 0,
         "null output diagnostic");

      Check_Bits (NaN_Bits_32, Zero_32, 0, One_64);
      Check_Bits (Zero_32, Inf_Bits_32, 0, One_64);
      Check_Bits (Zero_32, Zero_32, NaN_Bits, One_64);
      Check_Bits (Zero_32, Zero_32, Infinity_Bits, One_64);
      Check_Bits (Zero_32, Zero_32, 0, NaN_Bits);
      Check_Bits (Zero_32, Zero_32, 0, Neg_Inf_Bits);

      Output :=
        (M00 => 9.0,
         M01 => 9.0,
         M02 => 9.0,
         M10 => 9.0,
         M11 => 9.0,
         M12 => 9.0);
      Status :=
        C_API.Get_Rotation_Matrix_2D (0.0, 0.0, 0.0, 1.0, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success,
         "valid Get_Rotation_Matrix_2D C ABI input must succeed");
      AUnit.Assertions.Assert
        (Output.M00 = 1.0
         and then Output.M01 = 0.0
         and then Output.M02 = 0.0
         and then Output.M10 = 0.0
         and then Output.M11 = 1.0
         and then Output.M12 = 0.0,
         "valid Get_Rotation_Matrix_2D C ABI call must return identity");
   end C_ABI_Rejects_Malformed_Inputs;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D identity at origin",
            Identity_At_Origin'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D zero angle at nonzero center is identity",
            Zero_Angle_Nonzero_Center_Is_Identity'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D 90-degree coefficients",
            Ninety_Degree_Coefficients'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D scale around a nonzero center",
            Scale_Around_Nonzero_Center'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D negative angle flips beta",
            Negative_Angle_Flips_Beta'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D radians match degrees",
            Radians_Match_Degrees'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D zero scale is accepted",
            Zero_Scale_Is_Accepted'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D negative scale is accepted",
            Negative_Scale_Is_Accepted'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D large finite angles are reduced",
            Large_Finite_Angles_Are_Reduced'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D rejects invalid public inputs",
            Rejects_Invalid_Public_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Rotation_Matrix_2D C ABI rejects malformed inputs",
            C_ABI_Rejects_Malformed_Inputs'Access));
      return Result'Access;
   end Suite;

end Rotation_Matrix_Tests;
