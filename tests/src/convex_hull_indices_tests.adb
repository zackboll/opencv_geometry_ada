with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Convex_Hull_Indices_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type C_API.Int32_Array;
   use type Interfaces.Integer_32;
   use type OpenCV.Geometry.Point_Index_Array;
   use type OpenCV.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  A square with a notch in its top edge. Tracing OpenCV 4.6/4.10/5.0
   --  convexHull gives the counterclockwise hull indices 0, 1, 2, 4.
   Notched : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 10, Y => 0),
      (X => 10, Y => 10),
      (X => 5, Y => 6),
      (X => 0, Y => 10));

   --  Notches in the right edge and in the closing left edge.
   Two_Notches : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 12, Y => 0),
      (X => 9, Y => 6),
      (X => 12, Y => 12),
      (X => 0, Y => 12),
      (X => 2, Y => 5));

   Square_With_Interior : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 3),
      (X => 0, Y => 3),
      (X => 2, Y => 1));

   function Same_Point (Left, Right : OpenCV.Point) return Boolean is
   begin
      return Left.X = Right.X and then Left.Y = Right.Y;
   end Same_Point;

   function All_In_Range
     (Points : OpenCV.Geometry.Contour;
      Hull   : OpenCV.Geometry.Point_Index_Array) return Boolean is
   begin
      for Index of Hull loop
         if Index not in Points'Range then
            return False;
         end if;
      end loop;
      return True;
   end All_In_Range;

   function All_Distinct
     (Hull : OpenCV.Geometry.Point_Index_Array) return Boolean is
   begin
      for Left in Hull'Range loop
         for Right in Left + 1 .. Hull'Last loop
            if Hull (Left) = Hull (Right) then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end All_Distinct;

   function Is_Strictly_Monotonic
     (Hull : OpenCV.Geometry.Point_Index_Array) return Boolean
   is
      Increasing : Boolean := True;
      Decreasing : Boolean := True;
   begin
      for Position in Hull'First + 1 .. Hull'Last loop
         Increasing :=
           Increasing and then Hull (Position - 1) < Hull (Position);
         Decreasing :=
           Decreasing and then Hull (Position - 1) > Hull (Position);
      end loop;
      return Increasing or else Decreasing;
   end Is_Strictly_Monotonic;

   --  True when Points (Hull (K)) is exactly the K-th hull point.
   function Selects_Hull_Points
     (Points      : OpenCV.Geometry.Contour;
      Hull        : OpenCV.Geometry.Point_Index_Array;
      Hull_Points : OpenCV.Geometry.Contour) return Boolean is
   begin
      if Hull'Length /= Hull_Points'Length then
         return False;
      end if;
      for Offset in 0 .. Hull'Length - 1 loop
         if not Same_Point
                  (Points (Hull (Hull'First + Offset)),
                   Hull_Points (Hull_Points'First + Offset))
         then
            return False;
         end if;
      end loop;
      return True;
   end Selects_Hull_Points;

   procedure Notched_Counterclockwise (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hull : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Notched);
   begin
      AUnit.Assertions.Assert
        (Hull = (0, 1, 2, 4), "notched hull indices must be 0, 1, 2, 4");
      AUnit.Assertions.Assert
        (Hull'First = 0, "a nonempty index result must be zero-based");
      AUnit.Assertions.Assert
        (not (for some Index of Hull => Index = 3),
         "the notch vertex must not be a hull index");
   end Notched_Counterclockwise;

   procedure Matches_Convex_Hull_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Check
        (Points      : OpenCV.Geometry.Contour;
         Orientation : OpenCV.Geometry.Hull_Orientation;
         Label       : String)
      is
         Hull : constant OpenCV.Geometry.Point_Index_Array :=
           OpenCV.Geometry.Convex_Hull_Indices (Points, Orientation);
      begin
         AUnit.Assertions.Assert
           (Selects_Hull_Points
              (Points,
               Hull,
               OpenCV.Geometry.Convex_Hull (Points, Orientation)),
            Label & " indices must select the Convex_Hull points in order");
         AUnit.Assertions.Assert
           (Is_Strictly_Monotonic (Hull),
            Label & " indices of a simple contour must be monotonic");
      end Check;
   begin
      Check (Notched, OpenCV.Geometry.Counterclockwise, "notched CCW");
      Check (Notched, OpenCV.Geometry.Clockwise, "notched CW");
      Check (Two_Notches, OpenCV.Geometry.Counterclockwise, "two-notch CCW");
      Check (Two_Notches, OpenCV.Geometry.Clockwise, "two-notch CW");
      Check
        (Square_With_Interior,
         OpenCV.Geometry.Counterclockwise,
         "interior-point CCW");
   end Matches_Convex_Hull_Points;

   procedure Orientation_Keeps_Vertices (Test : in out Fixture) is
      pragma Unreferenced (Test);
      CCW : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices
          (Two_Notches, OpenCV.Geometry.Counterclockwise);
      CW  : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices
          (Two_Notches, OpenCV.Geometry.Clockwise);
   begin
      AUnit.Assertions.Assert
        (CCW = (0, 1, 3, 4), "two-notch CCW hull indices must be 0, 1, 3, 4");
      AUnit.Assertions.Assert
        (CW'Length = CCW'Length
         and then (for all Index of CW =>
                     (for some Other of CCW => Other = Index)),
         "both orientations must select the same hull vertices");
   end Orientation_Keeps_Vertices;

   procedure Interior_Points_Excluded (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Hull : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Square_With_Interior);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 4
         and then All_Distinct (Hull)
         and then All_In_Range (Square_With_Interior, Hull),
         "square hull must have four distinct in-range indices");
      AUnit.Assertions.Assert
        (not (for some Index of Hull => Index = 4),
         "interior point index must be excluded");
   end Interior_Points_Excluded;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted  : constant OpenCV.Geometry.Contour (10 .. 14) := Notched;
      Top      :
        constant OpenCV.Geometry.Contour (Natural'Last - 4 .. Natural'Last) :=
          Notched;
      Hull     : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Shifted);
      Top_Hull : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Top);
   begin
      AUnit.Assertions.Assert
        (Hull = (10, 11, 12, 14),
         "shifted hull indices must be Ada indices 10, 11, 12, 14");
      AUnit.Assertions.Assert
        (Hull'First = 0, "shifted input must still give a zero-based result");
      AUnit.Assertions.Assert
        (Top_Hull
         = (Natural'Last - 4,
            Natural'Last - 3,
            Natural'Last - 2,
            Natural'Last),
         "indices ending at Natural'Last must translate exactly");
      AUnit.Assertions.Assert
        (Selects_Hull_Points
           (Top, Top_Hull, OpenCV.Geometry.Convex_Hull (Top)),
         "Natural'Last-bounded indices must select the hull points");
   end Nonzero_Array_Bounds;

   procedure Empty_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Point'(X => 0, Y => 0));
      Hull  : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Empty);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 0 and then Hull'First = 1,
         "empty contour must give the null index range 1 .. 0");
   end Empty_Contour;

   procedure Small_Contours (Test : in out Fixture) is
      pragma Unreferenced (Test);
      One       : constant OpenCV.Geometry.Contour (5 .. 5) :=
        (5 => (X => 1, Y => 2));
      Two       : constant OpenCV.Geometry.Contour (7 .. 8) :=
        ((X => 0, Y => 0), (X => 3, Y => 4));
      Line      : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 1, Y => 0),
         (X => 2, Y => 0),
         (X => 3, Y => 0));
      Same      : constant OpenCV.Geometry.Contour :=
        ((X => 6, Y => 6), (X => 6, Y => 6), (X => 6, Y => 6));
      One_Hull  : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (One);
      Two_Hull  : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Two);
      Line_Hull : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Line);
      Same_Hull : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Same);
   begin
      AUnit.Assertions.Assert
        (One_Hull = (0 => 5), "one-point hull must be its Ada index");
      AUnit.Assertions.Assert
        (Two_Hull'Length = 2
         and then All_Distinct (Two_Hull)
         and then All_In_Range (Two, Two_Hull),
         "two-point hull must contain both Ada indices");
      AUnit.Assertions.Assert
        (Line_Hull'Length = 2
         and then (for some Index of Line_Hull => Index = 0)
         and then (for some Index of Line_Hull => Index = 3),
         "collinear hull must keep only the two extreme indices");
      AUnit.Assertions.Assert
        (Same_Hull'Length = 1
         and then All_In_Range (Same, Same_Hull)
         and then Same_Point
                    (Same (Same_Hull (Same_Hull'First)), (X => 6, Y => 6)),
         "identical points must give one valid hull index");
   end Small_Contours;

   procedure Duplicate_Points_Version_Tolerant (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  OpenCV 5 may choose a different index among duplicate points than
      --  OpenCV 4, so validate the indices and their points only.
      Duplicated : constant OpenCV.Geometry.Contour (3 .. 8) :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3),
         (X => 0, Y => 0),
         (X => 4, Y => 0));
      Corners    : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3));

      procedure Check (Orientation : OpenCV.Geometry.Hull_Orientation) is
         Hull : constant OpenCV.Geometry.Point_Index_Array :=
           OpenCV.Geometry.Convex_Hull_Indices (Duplicated, Orientation);
      begin
         AUnit.Assertions.Assert
           (Hull'Length = 4, "duplicate points must not inflate the hull");
         AUnit.Assertions.Assert
           (All_In_Range (Duplicated, Hull) and then All_Distinct (Hull),
            "duplicate-point hull indices must be distinct and in range");
         for Corner of Corners loop
            AUnit.Assertions.Assert
              ((for some Index of Hull =>
                  Same_Point (Duplicated (Index), Corner)),
               "every square corner must be selected by some hull index");
         end loop;
      end Check;
   begin
      Check (OpenCV.Geometry.Counterclockwise);
      Check (OpenCV.Geometry.Clockwise);
   end Duplicate_Points_Version_Tolerant;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Warnings (Off, "could be declared constant");
      Points : OpenCV.Geometry.Contour := Notched;
      pragma Warnings (On, "could be declared constant");
      Hull   : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices (Points);
   begin
      AUnit.Assertions.Assert
        (Hull'Length = 4, "notched input must give four hull indices");
      for Index in Points'Range loop
         AUnit.Assertions.Assert
           (Same_Point (Points (Index), Notched (Index)),
            "Convex_Hull_Indices must leave the input unchanged");
      end loop;
   end Input_Unchanged;

   procedure Arithmetic_Overflow_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Unsafe : constant OpenCV.Geometry.Contour :=
        ((X => OpenCV.Point_Coordinate'First, Y => 0),
         (X => OpenCV.Point_Coordinate'Last, Y => 0),
         (X => 0, Y => 1));
      Raised : Boolean := False;
   begin
      begin
         declare
            Unused : constant OpenCV.Geometry.Point_Index_Array :=
              OpenCV.Geometry.Convex_Hull_Indices (Unsafe);
            pragma Unreferenced (Unused);
         begin
            null;
         end;
      exception
         when Error : OpenCV.OpenCV_Error =>
            Raised :=
              Ada.Strings.Fixed.Index
                (Ada.Exceptions.Exception_Message (Error), "arithmetic")
              /= 0;
      end;
      AUnit.Assertions.Assert
        (Raised, "spans beyond signed 32-bit arithmetic must be rejected");
   end Arithmetic_Overflow_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : aliased C_API.Point_I32_Array (0 .. 0) :=
        (0 => (X => 9, Y => 9));
      Output : aliased C_API.Int32_Array (0 .. 0) := (0 => 77);
      Count  : aliased Interfaces.Integer_32 := -1;
      Status : C_API.Status;

      procedure Expect_Invalid (Fragment, Message : String) is
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Ada.Strings.Fixed.Index
                       (C_API.Last_Error_Message, Fragment)
                     /= 0,
            Message);
         AUnit.Assertions.Assert
           (Count = 0, Message & ": output count must be zero");
         AUnit.Assertions.Assert
           (Output (0) = 77, Message & ": output must be untouched");
      end Expect_Invalid;
   begin
      Status :=
        C_API.Convex_Hull_Indices
          (Points (0)'Access, -1, 0, Output (0)'Access, 1, Count'Access);
      Expect_Invalid ("count", "negative point count must be rejected");

      Count := -1;
      Status :=
        C_API.Convex_Hull_Indices
          (null, 1, 0, Output (0)'Access, 1, Count'Access);
      Expect_Invalid ("points", "null points with positive count");

      Count := -1;
      Status :=
        C_API.Convex_Hull_Indices
          (Points (0)'Access, 1, 2, Output (0)'Access, 1, Count'Access);
      Expect_Invalid ("clockwise", "invalid clockwise selector");

      Count := -1;
      Status :=
        C_API.Convex_Hull_Indices
          (Points (0)'Access, 1, 0, Output (0)'Access, -1, Count'Access);
      Expect_Invalid ("capacity", "negative output capacity");

      Count := -1;
      Status :=
        C_API.Convex_Hull_Indices
          (Points (0)'Access, 1, 0, null, 1, Count'Access);
      Expect_Invalid ("output", "null output with positive capacity");

      Count := -1;
      Status :=
        C_API.Convex_Hull_Indices
          (Points (0)'Access, 1, 0, Output (0)'Access, 0, Count'Access);
      Expect_Invalid ("capacity", "insufficient output capacity");

      Status := C_API.Convex_Hull_Indices (null, 0, 0, null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "null output count pointer must be rejected");

      Count := -1;
      Status := C_API.Convex_Hull_Indices (null, 0, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0,
         "zero-count hull indices must succeed with empty output");
   end C_ABI_Validation;

   procedure C_ABI_Offsets_And_Failures (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points   : aliased C_API.Point_I32_Array (0 .. 4) :=
        ((X => 0, Y => 0),
         (X => 10, Y => 0),
         (X => 10, Y => 10),
         (X => 5, Y => 6),
         (X => 0, Y => 10));
      Unsafe   : aliased C_API.Point_I32_Array (0 .. 2) :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => Interfaces.Integer_32'Last, Y => 0),
         (X => 0, Y => 1));
      Output   : aliased C_API.Int32_Array (0 .. 4) := (others => 0);
      Sentinel : constant C_API.Int32_Array (0 .. 4) := (61, 62, 63, 64, 65);
      Count    : aliased Interfaces.Integer_32 := -1;
      Status   : C_API.Status;
   begin
      Status :=
        C_API.Convex_Hull_Indices
          (Points (0)'Access, 5, 0, Output (0)'Access, 5, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 4,
         "raw hull indices must succeed with four indices");
      AUnit.Assertions.Assert
        (Output (0 .. 3) = (0, 1, 2, 4),
         "raw hull indices must be zero-based native offsets");

      Output := Sentinel;
      Count := -1;
      Status :=
        C_API.Convex_Hull_Indices
          (Points (0)'Access, 5, 0, Output (0)'Access, 3, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "capacity")
                  /= 0,
         "a capacity below the hull count must be rejected");
      AUnit.Assertions.Assert
        (Count = 0 and then Output = Sentinel,
         "insufficient capacity must not publish a count or indices");

      Count := -1;
      Status :=
        C_API.Convex_Hull_Indices
          (Unsafe (0)'Access, 3, 0, Output (0)'Access, 5, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "arithmetic")
                  /= 0,
         "raw spans beyond signed 32-bit arithmetic must be rejected");
      AUnit.Assertions.Assert
        (Count = 0 and then Output = Sentinel,
         "rejected spans must not publish a count or indices");
   end C_ABI_Offsets_And_Failures;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices notched counterclockwise",
            Notched_Counterclockwise'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices select Convex_Hull points",
            Matches_Convex_Hull_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices orientation keeps vertices",
            Orientation_Keeps_Vertices'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices exclude interior points",
            Interior_Points_Excluded'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices nonzero array bounds",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices empty contour", Empty_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices small contours", Small_Contours'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices duplicate points (version tolerant)",
            Duplicate_Points_Version_Tolerant'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices leave input unchanged",
            Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices reject arithmetic overflow",
            Arithmetic_Overflow_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices C ABI validation", C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Convex hull indices C ABI offsets and failures",
            C_ABI_Offsets_And_Failures'Access));
      return Result'Access;
   end Suite;

end Convex_Hull_Indices_Tests;
