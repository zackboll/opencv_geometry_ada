with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Convex_Hull_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type C_API.Point_I32_Array;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Float64_Value;
   use type OpenCV.Core.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Square : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3));

   Square_With_Interior : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 3),
      (X => 0, Y => 3),
      (X => 2, Y => 1));

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

   function Contains_Point
     (Points : OpenCV.Geometry.Contour; Item : OpenCV.Core.Point)
      return Boolean is
   begin
      for Point of Points loop
         if Same_Point (Point, Item) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Point;

   function Same_Vertex_Set
     (Left, Right : OpenCV.Geometry.Contour) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for Point of Left loop
         if not Contains_Point (Right, Point) then
            return False;
         end if;
      end loop;

      for Point of Right loop
         if not Contains_Point (Left, Point) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Vertex_Set;

   function Same_Cyclic_Order
     (Left, Right : OpenCV.Geometry.Contour) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      if Left'Length = 0 then
         return True;
      end if;

      declare
         Count : constant Natural := Left'Length;
      begin
         for Offset in 0 .. Count - 1 loop
            declare
               Matches : Boolean := True;
            begin
               for Index in 0 .. Count - 1 loop
                  if not Same_Point
                           (Left (Left'First + Index),
                            Right (Right'First + ((Index + Offset) mod Count)))
                  then
                     Matches := False;
                     exit;
                  end if;
               end loop;

               if Matches then
                  return True;
               end if;
            end;
         end loop;
      end;

      return False;
   end Same_Cyclic_Order;

   procedure Square_Interior_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Square_With_Interior);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 4, "interior point must not remain on the hull");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Hull, Square),
         "square hull must contain only the four exterior vertices");
      AUnit.Assertions.Assert
        (not Contains_Point (Hull, (X => 2, Y => 1)),
         "interior point must be removed");
   end Square_Interior_Points;

   procedure Concave_Polygon (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Concave);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 4, "concave vertex must not remain on the hull");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Hull, Square),
         "concave hull must match the enclosing square vertices");
      AUnit.Assertions.Assert
        (not Contains_Point (Hull, (X => 2, Y => 1)),
         "concave interior vertex must be removed");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Hull)
         >= OpenCV.Geometry.Contour_Area (Concave),
         "hull area must not be less than the original contour area");
   end Concave_Polygon;

   procedure Already_Convex (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Square);
   begin
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Hull, Square),
         "already-convex polygon must keep the same vertex set");
   end Already_Convex;

   procedure Duplicate_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Duplicated : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3),
         (X => 0, Y => 0),
         (X => 4, Y => 0));
      Hull       : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Duplicated);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 4, "duplicate points must not inflate the hull");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Hull, Square),
         "duplicate points must produce the square hull vertices");
   end Duplicate_Points;

   procedure Collinear_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Line : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 1, Y => 0),
         (X => 2, Y => 0),
         (X => 3, Y => 0));
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Line);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 2, "collinear hull must keep only the extremes");
      AUnit.Assertions.Assert
        (Contains_Point (Hull, (X => 0, Y => 0))
         and then Contains_Point (Hull, (X => 3, Y => 0)),
         "collinear hull must contain the extreme endpoints");
   end Collinear_Points;

   procedure Empty_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
      Hull  : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Empty);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 0, "empty contour hull must be empty");
   end Empty_Contour;

   procedure One_Point_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      One  : constant OpenCV.Geometry.Contour :=
        (0 => OpenCV.Core.Point'(X => 1, Y => 2));
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (One);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 1, "one-point hull must contain one point");
      AUnit.Assertions.Assert
        (Same_Point (Hull (Hull'First), (X => 1, Y => 2)),
         "one-point hull must preserve the input point");
   end One_Point_Contour;

   procedure Two_Point_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Two  : constant OpenCV.Geometry.Contour :=
        (0 => OpenCV.Core.Point'(X => 0, Y => 0),
         1 => OpenCV.Core.Point'(X => 3, Y => 4));
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Two);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 2, "two-point hull must contain both points");
      AUnit.Assertions.Assert
        (Contains_Point (Hull, (X => 0, Y => 0))
         and then Contains_Point (Hull, (X => 3, Y => 4)),
         "two-point hull must preserve both endpoints");
   end Two_Point_Contour;

   procedure Clockwise_Versus_Counterclockwise (Test : in out Fixture) is
      pragma Unreferenced (Test);
      CCW : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Square, OpenCV.Geometry.Counterclockwise);
      CW  : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Square, OpenCV.Geometry.Clockwise);
   begin
      AUnit.Assertions.Assert
        (Same_Vertex_Set (CCW, Square) and then Same_Vertex_Set (CW, Square),
         "both orientations must keep the same hull vertices");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (CCW, Oriented => True) > 0.0,
         "counterclockwise hull must have positive oriented area");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (CW, Oriented => True) < 0.0,
         "clockwise hull must have negative oriented area");
      AUnit.Assertions.Assert
        (Same_Cyclic_Order (CCW, Square),
         "counterclockwise hull must match square cyclic order");
   end Clockwise_Versus_Counterclockwise;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted  : constant OpenCV.Geometry.Contour (7 .. 10) := Square;
      Ordinary : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Square);
      Offset   : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Shifted);
   begin
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Offset, Ordinary),
         "hull vertices must not depend on Ada array lower bound");
      AUnit.Assertions.Assert
        (Same_Cyclic_Order (Offset, Ordinary),
         "hull order must not depend on Ada array lower bound");
   end Nonzero_Array_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Square_With_Interior;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Hull     : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (Points);
   begin
      AUnit.Assertions.Assert
        (Same_Cyclic_Order (Points, Original),
         "Convex_Hull must leave the input contour unchanged");
      AUnit.Assertions.Assert
        (Hull'Length = 4, "interior input must still produce a square hull");
   end Input_Unchanged;

   procedure Vertex_Set_Rejects_Duplicate_Omission (Test : in out Fixture) is
      pragma Unreferenced (Test);
      With_Duplicate : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 0, Y => 0), (X => 1, Y => 0));
      Distinct       : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 1, Y => 0), (X => 0, Y => 1));
   begin
      AUnit.Assertions.Assert
        (not Same_Vertex_Set (With_Duplicate, Distinct),
         "vertex-set comparison must reject duplicate vs omitted point");
      AUnit.Assertions.Assert
        (not Same_Vertex_Set (Distinct, With_Duplicate),
         "vertex-set comparison must be independent of argument order");
   end Vertex_Set_Rejects_Duplicate_Omission;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Count  : aliased Interfaces.Integer_32 := -1;
      Buffer : aliased C_API.Point_I32_Array (0 .. 0) :=
        (0 => (X => 9, Y => 9));
      Status : C_API.Status;
   begin
      Status :=
        C_API.Convex_Hull (null, -1, 0, Buffer (0)'Access, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "negative convex hull point count must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "invalid count must initialize output count to zero");

      Count := -1;
      Status :=
        C_API.Convex_Hull (null, 1, 0, Buffer (0)'Access, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "null points with positive count must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "invalid points must initialize output count to zero");

      Count := -1;
      Status :=
        C_API.Convex_Hull
          (Buffer (0)'Access, 1, 0, Buffer (0)'Access, -1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "capacity")
                  /= 0,
         "negative output capacity must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "invalid capacity must initialize output count to zero");

      Count := -1;
      Status :=
        C_API.Convex_Hull
          (Buffer (0)'Access, 1, 0, Buffer (0)'Access, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "capacity")
                  /= 0,
         "insufficient output capacity must be rejected");
      AUnit.Assertions.Assert
        (Count = 0,
         "insufficient capacity must initialize output count to zero");

      Count := -1;
      Status :=
        C_API.Convex_Hull (Buffer (0)'Access, 1, 0, null, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null output pointer with positive capacity must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "null output must initialize output count to zero");

      Status := C_API.Convex_Hull (null, 0, 0, null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "null output count pointer must be rejected");

      Count := -1;
      Status := C_API.Convex_Hull (null, 0, 2, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "clockwise")
                  /= 0,
         "invalid clockwise selector must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "invalid selector must initialize output count to zero");

      Count := -1;
      Status := C_API.Convex_Hull (null, 0, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0,
         "zero-count null convex hull must succeed with empty output");
   end C_ABI_Validation;

   procedure C_ABI_Arithmetic_Span_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Safe     : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => -1, Y => 0),
         (X => -2, Y => 1));
      Unsafe   : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => Interfaces.Integer_32'Last, Y => 0),
         (X => 0, Y => 1));
      Unsafe_Y : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => 0, Y => Interfaces.Integer_32'First),
         (X => 0, Y => Interfaces.Integer_32'Last),
         (X => 1, Y => 0));
      Output   : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => 11, Y => 12), (X => 13, Y => 14), (X => 15, Y => 16));
      Before   : constant C_API.Point_I32_Array := Output;
      Count    : aliased Interfaces.Integer_32 := -1;
      Status   : C_API.Status;
   begin
      Status :=
        C_API.Convex_Hull
          (Safe (0)'Access, 3, 0, Output (0)'Access, 3, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "safe full span status");
      Count := -1;
      Output := Before;
      Status :=
        C_API.Convex_Hull
          (Unsafe (0)'Access, 3, 0, Output (0)'Access, 3, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "unsafe X span status");
      AUnit.Assertions.Assert (Count = 0, "unsafe X span zero count");
      AUnit.Assertions.Assert
        (Output = Before, "unsafe X span preserves output buffer");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "arithmetic") /= 0,
         "unsafe X span diagnostic");
      Count := -1;
      Status :=
        C_API.Convex_Hull
          (Unsafe_Y (0)'Access, 3, 0, Output (0)'Access, 3, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "unsafe Y span status");
      AUnit.Assertions.Assert (Count = 0, "unsafe Y span zero count");
   end C_ABI_Arithmetic_Span_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Convex hull square with interior points",
            Square_Interior_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull concave polygon", Concave_Polygon'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull already-convex polygon", Already_Convex'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull duplicate points", Duplicate_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull collinear points", Collinear_Points'Access));
      Result.Add_Test
        (Caller.Create ("Convex hull empty contour", Empty_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull C ABI arithmetic span safety",
            C_ABI_Arithmetic_Span_Safety'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull one-point contour", One_Point_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull two-point contour", Two_Point_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull clockwise versus counterclockwise",
            Clockwise_Versus_Counterclockwise'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull preserves array order", Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull leaves input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull vertex-set helper rejects duplicate omission",
            Vertex_Set_Rejects_Duplicate_Omission'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Convex_Hull_Tests;
