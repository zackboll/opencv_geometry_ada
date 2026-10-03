with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Float32_Test_Support;
with Interfaces;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Float32_Convex_Hull_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Geometry.Float32_Point_Array;

   subtype Points is Support.Points;
   subtype Indices is OpenCV.Geometry.Point_Index_Array;

   Counterclockwise : constant OpenCV.Geometry.Hull_Orientation :=
     OpenCV.Geometry.Counterclockwise;
   Clockwise        : constant OpenCV.Geometry.Hull_Orientation :=
     OpenCV.Geometry.Clockwise;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  A fractional convex pentagon with interior points interleaved.
   Pentagon : constant Points :=
     ((X => 0.5, Y => 0.25),
      (X => 4.75, Y => 0.5),
      (X => 5.25, Y => 3.5),
      (X => 2.25, Y => 4.75),
      (X => -0.5, Y => 2.0));

   Scattered : constant Points :=
     ((X => 0.5, Y => 0.25),
      (X => 2.5, Y => 2.25),
      (X => 4.75, Y => 0.5),
      (X => 1.75, Y => 1.5),
      (X => 5.25, Y => 3.5),
      (X => 2.25, Y => 4.75),
      (X => 3.5, Y => 3.0),
      (X => -0.5, Y => 2.0));

   --  An integer set with interior points and no collinear hull vertices.
   Integer_Set : constant OpenCV.Geometry.Contour :=
     ((X => -3, Y => 1),
      (X => 2, Y => 3),
      (X => 5, Y => -2),
      (X => 1, Y => 1),
      (X => 9, Y => 4),
      (X => 2, Y => 8),
      (X => 4, Y => 5),
      (X => -1, Y => 6));

   function Points_At (Source : Points; Hull : Indices) return Points is
      Result : Points (Hull'Range);
   begin
      for Position in Hull'Range loop
         Result (Position) := Source (Hull (Position));
      end loop;
      return Result;
   end Points_At;

   function All_In_Range (Source : Points; Hull : Indices) return Boolean
   is (for all Index of Hull => Index in Source'Range);

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Hull (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hull : constant Points := OpenCV.Geometry.Convex_Hull (Scattered);
      --  A hull vertex only because it lies below the X axis; rounding
      --  makes it collinear with its neighbors.
      Kite : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 1.0, Y => -0.375),
         (X => 2.0, Y => 0.0),
         (X => 1.0, Y => 2.0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convex_Hull_Indices (Kite)'Length = 4
         and then OpenCV.Geometry.Convex_Hull_Indices
                    (Support.Rounded (Kite))'Length
                  = 3,
         "hull indices must keep a vertex that rounding would flatten");
      AUnit.Assertions.Assert
        (Support.Same_Vertex_Set (Hull, Pentagon),
         "the hull must be exactly the fractional pentagon vertices");
      AUnit.Assertions.Assert
        (Hull'First = 0 and then Hull'Length = 5,
         "a Float32 hull must be zero-based like the integer result");
      AUnit.Assertions.Assert
        (Support.Contains_Point (Hull, (X => 0.5, Y => 0.25))
         and then Support.Contains_Point (Hull, (X => 2.25, Y => 4.75)),
         "hull vertices must be the unrounded input coordinates");
   end Fractional_Hull;

   procedure Orientation_Convention (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Forward  : constant Points :=
        OpenCV.Geometry.Convex_Hull (Scattered, Counterclockwise);
      Backward : constant Points :=
        OpenCV.Geometry.Convex_Hull (Scattered, Clockwise);
      Integer  : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Contour_Area
          (OpenCV.Geometry.Convex_Hull (Integer_Set, Counterclockwise),
           Oriented => True);
      Area     : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Contour_Area (Forward, Oriented => True);
   begin
      AUnit.Assertions.Assert
        (Support.Same_Vertex_Set (Forward, Backward),
         "both orientations must keep the same vertices");
      AUnit.Assertions.Assert
        (Area = -OpenCV.Geometry.Contour_Area (Backward, Oriented => True)
         and then Area /= 0.0,
         "the two orientations must have opposite oriented areas");
      AUnit.Assertions.Assert
        ((Area > 0.0) = (Integer > 0.0),
         "Float32 orientation must follow the integer convention");
   end Orientation_Convention;

   procedure Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Converted : constant Points := Support.To_Float32 (Integer_Set);
   begin
      for Orientation in OpenCV.Geometry.Hull_Orientation loop
         AUnit.Assertions.Assert
           (Support.Same_Cyclic_Order
              (OpenCV.Geometry.Convex_Hull (Converted, Orientation),
               Support.To_Float32
                 (OpenCV.Geometry.Convex_Hull (Integer_Set, Orientation))),
            "integer-valued Float32 hull must equal the integer hull for "
            & Orientation'Image);
         AUnit.Assertions.Assert
           (Support.Same_Cyclic_Order
              (Points_At
                 (Converted,
                  OpenCV.Geometry.Convex_Hull_Indices
                    (Converted, Orientation)),
               Points_At
                 (Converted,
                  OpenCV.Geometry.Convex_Hull_Indices
                    (Integer_Set, Orientation))),
            "integer-valued Float32 hull indices must select the integer "
            & "hull for "
            & Orientation'Image);
      end loop;
   end Integer_Equivalence;

   procedure Indices_Preserve_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (100 .. 107) := Scattered;
      Late    : constant Points (Natural'Last - 7 .. Natural'Last) :=
        Scattered;
   begin
      for Orientation in OpenCV.Geometry.Hull_Orientation loop
         declare
            Hull      : constant Indices :=
              OpenCV.Geometry.Convex_Hull_Indices (Shifted, Orientation);
            Late_Hull : constant Indices :=
              OpenCV.Geometry.Convex_Hull_Indices (Late, Orientation);
         begin
            AUnit.Assertions.Assert
              (All_In_Range (Shifted, Hull)
               and then All_In_Range (Late, Late_Hull),
               "hull indices must lie in Points'Range");
            AUnit.Assertions.Assert
              (Hull'First = 0 and then Hull'Length = 5,
               "hull indices must be zero-based, one per hull vertex");
            AUnit.Assertions.Assert
              (Support.Same_Cyclic_Order
                 (Points_At (Shifted, Hull),
                  OpenCV.Geometry.Convex_Hull (Shifted, Orientation))
               and then Support.Same_Cyclic_Order
                          (Points_At (Late, Late_Hull),
                           OpenCV.Geometry.Convex_Hull (Late, Orientation)),
               "indices must select the hull points in hull order");
         end;
      end loop;
   end Indices_Preserve_Bounds;

   procedure Small_And_Degenerate (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty     : constant Points (1 .. 0) := (others => (0.0, 0.0));
      One       : constant Points := (0 => (X => 1.25, Y => -0.5));
      Two       : constant Points :=
        ((X => 1.25, Y => -0.5), (X => -2.75, Y => 3.5));
      Collinear : constant Points :=
        ((X => 0.5, Y => 0.5),
         (X => 2.5, Y => 2.5),
         (X => 1.5, Y => 1.5),
         (X => 3.5, Y => 3.5));
      Hull      : constant Points := OpenCV.Geometry.Convex_Hull (Collinear);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convex_Hull (Empty)'Length = 0
         and then OpenCV.Geometry.Convex_Hull (Empty)'First = 1
         and then OpenCV.Geometry.Convex_Hull_Indices (Empty)'Length = 0,
         "empty input must give the null range 1 .. 0");
      AUnit.Assertions.Assert
        (Support.Same_Vertex_Set (OpenCV.Geometry.Convex_Hull (One), One)
         and then Support.Same_Vertex_Set
                    (OpenCV.Geometry.Convex_Hull (Two), Two),
         "one- and two-point hulls are their points");
      AUnit.Assertions.Assert
        (Hull'Length = 2
         and then Support.Contains_Point (Hull, (X => 0.5, Y => 0.5))
         and then Support.Contains_Point (Hull, (X => 3.5, Y => 3.5)),
         "a collinear hull keeps only its extremes");
   end Small_And_Degenerate;

   procedure Duplicate_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Repeated : constant Points (3 .. 12) := Scattered & Pentagon (0 .. 1);
      Hull     : constant Indices :=
        OpenCV.Geometry.Convex_Hull_Indices (Repeated);
   begin
      AUnit.Assertions.Assert
        (Support.Same_Vertex_Set
           (OpenCV.Geometry.Convex_Hull (Repeated), Pentagon),
         "duplicate points must not inflate the hull");
      AUnit.Assertions.Assert
        (Hull'Length = 5
         and then All_In_Range (Repeated, Hull)
         and then Support.Same_Vertex_Set
                    (Points_At (Repeated, Hull), Pentagon),
         "any index of a duplicated hull vertex may be returned");
   end Duplicate_Points;

   procedure Signed_Zeros (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Zero  : constant OpenCV.Float32_Value := Support.Negative_Zero_32;
      Zeros : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => Zero, Y => 0.0),
         (X => 0.0, Y => Zero),
         (X => Zero, Y => Zero));
      Hull  : constant Points := OpenCV.Geometry.Convex_Hull (Zeros);
      Index : constant Indices := OpenCV.Geometry.Convex_Hull_Indices (Zeros);
   begin
      AUnit.Assertions.Assert
        (Support.Is_Negative_Zero (Zeros (1).X),
         "the fixture must hold a negative zero");
      AUnit.Assertions.Assert
        (Hull'Length = 1
         and then Hull (Hull'First).X = 0.0
         and then Hull (Hull'First).Y = 0.0
         and then not Support.Is_Negative_Zero (Hull (Hull'First).X),
         "a set of signed zeros must have the one-point hull (+0.0, +0.0)");
      AUnit.Assertions.Assert
        (Index'Length = 1 and then All_In_Range (Zeros, Index),
         "a set of signed zeros must have one hull index");
   end Signed_Zeros;

   procedure Large_Finite_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Square   : constant Points :=
        ((X => -1.0E+30, Y => -1.0E+30),
         (X => 1.0E+30, Y => -1.0E+30),
         (X => 1.0E+30, Y => 1.0E+30),
         (X => -1.0E+30, Y => 1.0E+30));
      Inside   : constant Points :=
        Square & OpenCV.Float32_Point'(X => 1.0E+29, Y => -2.0E+29);
      --  Spans of 3.0E+38 keep OpenCV's binary32 differences finite.
      Wide     : constant Points :=
        ((X => -1.5E+38, Y => 0.0),
         (X => 0.0, Y => 1.0),
         (X => 1.5E+38, Y => 0.0),
         (X => 0.0, Y => 1.0E+38));
      --  A span of 6.0E+38 overflows them.
      Too_Wide : constant Points :=
        ((X => -3.0E+38, Y => 0.0),
         (X => 3.0E+38, Y => 0.0),
         (X => 0.0, Y => 1.0));

      procedure Hull_Too_Wide is
         Unused : constant Points := OpenCV.Geometry.Convex_Hull (Too_Wide);
         pragma Unreferenced (Unused);
      begin
         null;
      end Hull_Too_Wide;

      procedure Indices_Too_Wide is
         Unused : constant Indices :=
           OpenCV.Geometry.Convex_Hull_Indices (Too_Wide);
         pragma Unreferenced (Unused);
      begin
         null;
      end Indices_Too_Wide;
   begin
      AUnit.Assertions.Assert
        (Support.Same_Vertex_Set
           (OpenCV.Geometry.Convex_Hull (Inside), Square),
         "binary32 hull arithmetic must handle large finite coordinates");
      AUnit.Assertions.Assert
        (Support.Same_Vertex_Set
           (OpenCV.Geometry.Convex_Hull (Wide),
            Points'(Wide (0), Wide (2), Wide (3))),
         "spans up to Float32_Value'Last must give the exact hull");
      Support.Assert_Raises_OpenCV_Error
        (Hull_Too_Wide'Access, "a span above Float32_Value'Last must raise");
      Support.Assert_Raises_OpenCV_Error
        (Indices_Too_Wide'Access,
         "a span above Float32_Value'Last must raise for indices");
   end Large_Finite_Coordinates;

   procedure Matches_Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Packed  : aliased C_API.Point_F32_Array := Support.Pack (Scattered);
      Output  : aliased C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => 0.0, Y => 0.0));
      Offsets : aliased C_API.Int32_Array (0 .. 7) := (others => -1);
      Count   : aliased Interfaces.Integer_32 := -1;
      Status  : C_API.Status;
      Shifted : constant Points (40 .. 47) := Scattered;
      Hull    : constant Points := OpenCV.Geometry.Convex_Hull (Scattered);
      Index   : constant Indices :=
        OpenCV.Geometry.Convex_Hull_Indices (Shifted);
   begin
      Status :=
        C_API.Convex_Hull_F32
          (Packed (Packed'First)'Access,
           Scattered'Length,
           0,
           Output (Output'First)'Access,
           Output'Length,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = Hull'Length,
         "raw and public hulls must have the same size");
      for Offset in 0 .. Hull'Length - 1 loop
         AUnit.Assertions.Assert
           (OpenCV.Float32_Value (Output (Offset).X)
            = Hull (Hull'First + Offset).X
            and then OpenCV.Float32_Value (Output (Offset).Y)
                     = Hull (Hull'First + Offset).Y,
            "Convex_Hull must preserve the native point order");
      end loop;
      Status :=
        C_API.Convex_Hull_Indices_F32
          (Packed (Packed'First)'Access,
           Scattered'Length,
           0,
           Offsets (Offsets'First)'Access,
           Offsets'Length,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = Index'Length,
         "raw and public hull indices must have the same size");
      for Offset in 0 .. Index'Length - 1 loop
         AUnit.Assertions.Assert
           (Index (Index'First + Offset)
            = Shifted'First + Natural (Offsets (Offset)),
            "public indices must be native offsets from Points'First");
      end loop;
   end Matches_Raw_C_ABI;

   procedure Hull_Points (Candidate : Points) is
      Unused : constant Points := OpenCV.Geometry.Convex_Hull (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Hull_Points;

   procedure Hull_Indices (Candidate : Points) is
      Unused : constant Indices :=
        OpenCV.Geometry.Convex_Hull_Indices (Candidate, Clockwise);
      pragma Unreferenced (Unused);
   begin
      null;
   end Hull_Indices;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (6 .. 13) := Scattered;
   begin
      Support.Assert_Rejects_Non_Finite
        (Shifted, Hull_Points'Access, "Convex_Hull");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Hull_Indices'Access, "Convex_Hull_Indices");
   end Non_Finite_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Raw buffers bypass the Ada policy; NaN is stored directly.
      pragma Suppress (Validity_Check);
      Packed  : aliased C_API.Point_F32_Array := Support.Pack (Scattered);
      Bad     : aliased C_API.Point_F32_Array := Support.Pack (Scattered);
      Output  : aliased C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => 0.0, Y => 0.0));
      Offsets : aliased C_API.Int32_Array (0 .. 7) := (others => 0);
      Count   : aliased Interfaces.Integer_32 := 7;
      Status  : C_API.Status;
   begin
      Bad (3).Y := Support.NaN_C;
      Status := C_API.Convex_Hull_F32 (null, -1, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("count")
         and then Count = 0,
         "negative count must be rejected with a zero count");
      Status := C_API.Convex_Hull_F32 (null, 2, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("points"),
         "null points with positive count must be rejected");
      Status :=
        C_API.Convex_Hull_F32
          (Packed (Packed'First)'Access,
           8,
           2,
           Output (Output'First)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("clockwise"),
         "invalid orientation selector must be rejected");
      Status :=
        C_API.Convex_Hull_F32
          (Packed (Packed'First)'Access, 8, 0, null, 8, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("output points"),
         "null output with positive capacity must be rejected");
      Status :=
        C_API.Convex_Hull_F32
          (Packed (Packed'First)'Access,
           8,
           0,
           Output (Output'First)'Access,
           2,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("capacity")
         and then Count = 0,
         "insufficient capacity must be rejected without writing a count");
      Status :=
        C_API.Convex_Hull_F32
          (Bad (Bad'First)'Access,
           8,
           0,
           Output (Output'First)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("NaN"),
         "NaN must be rejected before native sorting");
      Status :=
        C_API.Convex_Hull_Indices_F32
          (Bad (Bad'First)'Access,
           8,
           1,
           Offsets (Offsets'First)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("NaN"),
         "NaN must be rejected before native index sorting");
      Status :=
        C_API.Convex_Hull_Indices_F32
          (Packed (Packed'First)'Access, 8, 0, null, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("output indices"),
         "null index output with positive capacity must be rejected");
      Status :=
        C_API.Convex_Hull_Indices_F32 (null, 0, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0,
         "empty raw hull indices must succeed with no indices");
   end C_ABI_Validation;

   procedure C_ABI_Count_Overflow (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Dummy_I : aliased C_API.Point_I32 := (0, 0);
      Dummy_F : aliased C_API.Point_F32 := (0.0, 0.0);
      Count   : aliased Interfaces.Integer_32 := 9;
      Huge    : constant Interfaces.Integer_32 :=
        Interfaces.Integer_32'Last - 1;

      procedure Check (Status : C_API.Status) is
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Has_Message ("total + 2")
            and then Count = 0,
            "unsafe hull count must fail before reading the dummy buffer");
         Count := 9;
      end Check;
   begin
      --  Only one point exists: any scan of Huge points would be invalid.
      Check
        (C_API.Convex_Hull (Dummy_I'Access, Huge, 0, null, 0, Count'Access));
      Check
        (C_API.Convex_Hull_Indices
           (Dummy_I'Access, Huge, 0, null, 0, Count'Access));
      Check
        (C_API.Convex_Hull_F32
           (Dummy_F'Access, Huge, 0, null, 0, Count'Access));
      Check
        (C_API.Convex_Hull_Indices_F32
           (Dummy_F'Access, Huge, 0, null, 0, Count'Access));
   end C_ABI_Count_Overflow;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 hull fractional points", Fractional_Hull'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull orientation convention",
            Orientation_Convention'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull equals integer hull", Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull indices preserve bounds",
            Indices_Preserve_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull small and degenerate sets",
            Small_And_Degenerate'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull duplicate points", Duplicate_Points'Access));
      Result.Add_Test
        (Caller.Create ("Float32 hull signed zeros", Signed_Zeros'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull large finite coordinates",
            Large_Finite_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull matches raw C ABI", Matches_Raw_C_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull rejects non-finite coordinates",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 hull C ABI validation", C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Hull C ABI count overflow before reads",
            C_ABI_Count_Overflow'Access));
      return Result'Access;
   end Suite;

end Float32_Convex_Hull_Tests;
