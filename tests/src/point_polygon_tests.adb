with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Point_Polygon_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Float64_Value;
   use type OpenCV.Core.Point_Coordinate;
   use type OpenCV.Core.Point;
   use type OpenCV.Geometry.Contour_Point_Location;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Absolute_Tolerance : constant OpenCV.Core.Float64_Value := 1.0E-12;
   Relative_Tolerance : constant OpenCV.Core.Float64_Value := 1.0E-9;

   Square : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 4), (X => 0, Y => 4));

   Clockwise : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 0, Y => 4), (X => 4, Y => 4), (X => 4, Y => 0));

   Negative : constant OpenCV.Geometry.Contour :=
     ((X => -10, Y => -10),
      (X => -6, Y => -10),
      (X => -6, Y => -6),
      (X => -10, Y => -6));

   Diagonal : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 4), (X => 0, Y => 4));

   function Q
     (X, Y : OpenCV.Core.Float32_Value) return OpenCV.Core.Float32_Point
   is ((X => X, Y => Y));

   function Close (Left, Right : OpenCV.Core.Float64_Value) return Boolean is
      Difference : constant OpenCV.Core.Float64_Value := abs (Left - Right);
      Scale      : constant OpenCV.Core.Float64_Value :=
        OpenCV.Core.Float64_Value'Max (abs (Left), abs (Right));
   begin
      return
        Difference <= Absolute_Tolerance
        or else Difference <= Relative_Tolerance * Scale;
   end Close;

   procedure Assert_Close
     (Actual, Expected : OpenCV.Core.Float64_Value; Message : String) is
   begin
      AUnit.Assertions.Assert (Close (Actual, Expected), Message);
   end Assert_Close;

   procedure Assert_Location
     (Points   : OpenCV.Geometry.Contour;
      Query    : OpenCV.Core.Float32_Point;
      Expected : OpenCV.Geometry.Contour_Point_Location;
      Message  : String) is
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Locate_Point (Points, Query) = Expected, Message);
   end Assert_Location;

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

   procedure Inside_Square (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square,
         Q (2.0, 2.0),
         OpenCV.Geometry.Inside_Contour,
         "inside square");
   end Inside_Square;

   procedure Outside_Square (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square,
         Q (10.0, 10.0),
         OpenCV.Geometry.Outside_Contour,
         "outside square");
   end Outside_Square;

   procedure Horizontal_Edge (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square,
         Q (2.0, 0.0),
         OpenCV.Geometry.On_Contour_Boundary,
         "horizontal edge");
   end Horizontal_Edge;

   procedure Vertical_Edge (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square,
         Q (0.0, 2.0),
         OpenCV.Geometry.On_Contour_Boundary,
         "vertical edge");
   end Vertical_Edge;

   procedure Vertex (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square, Q (0.0, 0.0), OpenCV.Geometry.On_Contour_Boundary, "vertex");
   end Vertex;

   procedure Fractional_Inside (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square,
         Q (1.5, 1.5),
         OpenCV.Geometry.Inside_Contour,
         "fractional inside");
   end Fractional_Inside;

   procedure Fractional_Outside (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square,
         Q (4.1, 2.0),
         OpenCV.Geometry.Outside_Contour,
         "fractional outside");
   end Fractional_Outside;

   procedure Diagonal_Edge (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Diagonal,
         Q (2.0, 2.0),
         OpenCV.Geometry.On_Contour_Boundary,
         "diagonal edge");
   end Diagonal_Edge;

   procedure Clockwise_Inside (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Clockwise,
         Q (2.0, 2.0),
         OpenCV.Geometry.Inside_Contour,
         "clockwise inside");
   end Clockwise_Inside;

   procedure Counterclockwise_Inside (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Square,
         Q (2.0, 2.0),
         OpenCV.Geometry.Inside_Contour,
         "counterclockwise inside");
   end Counterclockwise_Inside;

   procedure Translated_Negative (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Location
        (Negative,
         Q (-8.0, -8.0),
         OpenCV.Geometry.Inside_Contour,
         "negative inside");
      Assert_Location
        (Negative,
         Q (-12.0, -8.0),
         OpenCV.Geometry.Outside_Contour,
         "negative outside");
   end Translated_Negative;

   procedure Empty_Classification (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
   begin
      Assert_Location
        (Empty, Q (0.0, 0.0), OpenCV.Geometry.Outside_Contour, "empty class");
   end Empty_Classification;

   procedure One_Point (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Point : constant OpenCV.Geometry.Contour := (1 => (X => 2, Y => 2));
   begin
      Assert_Location
        (Point, Q (2.0, 2.0), OpenCV.Geometry.On_Contour_Boundary, "one on");
      Assert_Location
        (Point, Q (0.0, 0.0), OpenCV.Geometry.Outside_Contour, "one out");
   end One_Point;

   procedure Two_Point (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Line : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
   begin
      Assert_Location
        (Line, Q (2.0, 0.0), OpenCV.Geometry.On_Contour_Boundary, "line on");
      Assert_Location
        (Line, Q (2.0, 1.0), OpenCV.Geometry.Outside_Contour, "line out");
   end Two_Point;

   procedure Repeated_Closing_Vertex (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Closed : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 4),
         (X => 0, Y => 4),
         (X => 0, Y => 0));
   begin
      Assert_Location
        (Closed,
         Q (2.0, 2.0),
         OpenCV.Geometry.Inside_Contour,
         "closed inside");
   end Repeated_Closing_Vertex;

   procedure Nonzero_Bounds_Classification (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant OpenCV.Geometry.Contour (5 .. 8) := Square;
   begin
      Assert_Location
        (Shifted,
         Q (2.0, 2.0),
         OpenCV.Geometry.Inside_Contour,
         "nonzero class");
   end Nonzero_Bounds_Classification;

   procedure Classification_Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Square;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Location : constant OpenCV.Geometry.Contour_Point_Location :=
        OpenCV.Geometry.Locate_Point (Points, Q (2.0, 2.0));
   begin
      AUnit.Assertions.Assert
        (Same_Contour (Points, Original), "classification leaves input");
      AUnit.Assertions.Assert
        (Location = OpenCV.Geometry.Inside_Contour, "unchanged still inside");
   end Classification_Input_Unchanged;

   procedure Inside_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Square, Q (2.0, 2.0)),
         2.0,
         "inside distance");
   end Inside_Distance;

   procedure Outside_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Square, Q (2.0, -1.0)),
         -1.0,
         "outside distance");
   end Outside_Distance;

   procedure Boundary_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Square, Q (2.0, 0.0)),
         0.0,
         "boundary distance");
   end Boundary_Distance;

   procedure Fractional_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Square, Q (2.0, 0.5)),
         0.5,
         "fractional distance");
   end Fractional_Distance;

   procedure Vertex_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Square, Q (5.0, 5.0)),
         -1.4142135623730951,
         "vertex-nearest distance");
   end Vertex_Distance;

   procedure Edge_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Square, Q (6.0, 2.0)),
         -2.0,
         "edge-nearest distance");
   end Edge_Distance;

   procedure Translated_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Negative, Q (-8.0, -8.0)),
         2.0,
         "translated inside distance");
   end Translated_Distance;

   procedure Orientation_Independent_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Clockwise, Q (2.0, 2.0)),
         OpenCV.Geometry.Signed_Distance_To_Contour (Square, Q (2.0, 2.0)),
         "orientation independent distance");
   end Orientation_Independent_Distance;

   procedure Empty_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Signed_Distance_To_Contour (Empty, Q (0.0, 0.0))
         = -OpenCV.Core.Float64_Value'Last,
         "empty distance is -Float64_Value'Last");
   end Empty_Distance;

   procedure One_Point_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Point : constant OpenCV.Geometry.Contour := (1 => (X => 2, Y => 2));
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Point, Q (2.0, 2.0)),
         0.0,
         "one-point on distance");
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Point, Q (2.0, 3.0)),
         -1.0,
         "one-point outside distance");
   end One_Point_Distance;

   procedure Nonzero_Bounds_Distance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant OpenCV.Geometry.Contour (3 .. 6) := Square;
   begin
      Assert_Close
        (OpenCV.Geometry.Signed_Distance_To_Contour (Shifted, Q (2.0, 2.0)),
         2.0,
         "nonzero bounds distance");
   end Nonzero_Bounds_Distance;

   procedure Distance_Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Square;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Distance : constant OpenCV.Core.Float64_Value :=
        OpenCV.Geometry.Signed_Distance_To_Contour (Points, Q (2.0, 2.0));
   begin
      AUnit.Assertions.Assert
        (Same_Contour (Points, Original), "distance leaves input");
      Assert_Close (Distance, 2.0, "unchanged still 2.0");
   end Distance_Input_Unchanged;

   procedure Query_Precision_Matters (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Fractional : constant OpenCV.Geometry.Contour_Point_Location :=
        OpenCV.Geometry.Locate_Point (Square, Q (3.6, 2.0));
      Rounded    : constant OpenCV.Geometry.Contour_Point_Location :=
        OpenCV.Geometry.Locate_Point (Square, Q (4.0, 2.0));
   begin
      AUnit.Assertions.Assert
        (Fractional = OpenCV.Geometry.Inside_Contour,
         "3.6,2 is inside without rounding");
      AUnit.Assertions.Assert
        (Rounded = OpenCV.Geometry.On_Contour_Boundary,
         "4,2 is on the boundary");
      AUnit.Assertions.Assert
        (Fractional /= Rounded, "query precision must change the result");
   end Query_Precision_Matters;

   procedure Safe_Integral_Fast_Path (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Last   : constant OpenCV.Core.Point_Coordinate :=
        OpenCV.Core.Point_Coordinate (Interfaces.Integer_32'Last);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => Last, Y => 0),
         (X => Last, Y => 1),
         (X => 0, Y => 1));
   begin
      Assert_Location
        (Points,
         Q (1.0, 0.0),
         OpenCV.Geometry.On_Contour_Boundary,
         "safe large contour integral query");
   end Safe_Integral_Fast_Path;

   procedure Unsafe_Integral_Delta (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => 0, Y => 0),
         (X => 0, Y => 1),
         (X => Interfaces.Integer_32'First, Y => 1));
      Output : aliased Interfaces.C.double := -7.0;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Point_Polygon_Test
          (Buffer (Buffer'First)'Access,
           Interfaces.Integer_32 (Buffer'Length),
           0.0,
           0.0,
           C_API.Point_Polygon_Classify,
           Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "unsafe delta status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "range") /= 0,
         "unsafe delta diagnostic");
      AUnit.Assertions.Assert (Output = 0.0, "unsafe delta zeros output");
   end Unsafe_Integral_Delta;

   procedure Fractional_Bypasses_Integer_Path (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => 0, Y => 0),
         (X => 0, Y => 1),
         (X => Interfaces.Integer_32'First, Y => 1));
      Output : aliased Interfaces.C.double := -7.0;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Point_Polygon_Test
          (Buffer (Buffer'First)'Access,
           Interfaces.Integer_32 (Buffer'Length),
           0.5,
           0.5,
           C_API.Point_Polygon_Classify,
           Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "fractional query must reach OpenCV");
      AUnit.Assertions.Assert
        (Output = -1.0, "fractional extreme query is outside this contour");
   end Fractional_Bypasses_Integer_Path;

   procedure Distance_Bypasses_Integer_Path (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => 0, Y => 0),
         (X => 0, Y => 1),
         (X => Interfaces.Integer_32'First, Y => 1));
      Output : aliased Interfaces.C.double := -7.0;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Point_Polygon_Test
          (Buffer (Buffer'First)'Access,
           Interfaces.Integer_32 (Buffer'Length),
           0.0,
           0.0,
           C_API.Point_Polygon_Distance,
           Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success,
         "distance mode must not inherit class limits");
   end Distance_Bypasses_Integer_Path;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 4),
         (X => 0, Y => 4));
      Output : aliased Interfaces.C.double := -1.0;
      Status : C_API.Status;

      procedure Assert_Rejected
        (Call_Status : C_API.Status; Needle : String; Message : String) is
      begin
         AUnit.Assertions.Assert
           (Call_Status = C_API.Error_Invalid_Argument, Message & ": status");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Needle) /= 0,
            Message & ": diagnostic");
         AUnit.Assertions.Assert (Output = 0.0, Message & ": output reset");
      end Assert_Rejected;
   begin
      Output := -1.0;
      Status :=
        C_API.Point_Polygon_Test
          (Points (Points'First)'Access,
           -1,
           2.0,
           2.0,
           C_API.Point_Polygon_Classify,
           Output'Access);
      Assert_Rejected (Status, "count", "negative count");

      Output := -1.0;
      Status :=
        C_API.Point_Polygon_Test
          (null, 4, 2.0, 2.0, C_API.Point_Polygon_Classify, Output'Access);
      Assert_Rejected (Status, "null", "null points");

      Status :=
        C_API.Point_Polygon_Test
          (Points (Points'First)'Access,
           4,
           2.0,
           2.0,
           C_API.Point_Polygon_Classify,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null output status");

      Output := -1.0;
      Status :=
        C_API.Point_Polygon_Test
          (Points (Points'First)'Access, 4, 2.0, 2.0, -1, Output'Access);
      Assert_Rejected (Status, "mode", "invalid mode -1");

      Output := -1.0;
      Status :=
        C_API.Point_Polygon_Test
          (Points (Points'First)'Access, 4, 2.0, 2.0, 2, Output'Access);
      Assert_Rejected (Status, "mode", "invalid mode 2");

      Output := -1.0;
      Status :=
        C_API.Point_Polygon_Test
          (Points (Points'First)'Access,
           4,
           2.0,
           2.0,
           C_API.Point_Polygon_Classify,
           Output'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "ABI class succeeds");
      AUnit.Assertions.Assert (Output = 1.0, "ABI class inside");

      Output := -1.0;
      Status :=
        C_API.Point_Polygon_Test
          (Points (Points'First)'Access,
           4,
           2.0,
           2.0,
           C_API.Point_Polygon_Distance,
           Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "ABI distance succeeds");
      AUnit.Assertions.Assert (Output = 2.0, "ABI distance inside");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Locate point inside square", Inside_Square'Access));
      Result.Add_Test
        (Caller.Create ("Locate point outside square", Outside_Square'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point horizontal edge", Horizontal_Edge'Access));
      Result.Add_Test
        (Caller.Create ("Locate point vertical edge", Vertical_Edge'Access));
      Result.Add_Test (Caller.Create ("Locate point vertex", Vertex'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point fractional inside", Fractional_Inside'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point fractional outside", Fractional_Outside'Access));
      Result.Add_Test
        (Caller.Create ("Locate point diagonal edge", Diagonal_Edge'Access));
      Result.Add_Test
        (Caller.Create ("Locate point clockwise", Clockwise_Inside'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point counterclockwise", Counterclockwise_Inside'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point translated negative", Translated_Negative'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point empty contour", Empty_Classification'Access));
      Result.Add_Test
        (Caller.Create ("Locate point one-point contour", One_Point'Access));
      Result.Add_Test
        (Caller.Create ("Locate point two-point contour", Two_Point'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point repeated closing vertex",
            Repeated_Closing_Vertex'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point nonzero bounds",
            Nonzero_Bounds_Classification'Access));
      Result.Add_Test
        (Caller.Create
           ("Locate point leaves input unchanged",
            Classification_Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance inside square", Inside_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance outside square", Outside_Distance'Access));
      Result.Add_Test
        (Caller.Create ("Signed distance boundary", Boundary_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance fractional", Fractional_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance vertex nearest", Vertex_Distance'Access));
      Result.Add_Test
        (Caller.Create ("Signed distance edge nearest", Edge_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance translated", Translated_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance orientation independent",
            Orientation_Independent_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance empty contour", Empty_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance one-point contour", One_Point_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance nonzero bounds", Nonzero_Bounds_Distance'Access));
      Result.Add_Test
        (Caller.Create
           ("Signed distance leaves input unchanged",
            Distance_Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Query precision is preserved", Query_Precision_Matters'Access));
      Result.Add_Test
        (Caller.Create
           ("Safe integral fast path", Safe_Integral_Fast_Path'Access));
      Result.Add_Test
        (Caller.Create
           ("Unsafe integral delta rejected", Unsafe_Integral_Delta'Access));
      Result.Add_Test
        (Caller.Create
           ("Fractional query bypasses integer path",
            Fractional_Bypasses_Integer_Path'Access));
      Result.Add_Test
        (Caller.Create
           ("Distance mode bypasses integer path",
            Distance_Bypasses_Integer_Path'Access));
      Result.Add_Test
        (Caller.Create
           ("Point polygon C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Point_Polygon_Tests;
