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

package body Float32_Enclosing_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;
   package Float64_Functions is new
     Ada.Numerics.Generic_Elementary_Functions (OpenCV.Float64_Value);

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Rotated_Rect;
   use type OpenCV.Geometry.Enclosing_Circle;

   subtype Points is Support.Points;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  The rectangle [0.5, 3.0] x [0.25, 1.75] with interior points; its
   --  center (1.75, 1.0) differs from the rounded rectangle's (2.0, 1.0).
   Rectangle : constant Points :=
     ((X => 0.5, Y => 0.25),
      (X => 1.25, Y => 1.0),
      (X => 3.0, Y => 0.25),
      (X => 3.0, Y => 1.75),
      (X => 2.0, Y => 0.5),
      (X => 0.5, Y => 1.75));

   --  A square rotated by 45 degrees, centered at (1.5, 2.25), with side
   --  1.25 * Sqrt (2).
   Diamond : constant Points :=
     ((X => 0.25, Y => 2.25),
      (X => 1.5, Y => 1.0),
      (X => 2.75, Y => 2.25),
      (X => 1.5, Y => 3.5),
      (X => 1.5, Y => 2.0));

   --  A right triangle; its smallest enclosing circle has the hypotenuse
   --  as diameter.
   Triangle : constant Points :=
     ((X => 0.5, Y => 0.25), (X => 3.75, Y => 0.25), (X => 0.5, Y => 2.5));

   Integer_Set : constant OpenCV.Geometry.Contour :=
     ((X => -3, Y => 1),
      (X => 2, Y => 3),
      (X => 5, Y => -2),
      (X => 1, Y => 1),
      (X => 9, Y => 4),
      (X => 2, Y => 8),
      (X => 4, Y => 5),
      (X => -1, Y => 6));

   Empty : constant Points (1 .. 0) := (others => (0.0, 0.0));

   function Close
     (Actual, Expected : OpenCV.Float64_Value;
      Tolerance        : OpenCV.Float64_Value := 1.0E-5) return Boolean
   is (abs (Actual - Expected)
       <= Tolerance * OpenCV.Float64_Value'Max (1.0, abs Expected));

   function Close
     (Actual : OpenCV.Float32_Value; Expected : OpenCV.Float64_Value)
      return Boolean
   is (Close (OpenCV.Float64_Value (Actual), Expected));

   --  True when Box has sides Long and Short, in either field.
   function Has_Sides
     (Box : OpenCV.Rotated_Rect; Long, Short : OpenCV.Float64_Value)
      return Boolean
   is ((Close (Box.Size.Width, Long) and then Close (Box.Size.Height, Short))
       or else (Close (Box.Size.Width, Short)
                and then Close (Box.Size.Height, Long)));

   function Encloses
     (Circle : OpenCV.Geometry.Enclosing_Circle; Source : Points)
      return Boolean is
   begin
      for Point of Source loop
         if Float64_Functions.Sqrt
              ((OpenCV.Float64_Value (Point.X)
                - OpenCV.Float64_Value (Circle.Center.X))
               **2
               + (OpenCV.Float64_Value (Point.Y)
                  - OpenCV.Float64_Value (Circle.Center.Y))
                 **2)
           > OpenCV.Float64_Value (Circle.Radius) + 1.0E-6
         then
            return False;
         end if;
      end loop;
      return True;
   end Encloses;

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Rectangles (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Upright : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Minimum_Area_Rectangle (Rectangle);
      Turned  : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Minimum_Area_Rectangle (Diamond);
      Side    : constant OpenCV.Float64_Value :=
        1.25 * Float64_Functions.Sqrt (2.0);
   begin
      AUnit.Assertions.Assert
        (Close (Upright.Center.X, 1.75)
         and then Close (Upright.Center.Y, 1.0)
         and then Has_Sides (Upright, 2.5, 1.5),
         "the fractional upright rectangle must be recovered");
      AUnit.Assertions.Assert
        (Close (Turned.Center.X, 1.5)
         and then Close (Turned.Center.Y, 2.25)
         and then Has_Sides (Turned, Side, Side),
         "the fractional rotated square must be recovered");
      AUnit.Assertions.Assert
        (Close
           (OpenCV.Geometry.Minimum_Area_Rectangle
              (Support.Rounded (Rectangle))
              .Center
              .X,
            2.0),
         "the rounded rectangle has a different center");
   end Fractional_Rectangles;

   procedure Rectangle_Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Area_Rectangle
           (Support.To_Float32 (Integer_Set))
         = OpenCV.Geometry.Minimum_Area_Rectangle (Integer_Set),
         "integer-valued Float32 rectangle must equal the integer overload");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Area_Rectangle (Empty)
         = OpenCV.Geometry.Minimum_Area_Rectangle
             (OpenCV.Geometry.Contour'(1 .. 0 => (X => 0, Y => 0))),
         "an empty Float32 set must give the empty integer result");
   end Rectangle_Integer_Equivalence;

   function Scaled
     (Source : Points; Scale : OpenCV.Float32_Value) return Points
   is
      Result : Points (Source'Range);
   begin
      for Index in Source'Range loop
         Result (Index) :=
           (X => Source (Index).X * Scale, Y => Source (Index).Y * Scale);
      end loop;
      return Result;
   end Scaled;

   procedure Rectangle_Bounds_And_Scale (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (50 .. 55) := Rectangle;
      Large   : constant Points := Scaled (Rectangle, 1.0E+17);
      --  Every candidate area exceeds Float32_Value'Last.
      Huge    : constant Points := Scaled (Rectangle, 1.0E+20);
      --  An X span of 6.0E+38 overflows a binary32 difference.
      Wide    : constant Points :=
        ((X => -3.0E+38, Y => 0.0),
         (X => 3.0E+38, Y => 0.0),
         (X => 0.0, Y => 1.0));

      procedure Bound_Huge is
         Unused : constant OpenCV.Rotated_Rect :=
           OpenCV.Geometry.Minimum_Area_Rectangle (Huge);
         pragma Unreferenced (Unused);
      begin
         null;
      end Bound_Huge;

      procedure Bound_Wide is
         Unused : constant OpenCV.Rotated_Rect :=
           OpenCV.Geometry.Minimum_Area_Rectangle (Wide);
         pragma Unreferenced (Unused);
      begin
         null;
      end Bound_Wide;
   begin
      Support.Assert_Raises_OpenCV_Error
        (Bound_Wide'Access, "a span above Float32_Value'Last must raise");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Area_Rectangle (Shifted)
         = OpenCV.Geometry.Minimum_Area_Rectangle (Rectangle),
         "the rectangle must not depend on the Ada lower bound");
      declare
         Box : constant OpenCV.Rotated_Rect :=
           OpenCV.Geometry.Minimum_Area_Rectangle (Large);
      begin
         AUnit.Assertions.Assert
           (Close (Box.Center.X, 1.75E+17)
            and then Close (Box.Center.Y, 1.0E+17)
            and then Has_Sides (Box, 2.5E+17, 1.5E+17),
            "binary32 rotating calipers must handle areas below FLT_MAX");
      end;
      Support.Assert_Raises_OpenCV_Error
        (Bound_Huge'Access,
         "rectangle areas that all overflow binary32 must raise");
   end Rectangle_Bounds_And_Scale;

   procedure Fractional_Circle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Triangle);
      Radius : constant OpenCV.Float64_Value :=
        Float64_Functions.Sqrt (3.25 * 3.25 + 2.25 * 2.25) / 2.0;
   begin
      AUnit.Assertions.Assert
        (Close (Circle.Center.X, 2.125)
         and then Close (Circle.Center.Y, 1.375),
         "the circle center must be the hypotenuse midpoint");
      AUnit.Assertions.Assert
        (Close (Circle.Radius, Radius + 1.0E-4),
         "the radius must be half the hypotenuse plus OpenCV's EPS");
      AUnit.Assertions.Assert
        (Encloses (Circle, Triangle), "the circle must enclose the triangle");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Support.Rounded (Triangle))
         /= Circle,
         "the rounded triangle has a different circle");
   end Fractional_Circle;

   procedure Circle_Small_Sets (Test : in out Fixture) is
      pragma Unreferenced (Test);
      One : constant Points := (0 => (X => -1.25, Y => 2.75));
      Two : constant Points :=
        ((X => -1.25, Y => 2.75), (X => 1.75, Y => -1.25));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Empty)
         = (Center => (X => 0.0, Y => 0.0), Radius => 0.0),
         "an empty set has the zero circle");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Enclosing_Circle (One)
         = (Center => (X => -1.25, Y => 2.75), Radius => 1.0E-4),
         "a one-point set is its point with radius EPS");
      declare
         Circle : constant OpenCV.Geometry.Enclosing_Circle :=
           OpenCV.Geometry.Minimum_Enclosing_Circle (Two);
      begin
         AUnit.Assertions.Assert
           (Close (Circle.Center.X, 0.25)
            and then Close (Circle.Center.Y, 0.75)
            and then Close (Circle.Radius, 2.5 + 1.0E-4),
            "a two-point set has their midpoint and half distance");
      end;
   end Circle_Small_Sets;

   procedure Circle_Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (9 .. 11) := Triangle;
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Enclosing_Circle
           (Support.To_Float32 (Integer_Set))
         = OpenCV.Geometry.Minimum_Enclosing_Circle (Integer_Set),
         "integer-valued Float32 circle must equal the integer overload");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Shifted)
         = OpenCV.Geometry.Minimum_Enclosing_Circle (Triangle),
         "the circle must not depend on the Ada lower bound");
   end Circle_Integer_Equivalence;

   procedure Circle_Magnitude_Limit (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Limit  : constant := 2.0**41;
      --  Coordinates of 2.0**41 keep OpenCV's binary32 products finite.
      Widest : constant Points :=
        ((X => -Limit, Y => -Limit),
         (X => Limit, Y => -Limit),
         (X => 0.0, Y => Limit));
      --  An equilateral triangle with sides of 3.0E+13, for which OpenCV
      --  4.6 and 4.10 return a circle that misses a vertex.
      Missed : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 3.0E+13, Y => 0.0),
         (X => 1.5E+13, Y => 2.598076E+13));
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Widest);

      procedure Circle_Missed is
         Unused : constant OpenCV.Geometry.Enclosing_Circle :=
           OpenCV.Geometry.Minimum_Enclosing_Circle (Missed);
         pragma Unreferenced (Unused);
      begin
         null;
      end Circle_Missed;
   begin
      for Point of Widest loop
         AUnit.Assertions.Assert
           (Float64_Functions.Sqrt
              ((OpenCV.Float64_Value (Point.X)
                - OpenCV.Float64_Value (Circle.Center.X))
               **2
               + (OpenCV.Float64_Value (Point.Y)
                  - OpenCV.Float64_Value (Circle.Center.Y))
                 **2)
            <= OpenCV.Float64_Value (Circle.Radius) * (1.0 + 1.0E-6),
            "coordinates of 2.0**41 must give an enclosing circle");
      end loop;
      Support.Assert_Raises_OpenCV_Error
        (Circle_Missed'Access,
         "coordinates above 2.0**41 must raise rather than miss a point");
   end Circle_Magnitude_Limit;

   procedure Rectangle_Candidate (Candidate : Points) is
      Unused : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Minimum_Area_Rectangle (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Rectangle_Candidate;

   procedure Circle_Candidate (Candidate : Points) is
      Unused : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Circle_Candidate;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (3 .. 8) := Rectangle;
   begin
      Support.Assert_Rejects_Non_Finite
        (Shifted, Rectangle_Candidate'Access, "Minimum_Area_Rectangle");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Circle_Candidate'Access, "Minimum_Enclosing_Circle");
   end Non_Finite_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Raw buffers bypass the Ada policy; NaN is stored directly.
      pragma Suppress (Validity_Check);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Rectangle);
      Bad    : aliased C_API.Point_F32_Array := Support.Pack (Rectangle);
      Box    : aliased C_API.C_Rotated_Rect :=
        (Center_X      => 9.0,
         Center_Y      => 9.0,
         Width         => 9.0,
         Height        => 9.0,
         Angle_Degrees => 9.0);
      Circle : aliased C_API.C_Enclosing_Circle :=
        (Center_X => 9.0, Center_Y => 9.0, Radius => 9.0);
      Status : C_API.Status;
   begin
      Bad (4).X := Support.NaN_C;
      --  The count is checked before any point is read.
      Status :=
        C_API.Min_Area_Rect_F32
          (Packed (Packed'First)'Access,
           Interfaces.Integer_32'Last / 3 + 1,
           Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("allocation")
         and then OpenCV.Float32_Value (Box.Width) = 0.0,
         "a count above INT32_MAX / 3 must be rejected");
      Status :=
        C_API.Min_Area_Rect_F32 (Bad (Bad'First)'Access, 6, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("NaN"),
         "NaN must be rejected before native sorting");
      Status := C_API.Min_Area_Rect_F32 (null, 2, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("points"),
         "null points with positive count must be rejected");
      Status := C_API.Min_Area_Rect_F32 (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null rectangle output must be rejected");
      Status := C_API.Min_Enclosing_Circle_F32 (null, -1, Circle'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("count")
         and then OpenCV.Float32_Value (Circle.Radius) = 0.0,
         "negative circle count must be rejected with a zero circle");
      Status := C_API.Min_Enclosing_Circle_F32 (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null circle output must be rejected");
   end C_ABI_Validation;

   procedure Circle_Large_Small_Sets (Test : in out Fixture) is
      pragma Unreferenced (Test);
      use type OpenCV.Float32_Point;
      One       : constant Points := (1 => (2.0**80, -2.0**80));
      Two       : constant Points := (One (1), One (1));
      Singleton : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (One);
      Pair      : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Two);
   begin
      AUnit.Assertions.Assert
        (Singleton.Center = One (1) and then Singleton.Radius = 1.0E-4,
         "large singleton must retain its center and native EPS radius");
      AUnit.Assertions.Assert
        (Pair.Center = One (1) and then Pair.Radius = 1.0E-4,
         "large repeated pair must retain its center and native EPS radius");
   end Circle_Large_Small_Sets;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 minimum area rectangle fractional",
            Fractional_Rectangles'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 minimum area rectangle equals integer overload",
            Rectangle_Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 minimum area rectangle bounds and scale",
            Rectangle_Bounds_And_Scale'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 enclosing circle fractional", Fractional_Circle'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 enclosing circle small sets", Circle_Small_Sets'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 enclosing circle equals integer overload",
            Circle_Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 enclosing circle magnitude limit",
            Circle_Magnitude_Limit'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 enclosing rejects non-finite coordinates",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 enclosing C ABI validation", C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 circle large singleton and repeated pair",
            Circle_Large_Small_Sets'Access));
      return Result'Access;
   end Suite;

end Float32_Enclosing_Tests;
