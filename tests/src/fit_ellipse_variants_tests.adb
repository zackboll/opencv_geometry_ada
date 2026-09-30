with Ada.Exceptions;
with Ada.Numerics;
with Ada.Numerics.Generic_Elementary_Functions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Fit_Ellipse_Variants_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Math is new
     Ada.Numerics.Generic_Elementary_Functions (OpenCV.Float64_Value);

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   type Fit_Function is
     access function
       (Points : OpenCV.Geometry.Contour) return OpenCV.Rotated_Rect;

   type Algorithm is record
      Fit  : Fit_Function;
      Name : String (1 .. 6);
   end record;

   Algorithms : constant array (1 .. 2) of Algorithm :=
     ((OpenCV.Geometry.Fit_Ellipse_AMS'Access, "AMS   "),
      (OpenCV.Geometry.Fit_Ellipse_Direct'Access, "Direct"));

   --  Samples of the ellipse with semi-axes 200 and 80 rounded to integers.
   --  Rounding moves them off the conic, so every algorithm takes its own
   --  numerical path; exact conic samples make the AMS system singular, and
   --  OpenCV then falls back or, in 4.12 and later, perturbs randomly.
   Axis_Samples : constant OpenCV.Geometry.Contour :=
     ((200, 0),
      (193, 21),
      (173, 40),
      (141, 57),
      (100, 69),
      (52, 77),
      (0, 80),
      (-52, 77),
      (-100, 69),
      (-141, 57),
      (-173, 40),
      (-193, 21),
      (-200, 0),
      (-193, -21),
      (-173, -40),
      (-141, -57),
      (-100, -69),
      (-52, -77),
      (0, -80),
      (52, -77),
      (100, -69),
      (141, -57),
      (173, -40),
      (193, -21));

   --  The same ellipse rotated by 30 degrees before rounding.
   Rotated_Samples : constant OpenCV.Geometry.Contour :=
     ((173, 100),
      (157, 115),
      (130, 121),
      (94, 120),
      (52, 110),
      (6, 93),
      (-40, 69),
      (-83, 41),
      (-121, 10),
      (-151, -22),
      (-170, -52),
      (-178, -79),
      (-173, -100),
      (-157, -115),
      (-130, -121),
      (-94, -120),
      (-52, -110),
      (-6, -93),
      (40, -69),
      (83, -41),
      (121, -10),
      (151, 22),
      (170, 52),
      (178, 79));

   --  Five rounded points of the rotated ellipse: always exactly one conic.
   Five_Samples : constant OpenCV.Geometry.Contour :=
     ((154, 116), (-38, 71), (-177, -72), (-72, -115), (133, 1));

   --  A rounded quarter arc of the axis-aligned ellipse, on which the three
   --  algorithms give clearly different ellipses.
   Arc_Samples : constant OpenCV.Geometry.Contour :=
     ((200, 0),
      (198, 10),
      (193, 21),
      (185, 31),
      (173, 40),
      (159, 49),
      (141, 57),
      (122, 63),
      (100, 69),
      (77, 74),
      (52, 77),
      (26, 79),
      (0, 80));

   --  Samples of the hyperbola x**2 - y**2 = 1_600 (scaled by 10), for
   --  which AMS finds no ellipse and returns fitEllipseDirect's result.
   Hyperbola_Samples : constant OpenCV.Geometry.Contour :=
     ((40, 0),
      (-40, 0),
      (50, 30),
      (50, -30),
      (-50, 30),
      (-50, -30),
      (68, 55),
      (-68, -55));

   function Translated
     (Points : OpenCV.Geometry.Contour; DX, DY : OpenCV.Point_Coordinate)
      return OpenCV.Geometry.Contour
   is
      Result : OpenCV.Geometry.Contour := Points;
   begin
      for Point of Result loop
         Point := (X => Point.X + DX, Y => Point.Y + DY);
      end loop;
      return Result;
   end Translated;

   --  (u / a)**2 + (v / b)**2 for Point in the frame of the fitted ellipse,
   --  where a and b are the semi-axes along Width and Height. It is 1.0 on
   --  the ellipse whatever width, height, and angle encoding OpenCV chose.
   function Ellipse_Value
     (Fit : OpenCV.Rotated_Rect; Point : OpenCV.Point)
      return OpenCV.Float64_Value
   is
      Theta : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Fit.Angle_Degrees) * Ada.Numerics.Pi / 180.0;
      DX    : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Point.X) - OpenCV.Float64_Value (Fit.Center.X);
      DY    : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Point.Y) - OpenCV.Float64_Value (Fit.Center.Y);
      U     : constant OpenCV.Float64_Value :=
        DX * Math.Cos (Theta) + DY * Math.Sin (Theta);
      V     : constant OpenCV.Float64_Value :=
        -DX * Math.Sin (Theta) + DY * Math.Cos (Theta);
      A     : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Fit.Size.Width) / 2.0;
      B     : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Fit.Size.Height) / 2.0;
   begin
      return (U / A)**2 + (V / B)**2;
   end Ellipse_Value;

   --  True when every point lies near the fitted ellipse.
   function Passes_Near
     (Fit       : OpenCV.Rotated_Rect;
      Points    : OpenCV.Geometry.Contour;
      Tolerance : OpenCV.Float64_Value) return Boolean is
   begin
      for Point of Points loop
         if abs (Ellipse_Value (Fit, Point) - 1.0) > Tolerance then
            return False;
         end if;
      end loop;
      return True;
   end Passes_Near;

   function Close
     (Left, Right : OpenCV.Float64_Value; Tolerance : OpenCV.Float64_Value)
      return Boolean
   is (abs (Left - Right) <= Tolerance);

   function Has_Center
     (Fit : OpenCV.Rotated_Rect; X, Y, Tolerance : OpenCV.Float64_Value)
      return Boolean
   is (Close (OpenCV.Float64_Value (Fit.Center.X), X, Tolerance)
       and then Close (OpenCV.Float64_Value (Fit.Center.Y), Y, Tolerance));

   function Minor_Axis (Fit : OpenCV.Rotated_Rect) return OpenCV.Float64_Value
   is (OpenCV.Float64_Value
         (OpenCV.Float32_Value'Min (Fit.Size.Width, Fit.Size.Height)));

   function Major_Axis (Fit : OpenCV.Rotated_Rect) return OpenCV.Float64_Value
   is (OpenCV.Float64_Value
         (OpenCV.Float32_Value'Max (Fit.Size.Width, Fit.Size.Height)));

   --  Full minor and major axis lengths, independent of which of Width and
   --  Height OpenCV used for each.
   function Has_Axes
     (Fit                     : OpenCV.Rotated_Rect;
      Minor, Major, Tolerance : OpenCV.Float64_Value) return Boolean
   is (Close (Minor_Axis (Fit), Minor, Tolerance)
       and then Close (Major_Axis (Fit), Major, Tolerance));

   --  Direction of the major axis in degrees, modulo 180. Width lies along
   --  Angle_Degrees and Height perpendicular to it.
   function Major_Axis_Degrees
     (Fit : OpenCV.Rotated_Rect) return OpenCV.Float64_Value
   is
      Angle : OpenCV.Float64_Value := OpenCV.Float64_Value (Fit.Angle_Degrees);
   begin
      if Fit.Size.Height > Fit.Size.Width then
         Angle := Angle + 90.0;
      end if;
      return Angle - 180.0 * OpenCV.Float64_Value'Floor (Angle / 180.0);
   end Major_Axis_Degrees;

   function Same_Direction
     (Left, Right, Tolerance : OpenCV.Float64_Value) return Boolean
   is
      Difference : constant OpenCV.Float64_Value := abs (Left - Right);
   begin
      return
        Difference <= Tolerance or else abs (Difference - 180.0) <= Tolerance;
   end Same_Direction;

   function Same_Fit
     (Left, Right : OpenCV.Rotated_Rect; Tolerance : OpenCV.Float64_Value)
      return Boolean
   is (Has_Center
         (Left,
          OpenCV.Float64_Value (Right.Center.X),
          OpenCV.Float64_Value (Right.Center.Y),
          Tolerance)
       and then Close
                  (OpenCV.Float64_Value (Left.Size.Width),
                   OpenCV.Float64_Value (Right.Size.Width),
                   Tolerance)
       and then Close
                  (OpenCV.Float64_Value (Left.Size.Height),
                   OpenCV.Float64_Value (Right.Size.Height),
                   Tolerance)
       and then Close
                  (OpenCV.Float64_Value (Left.Angle_Degrees),
                   OpenCV.Float64_Value (Right.Angle_Degrees),
                   Tolerance));

   function Raises
     (Fit : Fit_Function; Points : OpenCV.Geometry.Contour; Fragment : String)
      return Boolean is
   begin
      declare
         Unused : constant OpenCV.Rotated_Rect := Fit (Points);
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

   procedure Axis_Aligned_Ellipse (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Each of Algorithms loop
         declare
            Fit : constant OpenCV.Rotated_Rect := Each.Fit (Axis_Samples);
         begin
            AUnit.Assertions.Assert
              (Has_Center (Fit, 0.0, 0.0, 0.05),
               Each.Name & " center must be the origin");
            AUnit.Assertions.Assert
              (Has_Axes (Fit, 160.0, 400.0, 1.0),
               Each.Name & " full axes must be about 160 and 400");
            AUnit.Assertions.Assert
              (Same_Direction (Major_Axis_Degrees (Fit), 0.0, 0.2),
               Each.Name & " major axis must lie along X");
            AUnit.Assertions.Assert
              (Passes_Near (Fit, Axis_Samples, 0.03),
               Each.Name & " ellipse must pass near every sample");
         end;
      end loop;
   end Axis_Aligned_Ellipse;

   procedure Rotated_Ellipse (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Each of Algorithms loop
         declare
            Fit : constant OpenCV.Rotated_Rect := Each.Fit (Rotated_Samples);
         begin
            AUnit.Assertions.Assert
              (Has_Center (Fit, 0.0, 0.0, 0.05)
               and then Has_Axes (Fit, 160.0, 400.0, 1.0),
               Each.Name & " rotated ellipse must keep its size");
            AUnit.Assertions.Assert
              (Same_Direction (Major_Axis_Degrees (Fit), 30.0, 0.3),
               Each.Name & " major axis must be at 30 degrees");
            AUnit.Assertions.Assert
              (Passes_Near (Fit, Rotated_Samples, 0.03),
               Each.Name & " rotated ellipse must pass near its samples");
         end;
      end loop;
   end Rotated_Ellipse;

   procedure Translated_Negative_Coordinates (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Samples : constant OpenCV.Geometry.Contour :=
        Translated (Rotated_Samples, -1_000, -500);
   begin
      for Each of Algorithms loop
         declare
            Fit : constant OpenCV.Rotated_Rect := Each.Fit (Samples);
         begin
            AUnit.Assertions.Assert
              (Has_Center (Fit, -1_000.0, -500.0, 0.05)
               and then Has_Axes (Fit, 160.0, 400.0, 1.0)
               and then Same_Direction (Major_Axis_Degrees (Fit), 30.0, 0.3),
               Each.Name & " translated ellipse must keep its shape");
         end;
      end loop;
   end Translated_Negative_Coordinates;

   procedure Exactly_Five_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      --  Five points fix one conic exactly, so the fit is numerically
      --  singular; OpenCV 4.12 and later may perturb it randomly, so only
      --  loose agreement with the sampled ellipse is asserted.
      for Each of Algorithms loop
         declare
            Fit : constant OpenCV.Rotated_Rect := Each.Fit (Five_Samples);
         begin
            AUnit.Assertions.Assert
              (Has_Center (Fit, 0.0, 0.0, 5.0)
               and then Has_Axes (Fit, 160.0, 400.0, 20.0)
               and then Same_Direction (Major_Axis_Degrees (Fit), 30.0, 3.0)
               and then Passes_Near (Fit, Five_Samples, 0.1),
               Each.Name & " five points must fit the sampled ellipse");
         end;
      end loop;
   end Exactly_Five_Points;

   procedure Algorithms_Are_Distinct (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  On a rounded quarter arc the classic fit and AMS stay near a
      --  center about (-23, -7), while Direct lands near (-3, 0).
      Classic : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse (Arc_Samples);
      AMS     : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse_AMS (Arc_Samples);
      Direct  : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse_Direct (Arc_Samples);
   begin
      AUnit.Assertions.Assert
        (abs (OpenCV.Float64_Value (Direct.Center.X)
              - OpenCV.Float64_Value (AMS.Center.X))
         > 10.0
         and then abs (OpenCV.Float64_Value (Direct.Center.X)
                       - OpenCV.Float64_Value (Classic.Center.X))
                  > 10.0,
         "Direct must differ from AMS and the classic fit on an arc");
      AUnit.Assertions.Assert
        (abs (OpenCV.Float64_Value (AMS.Center.X)
              - OpenCV.Float64_Value (Classic.Center.X))
         > 0.3,
         "AMS must differ from the classic fit on an arc");
   end Algorithms_Are_Distinct;

   procedure AMS_Hyperbola_Uses_Direct (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Classic : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse (Hyperbola_Samples);
      AMS     : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse_AMS (Hyperbola_Samples);
      Direct  : constant OpenCV.Rotated_Rect :=
        OpenCV.Geometry.Fit_Ellipse_Direct (Hyperbola_Samples);
   begin
      AUnit.Assertions.Assert
        (Same_Fit (AMS, Direct, 1.0E-3),
         "AMS must return the Direct fit when it finds no ellipse");
      AUnit.Assertions.Assert
        (abs (Major_Axis (AMS) - Major_Axis (Classic)) > 10.0,
         "the Direct fallback must differ from the classic fit");
   end AMS_Hyperbola_Uses_Direct;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted : constant OpenCV.Geometry.Contour (100 .. 123) := Axis_Samples;
      Top     :
        constant OpenCV.Geometry.Contour (Natural'Last - 23 .. Natural'Last) :=
          Axis_Samples;
   begin
      for Each of Algorithms loop
         AUnit.Assertions.Assert
           (OpenCV."=" (Each.Fit (Shifted), Each.Fit (Axis_Samples))
            and then OpenCV."=" (Each.Fit (Top), Each.Fit (Axis_Samples)),
            Each.Name & " result must not depend on Ada array bounds");
      end loop;
   end Nonzero_Array_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Each of Algorithms loop
         declare
            pragma Warnings (Off, "could be declared constant");
            Points : OpenCV.Geometry.Contour := Rotated_Samples;
            pragma Warnings (On, "could be declared constant");
            Unused : constant OpenCV.Rotated_Rect := Each.Fit (Points);
            pragma Unreferenced (Unused);
         begin
            for Index in Points'Range loop
               AUnit.Assertions.Assert
                 (OpenCV."=" (Points (Index), Rotated_Samples (Index)),
                  Each.Name & " must leave Points unchanged");
            end loop;
         end;
      end loop;
   end Input_Unchanged;

   procedure Fewer_Than_Five_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      for Each of Algorithms loop
         for Count in 0 .. 4 loop
            AUnit.Assertions.Assert
              (Raises
                 (Each.Fit,
                  Axis_Samples
                    (Axis_Samples'First .. Axis_Samples'First + Count - 1),
                  "at least five points"),
               Each.Name & " must reject fewer than five points");
         end loop;
      end loop;
   end Fewer_Than_Five_Points;

   procedure Degenerate_Point_Sets (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Repeated  : constant OpenCV.Geometry.Contour (1 .. 6) :=
        (others => (X => 5, Y => 5));
      Collinear : constant OpenCV.Geometry.Contour :=
        ((0, 0), (1, 1), (2, 2), (3, 3), (4, 4));
   begin
      for Each of Algorithms loop
         --  Repeated points leave every native system singular; each path
         --  reaches fitEllipseNoDirect, which returns a point ellipse.
         declare
            Fit : constant OpenCV.Rotated_Rect := Each.Fit (Repeated);
         begin
            AUnit.Assertions.Assert
              (Has_Center (Fit, 5.0, 5.0, 1.0E-3)
               and then Fit.Size.Width <= 1.0E-3
               and then Fit.Size.Height <= 1.0E-3,
               Each.Name & " repeated points must give a point ellipse");
         end;

         --  Collinear points reach native fallbacks whose finite results
         --  vary; a non-finite or negative result must be an OpenCV_Error.
         begin
            declare
               Fit : constant OpenCV.Rotated_Rect := Each.Fit (Collinear);
            begin
               AUnit.Assertions.Assert
                 (Fit.Size.Width >= 0.0 and then Fit.Size.Height >= 0.0,
                  Each.Name & " collinear sizes must be nonnegative");
            end;
         exception
            when Error : OpenCV.OpenCV_Error =>
               declare
                  Message : constant String :=
                    Ada.Exceptions.Exception_Message (Error);
               begin
                  AUnit.Assertions.Assert
                    (Ada.Strings.Fixed.Index (Message, "rotated rectangle")
                     /= 0
                     or else Ada.Strings.Fixed.Index (Message, "fit ellipse")
                             /= 0,
                     Each.Name
                     & " collinear failure must be a rejected result or "
                     & "a native error");
               end;
         end;
      end loop;
   end Degenerate_Point_Sets;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);

      type Raw_Fit is
        access function
          (Points      : access C_API.Point_I32;
           Point_Count : Interfaces.Integer_32;
           Result      : access C_API.C_Rotated_Rect) return C_API.Status
      with Convention => C;

      Raw_Fits : constant array (1 .. 2) of Raw_Fit :=
        (C_API.Fit_Ellipse_AMS'Access, C_API.Fit_Ellipse_Direct'Access);
      Points   : aliased C_API.Point_I32_Array (0 .. 3) :=
        ((X => 20, Y => 0),
         (X => 0, Y => 10),
         (X => -20, Y => 0),
         (X => 0, Y => -10));
      Output   : aliased C_API.C_Rotated_Rect;
      Status   : C_API.Status;

      function Zeroed return Boolean
      is (Output.Center_X = 0.0
          and then Output.Center_Y = 0.0
          and then Output.Width = 0.0
          and then Output.Height = 0.0
          and then Output.Angle_Degrees = 0.0);

      procedure Reset is
      begin
         Output := (others => -3.0);
      end Reset;
   begin
      for Fit of Raw_Fits loop
         Reset;
         Status := Fit (Points (0)'Access, -1, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument and then Zeroed,
            "a negative count must be rejected with zeroed output");

         Reset;
         Status := Fit (null, 5, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument and then Zeroed,
            "null points with a positive count must be rejected");

         --  The count guard runs before OpenCV reads the buffer.
         Reset;
         Status :=
           Fit
             (Points (0)'Access,
              Interfaces.Integer_32'Last / 13 + 1,
              Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Ada.Strings.Fixed.Index
                       (C_API.Last_Error_Message, "allocation")
                     /= 0
            and then Zeroed,
            "counts beyond Integer_32'Last / 13 must be rejected");

         Status := Fit (Points (0)'Access, 4, null);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "a null output must be rejected");

         Reset;
         Status := Fit (Points (0)'Access, 4, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_OpenCV
            and then Ada.Strings.Fixed.Index
                       (C_API.Last_Error_Message, "at least 5")
                     /= 0
            and then Zeroed,
            "four raw points must fail in OpenCV with zeroed output");

         Reset;
         Status := Fit (null, 0, Output'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_OpenCV and then Zeroed,
            "an empty raw point set must fail in OpenCV");
      end loop;
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants axis-aligned ellipse",
            Axis_Aligned_Ellipse'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants rotated ellipse", Rotated_Ellipse'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants translated negative coordinates",
            Translated_Negative_Coordinates'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants exactly five points",
            Exactly_Five_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants algorithms are distinct",
            Algorithms_Are_Distinct'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants AMS hyperbola uses Direct",
            AMS_Hyperbola_Uses_Direct'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants nonzero array bounds",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants fewer than five points",
            Fewer_Than_Five_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants degenerate point sets",
            Degenerate_Point_Sets'Access));
      Result.Add_Test
        (Caller.Create
           ("Fit ellipse variants C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Fit_Ellipse_Variants_Tests;
