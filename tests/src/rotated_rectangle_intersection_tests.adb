with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Rotated_Rectangle_Intersection_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Float32_Value;
   use type OpenCV.Geometry.Rectangle_Intersection_Kind;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Tolerance : constant OpenCV.Float32_Value := 1.0E-3;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Float32_Value);

   NaN_Bits     : constant Interfaces.Unsigned_32 := 16#7FC0_0000#;
   Inf_Bits     : constant Interfaces.Unsigned_32 := 16#7F80_0000#;
   Neg_Inf_Bits : constant Interfaces.Unsigned_32 := 16#FF80_0000#;

   function Box
     (X, Y, Width, Height, Angle : OpenCV.Float32_Value)
      return OpenCV.Rotated_Rect
   is ((Center        => (X => X, Y => Y),
        Size          => (Width => Width, Height => Height),
        Angle_Degrees => Angle));

   function To_C (Value : OpenCV.Rotated_Rect) return C_API.C_Rotated_Rect
   is ((Center_X      => Interfaces.C.C_float (Value.Center.X),
        Center_Y      => Interfaces.C.C_float (Value.Center.Y),
        Width         => Interfaces.C.C_float (Value.Size.Width),
        Height        => Interfaces.C.C_float (Value.Size.Height),
        Angle_Degrees => Interfaces.C.C_float (Value.Angle_Degrees)));

   Unit_Square : constant OpenCV.Rotated_Rect := Box (0.0, 0.0, 4.0, 4.0, 0.0);

   function Close (Left, Right : OpenCV.Float32_Value) return Boolean
   is (abs (Left - Right) <= Tolerance);

   function Contains
     (Vertices : OpenCV.Geometry.Float32_Point_Array;
      Expected : OpenCV.Float32_Point) return Boolean is
   begin
      for Vertex of Vertices loop
         if Close (Vertex.X, Expected.X) and then Close (Vertex.Y, Expected.Y)
         then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   --  Same length and every expected vertex present; native order is not
   --  asserted.
   function Same_Vertex_Set
     (Actual, Expected : OpenCV.Geometry.Float32_Point_Array) return Boolean is
   begin
      if Actual'Length /= Expected'Length then
         return False;
      end if;
      for Vertex of Expected loop
         if not Contains (Actual, Vertex) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Vertex_Set;

   function Corners
     (Value : OpenCV.Rotated_Rect) return OpenCV.Geometry.Float32_Point_Array
   is
      Vertices : constant OpenCV.Geometry.Box_Vertices :=
        OpenCV.Geometry.Box_Points (Value);
      Result   : OpenCV.Geometry.Float32_Point_Array (1 .. 4);
   begin
      for Index in Vertices'Range loop
         Result (Natural (Index)) := Vertices (Index);
      end loop;
      return Result;
   end Corners;

   procedure Partial_Overlap (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result   : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
        OpenCV.Geometry.Intersect_Rotated_Rectangles
          (Unit_Square, Box (2.0, 2.0, 4.0, 4.0, 0.0));
      Expected : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 0.0, Y => 0.0),
         (X => 2.0, Y => 0.0),
         (X => 2.0, Y => 2.0),
         (X => 0.0, Y => 2.0));
   begin
      AUnit.Assertions.Assert
        (Result.Kind = OpenCV.Geometry.Partial_Intersection,
         "overlapping squares must intersect partially");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Result.Vertices, Expected),
         "partial overlap must be the 0 .. 2 square");
   end Partial_Overlap;

   procedure Octagon_Fills_Capacity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A square and the same square rotated 45 degrees intersect in a
      --  regular octagon: eight vertices, OpenCV's maximum.
      Inset    : constant OpenCV.Float32_Value := 0.828_427_1;
      Result   : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
        OpenCV.Geometry.Intersect_Rotated_Rectangles
          (Unit_Square, Box (0.0, 0.0, 4.0, 4.0, 45.0));
      Expected : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 2.0, Y => Inset),
         (X => 2.0, Y => -Inset),
         (X => -2.0, Y => Inset),
         (X => -2.0, Y => -Inset),
         (X => Inset, Y => 2.0),
         (X => -Inset, Y => 2.0),
         (X => Inset, Y => -2.0),
         (X => -Inset, Y => -2.0));
   begin
      AUnit.Assertions.Assert
        (Result.Kind = OpenCV.Geometry.Partial_Intersection
         and then Result.Vertex_Count = 8,
         "rotated squares must intersect in eight vertices");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Result.Vertices, Expected),
         "the octagon vertices must match");
   end Octagon_Fills_Capacity;

   procedure Full_Containment (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Outer : constant OpenCV.Rotated_Rect := Box (0.0, 0.0, 10.0, 10.0, 0.0);
      Inner : constant OpenCV.Rotated_Rect := Box (1.0, 1.0, 2.0, 2.0, 30.0);
   begin
      for Outer_First in Boolean loop
         declare
            Result : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
              (if Outer_First
               then OpenCV.Geometry.Intersect_Rotated_Rectangles (Outer, Inner)
               else
                 OpenCV.Geometry.Intersect_Rotated_Rectangles (Inner, Outer));
         begin
            AUnit.Assertions.Assert
              (Result.Kind = OpenCV.Geometry.Full_Intersection,
               "an enclosed rectangle must be a full intersection");
            AUnit.Assertions.Assert
              (Same_Vertex_Set (Result.Vertices, Corners (Inner)),
               "a full intersection must be the enclosed rectangle");
         end;
      end loop;
   end Full_Containment;

   procedure Identical_Rectangles (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Tilted : constant OpenCV.Rotated_Rect := Box (1.0, -2.0, 4.0, 2.0, 30.0);
      Result : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
        OpenCV.Geometry.Intersect_Rotated_Rectangles (Tilted, Tilted);
   begin
      AUnit.Assertions.Assert
        (Result.Kind = OpenCV.Geometry.Full_Intersection
         and then Same_Vertex_Set (Result.Vertices, Corners (Tilted)),
         "identical rectangles must fully intersect at their corners");
   end Identical_Rectangles;

   procedure No_Intersection (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check (Right : OpenCV.Rotated_Rect; Label : String) is
         Result : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
           OpenCV.Geometry.Intersect_Rotated_Rectangles (Unit_Square, Right);
      begin
         AUnit.Assertions.Assert
           (Result.Kind = OpenCV.Geometry.No_Intersection
            and then Result.Vertex_Count = 0,
            Label & " must not intersect");
      end Check;
   begin
      Check (Box (10.0, 10.0, 2.0, 2.0, 0.0), "a distant rectangle");
      Check (Box (0.0, 0.0, 0.0, 2.0, 0.0), "a zero-width rectangle");
      Check (Box (0.0, 0.0, 2.0, 0.0, 0.0), "a zero-height rectangle");
      Check (Box (0.0, 0.0, -4.0, 2.0, 0.0), "a negative-width rectangle");
   end No_Intersection;

   procedure Touching_Rectangles (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Small      : constant OpenCV.Rotated_Rect :=
        Box (0.0, 0.0, 2.0, 2.0, 0.0);
      Edge_Touch : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
        OpenCV.Geometry.Intersect_Rotated_Rectangles
          (Small, Box (2.0, 0.0, 2.0, 2.0, 0.0));
      Corner     : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
        OpenCV.Geometry.Intersect_Rotated_Rectangles
          (Small, Box (2.0, 2.0, 2.0, 2.0, 0.0));
   begin
      --  Touching edges cross the perpendicular edges at the shared
      --  endpoints, so OpenCV reports a partial intersection at the contact.
      --  The exact contact vertex count depends on OpenCV's duplicate
      --  tolerance, which differs between 4.6 and 4.10+.
      AUnit.Assertions.Assert
        (Edge_Touch.Kind = OpenCV.Geometry.Partial_Intersection
         and then Edge_Touch.Vertex_Count >= 1,
         "touching edges must be a partial intersection at the contact");
      AUnit.Assertions.Assert
        (Corner.Kind = OpenCV.Geometry.Partial_Intersection
         and then Corner.Vertex_Count >= 1,
         "touching corners must be a partial intersection at the contact");
      for Vertex of Edge_Touch.Vertices loop
         AUnit.Assertions.Assert
           (Close (Vertex.X, 1.0)
            and then Vertex.Y >= -1.0 - Tolerance
            and then Vertex.Y <= 1.0 + Tolerance,
            "edge contact vertices must lie on the shared edge");
      end loop;
      for Vertex of Corner.Vertices loop
         AUnit.Assertions.Assert
           (Close (Vertex.X, 1.0) and then Close (Vertex.Y, 1.0),
            "corner contact vertices must be the shared corner");
      end loop;
   end Touching_Rectangles;

   procedure Translated_Negative_Center (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result   : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
        OpenCV.Geometry.Intersect_Rotated_Rectangles
          (Box (-1_000.0, -500.0, 4.0, 4.0, 0.0),
           Box (-998.0, -498.0, 4.0, 4.0, 0.0));
      Expected : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => -1_000.0, Y => -500.0),
         (X => -998.0, Y => -500.0),
         (X => -998.0, Y => -498.0),
         (X => -1_000.0, Y => -498.0));
   begin
      AUnit.Assertions.Assert
        (Result.Kind = OpenCV.Geometry.Partial_Intersection
         and then Same_Vertex_Set (Result.Vertices, Expected),
         "translated overlap must move with the rectangles");
   end Translated_Negative_Center;

   procedure Inputs_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Warnings (Off, "could be declared constant");
      Left         : OpenCV.Rotated_Rect := Unit_Square;
      Right        : OpenCV.Rotated_Rect := Box (2.0, 2.0, 4.0, 4.0, 15.0);
      pragma Warnings (On, "could be declared constant");
      Right_Before : constant OpenCV.Rotated_Rect := Right;
      Unused       : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
        OpenCV.Geometry.Intersect_Rotated_Rectangles (Left, Right);
      pragma Unreferenced (Unused);
   begin
      AUnit.Assertions.Assert
        (OpenCV."=" (Left, Unit_Square)
         and then OpenCV."=" (Right, Right_Before),
         "Intersect_Rotated_Rectangles must leave its inputs unchanged");
   end Inputs_Unchanged;

   procedure Rejects_Non_Finite_Fields (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      type Field is (Center_X, Center_Y, Width, Height, Angle);

      type Bit_Patterns is array (Positive range <>) of Interfaces.Unsigned_32;

      function With_Value
        (Value : OpenCV.Float32_Value; Which : Field)
         return OpenCV.Rotated_Rect
      is
         Result : OpenCV.Rotated_Rect := Unit_Square;
      begin
         case Which is
            when Center_X =>
               Result.Center.X := Value;

            when Center_Y =>
               Result.Center.Y := Value;

            when Width    =>
               Result.Size.Width := Value;

            when Height   =>
               Result.Size.Height := Value;

            when Angle    =>
               Result.Angle_Degrees := Value;
         end case;
         return Result;
      end With_Value;

      function Rejected
        (Left, Right : OpenCV.Rotated_Rect; Fragment : String) return Boolean
      is
      begin
         declare
            Unused : constant OpenCV.Geometry.Rotated_Rectangle_Intersection :=
              OpenCV.Geometry.Intersect_Rotated_Rectangles (Left, Right);
            pragma Unreferenced (Unused);
         begin
            return False;
         end;
      exception
         when Error : OpenCV.OpenCV_Error =>
            return
              Ada.Strings.Fixed.Index
                (Ada.Exceptions.Exception_Message (Error), Fragment)
              /= 0;
      end Rejected;
   begin
      for Bits of Bit_Patterns'(NaN_Bits, Inf_Bits, Neg_Inf_Bits) loop
         for Which in Field loop
            declare
               Bad : constant OpenCV.Rotated_Rect :=
                 With_Value (Bits_To_Float32 (Bits), Which);
            begin
               AUnit.Assertions.Assert
                 (Rejected (Bad, Unit_Square, "finite Left"),
                  "a non-finite Left field must be rejected");
               AUnit.Assertions.Assert
                 (Rejected (Unit_Square, Bad, "finite Right"),
                  "a non-finite Right field must be rejected");
            end;
         end loop;
      end loop;
   end Rejects_Non_Finite_Fields;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left     : aliased constant C_API.C_Rotated_Rect := To_C (Unit_Square);
      Right    : aliased constant C_API.C_Rotated_Rect :=
        To_C (Box (0.0, 0.0, 4.0, 4.0, 45.0));
      Sentinel : constant C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => -7.0, Y => -9.0));
      Output   : aliased C_API.Point_F32_Array (0 .. 7) := Sentinel;
      Kind     : aliased Interfaces.Integer_32 := -1;
      Count    : aliased Interfaces.Integer_32 := -1;
      Status   : C_API.Status;

      procedure Expect_Invalid (Fragment, Message : String) is
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Ada.Strings.Fixed.Index
                       (C_API.Last_Error_Message, Fragment)
                     /= 0,
            Message);
         AUnit.Assertions.Assert
           (Count = 0
            and then Kind = C_API.Rectangles_Intersect_None
            and then C_API."=" (Output, Sentinel),
            Message & ": nothing may be published");
         Count := -1;
         Kind := -1;
      end Expect_Invalid;
   begin
      Status :=
        C_API.Rotated_Rectangle_Intersection
          (null,
           Right'Access,
           Kind'Access,
           Output (0)'Access,
           8,
           Count'Access);
      Expect_Invalid ("rotated rectangle", "null left rectangle");
      Status :=
        C_API.Rotated_Rectangle_Intersection
          (Left'Access, null, Kind'Access, Output (0)'Access, 8, Count'Access);
      Expect_Invalid ("rotated rectangle", "null right rectangle");
      Status :=
        C_API.Rotated_Rectangle_Intersection
          (Left'Access,
           Right'Access,
           Kind'Access,
           Output (0)'Access,
           -1,
           Count'Access);
      Expect_Invalid ("capacity", "negative capacity");
      Status :=
        C_API.Rotated_Rectangle_Intersection
          (Left'Access, Right'Access, Kind'Access, null, 8, Count'Access);
      Expect_Invalid ("output", "null output with positive capacity");
      Status :=
        C_API.Rotated_Rectangle_Intersection
          (Left'Access,
           Right'Access,
           Kind'Access,
           Output (0)'Access,
           7,
           Count'Access);
      Expect_Invalid ("capacity", "seven slots for an octagon");

      Status :=
        C_API.Rotated_Rectangle_Intersection
          (Left'Access,
           Right'Access,
           null,
           Output (0)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Count = 0
         and then C_API."=" (Output, Sentinel),
         "null output kind must be rejected");
      Kind := -1;
      Status :=
        C_API.Rotated_Rectangle_Intersection
          (Left'Access, Right'Access, Kind'Access, Output (0)'Access, 8, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then C_API."=" (Output, Sentinel),
         "null output count must be rejected");

      Count := -1;
      Status :=
        C_API.Rotated_Rectangle_Intersection
          (Left'Access,
           Right'Access,
           Kind'Access,
           Output (0)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Count = 8
         and then Kind = C_API.Rectangles_Intersect_Partial,
         "an exact eight-slot capacity must receive the octagon");
   end C_ABI_Validation;

   procedure C_ABI_Kind_Encoding (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Output : aliased C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => 0.0, Y => 0.0));
      Kind   : aliased Interfaces.Integer_32 := -1;
      Count  : aliased Interfaces.Integer_32 := -1;
      Status : C_API.Status;

      procedure Check
        (Left, Right : OpenCV.Rotated_Rect;
         Expected    : Interfaces.Integer_32;
         Message     : String)
      is
         Packed_Left  : aliased constant C_API.C_Rotated_Rect := To_C (Left);
         Packed_Right : aliased constant C_API.C_Rotated_Rect := To_C (Right);
      begin
         Status :=
           C_API.Rotated_Rectangle_Intersection
             (Packed_Left'Access,
              Packed_Right'Access,
              Kind'Access,
              Output (0)'Access,
              8,
              Count'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success and then Kind = Expected, Message);
      end Check;
   begin
      Check
        (Unit_Square,
         Box (10.0, 10.0, 2.0, 2.0, 0.0),
         C_API.Rectangles_Intersect_None,
         "no intersection must encode as NONE");
      Check
        (Unit_Square,
         Box (2.0, 2.0, 4.0, 4.0, 0.0),
         C_API.Rectangles_Intersect_Partial,
         "a partial intersection must encode as PARTIAL");
      Check
        (Box (0.0, 0.0, 10.0, 10.0, 0.0),
         Box (1.0, 1.0, 2.0, 2.0, 30.0),
         C_API.Rectangles_Intersect_Full,
         "containment must encode as FULL");
   end C_ABI_Kind_Encoding;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection partial overlap",
            Partial_Overlap'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection octagon fills capacity",
            Octagon_Fills_Capacity'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection full containment",
            Full_Containment'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection identical rectangles",
            Identical_Rectangles'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection none", No_Intersection'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection touching rectangles",
            Touching_Rectangles'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection translated negative center",
            Translated_Negative_Center'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection inputs unchanged",
            Inputs_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection rejects non-finite fields",
            Rejects_Non_Finite_Fields'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection C ABI validation",
            C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Rotated rectangle intersection C ABI kind encoding",
            C_ABI_Kind_Encoding'Access));
      return Result'Access;
   end Suite;

end Rotated_Rectangle_Intersection_Tests;
