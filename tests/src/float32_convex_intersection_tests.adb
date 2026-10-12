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

   --  ---------------------------------------------------------------
   --  Intersect_Convex_Polygons_Extended_Float32 (Task 027B)
   --  ---------------------------------------------------------------

   function Extended
     (Left, Right : Points; Nested : Boolean := True) return Intersection
   is (OpenCV.Geometry.Intersect_Convex_Polygons_Extended_Float32
         (Left, Right, Nested));

   --  Relative comparison with a small absolute floor.
   function Near
     (Actual, Expected : OpenCV.Float32_Value;
      Relative         : OpenCV.Float32_Value := 1.0E-4) return Boolean
   is (abs (Actual - Expected) <= Relative * abs Expected + 1.0E-6);

   function Box (X, Y, Side : OpenCV.Float32_Value) return Points
   is ((X => X, Y => Y),
       (X => X + Side, Y => Y),
       (X => X + Side, Y => Y + Side),
       (X => X, Y => Y + Side));

   --  True when the extended function raises OpenCV_Error. Any other
   --  exception, notably Constraint_Error, propagates and fails the test.
   function Ext_Rejects
     (Left, Right : Points; Nested : Boolean := True) return Boolean is
   begin
      declare
         Unused : constant Intersection := Extended (Left, Right, Nested);
         pragma Unreferenced (Unused);
      begin
         return False;
      end;
   exception
      when OpenCV.OpenCV_Error =>
         return True;
   end Ext_Rejects;

   Tri_A       : constant Points :=
     ((X => 0.1, Y => 0.1), (X => 4.3, Y => 0.2), (X => 2.1, Y => 3.9));
   Tri_B       : constant Points :=
     ((X => 0.7, Y => -0.5), (X => 3.9, Y => 2.2), (X => -0.4, Y => 2.8));
   Tri_Overlap : constant Points :=
     ((X => 0.344897956, Y => 0.565306127),
      (X => 0.496850371, Y => 0.10944882),
      (X => 1.44918334, Y => 0.132123411),
      (X => 3.3744657, Y => 1.75658047),
      (X => 3.03941059, Y => 2.32008219),
      (X => 1.38962364, Y => 2.5502851));

   --  The recovered rounded integer hexagons (Exact_Difference_Spans), as
   --  binary32 points, and the 12 vertices the private engine returns.
   Hexagon_Left   : constant Points :=
     ((X => -15767146.0, Y => -1608888.0),
      (X => -2320318.0, Y => -15678251.0),
      (X => 15750659.0, Y => 1762998.0),
      (X => 15604050.0, Y => 2775796.0),
      (X => 13860112.0, Y => 7686919.0),
      (X => -4538847.0, Y => 15185200.0));
   Hexagon_Right  : constant Points :=
     ((X => -15767147.0, Y => -1608887.0),
      (X => -2320318.0, Y => -15678249.0),
      (X => 15750662.0, Y => 1762996.0),
      (X => 15604050.0, Y => 2775793.0),
      (X => 13860114.0, Y => 7686922.0),
      (X => -4538847.0, Y => 15185197.0));
   Hexagon_Result : constant Points :=
     ((X => -10668174.0, Y => 6017608.5),
      (X => -15767146.0, Y => -1608888.0),
      (X => -15462922.0, Y => -1927196.75),
      (X => -2320318.0, Y => -15678249.0),
      (X => 2921097.75, Y => -10619485.0),
      (X => 15750659.0, Y => 1762998.0),
      (X => 15624296.0, Y => 2635932.75),
      (X => 15604050.0, Y => 2775793.0),
      (X => 15154281.0, Y => 4042394.25),
      (X => 13860112.0, Y => 7686919.0),
      (X => 3560384.5, Y => 11884453.0),
      (X => -4538847.0, Y => 15185197.0));

   procedure Ext_Fractional_Overlaps (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Found   : constant Intersection := Extended (Tri_A, Tri_B);
      Left    : constant Points := Box (0.3, 0.2, 2.3);
      Right   : constant Points := Box (1.0, 0.65, 2.3);
      Squares : constant Intersection := Extended (Left, Right);
      Tenths  : constant Intersection :=
        Extended (Box (0.1, 0.1, 0.3), Box (0.2, 0.2, 0.3));
   begin
      AUnit.Assertions.Assert
        (Raises (Tri_A, Tri_B, "binary grid"),
         "the original Float32 overload must still reject off-grid input");
      AUnit.Assertions.Assert
        (Found.Vertex_Count = 6
         and then Same_Vertices (Found.Vertices, Tri_Overlap)
         and then Near (Found.Area, 4.3435187)
         and then Found.Vertices'First = 1,
         "fractional triangles must intersect in the expected hexagon");
      AUnit.Assertions.Assert
        (Squares.Vertex_Count = 4 and then Near (Squares.Area, 2.96),
         "fractional squares must intersect in a 1.6 by 1.85 rectangle");
      AUnit.Assertions.Assert
        (Tenths.Vertex_Count = 4
         and then Same_Vertices (Tenths.Vertices, Box (0.2, 0.2, 0.2))
         and then Near (Tenths.Area, 0.04),
         "squares near 0.1 must intersect in a 0.2 square");
   end Ext_Fractional_Overlaps;

   procedure Ext_Integer_And_Grid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left  : constant Points := Support.To_Float32 (Integer_Square);
      Right : constant Points := Support.To_Float32 (Integer_Diamond);
   begin
      for Nested in Boolean loop
         AUnit.Assertions.Assert
           (Extended (Left, Right, Nested).Area
            = Intersect (Left, Right, Nested).Area
            and then Same_Vertices
                       (Extended (Left, Right, Nested).Vertices,
                        Intersect (Left, Right, Nested).Vertices),
            "integer-valued polygons must match the grid-restricted "
            & "overload");
      end loop;
      AUnit.Assertions.Assert
        (Same_Vertices (Extended (Square, Diamond).Vertices, Overlap)
         and then Close (Extended (Square, Diamond).Area, Overlap_Area),
         "power-of-two-grid polygons must give the known overlap");
   end Ext_Integer_And_Grid_Inputs;

   procedure Ext_Winding_And_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Base       : constant Intersection := Extended (Tri_A, Tri_B);
      Shift_A    : constant Points (10 .. 12) := Tri_A;
      Shift_B    : constant Points (Natural'Last - 2 .. Natural'Last) := Tri_B;
      Reversed_A : constant Points := Reversed (Tri_A);
      Reversed_B : constant Points := Reversed (Tri_B);
   begin
      for Left_Reversed in Boolean loop
         for Right_Reversed in Boolean loop
            declare
               Found : constant Intersection :=
                 Extended
                   ((if Left_Reversed then Reversed_A else Tri_A),
                    (if Right_Reversed then Reversed_B else Tri_B));
            begin
               AUnit.Assertions.Assert
                 (Found.Vertex_Count = 6
                  and then Same_Vertices (Found.Vertices, Tri_Overlap)
                  and then Near (Found.Area, Base.Area),
                  "every winding combination must give the same polygon");
            end;
         end loop;
      end loop;
      AUnit.Assertions.Assert
        (Extended (Shift_A, Shift_B) = Base,
         "differing nonzero lower bounds must not change the result");
   end Ext_Winding_And_Bounds;

   procedure Ext_Nested_Disjoint_Contact (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Outer    : constant Points := Box (0.0, 0.0, 10.0);
      Inner_P  : constant Points := Box (2.3, 2.3, 3.1);
      Nested   : constant Intersection := Extended (Outer, Inner_P, True);
      Swapped  : constant Intersection := Extended (Inner_P, Outer, True);
      Unneeded : constant Intersection := Extended (Outer, Inner_P, False);
      Apart    : constant Intersection :=
        Extended (Box (0.0, 0.0, 1.0), Box (5.1, 5.1, 1.0));
      Edge     : constant Intersection :=
        Extended (Box (0.0, 0.0, 1.0), Box (1.0, 0.0, 1.0));
      Corner   : constant Intersection :=
        Extended (Box (0.0, 0.0, 1.0), Box (1.0, 1.0, 1.0));
   begin
      AUnit.Assertions.Assert
        (Nested.Vertex_Count = 4
         and then Same_Vertices (Nested.Vertices, Inner_P)
         and then Near (Nested.Area, 9.61)
         and then Swapped.Vertex_Count = 4
         and then Near (Swapped.Area, 9.61),
         "nested polygons with Handle_Nested True give the inner polygon");
      AUnit.Assertions.Assert
        (Unneeded.Vertex_Count = 0 and then Unneeded.Area = 0.0,
         "nested polygons with Handle_Nested False give an empty result");
      AUnit.Assertions.Assert
        (Apart.Vertex_Count = 0 and then Apart.Area = 0.0,
         "disjoint polygons give an empty result");
      --  Contact results are raw contact points, not a polygon.
      AUnit.Assertions.Assert
        (Edge.Area = 0.0 and then Edge.Vertex_Count in 1 .. 3,
         "shared-edge contact gives one to three vertices and zero area");
      AUnit.Assertions.Assert
        (Corner.Area = 0.0 and then Corner.Vertex_Count in 0 .. 3,
         "vertex-only contact gives at most three vertices and zero area");
   end Ext_Nested_Disjoint_Contact;

   procedure Ext_Qualified_Shapes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A thin but well-conditioned convex sliver: 100 by 0.01.
      Thin      : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 100.0, Y => 0.0),
         (X => 100.0, Y => 0.01),
         (X => 0.0, Y => 0.01));
      Thin_Hit  : constant Points :=
        ((X => 40.0, Y => -1.0),
         (X => 60.0, Y => -1.0),
         (X => 60.0, Y => 1.0),
         (X => 40.0, Y => 1.0));
      Thin_Out  : constant Intersection := Extended (Thin, Thin_Hit);
      Big_Left  : constant Points := Box (5.0E8, 5.0E8, 1048576.0);
      Big_Right : constant Points := Box (5.0E8 + 524288.0, 5.0E8, 1048576.0);
      Big_Out   : constant Intersection := Extended (Big_Left, Big_Right);
   begin
      AUnit.Assertions.Assert
        (Thin_Out.Vertex_Count = 4 and then Near (Thin_Out.Area, 0.2),
         "a thin qualified sliver must intersect in a 20 by 0.01 strip");
      AUnit.Assertions.Assert
        (Big_Out.Vertex_Count = 4
         and then Near (Big_Out.Area, 524288.0 * 1048576.0),
         "large coordinates below 2.0**30 must intersect");
   end Ext_Qualified_Shapes;

   procedure Ext_Recovered_Hexagon (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Found : constant Intersection := Extended (Hexagon_Left, Hexagon_Right);
   begin
      AUnit.Assertions.Assert
        (Found.Vertex_Count = 12
         and then Found.Vertices = Hexagon_Result
         and then Near (Found.Area, 5.38046559E14, 1.0E-5),
         "the recovered rounded hexagons give the known 12 vertices");
   end Ext_Recovered_Hexagon;

   procedure Ext_Invalid_Shapes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty     : constant Points (1 .. 0) := (others => (X => 0.0, Y => 0.0));
      Good      : constant Points := Box (0.0, 0.0, 1.0);
      Star      : constant Points :=
        ((X => 0.0, Y => 3.0),
         (X => 1.0, Y => 1.0),
         (X => 3.0, Y => 0.0),
         (X => 1.0, Y => -1.0),
         (X => 0.0, Y => -3.0),
         (X => -1.0, Y => -1.0),
         (X => -3.0, Y => 0.0),
         (X => -1.0, Y => 1.0));
      Pentagram : constant Points :=
        ((X => 0.0, Y => 4.0),
         (X => 2.35, Y => -3.24),
         (X => -3.80, Y => 1.24),
         (X => 3.80, Y => 1.24),
         (X => -2.35, Y => -3.24));
   begin
      AUnit.Assertions.Assert
        (Ext_Rejects (Empty, Good) and then Ext_Rejects (Good, Empty),
         "an empty polygon must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects (Good (1 .. 1), Good)
         and then Ext_Rejects (Good, Good (1 .. 2)),
         "one- and two-vertex polygons must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects
           (((X => 0.0, Y => 0.0),
             (X => 2.0, Y => 0.0),
             (X => 2.0, Y => 0.0),
             (X => 1.0, Y => 1.0)),
            Good),
         "duplicate vertices must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects
           (((X => 0.0, Y => 0.0),
             (X => 1.0, Y => 0.0),
             (X => 2.0, Y => 0.0),
             (X => 1.0, Y => 1.0)),
            Good),
         "a redundant collinear vertex must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects
           (((X => 0.0, Y => 0.0),
             (X => 4.0, Y => 0.0),
             (X => 1.0, Y => 1.0),
             (X => 0.0, Y => 4.0)),
            Good),
         "a concave polygon must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects
           (((X => 0.0, Y => 0.0),
             (X => 2.0, Y => 2.0),
             (X => 2.0, Y => 0.0),
             (X => 0.0, Y => 2.0)),
            Good),
         "a bowtie must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects (Star, Good)
         and then Ext_Rejects (Good, Star)
         and then Ext_Rejects (Pentagram, Good),
         "self-intersecting stars must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects (Good & Good, Good)
         and then Ext_Rejects (Good, Good & Good),
         "a repeated contour traversal must be rejected");
   end Ext_Invalid_Shapes;

   procedure Ext_Left_As_Candidate (Candidate : Points) is
      Unused : constant Intersection := Extended (Candidate, Diamond);
      pragma Unreferenced (Unused);
   begin
      null;
   end Ext_Left_As_Candidate;

   procedure Ext_Right_As_Candidate (Candidate : Points) is
      Unused : constant Intersection := Extended (Square, Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Ext_Right_As_Candidate;

   procedure Ext_Non_Finite_And_Envelope (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Good         : constant Points := Box (0.0, 0.0, 1.0);
      --  Binary32 spacing near 2.0**30 is 128, so use sides of 256 and more.
      Over         : constant Points := Box (2.0**30, 0.0, 256.0);
      --  Maximum X is exactly 2.0**30, the accepted limit.
      Edge         : constant Points := Box (2.0**30 - 512.0, 0.0, 512.0);
      Edge_Partner : constant Points := Box (2.0**30 - 768.0, 256.0, 512.0);
      Neg          : constant Points := Box (-(2.0**30) - 128.0, 0.0, 256.0);
   begin
      Support.Assert_Rejects_Non_Finite
        (Square, Ext_Left_As_Candidate'Access, "Extended Left");
      Support.Assert_Rejects_Non_Finite
        (Square, Ext_Right_As_Candidate'Access, "Extended Right");
      AUnit.Assertions.Assert
        (Ext_Rejects (Over, Good) and then Ext_Rejects (Good, Neg),
         "coordinates beyond 2.0**30 must be rejected");
      AUnit.Assertions.Assert
        (not Ext_Rejects (Edge, Edge_Partner),
         "coordinates at 2.0**30 must be accepted");
   end Ext_Non_Finite_And_Envelope;

   procedure Ext_Ill_Conditioned (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Good : constant Points := Box (0.0, 0.0, 1.0);
      --  Features far below OpenCV's 1.0E-5 absolute tolerance: a square of
      --  side 1.0E-3 has orientations of about 1.0E-6.
      Tiny : constant Points := Box (0.0, 0.0, 1.0E-3);
      --  Nearly collinear: the apex is 1.0E-6 off a 100-long base.
      Flat : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 100.0, Y => 0.0),
         (X => 50.0, Y => 1.0E-6));
   begin
      AUnit.Assertions.Assert
        (Ext_Rejects (Tiny, Good) and then Ext_Rejects (Good, Tiny),
         "a polygon below the conditioning limit must be rejected");
      AUnit.Assertions.Assert
        (Ext_Rejects (Flat, Good),
         "a numerically ambiguous near-collinear polygon is rejected");
   end Ext_Ill_Conditioned;

   procedure Ext_Count_Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  4097 vertices exceeds the validator's documented limit of 4096.
      Many : Points (1 .. 4097);
      Good : constant Points := Box (0.0, 0.0, 1.0);
   begin
      for Index in Many'Range loop
         Many (Index) := (X => OpenCV.Float32_Value (Index), Y => 0.0);
      end loop;
      AUnit.Assertions.Assert
        (Ext_Rejects (Many, Good) and then Ext_Rejects (Good, Many),
         "more than 4096 vertices must be rejected");
   end Ext_Count_Rejection;

   --  Raw C ABI of opencv_geometry_intersect_convex_convex_extended_f32.
   procedure Ext_C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left   : aliased C_API.Point_F32_Array :=
        Support.Pack (Box (0.0, 0.0, 1.0));
      Right  : aliased C_API.Point_F32_Array :=
        Support.Pack (Box (0.5, 0.25, 1.0));
      Guard  : constant C_API.Point_F32 := (X => -7.0, Y => -9.0);
      Output : aliased C_API.Point_F32_Array (0 .. 15) := (others => Guard);
      Count  : aliased Interfaces.Integer_32 := 99;
      Area   : aliased Interfaces.C.C_float := 99.0;
      Status : C_API.Status;

      --  True when no element of Output changed.
      function Untouched return Boolean
      is (for all Item of Output =>
            Item.X = Guard.X and then Item.Y = Guard.Y);

      procedure Reset is
      begin
         Output := (others => Guard);
         Count := 99;
         Area := 99.0;
      end Reset;

      function Call
        (Left_Count, Right_Count : Interfaces.Integer_32;
         Nested                  : Interfaces.Integer_32 := 1;
         Capacity                : Interfaces.Integer_32 := 8)
         return C_API.Status
      is (C_API.Intersect_Convex_Convex_Extended_F32
            (Left (Left'First)'Access,
             Left_Count,
             Right (Right'First)'Access,
             Right_Count,
             Nested,
             Output (Output'First)'Access,
             Capacity,
             Count'Access,
             Area'Access));

      procedure Expect_Invalid (Fragment, Message : String) is
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Has_Message (Fragment)
            and then Count = 0
            and then Area = 0.0
            and then Untouched,
            Message);
      end Expect_Invalid;
   begin
      Reset;
      Status :=
        C_API.Intersect_Convex_Convex_Extended_F32
          (Left (Left'First)'Access,
           4,
           Right (Right'First)'Access,
           4,
           1,
           Output (Output'First)'Access,
           8,
           null,
           Area'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("output count")
         and then Untouched,
         "a null output count pointer must be rejected");
      Reset;
      Status :=
        C_API.Intersect_Convex_Convex_Extended_F32
          (Left (Left'First)'Access,
           4,
           Right (Right'First)'Access,
           4,
           1,
           Output (Output'First)'Access,
           8,
           Count'Access,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("output area")
         and then Count = 0
         and then Untouched,
         "a null output area pointer must be rejected, count reset");
      Reset;
      Status := Call (-1, 4);
      Expect_Invalid ("negative", "a negative left count must be rejected");
      Reset;
      Status := Call (4, -1);
      Expect_Invalid ("negative", "a negative right count must be rejected");
      Reset;
      Status := Call (2, 4);
      Expect_Invalid ("three vertices", "two left vertices are rejected");
      Reset;
      Status := Call (4, 0);
      Expect_Invalid ("three vertices", "an empty right polygon is rejected");
      Reset;
      Status := Call (4, 4, Nested => 2);
      Expect_Invalid ("nested", "an invalid nested selector is rejected");
      Reset;
      Status := Call (4, 4, Capacity => -1);
      Expect_Invalid ("capacity", "a negative capacity is rejected");
      Reset;
      Status := Call (4097, 4);
      Expect_Invalid ("4096", "more than 4096 vertices are rejected");
      Reset;
      Status := Call (Interfaces.Integer_32'Last, Interfaces.Integer_32'Last);
      Expect_Invalid ("4096", "overflowing combined counts are rejected");
      Reset;
      Status :=
        C_API.Intersect_Convex_Convex_Extended_F32
          (null,
           4,
           Right (Right'First)'Access,
           4,
           1,
           Output (Output'First)'Access,
           8,
           Count'Access,
           Area'Access);
      Expect_Invalid ("left polygon", "null left points are rejected");
      Reset;
      Status :=
        C_API.Intersect_Convex_Convex_Extended_F32
          (Left (Left'First)'Access,
           4,
           null,
           4,
           1,
           Output (Output'First)'Access,
           8,
           Count'Access,
           Area'Access);
      Expect_Invalid ("right polygon", "null right points are rejected");
      Reset;
      Status :=
        C_API.Intersect_Convex_Convex_Extended_F32
          (Left (Left'First)'Access,
           4,
           Right (Right'First)'Access,
           4,
           1,
           null,
           8,
           Count'Access,
           Area'Access);
      Expect_Invalid
        ("output vertices", "a null output with capacity is rejected");
      --  Polygon content, checked by the C++ layer for direct C callers.
      declare
         Concave   : aliased C_API.Point_F32_Array :=
           ((X => 0.0, Y => 0.0),
            (X => 4.0, Y => 0.0),
            (X => 1.0, Y => 1.0),
            (X => 0.0, Y => 4.0));
         Repeated  : aliased C_API.Point_F32_Array :=
           ((X => 0.0, Y => 0.0),
            (X => 2.0, Y => 0.0),
            (X => 2.0, Y => 0.0),
            (X => 1.0, Y => 1.0));
         Bowtie    : aliased C_API.Point_F32_Array :=
           ((X => 0.0, Y => 0.0),
            (X => 2.0, Y => 2.0),
            (X => 2.0, Y => 0.0),
            (X => 0.0, Y => 2.0));
         Twice     : aliased C_API.Point_F32_Array :=
           Support.Pack (Box (0.0, 0.0, 1.0) & Box (0.0, 0.0, 1.0));
         Not_A_Num : aliased C_API.Point_F32_Array :=
           ((X => 0.0, Y => 0.0),
            (X => Support.NaN_C, Y => 0.0),
            (X => 1.0, Y => 1.0),
            (X => 0.0, Y => 1.0));
         Infinite  : aliased C_API.Point_F32_Array :=
           ((X => 0.0, Y => 0.0),
            (X => 1.0, Y => 0.0),
            (X => 1.0, Y => Interfaces.C.C_float'Last),
            (X => 0.0, Y => 1.0));
         Too_Big   : aliased C_API.Point_F32_Array :=
           ((X => 2.0**31, Y => 0.0),
            (X => 2.0**31 + 256.0, Y => 0.0),
            (X => 2.0**31 + 256.0, Y => 256.0),
            (X => 2.0**31, Y => 256.0));

         procedure Try
           (Candidate : in out C_API.Point_F32_Array;
            Count_In  : Interfaces.Integer_32;
            Fragment  : String;
            Message   : String) is
         begin
            Reset;
            Status :=
              C_API.Intersect_Convex_Convex_Extended_F32
                (Candidate (Candidate'First)'Access,
                 Count_In,
                 Right (Right'First)'Access,
                 4,
                 1,
                 Output (Output'First)'Access,
                 8,
                 Count'Access,
                 Area'Access);
            Expect_Invalid (Fragment, Message);
         end Try;
      begin
         Try (Concave, 4, "left polygon", "a concave polygon is rejected");
         Try (Repeated, 4, "left polygon", "a repeated vertex is rejected");
         Try (Bowtie, 4, "left polygon", "a bowtie is rejected");
         Try (Twice, 8, "left polygon", "a repeated traversal is rejected");
         Try (Not_A_Num, 4, "finite", "a NaN coordinate is rejected");
         Try (Too_Big, 4, "2**30", "an out-of-envelope polygon is rejected");
         --  FLT_MAX is finite but far outside the envelope.
         Try (Infinite, 4, "2**30", "FLT_MAX coordinates are rejected");
      end;
      --  Valid input and the output-capacity boundary. Right overlaps Left
      --  in the 0.5 by 0.75 rectangle (0.5 .. 1.0, 0.25 .. 1.0), 4 vertices.
      Reset;
      Status := Call (4, 4);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Count = 4
         and then abs (Area - 0.375) <= 1.0E-6
         and then (for all Index in 4 .. 15 =>
                     Output (Index).X = Guard.X
                     and then Output (Index).Y = Guard.Y),
         "a valid call publishes 4 vertices and area 0.375 and writes "
         & "nothing beyond them");
      --  Capacity exactly 4 succeeds; 3 fails unpublished, writing nothing.
      Reset;
      Status := Call (4, 4, Capacity => 4);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Count = 4
         and then (for all Index in 4 .. 15 => Output (Index).X = Guard.X),
         "capacity equal to the result count succeeds");
      Reset;
      Status := Call (4, 4, Capacity => 3);
      Expect_Invalid
        ("capacity", "capacity below the result count is rejected");
      Reset;
      Status := Call (4, 4, Capacity => 0);
      Expect_Invalid ("capacity", "zero capacity cannot hold the result");
      --  Disjoint input needs no capacity: zero capacity is enough.
      declare
         Far : aliased C_API.Point_F32_Array :=
           Support.Pack (Box (10.0, 10.0, 1.0));
      begin
         Reset;
         Status :=
           C_API.Intersect_Convex_Convex_Extended_F32
             (Left (Left'First)'Access,
              4,
              Far (Far'First)'Access,
              4,
              1,
              null,
              0,
              Count'Access,
              Area'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success and then Count = 0 and then Area = 0.0,
            "a disjoint pair succeeds with a null buffer and zero capacity");
      end;
   end Ext_C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection fractional overlaps",
            Ext_Fractional_Overlaps'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection integer and grid inputs",
            Ext_Integer_And_Grid_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection winding and lower bounds",
            Ext_Winding_And_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection nested disjoint contact",
            Ext_Nested_Disjoint_Contact'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection qualified shapes",
            Ext_Qualified_Shapes'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection recovered hexagon",
            Ext_Recovered_Hexagon'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection invalid shapes",
            Ext_Invalid_Shapes'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection non-finite and envelope",
            Ext_Non_Finite_And_Envelope'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection ill-conditioned",
            Ext_Ill_Conditioned'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection vertex count limit",
            Ext_Count_Rejection'Access));
      Result.Add_Test
        (Caller.Create
           ("Extended Float32 intersection raw C ABI",
            Ext_C_ABI_Validation'Access));
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
