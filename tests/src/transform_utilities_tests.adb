with Ada.Numerics;
with Ada.Unchecked_Conversion;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry;  use OpenCV.Geometry;

package body Transform_Utilities_Tests is
   subtype F64 is OpenCV.Float64_Value;
   type F64_Array is array (Positive range <>) of F64;
   package Access_64 renames OpenCV.Core.Float64_Access;
   use type F64;
   use type OpenCV.Float32_Value;
   use type OpenCV.Core.Depth_Type;
   use type OpenCV.Core.Channel_Count;
   use type Interfaces.Unsigned_64;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result   : aliased AUnit.Test_Suites.Test_Suite;
   function From_Bits is new
     Ada.Unchecked_Conversion (Interfaces.Unsigned_64, F64);
   function To_Bits is new
     Ada.Unchecked_Conversion (F64, Interfaces.Unsigned_64);
   type Bit_Array is array (Positive range <>) of Interfaces.Unsigned_64;
   Specials : constant Bit_Array :=
     (16#7FF8_0000_0000_0000#,
      16#7FF0_0000_0000_0000#,
      16#FFF0_0000_0000_0000#);
   A        : constant Affine_Transform_2D :=
     ((2.0, 0.25, 10.0), (-0.5, 3.0, -20.0));
   H        : constant Perspective_Transform_2D :=
     ((2.0, 0.25, 1.0), (-0.5, 3.0, -2.0), (0.01, -0.02, 2.0));

   procedure Raises (Attempt : not null access procedure; Message : String) is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      Assert (Raised, Message);
   end Raises;

   function Homogeneous
     (Value : Affine_Transform_2D) return Perspective_Transform_2D
   is
      M : Perspective_Transform_2D := Identity_Perspective_Transform;
   begin
      for R in Value'Range (1) loop
         for C in Value'Range (2) loop
            M (Perspective_Row_Index (R), C) := Value (R, C);
         end loop;
      end loop;
      return M;
   end Homogeneous;

   procedure Near
     (Actual, Expected : Perspective_Transform_2D; Tolerance : F64 := 1.0E-12)
   is
   begin
      for R in Actual'Range (1) loop
         for C in Actual'Range (2) loop
            Assert
              (abs (Actual (R, C) - Expected (R, C)) <= Tolerance,
               "matrix coefficient residual");
         end loop;
      end loop;
   end Near;

   procedure Mat_Round_Trips (T : in out Fixture) is
      pragma Unreferenced (T);
      X : Affine_Transform_2D := A;
      Y : Perspective_Transform_2D := H;
   begin
      X (1, 2) := From_Bits (16#8000_0000_0000_0000#);
      X (2, 1) := 1.0E-300;
      Y (3, 1) := 1.0E-300;
      Y (3, 2) := From_Bits (16#8000_0000_0000_0000#);
      declare
         M  : constant OpenCV.Core.Mat := To_Mat (X);
         N  : constant OpenCV.Core.Mat := To_Mat (Y);
         XA : constant Affine_Transform_2D := Affine_From_Mat (M);
         YH : constant Perspective_Transform_2D := Perspective_From_Mat (N);
      begin
         Assert
           (M.Rows = 2
            and then M.Columns = 3
            and then M.Dimension_Count = 2
            and then M.Depth = OpenCV.Core.Float64
            and then M.Channels = 1,
            "affine output metadata");
         Assert
           (N.Rows = 3
            and then N.Columns = 3
            and then N.Dimension_Count = 2
            and then N.Depth = OpenCV.Core.Float64
            and then N.Channels = 1,
            "perspective output metadata");
         for R in X'Range (1) loop
            for C in X'Range (2) loop
               Assert
                 (To_Bits (XA (R, C)) = To_Bits (X (R, C)),
                  "affine exact bit round trip");
            end loop;
         end loop;
         for R in Y'Range (1) loop
            for C in Y'Range (2) loop
               Assert
                 (To_Bits (YH (R, C)) = To_Bits (Y (R, C)),
                  "perspective exact bit round trip");
            end loop;
         end loop;
      end;
      Assert
        (Affine_From_Mat (To_Mat (Identity_Affine_Transform))
         = Identity_Affine_Transform,
         "affine identity round trip");
      Assert
        (Perspective_From_Mat (To_Mat (Identity_Perspective_Transform))
         = Identity_Perspective_Transform,
         "perspective identity round trip");
   end Mat_Round_Trips;

   procedure Mat_Ownership (T : in out Fixture) is
      pragma Unreferenced (T);
      Saved_A : Affine_Transform_2D;
      Saved_H : Perspective_Transform_2D;
   begin
      declare
         M     : OpenCV.Core.Mat := To_Mat (A);
         N     : OpenCV.Core.Mat := To_Mat (H);
         Other : constant OpenCV.Core.Mat := To_Mat (A);
      begin
         Saved_A := Affine_From_Mat (M);
         Saved_H := Perspective_From_Mat (N);
         Access_64.Set (M, 0, 0, 99.0);
         Access_64.Set (N, 0, 0, 99.0);
         Assert (Affine_From_Mat (Other) = A, "new Mats are independent");
         M := To_Mat (Identity_Affine_Transform);
         N := To_Mat (Identity_Perspective_Transform);
      end;
      Assert
        (Saved_A = A and then Saved_H = H,
         "values survive mutation, rebinding and source finalization");
      declare
         M : OpenCV.Core.Mat := To_Mat (Saved_H);
         N : constant OpenCV.Core.Mat := To_Mat (Saved_H);
      begin
         Access_64.Set (M, 2, 2, 17.0);
         Assert
           (Perspective_From_Mat (N) = H and then Saved_H = H,
            "conversion back creates independent storage");
      end;
   end Mat_Ownership;

   procedure Mat_Regions (T : in out Fixture) is
      pragma Unreferenced (T);
      Parent        : constant OpenCV.Core.Mat :=
        OpenCV.Core.Create (5, 7, (OpenCV.Core.Float64, 1));
      Region        : OpenCV.Core.Mat := Parent.Region ((1, 1, 3, 3));
      Affine_Region : constant OpenCV.Core.Mat := Parent.Region ((1, 1, 3, 2));
   begin
      Assert
        (not Region.Is_Continuous and then not Affine_Region.Is_Continuous,
         "test exercises row strides");
      for R in H'Range (1) loop
         for C in H'Range (2) loop
            Access_64.Set (Region, Integer (R) - 1, Integer (C) - 1, H (R, C));
         end loop;
      end loop;
      Assert (Perspective_From_Mat (Region) = H, "strided perspective copy");
      for R in A'Range (1) loop
         for C in A'Range (2) loop
            Access_64.Set (Region, Integer (R) - 1, Integer (C) - 1, A (R, C));
         end loop;
      end loop;
      Assert (Affine_From_Mat (Affine_Region) = A, "strided affine copy");
   end Mat_Regions;

   procedure Mat_Invalid_Metadata (T : in out Fixture) is
      pragma Unreferenced (T);
      M : OpenCV.Core.Mat;
      procedure Read_A is
         V : constant Affine_Transform_2D := Affine_From_Mat (M);
         pragma Unreferenced (V);
      begin
         null;
      end Read_A;
      procedure Read_H is
         V : constant Perspective_Transform_2D := Perspective_From_Mat (M);
         pragma Unreferenced (V);
      begin
         null;
      end Read_H;
   begin
      for Case_Id in 1 .. 8 loop
         case Case_Id is
            when 1 =>
               null; --  default header

            when 2 =>
               M := OpenCV.Core.Create (0, 0, (OpenCV.Core.Float64, 1));

            when 3 =>
               M := OpenCV.Core.Create (2, 3, (OpenCV.Core.Float32, 1));

            when 4 =>
               M := OpenCV.Core.Create (3, 3, (OpenCV.Core.Float64, 2));

            when 5 =>
               M := OpenCV.Core.Create (2, 2, (OpenCV.Core.Float64, 1));

            when 6 =>
               M :=
                 OpenCV.Core.Create
                   (Shape        => (2, 3, 3),
                    Element_Type => (OpenCV.Core.Float64, 1));

            when 7 =>
               M := OpenCV.Core.Create (3, 2, (OpenCV.Core.Float64, 1));

            when 8 =>
               M := OpenCV.Core.Create (3, 3, (OpenCV.Core.UInt8, 1));
         end case;
         Raises (Read_A'Access, "reject invalid affine Mat metadata");
         Raises (Read_H'Access, "reject invalid perspective Mat metadata");
      end loop;
      M := To_Mat (A);
      Raises (Read_H'Access, "reject 2x3 perspective Mat");
      M := To_Mat (H);
      Raises (Read_A'Access, "reject 3x3 affine Mat");
   end Mat_Invalid_Metadata;

   procedure Nonfinite_Inputs (T : in out Fixture) is
      pragma Unreferenced (T);
      pragma Suppress (Validity_Check);
      X : Affine_Transform_2D := A;
      Y : Perspective_Transform_2D := H;
      procedure Convert_A is
         M : constant OpenCV.Core.Mat := To_Mat (X);
         pragma Unreferenced (M);
      begin
         null;
      end Convert_A;
      procedure Convert_H is
         M : constant OpenCV.Core.Mat := To_Mat (Y);
         pragma Unreferenced (M);
      begin
         null;
      end Convert_H;
      procedure Compose_A is
         V : constant Affine_Transform_2D := Compose (X, A);
         W : constant Affine_Transform_2D := Compose (A, X);
         pragma Unreferenced (V, W);
      begin
         null;
      end Compose_A;
      procedure Compose_H is
         V : constant Perspective_Transform_2D := Compose (H, Y);
         pragma Unreferenced (V);
      begin
         null;
      end Compose_H;
      procedure Invert_H is
         V : constant Perspective_Transform_2D :=
           Invert_Perspective_Transform (Y);
         pragma Unreferenced (V);
      begin
         null;
      end Invert_H;
   begin
      for Bits of Specials loop
         X (2, 3) := From_Bits (Bits);
         Y (3, 3) := From_Bits (Bits);
         Raises (Convert_A'Access, "affine nonfinite conversion");
         Raises (Convert_H'Access, "perspective nonfinite conversion");
         Raises (Compose_A'Access, "affine nonfinite composition");
         Raises (Compose_H'Access, "perspective nonfinite composition");
         Raises (Invert_H'Access, "perspective nonfinite inverse");
         Assert
           (To_Bits (X (2, 3)) = Bits and then To_Bits (Y (3, 3)) = Bits,
            "failure leaves operands unchanged");
      end loop;
   end Nonfinite_Inputs;

   procedure Mat_Nonfinite (T : in out Fixture) is
      pragma Unreferenced (T);
      pragma Suppress (Validity_Check);
      M : OpenCV.Core.Mat := To_Mat (A);
      N : OpenCV.Core.Mat := To_Mat (H);
      procedure Read_A is
         V : constant Affine_Transform_2D := Affine_From_Mat (M);
         pragma Unreferenced (V);
      begin
         null;
      end Read_A;
      procedure Read_H is
         V : constant Perspective_Transform_2D := Perspective_From_Mat (N);
         pragma Unreferenced (V);
      begin
         null;
      end Read_H;
   begin
      for Bits of Specials loop
         Access_64.Set (M, 1, 2, From_Bits (Bits));
         Access_64.Set (N, 2, 2, From_Bits (Bits));
         Raises (Read_A'Access, "classify affine raw nonfinite before Get");
         Raises
           (Read_H'Access, "classify homography raw nonfinite before Get");
      end loop;
   end Mat_Nonfinite;

   procedure Rotation_Equivalence (T : in out Fixture) is
      pragma Unreferenced (T);
      type Values is array (Positive range <>) of F64;
      Angles : constant Values :=
        (0.0,
         90.0,
         -45.0,
         180.0,
         -180.0,
         360.0,
         -360.0,
         360.0 - 1.0E-10,
         360.0 + 1.0E-10,
         1.0E+300,
         -1.0E+300);
      Scales : constant Values := (1.0, 0.0, -2.0, 0.5);
      Center : constant OpenCV.Float32_Point := (7.0, -3.0);
   begin
      for Units in OpenCV.Angle_Unit loop
         for Angle of Angles loop
            for Scale of Scales loop
               declare
                  V : constant Affine_Transform_2D :=
                    Get_Rotation_Affine_Transform_2D
                      (Center, Angle, Scale, Units);
                  M : constant OpenCV.Core.Mat :=
                    Get_Rotation_Matrix_2D (Center, Angle, Scale, Units);
                  P : constant OpenCV.Float32_Point :=
                    Transform_Point (V, Center);
               begin
                  Assert
                    (V = Affine_From_Mat (M), "rotation native equivalence");
                  Assert
                    (abs (P.X - Center.X) < 1.0E-5
                     and then abs (P.Y - Center.Y) < 1.0E-5,
                     "rotation center invariant");
               end;
            end loop;
         end loop;
      end loop;
      Near
        (Homogeneous (Get_Rotation_Affine_Transform_2D ((0.0, 0.0), 90.0)),
         Homogeneous
           (Get_Rotation_Affine_Transform_2D
              ((0.0, 0.0),
               F64 (Ada.Numerics.Pi) / 2.0,
               Units => OpenCV.Radians)));
   end Rotation_Equivalence;

   procedure Composition_Order (T : in out Fixture) is
      pragma Unreferenced (T);
      Translation : constant Affine_Transform_2D :=
        ((1.0, 0.0, 10.0), (0.0, 1.0, 20.0));
      Rotation    : constant Affine_Transform_2D :=
        ((0.0, 1.0, 0.0), (-1.0, 0.0, 0.0));
   begin
      Assert
        (Compose (Rotation, Translation)
         = ((0.0, 1.0, 10.0), (-1.0, 0.0, 20.0)),
         "rotation then translate");
      Assert
        (Compose (Translation, Rotation)
         = ((0.0, 1.0, 20.0), (-1.0, 0.0, -10.0)),
         "translate then rotation");
      Assert
        (Compose (A, Identity_Affine_Transform) = A
         and then Compose (Identity_Affine_Transform, A) = A,
         "affine identities");
      Assert
        (Compose (H, Identity_Perspective_Transform) = H
         and then Compose (Identity_Perspective_Transform, H) = H,
         "homography identities");
      Near
        (Homogeneous (Compose (A, Translation)),
         Compose (Homogeneous (A), Homogeneous (Translation)));
      Assert
        (A = ((2.0, 0.25, 10.0), (-0.5, 3.0, -20.0)), "operand unchanged");
   end Composition_Order;

   procedure Composition_Oracle (T : in out Fixture) is
      pragma Unreferenced (T);
      G          : constant Perspective_Transform_2D :=
        ((-1.0, 0.5, 2.0), (0.25, -2.0, 3.0), (0.02, 0.01, -3.0));
      Expected   : Perspective_Transform_2D := (others => (others => 0.0));
      Actual     : constant Perspective_Transform_2D := Compose (H, G);
      P          : constant OpenCV.Float32_Point := (0.5, -0.25);
      Direct     : constant OpenCV.Float32_Point :=
        Transform_Point (Actual, P);
      Sequential : constant OpenCV.Float32_Point :=
        Transform_Point (G, Transform_Point (H, P));
   begin
      --  Independent ordinary homogeneous multiplication on small fixtures.
      for R in Expected'Range (1) loop
         for C in Expected'Range (2) loop
            for K in Perspective_Row_Index loop
               Expected (R, C) :=
                 Expected (R, C)
                 + G (R, Transform_Column_Index (K)) * H (K, C);
            end loop;
         end loop;
      end loop;
      Near (Actual, Expected);
      Assert
        (Actual (3, 3) /= 1.0 and then Actual (3, 3) < 0.0,
         "negative homogeneous scale is not normalized");
      Assert
        (abs (Direct.X - Sequential.X) < 1.0E-5
         and then abs (Direct.Y - Sequential.Y) < 1.0E-5,
         "point equivalence");
      Near
        (Homogeneous (Compose (A, A)),
         Compose (Homogeneous (A), Homogeneous (A)));
   end Composition_Oracle;

   procedure Composition_Extremes (T : in out Fixture) is
      pragma Unreferenced (T);
      X, Y : Perspective_Transform_2D := Identity_Perspective_Transform;
      procedure Attempt is
         V : constant Perspective_Transform_2D := Compose (X, Y);
         pragma Unreferenced (V);
      begin
         null;
      end Attempt;
   begin
      X (1, 1) := 1.0E+200;
      Y (1, 1) := 1.0E+90;
      Assert
        (abs (Compose (X, Y) (1, 1) / 1.0E+290 - 1.0) < 1.0E-14,
         "large safe multiplication");
      X (1, 1) := F64'Last;
      Y (1, 1) := 2.0;
      Raises (Attempt'Access, "reject overflow before multiplying");
      Assert
        (X (1, 1) = F64'Last and then Y (1, 1) = 2.0,
         "overflow leaves inputs unchanged");
      X := ((6.0E+299, 0.0, 0.0), (6.0E+299, 1.0, 0.0), (0.0, 0.0, 1.0));
      Y := ((1.0, 1.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0));
      Raises (Attempt'Access, "reject unsafe sum before adding");
      X := Identity_Perspective_Transform;
      Y := Identity_Perspective_Transform;
      X (1, 1) := 1.0E-200;
      Y (1, 1) := 1.0E-200;
      Assert (Compose (X, Y) (1, 1) = 0.0, "documented gradual underflow");
   end Composition_Extremes;

   procedure Check_Inverse (Value : Perspective_Transform_2D) is
      Inverse : constant Perspective_Transform_2D :=
        Invert_Perspective_Transform (Value);
      Product : Perspective_Transform_2D;
   begin
      --  Independent evaluation: do not use Compose for this oracle.
      for Direction in Boolean loop
         Product := (others => (others => 0.0));
         for R in Product'Range (1) loop
            for C in Product'Range (2) loop
               for K in Perspective_Row_Index loop
                  if Direction then
                     Product (R, C) :=
                       Product (R, C)
                       + Value (R, Transform_Column_Index (K))
                         * Inverse (K, C);
                  else
                     Product (R, C) :=
                       Product (R, C)
                       + Inverse (R, Transform_Column_Index (K))
                         * Value (K, C);
                  end if;
               end loop;
            end loop;
         end loop;
         Near (Product, Identity_Perspective_Transform, 1.0E-10);
      end loop;
   end Check_Inverse;

   procedure Inverse_Ordinary (T : in out Fixture) is
      pragma Unreferenced (T);
      P        : constant OpenCV.Float32_Point := (0.5, -0.25);
      Inverse  : constant Perspective_Transform_2D :=
        Invert_Perspective_Transform (H);
      Restored : constant OpenCV.Float32_Point :=
        Transform_Point (Inverse, Transform_Point (H, P));
   begin
      Assert
        (Invert_Perspective_Transform (Identity_Perspective_Transform)
         = Identity_Perspective_Transform,
         "identity inverse");
      Check_Inverse (Homogeneous (A));
      Check_Inverse (((1.0, 0.0, 10.0), (0.0, 1.0, 20.0), (0.0, 0.0, 1.0)));
      Check_Inverse (H);
      Near (Compose (H, Inverse), Identity_Perspective_Transform, 1.0E-10);
      Assert
        (abs (Restored.X - P.X) < 1.0E-5
         and then abs (Restored.Y - P.Y) < 1.0E-5,
         "inverse point round trip");
   end Inverse_Ordinary;

   procedure Inverse_Scales (T : in out Fixture) is
      pragma Unreferenced (T);
      type Scales is array (Positive range <>) of F64;
      Values    : constant Scales :=
        (1.0E-280, 1.0E-200, -2.0, 1.0E+200, 1.0E+279);
      Scaled    : Perspective_Transform_2D;
      Reference : constant Perspective_Transform_2D :=
        Invert_Perspective_Transform (H);
   begin
      for Scale of Values loop
         for R in H'Range (1) loop
            for C in H'Range (2) loop
               Scaled (R, C) := H (R, C) * Scale;
            end loop;
         end loop;
         Check_Inverse (Scaled);
         declare
            Actual : constant Perspective_Transform_2D :=
              Invert_Perspective_Transform (Scaled);
         begin
            for R in H'Range (1) loop
               for C in H'Range (2) loop
                  Assert
                    (abs (Actual (R, C) * Scale - Reference (R, C)) < 1.0E-12,
                     "inverse preserves original coefficient scale");
               end loop;
            end loop;
         end;
      end loop;
   end Inverse_Scales;

   procedure Inverse_Rejections (T : in out Fixture) is
      pragma Unreferenced (T);
      X : Perspective_Transform_2D := (others => (others => 0.0));
      procedure Attempt is
         V : constant Perspective_Transform_2D :=
           Invert_Perspective_Transform (X);
         pragma Unreferenced (V);
      begin
         null;
      end Attempt;
   begin
      for Case_Id in 1 .. 9 loop
         case Case_Id is
            when 1 =>
               null; --  all zero

            when 2 =>
               X := ((1.0, 2.0, 3.0), (2.0, 4.0, 6.0), (0.0, 0.0, 1.0));

            when 3 =>
               X := ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 0.0));

            when 4 =>
               X := Identity_Perspective_Transform;
               X (3, 3) := 1.0E-12;

            when 5 =>
               X := Identity_Perspective_Transform;
               X (3, 3) := 1.0E-30;

            when 6 =>
               X := (others => (others => 1.0E+300));

            when 7 =>
               X := (others => (others => 1.0E-300));

            when 8 =>
               X := Identity_Perspective_Transform;
               X (1, 2) := 1.0E-200;

            when 9 =>
               X :=
                 ((1.0, 1.0, 0.0), (1.0, 1.0 + 1.0E-14, 0.0), (0.0, 0.0, 1.0));
         end case;
         declare
            Saved : constant Perspective_Transform_2D := X;
         begin
            Raises
              (Attempt'Access, "singular, near singular or unsafe inverse");
            Assert (X = Saved, "failed inverse leaves input unchanged");
         end;
      end loop;
   end Inverse_Rejections;

   procedure Rotation_Invalid (T : in out Fixture) is
      pragma Unreferenced (T);
      pragma Suppress (Validity_Check);
      Angle, Scale : F64 := 1.0;
      procedure Attempt is
         V : constant Affine_Transform_2D :=
           Get_Rotation_Affine_Transform_2D ((0.0, 0.0), Angle, Scale);
         pragma Unreferenced (V);
      begin
         null;
      end Attempt;
   begin
      for Bits of Specials loop
         Angle := From_Bits (Bits);
         Raises (Attempt'Access, "rotation wrapper rejects invalid angle");
         Angle := 1.0;
         Scale := From_Bits (Bits);
         Raises (Attempt'Access, "rotation wrapper rejects invalid scale");
         Scale := 1.0;
      end loop;
   end Rotation_Invalid;

   procedure Inverse_Regression (T : in out Fixture) is
      pragma Unreferenced (T);
      X       : Perspective_Transform_2D;
      Inverse : Perspective_Transform_2D;
   begin
      --  Deterministic diagonally dominant projective fixtures. The oracle
      --  evaluates both identity products independently of production Compose.
      for Index in 1 .. 100 loop
         X :=
           ((2.0 + F64 (Index) / 100.0, 0.1, -0.2),
            (0.2, 3.0, F64 (Index) / 200.0),
            (F64 (Index) / 10000.0, -0.01, -2.0));
         Check_Inverse (X);
      end loop;
      --  Accepted side of the condition boundary and exact common-scale
      --  endpoints, distinct from the deliberately rejected 1e-12 diagonal.
      X := Identity_Perspective_Transform;
      X (3, 3) := 1.0E-7;
      Check_Inverse (X);
      for Scale of F64_Array'(1.0E-280, 1.0E+280) loop
         X := (others => (others => 0.0));
         for R in X'Range (1) loop
            X (R, Transform_Column_Index (R)) := Scale;
         end loop;
         Check_Inverse (X);
         Inverse := Invert_Perspective_Transform (X);
         Assert
           (abs (Inverse (3, 3) * Scale - 1.0) < 1.0E-14,
            "scale endpoints retain algebraic inverse");
      end loop;
   end Inverse_Regression;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Transform utilities Mat round trips", Mat_Round_Trips'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities Mat ownership", Mat_Ownership'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities Mat Regions", Mat_Regions'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities Mat invalid metadata",
            Mat_Invalid_Metadata'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities nonfinite inputs", Nonfinite_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities Mat nonfinite", Mat_Nonfinite'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities rotation equivalence",
            Rotation_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities composition order",
            Composition_Order'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities composition oracle",
            Composition_Oracle'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities composition extremes",
            Composition_Extremes'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities inverse ordinary", Inverse_Ordinary'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities inverse scales", Inverse_Scales'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities inverse rejections",
            Inverse_Rejections'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities rotation invalid", Rotation_Invalid'Access));
      Result.Add_Test
        (Caller.Create
           ("Transform utilities inverse regression",
            Inverse_Regression'Access));
      return Result'Access;
   end Suite;
end Transform_Utilities_Tests;
