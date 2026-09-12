with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Is_Convex_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Square_CCW : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3));

   Square_CW : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 0, Y => 3), (X => 4, Y => 3), (X => 4, Y => 0));

   Triangle : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 0, Y => 3));

   Concave : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 3),
      (X => 2, Y => 1),
      (X => 0, Y => 3));

   function Same_Point (Left, Right : OpenCV.Core.Point) return Boolean is
   begin
      return Left.X = Right.X and then Left.Y = Right.Y;
   end Same_Point;

   function Same_Sequence
     (Left, Right : OpenCV.Geometry.Contour) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for Offset in 0 .. Integer (Left'Length) - 1 loop
         if not Same_Point
                  (Left (Left'First + Offset), Right (Right'First + Offset))
         then
            return False;
         end if;
      end loop;

      return True;
   end Same_Sequence;

   procedure Convex_Square (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Square_CCW),
         "convex square must be convex");
   end Convex_Square;

   procedure Convex_Triangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Triangle),
         "convex triangle must be convex");
   end Convex_Triangle;

   procedure Concave_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Concave),
         "simple concave contour must not be convex");
   end Concave_Contour;

   procedure Clockwise_Convex (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Square_CW),
         "clockwise convex square must be convex");
   end Clockwise_Convex;

   procedure Counterclockwise_Convex (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Square_CCW),
         "counterclockwise convex square must be convex");
   end Counterclockwise_Convex;

   procedure Translated_Negative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant OpenCV.Geometry.Contour :=
        ((X => -10, Y => -20),
         (X => -6, Y => -20),
         (X => -6, Y => -17),
         (X => -10, Y => -17));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Shifted),
         "translated convex contour with negative coordinates must be convex");
   end Translated_Negative;

   procedure Collinear_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Line : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 2, Y => 0), (X => 5, Y => 0));
   begin
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Line),
         "collinear contour must not be convex");
   end Collinear_Contour;

   procedure Empty_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
   begin
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Empty),
         "empty contour must not be convex");
   end Empty_Contour;

   procedure One_Point (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        (0 => OpenCV.Core.Point'(X => 1, Y => 2));
   begin
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Points),
         "one-point contour must not be convex");
   end One_Point;

   procedure Two_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
   begin
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Points),
         "two-point contour must not be convex");
   end Two_Points;

   procedure Duplicate_And_Closed_Vertex (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Consecutive : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3));
      Closed      : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3),
         (X => 0, Y => 0));
   begin
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Consecutive),
         "consecutive duplicate vertices must not be convex");
      AUnit.Assertions.Assert
        (not OpenCV.Geometry.Is_Convex (Closed),
         "repeated closing vertex must not be convex");
   end Duplicate_And_Closed_Vertex;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant OpenCV.Geometry.Contour (7 .. 10) := Square_CCW;
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Shifted),
         "convexity must not depend on Ada array lower bound");
   end Nonzero_Array_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Square_CCW;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Convex   : constant Boolean := OpenCV.Geometry.Is_Convex (Points);
   begin
      AUnit.Assertions.Assert
        (Same_Sequence (Points, Original),
         "Is_Convex must leave the input contour unchanged");
      AUnit.Assertions.Assert (Convex, "input must still be a convex square");
   end Input_Unchanged;

   procedure Matches_Convex_Hull (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Concave);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Hull),
         "convex hull of a simple polygon must be convex");
   end Matches_Convex_Hull;

   procedure Large_Safe_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Last   : constant OpenCV.Core.Point_Coordinate :=
        OpenCV.Core.Point_Coordinate (Interfaces.Integer_32'Last);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => Last, Y => 0),
         (X => Last, Y => 1),
         (X => 0, Y => 1));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Points),
         "large representable convex contour must remain convex");
   end Large_Safe_Contour;

   procedure Safe_Delta_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      First  : constant OpenCV.Core.Point_Coordinate :=
        OpenCV.Core.Point_Coordinate (Interfaces.Integer_32'First);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => First, Y => 0),
         (X => -1, Y => 0),
         (X => -1, Y => 1),
         (X => First, Y => 1));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Points),
         "INT32_MAX edge delta must remain representable and convex");
   end Safe_Delta_Boundary;

   procedure Safe_Product_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  46340^2 = 2_147_395_600, the largest square that still fits in
      --  signed 32-bit native products used by isContourConvex.
      Limit  : constant OpenCV.Core.Point_Coordinate := 46_340;
      Points : constant OpenCV.Geometry.Contour :=
        ((X => Limit, Y => Limit), (X => 0, Y => 0), (X => 0, Y => Limit));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Points),
         "maximum representable cross-product must still call OpenCV");
   end Safe_Product_Boundary;

   procedure Assert_Rejected_Arithmetic
     (Points : in out C_API.Point_I32_Array; Message : String)
   is
      Convex : aliased Interfaces.Integer_32 := -1;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Is_Convex
          (Points (Points'First)'Access,
           Interfaces.Integer_32 (Points'Length),
           Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, Message & ": status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "range") /= 0,
         Message & ": diagnostic");
      AUnit.Assertions.Assert
        (Convex = 0, Message & ": output must be reset to zero");
   end Assert_Rejected_Arithmetic;

   procedure Unsafe_Delta_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => 0, Y => 0),
         (X => 0, Y => 1),
         (X => Interfaces.Integer_32'First, Y => 1));
   begin
      Assert_Rejected_Arithmetic
        (Buffer, "INT32_MAX+1 edge delta must not reach isContourConvex");
   end Unsafe_Delta_Rejected;

   procedure Unsafe_Product_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  46341^2 exceeds INT32_MAX, so native dx*dy0 would overflow.
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => 46_341, Y => 46_341), (X => 0, Y => 0), (X => 0, Y => 46_341));
   begin
      Assert_Rejected_Arithmetic
        (Buffer, "overflowing cross-product must not reach isContourConvex");
   end Unsafe_Product_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Convex : aliased Interfaces.Integer_32 := -1;
      Buffer : aliased C_API.Point_I32_Array (0 .. 3) :=
        (0 => (X => 0, Y => 0),
         1 => (X => 4, Y => 0),
         2 => (X => 4, Y => 3),
         3 => (X => 0, Y => 3));
      Status : C_API.Status;
   begin
      Status := C_API.Is_Convex (null, -1, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "negative is-convex point count must be rejected");
      AUnit.Assertions.Assert
        (Convex = 0, "invalid count must initialize output to zero");

      Convex := -1;
      Status := C_API.Is_Convex (null, 1, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "null points with positive count must be rejected");
      AUnit.Assertions.Assert
        (Convex = 0, "invalid points must initialize output to zero");

      Status := C_API.Is_Convex (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null is-convex output pointer must be rejected");

      Convex := -1;
      Status := C_API.Is_Convex (null, 0, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Convex = 0,
         "zero-count null is-convex must succeed as not convex");

      Convex := -1;
      Status := C_API.Is_Convex (Buffer (0)'Access, 4, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Convex = 1,
         "convex ABI square must return exactly 1");

      Convex := -1;
      Buffer (2) := (X => 2, Y => 1);
      Status := C_API.Is_Convex (Buffer (0)'Access, 4, Convex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Convex = 0,
         "concave ABI contour must return exactly 0");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Is convex square", Convex_Square'Access));
      Result.Add_Test
        (Caller.Create ("Is convex triangle", Convex_Triangle'Access));
      Result.Add_Test
        (Caller.Create ("Is convex concave contour", Concave_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex clockwise contour", Clockwise_Convex'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex counterclockwise contour",
            Counterclockwise_Convex'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex translated negative contour",
            Translated_Negative'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex collinear contour", Collinear_Contour'Access));
      Result.Add_Test
        (Caller.Create ("Is convex empty contour", Empty_Contour'Access));
      Result.Add_Test
        (Caller.Create ("Is convex one point", One_Point'Access));
      Result.Add_Test
        (Caller.Create ("Is convex two points", Two_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex duplicate and closing vertex",
            Duplicate_And_Closed_Vertex'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex nonzero array bounds", Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex leaves input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex matches convex hull", Matches_Convex_Hull'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex large safe contour", Large_Safe_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex safe delta boundary", Safe_Delta_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex safe product boundary", Safe_Product_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex unsafe delta rejected", Unsafe_Delta_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex unsafe product rejected",
            Unsafe_Product_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Is convex C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Is_Convex_Tests;
