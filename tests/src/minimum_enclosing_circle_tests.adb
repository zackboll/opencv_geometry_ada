with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Minimum_Enclosing_Circle_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.C_float;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Point;
   use type OpenCV.Core.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Native_EPS         : constant OpenCV.Core.Float32_Value := 1.0E-4;
   Absolute_Tolerance : constant OpenCV.Core.Float32_Value := 1.0E-4;
   Relative_Tolerance : constant OpenCV.Core.Float32_Value := 1.0E-5;
   Square             : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 4), (X => 0, Y => 4));
   Clockwise          : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 0, Y => 4), (X => 4, Y => 4), (X => 4, Y => 0));
   Triangle           : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 0, Y => 3));
   Translated         : constant OpenCV.Geometry.Contour :=
     ((X => -10, Y => -10),
      (X => -6, Y => -10),
      (X => -6, Y => -6),
      (X => -10, Y => -6));

   function Close (Left, Right : OpenCV.Core.Float32_Value) return Boolean is
      Difference : constant OpenCV.Core.Float32_Value := abs (Left - Right);
      Scale      : constant OpenCV.Core.Float32_Value :=
        OpenCV.Core.Float32_Value'Max (abs (Left), abs (Right));
   begin
      return
        Difference <= Absolute_Tolerance
        or else Difference <= Relative_Tolerance * Scale;
   end Close;

   procedure Assert_Close
     (Actual, Expected : OpenCV.Core.Float32_Value; Message : String) is
   begin
      AUnit.Assertions.Assert (Close (Actual, Expected), Message);
   end Assert_Close;

   procedure Assert_Circle
     (Actual                     : OpenCV.Geometry.Enclosing_Circle;
      Center_X, Center_Y, Radius : OpenCV.Core.Float32_Value;
      Message                    : String) is
   begin
      Assert_Close (Actual.Center.X, Center_X, Message & ": X");
      Assert_Close (Actual.Center.Y, Center_Y, Message & ": Y");
      Assert_Close (Actual.Radius, Radius, Message & ": Radius");
   end Assert_Circle;

   function Same_Contour (Left, Right : OpenCV.Geometry.Contour) return Boolean
   is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      if Left'Length = 0 then
         return True;
      end if;
      for Offset in 0 .. Left'Length - 1 loop
         if Left (Left'First + Offset) /= Right (Right'First + Offset) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Contour;

   procedure Empty_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty  : OpenCV.Geometry.Contour (1 .. 0);
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Empty);
   begin
      AUnit.Assertions.Assert (Circle.Center.X = 0.0, "empty X");
      AUnit.Assertions.Assert (Circle.Center.Y = 0.0, "empty Y");
      AUnit.Assertions.Assert (Circle.Radius = 0.0, "empty radius");
   end Empty_Contour;

   procedure One_Point (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour := (1 => (X => 2, Y => 3));
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Points),
         2.0,
         3.0,
         Native_EPS,
         "one point");
   end One_Point;

   procedure Two_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Points),
         2.0,
         0.0,
         2.0 + Native_EPS,
         "two points");
   end Two_Points;

   procedure Ordinary_Triangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Triangle),
         2.0,
         1.5,
         2.5 + Native_EPS,
         "triangle");
   end Ordinary_Triangle;

   procedure Ordinary_Square (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Square),
         2.0,
         2.0,
         2.828427 + Native_EPS,
         "square");
   end Ordinary_Square;

   procedure Collinear_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 2, Y => 0), (X => 6, Y => 0));
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Points),
         3.0,
         0.0,
         3.0 + Native_EPS,
         "collinear");
   end Collinear_Points;

   procedure Duplicate_All_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 5, Y => 5), (X => 5, Y => 5), (X => 5, Y => 5));
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Points),
         5.0,
         5.0,
         Native_EPS,
         "identical points");
   end Duplicate_All_Points;

   procedure Duplicate_Mixed_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 0),
         (X => 0, Y => 4));
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Points),
         2.0,
         2.0,
         2.828427 + Native_EPS,
         "mixed duplicates");
   end Duplicate_Mixed_Points;

   procedure Translated_Negative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Translated);
   begin
      Assert_Close (Circle.Center.X, -8.0, "translated X");
      Assert_Close (Circle.Center.Y, -8.0, "translated Y");
      Assert_Close (Circle.Radius, 2.828427 + Native_EPS, "translated radius");
   end Translated_Negative;

   procedure Reversed_Order (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Forward   : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Square);
      Reverse_C : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Clockwise);
   begin
      Assert_Close (Forward.Center.X, Reverse_C.Center.X, "order X");
      Assert_Close (Forward.Center.Y, Reverse_C.Center.Y, "order Y");
      Assert_Close (Forward.Radius, Reverse_C.Radius, "order radius");
   end Reversed_Order;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour (5 .. 8) := Square;
   begin
      Assert_Circle
        (OpenCV.Geometry.Minimum_Enclosing_Circle (Points),
         2.0,
         2.0,
         2.828427 + Native_EPS,
         "nonzero bounds");
   end Nonzero_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Square;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Circle   : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Points);
   begin
      AUnit.Assertions.Assert
        (Same_Contour (Points, Original), "input unchanged");
      Assert_Close (Circle.Center.X, 2.0, "unchanged still 2,2");
   end Input_Unchanged;

   procedure Safe_Ordinary_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Square);
   begin
      AUnit.Assertions.Assert
        (Circle.Radius > 0.0, "ordinary radius positive");
   end Safe_Ordinary_Contour;

   procedure Safe_Large_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Limit  : constant OpenCV.Core.Point_Coordinate := 1_000_000;
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => Limit, Y => 0), (X => Limit, Y => 1));
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Points);
   begin
      Assert_Close (Circle.Center.X, 500_000.0, "large X");
      AUnit.Assertions.Assert (Circle.Radius > 0.0, "large radius");
   end Safe_Large_Coordinates;

   procedure Binary32_Above_Exact_Integer_Range (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  2^24 + 1 is not exact in binary32. Native integer addition of
      --  16777217 + 16777217 yields 33554434, which converts to 33554432.0f.
      --  Converting first would add 16777216.0f + 16777216.0f. The native
      --  integer path still produces this OpenCV 4.10 integer-input result.
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 16_777_217, Y => 0),
         (X => 16_777_217, Y => 1_000),
         (X => 16_777_218, Y => 0));
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Points);
   begin
      Assert_Close (Circle.Center.X, 16_777_216.0, "above 2^24 X");
      Assert_Close (Circle.Center.Y, 500.0, "above 2^24 Y");
      Assert_Close (Circle.Radius, 500.004089, "above 2^24 radius");
   end Binary32_Above_Exact_Integer_Range;

   procedure Assert_Rejected_Arithmetic
     (Buffer : in out C_API.Point_I32_Array; Message : String)
   is
      Output : aliased C_API.C_Enclosing_Circle :=
        (Center_X => -1.0, Center_Y => -2.0, Radius => -3.0);
      Status : C_API.Status;
   begin
      Status :=
        C_API.Min_Enclosing_Circle
          (Buffer (Buffer'First)'Access,
           Interfaces.Integer_32 (Buffer'Length),
           Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, Message & ": status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "range") /= 0,
         Message & ": diagnostic");
      AUnit.Assertions.Assert (Output.Center_X = 0.0, Message & ": X");
      AUnit.Assertions.Assert (Output.Center_Y = 0.0, Message & ": Y");
      AUnit.Assertions.Assert (Output.Radius = 0.0, Message & ": radius");
   end Assert_Rejected_Arithmetic;

   procedure Unsafe_Subtraction_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => 0, Y => 0),
         (X => 1, Y => 0));
   begin
      Assert_Rejected_Arithmetic
        (Buffer, "INT32_MIN subtraction must not reach minEnclosingCircle");
   end Unsafe_Subtraction_Rejected;

   procedure Unsafe_Addition_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'Last, Y => 0),
         (X => Interfaces.Integer_32'Last, Y => 1),
         (X => 0, Y => 0));
   begin
      Assert_Rejected_Arithmetic
        (Buffer, "INT32_MAX addition must not reach minEnclosingCircle");
   end Unsafe_Addition_Rejected;

   procedure Unsafe_Negative_Addition_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => Interfaces.Integer_32'First, Y => 1),
         (X => 0, Y => 0));
   begin
      Assert_Rejected_Arithmetic
        (Buffer, "INT32_MIN addition must not reach minEnclosingCircle");
   end Unsafe_Negative_Addition_Rejected;

   procedure Safe_Sum_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Half   : constant OpenCV.Core.Point_Coordinate :=
        OpenCV.Core.Point_Coordinate (Interfaces.Integer_32'Last / 2);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => Half, Y => 0), (X => Half, Y => 1), (X => 0, Y => 0));
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Points);
   begin
      AUnit.Assertions.Assert (Circle.Radius > 0.0, "safe half-sum radius");
   end Safe_Sum_Boundary;

   procedure Safe_Difference_Boundary (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Last   : constant OpenCV.Core.Point_Coordinate :=
        OpenCV.Core.Point_Coordinate (Interfaces.Integer_32'Last);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => Last, Y => 0), (X => 0, Y => 1));
      Circle : constant OpenCV.Geometry.Enclosing_Circle :=
        OpenCV.Geometry.Minimum_Enclosing_Circle (Points);
   begin
      AUnit.Assertions.Assert
        (Circle.Radius > 0.0, "INT32_MAX difference remains representable");
   end Safe_Difference_Boundary;

   procedure Two_Point_Integer_Extremes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => Interfaces.Integer_32'Last, Y => 0));
      Output : aliased C_API.C_Enclosing_Circle :=
        (Center_X => -1.0, Center_Y => -1.0, Radius => -1.0);
      Status : C_API.Status;
   begin
      Status :=
        C_API.Min_Enclosing_Circle
          (Buffer (Buffer'First)'Access, 2, Output'Access);
      --  OpenCV 4 converts count == 2 to Point2f first. OpenCV 5 uses
      --  integer pair arithmetic for count >= 2, so this pair is unsafe.
      AUnit.Assertions.Assert
        (Status = C_API.Success or else Status = C_API.Error_Invalid_Argument,
         "two-point extremes must be accepted or rejected by backend");
      if Status = C_API.Error_Invalid_Argument then
         AUnit.Assertions.Assert (Output.Radius = 0.0, "5.x zeros output");
      else
         AUnit.Assertions.Assert (Output.Radius > 0.0, "4.x two-point radius");
      end if;
   end Two_Point_Integer_Extremes;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 4),
         (X => 0, Y => 4));
      Output : aliased C_API.C_Enclosing_Circle :=
        (Center_X => -1.0, Center_Y => -2.0, Radius => -3.0);
      Status : C_API.Status;

      procedure Assert_Rejected
        (Call_Status : C_API.Status; Needle : String; Message : String) is
      begin
         AUnit.Assertions.Assert
           (Call_Status = C_API.Error_Invalid_Argument, Message & ": status");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Needle) /= 0,
            Message & ": diagnostic");
         AUnit.Assertions.Assert (Output.Center_X = 0.0, Message & ": X");
         AUnit.Assertions.Assert (Output.Center_Y = 0.0, Message & ": Y");
         AUnit.Assertions.Assert (Output.Radius = 0.0, Message & ": radius");
      end Assert_Rejected;
   begin
      Output := (Center_X => -1.0, Center_Y => -2.0, Radius => -3.0);
      Status :=
        C_API.Min_Enclosing_Circle
          (Points (Points'First)'Access, -1, Output'Access);
      Assert_Rejected (Status, "count", "negative count");

      Output := (Center_X => -1.0, Center_Y => -2.0, Radius => -3.0);
      Status := C_API.Min_Enclosing_Circle (null, 4, Output'Access);
      Assert_Rejected (Status, "null", "null points");

      Status :=
        C_API.Min_Enclosing_Circle (Points (Points'First)'Access, 4, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null output status");

      Output := (Center_X => -1.0, Center_Y => -2.0, Radius => -3.0);
      Status := C_API.Min_Enclosing_Circle (null, 0, Output'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "empty ABI status");
      AUnit.Assertions.Assert (Output.Center_X = 0.0, "empty ABI X");
      AUnit.Assertions.Assert (Output.Center_Y = 0.0, "empty ABI Y");
      AUnit.Assertions.Assert (Output.Radius = 0.0, "empty ABI radius");

      Output := (Center_X => -1.0, Center_Y => -2.0, Radius => -3.0);
      Status :=
        C_API.Min_Enclosing_Circle
          (Points (Points'First)'Access, 4, Output'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "ordinary ABI status");
      AUnit.Assertions.Assert (Output.Center_X > 0.0, "ordinary ABI X");
      AUnit.Assertions.Assert (Output.Radius > 0.0, "ordinary ABI radius");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test (Caller.Create ("Empty contour", Empty_Contour'Access));
      Result.Add_Test (Caller.Create ("One point", One_Point'Access));
      Result.Add_Test (Caller.Create ("Two points", Two_Points'Access));
      Result.Add_Test (Caller.Create ("Triangle", Ordinary_Triangle'Access));
      Result.Add_Test (Caller.Create ("Square", Ordinary_Square'Access));
      Result.Add_Test
        (Caller.Create ("Collinear points", Collinear_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Duplicate identical points", Duplicate_All_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Duplicate mixed points", Duplicate_Mixed_Points'Access));
      Result.Add_Test
        (Caller.Create ("Translated negative", Translated_Negative'Access));
      Result.Add_Test
        (Caller.Create ("Reversed order", Reversed_Order'Access));
      Result.Add_Test
        (Caller.Create ("Nonzero Ada bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create ("Input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Safe ordinary contour", Safe_Ordinary_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Safe large coordinates", Safe_Large_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Binary32 above exact integer range",
            Binary32_Above_Exact_Integer_Range'Access));
      Result.Add_Test
        (Caller.Create
           ("Unsafe subtraction rejected",
            Unsafe_Subtraction_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Unsafe addition rejected", Unsafe_Addition_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Unsafe negative addition rejected",
            Unsafe_Negative_Addition_Rejected'Access));
      Result.Add_Test
        (Caller.Create ("Safe sum boundary", Safe_Sum_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("Safe difference boundary", Safe_Difference_Boundary'Access));
      Result.Add_Test
        (Caller.Create
           ("Two-point integer extremes", Two_Point_Integer_Extremes'Access));
      Result.Add_Test
        (Caller.Create ("C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Minimum_Enclosing_Circle_Tests;
