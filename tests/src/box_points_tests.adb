with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Box_Points_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Rotated_Rect;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Tolerance : constant OpenCV.Float32_Value := 2.0E-3;

   function Close (Left, Right : OpenCV.Float32_Value) return Boolean is
   begin
      return abs (Left - Right) <= Tolerance;
   end Close;

   function Same_Point (Left, Right : OpenCV.Float32_Point) return Boolean is
   begin
      return Close (Left.X, Right.X) and then Close (Left.Y, Right.Y);
   end Same_Point;

   procedure Assert_Vertex_Set
     (Actual, Expected : OpenCV.Geometry.Box_Vertices; Message : String)
   is
      Used  : array (OpenCV.Geometry.Box_Vertex_Index) of Boolean :=
        (others => False);
      Found : Boolean;
   begin
      for Vertex of Expected loop
         Found := False;
         for Index in Actual'Range loop
            if not Used (Index) and then Same_Point (Actual (Index), Vertex)
            then
               Used (Index) := True;
               Found := True;
               exit;
            end if;
         end loop;
         AUnit.Assertions.Assert
           (Found, Message & ": missing expected vertex");
      end loop;
   end Assert_Vertex_Set;

   function To_C (Box : OpenCV.Rotated_Rect) return C_API.C_Rotated_Rect is
   begin
      return
        (Center_X      => Interfaces.C.C_float (Box.Center.X),
         Center_Y      => Interfaces.C.C_float (Box.Center.Y),
         Width         => Interfaces.C.C_float (Box.Size.Width),
         Height        => Interfaces.C.C_float (Box.Size.Height),
         Angle_Degrees => Interfaces.C.C_float (Box.Angle_Degrees));
   end To_C;

   procedure Axis_Aligned (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box      : constant OpenCV.Rotated_Rect :=
        (Center        => (X => 0.0, Y => 0.0),
         Size          => (Width => 4.0, Height => 2.0),
         Angle_Degrees => 0.0);
      Expected : constant OpenCV.Geometry.Box_Vertices :=
        ((X => -2.0, Y => 1.0),
         (X => -2.0, Y => -1.0),
         (X => 2.0, Y => -1.0),
         (X => 2.0, Y => 1.0));
   begin
      Assert_Vertex_Set
        (OpenCV.Geometry.Box_Points (Box), Expected, "axis-aligned box");
   end Axis_Aligned;

   procedure Translated_Axis_Aligned (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box      : constant OpenCV.Rotated_Rect :=
        (Center        => (X => -3.0, Y => 5.0),
         Size          => (Width => 4.0, Height => 2.0),
         Angle_Degrees => 0.0);
      Expected : constant OpenCV.Geometry.Box_Vertices :=
        ((X => -5.0, Y => 6.0),
         (X => -5.0, Y => 4.0),
         (X => -1.0, Y => 4.0),
         (X => -1.0, Y => 6.0));
   begin
      Assert_Vertex_Set
        (OpenCV.Geometry.Box_Points (Box), Expected, "translated box");
   end Translated_Axis_Aligned;

   procedure Rotated_Nonsquare (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box      : constant OpenCV.Rotated_Rect :=
        (Center        => (X => 0.0, Y => 0.0),
         Size          => (Width => 4.0, Height => 2.0),
         Angle_Degrees => 45.0);
      Expected : constant OpenCV.Geometry.Box_Vertices :=
        ((X => -2.121_320_2, Y => -0.707_106_8),
         (X => -0.707_106_8, Y => -2.121_320_2),
         (X => 2.121_320_2, Y => 0.707_106_8),
         (X => 0.707_106_8, Y => 2.121_320_2));
   begin
      Assert_Vertex_Set
        (OpenCV.Geometry.Box_Points (Box), Expected, "45-degree box");
   end Rotated_Nonsquare;

   procedure Minimum_Area_Integration (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points   : constant OpenCV.Geometry.Contour :=
        ((X => -6, Y => -4),
         (X => -2, Y => -4),
         (X => -2, Y => -2),
         (X => -6, Y => -2));
      Expected : constant OpenCV.Geometry.Box_Vertices :=
        ((X => -6.0, Y => -4.0),
         (X => -2.0, Y => -4.0),
         (X => -2.0, Y => -2.0),
         (X => -6.0, Y => -2.0));
   begin
      Assert_Vertex_Set
        (OpenCV.Geometry.Box_Points
           (OpenCV.Geometry.Minimum_Area_Rectangle (Points)),
         Expected,
         "minimum-area rectangle corners");
   end Minimum_Area_Integration;

   procedure Fit_Ellipse_Integration (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points   : constant OpenCV.Geometry.Contour :=
        ((X => 20, Y => 0),
         (X => -20, Y => 0),
         (X => 0, Y => 10),
         (X => 0, Y => -10),
         (X => 16, Y => 6),
         (X => 16, Y => -6),
         (X => -16, Y => 6),
         (X => -16, Y => -6));
      Expected : constant OpenCV.Geometry.Box_Vertices :=
        ((X => -20.0, Y => 10.0),
         (X => -20.0, Y => -10.0),
         (X => 20.0, Y => -10.0),
         (X => 20.0, Y => 10.0));
   begin
      Assert_Vertex_Set
        (OpenCV.Geometry.Box_Points (OpenCV.Geometry.Fit_Ellipse (Points)),
         Expected,
         "fitted ellipse rectangle corners");
   end Fit_Ellipse_Integration;

   procedure Degenerate_Boxes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Zero_Width  : constant OpenCV.Geometry.Box_Vertices :=
        OpenCV.Geometry.Box_Points
          ((Center        => (X => 0.0, Y => 0.0),
            Size          => (Width => 0.0, Height => 2.0),
            Angle_Degrees => 0.0));
      Zero_Height : constant OpenCV.Geometry.Box_Vertices :=
        OpenCV.Geometry.Box_Points
          ((Center        => (X => 0.0, Y => 0.0),
            Size          => (Width => 4.0, Height => 0.0),
            Angle_Degrees => 0.0));
      Point_Box   : constant OpenCV.Geometry.Box_Vertices :=
        OpenCV.Geometry.Box_Points
          ((Center        => (X => -2.0, Y => 3.0),
            Size          => (Width => 0.0, Height => 0.0),
            Angle_Degrees => 73.0));
   begin
      Assert_Vertex_Set
        (Zero_Width,
         ((X => 0.0, Y => 1.0),
          (X => 0.0, Y => -1.0),
          (X => 0.0, Y => -1.0),
          (X => 0.0, Y => 1.0)),
         "zero width");
      Assert_Vertex_Set
        (Zero_Height,
         ((X => -2.0, Y => 0.0),
          (X => -2.0, Y => 0.0),
          (X => 2.0, Y => 0.0),
          (X => 2.0, Y => 0.0)),
         "zero height");
      Assert_Vertex_Set
        (Point_Box,
         ((X => -2.0, Y => 3.0),
          (X => -2.0, Y => 3.0),
          (X => -2.0, Y => 3.0),
          (X => -2.0, Y => 3.0)),
         "zero size");
   end Degenerate_Boxes;

   procedure Input_Unchanged_And_Negative_Size (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box      : constant OpenCV.Rotated_Rect :=
        (Center        => (X => -1.0, Y => 2.0),
         Size          => (Width => -4.0, Height => 2.0),
         Angle_Degrees => 270.0);
      Original : constant OpenCV.Rotated_Rect := Box;
      Vertices : constant OpenCV.Geometry.Box_Vertices :=
        OpenCV.Geometry.Box_Points (Box);
   begin
      AUnit.Assertions.Assert (Box = Original, "Box must be unchanged");
      AUnit.Assertions.Assert
        (not Same_Point (Vertices (1), Vertices (2)),
         "negative finite size is accepted and converted");
   end Input_Unchanged_And_Negative_Size;

   procedure Native_Order_Is_Preserved (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box      : constant OpenCV.Rotated_Rect :=
        (Center        => (X => 1.0, Y => -2.0),
         Size          => (Width => 4.0, Height => 2.0),
         Angle_Degrees => 30.0);
      Packed   : aliased C_API.C_Rotated_Rect := To_C (Box);
      Raw      : aliased C_API.C_Box_Vertices := (others => 0.0);
      Vertices : constant OpenCV.Geometry.Box_Vertices :=
        OpenCV.Geometry.Box_Points (Box);
      Status   : C_API.Status;
   begin
      Status := C_API.Box_Points (Packed'Access, Raw'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "raw order status");
      AUnit.Assertions.Assert
        (Close (Vertices (1).X, OpenCV.Float32_Value (Raw.V0_X))
         and then Close (Vertices (1).Y, OpenCV.Float32_Value (Raw.V0_Y))
         and then Close (Vertices (2).X, OpenCV.Float32_Value (Raw.V1_X))
         and then Close (Vertices (2).Y, OpenCV.Float32_Value (Raw.V1_Y))
         and then Close (Vertices (3).X, OpenCV.Float32_Value (Raw.V2_X))
         and then Close (Vertices (3).Y, OpenCV.Float32_Value (Raw.V2_Y))
         and then Close (Vertices (4).X, OpenCV.Float32_Value (Raw.V3_X))
         and then Close (Vertices (4).Y, OpenCV.Float32_Value (Raw.V3_Y)),
         "Ada result preserves C ABI sequence");
      if C_API.OpenCV_Major_Version = 5 then
         for Vertex of Vertices loop
            AUnit.Assertions.Assert
              (Vertices (1).Y > Vertex.Y
               or else (Close (Vertices (1).Y, Vertex.Y)
                        and then Vertices (1).X >= Vertex.X),
               "OpenCV 5 documented greatest-Y/rightmost start");
         end loop;
      end if;
   end Native_Order_Is_Preserved;

   procedure C_ABI_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box    : aliased C_API.C_Rotated_Rect :=
        (Center_X      => 0.0,
         Center_Y      => 0.0,
         Width         => 4.0,
         Height        => 2.0,
         Angle_Degrees => 0.0);
      Output : aliased C_API.C_Box_Vertices := (others => -1.0);
      Status : C_API.Status;

      procedure Assert_Zeroed (Message : String) is
      begin
         AUnit.Assertions.Assert
           (Output.V0_X = 0.0
            and then Output.V0_Y = 0.0
            and then Output.V1_X = 0.0
            and then Output.V1_Y = 0.0
            and then Output.V2_X = 0.0
            and then Output.V2_Y = 0.0
            and then Output.V3_X = 0.0
            and then Output.V3_Y = 0.0,
            Message & " output zeroed");
      end Assert_Zeroed;
   begin
      Status := C_API.Box_Points (null, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null box status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "null") /= 0,
         "null box diagnostic");
      Assert_Zeroed ("null box");

      Status := C_API.Box_Points (Box'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null output status");

      Output := (others => -1.0);
      Status := C_API.Box_Points (Box'Access, Output'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "recovery status");
      AUnit.Assertions.Assert
        (Output.V0_X /= 0.0 or else Output.V0_Y /= 0.0,
         "successful known rectangle");
   end C_ABI_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Box points axis-aligned", Axis_Aligned'Access));
      Result.Add_Test
        (Caller.Create
           ("Box points translated axis-aligned",
            Translated_Axis_Aligned'Access));
      Result.Add_Test
        (Caller.Create
           ("Box points rotated nonsquare", Rotated_Nonsquare'Access));
      Result.Add_Test
        (Caller.Create
           ("Box points minimum-area integration",
            Minimum_Area_Integration'Access));
      Result.Add_Test
        (Caller.Create
           ("Box points fit ellipse integration",
            Fit_Ellipse_Integration'Access));
      Result.Add_Test
        (Caller.Create
           ("Box points degenerate rectangles", Degenerate_Boxes'Access));
      Result.Add_Test
        (Caller.Create
           ("Box points input unchanged and negative size",
            Input_Unchanged_And_Negative_Size'Access));
      Result.Add_Test
        (Caller.Create
           ("Box points native order preserved",
            Native_Order_Is_Preserved'Access));
      Result.Add_Test
        (Caller.Create ("Box points C ABI safety", C_ABI_Safety'Access));
      return Result'Access;
   end Suite;

end Box_Points_Tests;
