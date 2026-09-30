with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Affine_Transform_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Geometry.Affine_Transform_2D;
   use type OpenCV.Geometry.Transform_Column_Index;
   use type OpenCV.Geometry.Float32_Point_Array;

   subtype Affine is OpenCV.Geometry.Affine_Transform_2D;
   subtype Points is OpenCV.Geometry.Float32_Point_Array;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Float32_Value);

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Float64_Value);

   function Bits_To_C_Double is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => Interfaces.C.double);

   --  IEEE special values; callers suppress validity checks.
   function NaN_32 return OpenCV.Float32_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float32 (16#7FC0_0000#);
   end NaN_32;

   function Infinity_32 return OpenCV.Float32_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float32 (16#7F80_0000#);
   end Infinity_32;

   function NaN_64 return OpenCV.Float64_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float64 (16#7FF8_0000_0000_0000#);
   end NaN_64;

   function Infinity_64 return OpenCV.Float64_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float64 (16#7FF0_0000_0000_0000#);
   end Infinity_64;

   --  OpenCV solves the 6x6 system by LU in binary64.
   Coefficient_Tolerance : constant := 1.0E-9;
   Point_Tolerance       : constant := 1.0E-4;

   Unit_Triangle : constant Points :=
     ((X => 0.0, Y => 0.0), (X => 1.0, Y => 0.0), (X => 0.0, Y => 1.0));

   function Nearly_Equal
     (Left, Right : OpenCV.Float64_Value; Tolerance : OpenCV.Float64_Value)
      return Boolean
   is (abs (Left - Right) <= Tolerance);

   procedure Assert_Affine
     (Actual    : Affine;
      Expected  : Affine;
      Message   : String;
      Tolerance : OpenCV.Float64_Value := Coefficient_Tolerance) is
   begin
      for Row in Actual'Range (1) loop
         for Column in Actual'Range (2) loop
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (Actual (Row, Column), Expected (Row, Column), Tolerance),
               Message
               & " coefficient"
               & Row'Image
               & ","
               & Column'Image
               & " ="
               & Actual (Row, Column)'Image
               & ", expected"
               & Expected (Row, Column)'Image);
         end loop;
      end loop;
   end Assert_Affine;

   procedure Assert_All_Zero (Actual : Affine; Message : String) is
   begin
      for Coefficient of Actual loop
         AUnit.Assertions.Assert (Coefficient = 0.0, Message);
      end loop;
   end Assert_All_Zero;

   procedure Assert_Maps
     (Transform : Affine; Source, Destination : Points; Message : String) is
   begin
      for Offset in 0 .. Source'Length - 1 loop
         declare
            Mapped : constant OpenCV.Float32_Point :=
              OpenCV.Geometry.Transform_Point
                (Transform, Source (Source'First + Offset));
            Wanted : constant OpenCV.Float32_Point :=
              Destination (Destination'First + Offset);
         begin
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (OpenCV.Float64_Value (Mapped.X),
                  OpenCV.Float64_Value (Wanted.X),
                  Point_Tolerance)
               and then Nearly_Equal
                          (OpenCV.Float64_Value (Mapped.Y),
                           OpenCV.Float64_Value (Wanted.Y),
                           Point_Tolerance),
               Message & " maps point" & Offset'Image);
         end;
      end loop;
   end Assert_Maps;

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

   procedure Identity_Correspondence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Triangle : constant Points :=
        ((X => 3.0, Y => -2.0), (X => 7.5, Y => 1.0), (X => -1.0, Y => 4.0));
   begin
      Assert_Affine
        (OpenCV.Geometry.Get_Affine_Transform (Triangle, Triangle),
         OpenCV.Geometry.Identity_Affine_Transform,
         "identity correspondence");
   end Identity_Correspondence;

   procedure Translation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Destination : constant Points :=
        ((X => 5.0, Y => -7.0), (X => 6.0, Y => -7.0), (X => 5.0, Y => -6.0));
   begin
      Assert_Affine
        (OpenCV.Geometry.Get_Affine_Transform (Unit_Triangle, Destination),
         ((1.0, 0.0, 5.0), (0.0, 1.0, -7.0)),
         "translation");
   end Translation;

   procedure Anisotropic_Scale (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Destination : constant Points :=
        ((X => 0.0, Y => 0.0), (X => 2.0, Y => 0.0), (X => 0.0, Y => 3.0));
   begin
      Assert_Affine
        (OpenCV.Geometry.Get_Affine_Transform (Unit_Triangle, Destination),
         ((2.0, 0.0, 0.0), (0.0, 3.0, 0.0)),
         "anisotropic scale");
   end Anisotropic_Scale;

   procedure Rotation_And_Scale (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A quarter turn counter-clockwise combined with scale 2.
      Destination : constant Points :=
        ((X => 0.0, Y => 0.0), (X => 0.0, Y => 2.0), (X => -2.0, Y => 0.0));
   begin
      Assert_Affine
        (OpenCV.Geometry.Get_Affine_Transform (Unit_Triangle, Destination),
         ((0.0, -2.0, 0.0), (2.0, 0.0, 0.0)),
         "rotation and scale");
   end Rotation_And_Scale;

   procedure Shear (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  X' = X + 0.5 * Y.
      Destination : constant Points :=
        ((X => 0.0, Y => 0.0), (X => 1.0, Y => 0.0), (X => 0.5, Y => 1.0));
   begin
      Assert_Affine
        (OpenCV.Geometry.Get_Affine_Transform (Unit_Triangle, Destination),
         ((1.0, 0.5, 0.0), (0.0, 1.0, 0.0)),
         "shear");
   end Shear;

   procedure Arbitrary_Triangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant Points :=
        ((X => 12.5, Y => 3.0),
         (X => 40.0, Y => 18.25),
         (X => 7.0, Y => 33.0));
      Destination : constant Points :=
        ((X => 101.0, Y => -4.5),
         (X => 150.75, Y => 20.0),
         (X => 88.0, Y => 61.5));
      Transform   : constant Affine :=
        OpenCV.Geometry.Get_Affine_Transform (Source, Destination);
   begin
      Assert_Maps (Transform, Source, Destination, "arbitrary triangle");
      Assert_Affine
        (OpenCV.Geometry.Get_Affine_Transform
           (Unit_Triangle,
            ((X => 10.0, Y => 20.0),
             (X => 12.0, Y => 21.0),
             (X => 9.0, Y => 23.0))),
         ((2.0, -1.0, 10.0), (1.0, 3.0, 20.0)),
         "unit triangle coefficients");
   end Arbitrary_Triangle;

   procedure Negative_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant Points :=
        ((X => -10.0, Y => -20.0),
         (X => -3.0, Y => -25.0),
         (X => -8.0, Y => -9.0));
      Destination : constant Points :=
        ((X => -1.0, Y => 5.0),
         (X => -40.0, Y => -2.0),
         (X => 6.0, Y => -30.0));
   begin
      Assert_Maps
        (OpenCV.Geometry.Get_Affine_Transform (Source, Destination),
         Source,
         Destination,
         "negative coordinates");
   end Negative_Coordinates;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant Points (5 .. 7) :=
        ((X => 0.0, Y => 0.0), (X => 1.0, Y => 0.0), (X => 0.0, Y => 1.0));
      Destination : constant Points (100 .. 102) :=
        ((X => 10.0, Y => 20.0),
         (X => 12.0, Y => 21.0),
         (X => 9.0, Y => 23.0));
   begin
      Assert_Affine
        (OpenCV.Geometry.Get_Affine_Transform (Source, Destination),
         ((2.0, -1.0, 10.0), (1.0, 3.0, 20.0)),
         "points are paired in iteration order across different bounds");
   end Nonzero_Bounds;

   procedure Inputs_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source           : constant Points :=
        ((X => 1.5, Y => 2.5), (X => 9.0, Y => -1.0), (X => 4.0, Y => 7.0));
      Destination      : constant Points :=
        ((X => -3.0, Y => 0.5), (X => 2.0, Y => 2.0), (X => 5.0, Y => -6.0));
      Source_Copy      : constant Points := Source;
      Destination_Copy : constant Points := Destination;
      Transform        : constant Affine :=
        OpenCV.Geometry.Get_Affine_Transform (Source, Destination);
      Transform_Copy   : constant Affine := Transform;
      Inverse          : constant Affine :=
        OpenCV.Geometry.Invert_Affine_Transform (Transform);
   begin
      AUnit.Assertions.Assert
        (Source = Source_Copy and then Destination = Destination_Copy,
         "Get_Affine_Transform leaves its inputs unchanged");
      AUnit.Assertions.Assert
        (Transform = Transform_Copy and then Inverse /= Transform,
         "Invert_Affine_Transform leaves its input unchanged");
   end Inputs_Unchanged;

   procedure Degenerate_Triangles_Return_Zero (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Destination : constant Points :=
        ((X => 10.0, Y => 20.0),
         (X => 12.0, Y => 21.0),
         (X => 9.0, Y => 23.0));
   begin
      Assert_All_Zero
        (OpenCV.Geometry.Get_Affine_Transform
           (((X => 0.0, Y => 0.0), (X => 1.0, Y => 1.0), (X => 2.0, Y => 2.0)),
            Destination),
         "a collinear source triangle yields the zero transform");
      Assert_All_Zero
        (OpenCV.Geometry.Get_Affine_Transform
           (((X => 3.0, Y => 4.0), (X => 3.0, Y => 4.0), (X => 5.0, Y => 6.0)),
            Destination),
         "a repeated source point yields the zero transform");
      Assert_All_Zero
        (OpenCV.Geometry.Get_Affine_Transform
           (((X => 2.0, Y => 2.0), (X => 2.0, Y => 2.0), (X => 2.0, Y => 2.0)),
            Destination),
         "a single repeated source point yields the zero transform");
      Assert_All_Zero
        (OpenCV.Geometry.Get_Affine_Transform
           (Unit_Triangle,
            ((X => 0.0, Y => 0.0),
             (X => 0.0, Y => 0.0),
             (X => 0.0, Y => 0.0))),
         "mapping every point to the origin is the zero transform");
   end Degenerate_Triangles_Return_Zero;

   procedure Rejects_Invalid_Correspondences (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      Two  : constant Points := ((X => 0.0, Y => 0.0), (X => 1.0, Y => 0.0));
      Four : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 1.0, Y => 0.0),
         (X => 0.0, Y => 1.0),
         (X => 1.0, Y => 1.0));
      None : constant Points (1 .. 0) := (others => (X => 0.0, Y => 0.0));

      procedure Too_Few_Source is
         Ignored : constant Affine :=
           OpenCV.Geometry.Get_Affine_Transform (Two, Unit_Triangle);
      begin
         null;
      end Too_Few_Source;

      procedure Too_Many_Source is
         Ignored : constant Affine :=
           OpenCV.Geometry.Get_Affine_Transform (Four, Unit_Triangle);
      begin
         null;
      end Too_Many_Source;

      procedure Empty_Destination is
         Ignored : constant Affine :=
           OpenCV.Geometry.Get_Affine_Transform (Unit_Triangle, None);
      begin
         null;
      end Empty_Destination;

      procedure Nan_Source is
         Ignored : constant Affine :=
           OpenCV.Geometry.Get_Affine_Transform
             (((X => 0.0, Y => 0.0),
               (X => NaN_32, Y => 0.0),
               (X => 0.0, Y => 1.0)),
              Unit_Triangle);
      begin
         null;
      end Nan_Source;

      procedure Infinite_Destination is
         Ignored : constant Affine :=
           OpenCV.Geometry.Get_Affine_Transform
             (Unit_Triangle,
              ((X => 0.0, Y => 0.0),
               (X => 1.0, Y => 0.0),
               (X => 0.0, Y => -Infinity_32)));
      begin
         null;
      end Infinite_Destination;
   begin
      Assert_Raises_OpenCV_Error
        (Too_Few_Source'Access, "two source points are rejected");
      Assert_Raises_OpenCV_Error
        (Too_Many_Source'Access, "four source points are rejected");
      Assert_Raises_OpenCV_Error
        (Empty_Destination'Access, "an empty destination is rejected");
      Assert_Raises_OpenCV_Error
        (Nan_Source'Access, "a NaN source coordinate is rejected");
      Assert_Raises_OpenCV_Error
        (Infinite_Destination'Access,
         "an infinite destination coordinate is rejected");
   end Rejects_Invalid_Correspondences;

   procedure Invert_Known_Transforms (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Affine
        (OpenCV.Geometry.Invert_Affine_Transform
           (OpenCV.Geometry.Identity_Affine_Transform),
         OpenCV.Geometry.Identity_Affine_Transform,
         "inverse of identity");
      Assert_Affine
        (OpenCV.Geometry.Invert_Affine_Transform
           (((1.0, 0.0, 5.0), (0.0, 1.0, -7.0))),
         ((1.0, 0.0, -5.0), (0.0, 1.0, 7.0)),
         "inverse of a translation");
      Assert_Affine
        (OpenCV.Geometry.Invert_Affine_Transform
           (((0.0, -2.0, 4.0), (2.0, 0.0, 6.0))),
         ((0.0, 0.5, -3.0), (-0.5, 0.0, 2.0)),
         "inverse of a rotation, scale, and translation");
   end Invert_Known_Transforms;

   procedure Inverse_Composition (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant Affine := ((2.0, 1.0, 5.0), (-1.0, 3.0, -7.0));
      Inverse   : constant Affine :=
        OpenCV.Geometry.Invert_Affine_Transform (Transform);
      Samples   : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 13.5, Y => -2.25),
         (X => -40.0, Y => 17.0),
         (X => 1000.0, Y => 250.0));
   begin
      for Row in Affine'Range (1) loop
         for Column in Affine'Range (2) loop
            declare
               --  Composition of the affine maps Inverse and Transform.
               Product : OpenCV.Float64_Value :=
                 (if Column = 3 then Inverse (Row, 3) else 0.0);
               Wanted  : constant OpenCV.Float64_Value :=
                 (if Integer (Row) = Integer (Column) then 1.0 else 0.0);
            begin
               for Middle in Affine'Range (1) loop
                  Product :=
                    Product
                    + Inverse
                        (Row, OpenCV.Geometry.Transform_Column_Index (Middle))
                      * Transform (Middle, Column);
               end loop;
               AUnit.Assertions.Assert
                 (Nearly_Equal (Product, Wanted, Coefficient_Tolerance),
                  "Inverse composed with Transform is the identity");
            end;
         end loop;
      end loop;

      for Point of Samples loop
         declare
            Round_Trip : constant OpenCV.Float32_Point :=
              OpenCV.Geometry.Transform_Point
                (Inverse, OpenCV.Geometry.Transform_Point (Transform, Point));
         begin
            AUnit.Assertions.Assert
              (Nearly_Equal
                 (OpenCV.Float64_Value (Round_Trip.X),
                  OpenCV.Float64_Value (Point.X),
                  1.0E-3)
               and then Nearly_Equal
                          (OpenCV.Float64_Value (Round_Trip.Y),
                           OpenCV.Float64_Value (Point.Y),
                           1.0E-3),
               "mapping through Transform and its inverse recovers a point");
         end;
      end loop;
   end Inverse_Composition;

   procedure Invert_Singular_Returns_Zero (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_All_Zero
        (OpenCV.Geometry.Invert_Affine_Transform
           (((1.0, 2.0, 3.0), (2.0, 4.0, 5.0))),
         "a rank-one linear part yields the zero transform");
      Assert_All_Zero
        (OpenCV.Geometry.Invert_Affine_Transform
           (((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))),
         "the zero transform inverts to the zero transform");
      Assert_All_Zero
        (OpenCV.Geometry.Invert_Affine_Transform
           (((0.0, 0.0, 12.0), (0.0, 0.0, -9.0))),
         "a translation-only singular transform yields zero");
      Assert_All_Zero
        (OpenCV.Geometry.Invert_Affine_Transform
           (((1.0E-170, 0.0, 3.0), (0.0, 1.0E-170, 4.0))),
         "a determinant that underflows to zero yields zero");
      Assert_All_Zero
        (OpenCV.Geometry.Invert_Affine_Transform
           (((1.0E+200, 0.0, 3.0), (0.0, 1.0E+200, 4.0))),
         "a determinant that overflows to infinity yields zero");
   end Invert_Singular_Returns_Zero;

   procedure Invert_Rejects_Non_Finite (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      procedure Nan_Translation is
         Ignored : constant Affine :=
           OpenCV.Geometry.Invert_Affine_Transform
             (((1.0, 0.0, NaN_64), (0.0, 1.0, 0.0)));
      begin
         null;
      end Nan_Translation;

      procedure Infinite_Linear is
         Ignored : constant Affine :=
           OpenCV.Geometry.Invert_Affine_Transform
             (((1.0, 0.0, 0.0), (0.0, Infinity_64, 0.0)));
      begin
         null;
      end Infinite_Linear;

      procedure Inverse_Overflows is
         --  D = 1.0E-320 is nonzero, so 1.0 / D overflows.
         Ignored : constant Affine :=
           OpenCV.Geometry.Invert_Affine_Transform
             (((1.0E-160, 0.0, 0.0), (0.0, 1.0E-160, 0.0)));
      begin
         null;
      end Inverse_Overflows;

      procedure Determinant_Is_NaN is
         --  D = infinity - infinity.
         Ignored : constant Affine :=
           OpenCV.Geometry.Invert_Affine_Transform
             (((1.0E+200, 1.0E+200, 0.0), (1.0E+200, 1.0E+200, 0.0)));
      begin
         null;
      end Determinant_Is_NaN;
   begin
      Assert_Raises_OpenCV_Error
        (Nan_Translation'Access, "a NaN coefficient is rejected");
      Assert_Raises_OpenCV_Error
        (Infinite_Linear'Access, "an infinite coefficient is rejected");
      Assert_Raises_OpenCV_Error
        (Inverse_Overflows'Access,
         "non-finite native coefficients from a tiny determinant raise");
      Assert_Raises_OpenCV_Error
        (Determinant_Is_NaN'Access,
         "non-finite native coefficients from a NaN determinant raise");
   end Invert_Rejects_Non_Finite;

   procedure Transform_Point_Values (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Transform : constant Affine := ((2.0, -1.0, 10.0), (1.0, 3.0, 20.0));
      Mapped    : constant OpenCV.Float32_Point :=
        OpenCV.Geometry.Transform_Point (Transform, (X => 4.0, Y => -2.5));
      Huge      : constant Affine := ((1.0E+200, 0.0, 1.0), (0.0, 1.0, 2.0));
   begin
      AUnit.Assertions.Assert
        (Mapped.X = 20.5 and then Mapped.Y = 16.5,
         "Transform_Point evaluates both affine rows");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Transform_Point
           (OpenCV.Geometry.Identity_Affine_Transform, (X => -3.5, Y => 7.25))
         = (X => -3.5, Y => 7.25),
         "the identity maps a point to itself");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Transform_Point (Huge, (X => 0.0, Y => 5.0))
         = (X => 1.0, Y => 7.0),
         "large coefficients within the bound are accepted");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Transform_Point
           (Affine'((1.0E+269, 0.0, 0.0), (0.0, -1.0E+269, 3.0)),
            (X => 0.0, Y => 0.0))
         = (X => 0.0, Y => 3.0),
         "coefficients exactly at the bound are accepted");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Transform_Point
           (Affine'((1.0, 0.0, 0.1), (0.0, 1.0, 0.0)), (X => 0.0, Y => 0.0))
           .X
         = OpenCV.Float32_Value (0.1),
         "the binary64 result is rounded to the nearest binary32 value");
   end Transform_Point_Values;

   procedure Transform_Point_Rejects_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      procedure Nan_Point is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (OpenCV.Geometry.Identity_Affine_Transform,
              (X => NaN_32, Y => 0.0));
      begin
         null;
      end Nan_Point;

      procedure Nan_Coefficient is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (Affine'((1.0, 0.0, 0.0), (0.0, NaN_64, 0.0)),
              (X => 1.0, Y => 1.0));
      begin
         null;
      end Nan_Coefficient;

      procedure Coefficient_Above_Bound is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (Affine'((1.0, 0.0, 1.0E+270), (0.0, 1.0, 0.0)),
              (X => 0.0, Y => 0.0));
      begin
         null;
      end Coefficient_Above_Bound;

      procedure Result_Beyond_Binary32 is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (Affine'((1.0E+30, 0.0, 0.0), (0.0, 1.0, 0.0)),
              (X => 1.0E+30, Y => 0.0));
      begin
         null;
      end Result_Beyond_Binary32;

      procedure Infinite_Point is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (OpenCV.Geometry.Identity_Affine_Transform,
              (X => 0.0, Y => -Infinity_32));
      begin
         null;
      end Infinite_Point;

      procedure Infinite_Coefficient is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (Affine'((1.0, 0.0, Infinity_64), (0.0, 1.0, 0.0)),
              (X => 0.0, Y => 0.0));
      begin
         null;
      end Infinite_Coefficient;
   begin
      Assert_Raises_OpenCV_Error (Nan_Point'Access, "a NaN point is rejected");
      Assert_Raises_OpenCV_Error
        (Infinite_Point'Access, "an infinite point is rejected");
      Assert_Raises_OpenCV_Error
        (Infinite_Coefficient'Access, "an infinite coefficient is rejected");
      Assert_Raises_OpenCV_Error
        (Nan_Coefficient'Access, "a NaN coefficient is rejected");
      Assert_Raises_OpenCV_Error
        (Coefficient_Above_Bound'Access,
         "a coefficient above 1.0E+269 is rejected");
      Assert_Raises_OpenCV_Error
        (Result_Beyond_Binary32'Access,
         "a result outside binary32 range is rejected");
   end Transform_Point_Rejects_Invalid_Inputs;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      use type C_API.C_Triangle_Points;

      Source_Copy      : constant C_API.C_Triangle_Points :=
        (Points => ((0.0, 0.0), (1.0, 0.0), (0.0, 1.0)));
      Destination_Copy : constant C_API.C_Triangle_Points :=
        (Points => ((10.0, 20.0), (12.0, 21.0), (9.0, 23.0)));
      Source           : aliased C_API.C_Triangle_Points := Source_Copy;
      Destination      : aliased C_API.C_Triangle_Points := Destination_Copy;
      Output           : aliased C_API.C_Affine_2x3_F64 := (others => 7.0);
      Status           : C_API.Status;

      function Is_Zeroed (Value : C_API.C_Affine_2x3_F64) return Boolean
      is (Value.M00 = 0.0
          and then Value.M01 = 0.0
          and then Value.M02 = 0.0
          and then Value.M10 = 0.0
          and then Value.M11 = 0.0
          and then Value.M12 = 0.0);
   begin
      Status :=
        C_API.Get_Affine_Transform (Source'Access, Destination'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then C_API.Last_Error_Message'Length > 0,
         "a null affine output is rejected with a diagnostic");

      Status :=
        C_API.Get_Affine_Transform (null, Destination'Access, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Is_Zeroed (Output),
         "a null source is rejected and the output zeroed");

      Output := (others => 7.0);
      Status :=
        C_API.Get_Affine_Transform (Source'Access, null, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Is_Zeroed (Output),
         "a null destination is rejected and the output zeroed");

      Status :=
        C_API.Get_Affine_Transform
          (Source'Access, Destination'Access, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then abs (Output.M00 - 2.0) < 1.0E-9
         and then abs (Output.M12 - 20.0) < 1.0E-9,
         "a valid raw affine call succeeds");
      AUnit.Assertions.Assert
        (Source = Source_Copy and then Destination = Destination_Copy,
         "the shim does not write through its const point inputs");

      Status := C_API.Invert_Affine_Transform (Output'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "a null inverse output is rejected");

      declare
         Inverse : aliased C_API.C_Affine_2x3_F64 := (others => 7.0);
      begin
         Status := C_API.Invert_Affine_Transform (null, Inverse'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument and then Is_Zeroed (Inverse),
            "a null transform is rejected and the output zeroed");
      end;

      declare
         In_Place : aliased C_API.C_Affine_2x3_F64 :=
           (M00 => 1.0,
            M01 => 0.0,
            M02 => 5.0,
            M10 => 0.0,
            M11 => 1.0,
            M12 => -7.0);
      begin
         Status :=
           C_API.Invert_Affine_Transform (In_Place'Access, In_Place'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then In_Place.M02 = -5.0
            and then In_Place.M12 = 7.0
            and then In_Place.M00 = 1.0
            and then In_Place.M11 = 1.0,
            "an aliased input and output invert in place");
      end;

      declare
         --  The shim leaves finiteness policy to thick Ada and does not
         --  reject raw non-finite values itself. Whether OpenCV accepts them
         --  is not part of this contract.
         Raw_Input : aliased constant C_API.C_Affine_2x3_F64 :=
           (M00 => 1.0,
            M01 => 0.0,
            M02 => Bits_To_C_Double (16#7FF8_0000_0000_0000#),
            M10 => 0.0,
            M11 => 1.0,
            M12 => 0.0);
         Inverse   : aliased C_API.C_Affine_2x3_F64 := (others => 7.0);
      begin
         Status :=
           C_API.Invert_Affine_Transform (Raw_Input'Access, Inverse'Access);
         AUnit.Assertions.Assert
           (Status /= C_API.Error_Invalid_Argument,
            "the shim does not reject raw non-finite coefficients");
      end;
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform identity correspondence",
            Identity_Correspondence'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform translation", Translation'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform anisotropic scale",
            Anisotropic_Scale'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform rotation and scale",
            Rotation_And_Scale'Access));
      Result.Add_Test
        (Caller.Create ("Get_Affine_Transform shear", Shear'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform arbitrary triangle",
            Arbitrary_Triangle'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform negative coordinates",
            Negative_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform nonzero bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Affine transforms leave inputs unchanged",
            Inputs_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform degenerate triangles return zero",
            Degenerate_Triangles_Return_Zero'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Affine_Transform rejects invalid correspondences",
            Rejects_Invalid_Correspondences'Access));
      Result.Add_Test
        (Caller.Create
           ("Invert_Affine_Transform known inverses",
            Invert_Known_Transforms'Access));
      Result.Add_Test
        (Caller.Create
           ("Invert_Affine_Transform composes to identity",
            Inverse_Composition'Access));
      Result.Add_Test
        (Caller.Create
           ("Invert_Affine_Transform singular returns zero",
            Invert_Singular_Returns_Zero'Access));
      Result.Add_Test
        (Caller.Create
           ("Invert_Affine_Transform rejects non-finite coefficients",
            Invert_Rejects_Non_Finite'Access));
      Result.Add_Test
        (Caller.Create
           ("Affine Transform_Point values", Transform_Point_Values'Access));
      Result.Add_Test
        (Caller.Create
           ("Affine Transform_Point rejects invalid inputs",
            Transform_Point_Rejects_Invalid_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Affine transform C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Affine_Transform_Tests;
