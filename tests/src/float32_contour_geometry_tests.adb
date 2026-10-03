with Ada.Numerics.Generic_Elementary_Functions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Float32_Test_Support;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Float32_Contour_Geometry_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;
   package Float64_Functions is new
     Ada.Numerics.Generic_Elementary_Functions (OpenCV.Float64_Value);

   use type C_API.Rect_I32;
   use type C_API.Status;
   use type Interfaces.C.C_float;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Rect;
   use type OpenCV.Size_Coordinate;

   subtype Points is Support.Points;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  A right triangle with legs 3.25 and 2.25 and no integer vertex. Its
   --  coordinates and its area are exact binary32 values.
   Triangle : constant Points :=
     ((X => 0.5, Y => 0.25), (X => 3.75, Y => 0.25), (X => 0.5, Y => 2.5));

   Triangle_Area : constant := 3.65625;

   --  A convex integer pentagon and the same points as Float32 values.
   Pentagon : constant OpenCV.Geometry.Contour :=
     ((X => -3, Y => 1),
      (X => 5, Y => -2),
      (X => 9, Y => 4),
      (X => 2, Y => 8),
      (X => -1, Y => 6));

   Float32_Pentagon : constant Points :=
     ((X => -3.0, Y => 1.0),
      (X => 5.0, Y => -2.0),
      (X => 9.0, Y => 4.0),
      (X => 2.0, Y => 8.0),
      (X => -1.0, Y => 6.0));

   --  A concave integer contour and its Float32 counterpart.
   Notched : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 2, Y => 1),
      (X => 4, Y => 4),
      (X => 0, Y => 4));

   Float32_Notched : constant Points :=
     ((X => 0.0, Y => 0.0),
      (X => 4.0, Y => 0.0),
      (X => 2.0, Y => 1.0),
      (X => 4.0, Y => 4.0),
      (X => 0.0, Y => 4.0));

   function Close
     (Actual, Expected, Tolerance : OpenCV.Float64_Value) return Boolean
   is (abs (Actual - Expected)
       <= Tolerance * OpenCV.Float64_Value'Max (1.0, abs Expected));

   function Reversed (Source : Points) return Points is
      Result : Points (Source'Range);
   begin
      for Offset in 0 .. Source'Length - 1 loop
         Result (Source'First + Offset) := Source (Source'Last - Offset);
      end loop;
      return Result;
   end Reversed;

   function Contains_All (Box : OpenCV.Rect; Source : Points) return Boolean is
      Left   : constant OpenCV.Float64_Value := OpenCV.Float64_Value (Box.X);
      Bottom : constant OpenCV.Float64_Value := OpenCV.Float64_Value (Box.Y);
      Right  : constant OpenCV.Float64_Value :=
        Left + OpenCV.Float64_Value (Box.Width);
      Top    : constant OpenCV.Float64_Value :=
        Bottom + OpenCV.Float64_Value (Box.Height);
   begin
      for Point of Source loop
         if OpenCV.Float64_Value (Point.X) < Left
           or else OpenCV.Float64_Value (Point.X) >= Right
           or else OpenCV.Float64_Value (Point.Y) < Bottom
           or else OpenCV.Float64_Value (Point.Y) >= Top
         then
            return False;
         end if;
      end loop;
      return True;
   end Contains_All;

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Area_And_Length (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hypotenuse : constant OpenCV.Float64_Value :=
        Float64_Functions.Sqrt (3.25 * 3.25 + 2.25 * 2.25);
      Length     : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Arc_Length (Triangle, Closed => True);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Triangle) = Triangle_Area,
         "fractional triangle area must be exact");
      AUnit.Assertions.Assert
        (Close (Length, 5.5 + Hypotenuse, 1.0E-6),
         "fractional triangle perimeter must include its binary32 sides");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Arc_Length (Triangle, Closed => False)
         = Length - 2.25,
         "open fractional length must omit the closing edge");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Support.Rounded (Triangle)) = 4.5
         and then OpenCV.Geometry.Contour_Area (Support.Rounded (Triangle))
                  /= OpenCV.Geometry.Contour_Area (Triangle),
         "rounding the vertices must change the area");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Arc_Length (Support.Rounded (Triangle), True)
         /= Length,
         "rounding the vertices must change the perimeter");
   end Fractional_Area_And_Length;

   procedure Oriented_Area (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Forward : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Contour_Area (Triangle, Oriented => True);
      Back    : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Contour_Area (Reversed (Triangle), Oriented => True);
   begin
      AUnit.Assertions.Assert
        (abs Forward = Triangle_Area and then Back = -Forward,
         "reversing the point order must reverse the oriented area sign");
      AUnit.Assertions.Assert
        ((Forward > 0.0)
         = (OpenCV.Geometry.Contour_Area
              (Support.Rounded (Triangle), Oriented => True)
            > 0.0),
         "Float32 orientation sign must follow the integer convention");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Reversed (Triangle)) = Triangle_Area,
         "unoriented area must not depend on point order");
   end Oriented_Area;

   procedure Degenerate_Point_Sets (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty      : constant Points (1 .. 0) := (others => (0.0, 0.0));
      One_Point  : constant Points := (0 => (X => 0.5, Y => -1.5));
      Two_Points : constant Points :=
        ((X => 0.5, Y => 0.5), (X => 3.5, Y => 4.5));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Empty) = 0.0
         and then OpenCV.Geometry.Arc_Length (Empty, Closed => True) = 0.0,
         "empty Float32 point set must have zero area and length");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (One_Point) = 0.0
         and then OpenCV.Geometry.Arc_Length (One_Point, Closed => True) = 0.0,
         "one-point Float32 set must have zero area and length");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Arc_Length (Two_Points, Closed => False) = 5.0
         and then OpenCV.Geometry.Arc_Length (Two_Points, Closed => True)
                  = 10.0
         and then OpenCV.Geometry.Contour_Area (Two_Points) = 0.0,
         "two-point Float32 set must have one or two segments and no area");
   end Degenerate_Point_Sets;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (7 .. 9) := Triangle;
      Late    : constant Points (Natural'Last - 2 .. Natural'Last) := Triangle;
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Shifted, Oriented => True)
         = OpenCV.Geometry.Contour_Area (Triangle, Oriented => True)
         and then OpenCV.Geometry.Contour_Area (Late, Oriented => True)
                  = OpenCV.Geometry.Contour_Area (Triangle, Oriented => True),
         "Float32 area must not depend on the Ada lower bound");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Arc_Length (Shifted, Closed => False)
         = OpenCV.Geometry.Arc_Length (Triangle, Closed => False)
         and then OpenCV.Geometry.Arc_Length (Late, Closed => False)
                  = OpenCV.Geometry.Arc_Length (Triangle, Closed => False),
         "open Float32 length must follow iteration order for any bounds");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Bounding_Rect (Shifted)
         = OpenCV.Geometry.Bounding_Rect (Triangle)
         and then OpenCV.Geometry.Is_Convex (Late),
         "bounding rectangle and convexity must accept nonzero bounds");
   end Nonzero_Bounds;

   procedure Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Oriented in Boolean loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Contour_Area (Float32_Pentagon, Oriented)
            = OpenCV.Geometry.Contour_Area (Pentagon, Oriented)
            and then OpenCV.Geometry.Contour_Area (Float32_Notched, Oriented)
                     = OpenCV.Geometry.Contour_Area (Notched, Oriented),
            "integer-valued Float32 area must equal the integer overload");
      end loop;
      for Closed in Boolean loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Arc_Length (Float32_Pentagon, Closed)
            = OpenCV.Geometry.Arc_Length (Pentagon, Closed)
            and then OpenCV.Geometry.Arc_Length (Float32_Notched, Closed)
                     = OpenCV.Geometry.Arc_Length (Notched, Closed),
            "integer-valued Float32 length must equal the integer overload");
      end loop;
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Bounding_Rect (Float32_Pentagon)
         = OpenCV.Geometry.Bounding_Rect (Pentagon)
         and then OpenCV.Geometry.Bounding_Rect (Float32_Notched)
                  = OpenCV.Geometry.Bounding_Rect (Notched),
         "integer-valued Float32 bounding rectangle must equal the integer "
         & "overload");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Float32_Pentagon)
         and then OpenCV.Geometry.Is_Convex (Pentagon)
         and then not OpenCV.Geometry.Is_Convex (Float32_Notched)
         and then not OpenCV.Geometry.Is_Convex (Notched),
         "integer-valued Float32 convexity must equal the integer overload");
   end Integer_Equivalence;

   procedure Matches_Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Triangle);
      Value  : aliased Interfaces.C.double := 0.0;
      Box    : aliased C_API.Rect_I32 := (others => 0);
      Convex : aliased Interfaces.Integer_32 := -1;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Contour_Area_F32
          (Packed (Packed'First)'Access, Triangle'Length, 1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then OpenCV.Float64_Value (Value)
                  = OpenCV.Geometry.Contour_Area (Triangle, Oriented => True),
         "Contour_Area must return the raw C ABI area");
      Status :=
        C_API.Arc_Length_F32
          (Packed (Packed'First)'Access, Triangle'Length, 1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then OpenCV.Float64_Value (Value)
                  = OpenCV.Geometry.Arc_Length (Triangle, Closed => True),
         "Arc_Length must return the raw C ABI length");
      Status :=
        C_API.Bounding_Rect_F32
          (Packed (Packed'First)'Access, Triangle'Length, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then OpenCV.Geometry.Bounding_Rect (Triangle)
                  = (X      => OpenCV.Point_Coordinate (Box.X),
                     Y      => OpenCV.Point_Coordinate (Box.Y),
                     Width  => OpenCV.Size_Coordinate (Box.Width),
                     Height => OpenCV.Size_Coordinate (Box.Height)),
         "Bounding_Rect must return the raw C ABI rectangle");
      Status :=
        C_API.Is_Convex_F32
          (Packed (Packed'First)'Access, Triangle'Length, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Convex = 1
         and then OpenCV.Geometry.Is_Convex (Triangle),
         "Is_Convex must return the raw C ABI classification");
   end Matches_Raw_C_ABI;

   procedure Large_Finite_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Huge     : constant Points :=
        ((X => -3.0E+38, Y => -3.0E+38),
         (X => 3.0E+38, Y => -3.0E+38),
         (X => 3.0E+38, Y => 3.0E+38));
      Long     : constant Points :=
        ((X => 0.0, Y => 0.0), (X => 1.0E+19, Y => 0.0));
      Too_Long : constant Points :=
        ((X => 0.0, Y => 0.0), (X => 2.0E+19, Y => 0.0));

      procedure Measure_Too_Long is
         Unused : constant OpenCV.Float64_Value :=
           OpenCV.Geometry.Arc_Length (Too_Long, Closed => False);
         pragma Unreferenced (Unused);
      begin
         null;
      end Measure_Too_Long;
   begin
      AUnit.Assertions.Assert
        (Close
           (OpenCV.Geometry.Contour_Area (Huge),
            2.0 * OpenCV.Float64_Value (Huge (Huge'Last).X)**2,
            1.0E-6),
         "binary64 area accumulation must stay finite near Float32'Last");
      AUnit.Assertions.Assert
        (Close
           (OpenCV.Geometry.Arc_Length (Long, Closed => False),
            1.0E+19,
            1.0E-6),
         "a segment whose binary32 square is finite must be measured");
      Support.Assert_Raises_OpenCV_Error
        (Measure_Too_Long'Access,
         "a segment whose binary32 square overflows must raise");
   end Large_Finite_Coordinates;

   procedure Fractional_Bounding_Rect (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Scattered : constant Points :=
        ((X => 0.5, Y => -0.5),
         (X => 2.25, Y => 3.75),
         (X => -1.25, Y => 1.0));
      Box       : constant OpenCV.Rect :=
        OpenCV.Geometry.Bounding_Rect (Scattered);
      Integral  : constant Points :=
        ((X => 0.0, Y => 0.0), (X => 4.0, Y => 3.0));
      Empty     : constant Points (1 .. 0) := (others => (0.0, 0.0));
   begin
      AUnit.Assertions.Assert
        (Box = (X => -2, Y => -1, Width => 5, Height => 5),
         "Float32 bounding rectangle must floor the extreme coordinates");
      AUnit.Assertions.Assert
        (Contains_All (Box, Scattered),
         "every point must satisfy X <= P.X < X + Width");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Bounding_Rect (Support.Rounded (Scattered)) /= Box,
         "rounding the points must change the rectangle");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Bounding_Rect (Integral)
         = (X => 0, Y => 0, Width => 5, Height => 4),
         "integral maxima must lie in the last column and row");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Bounding_Rect (Empty)
         = (X => 0, Y => 0, Width => 0, Height => 0),
         "empty Float32 set must have an empty rectangle");
   end Fractional_Bounding_Rect;

   procedure Bounding_Rect_Limits (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Widest   : constant Points :=
        ((X => -2.0**31, Y => 0.0), (X => -2.0, Y => 1.5));
      Too_Wide : constant Points :=
        ((X => -2.0**31, Y => 0.0), (X => -1.0, Y => 0.0));
      Highest  : constant Points := (0 => (X => 2147483520.0, Y => -7.25));
      Too_High : constant Points := (0 => (X => 0.0, Y => 2.0**31));
      Too_Low  : constant Points := (0 => (X => -2147483904.0, Y => 0.0));

      procedure Bound_Source (Source : Points) is
         Unused : constant OpenCV.Rect :=
           OpenCV.Geometry.Bounding_Rect (Source);
         pragma Unreferenced (Unused);
      begin
         null;
      end Bound_Source;

      procedure Bound_Too_Wide is
      begin
         Bound_Source (Too_Wide);
      end Bound_Too_Wide;

      procedure Bound_Too_High is
      begin
         Bound_Source (Too_High);
      end Bound_Too_High;

      procedure Bound_Too_Low is
      begin
         Bound_Source (Too_Low);
      end Bound_Too_Low;
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Bounding_Rect (Widest)
         = (X      => OpenCV.Point_Coordinate'First,
            Y      => 0,
            Width  => OpenCV.Size_Coordinate'Last,
            Height => 2),
         "the widest representable extent must be accepted");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Bounding_Rect (Highest)
         = (X => 2147483520, Y => -8, Width => 1, Height => 1),
         "the largest cvFloor-convertible coordinate must be accepted");
      Support.Assert_Raises_OpenCV_Error
        (Bound_Too_Wide'Access, "an extent above Integer_32'Last must raise");
      Support.Assert_Raises_OpenCV_Error
        (Bound_Too_High'Access, "a coordinate of 2.0**31 must raise");
      Support.Assert_Raises_OpenCV_Error
        (Bound_Too_Low'Access, "a coordinate below -2.0**31 must raise");
   end Bounding_Rect_Limits;

   procedure Fractional_Convexity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Convex only because the second vertex lies below the X axis;
      --  rounding makes the first three vertices collinear.
      Kite    : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 1.0, Y => -0.375),
         (X => 2.0, Y => 0.0),
         (X => 1.0, Y => 2.0));
      Concave : constant Points :=
        ((X => 0.25, Y => 0.25),
         (X => 4.5, Y => 0.25),
         (X => 2.5, Y => 1.75),
         (X => 4.5, Y => 4.5),
         (X => 0.25, Y => 4.5));
      --  Convex only because the second vertex lies below Y = 0.5; flooring
      --  every coordinate makes the first three vertices collinear.
      Shallow : constant Points :=
        ((X => 0.0, Y => 0.5),
         (X => 1.75, Y => 0.25),
         (X => 3.0, Y => 0.5),
         (X => 1.5, Y => 3.0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Kite)
         and then OpenCV.Geometry.Is_Convex (Reversed (Kite)),
         "fractional convex kite must be convex in both directions");
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Support.Rounded (Kite)),
         "the rounded kite has collinear vertices and is not convex");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Shallow),
         "a quadrilateral that flooring would flatten must be convex");
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Concave),
         "fractional notched contour must not be convex");
   end Fractional_Convexity;

   procedure Convexity_Span_Limits (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Span product 1.0E+38, below Float32_Value'Last / 2.
      Large     : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 1.0E+19, Y => 0.0),
         (X => 1.0E+19, Y => 1.0E+19),
         (X => 0.0, Y => 1.0E+19));
      --  Span product 4.0E+38: OpenCV's binary32 cross products overflow.
      Too_Large : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 2.0E+19, Y => 0.0),
         (X => 2.0E+19, Y => 2.0E+19),
         (X => 0.0, Y => 2.0E+19));
      --  An X span of 6.0E+38 overflows a binary32 difference.
      Too_Wide  : constant Points :=
        ((X => -3.0E+38, Y => 0.0),
         (X => 3.0E+38, Y => 0.0),
         (X => 0.0, Y => 1.0E-30));

      procedure Test_Too_Large is
         Unused : constant Boolean := OpenCV.Geometry.Is_Convex (Too_Large);
         pragma Unreferenced (Unused);
      begin
         null;
      end Test_Too_Large;

      procedure Test_Too_Wide is
         Unused : constant Boolean := OpenCV.Geometry.Is_Convex (Too_Wide);
         pragma Unreferenced (Unused);
      begin
         null;
      end Test_Too_Wide;
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Large),
         "a square of side 1.0E+19 must be convex");
      Support.Assert_Raises_OpenCV_Error
        (Test_Too_Large'Access,
         "a span product above Float32_Value'Last / 2 must raise");
      Support.Assert_Raises_OpenCV_Error
        (Test_Too_Wide'Access, "a span above Float32_Value'Last must raise");
   end Convexity_Span_Limits;

   procedure Degenerate_Convexity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty     : constant Points (1 .. 0) := (others => (0.0, 0.0));
      One       : constant Points := (0 => (X => 0.5, Y => 0.5));
      Two       : constant Points :=
        ((X => 0.5, Y => 0.5), (X => 1.5, Y => 0.25));
      Collinear : constant Points :=
        ((X => 0.5, Y => 0.5), (X => 1.5, Y => 1.5), (X => 2.5, Y => 2.5));
   begin
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Empty)
         and then not OpenCV.Geometry.Is_Convex (One)
         and then not OpenCV.Geometry.Is_Convex (Two)
         and then not OpenCV.Geometry.Is_Convex (Collinear),
         "empty, short, and collinear Float32 sets must not be convex");
   end Degenerate_Convexity;

   procedure Area (Candidate : Points) is
      Unused : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Contour_Area (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Area;

   procedure Length (Candidate : Points) is
      Unused : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Arc_Length (Candidate, Closed => True);
      pragma Unreferenced (Unused);
   begin
      null;
   end Length;

   procedure Bound (Candidate : Points) is
      Unused : constant OpenCV.Rect :=
        OpenCV.Geometry.Bounding_Rect (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Bound;

   procedure Convexity (Candidate : Points) is
      Unused : constant Boolean := OpenCV.Geometry.Is_Convex (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Convexity;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (4 .. 6) := Triangle;
   begin
      Support.Assert_Rejects_Non_Finite (Shifted, Area'Access, "Contour_Area");
      Support.Assert_Rejects_Non_Finite (Shifted, Length'Access, "Arc_Length");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Bound'Access, "Bounding_Rect");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Convexity'Access, "Is_Convex");
   end Non_Finite_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Triangle);
      Value  : aliased Interfaces.C.double := -1.0;
      Box    : aliased C_API.Rect_I32 := (others => 7);
      Convex : aliased Interfaces.Integer_32 := 7;
      Status : C_API.Status;
   begin
      Status := C_API.Contour_Area_F32 (null, -1, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("count"),
         "negative area count must be rejected");
      Status := C_API.Contour_Area_F32 (null, 1, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("points"),
         "null area points with positive count must be rejected");
      Status :=
        C_API.Contour_Area_F32
          (Packed (Packed'First)'Access, 3, 2, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("oriented"),
         "invalid oriented selector must be rejected");
      Status := C_API.Contour_Area_F32 (null, 0, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null area output must be rejected");
      Status := C_API.Contour_Area_F32 (null, 0, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Value = 0.0,
         "empty area must succeed with zero");

      Status :=
        C_API.Arc_Length_F32
          (Packed (Packed'First)'Access, 3, -1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("closed"),
         "invalid closed selector must be rejected");
      Status := C_API.Arc_Length_F32 (null, 2, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("points"),
         "null length points with positive count must be rejected");
      Status := C_API.Arc_Length_F32 (null, 0, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null length output must be rejected");

      Status := C_API.Bounding_Rect_F32 (null, -1, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("count")
         and then Box = (others => 0),
         "negative bounding count must be rejected with a zero rectangle");
      Status := C_API.Bounding_Rect_F32 (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null bounding output must be rejected");

      Status := C_API.Is_Convex_F32 (null, 1, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("points")
         and then Convex = 0,
         "null convexity points must be rejected with a false result");
      Status := C_API.Is_Convex_F32 (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null convexity output must be rejected");
      Status := C_API.Is_Convex_F32 (null, 0, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Convex = 0,
         "empty convexity must succeed with false");
   end C_ABI_Validation;

   procedure Bounding_Rect_ABI_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Raw buffers bypass the Ada policy; NaN is stored directly.
      pragma Suppress (Validity_Check);
      Not_A_Number : aliased C_API.Point_F32_Array :=
        (0 => (X => 0.0, Y => 0.0), 1 => (X => Support.NaN_C, Y => 1.0));
      Beyond_Floor : aliased C_API.Point_F32_Array :=
        (0 => (X => 3.0E+9, Y => 0.0));
      Too_Wide     : aliased C_API.Point_F32_Array :=
        ((X => -2147483648.0, Y => 0.0), (X => -1.0, Y => 0.0));
      Box          : aliased C_API.Rect_I32 := (others => 7);
      Status       : C_API.Status;
   begin
      Status :=
        C_API.Bounding_Rect_F32
          (Not_A_Number (Not_A_Number'First)'Access, 2, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("cvFloor")
         and then Box = (others => 0),
         "NaN must be rejected before native cvFloor");
      Status :=
        C_API.Bounding_Rect_F32
          (Beyond_Floor (Beyond_Floor'First)'Access, 1, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("cvFloor"),
         "coordinates beyond int range must be rejected before cvFloor");
      Status :=
        C_API.Bounding_Rect_F32
          (Too_Wide (Too_Wide'First)'Access, 2, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("extent"),
         "signed 32-bit extent overflow must be rejected");
   end Bounding_Rect_ABI_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 fractional area and length",
            Fractional_Area_And_Length'Access));
      Result.Add_Test
        (Caller.Create ("Float32 oriented area", Oriented_Area'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 degenerate area and length",
            Degenerate_Point_Sets'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 geometry nonzero bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 geometry equals integer overloads",
            Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 geometry matches raw C ABI", Matches_Raw_C_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 geometry large finite coordinates",
            Large_Finite_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 fractional bounding rectangle",
            Fractional_Bounding_Rect'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 bounding rectangle limits", Bounding_Rect_Limits'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 fractional convexity", Fractional_Convexity'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 convexity span limits", Convexity_Span_Limits'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 degenerate convexity", Degenerate_Convexity'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 geometry rejects non-finite coordinates",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 geometry C ABI validation", C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 bounding rectangle C ABI safety",
            Bounding_Rect_ABI_Safety'Access));
      return Result'Access;
   end Suite;

end Float32_Contour_Geometry_Tests;
