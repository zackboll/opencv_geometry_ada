with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Fit_Ellipse_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point;
   use type OpenCV.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Center_Tolerance : constant OpenCV.Float32_Value := 0.75;
   Size_Tolerance   : constant OpenCV.Float32_Value := 1.5;
   Angle_Tolerance  : constant OpenCV.Float32_Value := 5.0;

   --  Integer samples of x^2/20^2 + y^2/10^2 = 1. Full axes are 40 and 20.
   Axis_Aligned : constant OpenCV.Geometry.Contour :=
     ((X => 20, Y => 0),
      (X => -20, Y => 0),
      (X => 0, Y => 10),
      (X => 0, Y => -10),
      (X => 16, Y => 6),
      (X => 16, Y => -6),
      (X => -16, Y => 6),
      (X => -16, Y => -6),
      (X => 12, Y => 8),
      (X => 12, Y => -8),
      (X => -12, Y => 8),
      (X => -12, Y => -8));

   Five_Points : constant OpenCV.Geometry.Contour :=
     ((X => 20, Y => 0),
      (X => -20, Y => 0),
      (X => 0, Y => 10),
      (X => 0, Y => -10),
      (X => 16, Y => 6));

   Rotated : constant OpenCV.Geometry.Contour :=
     ((X => 14, Y => 14),
      (X => -14, Y => -14),
      (X => -7, Y => 7),
      (X => 7, Y => -7),
      (X => 7, Y => 16),
      (X => -7, Y => -16),
      (X => 16, Y => 7),
      (X => -16, Y => -7));

   Translated : constant OpenCV.Geometry.Contour :=
     ((X => -30, Y => 30),
      (X => -70, Y => 30),
      (X => -50, Y => 40),
      (X => -50, Y => 20),
      (X => -34, Y => 36),
      (X => -34, Y => 24),
      (X => -66, Y => 36),
      (X => -66, Y => 24),
      (X => -38, Y => 38),
      (X => -38, Y => 22),
      (X => -62, Y => 38),
      (X => -62, Y => 22));

   Reversed : constant OpenCV.Geometry.Contour :=
     ((X => -12, Y => -8),
      (X => -12, Y => 8),
      (X => 12, Y => -8),
      (X => 12, Y => 8),
      (X => -16, Y => -6),
      (X => -16, Y => 6),
      (X => 16, Y => -6),
      (X => 16, Y => 6),
      (X => 0, Y => -10),
      (X => 0, Y => 10),
      (X => -20, Y => 0),
      (X => 20, Y => 0));

   function Close
     (Left, Right : OpenCV.Float32_Value; Tolerance : OpenCV.Float32_Value)
      return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Close;

   function Angle_Distance
     (Left, Right : OpenCV.Float32_Value) return OpenCV.Float32_Value
   is
      Diff : OpenCV.Float32_Value := abs (Left - Right);
   begin
      while Diff >= 180.0 loop
         Diff := Diff - 180.0;
      end loop;
      if Diff > 90.0 then
         Diff := 180.0 - Diff;
      end if;
      return Diff;
   end Angle_Distance;

   function Same_Ellipse
     (Left, Right : OpenCV.Rotated_Rect;
      Center_Tol  : OpenCV.Float32_Value := Center_Tolerance;
      Size_Tol    : OpenCV.Float32_Value := Size_Tolerance;
      Angle_Tol   : OpenCV.Float32_Value := Angle_Tolerance) return Boolean
   is
      Direct_Match : Boolean;
      Swapped      : Boolean;
   begin
      if not Close (Left.Center.X, Right.Center.X, Center_Tol)
        or else not Close (Left.Center.Y, Right.Center.Y, Center_Tol)
      then
         return False;
      end if;

      Direct_Match :=
        Close (Left.Size.Width, Right.Size.Width, Size_Tol)
        and then Close (Left.Size.Height, Right.Size.Height, Size_Tol)
        and then Angle_Distance (Left.Angle_Degrees, Right.Angle_Degrees)
                 <= Angle_Tol;
      Swapped :=
        Close (Left.Size.Width, Right.Size.Height, Size_Tol)
        and then Close (Left.Size.Height, Right.Size.Width, Size_Tol)
        and then Angle_Distance
                   (Left.Angle_Degrees, Right.Angle_Degrees + 90.0)
                 <= Angle_Tol;
      return Direct_Match or else Swapped;
   end Same_Ellipse;

   procedure Assert_Same_Ellipse
     (Actual, Expected : OpenCV.Rotated_Rect; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Same_Ellipse (Actual, Expected),
         Message
         & ": actual=("
         & OpenCV.Float32_Value'Image (Actual.Center.X)
         & ","
         & OpenCV.Float32_Value'Image (Actual.Center.Y)
         & ","
         & OpenCV.Float32_Value'Image (Actual.Size.Width)
         & ","
         & OpenCV.Float32_Value'Image (Actual.Size.Height)
         & ","
         & OpenCV.Float32_Value'Image (Actual.Angle_Degrees)
         & ")");
   end Assert_Same_Ellipse;

   function Finite_Nonnegative (Value : OpenCV.Rotated_Rect) return Boolean is
   begin
      return Value.Size.Width >= 0.0 and then Value.Size.Height >= 0.0;
   end Finite_Nonnegative;

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

   procedure Assert_Raises_OpenCV_Error
     (Attempt : not null access procedure; Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      AUnit.Assertions.Assert (Raised, Message);
   end Assert_Raises_OpenCV_Error;

   procedure Axis_Aligned_Ellipse (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Same_Ellipse
        (OpenCV.Geometry.Fit_Ellipse (Axis_Aligned),
         (Center        => (X => 0.0, Y => 0.0),
          Size          => (Width => 40.0, Height => 20.0),
          Angle_Degrees => 0.0),
         "axis-aligned ellipse");
   end Axis_Aligned_Ellipse;

   procedure Rotated_Ellipse (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse (Rotated);
   begin
      Assert_Same_Ellipse
        (Actual,
         (Center        => (X => 0.0, Y => 0.0),
          Size          => (Width => 40.0, Height => 20.0),
          Angle_Degrees => 45.0),
         "rotated ellipse");
      AUnit.Assertions.Assert
        (Actual.Size.Width /= Actual.Size.Height,
         "rotated fixture must stay noncircular");
   end Rotated_Ellipse;

   procedure Exactly_Five_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Same_Ellipse
        (OpenCV.Geometry.Fit_Ellipse (Five_Points),
         (Center        => (X => 0.0, Y => 0.0),
          Size          => (Width => 40.0, Height => 20.0),
          Angle_Degrees => 0.0),
         "exactly five points");
   end Exactly_Five_Points;

   procedure More_Than_Five_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      AUnit.Assertions.Assert
        (Axis_Aligned'Length > 5, "fixture has more than five points");
      Assert_Same_Ellipse
        (OpenCV.Geometry.Fit_Ellipse (Axis_Aligned),
         (Center        => (X => 0.0, Y => 0.0),
          Size          => (Width => 40.0, Height => 20.0),
          Angle_Degrees => 0.0),
         "more than five points");
   end More_Than_Five_Points;

   procedure Translated_Negative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse (Translated);
   begin
      Assert_Same_Ellipse
        (Actual,
         (Center        => (X => -50.0, Y => 30.0),
          Size          => (Width => 40.0, Height => 20.0),
          Angle_Degrees => 0.0),
         "translated negative");
      AUnit.Assertions.Assert (Actual.Center.X < 0.0, "negative center X");
   end Translated_Negative;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour (11 .. 22) :=
        (11 => (X => 20, Y => 0),
         12 => (X => -20, Y => 0),
         13 => (X => 0, Y => 10),
         14 => (X => 0, Y => -10),
         15 => (X => 16, Y => 6),
         16 => (X => 16, Y => -6),
         17 => (X => -16, Y => 6),
         18 => (X => -16, Y => -6),
         19 => (X => 12, Y => 8),
         20 => (X => 12, Y => -8),
         21 => (X => -12, Y => 8),
         22 => (X => -12, Y => -8));
   begin
      Assert_Same_Ellipse
        (OpenCV.Geometry.Fit_Ellipse (Points),
         (Center        => (X => 0.0, Y => 0.0),
          Size          => (Width => 40.0, Height => 20.0),
          Angle_Degrees => 0.0),
         "nonzero Ada bounds");
   end Nonzero_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Warnings (Off, "could be declared constant");
      Points : OpenCV.Geometry.Contour := Axis_Aligned;
      pragma Warnings (On, "could be declared constant");
      Before : constant OpenCV.Geometry.Contour := Points;
      Unused : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse (Points);
      pragma Unreferenced (Unused);
   begin
      AUnit.Assertions.Assert
        (Same_Contour (Points, Before), "input unchanged");
   end Input_Unchanged;

   procedure Reordered_Equivalent (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Same_Ellipse
        (OpenCV.Geometry.Fit_Ellipse (Reversed),
         OpenCV.Geometry.Fit_Ellipse (Axis_Aligned),
         "reordered equivalent");
   end Reordered_Equivalent;

   procedure Fewer_Than_Five_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty   : OpenCV.Geometry.Contour (1 .. 0);
      One     : constant OpenCV.Geometry.Contour := (1 => (X => 1, Y => 1));
      Two     : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
      Three   : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0), (X => 0, Y => 3));
      Four    : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3));
      Discard : OpenCV.Rotated_Rect;

      procedure Call_Empty is
      begin
         Discard := OpenCV.Geometry.Fit_Ellipse (Empty);
      end Call_Empty;

      procedure Call_One is
      begin
         Discard := OpenCV.Geometry.Fit_Ellipse (One);
      end Call_One;

      procedure Call_Two is
      begin
         Discard := OpenCV.Geometry.Fit_Ellipse (Two);
      end Call_Two;

      procedure Call_Three is
      begin
         Discard := OpenCV.Geometry.Fit_Ellipse (Three);
      end Call_Three;

      procedure Call_Four is
      begin
         Discard := OpenCV.Geometry.Fit_Ellipse (Four);
      end Call_Four;
   begin
      Assert_Raises_OpenCV_Error (Call_Empty'Access, "empty");
      Assert_Raises_OpenCV_Error (Call_One'Access, "one point");
      Assert_Raises_OpenCV_Error (Call_Two'Access, "two points");
      Assert_Raises_OpenCV_Error (Call_Three'Access, "three points");
      Assert_Raises_OpenCV_Error (Call_Four'Access, "four points");
   end Fewer_Than_Five_Points;

   procedure Repeated_And_Collinear (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Repeated  : constant OpenCV.Geometry.Contour :=
        ((X => 3, Y => 4),
         (X => 3, Y => 4),
         (X => 3, Y => 4),
         (X => 3, Y => 4),
         (X => 3, Y => 4));
      Collinear : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 2, Y => 0),
         (X => 4, Y => 0),
         (X => 6, Y => 0),
         (X => 8, Y => 0));
   begin
      begin
         declare
            Actual : constant OpenCV.Rotated_Rect :=
              OpenCV.Geometry.Fit_Ellipse (Repeated);
         begin
            AUnit.Assertions.Assert
              (Finite_Nonnegative (Actual), "repeated finite");
         end;
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end;

      begin
         declare
            Actual : constant OpenCV.Rotated_Rect :=
              OpenCV.Geometry.Fit_Ellipse (Collinear);
         begin
            AUnit.Assertions.Assert
              (Finite_Nonnegative (Actual), "collinear finite");
         end;
      exception
         when OpenCV.OpenCV_Error =>
            null;
      end;
   end Repeated_And_Collinear;

   procedure C_ABI_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points         : aliased C_API.Point_I32_Array :=
        ((X => 20, Y => 0),
         (X => -20, Y => 0),
         (X => 0, Y => 10),
         (X => 0, Y => -10),
         (X => 16, Y => 6),
         (X => 16, Y => -6));
      Short          : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3));
      Output         : aliased C_API.C_Rotated_Rect :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status         : C_API.Status;
      Overflow_Count : constant Interfaces.Integer_32 :=
        Interfaces.Integer_32'Last / 13 + 1;

      procedure Assert_Zeroed (Message : String) is
      begin
         AUnit.Assertions.Assert
           (Output.Center_X = 0.0
            and then Output.Center_Y = 0.0
            and then Output.Width = 0.0
            and then Output.Height = 0.0
            and then Output.Angle_Degrees = 0.0,
            Message);
      end Assert_Zeroed;

      procedure Assert_Rejected
        (Actual : C_API.Status; Needle, Message : String) is
      begin
         AUnit.Assertions.Assert
           (Actual = C_API.Error_Invalid_Argument, Message & " status");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Needle) /= 0,
            Message & " diagnostic");
         Assert_Zeroed (Message & " output");
      end Assert_Rejected;
   begin
      Status := C_API.Fit_Ellipse (Points (0)'Access, 6, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null output status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "null") /= 0,
         "null output diagnostic");

      Output :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status := C_API.Fit_Ellipse (null, 6, Output'Access);
      Assert_Rejected (Status, "null", "null points");

      Output :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status := C_API.Fit_Ellipse (Points (0)'Access, -1, Output'Access);
      Assert_Rejected (Status, "negative", "negative count");

      Output :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status := C_API.Fit_Ellipse (null, Overflow_Count, Output'Access);
      Assert_Rejected (Status, "allocation", "overflow count");

      Output :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status := C_API.Fit_Ellipse (Short (0)'Access, 4, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV, "insufficient native status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "5 points") /= 0,
         "insufficient native diagnostic");
      Assert_Zeroed ("insufficient native output");

      Output :=
        (Center_X      => -1.0,
         Center_Y      => -1.0,
         Width         => -1.0,
         Height        => -1.0,
         Angle_Degrees => -1.0);
      Status := C_API.Fit_Ellipse (Points (0)'Access, 6, Output'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "recovery status");
      AUnit.Assertions.Assert
        (Output.Width >= 0.0 and then Output.Height >= 0.0, "recovery size");
      AUnit.Assertions.Assert
        (abs (Output.Center_X) < 2.0 and then abs (Output.Center_Y) < 2.0,
         "recovery center");
   end C_ABI_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse axis-aligned", Axis_Aligned_Ellipse'Access));
      Result.Add_Test
        (Caller.Create ("Fit ellipse rotated", Rotated_Ellipse'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse exactly five points", Exactly_Five_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse more than five points",
            More_Than_Five_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse translated negative", Translated_Negative'Access));
      Result.Add_Test
        (Caller.Create ("Fit ellipse nonzero bounds", Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse reordered equivalent", Reordered_Equivalent'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse fewer than five points",
            Fewer_Than_Five_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse repeated and collinear",
            Repeated_And_Collinear'Access));
      Result.Add_Test
        (Caller.Create ("Fit ellipse C ABI safety", C_ABI_Safety'Access));
      return Result'Access;
   end Suite;

end Fit_Ellipse_Tests;
