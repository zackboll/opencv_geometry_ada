with Ada.Numerics.Generic_Elementary_Functions;
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

package body Float32_Point_Polygon_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Support renames Float32_Test_Support;
   package Float64_Functions is new
     Ada.Numerics.Generic_Elementary_Functions (OpenCV.Float64_Value);

   use type C_API.Status;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Geometry.Contour_Point_Location;

   subtype Points is Support.Points;
   subtype Location is OpenCV.Geometry.Contour_Point_Location;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  The square [0.5, 2.5] x [0.5, 2.5]; rounding moves it to
   --  [1, 3] x [1, 3].
   Square : constant Points :=
     ((X => 0.5, Y => 0.5),
      (X => 2.5, Y => 0.5),
      (X => 2.5, Y => 2.5),
      (X => 0.5, Y => 2.5));

   --  A right triangle whose hypotenuse is the line X + Y = 4.5.
   Triangle : constant Points :=
     ((X => 0.25, Y => 0.25), (X => 4.25, Y => 0.25), (X => 0.25, Y => 4.25));

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

   function Q (X, Y : OpenCV.Float32_Value) return OpenCV.Float32_Point
   is ((X => X, Y => Y));

   function Close
     (Actual, Expected : OpenCV.Float64_Value;
      Tolerance        : OpenCV.Float64_Value := 1.0E-6) return Boolean
   is (abs (Actual - Expected)
       <= Tolerance * OpenCV.Float64_Value'Max (1.0, abs Expected));

   function Reversed (Source : Points) return Points is
      Result : Points (Source'Range);
   begin
      for Offset in 0 .. Source'Length - 1 loop
         Result (Source'First + Offset) := Source (Source'Last - Offset);
      end loop;
      return Result;
   end Reversed;

   function Locate
     (Source : Points; X, Y : OpenCV.Float32_Value) return Location
   is (OpenCV.Geometry.Locate_Point (Source, Q (X, Y)));

   function Distance
     (Source : Points; X, Y : OpenCV.Float32_Value) return OpenCV.Float64_Value
   is (OpenCV.Geometry.Signed_Distance_To_Contour (Source, Q (X, Y)));

   function Has_Message (Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Fragment) /= 0);

   procedure Fractional_Square (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (Locate (Square, 1.5, 1.5) = OpenCV.Geometry.Inside_Contour
         and then Distance (Square, 1.5, 1.5) = 1.0,
         "center of the fractional square");
      AUnit.Assertions.Assert
        (Locate (Square, 0.5, 1.25) = OpenCV.Geometry.On_Contour_Boundary
         and then Distance (Square, 0.5, 1.25) = 0.0,
         "fractional query on a fractional edge");
      AUnit.Assertions.Assert
        (Locate (Square, 0.25, 1.0) = OpenCV.Geometry.Outside_Contour
         and then Distance (Square, 0.25, 1.0) = -0.25,
         "fractional query just outside a fractional edge");
      AUnit.Assertions.Assert
        (Close
           (Distance (Square, 2.75, 3.0),
            -Float64_Functions.Sqrt (0.25**2 + 0.5**2)),
         "fractional query nearest a fractional vertex");
      AUnit.Assertions.Assert
        (Locate (Square, 0.75, 1.5) = OpenCV.Geometry.Inside_Contour
         and then OpenCV.Geometry.Locate_Point
                    (Support.Rounded (Square), Q (0.75, 1.5))
                  = OpenCV.Geometry.Outside_Contour,
         "a point inside the fractional square lies outside the rounded one");
   end Fractional_Square;

   procedure Fractional_Diagonal (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (Locate (Triangle, 2.25, 2.25) = OpenCV.Geometry.On_Contour_Boundary,
         "query on the fractional hypotenuse");
      AUnit.Assertions.Assert
        (Locate (Triangle, 2.0, 2.25) = OpenCV.Geometry.Inside_Contour
         and then Locate (Triangle, 2.5, 2.25)
                  = OpenCV.Geometry.Outside_Contour,
         "queries on either side of the fractional hypotenuse");
      AUnit.Assertions.Assert
        (Close
           (Distance (Triangle, 2.5, 2.25),
            -0.25 / Float64_Functions.Sqrt (2.0)),
         "distance to the fractional hypotenuse");
      AUnit.Assertions.Assert
        (Distance (Triangle, 1.0, 1.0) = 0.75,
         "an inside query nearest a leg");
   end Fractional_Diagonal;

   procedure Orientation_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Clockwise : constant Points := Reversed (Square);
   begin
      AUnit.Assertions.Assert
        (Locate (Clockwise, 1.5, 1.5) = Locate (Square, 1.5, 1.5)
         and then Distance (Clockwise, 1.5, 1.5) = Distance (Square, 1.5, 1.5)
         and then Distance (Clockwise, 0.25, 1.0)
                  = Distance (Square, 0.25, 1.0),
         "winding direction must not change the result");
   end Orientation_Independent;

   procedure Empty_And_Minimal (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant Points (1 .. 0) := (others => (0.0, 0.0));
      One   : constant Points := (0 => (X => 0.5, Y => 0.5));
   begin
      AUnit.Assertions.Assert
        (Locate (Empty, 1.0, 1.0) = OpenCV.Geometry.Outside_Contour
         and then Distance (Empty, 1.0, 1.0) = -OpenCV.Float64_Value'Last,
         "an empty Float32 polygon behaves as an empty contour");
      AUnit.Assertions.Assert
        (Locate (Empty, OpenCV.Float32_Value'Last, 0.0)
         = OpenCV.Geometry.Outside_Contour,
         "an empty polygon does not round its query");
      AUnit.Assertions.Assert
        (Locate (One, 0.5, 0.5) = OpenCV.Geometry.On_Contour_Boundary
         and then Distance (One, 0.5, 0.5) = 0.0
         and then Distance (One, 3.5, 4.5) = -5.0,
         "a one-point polygon is its only boundary point");
   end Empty_And_Minimal;

   procedure Integer_Equivalence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      type Query_List is array (Positive range <>) of OpenCV.Float32_Point;
      Queries : constant Query_List :=
        (Q (2.0, 3.0),
         Q (9.0, 4.0),
         Q (7.0, 1.0),
         Q (-5.0, 0.0),
         Q (2.25, 3.75),
         Q (5.5, 6.5),
         Q (-2.0, 3.5));
   begin
      for Query of Queries loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Locate_Point (Float32_Pentagon, Query)
            = OpenCV.Geometry.Locate_Point (Pentagon, Query),
            "integer-valued Float32 classification must equal the integer "
            & "overload");
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Signed_Distance_To_Contour
              (Float32_Pentagon, Query)
            = OpenCV.Geometry.Signed_Distance_To_Contour (Pentagon, Query),
            "integer-valued Float32 distance must equal the integer "
            & "overload");
      end loop;
   end Integer_Equivalence;

   procedure Matches_Raw_C_ABI (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Triangle);
      Value  : aliased Interfaces.C.double := 0.0;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Point_Polygon_Test_F32
          (Packed (Packed'First)'Access,
           Triangle'Length,
           2.5,
           2.25,
           C_API.Point_Polygon_Distance,
           Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then OpenCV.Float64_Value (Value)
                  = Distance (Triangle, 2.5, 2.25),
         "Signed_Distance_To_Contour must return the raw C ABI distance");
      Status :=
        C_API.Point_Polygon_Test_F32
          (Packed (Packed'First)'Access,
           Triangle'Length,
           2.25,
           2.25,
           C_API.Point_Polygon_Classify,
           Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Value = 0.0,
         "the raw C ABI classifies the hypotenuse query as boundary");
   end Matches_Raw_C_ABI;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant Points (20 .. 23) := Square;
   begin
      AUnit.Assertions.Assert
        (Locate (Shifted, 0.5, 1.25) = OpenCV.Geometry.On_Contour_Boundary
         and then Distance (Shifted, 0.25, 1.0) = -0.25
         and then Distance (Shifted, 2.75, 3.0) = Distance (Square, 2.75, 3.0),
         "Float32 point tests must not depend on the Ada lower bound");
   end Nonzero_Bounds;

   procedure Query_Range (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Locate_At_Limit is
         Unused : constant Location := Locate (Square, 2.0**31, 0.0);
         pragma Unreferenced (Unused);
      begin
         null;
      end Locate_At_Limit;

      procedure Measure_Below_Limit is
         Unused : constant OpenCV.Float64_Value :=
           Distance (Square, 0.0, -2147483904.0);
         pragma Unreferenced (Unused);
      begin
         null;
      end Measure_Below_Limit;
   begin
      AUnit.Assertions.Assert
        (Locate (Square, 2147483520.0, 1.0) = OpenCV.Geometry.Outside_Contour
         and then Locate (Square, -2.0**31, 1.0)
                  = OpenCV.Geometry.Outside_Contour,
         "the extreme cvRound-convertible queries must be accepted");
      Support.Assert_Raises_OpenCV_Error
        (Locate_At_Limit'Access, "a query coordinate of 2.0**31 must raise");
      Support.Assert_Raises_OpenCV_Error
        (Measure_Below_Limit'Access,
         "a query coordinate below -2.0**31 must raise");
   end Query_Range;

   procedure Distance_Search_Limit (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Distant  : constant Points :=
        ((X => 1.0E+19, Y => -1.0),
         (X => 1.1E+19, Y => -1.0),
         (X => 1.1E+19, Y => 1.0),
         (X => 1.0E+19, Y => 1.0));
      Farthest : constant Points :=
        ((X => 3.0E+19, Y => 3.0E+19),
         (X => 3.1E+19, Y => 3.0E+19),
         (X => 3.1E+19, Y => 3.1E+19));

      procedure Measure_Farthest is
         Unused : constant OpenCV.Float64_Value :=
           Distance (Farthest, 0.0, 0.0);
         pragma Unreferenced (Unused);
      begin
         null;
      end Measure_Farthest;
   begin
      AUnit.Assertions.Assert
        (Close
           (Distance (Distant, 0.0, 0.0),
            -OpenCV.Float64_Value (Distant (Distant'First).X)),
         "a distance below Sqrt (FLT_MAX) must be reported");
      AUnit.Assertions.Assert
        (Locate (Farthest, 0.0, 0.0) = OpenCV.Geometry.Outside_Contour,
         "classification has no distance search limit");
      Support.Assert_Raises_OpenCV_Error
        (Measure_Farthest'Access,
         "a distance at OpenCV's Sqrt (FLT_MAX) search limit must raise");
   end Distance_Search_Limit;

   procedure Span_Limit (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Spans of 3.0E+38 keep OpenCV's binary32 differences finite; the
      --  query (0, 1) lies inside.
      Wide     : constant Points :=
        ((X => -1.5E+38, Y => 0.0),
         (X => 1.5E+38, Y => 10.0),
         (X => 1.5E+38, Y => 0.0));
      --  Spans of 4.0E+38 overflow them, and OpenCV would report the inside
      --  query (0, 1) as outside.
      Too_Wide : constant Points :=
        ((X => -2.0E+38, Y => 0.0),
         (X => 2.0E+38, Y => 10.0),
         (X => 2.0E+38, Y => 0.0));

      procedure Locate_Too_Wide is
         Unused : constant Location := Locate (Too_Wide, 0.0, 1.0);
         pragma Unreferenced (Unused);
      begin
         null;
      end Locate_Too_Wide;

      procedure Measure_Too_Wide is
         Unused : constant OpenCV.Float64_Value :=
           Distance (Too_Wide, 0.0, 1.0);
         pragma Unreferenced (Unused);
      begin
         null;
      end Measure_Too_Wide;
   begin
      AUnit.Assertions.Assert
        (Locate (Wide, 0.0, 1.0) = OpenCV.Geometry.Inside_Contour
         and then Locate (Wide, 0.0, 6.0) = OpenCV.Geometry.Outside_Contour,
         "spans up to Float32_Value'Last must classify correctly");
      Support.Assert_Raises_OpenCV_Error
        (Locate_Too_Wide'Access,
         "a span above Float32_Value'Last must raise for Locate_Point");
      Support.Assert_Raises_OpenCV_Error
        (Measure_Too_Wide'Access,
         "a span above Float32_Value'Last must raise for the distance");
   end Span_Limit;

   procedure Locate_Candidate (Candidate : Points) is
      Unused : constant Location :=
        OpenCV.Geometry.Locate_Point (Candidate, Q (1.0, 1.0));
      pragma Unreferenced (Unused);
   begin
      null;
   end Locate_Candidate;

   procedure Measure_Candidate (Candidate : Points) is
      Unused : constant OpenCV.Float64_Value :=
        OpenCV.Geometry.Signed_Distance_To_Contour (Candidate, Q (1.0, 1.0));
      pragma Unreferenced (Unused);
   begin
      null;
   end Measure_Candidate;

   procedure Non_Finite_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Non-finite queries are built here by design.
      pragma Suppress (Validity_Check);
      Shifted : constant Points (2 .. 5) := Square;
      Empty   : constant Points (1 .. 0) := (others => (0.0, 0.0));

      procedure Locate_NaN_Query is
         Unused : constant Location :=
           OpenCV.Geometry.Locate_Point (Square, Q (Support.NaN_32, 1.0));
         pragma Unreferenced (Unused);
      begin
         null;
      end Locate_NaN_Query;

      procedure Measure_Infinite_Query is
         Unused : constant OpenCV.Float64_Value :=
           OpenCV.Geometry.Signed_Distance_To_Contour
             (Square, Q (1.0, Support.Negative_Infinity_32));
         pragma Unreferenced (Unused);
      begin
         null;
      end Measure_Infinite_Query;

      procedure Locate_Infinite_Query_In_Empty is
         Unused : constant Location :=
           OpenCV.Geometry.Locate_Point (Empty, Q (Support.Infinity_32, 0.0));
         pragma Unreferenced (Unused);
      begin
         null;
      end Locate_Infinite_Query_In_Empty;
   begin
      Support.Assert_Rejects_Non_Finite
        (Shifted, Locate_Candidate'Access, "Locate_Point");
      Support.Assert_Rejects_Non_Finite
        (Shifted, Measure_Candidate'Access, "Signed_Distance_To_Contour");
      Support.Assert_Raises_OpenCV_Error
        (Locate_NaN_Query'Access, "a NaN query must raise");
      Support.Assert_Raises_OpenCV_Error
        (Measure_Infinite_Query'Access, "an infinite query must raise");
      Support.Assert_Raises_OpenCV_Error
        (Locate_Infinite_Query_In_Empty'Access,
         "an infinite query must raise even for an empty polygon");
   end Non_Finite_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Raw queries bypass the Ada policy; NaN is passed directly.
      pragma Suppress (Validity_Check);
      Packed : aliased C_API.Point_F32_Array := Support.Pack (Square);
      Value  : aliased Interfaces.C.double := 7.0;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Point_Polygon_Test_F32
          (null, -1, 0.0, 0.0, C_API.Point_Polygon_Classify, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("count")
         and then Value = 0.0,
         "negative count must be rejected with a zero result");
      Status :=
        C_API.Point_Polygon_Test_F32
          (null, 3, 0.0, 0.0, C_API.Point_Polygon_Classify, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("points"),
         "null points with positive count must be rejected");
      Status :=
        C_API.Point_Polygon_Test_F32
          (Packed (Packed'First)'Access, 4, 1.0, 1.0, 2, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("mode"),
         "invalid mode selector must be rejected");
      Status :=
        C_API.Point_Polygon_Test_F32
          (null, 0, 0.0, 0.0, C_API.Point_Polygon_Classify, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Has_Message ("output"),
         "null output must be rejected");
      Status :=
        C_API.Point_Polygon_Test_F32
          (null,
           0,
           Support.NaN_C,
           0.0,
           C_API.Point_Polygon_Distance,
           Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Value = -Interfaces.C.double'Last,
         "an empty polygon returns -DBL_MAX without rounding the query");
      Status :=
        C_API.Point_Polygon_Test_F32
          (Packed (Packed'First)'Access,
           4,
           Support.NaN_C,
           0.0,
           C_API.Point_Polygon_Classify,
           Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("cvRound"),
         "a NaN query must be rejected before native cvRound");
      Status :=
        C_API.Point_Polygon_Test_F32
          (Packed (Packed'First)'Access,
           4,
           0.0,
           3.0E+9,
           C_API.Point_Polygon_Distance,
           Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Has_Message ("cvRound"),
         "a query beyond the int range must be rejected before cvRound");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Float32 point test fractional square", Fractional_Square'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test fractional diagonal",
            Fractional_Diagonal'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test orientation independent",
            Orientation_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test empty and minimal", Empty_And_Minimal'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test equals integer overloads",
            Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test matches raw C ABI", Matches_Raw_C_ABI'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test nonzero bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create ("Float32 point test query range", Query_Range'Access));
      Result.Add_Test
        (Caller.Create ("Float32 point test span limit", Span_Limit'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test distance search limit",
            Distance_Search_Limit'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test rejects non-finite values",
            Non_Finite_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Float32 point test C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Float32_Point_Polygon_Tests;
