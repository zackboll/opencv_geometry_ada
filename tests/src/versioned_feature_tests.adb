with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Float32_Test_Support;
with Interfaces;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;
with OpenCV.Geometry.Internal.Convexity;

package body Versioned_Feature_Tests is
   package G renames OpenCV.Geometry;
   package C renames OpenCV.Geometry.Internal.C_API;
   package S renames Float32_Test_Support;
   use type C.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Value;
   use type G.Float32_Point_Array;
   use type G.Native_Feature;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;
   Circle : constant OpenCV.Rotated_Rect :=
     (Center => (0.0, 0.0), Size => (2.0, 2.0), Angle_Degrees => 0.0);
   function Available return Boolean
   is (G.Is_Natively_Supported (G.Closest_Ellipse_Points_Feature));

   procedure Capabilities (F : in out Fixture) is
      pragma Unreferenced (F);
      Raw    : aliased Interfaces.Integer_32 := -1;
      Status : C.Status;
   begin
      for Feature in G.Native_Feature loop
         Status :=
           C.Native_Feature_Supported
             (Interfaces.Integer_32 (G.Native_Feature'Pos (Feature) + 1),
              Raw'Access);
         AUnit.Assertions.Assert
           (Status = C.Success and then Raw in 0 .. 1,
            "capability must be explicit Boolean");
         AUnit.Assertions.Assert
           (G.Is_Natively_Supported (Feature) = (Raw = 1),
            "public/raw capability agreement");
         if C.OpenCV_Major_Version >= 5 then
            AUnit.Assertions.Assert (Raw = 1, "5.x native capability");
         elsif not Available then
            --  4.11 has approxPolyN but not closest ellipse points.
            if Feature /= G.Approximate_Convex_Polygon_Feature then
               AUnit.Assertions.Assert (Raw = 0, "pre-4.12 capability");
            end if;
         end if;
      end loop;
   end Capabilities;

   procedure Invalid_Feature (F : in out Fixture) is
      pragma Unreferenced (F);
      Raw    : aliased Interfaces.Integer_32 := 99;
      Status : C.Status;
   begin
      Status := C.Native_Feature_Supported (0, Raw'Access);
      AUnit.Assertions.Assert
        (Status = C.Error_Invalid_Argument and then Raw = 0,
         "invalid feature zeroes output");
      Status := C.Native_Feature_Supported (5, Raw'Access);
      AUnit.Assertions.Assert
        (Status = C.Error_Invalid_Argument, "unknown feature rejected");
      Status := C.Native_Feature_Supported (1, null);
      AUnit.Assertions.Assert
        (Status = C.Error_Invalid_Argument, "null capability output rejected");
   end Invalid_Feature;

   procedure Unsupported_Public (F : in out Fixture) is
      pragma Unreferenced (F);
      I : constant G.Contour (20 .. 20) := (others => (4, 0));
      P : constant G.Float32_Point_Array (20 .. 20) := (others => (4.0, 0.0));
      procedure Attempt (Integer_Input, Empty : Boolean) is
      begin
         declare
            R : constant G.Float32_Point_Array :=
              (if Integer_Input
               then
                 G.Closest_Ellipse_Points
                   (Circle, I (20 .. (if Empty then 19 else 20)))
               else
                 G.Closest_Ellipse_Points
                   (Circle, P (20 .. (if Empty then 19 else 20))));
         begin
            AUnit.Assertions.Assert (R'Length = 999, "expected unsupported");
         end;
      exception
         when E : OpenCV.OpenCV_Error =>
            AUnit.Assertions.Assert
              (Ada.Strings.Fixed.Index
                 (Ada.Exceptions.Exception_Message (E),
                  "requires OpenCV 4.12 or newer")
               > 0,
               "clear unsupported diagnostic");
      end Attempt;
   begin
      if Available then
         return;
      end if;
      Attempt (True, False);
      Attempt (False, False);
      Attempt (True, True);
      Attempt (False, True);
   end Unsupported_Public;

   procedure Raw_Ordering (F : in out Fixture) is
      pragma Unreferenced (F);
      Count  : aliased Interfaces.Integer_32 := 99;
      Status : C.Status;
   begin
      Status :=
        C.Closest_Ellipse_Points_I32 (null, null, -1, null, -1, Count'Access);
      AUnit.Assertions.Assert
        (Count = 0
         and then Status
                  = (if Available
                     then C.Error_Invalid_Argument
                     else C.Error_Unsupported),
         "raw i32 version gate ordering");
      Count := 99;
      Status :=
        C.Closest_Ellipse_Points_F32 (null, null, 1, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Count = 0
         and then Status
                  = (if Available
                     then C.Error_Invalid_Argument
                     else C.Error_Unsupported),
         "raw f32 version gate ordering");
      Status := C.Closest_Ellipse_Points_F32 (null, null, 1, null, 0, null);
      AUnit.Assertions.Assert
        (Status = C.Error_Invalid_Argument,
         "count pointer precedes version gate");
   end Raw_Ordering;

   procedure Circle_Axes (F : in out Fixture) is
      pragma Unreferenced (F);
      P : constant G.Float32_Point_Array :=
        (20 => (4.0, 0.0),
         21 => (0.0, 4.0),
         22 => (-4.0, 0.0),
         23 => (0.0, -4.0));
   begin
      if not Available then
         return;
      end if;
      declare
         R : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, P);
      begin
         AUnit.Assertions.Assert
           (R'First = 20 and then R'Last = 23, "positional bounds");
         for J in P'Range loop
            AUnit.Assertions.Assert
              (abs (R (J).X - P (J).X / 4.0) < 1.0E-4
               and then abs (R (J).Y - P (J).Y / 4.0) < 1.0E-4,
               "circle axis closest point");
         end loop;
      end;
   end Circle_Axes;

   procedure Ellipse_Axes (F : in out Fixture) is
      pragma Unreferenced (F);
      E : OpenCV.Rotated_Rect := Circle;
      P : constant G.Float32_Point_Array := ((8.0, 0.0), (0.0, 8.0));
   begin
      if not Available then
         return;
      end if;
      E.Size := (4.0, 2.0);
      declare
         R : constant G.Float32_Point_Array := G.Closest_Ellipse_Points (E, P);
      begin
         AUnit.Assertions.Assert
           (abs (R (0).X - 2.0) < 1.0E-4 and then abs (R (1).Y - 1.0) < 1.0E-4,
            "ellipse axes");
      end;
      E.Angle_Degrees := 90.0;
      declare
         R : constant G.Float32_Point_Array := G.Closest_Ellipse_Points (E, P);
      begin
         AUnit.Assertions.Assert
           (abs (R (0).X - 1.0) < 1.0E-4 and then abs (R (1).Y - 2.0) < 1.0E-4,
            "rotated ellipse");
      end;
      E.Size := (2.0, 4.0);
      E.Angle_Degrees := 0.0;
      declare
         R : constant G.Float32_Point_Array := G.Closest_Ellipse_Points (E, P);
      begin
         AUnit.Assertions.Assert
           (abs (R (0).X - 1.0) < 1.0E-4 and then abs (R (1).Y - 2.0) < 1.0E-4,
            "semiaxis swap");
      end;
   end Ellipse_Axes;

   procedure Integer_Equivalence (F : in out Fixture) is
      pragma Unreferenced (F);
      P : constant G.Contour := (20 => (4, 0), 21 => (0, 4));
   begin
      if not Available then
         return;
      end if;
      declare
         R : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, P);
         T : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, S.To_Float32 (P));
      begin
         AUnit.Assertions.Assert (R = T, "native integer/float agreement");
      end;
   end Integer_Equivalence;

   procedure Fractional_High_Bounds (F : in out Fixture) is
      pragma Unreferenced (F);
      P : constant G.Float32_Point_Array (Natural'Last - 1 .. Natural'Last) :=
        (others => (0.375, 0.5));
   begin
      if not Available then
         return;
      end if;
      declare
         R : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, P);
      begin
         AUnit.Assertions.Assert
           (R'First = P'First and then R'Last = P'Last,
            "high bounds preserved");
         for V of R loop
            AUnit.Assertions.Assert
              (abs (V.X - 0.6) < 1.0E-4 and then abs (V.Y - 0.8) < 1.0E-4,
               "fractional query");
         end loop;
      end;
   end Fractional_High_Bounds;

   procedure Empty_Ranges (F : in out Fixture) is
      pragma Unreferenced (F);
      P : G.Float32_Point_Array (27 .. 20);
      I : G.Contour (Natural'Last .. Natural'Last - 1);
   begin
      if not Available then
         return;
      end if;
      declare
         R : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, P);
         T : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, I);
      begin
         AUnit.Assertions.Assert
           (R'First = P'First
            and then R'Last = P'Last
            and then T'First = I'First
            and then T'Last = I'Last,
            "null ranges");
      end;
   end Empty_Ranges;

   procedure Invalid_Dimensions (F : in out Fixture) is
      pragma Unreferenced (F);
      E : OpenCV.Rotated_Rect := Circle;
      P : constant G.Contour := (0 => (4, 0));
      procedure Attempt is
         R : constant G.Float32_Point_Array := G.Closest_Ellipse_Points (E, P);
      begin
         AUnit.Assertions.Assert (R'Length = 999, "invalid ellipse accepted");
      end Attempt;
   begin
      if not Available then
         return;
      end if;
      for V in -1 .. 0 loop
         E.Size := (OpenCV.Float32_Value (V), 2.0);
         S.Assert_Raises_OpenCV_Error (Attempt'Access, "invalid width");
         E.Size := (2.0, OpenCV.Float32_Value (V));
         S.Assert_Raises_OpenCV_Error (Attempt'Access, "invalid height");
      end loop;
   end Invalid_Dimensions;

   procedure Nonfinite_Queries (F : in out Fixture) is
      pragma Unreferenced (F);
      procedure Attempt (P : G.Float32_Point_Array) is
         pragma Suppress (Validity_Check);
         R : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, P);
      begin
         AUnit.Assertions.Assert (R'Length = 999, "nonfinite query accepted");
      end Attempt;
   begin
      if not Available then
         return;
      end if;
      S.Assert_Rejects_Non_Finite
        ((0 => (4.0, 0.0)), Attempt'Access, "closest ellipse query");
   end Nonfinite_Queries;

   procedure Nonfinite_Ellipse (F : in out Fixture) is
      pragma Unreferenced (F);
      pragma Suppress (Validity_Check);
      E : OpenCV.Rotated_Rect := Circle;
      P : constant G.Float32_Point_Array := (0 => (4.0, 0.0));
      procedure Attempt is
         pragma Suppress (Validity_Check);
         R : constant G.Float32_Point_Array := G.Closest_Ellipse_Points (E, P);
      begin
         AUnit.Assertions.Assert
           (R'Length = 999, "nonfinite ellipse accepted");
      end Attempt;
   begin
      if not Available then
         return;
      end if;
      for Kind in 1 .. 3 loop
         declare
            V : constant OpenCV.Float32_Value :=
              (case Kind is
                 when 1      => S.NaN_32,
                 when 2      => S.Infinity_32,
                 when others => S.Negative_Infinity_32);
         begin
            for Field in 1 .. 5 loop
               E := Circle;
               case Field is
                  when 1      =>
                     E.Center.X := V;

                  when 2      =>
                     E.Center.Y := V;

                  when 3      =>
                     E.Size.Width := V;

                  when 4      =>
                     E.Size.Height := V;

                  when others =>
                     E.Angle_Degrees := V;
               end case;
               S.Assert_Raises_OpenCV_Error (Attempt'Access, "ellipse finite");
            end loop;
         end;
      end loop;
   end Nonfinite_Ellipse;

   procedure Native_Nonfinite (F : in out Fixture) is
      pragma Unreferenced (F);
      E : OpenCV.Rotated_Rect := Circle;
      P : constant G.Float32_Point_Array := (0 => (1.0, 1.0));
      procedure Attempt is
         R : constant G.Float32_Point_Array := G.Closest_Ellipse_Points (E, P);
      begin
         AUnit.Assertions.Assert (R'Length = 999, "native nonfinite escaped");
      end Attempt;
   begin
      if not Available then
         return;
      end if;
      E.Size := (1.0E20, 1.0E20);
      S.Assert_Raises_OpenCV_Error
        (Attempt'Access, "native numerical failure");
      E := Circle;
      declare
         procedure At_Center is
            R : constant G.Float32_Point_Array :=
              G.Closest_Ellipse_Points
                (E, G.Float32_Point_Array'(0 => (0.0, 0.0)));
         begin
            AUnit.Assertions.Assert (R'Length = 999, "circle center NaN");
         end At_Center;
      begin
         S.Assert_Raises_OpenCV_Error (At_Center'Access, "q=0 circle center");
      end;
   end Native_Nonfinite;

   procedure Raw_Buffers (F : in out Fixture) is
      pragma Unreferenced (F);
      E      : aliased C.C_Rotated_Rect := (0.0, 0.0, 2.0, 2.0, 0.0);
      P      : aliased C.Point_F32 := (4.0, 0.0);
      I      : aliased C.Point_I32 := (4, 0);
      O      : aliased C.Point_F32 := (0.0, 0.0);
      Count  : aliased Interfaces.Integer_32 := 99;
      Status : C.Status;
      procedure Check (Status : C.Status) is
      begin
         AUnit.Assertions.Assert
           (Status = C.Error_Invalid_Argument and then Count = 0,
            "malformed ABI zero count");
      end Check;
   begin
      if not Available then
         return;
      end if;
      Check
        (C.Closest_Ellipse_Points_F32
           (E'Access, P'Access, -1, O'Access, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_F32
           (E'Access, null, 1, O'Access, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_F32
           (null, P'Access, 1, O'Access, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_F32
           (E'Access, P'Access, 1, O'Access, -1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_F32
           (E'Access, P'Access, 1, null, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_F32
           (E'Access, P'Access, 1, O'Access, 0, Count'Access));
      Status :=
        C.Closest_Ellipse_Points_I32
          (E'Access, I'Access, 1, O'Access, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C.Success and then Count = 1, "raw i32 one-to-one output");
      Check
        (C.Closest_Ellipse_Points_I32
           (E'Access, I'Access, -1, O'Access, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_I32
           (E'Access, null, 1, O'Access, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_I32
           (null, I'Access, 1, O'Access, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_I32
           (E'Access, I'Access, 1, O'Access, -1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_I32
           (E'Access, I'Access, 1, null, 1, Count'Access));
      Check
        (C.Closest_Ellipse_Points_I32
           (E'Access, I'Access, 1, O'Access, 0, Count'Access));
      Status :=
        C.Closest_Ellipse_Points_F32
          (E'Access, P'Access, 1, O'Access, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C.Success and then Count = 1, "raw f32 one-to-one output");
   end Raw_Buffers;
   procedure Single_Unchanged (F : in out Fixture) is
      pragma Unreferenced (F);
      use type OpenCV.Rotated_Rect;
      use type G.Contour;
      P      : constant G.Contour (Natural'Last .. Natural'Last) :=
        (others => (4, 0));
      E      : constant OpenCV.Rotated_Rect := Circle;
      Before : constant G.Contour := P;
   begin
      if not Available then
         return;
      end if;
      declare
         R : constant G.Float32_Point_Array := G.Closest_Ellipse_Points (E, P);
      begin
         AUnit.Assertions.Assert
           (R'First = Natural'Last
            and then R'Length = 1
            and then abs (R (Natural'Last).X - 1.0) < 1.0E-4,
            "single integer high-bound result");
         AUnit.Assertions.Assert
           (P = Before and then E = Circle, "inputs unchanged");
      end;
   end Single_Unchanged;

   procedure Large_Integer (F : in out Fixture) is
      pragma Unreferenced (F);
      P : constant G.Contour := (0 => (OpenCV.Point_Coordinate'Last, 0));
   begin
      if not Available then
         return;
      end if;
      declare
         R : constant G.Float32_Point_Array :=
           G.Closest_Ellipse_Points (Circle, P);
      begin
         AUnit.Assertions.Assert
           (abs (R (0).X - 1.0) < 1.0E-4,
            "large integer native float conversion allowed");
      end;
   end Large_Integer;

   procedure Positional_Offsets (F : in out Fixture) is
      pragma Unreferenced (F);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Internal.Convexity.Positional_Offset
           (Natural'Last - 2, Natural'Last, Natural'Last)
         = 2,
         "proved high-bound positional offset");
   end Positional_Offsets;
   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse single unchanged high bound",
            Single_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse large integer", Large_Integer'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse positional offset", Positional_Offsets'Access));
      Result.Add_Test
        (Caller.Create ("Native feature capabilities", Capabilities'Access));
      Result.Add_Test
        (Caller.Create ("Invalid native feature IDs", Invalid_Feature'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse unsupported public", Unsupported_Public'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse raw version ordering", Raw_Ordering'Access));
      Result.Add_Test
        (Caller.Create ("Closest ellipse circle axes", Circle_Axes'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse axes rotation swap", Ellipse_Axes'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse integer equivalence",
            Integer_Equivalence'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse fractional high bounds",
            Fractional_High_Bounds'Access));
      Result.Add_Test
        (Caller.Create ("Closest ellipse empty ranges", Empty_Ranges'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse invalid dimensions", Invalid_Dimensions'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse nonfinite queries", Nonfinite_Queries'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse nonfinite fields", Nonfinite_Ellipse'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse native nonfinite result",
            Native_Nonfinite'Access));
      Result.Add_Test
        (Caller.Create
           ("Closest ellipse raw buffer safety", Raw_Buffers'Access));
      return Result'Access;
   end Suite;
end Versioned_Feature_Tests;
