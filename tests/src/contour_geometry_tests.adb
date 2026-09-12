with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Contour_Geometry_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.C.double;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Float64_Value;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Rectangle : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3));

   procedure Assert_Equal
     (Actual, Expected : OpenCV.Core.Float64_Value; Message : String) is
   begin
      AUnit.Assertions.Assert (Actual = Expected, Message);
   end Assert_Equal;

   procedure Rectangle_Area_And_Length (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Equal
        (OpenCV.Geometry.Contour_Area (Rectangle),
         12.0,
         "rectangle area must be exact");
      Assert_Equal
        (OpenCV.Geometry.Arc_Length (Rectangle, Closed => True),
         14.0,
         "closed rectangle length must be exact");
      Assert_Equal
        (OpenCV.Geometry.Arc_Length (Rectangle, Closed => False),
         11.0,
         "open rectangle length must omit closing edge");
   end Rectangle_Area_And_Length;

   procedure Oriented_Area (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Reversed     : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 3),
         (X => 4, Y => 3),
         (X => 4, Y => 0),
         (X => 0, Y => 0));
      Forward_Area : constant OpenCV.Core.Float64_Value :=
        OpenCV.Geometry.Contour_Area (Rectangle, Oriented => True);
      Reverse_Area : constant OpenCV.Core.Float64_Value :=
        OpenCV.Geometry.Contour_Area (Reversed, Oriented => True);
   begin
      Assert_Equal
        (OpenCV.Geometry.Contour_Area (Reversed),
         12.0,
         "reversed rectangle absolute area must be exact");
      AUnit.Assertions.Assert
        (abs Forward_Area = abs Reverse_Area
         and then Forward_Area = -Reverse_Area,
         "reversing contour order must reverse oriented area sign");
   end Oriented_Area;

   procedure Degenerate_Contours (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty      : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
      One_Point  : constant OpenCV.Geometry.Contour :=
        (0 => OpenCV.Core.Point'(X => 0, Y => 0));
      Two_Points : constant OpenCV.Geometry.Contour :=
        (0 => OpenCV.Core.Point'(X => 0, Y => 0),
         1 => OpenCV.Core.Point'(X => 3, Y => 4));
   begin
      Assert_Equal
        (OpenCV.Geometry.Contour_Area (Empty),
         0.0,
         "empty contour area must be zero");
      Assert_Equal
        (OpenCV.Geometry.Arc_Length (Empty, Closed => False),
         0.0,
         "empty contour length must be zero");
      Assert_Equal
        (OpenCV.Geometry.Arc_Length (One_Point, Closed => True),
         0.0,
         "one-point contour length must be zero");
      Assert_Equal
        (OpenCV.Geometry.Arc_Length (Two_Points, Closed => False),
         5.0,
         "open two-point contour length must be its segment");
      Assert_Equal
        (OpenCV.Geometry.Arc_Length (Two_Points, Closed => True),
         10.0,
         "closed two-point contour length must include both segments");
      Assert_Equal
        (OpenCV.Geometry.Contour_Area (Two_Points),
         0.0,
         "two-point contour area must be zero");
   end Degenerate_Contours;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant OpenCV.Geometry.Contour (7 .. 10) := Rectangle;
   begin
      Assert_Equal
        (OpenCV.Geometry.Contour_Area (Shifted),
         OpenCV.Geometry.Contour_Area (Rectangle),
         "contour area must not depend on Ada array lower bound");
      Assert_Equal
        (OpenCV.Geometry.Arc_Length (Shifted, Closed => True),
         OpenCV.Geometry.Arc_Length (Rectangle, Closed => True),
         "arc length must not depend on Ada array lower bound");
   end Nonzero_Array_Bounds;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Value  : aliased Interfaces.C.double := -1.0;
      Status : C_API.Status;
   begin
      Status := C_API.Contour_Area (null, -1, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "negative contour point count must be rejected");
      Status := C_API.Contour_Area (null, 1, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "null points with positive count must be rejected");
      Status := C_API.Contour_Area (null, 0, 2, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "oriented")
                  /= 0,
         "invalid oriented selector must be rejected");
      Status := C_API.Arc_Length (null, 0, -1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "closed")
                  /= 0,
         "invalid closed selector must be rejected");
      Status := C_API.Arc_Length (null, -1, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "negative arc length count must be rejected");
      Status := C_API.Arc_Length (null, 1, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "null arc length points must be rejected");
      Status := C_API.Contour_Area (null, 0, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null area output must be rejected");
      Status := C_API.Arc_Length (null, 0, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null length output must be rejected");
      Status := C_API.Contour_Area (null, 0, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Value = 0.0,
         "zero-count null contour area must succeed with zero");
      Status := C_API.Arc_Length (null, 0, 0, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Value = 0.0,
         "zero-count null arc length must succeed with zero");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Contour rectangle geometry", Rectangle_Area_And_Length'Access));
      Result.Add_Test
        (Caller.Create ("Contour oriented area", Oriented_Area'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour degenerate geometry", Degenerate_Contours'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour geometry preserves array order",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Contour geometry C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Contour_Geometry_Tests;
