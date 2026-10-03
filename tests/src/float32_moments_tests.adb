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

package body Float32_Moments_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Geometry.Hu_Moments_Result;
   use type OpenCV.Geometry.Moments_Result;

   subtype Points is Support.Points;
   subtype Method is OpenCV.Geometry.Shape_Match_Method;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  The rectangle [0.5, 3.0] x [0.25, 1.75]: area 3.75, centroid
   --  (1.75, 1.0). Rounding moves it to [1, 3] x [0, 2].
   Rectangle : constant Points :=
     ((X => 0.5, Y => 0.25),
      (X => 3.0, Y => 0.25),
      (X => 3.0, Y => 1.75),
      (X => 0.5, Y => 1.75));

   Pentagon : constant OpenCV.Geometry.Contour :=
     ((X => -3, Y => 1),
      (X => 5, Y => -2),
      (X => 9, Y => 4),
      (X => 2, Y => 8),
      (X => -1, Y => 6));

   Float32_Pentagon : constant Points :=
     ((X => -3.0, Y => 1.0),
      (X => 5.0, Y => -2.0),
      (X => 9.0, Y => 4.0),
      (X => 2.0, Y => 8.0),
      (X => -1.0, Y => 6.0));

   Notched : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 2, Y => 1),
      (X => 4, Y => 4),
      (X => 0, Y => 4));

   Float32_Notched : constant Points :=
     ((X => 0.0, Y => 0.0),
      (X => 4.0, Y => 0.0),
      (X => 2.0, Y => 1.0),
      (X => 4.0, Y => 4.0),
      (X => 0.0, Y => 4.0));

   --  An irregular fractional quadrilateral; rounding it collapses three of
   --  its vertices onto one line.
   Quadrilateral : constant Points :=
     ((X => 0.4, Y => 0.3),
      (X => 2.6, Y => 0.2),
      (X => 2.2, Y => 1.8),
      (X => 0.7, Y => 1.4));

   --  Doubled area 1.0E-8, below OpenCV's FLT_EPSILON threshold.
   Tiny : constant Points :=
     ((X => 0.0, Y => 0.0), (X => 1.0E-4, Y => 0.0), (X => 0.0, Y => 1.0E-4));

   --  Doubled area 1.0E-6, above that threshold.
   Small : constant Points :=
     ((X => 0.0, Y => 0.0), (X => 1.0E-3, Y => 0.0), (X => 0.0, Y => 1.0E-3));

   --  A huge self-intersecting bowtie, whose signed areas cancel, followed by
   --  a tiny loop at the origin. The net area is tiny while the first
   --  moment is huge, so OpenCV's central moments overflow.
   Overflowing : constant Points :=
     ((X => 0.0, Y => 0.0),
      (X => 1.0E+36, Y => 1.0E+36),
      (X => 1.0E+36, Y => 0.0),
      (X => 0.0, Y => 1.0E+36),
      (X => 0.0, Y => 0.0),
      (X => 1.0E-3, Y => 0.0),
      (X => 0.0, Y => 1.0E-3));

   Empty : constant Points (1 .. 0) := (others => (0.0, 0.0));

   function Close
     (Actual, Expected : OpenCV.Float64_Value;
      Tolerance        : OpenCV.Float64_Value := 1.0E-9) return Boolean
   is (abs (Actual - Expected)
       <= Tolerance * OpenCV.Float64_Value'Max (1.0, abs Expected));

   --  Source scaled by 2.5 and translated by (0.375, -1.25).
   function Transformed (Source : Points) return Points is
      Result : Points (Source'Range);
   begin
      for Index in Source'Range loop
         Result (Index) :=
           (X => 2.5 * Source (Index).X + 0.375,
            Y => 2.5 * Source (Index).Y - 1.25);
      end loop;
      return Result;
   end Transformed;

   function Is_Zero (Value : OpenCV.Geometry.Moments_Result) return Boolean
   is (Value = OpenCV.Geometry.Moments_Result'(others => 0.0));

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Rectangle_Moments (Test : in out Fixture) is
      pragma Unreferenced (Test);
      M : constant OpenCV.Geometry.Moments_Result :=
        OpenCV.Geometry.Compute_Moments (Rectangle);
   begin
      AUnit.Assertions.Assert
        (Close (M.M_00, 3.75)
         and then Close (M.M_10, 6.5625)
         and then Close (M.M_01, 3.75)
         and then Close (M.M_20, 13.4375)
         and then Close (M.M_11, 6.5625)
         and then Close (M.M_02, 4.453125),
         "fractional rectangle spatial moments");
      AUnit.Assertions.Assert
        (Close (M.Mu_20, 1.953125)
         and then Close (M.Mu_11, 0.0)
         and then Close (M.Mu_02, 0.703125)
         and then Close (M.Mu_30, 0.0)
         and then Close (M.Mu_03, 0.0),
         "fractional rectangle central moments");
      AUnit.Assertions.Assert
        (Close (M.Nu_20, 1.953125 / 3.75**2)
         and then Close (M.Nu_02, 0.703125 / 3.75**2),
         "fractional rectangle normalized moments");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Compute_Moments (Support.Rounded (Rectangle)).M_00
         = 4.0,
         "the rounded rectangle has a different area");
   end Fractional_Rectangle_Moments;

   procedure Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Compute_Moments (Float32_Pentagon)
         = OpenCV.Geometry.Compute_Moments (Pentagon)
         and then OpenCV.Geometry.Compute_Moments (Float32_Notched)
                  = OpenCV.Geometry.Compute_Moments (Notched),
         "integer-valued Float32 moments must equal the integer overload");
      for Kind in Method loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Match_Shapes
              (Float32_Pentagon, Float32_Notched, Kind)
            = OpenCV.Geometry.Match_Shapes (Pentagon, Notched, Kind),
            "integer-valued Float32 shape score must equal the integer "
            & "overload for "
            & Kind'Image);
      end loop;
   end Integer_Equivalence;

   procedure Area_Threshold (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Small_Moments : constant OpenCV.Geometry.Moments_Result :=
        OpenCV.Geometry.Compute_Moments (Small);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Contour_Area (Tiny) > 0.0
         and then Is_Zero (OpenCV.Geometry.Compute_Moments (Tiny)),
         "a nonzero area within FLT_EPSILON must give all-zero moments");
      AUnit.Assertions.Assert
        (Close
           (Small_Moments.M_00, OpenCV.Geometry.Contour_Area (Small), 1.0E-6)
         and then Small_Moments.M_00 > 0.0,
         "an area above the threshold must give nonzero moments");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Hu_Moments (OpenCV.Geometry.Compute_Moments (Tiny))
         = OpenCV.Geometry.Hu_Moments_Result'(others => 0.0),
         "all-zero moments must have all-zero Hu moments");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Match_Shapes
           (Tiny, Quadrilateral, OpenCV.Geometry.Log_Difference)
         = OpenCV.Float64_Value'Last,
         "a set with zero moments must not match an ordinary shape");
   end Area_Threshold;

   procedure Empty_And_Minimal (Test : in out Fixture) is
      pragma Unreferenced (Test);
      One : constant Points := (0 => (X => 1.5, Y => -2.5));
   begin
      AUnit.Assertions.Assert
        (Is_Zero (OpenCV.Geometry.Compute_Moments (Empty))
         and then Is_Zero (OpenCV.Geometry.Compute_Moments (One)),
         "empty and one-point Float32 sets must have zero moments");
      for Kind in Method loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Match_Shapes (Empty, Empty, Kind) = 0.0,
            "empty Float32 sets must match perfectly for " & Kind'Image);
      end loop;
   end Empty_And_Minimal;

   procedure Overflowing_Moments_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A convex sliver whose moments are finite but whose fifth Hu moment
      --  is not; OpenCV's I1 and I3 skip that term and score finitely.
      Sliver : constant Points :=
        ((X => 0.0, Y => 0.0),
         (X => 1.0E+30, Y => 0.0),
         (X => 1.0E+30, Y => 1.0E-36));
      Kind   : Method := Method'First;
      Swap   : Boolean := False;

      procedure Compute is
         Unused : constant OpenCV.Geometry.Moments_Result :=
           OpenCV.Geometry.Compute_Moments (Overflowing);
         pragma Unreferenced (Unused);
      begin
         null;
      end Compute;

      procedure Hu_Of_Sliver is
         Unused : constant OpenCV.Geometry.Hu_Moments_Result :=
           OpenCV.Geometry.Hu_Moments
             (OpenCV.Geometry.Compute_Moments (Sliver));
         pragma Unreferenced (Unused);
      begin
         null;
      end Hu_Of_Sliver;

      procedure Match is
         Unused : constant OpenCV.Float64_Value :=
           (if Swap
            then
              OpenCV.Geometry.Match_Shapes (Quadrilateral, Overflowing, Kind)
            else
              OpenCV.Geometry.Match_Shapes (Overflowing, Quadrilateral, Kind));
         pragma Unreferenced (Unused);
      begin
         null;
      end Match;

      procedure Match_Sliver is
         Unused : constant OpenCV.Float64_Value :=
           (if Swap
            then OpenCV.Geometry.Match_Shapes (Quadrilateral, Sliver, Kind)
            else OpenCV.Geometry.Match_Shapes (Sliver, Quadrilateral, Kind));
         pragma Unreferenced (Unused);
      begin
         null;
      end Match_Sliver;
   begin
      Support.Assert_Raises_OpenCV_Error
        (Compute'Access, "non-finite native moments must raise");
      Support.Assert_Raises_OpenCV_Error
        (Hu_Of_Sliver'Access, "the sliver's Hu moments must not be finite");
      for Each_Kind in Method loop
         for Each_Swap in Boolean loop
            Kind := Each_Kind;
            Swap := Each_Swap;
            Support.Assert_Raises_OpenCV_Error
              (Match'Access,
               "matching non-finite moments must raise for " & Kind'Image);
            Support.Assert_Raises_OpenCV_Error
              (Match_Sliver'Access,
               "matching non-finite Hu moments must raise for " & Kind'Image);
         end loop;
      end loop;
   end Overflowing_Moments_Rejected;

   procedure Fractional_Shape_Matching (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Copy : constant Points := Transformed (Quadrilateral);
   begin
      for Kind in Method loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Match_Shapes (Quadrilateral, Copy, Kind) < 1.0E-5,
            "a scaled and translated fractional shape must match for "
            & Kind'Image);
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Match_Shapes
              (Support.Rounded (Quadrilateral), Support.Rounded (Copy), Kind)
            > 1.0E-2,
            "the same shapes rounded to integers must not match for "
            & Kind'Image);
      end loop;
   end Fractional_Shape_Matching;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted_Rectangle : constant Points (11 .. 14) := Rectangle;
      Shifted_Copy      : constant Points (3 .. 6) := Transformed (Rectangle);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Compute_Moments (Shifted_Rectangle)
         = OpenCV.Geometry.Compute_Moments (Rectangle),
         "Float32 moments must not depend on the Ada lower bound");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Match_Shapes
           (Shifted_Rectangle, Shifted_Copy, OpenCV.Geometry.Log_Difference)
         = OpenCV.Geometry.Match_Shapes
             (Rectangle,
              Transformed (Rectangle),
              OpenCV.Geometry.Log_Difference),
         "Float32 shape matching must not depend on the Ada lower bound");
   end Nonzero_Bounds;

   procedure Matches_Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left   : aliased C_API.Point_F32_Array := Support.Pack (Quadrilateral);
      Right  : aliased C_API.Point_F32_Array :=
        Support.Pack (Transformed (Quadrilateral));
      Native : aliased C_API.C_Moments;
      Score  : aliased Interfaces.C.double := -1.0;
      Status : C_API.Status;
      M      : constant OpenCV.Geometry.Moments_Result :=
        OpenCV.Geometry.Compute_Moments (Quadrilateral);
   begin
      Status :=
        C_API.Contour_Moments_F32
          (Left (Left'First)'Access, Quadrilateral'Length, Native'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then OpenCV.Float64_Value (Native.M00) = M.M_00
         and then OpenCV.Float64_Value (Native.M21) = M.M_21
         and then OpenCV.Float64_Value (Native.Mu12) = M.Mu_12
         and then OpenCV.Float64_Value (Native.Nu03) = M.Nu_03,
         "Compute_Moments must copy the raw C ABI moments");
      Status :=
        C_API.Match_Shapes_F32
          (Left (Left'First)'Access,
           Quadrilateral'Length,
           Right (Right'First)'Access,
           Quadrilateral'Length,
           C_API.Match_Shapes_Relative_Log_Difference,
           Score'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then OpenCV.Float64_Value (Score)
                  = OpenCV.Geometry.Match_Shapes
                      (Quadrilateral,
                       Transformed (Quadrilateral),
                       OpenCV.Geometry.Relative_Log_Difference),
         "Match_Shapes must return the raw C ABI score");
   end Matches_Raw_C_ABI;

   procedure Moments_Of (Candidate : Points) is
      Unused : constant OpenCV.Geometry.Moments_Result :=
        OpenCV.Geometry.Compute_Moments (Candidate);
      pragma Unreferenced (Unused);
   begin
      null;
   end Moments_Of;

   procedure Match_As_Left (Candidate : Points) is
      Unused : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Match_Shapes
          (Candidate, Rectangle, OpenCV.Geometry.Reciprocal_Log_Difference);
      pragma Unreferenced (Unused);
   begin
      null;
   end Match_As_Left;

   procedure Match_As_Right (Candidate : Points) is
      Unused : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Match_Shapes
          (Rectangle, Candidate, OpenCV.Geometry.Log_Difference);
      pragma Unreferenced (Unused);
   begin
      null;
   end Match_As_Right;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (9 .. 12) := Quadrilateral;
   begin
      Support.Assert_Rejects_Non_Finite
        (Shifted, Moments_Of'Access, "Compute_Moments");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Match_As_Left'Access, "Match_Shapes Left");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Match_As_Right'Access, "Match_Shapes Right");
   end Non_Finite_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Rectangle);
      Native : aliased C_API.C_Moments;
      Score  : aliased Interfaces.C.double := -1.0;
      Status : C_API.Status;
   begin
      Status := C_API.Contour_Moments_F32 (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null moments output must be rejected");
      Status := C_API.Contour_Moments_F32 (null, -1, Native'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("count")
         and then Native.M00 = 0.0
         and then Native.Nu03 = 0.0,
         "negative moments count must be rejected with zero moments");
      Status := C_API.Contour_Moments_F32 (null, 2, Native'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("points"),
         "null moments points with positive count must be rejected");
      Status := C_API.Contour_Moments_F32 (null, 0, Native'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Native.M00 = 0.0,
         "empty moments must succeed with zero moments");

      Status :=
        C_API.Match_Shapes_F32
          (Packed (Packed'First)'Access,
           4,
           Packed (Packed'First)'Access,
           4,
           3,
           Score'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("method"),
         "invalid match method must be rejected");
      Status :=
        C_API.Match_Shapes_F32
          (null, 1, Packed (Packed'First)'Access, 4, 0, Score'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("left"),
         "null left points with positive count must be rejected");
      Status :=
        C_API.Match_Shapes_F32
          (Packed (Packed'First)'Access, 4, null, -1, 0, Score'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("right"),
         "negative right count must be rejected");
      Status := C_API.Match_Shapes_F32 (null, 0, null, 0, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null score output must be rejected");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 fractional rectangle moments",
            Fractional_Rectangle_Moments'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 moments equal integer overloads",
            Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 moments area threshold", Area_Threshold'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 moments empty and minimal", Empty_And_Minimal'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 overflowing moments raise",
            Overflowing_Moments_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 fractional shape matching",
            Fractional_Shape_Matching'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 moments nonzero bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 moments match raw C ABI", Matches_Raw_C_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 moments reject non-finite coordinates",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 moments C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Float32_Moments_Tests;
