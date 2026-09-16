with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Approximate_Curve_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Square : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3));

   Near_Rectangle : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 2, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 2),
      (X => 4, Y => 3),
      (X => 2, Y => 3),
      (X => 0, Y => 3),
      (X => 0, Y => 1));

   Open_Bump : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 5, Y => 1), (X => 10, Y => 0));

   Stair : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 10, Y => 0),
      (X => 10, Y => 10),
      (X => 0, Y => 10),
      (X => 0, Y => 1));

   Collinear : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 2, Y => 0), (X => 4, Y => 0), (X => 6, Y => 0));

   function Same_Point (Left, Right : OpenCV.Point) return Boolean is
   begin
      return Left.X = Right.X and then Left.Y = Right.Y;
   end Same_Point;

   function Contains_Point
     (Points : OpenCV.Geometry.Contour; Item : OpenCV.Point)
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

   procedure Closed_Near_Rectangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Approx : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve
          (Near_Rectangle, 1.0, Closed => True);
   begin
      AUnit.Assertions.Assert
        (Approx'Length <= Near_Rectangle'Length,
         "closed approximation must not exceed input length");
      AUnit.Assertions.Assert
        (Approx'Length = 4, "redundant rectangle vertices must be removed");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Approx, Square),
         "closed near-rectangle must reduce to the four corners");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Approx)
         = OpenCV.Geometry.Contour_Area (Square),
         "simplified closed rectangle must keep the original area");
   end Closed_Near_Rectangle;

   procedure Open_Polyline (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Expected : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 10, Y => 0));
      Approx   : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Open_Bump, 2.0, Closed => False);
   begin
      AUnit.Assertions.Assert
        (Approx'Length <= Open_Bump'Length,
         "open approximation must not exceed input length");
      AUnit.Assertions.Assert
        (Same_Sequence (Approx, Expected),
         "open bump must drop the intermediate vertex at epsilon 2");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Arc_Length (Approx, Closed => False)
         <= OpenCV.Geometry.Arc_Length (Open_Bump, Closed => False),
         "simplified open polyline must not be longer than the original");
   end Open_Polyline;

   procedure Open_Versus_Closed (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Closed_Approx : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Stair, 2.0, Closed => True);
      Open_Approx   : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Stair, 2.0, Closed => False);
   begin
      AUnit.Assertions.Assert
        (Closed_Approx'Length = 4,
         "closed stair must drop the near-start extra vertex");
      AUnit.Assertions.Assert
        (not Contains_Point (Closed_Approx, (X => 0, Y => 1)),
         "closed stair must not keep the extra closing-side vertex");
      AUnit.Assertions.Assert
        (Open_Approx'Length = 5,
         "open stair must keep the extra terminal vertex");
      AUnit.Assertions.Assert
        (Contains_Point (Open_Approx, (X => 0, Y => 1)),
         "open stair must retain the unmatched end vertex");
   end Open_Versus_Closed;

   procedure Epsilon_Zero (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Approx : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve
          (Near_Rectangle, 0.0, Closed => True);
   begin
      AUnit.Assertions.Assert
        (Approx'Length <= Near_Rectangle'Length,
         "zero-epsilon approximation must not exceed input length");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Approx, Square),
         "zero epsilon still removes collinear rectangle intermediates");
   end Epsilon_Zero;

   procedure Increasing_Epsilon (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Tight : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Open_Bump, 0.5, Closed => False);
      Loose : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Open_Bump, 2.0, Closed => False);
   begin
      AUnit.Assertions.Assert
        (Tight'Length = 3, "small epsilon must keep the bump vertex");
      AUnit.Assertions.Assert
        (Loose'Length <= Tight'Length,
         "larger epsilon must not produce more vertices");
      AUnit.Assertions.Assert
        (Loose'Length = 2, "larger epsilon must drop the bump vertex");
   end Increasing_Epsilon;

   procedure Collinear_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Expected : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 6, Y => 0));
      Approx   : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Collinear, 0.5, Closed => False);
   begin
      AUnit.Assertions.Assert
        (Same_Sequence (Approx, Expected),
         "open collinear points must reduce to the endpoints");
   end Collinear_Points;

   procedure Empty_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty  : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Point'(X => 0, Y => 0));
      Approx : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Empty, 1.0, Closed => True);
   begin
      AUnit.Assertions.Assert
        (Approx'Length = 0, "empty input must produce an empty approximation");
   end Empty_Contour;

   procedure One_Point_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour := (1 => (X => 7, Y => 9));
      Approx : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Points, 1.0, Closed => True);
   begin
      AUnit.Assertions.Assert
        (Same_Sequence (Approx, Points),
         "one-point contour must be returned unchanged");
   end One_Point_Contour;

   procedure Two_Point_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
      Approx : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Points, 1.0, Closed => False);
   begin
      AUnit.Assertions.Assert
        (Same_Sequence (Approx, Points),
         "two-point open contour must keep both endpoints");
   end Two_Point_Contour;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Offset : OpenCV.Geometry.Contour (3 .. 10);
   begin
      for Index in Near_Rectangle'Range loop
         Offset (Offset'First + (Index - Near_Rectangle'First)) :=
           Near_Rectangle (Index);
      end loop;

      declare
         Ordinary : constant OpenCV.Geometry.Contour :=
           OpenCV.Geometry.Approximate_Curve
             (Near_Rectangle, 1.0, Closed => True);
         Shifted  : constant OpenCV.Geometry.Contour :=
           OpenCV.Geometry.Approximate_Curve (Offset, 1.0, Closed => True);
      begin
         AUnit.Assertions.Assert
           (Same_Vertex_Set (Shifted, Ordinary),
            "approximation vertices must not depend on Ada lower bound");
      end;
   end Nonzero_Array_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Near_Rectangle;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Approx   : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve (Points, 1.0, Closed => True);
   begin
      AUnit.Assertions.Assert
        (Same_Sequence (Points, Original),
         "Approximate_Curve must leave the input contour unchanged");
      AUnit.Assertions.Assert
        (Approx'Length = 4, "interior input must still simplify");
   end Input_Unchanged;

   procedure Invalid_Public_Epsilon (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
      function Bits_To_Epsilon is new
        Ada.Unchecked_Conversion
          (Interfaces.Unsigned_64,
           OpenCV.Float64_Value);

      procedure Assert_Rejected
        (Epsilon : OpenCV.Float64_Value; Message : String)
      is
         Raised : Boolean := False;
      begin
         begin
            declare
               Unused : constant OpenCV.Geometry.Contour :=
                 OpenCV.Geometry.Approximate_Curve
                   (Points, Epsilon, Closed => False);
               pragma Unreferenced (Unused);
            begin
               null;
            end;
         exception
            when Error : OpenCV.OpenCV_Error =>
               Raised :=
                 Ada.Strings.Fixed.Index
                   (Ada.Exceptions.Exception_Message (Error),
                    "0.0 <= epsilon < 1.0E30")
                 /= 0;
         end;

         AUnit.Assertions.Assert (Raised, Message);
      end Assert_Rejected;
   begin
      Assert_Rejected (-1.0, "negative epsilon must be rejected");
      Assert_Rejected
        (Bits_To_Epsilon (16#7FF0_0000_0000_0000#),
         "positive infinity epsilon must be rejected");
      Assert_Rejected
        (Bits_To_Epsilon (16#FFF0_0000_0000_0000#),
         "negative infinity epsilon must be rejected");
      Assert_Rejected
        (Bits_To_Epsilon (16#7FF8_0000_0000_0000#),
         "NaN epsilon must be rejected");
      Assert_Rejected (1.0E30, "epsilon equal to 1.0E30 must be rejected");
      Assert_Rejected (1.1E30, "epsilon greater than 1.0E30 must be rejected");

      declare
         Approx : constant OpenCV.Geometry.Contour :=
           OpenCV.Geometry.Approximate_Curve (Points, 1.0E29, Closed => False);
      begin
         AUnit.Assertions.Assert
           (Approx'Length <= Points'Length,
            "finite epsilon below 1.0E30 must return a valid contour");
      end;
   end Invalid_Public_Epsilon;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Count  : aliased Interfaces.Integer_32 := -1;
      Buffer : aliased C_API.Point_I32_Array (0 .. 0) :=
        (0 => (X => 9, Y => 9));
      Status : C_API.Status;
   begin
      Status :=
        C_API.Approximate_Curve
          (null, -1, 1.0, 0, Buffer (0)'Access, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "negative approximate-curve point count must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "invalid count must initialize output count to zero");

      Count := -1;
      Status :=
        C_API.Approximate_Curve
          (null, 1, 1.0, 0, Buffer (0)'Access, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "null points with positive count must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "invalid points must initialize output count to zero");

      Count := -1;
      Status :=
        C_API.Approximate_Curve
          (Buffer (0)'Access, 1, 1.0, 0, Buffer (0)'Access, -1, Count'Access);
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
        C_API.Approximate_Curve
          (Buffer (0)'Access, 1, 1.0, 0, Buffer (0)'Access, 0, Count'Access);
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
        C_API.Approximate_Curve
          (Buffer (0)'Access, 1, 1.0, 0, null, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null output pointer with positive capacity must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "null output must initialize output count to zero");

      Status := C_API.Approximate_Curve (null, 0, 1.0, 0, null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "null output count pointer must be rejected");

      Count := -1;
      Status :=
        C_API.Approximate_Curve (null, 0, 1.0, 2, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "closed")
                  /= 0,
         "invalid closed selector must be rejected");
      AUnit.Assertions.Assert
        (Count = 0, "invalid selector must initialize output count to zero");

      Count := -1;
      Status :=
        C_API.Approximate_Curve (null, 0, 1.0, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0,
         "zero-count null approximate curve must succeed with empty output");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Approximate curve closed nearly rectangular contour",
            Closed_Near_Rectangle'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve open polyline", Open_Polyline'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve open versus closed",
            Open_Versus_Closed'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve epsilon zero", Epsilon_Zero'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve increasing epsilon",
            Increasing_Epsilon'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve collinear points", Collinear_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve empty contour", Empty_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve one-point contour", One_Point_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve two-point contour", Two_Point_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve preserves array order",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve leaves input unchanged",
            Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve invalid public epsilon",
            Invalid_Public_Epsilon'Access));
      Result.Add_Test
        (Caller.Create
           ("Approximate curve C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Approximate_Curve_Tests;
