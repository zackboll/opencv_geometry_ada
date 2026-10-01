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

package body Float32_Approximate_Curve_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;

   use type C_API.Status;
   use type Interfaces.C.C_float;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Geometry.Float32_Point_Array;

   subtype Points is Support.Points;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  An open L-shaped path whose dropped points lie 0.125 or 0.0625 from
   --  their chords, with projections inside the chords, so OpenCV 4.x line
   --  distances and 5.x segment distances agree.
   Path : constant Points :=
     ((X => 0.5, Y => 0.5),
      (X => 1.5, Y => 0.625),
      (X => 2.5, Y => 0.375),
      (X => 3.5, Y => 0.5),
      (X => 3.5625, Y => 1.5),
      (X => 3.4375, Y => 2.5),
      (X => 3.5, Y => 3.5));

   Path_Corners : constant Points :=
     ((X => 0.5, Y => 0.5), (X => 3.5, Y => 0.5), (X => 3.5, Y => 3.5));

   --  A closed square outline with a slightly displaced midpoint per side.
   Outline : constant Points :=
     ((X => 0.5, Y => 0.5),
      (X => 2.5, Y => 0.625),
      (X => 4.5, Y => 0.5),
      (X => 4.375, Y => 2.5),
      (X => 4.5, Y => 4.5),
      (X => 2.5, Y => 4.375),
      (X => 0.5, Y => 4.5),
      (X => 0.625, Y => 2.5));

   Outline_Corners : constant Points :=
     ((X => 0.5, Y => 0.5),
      (X => 4.5, Y => 0.5),
      (X => 4.5, Y => 4.5),
      (X => 0.5, Y => 4.5));

   Integer_Path : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 2, Y => 1),
      (X => 4, Y => -1),
      (X => 6, Y => 0),
      (X => 7, Y => 2),
      (X => 5, Y => 4),
      (X => 6, Y => 6),
      (X => 3, Y => 7));

   function Approximate
     (Source : Points; Epsilon : OpenCV.Float64_Value; Closed : Boolean)
      return Points
   is (OpenCV.Geometry.Approximate_Curve (Source, Epsilon, Closed));

   --  True when Approximation lists points of Source in Source order,
   --  starting anywhere in Source and wrapping around at most once, as a
   --  closed approximation does.
   function Is_Cyclic_Subset (Approximation, Source : Points) return Boolean is
      Count : constant Natural := Source'Length;
   begin
      for Start in 0 .. Count - 1 loop
         declare
            Offset  : Natural := Start;
            Matches : Boolean := True;
         begin
            for Point of Approximation loop
               while Offset < Start + Count
                 and then Source (Source'First + Offset mod Count) /= Point
               loop
                  Offset := Offset + 1;
               end loop;
               if Offset = Start + Count then
                  Matches := False;
                  exit;
               end if;
               Offset := Offset + 1;
            end loop;
            if Matches then
               return True;
            end if;
         end;
      end loop;
      return Approximation'Length = 0;
   end Is_Cyclic_Subset;

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Open_Curve (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result : constant Points := Approximate (Path, 0.25, Closed => False);
   begin
      AUnit.Assertions.Assert
        (Result = Path_Corners,
         "an open fractional path must keep its fractional corners");
      AUnit.Assertions.Assert
        (Result'First = 0, "a Float32 approximation must be zero-based");
      AUnit.Assertions.Assert
        (Approximate (Path, 0.03125, Closed => False) = Path,
         "a smaller epsilon must keep points 0.0625 from their chord");
   end Fractional_Open_Curve;

   procedure Fractional_Closed_Curve (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result : constant Points := Approximate (Outline, 0.25, Closed => True);
   begin
      AUnit.Assertions.Assert
        (Support.Same_Vertex_Set (Result, Outline_Corners)
         and then Is_Cyclic_Subset (Result, Outline),
         "a closed fractional outline must reduce to its corners");
      AUnit.Assertions.Assert
        (Approximate (Outline, 0.25, Closed => False)'Length > Result'Length,
         "an open curve keeps its end points");
   end Fractional_Closed_Curve;

   procedure Zero_Epsilon (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Bent : constant Points :=
        ((X => 0.5, Y => 0.5),
         (X => 1.5, Y => 1.5),
         (X => 2.5, Y => 2.5),
         (X => 2.5, Y => 0.25));
   begin
      AUnit.Assertions.Assert
        (Approximate (Bent, 0.0, Closed => False)
         = Points'
             ((X => 0.5, Y => 0.5),
              (X => 2.5, Y => 2.5),
              (X => 2.5, Y => 0.25)),
         "epsilon 0 must drop only an exactly collinear point");
      AUnit.Assertions.Assert
        (Approximate (Path, 0.0, Closed => False) = Path,
         "epsilon 0 must keep every non-collinear point");
   end Zero_Epsilon;

   procedure Rounding_Would_Differ (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Result  : constant Points := Approximate (Path, 0.25, Closed => False);
      Rounded : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Approximate_Curve
          (Support.Rounded (Path), 0.25, Closed => False);
   begin
      AUnit.Assertions.Assert
        (Support.Contains_Point (Result, (X => 0.5, Y => 0.5))
         and then Support.To_Float32 (Rounded) /= Result,
         "the Float32 path must not approximate rounded coordinates");
   end Rounding_Would_Differ;

   procedure Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Converted : constant Points := Support.To_Float32 (Integer_Path);
      type Epsilon_List is array (Positive range <>) of OpenCV.Float64_Value;
      Epsilons  : constant Epsilon_List := (0.0, 0.5, 1.0, 2.5, 5.0);
   begin
      for Epsilon of Epsilons loop
         for Closed in Boolean loop
            AUnit.Assertions.Assert
              (Approximate (Converted, Epsilon, Closed)
               = Support.To_Float32
                   (OpenCV.Geometry.Approximate_Curve
                      (Integer_Path, Epsilon, Closed)),
               "integer-valued Float32 approximation must equal the "
               & "integer overload at epsilon"
               & Epsilon'Image
               & " closed "
               & Closed'Image);
         end loop;
      end loop;
   end Integer_Equivalence;

   procedure Degenerate_Curves (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant Points (1 .. 0) := (others => (0.0, 0.0));
      One   : constant Points := (0 => (X => 1.25, Y => -2.5));
      Two   : constant Points :=
        ((X => 1.25, Y => -2.5), (X => -3.75, Y => 0.5));
   begin
      AUnit.Assertions.Assert
        (Approximate (Empty, 1.0, Closed => True)'Length = 0
         and then Approximate (Empty, 1.0, Closed => True)'First = 1,
         "empty input must give the null range 1 .. 0");
      AUnit.Assertions.Assert
        (Approximate (One, 0.0, Closed => False) = One
         and then Approximate (Two, 10.0, Closed => False) = Two,
         "an open curve must keep its one or two points");
   end Degenerate_Curves;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (30 .. 36) := Path;
      Late    : constant Points (Natural'Last - 7 .. Natural'Last) := Outline;
   begin
      AUnit.Assertions.Assert
        (Approximate (Shifted, 0.25, Closed => False) = Path_Corners,
         "approximation must follow iteration order for any bounds");
      AUnit.Assertions.Assert
        (Approximate (Late, 0.25, Closed => True)
         = Approximate (Outline, 0.25, Closed => True),
         "approximation must not depend on the Ada lower bound");
   end Nonzero_Bounds;

   procedure Large_Finite_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Scale      : constant := 1.0E+30;
      Large_Path : Points (Path'Range);
      Widest     : constant Points :=
        ((X => -1.5E+38, Y => 0.0),
         (X => 0.0, Y => 1.0E+30),
         (X => 1.5E+38, Y => 0.0));
   begin
      for Index in Path'Range loop
         Large_Path (Index) :=
           (X => Path (Index).X * Scale, Y => Path (Index).Y * Scale);
      end loop;
      AUnit.Assertions.Assert
        (Approximate (Large_Path, 0.25 * Scale, Closed => False)'Length = 3,
         "a scaled path must keep its three corners");
      AUnit.Assertions.Assert
        (Approximate (Widest, 0.0, Closed => False) = Widest,
         "spans up to Float32_Value'Last must be accepted");
   end Large_Finite_Coordinates;

   procedure Span_And_Epsilon_Limits (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Native approxPolyDP does not return for this curve at epsilon 0.
      Too_Wide : constant Points :=
        ((X => -3.0E+38, Y => 0.0),
         (X => 0.0, Y => 0.0),
         (X => 3.0E+38, Y => 0.0));

      procedure Approximate_Too_Wide is
         Unused : constant Points :=
           Approximate (Too_Wide, 0.0, Closed => False);
         pragma Unreferenced (Unused);
      begin
         null;
      end Approximate_Too_Wide;

      procedure Approximate_Too_Wide_Closed is
         Unused : constant Points :=
           Approximate (Too_Wide, 1.0, Closed => True);
         pragma Unreferenced (Unused);
      begin
         null;
      end Approximate_Too_Wide_Closed;

      procedure Approximate_Negative_Epsilon is
         Unused : constant Points := Approximate (Path, -0.5, Closed => False);
         pragma Unreferenced (Unused);
      begin
         null;
      end Approximate_Negative_Epsilon;

      procedure Approximate_Huge_Epsilon is
         Unused : constant Points :=
           Approximate (Path, 1.0E30, Closed => True);
         pragma Unreferenced (Unused);
      begin
         null;
      end Approximate_Huge_Epsilon;
   begin
      Support.Assert_Raises_OpenCV_Error
        (Approximate_Too_Wide'Access,
         "a span above Float32_Value'Last must raise at epsilon 0");
      Support.Assert_Raises_OpenCV_Error
        (Approximate_Too_Wide_Closed'Access,
         "a span above Float32_Value'Last must raise for any epsilon");
      Support.Assert_Raises_OpenCV_Error
        (Approximate_Negative_Epsilon'Access, "a negative epsilon must raise");
      Support.Assert_Raises_OpenCV_Error
        (Approximate_Huge_Epsilon'Access, "an epsilon of 1.0E30 must raise");
   end Span_And_Epsilon_Limits;

   procedure Matches_Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Outline);
      Output : aliased C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => 0.0, Y => 0.0));
      Count  : aliased Interfaces.Integer_32 := -1;
      Status : C_API.Status;
      Public : constant Points := Approximate (Outline, 0.25, Closed => True);
   begin
      Status :=
        C_API.Approximate_Curve_F32
          (Packed (Packed'First)'Access,
           Outline'Length,
           0.25,
           1,
           Output (Output'First)'Access,
           Output'Length,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = Public'Length,
         "raw and public approximations must have the same size");
      for Offset in 0 .. Public'Length - 1 loop
         AUnit.Assertions.Assert
           (OpenCV.Float32_Value (Output (Offset).X)
            = Public (Public'First + Offset).X
            and then OpenCV.Float32_Value (Output (Offset).Y)
                     = Public (Public'First + Offset).Y,
            "Approximate_Curve must preserve the native point order");
      end loop;
   end Matches_Raw_C_ABI;

   procedure Approximate_Candidate (Candidate : Points) is
      Unused : constant Points := Approximate (Candidate, 0.5, Closed => True);
      pragma Unreferenced (Unused);
   begin
      null;
   end Approximate_Candidate;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  NaN epsilon is built here by design.
      pragma Suppress (Validity_Check);
      Shifted : constant Points (5 .. 11) := Path;

      procedure Approximate_NaN_Epsilon is
         Unused : constant Points :=
           OpenCV.Geometry.Approximate_Curve
             (Path, OpenCV.Float64_Value (Support.NaN_32), Closed => False);
         pragma Unreferenced (Unused);
      begin
         null;
      end Approximate_NaN_Epsilon;
   begin
      Support.Assert_Rejects_Non_Finite
        (Shifted, Approximate_Candidate'Access, "Approximate_Curve");
      Support.Assert_Raises_OpenCV_Error
        (Approximate_NaN_Epsilon'Access, "a NaN epsilon must raise");
   end Non_Finite_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Raw buffers bypass the Ada policy; NaN is stored directly.
      pragma Suppress (Validity_Check);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Path);
      Bad    : aliased C_API.Point_F32_Array := Support.Pack (Path);
      Wide   : aliased C_API.Point_F32_Array :=
        ((X => -3.0E+38, Y => 0.0),
         (X => 0.0, Y => 0.0),
         (X => 3.0E+38, Y => 0.0));
      Output : aliased C_API.Point_F32_Array (0 .. 7) :=
        (others => (X => 0.0, Y => 0.0));
      Count  : aliased Interfaces.Integer_32 := 7;
      Status : C_API.Status;
   begin
      Bad (2).X := Support.NaN_C;
      Status :=
        C_API.Approximate_Curve_F32
          (Wide (Wide'First)'Access,
           3,
           0.0,
           0,
           Output (Output'First)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("FLT_MAX")
         and then Count = 0,
         "a span whose binary32 differences overflow must be rejected");
      Status :=
        C_API.Approximate_Curve_F32
          (Bad (Bad'First)'Access,
           7,
           1.0,
           1,
           Output (Output'First)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("NaN"),
         "NaN must be rejected before native approximation");
      Status :=
        C_API.Approximate_Curve_F32
          (Packed (Packed'First)'Access,
           7,
           0.25,
           2,
           Output (Output'First)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("closed"),
         "invalid closed selector must be rejected");
      Status :=
        C_API.Approximate_Curve_F32
          (Packed (Packed'First)'Access,
           7,
           0.0,
           0,
           Output (Output'First)'Access,
           2,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("capacity"),
         "insufficient capacity must be rejected");
      Status :=
        C_API.Approximate_Curve_F32
          (Packed (Packed'First)'Access, 7, 0.0, 0, null, 8, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("output points"),
         "null output with positive capacity must be rejected");
      Status :=
        C_API.Approximate_Curve_F32
          (Packed (Packed'First)'Access,
           7,
           -1.0,
           0,
           Output (Output'First)'Access,
           8,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV,
         "OpenCV must reject a negative epsilon that reaches it");
      Status :=
        C_API.Approximate_Curve_F32 (null, 0, 0.0, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0,
         "an empty raw curve must succeed with no points");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation open fractional curve",
            Fractional_Open_Curve'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation closed fractional curve",
            Fractional_Closed_Curve'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation epsilon 0", Zero_Epsilon'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation is not rounded",
            Rounding_Would_Differ'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation equals integer overload",
            Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation degenerate curves",
            Degenerate_Curves'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation nonzero bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation large finite coordinates",
            Large_Finite_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation span and epsilon limits",
            Span_And_Epsilon_Limits'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation matches raw C ABI",
            Matches_Raw_C_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation rejects non-finite values",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 approximation C ABI validation",
            C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Float32_Approximate_Curve_Tests;
