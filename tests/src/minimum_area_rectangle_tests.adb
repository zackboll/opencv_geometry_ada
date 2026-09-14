with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Minimum_Area_Rectangle_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Core.Float32_Value;
   use type OpenCV.Core.Point;
   use type OpenCV.Core.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Tolerance : constant OpenCV.Core.Float32_Value := 1.0E-4;

   function Is_OpenCV_5 return Boolean is
   begin
      return C_API.OpenCV_Major_Version = 5;
   end Is_OpenCV_5;

   function Close (Left, Right : OpenCV.Core.Float32_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Close;

   procedure Assert_Rect
     (Actual                       : OpenCV.Core.Rotated_Rect;
      Center_X, Center_Y           : OpenCV.Core.Float32_Value;
      Width, Height, Angle_Degrees : OpenCV.Core.Float32_Value;
      Message                      : String)
   is
      function Detail
        (Name : String; Actual, Expected : OpenCV.Core.Float32_Value)
         return String is
      begin
         return
           Message
           & ": "
           & Name
           & " actual="
           & OpenCV.Core.Float32_Value'Image (Actual)
           & " expected="
           & OpenCV.Core.Float32_Value'Image (Expected);
      end Detail;
   begin
      AUnit.Assertions.Assert
        (Close (Actual.Center.X, Center_X),
         Detail ("X", Actual.Center.X, Center_X));
      AUnit.Assertions.Assert
        (Close (Actual.Center.Y, Center_Y),
         Detail ("Y", Actual.Center.Y, Center_Y));
      AUnit.Assertions.Assert
        (Close (Actual.Size.Width, Width),
         Detail ("width", Actual.Size.Width, Width));
      AUnit.Assertions.Assert
        (Close (Actual.Size.Height, Height),
         Detail ("height", Actual.Size.Height, Height));
      AUnit.Assertions.Assert
        (Close (Actual.Angle_Degrees, Angle_Degrees),
         Detail ("angle", Actual.Angle_Degrees, Angle_Degrees));
   end Assert_Rect;

   function Same_Contour (Left, Right : OpenCV.Geometry.Contour) return Boolean
   is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      for Offset in 0 .. Left'Length - 1 loop
         if Left (Left'First + Offset) /= Right (Right'First + Offset) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Contour;

   procedure Axis_Aligned_Rectangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 6, Y => 0),
         (X => 6, Y => 4),
         (X => 0, Y => 4));
   begin
      if Is_OpenCV_5 then
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Points),
            3.0,
            2.0,
            4.0,
            6.0,
            -90.0,
            "axis-aligned rectangle");
      else
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Points),
            3.0,
            2.0,
            4.0,
            6.0,
            90.0,
            "axis-aligned rectangle");
      end if;
   end Axis_Aligned_Rectangle;

   procedure Diamond (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 2),
         (X => 2, Y => 0),
         (X => 4, Y => 2),
         (X => 2, Y => 4));
      Actual : constant OpenCV.Core.Rotated_Rect :=
        OpenCV.Geometry.Minimum_Area_Rectangle (Points);
   begin
      AUnit.Assertions.Assert (Close (Actual.Center.X, 2.0), "diamond X");
      AUnit.Assertions.Assert (Close (Actual.Center.Y, 2.0), "diamond Y");
      AUnit.Assertions.Assert
        (Close (Actual.Size.Width, 2.828427), "diamond width");
      AUnit.Assertions.Assert
        (Close (Actual.Size.Height, 2.828427), "diamond height");
      AUnit.Assertions.Assert
        (Close (Actual.Angle_Degrees, (if Is_OpenCV_5 then -45.0 else 45.0)),
         "diamond angle");
   end Diamond;

   procedure Empty_And_One_Point (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : OpenCV.Geometry.Contour (1 .. 0);
      Point : constant OpenCV.Geometry.Contour := (0 => (X => -3, Y => 7));
   begin
      declare
         Angle : constant OpenCV.Core.Float32_Value :=
           (if Is_OpenCV_5 then -90.0 else 0.0);
      begin
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Empty),
            0.0,
            0.0,
            0.0,
            0.0,
            Angle,
            "empty");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Point),
            -3.0,
            7.0,
            0.0,
            0.0,
            Angle,
            "one point");
      end;
   end Empty_And_One_Point;

   procedure Two_Point_Conventions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Horizontal : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 6, Y => 0));
      Vertical   : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 0, Y => 4));
      Positive   : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 3, Y => 4));
      Negative   : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 3, Y => -4));
   begin
      if Is_OpenCV_5 then
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Horizontal),
            3.0,
            0.0,
            0.0,
            6.0,
            -90.0,
            "horizontal pair");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Vertical),
            0.0,
            2.0,
            4.0,
            0.0,
            -90.0,
            "vertical pair");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Positive),
            1.5,
            2.0,
            0.0,
            5.0,
            -36.869896,
            "positive pair");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Negative),
            1.5,
            -2.0,
            5.0,
            0.0,
            -53.130102,
            "negative pair");
      else
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Horizontal),
            3.0,
            0.0,
            6.0,
            0.0,
            180.0,
            "horizontal pair");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Vertical),
            0.0,
            2.0,
            4.0,
            0.0,
            -90.0,
            "vertical pair");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Positive),
            1.5,
            2.0,
            5.0,
            0.0,
            -126.869896,
            "positive pair");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Negative),
            1.5,
            -2.0,
            5.0,
            0.0,
            126.869896,
            "negative pair");
      end if;
   end Two_Point_Conventions;

   procedure Collinear_Duplicates_And_Translation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Collinear  : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 2, Y => 0),
         (X => 4, Y => 0),
         (X => 2, Y => 0));
      Translated : constant OpenCV.Geometry.Contour :=
        ((X => -10, Y => 5),
         (X => -4, Y => 5),
         (X => -4, Y => 9),
         (X => -10, Y => 9));
   begin
      if Is_OpenCV_5 then
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Collinear),
            2.0,
            0.0,
            0.0,
            4.0,
            -90.0,
            "collinear");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Translated),
            -7.0,
            7.0,
            4.0,
            6.0,
            -90.0,
            "translated");
      else
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Collinear),
            2.0,
            0.0,
            4.0,
            0.0,
            180.0,
            "collinear");
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Translated),
            -7.0,
            7.0,
            4.0,
            6.0,
            90.0,
            "translated");
      end if;
   end Collinear_Duplicates_And_Translation;

   procedure Nonzero_Bounds_And_Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour (11 .. 14) :=
        (11 => (X => 0, Y => 0),
         12 => (X => 6, Y => 0),
         13 => (X => 6, Y => 4),
         14 => (X => 0, Y => 4));
      Before : constant OpenCV.Geometry.Contour := Points;
   begin
      if Is_OpenCV_5 then
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Points),
            3.0,
            2.0,
            4.0,
            6.0,
            -90.0,
            "nonzero bounds");
      else
         Assert_Rect
           (OpenCV.Geometry.Minimum_Area_Rectangle (Points),
            3.0,
            2.0,
            4.0,
            6.0,
            90.0,
            "nonzero bounds");
      end if;
      AUnit.Assertions.Assert
        (Same_Contour (Points, Before), "input unchanged");
   end Nonzero_Bounds_And_Input_Unchanged;

   procedure Binary32_Precision (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 16_777_217, Y => 0),
         (X => 16_777_223, Y => 0),
         (X => 16_777_223, Y => 4),
         (X => 16_777_217, Y => 4));
      Actual : constant OpenCV.Core.Rotated_Rect :=
        OpenCV.Geometry.Minimum_Area_Rectangle (Points);
   begin
      AUnit.Assertions.Assert (Actual.Size.Width > 0.0, "large width");
      AUnit.Assertions.Assert (Actual.Size.Height > 0.0, "large height");
   end Binary32_Precision;

   procedure C_ABI_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Safe     : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => -1, Y => 0),
         (X => -2, Y => 1));
      Unsafe_X : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => Interfaces.Integer_32'Last, Y => 0),
         (X => 0, Y => 1));
      Unsafe_Y : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => 0, Y => Interfaces.Integer_32'First),
         (X => 0, Y => Interfaces.Integer_32'Last),
         (X => 1, Y => 0));
      Output   : aliased C_API.C_Rotated_Rect :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status   : C_API.Status;
   begin
      Status := C_API.Min_Area_Rect (Safe (0)'Access, 3, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "safe full span status");
      Output :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status := C_API.Min_Area_Rect (Unsafe_X (0)'Access, 3, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "unsafe status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "arithmetic") /= 0,
         "unsafe diagnostic");
      AUnit.Assertions.Assert
        (Output.Center_X = 0.0
         and then Output.Center_Y = 0.0
         and then Output.Width = 0.0
         and then Output.Height = 0.0
         and then Output.Angle_Degrees = 0.0,
         "unsafe output zeroed");
      Output :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status := C_API.Min_Area_Rect (Unsafe_Y (0)'Access, 3, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "unsafe Y status");
      AUnit.Assertions.Assert
        (Output.Center_X = 0.0
         and then Output.Center_Y = 0.0
         and then Output.Width = 0.0
         and then Output.Height = 0.0
         and then Output.Angle_Degrees = 0.0,
         "unsafe Y output zeroed");
   end C_ABI_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Minimum area axis rectangle", Axis_Aligned_Rectangle'Access));
      Result.Add_Test (Caller.Create ("Minimum area diamond", Diamond'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum area empty and one point", Empty_And_One_Point'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum area two-point conventions",
            Two_Point_Conventions'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum area collinear duplicates translation",
            Collinear_Duplicates_And_Translation'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum area nonzero bounds input unchanged",
            Nonzero_Bounds_And_Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum area binary32 precision", Binary32_Precision'Access));
      Result.Add_Test
        (Caller.Create ("Minimum area C ABI safety", C_ABI_Safety'Access));
      return Result'Access;
   end Suite;

end Minimum_Area_Rectangle_Tests;
