with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Convex_Polygon_Intersection_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Tolerance : constant OpenCV.Float32_Value := 1.0E-3;

   --  Axis-aligned squares. Square_A and Square_B overlap in the square
   --  5 .. 10 x 5 .. 10.
   Square_A : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 10, Y => 0),
      (X => 10, Y => 10),
      (X => 0, Y => 10));

   Square_B : constant OpenCV.Geometry.Contour :=
     ((X => 5, Y => 5),
      (X => 15, Y => 5),
      (X => 15, Y => 15),
      (X => 5, Y => 15));

   Overlap : constant OpenCV.Geometry.Float32_Point_Array :=
     ((X => 5.0, Y => 5.0),
      (X => 10.0, Y => 5.0),
      (X => 10.0, Y => 10.0),
      (X => 5.0, Y => 10.0));

   function Reversed
     (Points : OpenCV.Geometry.Contour) return OpenCV.Geometry.Contour
   is
      Result : OpenCV.Geometry.Contour (Points'Range);
   begin
      for Offset in 0 .. Points'Length - 1 loop
         Result (Points'First + Offset) := Points (Points'Last - Offset);
      end loop;
      return Result;
   end Reversed;

   function Translated
     (Points : OpenCV.Geometry.Contour; DX, DY : OpenCV.Point_Coordinate)
      return OpenCV.Geometry.Contour
   is
      Result : OpenCV.Geometry.Contour := Points;
   begin
      for Point of Result loop
         Point := (X => Point.X + DX, Y => Point.Y + DY);
      end loop;
      return Result;
   end Translated;

   function Oriented
     (Points : OpenCV.Geometry.Contour; Reverse_Order : Boolean)
      return OpenCV.Geometry.Contour
   is (if Reverse_Order then Reversed (Points) else Points);

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

   --  True when Actual and Expected have the same length and every expected
   --  vertex appears in Actual. The native vertex order is not asserted.
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

   function Raises_OpenCV_Error
     (Left, Right : OpenCV.Geometry.Contour; Fragment : String) return Boolean
   is
   begin
      declare
         Unused : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
           OpenCV.Geometry.Intersect_Convex_Polygons (Left, Right);
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
   end Raises_OpenCV_Error;

   procedure Partial_Overlap (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons (Square_A, Square_B);
   begin
      AUnit.Assertions.Assert
        (Close (Result.Area, 25.0), "overlap area must be 25");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Result.Vertices, Overlap),
         "overlap vertices must be the 5 .. 10 square corners");
      AUnit.Assertions.Assert
        (Result.Vertices'First = 1, "vertices must be indexed from 1");
   end Partial_Overlap;

   procedure Winding_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check (Left, Right : OpenCV.Geometry.Contour; Label : String)
      is
         Result : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
           OpenCV.Geometry.Intersect_Convex_Polygons (Left, Right);
      begin
         AUnit.Assertions.Assert
           (Close (Result.Area, 25.0)
            and then Same_Vertex_Set (Result.Vertices, Overlap),
            Label & " must give the same overlap");
      end Check;
   begin
      Check (Square_A, Reversed (Square_B), "reversed right");
      Check (Reversed (Square_A), Square_B, "reversed left");
      Check (Reversed (Square_A), Reversed (Square_B), "both reversed");
      Check (Square_B, Square_A, "swapped arguments");
   end Winding_Independent;

   procedure Disjoint_Polygons (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Side-by-side squares reach OpenCV's parallel-separated early exit,
      --  which returns the internal FLT_MAX sentinel as a vertex; reversing
      --  both inputs makes OpenCV reverse that result, moving it last.
      Far      : constant OpenCV.Geometry.Contour :=
        Translated (Square_A, 20, 20);
      Triangle : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 12, Y => 0), (X => 6, Y => 12));
      Distant  : constant OpenCV.Geometry.Contour :=
        Translated (Triangle, 40, 3);
   begin
      for Nested in Boolean loop
         for Reverse_Both in Boolean loop
            declare
               Parallel :
                 constant OpenCV.Geometry.Convex_Polygon_Intersection :=
                   OpenCV.Geometry.Intersect_Convex_Polygons
                     (Oriented (Square_A, Reverse_Both),
                      Oriented (Far, Reverse_Both),
                      Handle_Nested => Nested);
               Skew     :
                 constant OpenCV.Geometry.Convex_Polygon_Intersection :=
                   OpenCV.Geometry.Intersect_Convex_Polygons
                     (Oriented (Triangle, Reverse_Both),
                      Oriented (Distant, Reverse_Both),
                      Handle_Nested => Nested);
            begin
               AUnit.Assertions.Assert
                 (Parallel.Vertex_Count = 0 and then Parallel.Area = 0.0,
                  "parallel separated polygons must not intersect");
               AUnit.Assertions.Assert
                 (Skew.Vertex_Count = 0 and then Skew.Area = 0.0,
                  "distant triangles must not intersect");
            end;
         end loop;
      end loop;
   end Disjoint_Polygons;

   procedure Nested_Polygons (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Inner    : constant OpenCV.Geometry.Contour :=
        ((X => 2, Y => 2),
         (X => 4, Y => 2),
         (X => 4, Y => 4),
         (X => 2, Y => 4));
      Expected : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 2.0, Y => 2.0),
         (X => 4.0, Y => 2.0),
         (X => 4.0, Y => 4.0),
         (X => 2.0, Y => 4.0));
   begin
      for Outer_First in Boolean loop
         for Reverse_Outer in Boolean loop
            declare
               Outer   : constant OpenCV.Geometry.Contour :=
                 Oriented (Square_A, Reverse_Outer);
               Left    : constant OpenCV.Geometry.Contour :=
                 (if Outer_First then Outer else Inner);
               Right   : constant OpenCV.Geometry.Contour :=
                 (if Outer_First then Inner else Outer);
               Handled :
                 constant OpenCV.Geometry.Convex_Polygon_Intersection :=
                   OpenCV.Geometry.Intersect_Convex_Polygons (Left, Right);
               Ignored :
                 constant OpenCV.Geometry.Convex_Polygon_Intersection :=
                   OpenCV.Geometry.Intersect_Convex_Polygons
                     (Left, Right, Handle_Nested => False);
            begin
               AUnit.Assertions.Assert
                 (Close (Handled.Area, 4.0)
                  and then Same_Vertex_Set (Handled.Vertices, Expected),
                  "Handle_Nested must return the enclosed polygon");
               AUnit.Assertions.Assert
                 (Ignored.Vertex_Count = 0 and then Ignored.Area = 0.0,
                  "Handle_Nested False must return no intersection");
            end;
         end loop;
      end loop;
   end Nested_Polygons;

   procedure Boundary_Contact_Is_Not_Nested (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A quarter square sharing two edges and a corner with Square_A.
      Corner   : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 5, Y => 0),
         (X => 5, Y => 5),
         (X => 0, Y => 5));
      Expected : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 0.0, Y => 0.0),
         (X => 5.0, Y => 0.0),
         (X => 5.0, Y => 5.0),
         (X => 0.0, Y => 5.0));
   begin
      for Nested in Boolean loop
         declare
            Result : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
              OpenCV.Geometry.Intersect_Convex_Polygons
                (Square_A, Corner, Handle_Nested => Nested);
         begin
            AUnit.Assertions.Assert
              (Close (Result.Area, 25.0)
               and then Same_Vertex_Set (Result.Vertices, Expected),
               "boundary contact must intersect regardless of Handle_Nested");
         end;
      end loop;
   end Boundary_Contact_Is_Not_Nested;

   procedure Shared_Edge (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Beside : constant OpenCV.Geometry.Contour :=
        Translated (Square_A, 10, 0);
   begin
      for Nested in Boolean loop
         for Reverse_Both in Boolean loop
            declare
               Result : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
                 OpenCV.Geometry.Intersect_Convex_Polygons
                   (Oriented (Square_A, Reverse_Both),
                    Oriented (Beside, Reverse_Both),
                    Handle_Nested => Nested);
            begin
               AUnit.Assertions.Assert
                 (Close (Result.Area, 0.0),
                  "a shared edge must have near-zero area");
               for Vertex of Result.Vertices loop
                  AUnit.Assertions.Assert
                    (Close (Vertex.X, 10.0)
                     and then Vertex.Y >= -Tolerance
                     and then Vertex.Y <= 10.0 + Tolerance,
                     "shared-edge vertices must lie on the shared edge");
               end loop;
            end;
         end loop;
      end loop;
   end Shared_Edge;

   procedure Touching_Vertex (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Diagonal : constant OpenCV.Geometry.Contour :=
        Translated (Square_A, 10, 10);
   begin
      for Nested in Boolean loop
         for Reverse_Both in Boolean loop
            declare
               Result : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
                 OpenCV.Geometry.Intersect_Convex_Polygons
                   (Oriented (Square_A, Reverse_Both),
                    Oriented (Diagonal, Reverse_Both),
                    Handle_Nested => Nested);
            begin
               AUnit.Assertions.Assert
                 (Close (Result.Area, 0.0),
                  "a touching vertex must have near-zero area");
               for Vertex of Result.Vertices loop
                  AUnit.Assertions.Assert
                    (Close (Vertex.X, 10.0) and then Close (Vertex.Y, 10.0),
                     "a touching-vertex result must be the shared vertex");
               end loop;
            end;
         end loop;
      end loop;
   end Touching_Vertex;

   procedure Hexagram_Fills_Capacity (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Two triangles whose intersection hexagon has 3 + 3 vertices, the
      --  full Left'Length + Right'Length capacity. Its area is 48.
      Up      : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 12, Y => 0), (X => 6, Y => 12));
      Down    : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 8), (X => 6, Y => -4), (X => 12, Y => 8));
      Hexagon : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 4.0, Y => 0.0),
         (X => 8.0, Y => 0.0),
         (X => 10.0, Y => 4.0),
         (X => 8.0, Y => 8.0),
         (X => 4.0, Y => 8.0),
         (X => 2.0, Y => 4.0));
      Result  : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons (Up, Down);
   begin
      AUnit.Assertions.Assert
        (Result.Vertex_Count = 6, "hexagram must have six vertices");
      AUnit.Assertions.Assert
        (Close (Result.Area, 48.0)
         and then Same_Vertex_Set (Result.Vertices, Hexagon),
         "hexagram intersection must be the expected hexagon");
   end Hexagram_Fills_Capacity;

   procedure Identical_Polygons (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result   : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons (Square_A, Square_A);
      Expected : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 0.0, Y => 0.0),
         (X => 10.0, Y => 0.0),
         (X => 10.0, Y => 10.0),
         (X => 0.0, Y => 10.0));
   begin
      AUnit.Assertions.Assert
        (Close (Result.Area, 100.0)
         and then Same_Vertex_Set (Result.Vertices, Expected),
         "identical squares must intersect in the whole square");
   end Identical_Polygons;

   procedure Translated_Negative_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result   : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons
          (Translated (Square_A, -1_000, -2_000),
           Translated (Square_B, -1_000, -2_000));
      Expected : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => -995.0, Y => -1_995.0),
         (X => -990.0, Y => -1_995.0),
         (X => -990.0, Y => -1_990.0),
         (X => -995.0, Y => -1_990.0));
   begin
      AUnit.Assertions.Assert
        (Close (Result.Area, 25.0)
         and then Same_Vertex_Set (Result.Vertices, Expected),
         "translated overlap must move with the polygons");
   end Translated_Negative_Coordinates;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left   : constant OpenCV.Geometry.Contour (10 .. 13) := Square_A;
      Right  :
        constant OpenCV.Geometry.Contour (Natural'Last - 3 .. Natural'Last) :=
          Square_B;
      Result : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons (Left, Right);
   begin
      AUnit.Assertions.Assert
        (Close (Result.Area, 25.0)
         and then Same_Vertex_Set (Result.Vertices, Overlap),
         "Ada array bounds must not change the intersection");
   end Nonzero_Array_Bounds;

   procedure Inputs_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Warnings (Off, "could be declared constant");
      Left   : OpenCV.Geometry.Contour := Square_A;
      Right  : OpenCV.Geometry.Contour := Square_B;
      pragma Warnings (On, "could be declared constant");
      Unused : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons (Left, Right);
      pragma Unreferenced (Unused);
   begin
      for Index in Left'Range loop
         AUnit.Assertions.Assert
           (OpenCV."=" (Left (Index), Square_A (Index))
            and then OpenCV."=" (Right (Index), Square_B (Index)),
            "Intersect_Convex_Polygons must leave its inputs unchanged");
      end loop;
   end Inputs_Unchanged;

   procedure Rejects_Invalid_Polygons (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Concave   : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 10, Y => 0),
         (X => 10, Y => 10),
         (X => 5, Y => 5),
         (X => 0, Y => 10));
      Collinear : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 5, Y => 0),
         (X => 10, Y => 0),
         (X => 10, Y => 10),
         (X => 0, Y => 10));
      Segment   : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 10, Y => 10));
      Empty     : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Point'(X => 0, Y => 0));
      --  A pentagram visits a pentagon's vertices in star order, and a
      --  triangle listed twice winds twice. Both turn consistently, so
      --  isContourConvex accepts them, yet neither is a simple polygon.
      Pentagram : constant OpenCV.Geometry.Contour :=
        ((X => 100, Y => 0),
         (X => -81, Y => 59),
         (X => 31, Y => -95),
         (X => 31, Y => 95),
         (X => -81, Y => -59));
      Twice     : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 12, Y => 0),
         (X => 6, Y => 12),
         (X => 0, Y => 0),
         (X => 12, Y => 0),
         (X => 6, Y => 12));
      Simple    : constant String := "simple strictly convex polygon";
   begin
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Concave, Square_B, "Left to be a " & Simple),
         "a concave Left must be rejected");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Square_A, Concave, "Right to be a " & Simple),
         "a concave Right must be rejected");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Collinear, Square_B, Simple),
         "collinear consecutive vertices must be rejected");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Segment, Square_B, "at least three vertices"),
         "a two-vertex polygon must be rejected");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Square_A, Empty, "at least three vertices"),
         "an empty polygon must be rejected");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Is_Convex (Pentagram)
         and then OpenCV.Geometry.Is_Convex (Twice),
         "Is_Convex accepts the star and the doubly wound triangle");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Pentagram, Square_B, Simple)
         and then Raises_OpenCV_Error (Square_A, Pentagram, Simple),
         "a self-intersecting star must be rejected");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Twice, Square_B, Simple)
         and then Raises_OpenCV_Error (Square_A, Twice, Simple),
         "a doubly wound polygon must be rejected");
   end Rejects_Invalid_Polygons;

   procedure Binary32_Exact_Coordinate_Limit (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Limit      : constant OpenCV.Point_Coordinate := 2**24;
      --  Square_B spans X up to Limit and Square_A spans Y down to -Limit.
      Near_Limit : constant OpenCV.Geometry.Contour :=
        Translated (Square_A, Limit - 15, -Limit);
      Overlapped : constant OpenCV.Geometry.Contour :=
        Translated (Square_B, Limit - 15, -Limit);
      Beyond     : constant OpenCV.Geometry.Contour :=
        Translated (Square_A, Limit - 9, 0);
      Below      : constant OpenCV.Geometry.Contour :=
        Translated (Square_A, 0, -Limit - 1);
      Result     : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons (Near_Limit, Overlapped);
   begin
      AUnit.Assertions.Assert
        (Close (Result.Area, 25.0),
         "coordinates at +/-2**24 must be accepted");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Beyond, Square_A, "2**24"),
         "a coordinate above 2**24 must be rejected");
      AUnit.Assertions.Assert
        (Raises_OpenCV_Error (Square_A, Below, "2**24"),
         "a coordinate below -2**24 must be rejected");
   end Binary32_Exact_Coordinate_Limit;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left     : aliased C_API.Point_I32_Array (0 .. 3) :=
        ((X => 0, Y => 0),
         (X => 10, Y => 0),
         (X => 10, Y => 10),
         (X => 0, Y => 10));
      Right    : aliased C_API.Point_I32_Array (0 .. 3) :=
        ((X => 5, Y => 5),
         (X => 15, Y => 5),
         (X => 15, Y => 15),
         (X => 5, Y => 15));
      Sentinel : constant C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => -7.0, Y => -9.0));
      Output   : aliased C_API.Point_F32_Array (0 .. 7) := Sentinel;
      Count    : aliased Interfaces.Integer_32 := -1;
      Area     : aliased Interfaces.C.C_float := -1.0;
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
            and then Area = 0.0
            and then C_API."=" (Output, Sentinel),
            Message & ": nothing may be published");
         Count := -1;
         Area := -1.0;
      end Expect_Invalid;

      function Call
        (Left_Count, Right_Count : Interfaces.Integer_32;
         Nested                  : Interfaces.Integer_32 := 1;
         Capacity                : Interfaces.Integer_32 := 8)
         return C_API.Status is
      begin
         return
           C_API.Intersect_Convex_Convex
             (Left (0)'Access,
              Left_Count,
              Right (0)'Access,
              Right_Count,
              Nested,
              Output (0)'Access,
              Capacity,
              Count'Access,
              Area'Access);
      end Call;
   begin
      Status := Call (-1, 4);
      Expect_Invalid ("count", "negative left count");
      Status := Call (4, -1);
      Expect_Invalid ("count", "negative right count");
      Status := Call (4, 4, Nested => 2);
      Expect_Invalid ("nested", "invalid nested selector");
      Status := Call (4, 4, Capacity => -1);
      Expect_Invalid ("capacity", "negative capacity");
      Status := Call (4, 4, Capacity => 3);
      Expect_Invalid ("capacity", "insufficient capacity for four vertices");
      --  The count guard runs before OpenCV reads either buffer.
      Status := Call (1_073_741_821, 1);
      Expect_Invalid ("allocation", "combined counts beyond native range");

      Status :=
        C_API.Intersect_Convex_Convex
          (null,
           4,
           Right (0)'Access,
           4,
           1,
           Output (0)'Access,
           8,
           Count'Access,
           Area'Access);
      Expect_Invalid ("left", "null left points with positive count");
      Status :=
        C_API.Intersect_Convex_Convex
          (Left (0)'Access,
           4,
           null,
           4,
           1,
           Output (0)'Access,
           8,
           Count'Access,
           Area'Access);
      Expect_Invalid ("right", "null right points with positive count");
      Status :=
        C_API.Intersect_Convex_Convex
          (Left (0)'Access,
           4,
           Right (0)'Access,
           4,
           1,
           null,
           8,
           Count'Access,
           Area'Access);
      Expect_Invalid ("output", "null output with positive capacity");
      Status :=
        C_API.Intersect_Convex_Convex
          (Left (0)'Access,
           4,
           Right (0)'Access,
           4,
           1,
           Output (0)'Access,
           8,
           null,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then C_API."=" (Output, Sentinel),
         "null output count must be rejected");
      Count := -1;
      Status :=
        C_API.Intersect_Convex_Convex
          (Left (0)'Access,
           4,
           Right (0)'Access,
           4,
           1,
           Output (0)'Access,
           8,
           Count'Access,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Count = 0
         and then C_API."=" (Output, Sentinel),
         "null output area must be rejected");

      Count := -1;
      Status := Call (4, 4, Capacity => 4);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 4 and then Area = 25.0,
         "an exact capacity must receive the whole overlap");
   end C_ABI_Validation;

   procedure C_ABI_Native_Edge_Cases (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left         : aliased C_API.Point_I32_Array (0 .. 3) :=
        ((X => 0, Y => 0),
         (X => 10, Y => 0),
         (X => 10, Y => 10),
         (X => 0, Y => 10));
      Far          : aliased C_API.Point_I32_Array (0 .. 3) :=
        ((X => 20, Y => 20),
         (X => 30, Y => 20),
         (X => 30, Y => 30),
         (X => 20, Y => 30));
      type Raw_Polygon is record
         Points : aliased C_API.Point_I32_Array (0 .. 4);
      end record;
      type Raw_Polygons is array (Positive range <>) of aliased Raw_Polygon;
      Bad_Polygons : aliased Raw_Polygons :=
        (1 =>
           (Points =>
              ((X => 0, Y => 0),
               (X => 10, Y => 0),
               (X => 10, Y => 10),
               (X => 5, Y => 5),
               (X => 0, Y => 10))),
         2 =>
           (Points =>
              ((X => 100, Y => 0),
               (X => -81, Y => 59),
               (X => 31, Y => -95),
               (X => 31, Y => 95),
               (X => -81, Y => -59))));
      One          : aliased C_API.Point_I32_Array (0 .. 0) :=
        (0 => (X => 1, Y => 1));
      Sentinel     : constant C_API.Point_F32_Array (0 .. 8) :=
        (others => (X => -7.0, Y => -9.0));
      Output       : aliased C_API.Point_F32_Array (0 .. 8) := Sentinel;
      Count        : aliased Interfaces.Integer_32 := -1;
      Area         : aliased Interfaces.C.C_float := -1.0;
      Status       : C_API.Status;
   begin
      --  OpenCV's parallel-separated early exit returns only its sentinel,
      --  which the shim omits.
      Status :=
        C_API.Intersect_Convex_Convex
          (Left (0)'Access,
           4,
           Far (0)'Access,
           4,
           1,
           Output (0)'Access,
           8,
           Count'Access,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0 and then Area = 0.0,
         "the native FLT_MAX sentinel must not be published as a vertex");

      --  OpenCV rejects an empty point vector by assertion.
      Output := Sentinel;
      Count := -1;
      Status :=
        C_API.Intersect_Convex_Convex
          (null,
           0,
           Far (0)'Access,
           4,
           1,
           Output (0)'Access,
           8,
           Count'Access,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then Count = 0
         and then Area = 0.0
         and then C_API."=" (Output, Sentinel),
         "a raw empty polygon must fail in OpenCV unpublished");

      --  OpenCV returns no intersection for fewer than two points.
      Count := -1;
      Status :=
        C_API.Intersect_Convex_Convex
          (One (0)'Access,
           1,
           Far (0)'Access,
           4,
           1,
           Output (0)'Access,
           8,
           Count'Access,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0 and then Area = 0.0,
         "a raw one-point polygon must give no intersection");

      --  Before OpenCV 4.11 the shim rejects input that is not a simple
      --  convex polygon, which could overflow OpenCV's buffer; later
      --  versions bound the native output and may report -1 instead.
      for Bad of Bad_Polygons loop
         Output := Sentinel;
         Count := -1;
         Status :=
           C_API.Intersect_Convex_Convex
             (Bad.Points (0)'Access,
              5,
              Left (0)'Access,
              4,
              1,
              Output (0)'Access,
              9,
              Count'Access,
              Area'Access);
         if Status = C_API.Error_Invalid_Argument then
            AUnit.Assertions.Assert
              (Ada.Strings.Fixed.Index
                 (C_API.Last_Error_Message, "version guard")
               /= 0
               and then Count = 0
               and then C_API."=" (Output, Sentinel),
               "a guarded invalid polygon must be rejected unpublished");
         else
            AUnit.Assertions.Assert
              (Status = C_API.Success
               and then Count >= 0
               and then Count <= 9
               and then (if Area < 0.0 then Count = 0),
               "a bounded native result must fit the capacity");
         end if;
      end loop;
   end C_ABI_Native_Edge_Cases;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection partial overlap",
            Partial_Overlap'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection winding independent",
            Winding_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection disjoint polygons",
            Disjoint_Polygons'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection nested polygons",
            Nested_Polygons'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection boundary contact is not nested",
            Boundary_Contact_Is_Not_Nested'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection shared edge", Shared_Edge'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection touching vertex",
            Touching_Vertex'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection hexagram fills capacity",
            Hexagram_Fills_Capacity'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection identical polygons",
            Identical_Polygons'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection translated negative coordinates",
            Translated_Negative_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection nonzero array bounds",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection inputs unchanged",
            Inputs_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection rejects invalid polygons",
            Rejects_Invalid_Polygons'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection binary32 coordinate limit",
            Binary32_Exact_Coordinate_Limit'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection C ABI validation",
            C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex polygon intersection C ABI native edge cases",
            C_ABI_Native_Edge_Cases'Access));
      return Result'Access;
   end Suite;

end Convex_Polygon_Intersection_Tests;
