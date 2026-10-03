with Ada.Exceptions;
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
with OpenCV.Geometry.Internal.Convexity;
with OpenCV.Geometry.Internal.Intersection;

package body Float32_Convex_Intersection_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;

   use type C_API.Status;
   use type Interfaces.C.C_float;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Geometry.Convex_Polygon_Intersection;
   use type OpenCV.Geometry.Float32_Point_Array;

   subtype Points is Support.Points;
   subtype Intersection is OpenCV.Geometry.Convex_Polygon_Intersection;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Tolerance : constant OpenCV.Float32_Value := 1.0E-5;

   --  Polygons on the 0.25 grid, which the integer overload cannot express.
   Square : constant Points :=
     ((X => 0.25, Y => 0.25),
      (X => 2.75, Y => 0.25),
      (X => 2.75, Y => 2.75),
      (X => 0.25, Y => 2.75));

   Diamond : constant Points :=
     ((X => 1.0, Y => 2.5),
      (X => 2.5, Y => 1.0),
      (X => 4.0, Y => 2.5),
      (X => 2.5, Y => 4.0));

   Overlap : constant Points :=
     ((X => 1.0, Y => 2.5),
      (X => 2.5, Y => 1.0),
      (X => 2.75, Y => 1.25),
      (X => 2.75, Y => 2.75),
      (X => 1.25, Y => 2.75));

   Overlap_Area : constant := 1.875;

   --  The same polygons scaled by 4 into integers.
   Integer_Square : constant OpenCV.Geometry.Contour :=
     ((X => 1, Y => 1),
      (X => 11, Y => 1),
      (X => 11, Y => 11),
      (X => 1, Y => 11));

   Integer_Diamond : constant OpenCV.Geometry.Contour :=
     ((X => 4, Y => 10),
      (X => 10, Y => 4),
      (X => 16, Y => 10),
      (X => 10, Y => 16));

   Inner : constant Points :=
     ((X => 1.25, Y => 1.25),
      (X => 1.75, Y => 1.25),
      (X => 1.75, Y => 1.75),
      (X => 1.25, Y => 1.75));

   function Intersect
     (Left, Right : Points; Handle_Nested : Boolean := True)
      return Intersection
   is (OpenCV.Geometry.Intersect_Convex_Polygons (Left, Right, Handle_Nested));

   function Close (Left, Right : OpenCV.Float32_Value) return Boolean
   is (abs (Left - Right) <= Tolerance);

   function Contains_Close
     (Vertices : Points; Expected : OpenCV.Float32_Point) return Boolean is
   begin
      for Vertex of Vertices loop
         if Close (Vertex.X, Expected.X) and then Close (Vertex.Y, Expected.Y)
         then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Close;

   function Same_Vertices (Actual, Expected : Points) return Boolean is
   begin
      if Actual'Length /= Expected'Length then
         return False;
      end if;
      for Vertex of Expected loop
         if not Contains_Close (Actual, Vertex) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Vertices;

   function Reversed (Source : Points) return Points is
      Result : Points (Source'Range);
   begin
      for Offset in 0 .. Source'Length - 1 loop
         Result (Source'First + Offset) := Source (Source'Last - Offset);
      end loop;
      return Result;
   end Reversed;

   function Translated
     (Source : Points; DX, DY : OpenCV.Float32_Value) return Points
   is
      Result : Points := Source;
   begin
      for Point of Result loop
         Point := (X => Point.X + DX, Y => Point.Y + DY);
      end loop;
      return Result;
   end Translated;

   --  True when intersecting Left and Right raises OpenCV_Error whose
   --  message contains Fragment.
   function Raises
     (Left, Right : Points; Fragment : String := "") return Boolean is
   begin
      declare
         Unused : constant Intersection := Intersect (Left, Right);
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
   end Raises;

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Overlap (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Found : constant Intersection := Intersect (Square, Diamond);
   begin
      AUnit.Assertions.Assert
        (Same_Vertices (Found.Vertices, Overlap),
         "the fractional overlap must have the expected vertices");
      AUnit.Assertions.Assert
        (Close (Found.Area, Overlap_Area),
         "the fractional overlap must have area 1.875");
      AUnit.Assertions.Assert
        (Found.Vertices'First = 1,
         "intersection vertices are indexed 1 .. Vertex_Count");
   end Fractional_Overlap;

   procedure Exact_Integer_Scaling (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Found  : constant Intersection := Intersect (Square, Diamond);
      Scaled : constant Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons
          (Integer_Square, Integer_Diamond);
   begin
      AUnit.Assertions.Assert
        (Found.Vertex_Count = Scaled.Vertex_Count
         and then Found.Area = Scaled.Area / 16.0,
         "the Float32 result must be the integer result scaled by 0.25");
      for Index in Found.Vertices'Range loop
         AUnit.Assertions.Assert
           (Found.Vertices (Index).X = Scaled.Vertices (Index).X / 4.0
            and then Found.Vertices (Index).Y
                     = Scaled.Vertices (Index).Y / 4.0,
            "every Float32 vertex must be exactly a scaled integer vertex");
      end loop;
   end Exact_Integer_Scaling;

   procedure Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Nested in Boolean loop
         AUnit.Assertions.Assert
           (Intersect
              (Support.To_Float32 (Integer_Square),
               Support.To_Float32 (Integer_Diamond),
               Nested)
            = OpenCV.Geometry.Intersect_Convex_Polygons
                (Integer_Square, Integer_Diamond, Nested),
            "integer-valued Float32 polygons must intersect exactly as the "
            & "integer overload");
      end loop;
   end Integer_Equivalence;

   procedure Nested_Polygons (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Kept    : constant Intersection := Intersect (Square, Inner, True);
      Ignored : constant Intersection := Intersect (Square, Inner, False);
   begin
      AUnit.Assertions.Assert
        (Same_Vertices (Kept.Vertices, Inner) and then Close (Kept.Area, 0.25),
         "Handle_Nested must return the inner polygon");
      AUnit.Assertions.Assert
        (Same_Vertices (Intersect (Inner, Square, True).Vertices, Inner),
         "nesting must be found in either order");
      AUnit.Assertions.Assert
        (Ignored.Vertex_Count = 0 and then Ignored.Area = 0.0,
         "without Handle_Nested a nested pair must be empty");
   end Nested_Polygons;

   procedure Contact_And_Disjoint (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left_Box   : constant Points :=
        ((X => 0.25, Y => 0.25),
         (X => 1.25, Y => 0.25),
         (X => 1.25, Y => 1.25),
         (X => 0.25, Y => 1.25));
      Right_Box  : constant Points := Translated (Left_Box, 1.0, 0.0);
      Left_Kite  : constant Points :=
        ((X => 0.5, Y => 1.0),
         (X => 1.0, Y => 0.5),
         (X => 1.5, Y => 1.0),
         (X => 1.0, Y => 1.5));
      Right_Kite : constant Points := Translated (Left_Kite, 1.0, 0.0);
      Edge       : constant Intersection := Intersect (Left_Box, Right_Box);
      Corner     : constant Intersection := Intersect (Left_Kite, Right_Kite);
      Apart      : constant Intersection :=
        Intersect (Square, Translated (Square, 10.0, 10.0));
   begin
      AUnit.Assertions.Assert
        (Close (Edge.Area, 0.0)
         and then (for all Vertex of Edge.Vertices => Close (Vertex.X, 1.25)),
         "boxes sharing an edge must meet only on that edge");
      AUnit.Assertions.Assert
        (Close (Corner.Area, 0.0)
         and then (for all Vertex of Corner.Vertices =>
                     Close (Vertex.X, 1.5) and then Close (Vertex.Y, 1.0)),
         "kites touching at a vertex must meet only at that vertex");
      AUnit.Assertions.Assert
        (Apart.Vertex_Count = 0 and then Apart.Area = 0.0,
         "disjoint polygons must have an empty intersection");
   end Contact_And_Disjoint;

   procedure Winding_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Reverse_Left in Boolean loop
         for Reverse_Right in Boolean loop
            declare
               Left  : constant Points :=
                 (if Reverse_Left then Reversed (Square) else Square);
               Right : constant Points :=
                 (if Reverse_Right then Reversed (Diamond) else Diamond);
               Found : constant Intersection := Intersect (Left, Right);
            begin
               AUnit.Assertions.Assert
                 (Same_Vertices (Found.Vertices, Overlap)
                  and then Close (Found.Area, Overlap_Area),
                  "winding must not change the intersection");
            end;
         end loop;
      end loop;
   end Winding_Independent;

   procedure Invalid_Polygons (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Dart      : constant Points :=
        ((X => 0.25, Y => 0.25),
         (X => 2.75, Y => 0.25),
         (X => 1.5, Y => 1.0),
         (X => 2.75, Y => 2.75),
         (X => 0.25, Y => 2.75));
      Bowtie    : constant Points :=
        ((X => 0.25, Y => 0.25),
         (X => 2.75, Y => 2.75),
         (X => 2.75, Y => 0.25),
         (X => 0.25, Y => 2.75));
      Twice     : constant Points := Square & Square;
      Repeated  : constant Points :=
        ((X => 0.25, Y => 0.25),
         (X => 2.75, Y => 0.25),
         (X => 2.75, Y => 0.25),
         (X => 2.75, Y => 2.75),
         (X => 0.25, Y => 2.75));
      Collinear : constant Points :=
        ((X => 0.25, Y => 0.25),
         (X => 1.5, Y => 0.25),
         (X => 2.75, Y => 0.25),
         (X => 2.75, Y => 2.75),
         (X => 0.25, Y => 2.75));
      Segment   : constant Points :=
        ((X => 0.25, Y => 0.25), (X => 2.75, Y => 0.25));
   begin
      AUnit.Assertions.Assert
        (Raises (Dart, Diamond, "convex"), "a concave polygon must raise");
      AUnit.Assertions.Assert
        (Raises (Diamond, Bowtie, "convex"),
         "a self-intersecting polygon must raise");
      AUnit.Assertions.Assert
        (Raises (Twice, Diamond, "convex"), "a repeated traversal must raise");
      AUnit.Assertions.Assert
        (Raises (Repeated, Diamond, "convex"), "a repeated vertex must raise");
      AUnit.Assertions.Assert
        (Raises (Diamond, Collinear, "convex"),
         "a collinear vertex must raise");
      AUnit.Assertions.Assert
        (Raises (Segment, Diamond, "three"),
         "fewer than three vertices must raise");
   end Invalid_Polygons;

   procedure Binary_Grid_Rule (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  0.1 is not a multiple of any power of two at least 2.0**(-8).
      Decimal      : constant Points :=
        ((X => 0.1, Y => 0.1),
         (X => 2.6, Y => 0.1),
         (X => 2.6, Y => 2.6),
         (X => 0.1, Y => 2.6));
      Finest       : constant Points :=
        ((X => 0.00390625, Y => 0.0),
         (X => 1.0, Y => 0.0),
         (X => 1.0, Y => 1.0),
         (X => 0.0, Y => 1.0));
      Too_Fine     : constant Points :=
        ((X => 0.001953125, Y => 0.0),
         (X => 1.0, Y => 0.0),
         (X => 1.0, Y => 1.0),
         (X => 0.0, Y => 1.0));
      --  Multiples of 2.0**6 up to 2.0**29; the grid allows 2.0**30.
      Coarse_Left  : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 2.0**29, Y => 0.0),
         (X => 2.0**29, Y => 2.0**29),
         (X => 0.0, Y => 2.0**29));
      Coarse_Right : constant Points :=
        Translated (Coarse_Left, 2.0**28, 2.0**28);
      Too_Large    : constant Points := Translated (Coarse_Left, 2.0**31, 0.0);
      --  Integers whose joint X span is 2**24 + 1.
      Low          : constant Points :=
        Translated
          (((X => 0.0, Y => 0.0),
            (X => 10.0, Y => 0.0),
            (X => 10.0, Y => 10.0),
            (X => 0.0, Y => 10.0)),
           -8388608.0,
           0.0);
      High         : constant Points := Translated (Low, 16777207.0, 0.0);
      --  Two valid convex triangles near 0.1 for which OpenCV 4.6 and 4.10
      --  emit more vertices than their result region holds and 4.11 and
      --  later report non-convergence.
      Small_Left   : constant Points :=
        ((X => 0.08547630906105042, Y => 0.0527978390455246),
         (X => -0.169072687625885, Y => 0.05880429968237877),
         (X => 0.03679491952061653, Y => -0.029670946300029755));
      Small_Right  : constant Points :=
        ((X => 0.08548733592033386, Y => 0.05277998372912407),
         (X => 0.03678872063755989, Y => -0.02967863157391548),
         (X => -0.16906039416790009, Y => 0.05883961543440819));
      Coarse       : constant Intersection :=
        Intersect (Coarse_Left, Coarse_Right);
   begin
      AUnit.Assertions.Assert
        (Raises (Decimal, Diamond, "binary grid"),
         "decimal fractions such as 0.1 must raise");
      AUnit.Assertions.Assert
        (Intersect (Finest, Translated (Finest, 0.5, 0.5)).Vertex_Count > 0,
         "multiples of 2.0**(-8) must be accepted");
      AUnit.Assertions.Assert
        (Raises (Too_Fine, Diamond, "binary grid"),
         "multiples of only 2.0**(-9) must raise");
      AUnit.Assertions.Assert
        (Close (Coarse.Area / 2.0**56, 1.0),
         "multiples of 2.0**6 up to 2.0**30 must be accepted");
      AUnit.Assertions.Assert
        (Raises (Too_Large, Coarse_Left, "binary grid"),
         "coordinates of 2.0**31 must raise");
      AUnit.Assertions.Assert
        (Raises (Low, High, "spans"),
         "a joint span above 2.0**(24 + K) must raise");
      AUnit.Assertions.Assert
        (Raises (Small_Left, Small_Right, "binary grid"),
         "off-grid polygons that overflow OpenCV 4.6 and 4.10 must raise");
   end Binary_Grid_Rule;

   procedure Even_Grid_Spans (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Multiples of 2.0**7 on the 2.0**6 grid, reaching 2.0**30, with
      --  joint spans of 2.0**31 = 2.0**(25 + 6).
      Outer         : constant Points :=
        ((X => -2.0**30, Y => -2.0**30),
         (X => 2.0**30, Y => -2.0**30),
         (X => 2.0**30, Y => 2.0**30),
         (X => -2.0**30, Y => 2.0**30));
      Quadrant      : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 2.0**30, Y => 0.0),
         (X => 2.0**30, Y => 2.0**30),
         (X => 0.0, Y => 2.0**30));
      Integer_Outer : constant OpenCV.Geometry.Contour :=
        ((X => -2**24, Y => -2**24),
         (X => 2**24, Y => -2**24),
         (X => 2**24, Y => 2**24),
         (X => -2**24, Y => 2**24));
      Integer_Quad  : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 2**24, Y => 0),
         (X => 2**24, Y => 2**24),
         (X => 0, Y => 2**24));
      Found         : constant Intersection := Intersect (Outer, Quadrant);
      Scaled        : constant Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons
          (Integer_Outer, Integer_Quad);
      --  One coordinate off the 2.0**7 grid leaves a 2.0**6 grid joint span
      --  above 2.0**30.
      Odd_Quadrant  : constant Points :=
        ((X => 64.0, Y => 0.0),
         (X => 2.0**30, Y => 0.0),
         (X => 2.0**30, Y => 2.0**30),
         (X => 64.0, Y => 2.0**30));
   begin
      AUnit.Assertions.Assert
        (Found.Area = 2.0**60,
         "coordinates of 2.0**30 must be accepted with their exact area");
      AUnit.Assertions.Assert
        (Found.Vertex_Count = Scaled.Vertex_Count
         and then Found.Area = Scaled.Area * 2.0**12,
         "the Float32 result must be the integer result scaled by 2.0**6");
      for Index in Found.Vertices'Range loop
         AUnit.Assertions.Assert
           (Found.Vertices (Index).X = Scaled.Vertices (Index).X * 2.0**6
            and then Found.Vertices (Index).Y
                     = Scaled.Vertices (Index).Y * 2.0**6,
            "every Float32 vertex must be exactly a scaled integer vertex");
      end loop;
      AUnit.Assertions.Assert
        (Raises (Outer, Odd_Quadrant, "spans"),
         "joint spans above 2.0**30 off the 2.0**7 grid must raise");
   end Even_Grid_Spans;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted_Left  : constant Points (10 .. 13) := Square;
      Shifted_Right : constant Points (Natural'Last - 3 .. Natural'Last) :=
        Diamond;
   begin
      AUnit.Assertions.Assert
        (Intersect (Shifted_Left, Shifted_Right) = Intersect (Square, Diamond),
         "the intersection must not depend on the Ada lower bounds");
   end Nonzero_Bounds;

   procedure Intersect_As_Left (Candidate : Points) is
      Unused : constant Intersection := Intersect (Candidate, Diamond);
      pragma Unreferenced (Unused);
   begin
      null;
   end Intersect_As_Left;

   procedure Intersect_As_Right (Candidate : Points) is
      Unused : constant Intersection := Intersect (Square, Candidate, False);
      pragma Unreferenced (Unused);
   begin
      null;
   end Intersect_As_Right;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (7 .. 10) := Square;
   begin
      Support.Assert_Rejects_Non_Finite
        (Shifted, Intersect_As_Left'Access, "Intersect_Convex_Polygons Left");
      Support.Assert_Rejects_Non_Finite
        (Shifted,
         Intersect_As_Right'Access,
         "Intersect_Convex_Polygons Right");
   end Non_Finite_Rejected;

   procedure Matches_Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left   : aliased C_API.Point_F32_Array := Support.Pack (Square);
      Right  : aliased C_API.Point_F32_Array := Support.Pack (Diamond);
      Output : aliased C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => 0.0, Y => 0.0));
      Count  : aliased Interfaces.Integer_32 := -1;
      Area   : aliased Interfaces.C.C_float := -1.0;
      Status : C_API.Status;
      Found  : constant Intersection := Intersect (Square, Diamond);
   begin
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (Left (Left'First)'Access,
           4,
           Right (Right'First)'Access,
           4,
           1,
           Output (Output'First)'Access,
           Output'Length,
           Count'Access,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Natural (Count) = Found.Vertex_Count
         and then OpenCV.Float32_Value (Area) = Found.Area,
         "raw and public intersections must agree");
      for Offset in 0 .. Found.Vertex_Count - 1 loop
         AUnit.Assertions.Assert
           (OpenCV.Float32_Value (Output (Offset).X)
            = Found.Vertices (1 + Offset).X
            and then OpenCV.Float32_Value (Output (Offset).Y)
                     = Found.Vertices (1 + Offset).Y,
            "the native vertex order must be preserved");
      end loop;
   end Matches_Raw_C_ABI;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left     : aliased C_API.Point_F32_Array := Support.Pack (Square);
      Right    : aliased C_API.Point_F32_Array := Support.Pack (Diamond);
      Tiny     : aliased C_API.Point_F32_Array :=
        ((X => 0.0854763090, Y => 0.0527978390),
         (X => -0.169072688, Y => 0.0588042997),
         (X => 0.0367949195, Y => -0.0296709463));
      Tiny_Too : aliased C_API.Point_F32_Array :=
        ((X => 0.0854873359, Y => 0.0527799837),
         (X => 0.0367887206, Y => -0.0296786316),
         (X => -0.169060394, Y => 0.0588396154));
      Output   : aliased C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => 0.0, Y => 0.0));
      Count    : aliased Interfaces.Integer_32 := 7;
      Area     : aliased Interfaces.C.C_float := 7.0;
      Status   : C_API.Status;
   begin
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (null, 0, null, 0, 0, null, 0, null, Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("count pointer"),
         "a null count output must be rejected");
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (null, -1, null, 0, 0, null, 0, Count'Access, Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("negative")
         and then Count = 0
         and then Area = 0.0,
         "a negative count must be rejected with zero outputs");
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (null, 3, null, 0, 0, null, 0, Count'Access, Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("left polygon"),
         "null left points with positive count must be rejected");
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (Left (Left'First)'Access,
           4,
           Right (Right'First)'Access,
           4,
           2,
           Output (Output'First)'Access,
           8,
           Count'Access,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("nested"),
         "an invalid nested selector must be rejected");
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (Left (Left'First)'Access,
           4,
           Right (Right'First)'Access,
           4,
           1,
           null,
           8,
           Count'Access,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("output vertices"),
         "null output with positive capacity must be rejected");
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (Left (Left'First)'Access,
           4,
           Right (Right'First)'Access,
           4,
           1,
           Output (Output'First)'Access,
           2,
           Count'Access,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("capacity")
         and then Count = 0,
         "insufficient capacity must be rejected unpublished");
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (Tiny (Tiny'First)'Access,
           3,
           Tiny_Too (Tiny_Too'First)'Access,
           3,
           1,
           Output (Output'First)'Access,
           6,
           Count'Access,
           Area'Access);
      if Status = C_API.Error_Invalid_Argument then
         AUnit.Assertions.Assert
           (Has_Message ("version guard") and then Count = 0,
            "before OpenCV 4.11 off-grid polygons must be guarded");
      else
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then Count in 0 .. 6
            and then (if Area < 0.0 then Count = 0),
            "a bounded native result must fit the capacity");
      end if;
   end C_ABI_Validation;

   procedure C_ABI_Version_Guard (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  On the binary grid, but not convex.
      Bowtie   : aliased C_API.Point_F32_Array :=
        ((X => 0.25, Y => 0.25),
         (X => 2.75, Y => 2.75),
         (X => 2.75, Y => 0.25),
         (X => 0.25, Y => 2.75));
      Diamonds : aliased C_API.Point_F32_Array := Support.Pack (Diamond);
      --  On the integer grid, but with a joint X span of 2**24 + 1.
      Low      : aliased C_API.Point_F32_Array :=
        ((X => -8388608.0, Y => 0.0),
         (X => -8388598.0, Y => 0.0),
         (X => -8388598.0, Y => 10.0),
         (X => -8388608.0, Y => 10.0));
      High     : aliased C_API.Point_F32_Array :=
        ((X => 8388599.0, Y => 0.0),
         (X => 8388609.0, Y => 0.0),
         (X => 8388609.0, Y => 10.0),
         (X => 8388599.0, Y => 10.0));
      Output   : aliased C_API.Point_F32_Array (0 .. 11) :=
        (others => (X => 0.0, Y => 0.0));
      Count    : aliased Interfaces.Integer_32 := -1;
      Area     : aliased Interfaces.C.C_float := -1.0;
      Status   : C_API.Status;

      --  Before OpenCV 4.11 the shim must reject the pair whichever caller
      --  validated it; later versions bound the native output.
      procedure Expect_Guard_Or_Bounded (Fragment, Label : String) is
      begin
         if Status = C_API.Error_Invalid_Argument then
            AUnit.Assertions.Assert
              (Has_Message ("version guard")
               and then Has_Message (Fragment)
               and then Count = 0,
               Label & " must be guarded before OpenCV 4.11");
         else
            AUnit.Assertions.Assert
              (Status = C_API.Success
               and then Count in 0 .. 12
               and then (if Area < 0.0 then Count = 0),
               Label & " must give a bounded native result");
         end if;
      end Expect_Guard_Or_Bounded;
   begin
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (Bowtie (Bowtie'First)'Access,
           4,
           Diamonds (Diamonds'First)'Access,
           4,
           1,
           Output (Output'First)'Access,
           12,
           Count'Access,
           Area'Access);
      Expect_Guard_Or_Bounded ("convex", "a raw self-intersecting polygon");
      Count := -1;
      Status :=
        C_API.Intersect_Convex_Convex_F32
          (Low (Low'First)'Access,
           4,
           High (High'First)'Access,
           4,
           1,
           Output (Output'First)'Access,
           12,
           Count'Access,
           Area'Access);
      Expect_Guard_Or_Bounded
        ("differences", "raw polygons with rounded differences");
   end C_ABI_Version_Guard;

   procedure Pure_Limits (Test : in out Fixture) is
      pragma Unreferenced (Test);
      package Limits renames OpenCV.Geometry.Internal.Intersection;
      package Convexity renames OpenCV.Geometry.Internal.Convexity;
      Maximum  : constant Natural := Limits.Maximum_Input_Count;
      --  Even coordinates beyond the public range exercise the helper
      --  independently of Is_Binary32_Exact.
      Left     : constant OpenCV.Geometry.Contour := (1 => (0, 0));
      At_Limit : constant OpenCV.Geometry.Contour := (1 => (2**25, 0));
      Beyond   : constant OpenCV.Geometry.Contour := (1 => (2**25 + 2, 0));
   begin
      AUnit.Assertions.Assert
        (Limits.Is_Safe_Input_Count (Maximum - 3, 3)
         and then Limits.Output_Capacity (Maximum - 3, 3) = Maximum
         and then not Limits.Is_Safe_Input_Count (Maximum - 2, 3)
         and then not Limits.Is_Safe_Input_Count (3, Maximum - 2)
         and then not Limits.Is_Safe_Input_Count (Natural'Last, Natural'Last),
         "combined count boundary must be checked without array allocation");
      AUnit.Assertions.Assert
        (Limits.Has_Exact_Differences
           (Left,
            At_Limit,
            Convexity.Bounds_Of (Left),
            Convexity.Bounds_Of (At_Limit))
         and then not Limits.Has_Exact_Differences
                        (Left,
                         Beyond,
                         Convexity.Bounds_Of (Left),
                         Convexity.Bounds_Of (Beyond)),
         "even differences need their own explicit 2**25 span bound");
   end Pure_Limits;

   procedure Minimum_Orientation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Step     : constant := 2.0**(-8);
      Triangle : constant Points := ((0.0, 0.0), (Step, 0.0), (0.0, Step));
      --  A second convex polygon shares the triangle's hypotenuse.
      --  Native predicates see Step**2 = 2**(-16) > 1.0E-5.
      Other    : constant Points :=
        ((0.0, -Step), (Step, 0.0), (0.0, Step), (-Step, 0.0));
      Found    : constant Intersection := Intersect (Triangle, Other);
   begin
      AUnit.Assertions.Assert
        (Found.Area = 2.0**(-17)
         and then Same_Vertices (Found.Vertices, Triangle),
         "K=-8 minimum determinant must remain above native tolerance");
   end Minimum_Orientation;

   procedure Coarse_Nested_Second (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Outer : constant Points :=
        ((-2.0**30, -2.0**30),
         (2.0**30, -2.0**30),
         (2.0**30, 2.0**30),
         (-2.0**30, 2.0**30));
      Inner : constant Points :=
        ((2.0**30 - 256.0, 2.0**30 - 256.0),
         (2.0**30 - 128.0, 2.0**30 - 256.0),
         (2.0**30 - 128.0, 2.0**30 - 128.0),
         (2.0**30 - 256.0, 2.0**30 - 128.0));
      Found : constant Intersection := Intersect (Inner, Outer);
   begin
      AUnit.Assertions.Assert
        (Found.Area = 2.0**14 and then Same_Vertices (Found.Vertices, Inner),
         "nested K=6 with outer second must safely round near 2**30");
   end Coarse_Nested_Second;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection fractional overlap",
            Fractional_Overlap'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection is an exact integer scaling",
            Exact_Integer_Scaling'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection equals integer overload",
            Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection nested polygons", Nested_Polygons'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection contact and disjoint",
            Contact_And_Disjoint'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection winding independent",
            Winding_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection invalid polygons", Invalid_Polygons'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection binary grid rule", Binary_Grid_Rule'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection even grid spans", Even_Grid_Spans'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection nonzero bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection rejects non-finite coordinates",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection matches raw C ABI",
            Matches_Raw_C_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection C ABI validation", C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection C ABI version guard",
            C_ABI_Version_Guard'Access));
      Result.Add_Test
        (Caller.Create
           ("Intersection pure count and span limits", Pure_Limits'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection minimum K=-8 orientation",
            Minimum_Orientation'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 intersection K=6 nested outer second",
            Coarse_Nested_Second'Access));
      return Result'Access;
   end Suite;

end Float32_Convex_Intersection_Tests;
