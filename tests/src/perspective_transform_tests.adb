with Ada.Numerics.Generic_Elementary_Functions;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Perspective_Transform_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Float64_Functions is new
     Ada.Numerics.Generic_Elementary_Functions (OpenCV.Float64_Value);

   use type C_API.Status;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Geometry.Float32_Point_Array;
   use type OpenCV.Geometry.Perspective_Row_Index;
   use type OpenCV.Geometry.Transform_Column_Index;

   subtype Homography is OpenCV.Geometry.Perspective_Transform_2D;
   subtype Points is OpenCV.Geometry.Float32_Point_Array;
   subtype Method is OpenCV.Geometry.Perspective_Solve_Method;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Float32_Value);

   function Bits_To_C_Float is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => Interfaces.C.C_float);

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

   Coefficient_Tolerance : constant := 1.0E-9;
   Point_Tolerance       : constant := 1.0E-4;

   Unit_Square : constant Points :=
     ((X => 0.0, Y => 0.0),
      (X => 1.0, Y => 0.0),
      (X => 1.0, Y => 1.0),
      (X => 0.0, Y => 1.0));

   General_Quad : constant Points :=
     ((X => 10.0, Y => 10.0),
      (X => 30.0, Y => 12.0),
      (X => 28.0, Y => 35.0),
      (X => 8.0, Y => 30.0));

   --  Three collinear source points make the c22 = 1 system singular.
   Collinear_Quad : constant Points :=
     ((X => 0.0, Y => 0.0),
      (X => 1.0, Y => 1.0),
      (X => 2.0, Y => 2.0),
      (X => 0.0, Y => 1.0));

   function Nearly_Equal
     (Left, Right : OpenCV.Float64_Value; Tolerance : OpenCV.Float64_Value)
      return Boolean
   is (abs (Left - Right) <= Tolerance);

   function Frobenius_Norm (Value : Homography) return OpenCV.Float64_Value is
      Sum : OpenCV.Float64_Value := 0.0;
   begin
      for Coefficient of Value loop
         Sum := Sum + Coefficient * Coefficient;
      end loop;
      return Float64_Functions.Sqrt (Sum);
   end Frobenius_Norm;

   --  OpenCV before 4.12 with LU or QR: only T (3, 3) = 1.0 is nonzero.
   function Is_Singular_Pattern (Value : Homography) return Boolean is
   begin
      for Row in Value'Range (1) loop
         for Column in Value'Range (2) loop
            if Value (Row, Column)
              /= (if Row = 3 and then Column = 3 then 1.0 else 0.0)
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Is_Singular_Pattern;

   function Is_Unit_Norm (Value : Homography) return Boolean
   is (Nearly_Equal (Frobenius_Norm (Value), 1.0, 1.0E-9));

   function Major_Version return Interfaces.Integer_32
   is (C_API.OpenCV_Major_Version);

   procedure Assert_Homography
     (Actual    : Homography;
      Expected  : Homography;
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
   end Assert_Homography;

   procedure Assert_Maps
     (Transform : Homography; Source, Destination : Points; Message : String)
   is
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

   procedure Identity_For_Every_Method (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Solver in Method loop
         Assert_Homography
           (OpenCV.Geometry.Get_Perspective_Transform
              (General_Quad, General_Quad, Solver),
            OpenCV.Geometry.Identity_Perspective_Transform,
            "identity correspondence with " & Solver'Image);
      end loop;
   end Identity_For_Every_Method;

   procedure Translation_Like (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Destination : constant Points :=
        ((X => 3.0, Y => 4.0),
         (X => 4.0, Y => 4.0),
         (X => 4.0, Y => 5.0),
         (X => 3.0, Y => 5.0));
   begin
      Assert_Homography
        (OpenCV.Geometry.Get_Perspective_Transform (Unit_Square, Destination),
         ((1.0, 0.0, 3.0), (0.0, 1.0, 4.0), (0.0, 0.0, 1.0)),
         "translation homography");
   end Translation_Like;

   procedure Scale_And_Shear (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  X' = 2X + Y, Y' = 3Y: an affine map, so the last row is (0, 0, 1).
      Destination : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 2.0, Y => 0.0),
         (X => 3.0, Y => 3.0),
         (X => 1.0, Y => 3.0));
   begin
      Assert_Homography
        (OpenCV.Geometry.Get_Perspective_Transform (Unit_Square, Destination),
         ((2.0, 1.0, 0.0), (0.0, 3.0, 0.0), (0.0, 0.0, 1.0)),
         "scale and shear homography");
   end Scale_And_Shear;

   procedure Rotation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A quarter turn counter-clockwise about the origin: (X, Y) maps to
      --  (-Y, X).
      Destination : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 0.0, Y => 1.0),
         (X => -1.0, Y => 1.0),
         (X => -1.0, Y => 0.0));
   begin
      for Solver in Method loop
         Assert_Homography
           (OpenCV.Geometry.Get_Perspective_Transform
              (Unit_Square, Destination, Solver),
            ((0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
            "rotation homography with " & Solver'Image);
      end loop;
   end Rotation;

   procedure General_Quadrilateral (Test : in out Fixture) is
      pragma Unreferenced (Test);
      LU        : constant Homography :=
        OpenCV.Geometry.Get_Perspective_Transform (Unit_Square, General_Quad);
      Reference : constant Homography :=
        ((16.170212765957448, -2.1021276595744682, 10.0),
         (0.46808510638297873, 19.617021276595743, 10.0),
         (-0.1276595744680851, -0.01276595744680851, 1.0));
   begin
      for Solver in Method loop
         declare
            Transform : constant Homography :=
              OpenCV.Geometry.Get_Perspective_Transform
                (Unit_Square, General_Quad, Solver);
         begin
            Assert_Maps
              (Transform,
               Unit_Square,
               General_Quad,
               "general quadrilateral with " & Solver'Image);
            Assert_Homography
              (Transform,
               Reference,
               "general quadrilateral coefficients with " & Solver'Image,
               1.0E-9);
         end;
      end loop;
      AUnit.Assertions.Assert
        (LU (3, 3) = 1.0, "a regular correspondence has T (3, 3) = 1.0");
   end General_Quadrilateral;

   procedure Negative_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant Points :=
        ((X => -50.0, Y => -40.0),
         (X => -10.0, Y => -42.0),
         (X => -12.0, Y => -5.0),
         (X => -48.0, Y => -8.0));
      Destination : constant Points :=
        ((X => -1.0, Y => -1.0),
         (X => -0.2, Y => -1.1),
         (X => -0.1, Y => -0.1),
         (X => -1.2, Y => -0.3));
   begin
      for Solver in Method loop
         Assert_Maps
           (OpenCV.Geometry.Get_Perspective_Transform
              (Source, Destination, Solver),
            Source,
            Destination,
            "negative coordinates with " & Solver'Image);
      end loop;
   end Negative_Coordinates;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant Points (20 .. 23) := Unit_Square;
      Destination : constant Points (7 .. 10) := General_Quad;
   begin
      Assert_Homography
        (OpenCV.Geometry.Get_Perspective_Transform (Source, Destination),
         OpenCV.Geometry.Get_Perspective_Transform (Unit_Square, General_Quad),
         "points are paired in iteration order across different bounds",
         0.0);
   end Nonzero_Bounds;

   procedure Inputs_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source      : constant Points := General_Quad;
      Destination : constant Points := Unit_Square;
      Transform   : constant Homography :=
        OpenCV.Geometry.Get_Perspective_Transform (Source, Destination);
   begin
      AUnit.Assertions.Assert
        (Source = General_Quad
         and then Destination = Unit_Square
         and then Transform (3, 3) = 1.0,
         "Get_Perspective_Transform leaves its inputs unchanged");
   end Inputs_Unchanged;

   procedure Degenerate_Correspondence (Test : in out Fixture) is
      pragma Unreferenced (Test);

      type Method_List is array (Positive range <>) of Method;

      Singular_Reporting : constant Method_List :=
        (OpenCV.Geometry.LU_Decomposition, OpenCV.Geometry.QR_Decomposition);
   begin
      for Solver of Singular_Reporting loop
         declare
            Transform : constant Homography :=
              OpenCV.Geometry.Get_Perspective_Transform
                (Collinear_Quad, General_Quad, Solver);
         begin
            --  Before 4.12 OpenCV keeps only T (3, 3) = 1.0; 4.12+ and 5.x
            --  return the unit-norm homogeneous solution instead.
            AUnit.Assertions.Assert
              ((Major_Version = 4 and then Is_Singular_Pattern (Transform))
               or else Is_Unit_Norm (Transform),
               "a singular system with "
               & Solver'Image
               & " returns the documented native fallback");
            if Major_Version >= 5 then
               AUnit.Assertions.Assert
                 (Is_Unit_Norm (Transform),
                  "OpenCV 5 returns the unit-norm solution with "
                  & Solver'Image);
            end if;
         end;
      end loop;
   end Degenerate_Correspondence;

   procedure Singular_Value_Decomposition_Is_Distinct (Test : in out Fixture)
   is
      pragma Unreferenced (Test);
      --  With three collinear points mapped to themselves, the c22 = 1
      --  system is singular but consistent. SVD returns a least-squares
      --  solution that maps the points, while LU reports a singular system.
      SVD : constant Homography :=
        OpenCV.Geometry.Get_Perspective_Transform
          (Collinear_Quad,
           Collinear_Quad,
           OpenCV.Geometry.Singular_Value_Decomposition);
      LU  : constant Homography :=
        OpenCV.Geometry.Get_Perspective_Transform
          (Collinear_Quad, Collinear_Quad, OpenCV.Geometry.LU_Decomposition);
   begin
      if Is_Singular_Pattern (LU) then
         --  OpenCV before 4.12 keeps each solver's c22 = 1 result, so the
         --  methods are distinguishable: LU returns the singular pattern and
         --  SVD a least-squares solution that maps the points.
         Assert_Maps (SVD, Collinear_Quad, Collinear_Quad, "SVD solution");
         AUnit.Assertions.Assert
           (SVD (3, 3) = 1.0 and then not Is_Singular_Pattern (SVD),
            "the SVD least-squares solution keeps T (3, 3) = 1.0");
         AUnit.Assertions.Assert
           (Major_Version = 4, "only OpenCV 4 returns the singular pattern");
      else
         --  From 4.12 either solution may fail OpenCV's residual check and
         --  take the unit-norm fallback, depending on rounding.
         if SVD (3, 3) = 1.0 then
            Assert_Maps (SVD, Collinear_Quad, Collinear_Quad, "SVD solution");
         else
            AUnit.Assertions.Assert
              (Is_Unit_Norm (SVD), "the SVD fallback has unit norm");
         end if;
         AUnit.Assertions.Assert
           (Is_Unit_Norm (LU), "LU takes the unit-norm fallback");
      end if;
   end Singular_Value_Decomposition_Is_Distinct;

   procedure Rejects_Invalid_Correspondences (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      Three : constant Points :=
        ((X => 0.0, Y => 0.0), (X => 1.0, Y => 0.0), (X => 0.0, Y => 1.0));

      procedure Too_Few_Source is
         Ignored : constant Homography :=
           OpenCV.Geometry.Get_Perspective_Transform (Three, Unit_Square);
      begin
         null;
      end Too_Few_Source;

      procedure Too_Many_Destination is
         Five    : constant Points :=
           Unit_Square & OpenCV.Float32_Point'(X => 5.0, Y => 5.0);
         Ignored : constant Homography :=
           OpenCV.Geometry.Get_Perspective_Transform (Unit_Square, Five);
      begin
         null;
      end Too_Many_Destination;

      procedure Nan_Destination is
         Bad : Points := General_Quad;
      begin
         Bad (Bad'First + 2).Y := NaN_32;
         declare
            Ignored : constant Homography :=
              OpenCV.Geometry.Get_Perspective_Transform (Unit_Square, Bad);
         begin
            null;
         end;
      end Nan_Destination;

      procedure Infinite_Source is
         Bad : Points := Unit_Square;
      begin
         Bad (Bad'First).X := Infinity_32;
         declare
            Ignored : constant Homography :=
              OpenCV.Geometry.Get_Perspective_Transform (Bad, General_Quad);
         begin
            null;
         end;
      end Infinite_Source;
   begin
      Assert_Raises_OpenCV_Error
        (Too_Few_Source'Access, "three source points are rejected");
      Assert_Raises_OpenCV_Error
        (Too_Many_Destination'Access, "five destination points are rejected");
      Assert_Raises_OpenCV_Error
        (Nan_Destination'Access, "a NaN destination coordinate is rejected");
      Assert_Raises_OpenCV_Error
        (Infinite_Source'Access, "an infinite source coordinate is rejected");
   end Rejects_Invalid_Correspondences;

   procedure Transform_Point_Values (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  (U, V, W) = (X + 1, Y, X + 2).
      Transform : constant Homography :=
        ((1.0, 0.0, 1.0), (0.0, 1.0, 0.0), (1.0, 0.0, 2.0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Transform_Point (Transform, (X => 2.0, Y => 8.0))
         = (X => 0.75, Y => 2.0),
         "Transform_Point divides by W");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Transform_Point
           (OpenCV.Geometry.Identity_Perspective_Transform,
            (X => -3.5, Y => 7.25))
         = (X => -3.5, Y => 7.25),
         "the identity maps a point to itself");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Transform_Point
           (Homography'((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, -2.0)),
            (X => 3.0, Y => -4.0))
         = (X => -1.5, Y => 2.0),
         "a negative W flips the sign");
   end Transform_Point_Values;

   procedure Transform_Point_Rejects_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      procedure Point_At_Infinity is
         --  W = X - 1 vanishes at X = 1.
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (Homography'((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (1.0, 0.0, -1.0)),
              (X => 1.0, Y => 5.0));
      begin
         null;
      end Point_At_Infinity;

      procedure Result_Beyond_Binary32 is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (Homography'
                ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0E-38)),
              (X => 10.0, Y => 0.0));
      begin
         null;
      end Result_Beyond_Binary32;

      procedure Coefficient_Above_Bound is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (Homography'
                ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0E+300)),
              (X => 1.0, Y => 1.0));
      begin
         null;
      end Coefficient_Above_Bound;

      procedure Nan_Point is
         Ignored : constant OpenCV.Float32_Point :=
           OpenCV.Geometry.Transform_Point
             (OpenCV.Geometry.Identity_Perspective_Transform,
              (X => 0.0, Y => NaN_32));
      begin
         null;
      end Nan_Point;
   begin
      Assert_Raises_OpenCV_Error
        (Point_At_Infinity'Access, "W = 0 is rejected");
      Assert_Raises_OpenCV_Error
        (Result_Beyond_Binary32'Access,
         "a result outside binary32 range is rejected");
      Assert_Raises_OpenCV_Error
        (Coefficient_Above_Bound'Access,
         "a coefficient above 1.0E+269 is rejected");
      Assert_Raises_OpenCV_Error (Nan_Point'Access, "a NaN point is rejected");
   end Transform_Point_Rejects_Invalid_Inputs;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      Source      : aliased C_API.C_Quad_Points :=
        (Points => ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)));
      Destination : aliased constant C_API.C_Quad_Points :=
        (Points => ((10.0, 10.0), (30.0, 12.0), (28.0, 35.0), (8.0, 30.0)));
      Output      : aliased C_API.C_Perspective_3x3_F64 := (others => 7.0);
      Status      : C_API.Status;

      function Is_Zeroed (Value : C_API.C_Perspective_3x3_F64) return Boolean
      is (Value.M00 = 0.0
          and then Value.M01 = 0.0
          and then Value.M02 = 0.0
          and then Value.M10 = 0.0
          and then Value.M11 = 0.0
          and then Value.M12 = 0.0
          and then Value.M20 = 0.0
          and then Value.M21 = 0.0
          and then Value.M22 = 0.0);

      Invalid_Selectors :
        constant array (Positive range <>) of Interfaces.Integer_32 :=
          (-1,
           3,
           4,
           16,
           17,
           Interfaces.Integer_32'Last,
           Interfaces.Integer_32'First);
   begin
      Status :=
        C_API.Get_Perspective_Transform
          (Source'Access,
           Destination'Access,
           C_API.Perspective_Solve_LU,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then C_API.Last_Error_Message'Length > 0,
         "a null perspective output is rejected with a diagnostic");

      Status :=
        C_API.Get_Perspective_Transform
          (null,
           Destination'Access,
           C_API.Perspective_Solve_LU,
           Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Is_Zeroed (Output),
         "a null source is rejected and the output zeroed");

      Output := (others => 7.0);
      Status :=
        C_API.Get_Perspective_Transform
          (Source'Access, null, C_API.Perspective_Solve_SVD, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Is_Zeroed (Output),
         "a null destination is rejected and the output zeroed");

      for Selector of Invalid_Selectors loop
         Output := (others => 7.0);
         Status :=
           C_API.Get_Perspective_Transform
             (Source'Access, Destination'Access, Selector, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Is_Zeroed (Output)
            and then C_API.Last_Error_Message'Length > 0,
            "solve selector" & Selector'Image & " is rejected");
      end loop;

      for Selector in C_API.Perspective_Solve_LU .. C_API.Perspective_Solve_QR
      loop
         Status :=
           C_API.Get_Perspective_Transform
             (Source'Access, Destination'Access, Selector, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then abs (Output.M00 - 16.170212765957448) < 1.0E-9
            and then Output.M22 = 1.0,
            "solve selector" & Selector'Image & " succeeds");
      end loop;

      --  The shim leaves finiteness policy to thick Ada and does not reject
      --  raw non-finite values itself. Whether OpenCV accepts them is not
      --  part of this contract.
      Source.Points (2).X := Bits_To_C_Float (16#7FC0_0000#);
      Status :=
        C_API.Get_Perspective_Transform
          (Source'Access,
           Destination'Access,
           C_API.Perspective_Solve_LU,
           Output'Access);
      AUnit.Assertions.Assert
        (Status /= C_API.Error_Invalid_Argument,
         "the shim does not reject raw non-finite points");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform identity for every method",
            Identity_For_Every_Method'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform translation", Translation_Like'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform scale and shear",
            Scale_And_Shear'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform rotation", Rotation'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform general quadrilateral",
            General_Quadrilateral'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform negative coordinates",
            Negative_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform nonzero bounds",
            Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform leaves inputs unchanged",
            Inputs_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform degenerate correspondence",
            Degenerate_Correspondence'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform SVD is distinct from LU",
            Singular_Value_Decomposition_Is_Distinct'Access));
      Result.Add_Test
        (Caller.Create
           ("Get_Perspective_Transform rejects invalid correspondences",
            Rejects_Invalid_Correspondences'Access));
      Result.Add_Test
        (Caller.Create
           ("Perspective Transform_Point values",
            Transform_Point_Values'Access));
      Result.Add_Test
        (Caller.Create
           ("Perspective Transform_Point rejects invalid inputs",
            Transform_Point_Rejects_Invalid_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Perspective transform C ABI validation",
            C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Perspective_Transform_Tests;
