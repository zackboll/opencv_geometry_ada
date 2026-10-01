with Ada.Numerics;
with Ada.Numerics.Generic_Elementary_Functions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Float32_Test_Support;
with Interfaces;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Float32_Fit_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;
   package Float64_Functions is new
     Ada.Numerics.Generic_Elementary_Functions (OpenCV.Float64_Value);

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Rotated_Rect;
   use type OpenCV.Geometry.Fitted_Line_2D;
   use type OpenCV.Geometry.Float32_Point_Array;

   subtype Points is Support.Points;
   subtype Float64 is OpenCV.Float64_Value;
   subtype Distance_Kind is OpenCV.Geometry.Line_Fit_Distance;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  Twelve binary32 points of the ellipse centered at (2.5, -1.25) with
   --  semi-axes 3.5 and 1.75, rotated by 30 degrees.
   function Ellipse_Points (Scale : Float64 := 1.0) return Points is
      Result : Points (0 .. 11);
      Theta  : constant Float64 := Ada.Numerics.Pi / 6.0;
   begin
      for Index in Result'Range loop
         declare
            T : constant Float64 :=
              (Float64 (Index) * 30.0 + 7.0) * Ada.Numerics.Pi / 180.0;
            U : constant Float64 := 3.5 * Float64_Functions.Cos (T);
            V : constant Float64 := 1.75 * Float64_Functions.Sin (T);
         begin
            Result (Index) :=
              (X =>
                 OpenCV.Float32_Value
                   (Scale
                    * (2.5
                       + U * Float64_Functions.Cos (Theta)
                       - V * Float64_Functions.Sin (Theta))),
               Y =>
                 OpenCV.Float32_Value
                   (Scale
                    * (-1.25
                       + U * Float64_Functions.Sin (Theta)
                       + V * Float64_Functions.Cos (Theta))));
         end;
      end loop;
      return Result;
   end Ellipse_Points;

   Expected_Ellipse : constant OpenCV.Rotated_Rect :=
     (Center        => (X => 2.5, Y => -1.25),
      Size          => (Width => 7.0, Height => 3.5),
      Angle_Degrees => 30.0);

   --  Nine integer points near an ellipse but not on one conic.
   Integer_Ellipse : constant OpenCV.Geometry.Contour :=
     ((X => 10, Y => 1),
      (X => 7, Y => 6),
      (X => 1, Y => 8),
      (X => -5, Y => 6),
      (X => -9, Y => 2),
      (X => -8, Y => -4),
      (X => -3, Y => -7),
      (X => 4, Y => -6),
      (X => 9, Y => -3));

   --  Seven points on the line Y = 0.5 * X + 0.375.
   Line_Points : constant Points :=
     ((X => 0.25, Y => 0.5),
      (X => 1.25, Y => 1.0),
      (X => 2.25, Y => 1.5),
      (X => 3.25, Y => 2.0),
      (X => 4.25, Y => 2.5),
      (X => 5.25, Y => 3.0),
      (X => 6.25, Y => 3.5));

   Integer_Line : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 1),
      (X => 2, Y => 2),
      (X => 4, Y => 2),
      (X => 6, Y => 4),
      (X => 8, Y => 5),
      (X => 10, Y => 5),
      (X => 12, Y => 7));

   function Relative_Error (Actual, Expected : Float64) return Float64
   is (abs (Actual - Expected) / Float64'Max (1.0, abs Expected));

   function Angle_Distance (Left, Right : Float64) return Float64 is
      Difference : constant Float64 := Float64'Remainder (Left - Right, 180.0);
   begin
      return abs Difference;
   end Angle_Distance;

   --  Largest relative error between two ellipse rectangles, allowing the
   --  native width and height to be swapped with a 90-degree angle change.
   function Ellipse_Error
     (Actual, Expected : OpenCV.Rotated_Rect) return Float64
   is
      Center : constant Float64 :=
        Float64'Max
          (Relative_Error
             (Float64 (Actual.Center.X), Float64 (Expected.Center.X)),
           Relative_Error
             (Float64 (Actual.Center.Y), Float64 (Expected.Center.Y)));
      Same   : constant Float64 :=
        Float64'Max
          (Float64'Max
             (Relative_Error
                (Float64 (Actual.Size.Width), Float64 (Expected.Size.Width)),
              Relative_Error
                (Float64 (Actual.Size.Height),
                 Float64 (Expected.Size.Height))),
           Angle_Distance
             (Float64 (Actual.Angle_Degrees), Float64 (Expected.Angle_Degrees))
           / 180.0);
      Turned : constant Float64 :=
        Float64'Max
          (Float64'Max
             (Relative_Error
                (Float64 (Actual.Size.Width), Float64 (Expected.Size.Height)),
              Relative_Error
                (Float64 (Actual.Size.Height), Float64 (Expected.Size.Width))),
           Angle_Distance
             (Float64 (Actual.Angle_Degrees),
              Float64 (Expected.Angle_Degrees) + 90.0)
           / 180.0);
   begin
      return Float64'Max (Center, Float64'Min (Same, Turned));
   end Ellipse_Error;

   function Scaled
     (Value : OpenCV.Rotated_Rect; Scale : Float64) return OpenCV.Rotated_Rect
   is ((Center        =>
          (X => OpenCV.Float32_Value (Float64 (Value.Center.X) * Scale),
           Y => OpenCV.Float32_Value (Float64 (Value.Center.Y) * Scale)),
        Size          =>
          (Width  => OpenCV.Float32_Value (Float64 (Value.Size.Width) * Scale),
           Height =>
             OpenCV.Float32_Value (Float64 (Value.Size.Height) * Scale)),
        Angle_Degrees => Value.Angle_Degrees));

   type Ellipse_Fit is
     access function (Source : Points) return OpenCV.Rotated_Rect;

   function Classic (Source : Points) return OpenCV.Rotated_Rect
   is (OpenCV.Geometry.Fit_Ellipse (Source));

   function AMS (Source : Points) return OpenCV.Rotated_Rect
   is (OpenCV.Geometry.Fit_Ellipse_AMS (Source));

   function Direct (Source : Points) return OpenCV.Rotated_Rect
   is (OpenCV.Geometry.Fit_Ellipse_Direct (Source));

   Fits : constant array (1 .. 3) of Ellipse_Fit :=
     (Classic'Access, AMS'Access, Direct'Access);

   --  Distance of Line's point from Y = 0.5 * X + 0.375, and the sine of
   --  the angle between Line's direction and (2, 1).
   function Point_Error (Line : OpenCV.Geometry.Fitted_Line_2D) return Float64
   is (abs (Float64 (Line.Point.Y) - (0.5 * Float64 (Line.Point.X) + 0.375)));

   function Direction_Error
     (Line : OpenCV.Geometry.Fitted_Line_2D) return Float64
   is (abs (Float64 (Line.Direction.X) - 2.0 * Float64 (Line.Direction.Y))
       / Float64_Functions.Sqrt (5.0));

   function Is_Unit (Line : OpenCV.Geometry.Fitted_Line_2D) return Boolean
   is (abs (Float64 (Line.Direction.X)
            **2
            + Float64 (Line.Direction.Y)**2
            - 1.0)
       <= 1.0E-6);

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Ellipse (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source  : constant Points := Ellipse_Points;
      Rounded : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse (Support.Rounded (Source));
   begin
      for Index in Fits'Range loop
         AUnit.Assertions.Assert
           (Ellipse_Error (Fits (Index) (Source), Expected_Ellipse) < 1.0E-4,
            "a fractional ellipse must be recovered by fit" & Index'Image);
      end loop;
      AUnit.Assertions.Assert
        (Ellipse_Error (Rounded, Expected_Ellipse) > 1.0E-2,
         "rounding the points must visibly change the fit");
   end Fractional_Ellipse;

   procedure Ellipse_Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Converted : constant Points := Support.To_Float32 (Integer_Ellipse);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Ellipse (Converted)
         = OpenCV.Geometry.Fit_Ellipse (Integer_Ellipse)
         and then OpenCV.Geometry.Fit_Ellipse_AMS (Converted)
                  = OpenCV.Geometry.Fit_Ellipse_AMS (Integer_Ellipse)
         and then OpenCV.Geometry.Fit_Ellipse_Direct (Converted)
                  = OpenCV.Geometry.Fit_Ellipse_Direct (Integer_Ellipse),
         "integer-valued Float32 fits must equal the integer overloads");
   end Ellipse_Integer_Equivalence;

   procedure Ellipse_Counts_And_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Source  : constant Points := Ellipse_Points;
      Five    : constant Points := Source (0 .. 4);
      Shifted : constant Points (100 .. 111) := Source;

      procedure Fit_Four is
         Unused : constant OpenCV.Rotated_Rect :=
           OpenCV.Geometry.Fit_Ellipse_AMS (Source (3 .. 6));
         pragma Unreferenced (Unused);
      begin
         null;
      end Fit_Four;
   begin
      AUnit.Assertions.Assert
        (Ellipse_Error
           (OpenCV.Geometry.Fit_Ellipse (Five),
            OpenCV.Geometry.Fit_Ellipse_Direct (Five))
         < 1.0E-4,
         "exactly five points must use the direct fit");
      AUnit.Assertions.Assert
        (Ellipse_Error
           (OpenCV.Geometry.Fit_Ellipse (Shifted), Expected_Ellipse)
         < 1.0E-4,
         "ellipse fits must not depend on the Ada lower bound");
      Support.Assert_Raises_OpenCV_Error
        (Fit_Four'Access, "fewer than five points must raise");
   end Ellipse_Counts_And_Bounds;

   procedure Ellipse_Coordinate_Sum_Limit (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Scale     : constant := 1.0E+29;
      Large     : constant Points := Ellipse_Points (Scale);
      Too_Large : constant Points (1 .. 5) :=
        (others => (X => 3.0E+30, Y => 1.0));

      procedure Fit_Too_Large is
         Unused : constant OpenCV.Rotated_Rect :=
           OpenCV.Geometry.Fit_Ellipse_Direct (Too_Large);
         pragma Unreferenced (Unused);
      begin
         null;
      end Fit_Too_Large;
   begin
      for Index in Fits'Range loop
         AUnit.Assertions.Assert
           (Ellipse_Error
              (Fits (Index) (Large), Scaled (Expected_Ellipse, Scale))
            < 1.0E-4,
            "coordinates summing below 2.0**103 must be fitted by fit"
            & Index'Image);
      end loop;
      Support.Assert_Raises_OpenCV_Error
        (Fit_Too_Large'Access,
         "coordinates summing above 2.0**103 must raise");
   end Ellipse_Coordinate_Sum_Limit;

   procedure Fractional_Line (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Distance in Distance_Kind loop
         declare
            Line : constant OpenCV.Geometry.Fitted_Line_2D :=
              OpenCV.Geometry.Fit_Line_2D (Line_Points, Distance);
         begin
            AUnit.Assertions.Assert
              (Is_Unit (Line)
               and then Direction_Error (Line) < 1.0E-6
               and then Point_Error (Line) < 1.0E-6,
               "an exact line with fractional intercept must be recovered "
               & "by "
               & Distance'Image);
         end;
      end loop;
      declare
         Rounded : constant OpenCV.Geometry.Fitted_Line_2D :=
           OpenCV.Geometry.Fit_Line_2D (Support.Rounded (Line_Points));
      begin
         AUnit.Assertions.Assert
           (Point_Error (Rounded) > 1.0E-2
            or else Direction_Error (Rounded) > 1.0E-2,
            "fitting rounded points must not recover the fractional line");
      end;
   end Fractional_Line;

   procedure Robust_Line (Test : in out Fixture) is
      pragma Unreferenced (Test);
      With_Outlier : constant Points :=
        Line_Points & OpenCV.Float32_Point'(X => 3.75, Y => 9.0);
      L2_Error     : constant Float64 :=
        Direction_Error (OpenCV.Geometry.Fit_Line_2D (With_Outlier));
   begin
      for Distance in OpenCV.Geometry.L1 .. OpenCV.Geometry.Huber loop
         AUnit.Assertions.Assert
           (Direction_Error
              (OpenCV.Geometry.Fit_Line_2D (With_Outlier, Distance))
            < L2_Error,
            Distance'Image & " must resist the outlier better than L2");
      end loop;
   end Robust_Line;

   procedure Line_Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Converted : constant Points := Support.To_Float32 (Integer_Line);
   begin
      for Distance in Distance_Kind loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Fit_Line_2D (Converted, Distance)
            = OpenCV.Geometry.Fit_Line_2D (Integer_Line, Distance),
            "integer-valued Float32 line must equal the integer overload for "
            & Distance'Image);
      end loop;
   end Line_Integer_Equivalence;

   procedure Line_Order_And_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Reversed : Points (Line_Points'Range);
      Shifted  : constant Points (70 .. 76) := Line_Points;
      Forward  : constant OpenCV.Geometry.Fitted_Line_2D :=
        OpenCV.Geometry.Fit_Line_2D (Line_Points);
   begin
      for Offset in 0 .. Line_Points'Length - 1 loop
         Reversed (Reversed'First + Offset) :=
           Line_Points (Line_Points'Last - Offset);
      end loop;
      AUnit.Assertions.Assert
        (Point_Error (OpenCV.Geometry.Fit_Line_2D (Reversed)) < 1.0E-6
         and then Direction_Error (OpenCV.Geometry.Fit_Line_2D (Reversed))
                  < 1.0E-6,
         "reversed points must fit the same L2 line");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D (Shifted) = Forward,
         "the fit must not depend on the Ada lower bound");
   end Line_Order_And_Bounds;

   procedure Line_Large_Offset (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Offset_Points : Points (Line_Points'Range);
      Line          : OpenCV.Geometry.Fitted_Line_2D;
   begin
      for Index in Line_Points'Range loop
         Offset_Points (Index) :=
           (X => Line_Points (Index).X + 1.0E+4,
            Y => Line_Points (Index).Y + 2.0E+4);
      end loop;
      Line := OpenCV.Geometry.Fit_Line_2D (Offset_Points);
      AUnit.Assertions.Assert
        (Is_Unit (Line)
         and then abs (Float64 (Line.Point.X) - 10003.25) < 1.0E-2
         and then abs (Float64 (Line.Point.Y) - 20002.0) < 1.0E-2,
         "a line far from the origin must still pass through the centroid");
   end Line_Large_Offset;

   procedure Line_Overflow_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Huge : constant Points :=
        ((X => 1.0E+20, Y => 1.0E+20),
         (X => 2.0E+20, Y => 2.5E+20),
         (X => 3.0E+20, Y => 3.0E+20));

      procedure Fit_L2 is
         Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
           OpenCV.Geometry.Fit_Line_2D (Huge);
         pragma Unreferenced (Unused);
      begin
         null;
      end Fit_L2;

      procedure Fit_Huber is
         Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
           OpenCV.Geometry.Fit_Line_2D (Huge, OpenCV.Geometry.Huber);
         pragma Unreferenced (Unused);
      begin
         null;
      end Fit_Huber;

      --  A vertical line at X = 9.0E+18, below 2.0**63, and at 2.0E+19,
      --  where only the X products overflow and OpenCV would report the
      --  direction (1, 0).
      function Vertical (X : OpenCV.Float32_Value) return Points
      is ((X => X, Y => -3.0), (X => X, Y => 0.5), (X => X, Y => 4.0));

      procedure Fit_Far_Vertical is
         Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
           OpenCV.Geometry.Fit_Line_2D (Vertical (2.0E+19));
         pragma Unreferenced (Unused);
      begin
         null;
      end Fit_Far_Vertical;

      Near : constant OpenCV.Geometry.Fitted_Line_2D :=
        OpenCV.Geometry.Fit_Line_2D (Vertical (9.0E+18));
   begin
      Support.Assert_Raises_OpenCV_Error
        (Fit_L2'Access, "overflowing binary32 products must raise for L2");
      Support.Assert_Raises_OpenCV_Error
        (Fit_Huber'Access, "a robust fit with no finite candidate must raise");
      AUnit.Assertions.Assert
        (abs Float64 (Near.Direction.X) < 1.0E-6
         and then abs (abs Float64 (Near.Direction.Y) - 1.0) < 1.0E-6,
         "a vertical line within 2.0**63 must be fitted as vertical");
      Support.Assert_Raises_OpenCV_Error
        (Fit_Far_Vertical'Access,
         "coordinates above 2.0**63 must raise rather than fit wrongly");
   end Line_Overflow_Rejected;

   procedure Line_Minimal_And_Invalid (Test : in out Fixture) is
      pragma Unreferenced (Test);
      One   : constant Points := (0 => (X => 1.25, Y => -0.75));
      Empty : constant Points (1 .. 0) := (others => (0.0, 0.0));

      procedure Fit_Empty is
         Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
           OpenCV.Geometry.Fit_Line_2D (Empty);
         pragma Unreferenced (Unused);
      begin
         null;
      end Fit_Empty;

      procedure Fit_Negative_Parameter is
         Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
           OpenCV.Geometry.Fit_Line_2D
             (Line_Points, OpenCV.Geometry.Fair, Parameter => -1.0);
         pragma Unreferenced (Unused);
      begin
         null;
      end Fit_Negative_Parameter;
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D (One).Point = One (One'First)
         and then Is_Unit (OpenCV.Geometry.Fit_Line_2D (One)),
         "a one-point fit passes through its point");
      Support.Assert_Raises_OpenCV_Error
        (Fit_Empty'Access, "an empty fit must raise");
      Support.Assert_Raises_OpenCV_Error
        (Fit_Negative_Parameter'Access, "a negative parameter must raise");
   end Line_Minimal_And_Invalid;

   procedure Classic_Candidate (Candidate : Points) is
      Unused : constant OpenCV.Rotated_Rect := Classic (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Classic_Candidate;

   procedure AMS_Candidate (Candidate : Points) is
      Unused : constant OpenCV.Rotated_Rect := AMS (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end AMS_Candidate;

   procedure Direct_Candidate (Candidate : Points) is
      Unused : constant OpenCV.Rotated_Rect := Direct (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Direct_Candidate;

   procedure Line_Candidate (Candidate : Points) is
      Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
        OpenCV.Geometry.Fit_Line_2D (Candidate, OpenCV.Geometry.Welsch);
      pragma Unreferenced (Unused);
   begin
      null;
   end Line_Candidate;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (20 .. 31) := Ellipse_Points;
   begin
      Support.Assert_Rejects_Non_Finite
        (Shifted, Classic_Candidate'Access, "Fit_Ellipse");
      Support.Assert_Rejects_Non_Finite
        (Shifted, AMS_Candidate'Access, "Fit_Ellipse_AMS");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Direct_Candidate'Access, "Fit_Ellipse_Direct");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Line_Candidate'Access, "Fit_Line_2D");
   end Non_Finite_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Ellipse_Points);
      Box    : aliased C_API.C_Rotated_Rect :=
        (Center_X      => 9.0,
         Center_Y      => 9.0,
         Width         => 9.0,
         Height        => 9.0,
         Angle_Degrees => 9.0);
      Line   : aliased C_API.C_Line_2D :=
        (Direction_X => 9.0,
         Direction_Y => 9.0,
         Point_X     => 9.0,
         Point_Y     => 9.0);
      Status : C_API.Status;
   begin
      --  Counts are checked before any point is read.
      Status :=
        C_API.Fit_Ellipse_F32
          (Packed (Packed'First)'Access,
           Interfaces.Integer_32'Last / 13 + 1,
           Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("allocation")
         and then OpenCV.Float32_Value (Box.Width) = 0.0,
         "an ellipse count above INT32_MAX / 13 must be rejected");
      Status :=
        C_API.Fit_Ellipse_AMS_F32
          (Packed (Packed'First)'Access,
           Interfaces.Integer_32'Last / 13 + 1,
           Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("allocation"),
         "an AMS count above INT32_MAX / 13 must be rejected");
      Status := C_API.Fit_Ellipse_Direct_F32 (null, 7, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("points"),
         "null ellipse points with positive count must be rejected");
      Status := C_API.Fit_Ellipse_F32 (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null ellipse output must be rejected");
      Status :=
        C_API.Fit_Line_2D_F32
          (Packed (Packed'First)'Access,
           Interfaces.Integer_32'Last / 2 + 1,
           C_API.Line_Fit_L1,
           0.0,
           0.01,
           0.01,
           Line'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("allocation")
         and then OpenCV.Float32_Value (Line.Direction_X) = 0.0,
         "a line count above INT32_MAX / 2 must be rejected");
      Status :=
        C_API.Fit_Line_2D_F32
          (Packed (Packed'First)'Access, 12, 6, 0.0, 0.01, 0.01, Line'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("distance"),
         "an invalid distance selector must be rejected");
      Status :=
        C_API.Fit_Line_2D_F32
          (null, 0, C_API.Line_Fit_L2, 0.0, 0.01, 0.01, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null line output must be rejected");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 ellipse fits fractional ellipse",
            Fractional_Ellipse'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 ellipse fits equal integer overloads",
            Ellipse_Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 ellipse fits counts and bounds",
            Ellipse_Counts_And_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 ellipse fits coordinate sum limit",
            Ellipse_Coordinate_Sum_Limit'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 line fit fractional line", Fractional_Line'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 line fit robust distances", Robust_Line'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 line fit equals integer overload",
            Line_Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 line fit order and bounds",
            Line_Order_And_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 line fit large offset", Line_Large_Offset'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 line fit overflow raises",
            Line_Overflow_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 line fit minimal and invalid",
            Line_Minimal_And_Invalid'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 fits reject non-finite coordinates",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 fits C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Float32_Fit_Tests;
