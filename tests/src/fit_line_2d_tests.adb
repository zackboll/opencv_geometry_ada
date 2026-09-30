with Ada.Exceptions;
with Ada.Numerics.Generic_Elementary_Functions;
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

package body Fit_Line_2D_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Math is new
     Ada.Numerics.Generic_Elementary_Functions (OpenCV.Float64_Value);

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type Interfaces.C.double;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Geometry.Fitted_Line_2D;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   subtype Distance is OpenCV.Geometry.Line_Fit_Distance;

   type Distance_Array is array (Positive range <>) of Distance;

   Robust : constant Distance_Array (1 .. 5) :=
     (OpenCV.Geometry.L1,
      OpenCV.Geometry.L12,
      OpenCV.Geometry.Fair,
      OpenCV.Geometry.Welsch,
      OpenCV.Geometry.Huber);

   function Bits_To_Float64 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_64,
        Target => OpenCV.Float64_Value);

   NaN_Bits     : constant Interfaces.Unsigned_64 := 16#7FF8_0000_0000_0000#;
   Inf_Bits     : constant Interfaces.Unsigned_64 := 16#7FF0_0000_0000_0000#;
   Neg_Inf_Bits : constant Interfaces.Unsigned_64 := 16#FFF0_0000_0000_0000#;

   Negative_Zero_Bits : constant Interfaces.Unsigned_64 :=
     16#8000_0000_0000_0000#;

   Horizontal : constant OpenCV.Geometry.Contour :=
     ((0, 5), (10, 5), (20, 5), (30, 5));

   Vertical : constant OpenCV.Geometry.Contour :=
     ((3, -7), (3, 0), (3, 12), (3, 20));

   Diagonal : constant OpenCV.Geometry.Contour :=
     ((0, 0), (1, 1), (2, 2), (5, 5), (9, 9));

   --  Twenty-one points on Y = 0 and one far outlier. The outlier dominates
   --  the L2 covariance, so least squares returns a vertical line; the
   --  robust distances recover Y = 0.
   function With_Outlier return OpenCV.Geometry.Contour is
      Result : OpenCV.Geometry.Contour (0 .. 21);
   begin
      for X in 0 .. 20 loop
         Result (X) := (X => OpenCV.Point_Coordinate (X), Y => 0);
      end loop;
      Result (21) := (X => 10, Y => 60);
      return Result;
   end With_Outlier;

   --  Y = X / 2 with fixed residuals and two outliers, on which every
   --  distance model and parameter setting gives a visibly different fit.
   Noisy : constant OpenCV.Geometry.Contour :=
     ((0, 0),
      (4, 4),
      (8, 3),
      (12, 9),
      (16, 6),
      (20, 11),
      (24, 9),
      (28, 16),
      (32, 16),
      (36, 17),
      (40, 24),
      (44, 20),
      (48, 25),
      (10, 40),
      (30, -25));

   function Norm (X, Y : OpenCV.Float64_Value) return OpenCV.Float64_Value
   is (Math.Sqrt (X * X + Y * Y));

   function Is_Unit (Line : OpenCV.Geometry.Fitted_Line_2D) return Boolean
   is (abs (Norm
              (OpenCV.Float64_Value (Line.Direction.X),
               OpenCV.Float64_Value (Line.Direction.Y))
            - 1.0)
       <= 1.0E-5);

   --  True when Line is the line through (PX, PY) along (DX, DY), whatever
   --  the sign of Line.Direction: the directions are parallel and Line.Point
   --  lies on the expected line.
   function Is_Line
     (Line           : OpenCV.Geometry.Fitted_Line_2D;
      PX, PY, DX, DY : OpenCV.Float64_Value;
      Tolerance      : OpenCV.Float64_Value := 1.0E-3) return Boolean
   is
      Length : constant OpenCV.Float64_Value := Norm (DX, DY);
      UX     : constant OpenCV.Float64_Value := DX / Length;
      UY     : constant OpenCV.Float64_Value := DY / Length;
      VX     : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Line.Direction.X);
      VY     : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Line.Direction.Y);
      QX     : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Line.Point.X) - PX;
      QY     : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Line.Point.Y) - PY;
   begin
      return
        Is_Unit (Line)
        and then abs (VX * UY - VY * UX) <= Tolerance
        and then abs (QX * UY - QY * UX) <= Tolerance;
   end Is_Line;

   function Raises
     (Points          : OpenCV.Geometry.Contour;
      Fragment        : String;
      Parameter       : OpenCV.Float64_Value := 0.0;
      Radius_Accuracy : OpenCV.Float64_Value := 0.01;
      Angle_Accuracy  : OpenCV.Float64_Value := 0.01) return Boolean
   is
      pragma Suppress (Validity_Check);
   begin
      declare
         Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
           OpenCV.Geometry.Fit_Line_2D
             (Points,
              OpenCV.Geometry.Huber,
              Parameter,
              Radius_Accuracy,
              Angle_Accuracy);
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

   procedure Exact_Lines_All_Distances (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Each in Distance loop
         declare
            Label : constant String := Distance'Image (Each);
         begin
            AUnit.Assertions.Assert
              (Is_Line
                 (OpenCV.Geometry.Fit_Line_2D (Horizontal, Each),
                  0.0,
                  5.0,
                  1.0,
                  0.0),
               Label & " must fit the horizontal line Y = 5");
            AUnit.Assertions.Assert
              (Is_Line
                 (OpenCV.Geometry.Fit_Line_2D (Vertical, Each),
                  3.0,
                  0.0,
                  0.0,
                  1.0),
               Label & " must fit the vertical line X = 3");
            AUnit.Assertions.Assert
              (Is_Line
                 (OpenCV.Geometry.Fit_Line_2D (Diagonal, Each),
                  0.0,
                  0.0,
                  1.0,
                  1.0),
               Label & " must fit the diagonal Y = X");
         end;
      end loop;
   end Exact_Lines_All_Distances;

   procedure L2_Point_Is_Centroid (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Line : constant OpenCV.Geometry.Fitted_Line_2D :=
        OpenCV.Geometry.Fit_Line_2D (Vertical);
   begin
      AUnit.Assertions.Assert
        (abs (OpenCV.Float64_Value (Line.Point.X) - 3.0) <= 1.0E-4
         and then abs (OpenCV.Float64_Value (Line.Point.Y) - 6.25) <= 1.0E-4,
         "the L2 line point must be the centroid (3, 6.25)");
   end L2_Point_Is_Centroid;

   procedure Many_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  One hundred points on Y = 2 * X + 3.
      function Sloped return OpenCV.Geometry.Contour is
         Result : OpenCV.Geometry.Contour (0 .. 99);
      begin
         for X in Result'Range loop
            Result (X) :=
              (X => OpenCV.Point_Coordinate (X - 50),
               Y => OpenCV.Point_Coordinate (2 * (X - 50) + 3));
         end loop;
         return Result;
      end Sloped;

      Points : constant OpenCV.Geometry.Contour := Sloped;
   begin
      for Each in Distance loop
         AUnit.Assertions.Assert
           (Is_Line
              (OpenCV.Geometry.Fit_Line_2D (Points, Each), 0.0, 3.0, 1.0, 2.0),
            Distance'Image (Each) & " must fit Y = 2 * X + 3");
      end loop;
   end Many_Points;

   procedure Minimal_Point_Counts (Test : in out Fixture) is
      pragma Unreferenced (Test);
      One  : constant OpenCV.Geometry.Contour := (0 => (4, -2));
      Two  : constant OpenCV.Geometry.Contour :=
        ((-1_000, -500), (-990, -490));
      Same : constant OpenCV.Geometry.Contour := ((7, 7), (7, 7), (7, 7));
   begin
      for Each in Distance loop
         declare
            Single   : constant OpenCV.Geometry.Fitted_Line_2D :=
              OpenCV.Geometry.Fit_Line_2D (One, Each);
            Repeated : constant OpenCV.Geometry.Fitted_Line_2D :=
              OpenCV.Geometry.Fit_Line_2D (Same, Each);
            Label    : constant String := Distance'Image (Each);
         begin
            AUnit.Assertions.Assert
              (Is_Unit (Single)
               and then abs (OpenCV.Float64_Value (Single.Point.X) - 4.0)
                        <= 1.0E-4
               and then abs (OpenCV.Float64_Value (Single.Point.Y) + 2.0)
                        <= 1.0E-4,
               Label & " one point must give a unit line through it");
            AUnit.Assertions.Assert
              (Is_Unit (Repeated)
               and then abs (OpenCV.Float64_Value (Repeated.Point.X) - 7.0)
                        <= 1.0E-4
               and then abs (OpenCV.Float64_Value (Repeated.Point.Y) - 7.0)
                        <= 1.0E-4,
               Label & " repeated points must give a unit line through them");
            AUnit.Assertions.Assert
              (Is_Line
                 (OpenCV.Geometry.Fit_Line_2D (Two, Each),
                  -1_000.0,
                  -500.0,
                  1.0,
                  1.0),
               Label & " two translated points must fix their line");
         end;
      end loop;
   end Minimal_Point_Counts;

   procedure Robust_Distances_Ignore_Outlier (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour := With_Outlier;
      Least  : constant OpenCV.Geometry.Fitted_Line_2D :=
        OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.L2);
   begin
      AUnit.Assertions.Assert
        (Is_Unit (Least)
         and then abs (OpenCV.Float64_Value (Least.Direction.Y)) > 0.5,
         "the outlier must pull the L2 line away from Y = 0");
      for Each of Robust loop
         AUnit.Assertions.Assert
           (Is_Line
              (OpenCV.Geometry.Fit_Line_2D (Points, Each),
               0.0,
               0.0,
               1.0,
               0.0,
               Tolerance => 1.0E-2),
            Distance'Image (Each) & " must recover Y = 0");
      end loop;
   end Robust_Distances_Ignore_Outlier;

   procedure Distances_Are_Distinct (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Every distance model weights Noisy differently, so each selector
      --  must reach a different native estimator. On OpenCV 4.10 the fitted
      --  points differ pairwise by at least 0.02; the robust distances share
      --  OpenCV's random subsets, so a much smaller threshold is asserted.
      Lines : array (Distance) of OpenCV.Geometry.Fitted_Line_2D;
   begin
      for Each in Distance loop
         Lines (Each) := OpenCV.Geometry.Fit_Line_2D (Noisy, Each);
      end loop;
      for Left in Distance'First .. Distance'Pred (Distance'Last) loop
         for Right in Distance'Succ (Left) .. Distance'Last loop
            AUnit.Assertions.Assert
              (Norm
                 (OpenCV.Float64_Value (Lines (Left).Point.X)
                  - OpenCV.Float64_Value (Lines (Right).Point.X),
                  OpenCV.Float64_Value (Lines (Left).Point.Y)
                  - OpenCV.Float64_Value (Lines (Right).Point.Y))
               > 1.0E-3,
               Distance'Image (Left)
               & " and "
               & Distance'Image (Right)
               & " must select different estimators");
         end loop;
      end loop;
   end Distances_Are_Distinct;

   procedure Parameter_Behavior (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour := With_Outlier;
   begin
      --  OpenCV substitutes these constants when Parameter is 0.0, so the
      --  explicit and default forms must agree exactly.
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Huber, 1.345)
         = OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Huber),
         "Huber Parameter 0.0 must select 1.345");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Fair, 1.399_8)
         = OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Fair),
         "Fair Parameter 0.0 must select 1.3998");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Welsch, 2.984_6)
         = OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Welsch),
         "Welsch Parameter 0.0 must select 2.9846");
      --  A different constant still gives a robust fit, and L2 ignores it.
      AUnit.Assertions.Assert
        (Is_Line
           (OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Huber, 5.0),
            0.0,
            0.0,
            1.0,
            0.0,
            Tolerance => 1.0E-2),
         "Huber with Parameter 5.0 must still recover Y = 0");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.L2, 5.0)
         = OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.L2),
         "L2 must ignore Parameter");
      --  Zero accuracies, including -0.0, select OpenCV's defaults 1.0 and
      --  0.01.
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D
           (Points, OpenCV.Geometry.L1, 0.0, 0.0, 0.0)
         = OpenCV.Geometry.Fit_Line_2D
             (Points, OpenCV.Geometry.L1, 0.0, 1.0, 0.01)
         and then OpenCV.Geometry.Fit_Line_2D
                    (Points,
                     OpenCV.Geometry.L1,
                     0.0,
                     Bits_To_Float64 (Negative_Zero_Bits),
                     Bits_To_Float64 (Negative_Zero_Bits))
                  = OpenCV.Geometry.Fit_Line_2D
                      (Points, OpenCV.Geometry.L1, 0.0, 0.0, 0.0),
         "zero accuracies must select OpenCV's defaults");
   end Parameter_Behavior;

   function Point_Distance
     (Left, Right : OpenCV.Geometry.Fitted_Line_2D) return OpenCV.Float64_Value
   is (Norm
         (OpenCV.Float64_Value (Left.Point.X)
          - OpenCV.Float64_Value (Right.Point.X),
          OpenCV.Float64_Value (Left.Point.Y)
          - OpenCV.Float64_Value (Right.Point.Y)));

   procedure Parameters_Reach_OpenCV (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  On Noisy, a non-default constant and non-default accuracies each
      --  move the fitted point by at least 0.3 on OpenCV 4.10, so a binding
      --  that dropped or swapped them would fail here.
      use OpenCV.Geometry;
      function Fit
        (Which         : Distance;
         Parameter     : OpenCV.Float64_Value := 0.0;
         Radius, Angle : OpenCV.Float64_Value := 0.01) return Fitted_Line_2D
      is (Fit_Line_2D (Noisy, Which, Parameter, Radius, Angle));

      Radius_Only : constant Fitted_Line_2D := Fit (L1, Radius => 5.0);
      Angle_Only  : constant Fitted_Line_2D := Fit (L1, Angle => 5.0);
      Both        : constant Fitted_Line_2D :=
        Fit (L1, Radius => 5.0, Angle => 5.0);
   begin
      for Which of Distance_Array'(Fair, Welsch, Huber) loop
         AUnit.Assertions.Assert
           (Point_Distance (Fit (Which, Parameter => 0.5), Fit (Which)) > 0.1,
            Distance'Image (Which) & " Parameter must reach OpenCV");
      end loop;
      AUnit.Assertions.Assert
        (Point_Distance (Radius_Only, Fit (L1)) > 0.1,
         "Radius_Accuracy must reach OpenCV");
      AUnit.Assertions.Assert
        (Point_Distance (Radius_Only, Angle_Only) > 0.1,
         "Radius_Accuracy and Angle_Accuracy must not be swapped");
      AUnit.Assertions.Assert
        (Point_Distance (Both, Radius_Only) > 0.1,
         "Angle_Accuracy must reach OpenCV");
   end Parameters_Reach_OpenCV;

   procedure Boundary_Values_Accepted (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Largest : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (OpenCV.Float32_Value'Last);
   begin
      --  Float32_Value'Last is the inclusive upper limit of each value.
      AUnit.Assertions.Assert
        (Is_Line
           (OpenCV.Geometry.Fit_Line_2D
              (Horizontal, OpenCV.Geometry.Huber, Largest, Largest, Largest),
            0.0,
            5.0,
            1.0,
            0.0),
         "Float32_Value'Last must be accepted for every value");
   end Boundary_Values_Accepted;

   procedure Reversed_Order (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Backward : OpenCV.Geometry.Contour (Diagonal'Range);
   begin
      for Index in Diagonal'Range loop
         Backward (Index) :=
           Diagonal (Diagonal'Last - (Index - Diagonal'First));
      end loop;
      for Each in Distance loop
         AUnit.Assertions.Assert
           (Is_Line
              (OpenCV.Geometry.Fit_Line_2D (Backward, Each),
               0.0,
               0.0,
               1.0,
               1.0),
            Distance'Image (Each) & " reversed points must fit Y = X");
      end loop;
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Fit_Line_2D (Backward)
         = OpenCV.Geometry.Fit_Line_2D (Diagonal),
         "L2 must not depend on point order");
   end Reversed_Order;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points  : constant OpenCV.Geometry.Contour := With_Outlier;
      Shifted : constant OpenCV.Geometry.Contour (40 .. 61) := Points;
      Top     :
        constant OpenCV.Geometry.Contour (Natural'Last - 21 .. Natural'Last) :=
          Points;
   begin
      for Each in Distance loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Fit_Line_2D (Shifted, Each)
            = OpenCV.Geometry.Fit_Line_2D (Points, Each)
            and then OpenCV.Geometry.Fit_Line_2D (Top, Each)
                     = OpenCV.Geometry.Fit_Line_2D (Points, Each),
            Distance'Image (Each) & " must not depend on Ada array bounds");
      end loop;
   end Nonzero_Array_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Warnings (Off, "could be declared constant");
      Points : OpenCV.Geometry.Contour := Diagonal;
      pragma Warnings (On, "could be declared constant");
      Unused : constant OpenCV.Geometry.Fitted_Line_2D :=
        OpenCV.Geometry.Fit_Line_2D (Points, OpenCV.Geometry.Welsch);
      pragma Unreferenced (Unused);
   begin
      for Index in Points'Range loop
         AUnit.Assertions.Assert
           (OpenCV."=" (Points (Index), Diagonal (Index)),
            "Fit_Line_2D must leave Points unchanged");
      end loop;
   end Input_Unchanged;

   procedure Rejects_Invalid_Inputs (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Point'(X => 0, Y => 0));
      Bad   : constant array (1 .. 5) of OpenCV.Float64_Value :=
        (Bits_To_Float64 (NaN_Bits),
         Bits_To_Float64 (Inf_Bits),
         Bits_To_Float64 (Neg_Inf_Bits),
         -1.0,
         1.0E39);
   begin
      AUnit.Assertions.Assert
        (Raises (Empty, "at least one point"),
         "an empty contour must be rejected");
      for Value of Bad loop
         AUnit.Assertions.Assert
           (Raises (Diagonal, "Parameter", Parameter => Value),
            "an invalid Parameter must be rejected");
         AUnit.Assertions.Assert
           (Raises (Diagonal, "Radius_Accuracy", Radius_Accuracy => Value),
            "an invalid Radius_Accuracy must be rejected");
         AUnit.Assertions.Assert
           (Raises (Diagonal, "Angle_Accuracy", Angle_Accuracy => Value),
            "an invalid Angle_Accuracy must be rejected");
      end loop;
   end Rejects_Invalid_Inputs;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);
      Points : aliased C_API.Point_I32_Array (0 .. 3) :=
        ((X => 0, Y => 5),
         (X => 10, Y => 5),
         (X => 20, Y => 5),
         (X => 30, Y => 5));
      Output : aliased C_API.C_Line_2D;
      Status : C_API.Status;

      function Call
        (Count     : Interfaces.Integer_32 := 4;
         Selector  : Interfaces.Integer_32 := C_API.Line_Fit_L2;
         Parameter : Interfaces.C.double := 0.0;
         Accuracy  : Interfaces.C.double := 0.01) return C_API.Status is
      begin
         Output := (others => -3.0);
         return
           C_API.Fit_Line_2D
             (Points (0)'Access,
              Count,
              Selector,
              Parameter,
              Accuracy,
              Accuracy,
              Output'Access);
      end Call;

      function Zeroed return Boolean
      is (Output.Direction_X = 0.0
          and then Output.Direction_Y = 0.0
          and then Output.Point_X = 0.0
          and then Output.Point_Y = 0.0);

      procedure Expect_Invalid (Fragment, Message : String) is
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Ada.Strings.Fixed.Index
                       (C_API.Last_Error_Message, Fragment)
                     /= 0
            and then Zeroed,
            Message);
      end Expect_Invalid;
   begin
      Status := Call (Count => -1);
      Expect_Invalid ("count", "a negative count must be rejected");
      --  The count guard runs before OpenCV reads the buffer.
      Status := Call (Count => Interfaces.Integer_32'Last / 2 + 1);
      Expect_Invalid ("allocation", "counts beyond Integer_32'Last / 2");
      Status := Call (Selector => 6);
      Expect_Invalid ("distance", "an unknown selector must be rejected");
      Status := Call (Selector => -1);
      Expect_Invalid ("distance", "a negative selector must be rejected");
      --  The value range of Parameter and the accuracies is Ada policy: the
      --  IEC 559 toolchains define narrowing them to binary32, and OpenCV's
      --  reweighting tolerates NaN and infinite values, so the shim passes
      --  them through and OpenCV must still return a finite line.
      declare
         pragma Suppress (Validity_Check);
         Unusual : constant array (1 .. 4) of Interfaces.C.double :=
           (Interfaces.C.double (Bits_To_Float64 (NaN_Bits)),
            Interfaces.C.double (Bits_To_Float64 (Inf_Bits)),
            1.0E39,
            -1.0E39);
      begin
         for Value of Unusual loop
            Status :=
              Call
                (Selector  => C_API.Line_Fit_Huber,
                 Parameter => Value,
                 Accuracy  => Value);
            AUnit.Assertions.Assert
              (Status = C_API.Success
               and then abs (Output.Direction_Y) <= 1.0E-6
               and then abs (Output.Point_Y - 5.0) <= 1.0E-4,
               "raw unusual parameters must still fit Y = 5 in OpenCV");
         end loop;
      end;

      Output := (others => -3.0);
      Status :=
        C_API.Fit_Line_2D
          (null, 4, C_API.Line_Fit_L2, 0.0, 0.01, 0.01, Output'Access);
      Expect_Invalid ("points", "null points with a positive count");

      Status :=
        C_API.Fit_Line_2D
          (Points (0)'Access, 4, C_API.Line_Fit_L2, 0.0, 0.01, 0.01, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "a null output must be rejected");

      --  OpenCV rejects an empty point set by assertion.
      Output := (others => -3.0);
      Status :=
        C_API.Fit_Line_2D
          (null, 0, C_API.Line_Fit_L2, 0.0, 0.01, 0.01, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV and then Zeroed,
         "an empty raw point set must fail in OpenCV");

      Status := Call (Selector => C_API.Line_Fit_Huber);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then abs (Output.Direction_Y) <= 1.0E-6
         and then abs (Output.Point_Y - 5.0) <= 1.0E-4,
         "a valid raw call must fit Y = 5");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D exact lines for every distance",
            Exact_Lines_All_Distances'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D L2 point is the centroid",
            L2_Point_Is_Centroid'Access));
      Result.Add_Test
        (Caller.Create ("Fit line 2D many points", Many_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D minimal point counts", Minimal_Point_Counts'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D robust distances ignore an outlier",
            Robust_Distances_Ignore_Outlier'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D distances are distinct",
            Distances_Are_Distinct'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D parameter behavior", Parameter_Behavior'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D parameters reach OpenCV",
            Parameters_Reach_OpenCV'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D boundary values accepted",
            Boundary_Values_Accepted'Access));
      Result.Add_Test
        (Caller.Create ("Fit line 2D reversed order", Reversed_Order'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D nonzero array bounds", Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D rejects invalid inputs",
            Rejects_Invalid_Inputs'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit line 2D C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Fit_Line_2D_Tests;
