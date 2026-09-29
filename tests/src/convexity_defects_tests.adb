with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;
with OpenCV.Geometry.Internal.Convexity;

package body Convexity_Defects_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Convexity renames OpenCV.Geometry.Internal.Convexity;

   use type C_API.Status;
   use type C_API.C_Convexity_Defect;
   use type C_API.C_Convexity_Defect_Array;
   use type Convexity.Coordinate_Bounds;
   use type Interfaces.Integer_32;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Geometry.Convexity_Defect_Array;
   use type OpenCV.Geometry.Point_Index_Array;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   --  Expected results trace OpenCV convexityDefects, whose source is
   --  identical in OpenCV 4.6, 4.10, and 5.0. Depth is the native
   --  cvRound (distance * 256) divided by 256.0.

   --  A square with a notch of depth 4 in its top edge. Hull: 0, 1, 2, 4.
   Notched : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 10, Y => 0),
      (X => 10, Y => 10),
      (X => 5, Y => 6),
      (X => 0, Y => 10));

   Notched_Defects : constant OpenCV.Geometry.Convexity_Defect_Array :=
     (0 =>
        (Start_Index => 2, End_Index => 4, Farthest_Index => 3, Depth => 4.0));

   --  A depth-3 notch in the right edge and a depth-2 notch in the closing
   --  edge from index 4 back to index 0. Hull: 0, 1, 3, 4.
   Two_Notches : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 12, Y => 0),
      (X => 9, Y => 6),
      (X => 12, Y => 12),
      (X => 0, Y => 12),
      (X => 2, Y => 5));

   --  OpenCV reports the closing edge first, then ascending edges.
   Two_Notch_Defects : constant OpenCV.Geometry.Convexity_Defect_Array :=
     ((Start_Index => 4, End_Index => 0, Farthest_Index => 5, Depth => 2.0),
      (Start_Index => 1, End_Index => 3, Farthest_Index => 2, Depth => 3.0));

   Square : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3));

   Maximum_Extent : constant := 8_388_607;

   pragma
     Compile_Time_Error
       (Convexity.Maximum_Defect_Extent /= Maximum_Extent,
        "the extent limit must be Integer_32'Last / 256 = 8_388_607");

   function Shifted_Defects
     (Defects : OpenCV.Geometry.Convexity_Defect_Array; Offset : Natural)
      return OpenCV.Geometry.Convexity_Defect_Array
   is
      Shifted : OpenCV.Geometry.Convexity_Defect_Array := Defects;
   begin
      for Defect of Shifted loop
         Defect.Start_Index := Defect.Start_Index + Offset;
         Defect.End_Index := Defect.End_Index + Offset;
         Defect.Farthest_Index := Defect.Farthest_Index + Offset;
      end loop;
      return Shifted;
   end Shifted_Defects;

   --  True when Operation raises OpenCV_Error whose message contains
   --  Fragment.
   generic
      with procedure Operation;
   function Raises (Fragment : String) return Boolean;

   function Raises (Fragment : String) return Boolean is
   begin
      Operation;
      return False;
   exception
      when Error : OpenCV.OpenCV_Error =>
         return
           Ada.Strings.Fixed.Index
             (Ada.Exceptions.Exception_Message (Error), Fragment)
           /= 0;
   end Raises;

   function Defects_Raise
     (Points   : OpenCV.Geometry.Contour;
      Hull     : OpenCV.Geometry.Point_Index_Array;
      Fragment : String) return Boolean
   is
      procedure Call is
         Unused : constant OpenCV.Geometry.Convexity_Defect_Array :=
           OpenCV.Geometry.Convexity_Defects (Points, Hull);
         pragma Unreferenced (Unused);
      begin
         null;
      end Call;

      function Call_Raises is new Raises (Call);
   begin
      return Call_Raises (Fragment);
   end Defects_Raise;

   function Own_Hull_Defects_Raise
     (Points : OpenCV.Geometry.Contour; Fragment : String) return Boolean
   is
      procedure Call is
         Unused : constant OpenCV.Geometry.Convexity_Defect_Array :=
           OpenCV.Geometry.Convexity_Defects (Points);
         pragma Unreferenced (Unused);
      begin
         null;
      end Call;

      function Call_Raises is new Raises (Call);
   begin
      return Call_Raises (Fragment);
   end Own_Hull_Defects_Raise;

   procedure Notched_Single_Defect (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Defects : constant OpenCV.Geometry.Convexity_Defect_Array :=
        OpenCV.Geometry.Convexity_Defects (Notched);
   begin
      AUnit.Assertions.Assert
        (Defects = Notched_Defects,
         "notch must be one defect 2 -> 4 at index 3 with depth 4.0");
      AUnit.Assertions.Assert
        (Defects'First = 0, "a nonempty defect result must be zero-based");
   end Notched_Single_Defect;

   procedure Closing_Edge_Order (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Defects : constant OpenCV.Geometry.Convexity_Defect_Array :=
        OpenCV.Geometry.Convexity_Defects (Two_Notches);
   begin
      AUnit.Assertions.Assert
        (Defects = Two_Notch_Defects,
         "closing-edge defect must precede the ascending-edge defect");
   end Closing_Edge_Order;

   procedure Hull_Direction_Independent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Ascending  : constant OpenCV.Geometry.Point_Index_Array := (0, 1, 3, 4);
      Descending : constant OpenCV.Geometry.Point_Index_Array := (4, 3, 1, 0);
      Clockwise  : constant OpenCV.Geometry.Point_Index_Array :=
        OpenCV.Geometry.Convex_Hull_Indices
          (Two_Notches, OpenCV.Geometry.Clockwise);
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convex_Hull_Indices (Two_Notches) = Ascending,
         "two-notch hull indices must be 0, 1, 3, 4");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Two_Notches, Ascending)
         = Two_Notch_Defects,
         "an ascending explicit hull must match the computed-hull result");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Two_Notches, Descending)
         = Two_Notch_Defects,
         "a descending hull must give the same defects in the same order");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Two_Notches, Clockwise)
         = Two_Notch_Defects,
         "a clockwise Convex_Hull_Indices hull must give the same defects");
   end Hull_Direction_Independent;

   procedure Non_Hull_Polygon (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Hull is not checked to be the convex hull. Against edge 0 -> 2,
      --  point 1 lies 10 / sqrt (2) = 7.0710678 from the edge line, which
      --  OpenCV rounds to 1810 / 256 = 7.0703125.
      Expected : constant OpenCV.Geometry.Convexity_Defect_Array :=
        ((Start_Index    => 0,
          End_Index      => 2,
          Farthest_Index => 1,
          Depth          => 7.0703125),
         (Start_Index    => 2,
          End_Index      => 4,
          Farthest_Index => 3,
          Depth          => 4.0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Notched, (0, 2, 4)) = Expected,
         "defects must be measured against the supplied index polygon");
   end Non_Hull_Polygon;

   procedure Fixed_Point_Resolution (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Point 1 lies 1 / sqrt (4000001) < 1 / 512 inside hull edge 0 -> 2,
      --  so OpenCV records a defect whose fixed-point depth rounds to 0.
      Shallow  : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 1999, Y => 1),
         (X => 2000, Y => 1),
         (X => 2000, Y => 100),
         (X => 0, Y => 100));
      Expected : constant OpenCV.Geometry.Convexity_Defect_Array :=
        (0 =>
           (Start_Index    => 0,
            End_Index      => 2,
            Farthest_Index => 1,
            Depth          => 0.0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convex_Hull_Indices (Shallow) = (0, 2, 3, 4),
         "shallow contour hull indices must be 0, 2, 3, 4");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Shallow) = Expected,
         "a defect shallower than 1/512 must report Depth 0.0");
   end Fixed_Point_Resolution;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted   : constant OpenCV.Geometry.Contour (10 .. 15) := Two_Notches;
      Top       :
        constant OpenCV.Geometry.Contour (Natural'Last - 5 .. Natural'Last) :=
          Two_Notches;
      Top_First : constant Natural := Natural'Last - 5;
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Shifted)
         = Shifted_Defects (Two_Notch_Defects, 10),
         "shifted contour defects must use Ada indices");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Shifted, (10, 11, 13, 14))
         = Shifted_Defects (Two_Notch_Defects, 10),
         "explicit shifted hull must use Ada indices in Points'Range");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Top)
         = Shifted_Defects (Two_Notch_Defects, Top_First),
         "indices ending at Natural'Last must translate exactly");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects
           (Top, (Top_First + 4, Top_First + 3, Top_First + 1, Top_First))
         = Shifted_Defects (Two_Notch_Defects, Top_First),
         "a descending hull ending at Natural'Last must translate exactly");
   end Nonzero_Array_Bounds;

   procedure Small_Inputs_Are_Empty (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty         : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Point'(X => 0, Y => 0));
      No_Hull       : constant OpenCV.Geometry.Point_Index_Array (1 .. 0) :=
        (others => 0);
      Triangle      : constant OpenCV.Geometry.Contour (4 .. 6) :=
        ((X => 0, Y => 0), (X => 5, Y => 0), (X => 0, Y => 5));
      Empty_Defects : constant OpenCV.Geometry.Convexity_Defect_Array :=
        OpenCV.Geometry.Convexity_Defects (Empty);
   begin
      AUnit.Assertions.Assert
        (Empty_Defects'Length = 0 and then Empty_Defects'First = 1,
         "empty contour must give the null defect range 1 .. 0");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Empty, No_Hull)'Length = 0,
         "empty contour and empty hull must give no defects");
      for Count in 1 .. 3 loop
         AUnit.Assertions.Assert
           (OpenCV.Geometry.Convexity_Defects
              (Notched (Notched'First .. Notched'First + Count - 1))'Length
            = 0,
            "contours of at most three points must have no defects");
      end loop;
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Triangle, (4, 5, 6))'Length = 0,
         "a three-point contour with a valid hull must have no defects");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Notched, No_Hull)'Length = 0
         and then OpenCV.Geometry.Convexity_Defects (Notched, (0 => 2))'Length
                  = 0
         and then OpenCV.Geometry.Convexity_Defects (Notched, (0, 4))'Length
                  = 0,
         "hulls of fewer than three indices must give no defects");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Square)'Length = 0,
         "a convex contour must have no defects");
   end Small_Inputs_Are_Empty;

   procedure Collinear_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Line : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 1, Y => 0),
         (X => 2, Y => 0),
         (X => 3, Y => 0),
         (X => 4, Y => 0));
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Line)'Length = 0,
         "a collinear contour's two-index hull must give no defects");
   end Collinear_Contour;

   procedure Hull_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted           : constant OpenCV.Geometry.Contour (10 .. 14) :=
        Notched;
      Triangle          : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 5, Y => 0), (X => 0, Y => 5));
      Empty             : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Point'(X => 0, Y => 0));
      Range_Message     : constant String := "outside Points'Range";
      Monotonic_Message : constant String := "strictly increasing";
   begin
      AUnit.Assertions.Assert
        (Defects_Raise (Shifted, (9, 11, 12, 14), Range_Message),
         "an index below Points'First must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (Defects_Raise (Shifted, (10, 11, 12, 15), Range_Message),
         "an index above Points'Last must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (Defects_Raise (Notched, (0, 1, 2, 4, 5), Range_Message),
         "a zero-based offset past the end must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (Defects_Raise (Triangle, (0, 1, 7), Range_Message),
         "invalid indices must raise even for three-point contours");
      AUnit.Assertions.Assert
        (Defects_Raise (Empty, (0 => 0), Range_Message),
         "any index into an empty contour must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (Defects_Raise (Notched, (0, 1, 1, 4), Monotonic_Message),
         "a repeated hull index must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (Defects_Raise (Notched, (0, 2, 1, 4), Monotonic_Message),
         "a non-monotonic hull must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (Defects_Raise (Notched, (2, 4, 0, 1), Monotonic_Message),
         "a cyclically rotated hull must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (Defects_Raise (Notched, (3, 3), Monotonic_Message),
         "a repeated index must raise even in a short hull");
   end Hull_Validation;

   procedure Self_Intersecting_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A bow tie: its hull visits indices 0, 2, 1, 3 in cyclic order, which
      --  no cyclic shift makes monotonic.
      Bow_Tie : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 10, Y => 10),
         (X => 10, Y => 0),
         (X => 0, Y => 10));
   begin
      AUnit.Assertions.Assert
        (Own_Hull_Defects_Raise (Bow_Tie, "self-intersecting"),
         "a self-intersecting contour must raise OpenCV_Error");
   end Self_Intersecting_Contour;

   procedure Extent_Limit (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  A two-wide sliver whose top-edge notch reaches down to Y = 1. With
      --  Top = 8_388_606, Width**2 + Height**2 = 4 + 8_388_606**2 is within
      --  8_388_607**2 and the depth 8_388_605 is stored natively as
      --  2_147_481_280, just below Integer_32'Last.
      function Sliver
        (Top : OpenCV.Point_Coordinate) return OpenCV.Geometry.Contour
      is (((X => 0, Y => 0),
           (X => 2, Y => 0),
           (X => 2, Y => Top),
           (X => 1, Y => 1),
           (X => 0, Y => Top)));

      Deep     : constant OpenCV.Geometry.Contour :=
        Sliver (Maximum_Extent - 1);
      Too_Deep : constant OpenCV.Geometry.Contour := Sliver (Maximum_Extent);
      Expected : constant OpenCV.Geometry.Convexity_Defect_Array :=
        (0 =>
           (Start_Index    => 2,
            End_Index      => 4,
            Farthest_Index => 3,
            Depth          => 8_388_605.0));

      function Rectangle
        (Height : OpenCV.Point_Coordinate) return OpenCV.Geometry.Contour
      is (((X => 0, Y => 0),
           (X => Maximum_Extent - 1, Y => 0),
           (X => Maximum_Extent - 1, Y => Height),
           (X => 0, Y => Height)));

      Huge           : constant OpenCV.Geometry.Contour :=
        ((X => OpenCV.Point_Coordinate'First, Y => 0),
         (X => OpenCV.Point_Coordinate'Last, Y => 0),
         (X => OpenCV.Point_Coordinate'Last, Y => 5),
         (X => 0, Y => 1),
         (X => OpenCV.Point_Coordinate'First, Y => 5));
      Extent_Message : constant String := "fixed-point";
   begin
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Deep) = Expected,
         "a defect at the extent limit must keep its exact depth");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Deep, (0, 1, 2, 4)) = Expected,
         "an explicit hull at the extent limit must keep its exact depth");
      AUnit.Assertions.Assert
        (Own_Hull_Defects_Raise (Too_Deep, Extent_Message),
         "4 + 8_388_607**2 must exceed the extent limit");
      AUnit.Assertions.Assert
        (Defects_Raise (Too_Deep, (0, 1, 2, 4), Extent_Message),
         "an explicit hull must not bypass the extent limit");
      --  (M - 1)**2 + 4095**2 <= M**2 < (M - 1)**2 + 4096**2.
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Rectangle (4_095))'Length = 0,
         "the largest diagonal within the limit must be accepted");
      AUnit.Assertions.Assert
        (Own_Hull_Defects_Raise (Rectangle (4_096), Extent_Message),
         "the smallest diagonal beyond the limit must be rejected");
      AUnit.Assertions.Assert
        (Defects_Raise (Huge, (0, 1, 2, 4), Extent_Message),
         "full signed 32-bit spans must be rejected before native code");
      --  The computed hull itself rejects spans beyond signed 32-bit
      --  arithmetic before the defect extent is checked.
      AUnit.Assertions.Assert
        (Own_Hull_Defects_Raise (Huge, "arithmetic"),
         "full signed 32-bit spans must raise OpenCV_Error");
      AUnit.Assertions.Assert
        (OpenCV.Geometry.Convexity_Defects (Huge (0 .. 2))'Length = 0
         and then OpenCV.Geometry.Convexity_Defects (Huge, (0, 2))'Length = 0,
         "the limit applies only when native defect arithmetic runs");
   end Extent_Limit;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Warnings (Off, "could be declared constant");
      Points  : OpenCV.Geometry.Contour := Two_Notches;
      Hull    : OpenCV.Geometry.Point_Index_Array := (0, 1, 3, 4);
      pragma Warnings (On, "could be declared constant");
      Defects : constant OpenCV.Geometry.Convexity_Defect_Array :=
        OpenCV.Geometry.Convexity_Defects (Points, Hull);
   begin
      AUnit.Assertions.Assert
        (Defects = Two_Notch_Defects, "two-notch defects must be computed");
      AUnit.Assertions.Assert
        (Hull = (0, 1, 3, 4), "Convexity_Defects must leave Hull unchanged");
      for Index in Points'Range loop
         AUnit.Assertions.Assert
           (OpenCV."=" (Points (Index), Two_Notches (Index)),
            "Convexity_Defects must leave Points unchanged");
      end loop;
   end Input_Unchanged;

   procedure Helper_Arithmetic (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Top_First : constant Natural := Natural'Last - 5;
      Sample    : constant OpenCV.Point_Array :=
        ((X => 3, Y => -2), (X => -7, Y => 9), (X => 5, Y => 1));
      Bounds    : constant Convexity.Coordinate_Bounds :=
        Convexity.Bounds_Of (Sample);

      function Safe (Width, Height : OpenCV.Point_Coordinate) return Boolean
      is (Convexity.Defect_Extent_Is_Safe
            ((Min_X => -1,
              Max_X => Width - 1,
              Min_Y => 3,
              Max_Y => Height + 3)));
   begin
      AUnit.Assertions.Assert
        (Convexity.To_Native_Offset (Top_First, Natural'Last, Natural'Last) = 5
         and then Convexity.To_Point_Index (Top_First, Natural'Last, 5)
                  = Natural'Last
         and then Convexity.To_Point_Index (Top_First, Natural'Last, 0)
                  = Top_First,
         "offsets must translate exactly near Natural'Last");
      AUnit.Assertions.Assert
        (Convexity.Is_Native_Offset (10, 14, 4)
         and then not Convexity.Is_Native_Offset (10, 14, 5)
         and then not Convexity.Is_Native_Offset (10, 14, -1)
         and then not Convexity.Is_Native_Offset
                        (0, Natural'Last, Interfaces.Integer_32'First),
         "native offsets must be checked against the array length");
      AUnit.Assertions.Assert
        (Convexity.Is_Strictly_Monotonic ((1 .. 0 => 0))
         and then Convexity.Is_Strictly_Monotonic ((0 => 4))
         and then Convexity.Is_Strictly_Monotonic ((1, 3, 8))
         and then Convexity.Is_Strictly_Monotonic ((8, 3, 1))
         and then not Convexity.Is_Strictly_Monotonic ((1, 3, 3))
         and then not Convexity.Is_Strictly_Monotonic ((3, 8, 1)),
         "hull ordering must accept only strictly monotonic sequences");
      AUnit.Assertions.Assert
        (Bounds = (Min_X => -7, Max_X => 5, Min_Y => -2, Max_Y => 9),
         "bounds must be the tight coordinate extremes");
      AUnit.Assertions.Assert
        (Safe (Maximum_Extent, 0)
         and then not Safe (Maximum_Extent + 1, 0)
         and then Safe (0, Maximum_Extent)
         and then Safe (Maximum_Extent - 1, 4_095)
         and then not Safe (Maximum_Extent - 1, 4_096)
         and then not Safe (Maximum_Extent, 1),
         "the extent limit must compare the squared diagonal exactly");
   end Helper_Arithmetic;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points   : aliased C_API.Point_I32_Array (0 .. 4) :=
        ((X => 0, Y => 0),
         (X => 10, Y => 0),
         (X => 10, Y => 10),
         (X => 5, Y => 6),
         (X => 0, Y => 10));
      Hull     : aliased C_API.Int32_Array (0 .. 3) := (0, 1, 2, 4);
      Sentinel : constant C_API.C_Convexity_Defect_Array (0 .. 3) :=
        (others => (-5, -6, -7, -8));
      Output   : aliased C_API.C_Convexity_Defect_Array (0 .. 3) := Sentinel;
      Count    : aliased Interfaces.Integer_32 := -1;
      Status   : C_API.Status;

      procedure Expect_Invalid (Fragment, Message : String) is
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument
            and then Ada.Strings.Fixed.Index
                       (C_API.Last_Error_Message, Fragment)
                     /= 0,
            Message);
         AUnit.Assertions.Assert
           (Count = 0 and then Output = Sentinel,
            Message & ": no count or defect may be published");
         Count := -1;
      end Expect_Invalid;
   begin
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           -1,
           Hull (0)'Access,
           4,
           Output (0)'Access,
           4,
           Count'Access);
      Expect_Invalid ("point count", "negative point count");

      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           5,
           Hull (0)'Access,
           -1,
           Output (0)'Access,
           4,
           Count'Access);
      Expect_Invalid ("hull count", "negative hull count");

      Status :=
        C_API.Convexity_Defects
          (null, 5, Hull (0)'Access, 4, Output (0)'Access, 4, Count'Access);
      Expect_Invalid ("points", "null points with positive count");

      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access, 5, null, 4, Output (0)'Access, 4, Count'Access);
      Expect_Invalid ("hull", "null hull with positive count");

      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           5,
           Hull (0)'Access,
           4,
           Output (0)'Access,
           -1,
           Count'Access);
      Expect_Invalid ("capacity", "negative output capacity");

      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access, 5, Hull (0)'Access, 4, null, 4, Count'Access);
      Expect_Invalid ("output", "null output with positive capacity");

      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           5,
           Hull (0)'Access,
           4,
           Output (0)'Access,
           0,
           Count'Access);
      Expect_Invalid ("capacity", "insufficient output capacity");

      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           5,
           Hull (0)'Access,
           4,
           Output (0)'Access,
           4,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0
         and then Output = Sentinel,
         "null output count pointer must be rejected");

      --  Public Ada handles empty contours itself. A raw empty contour is
      --  rejected by OpenCV's own assertion, safely and unpublished.
      Count := -1;
      Status :=
        C_API.Convexity_Defects (null, 0, null, 0, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then C_API.Last_Error_Message'Length > 0
         and then Count = 0,
         "a raw empty contour must be rejected by OpenCV unpublished");
   end C_ABI_Validation;

   procedure C_ABI_Native_Results (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points    : aliased C_API.Point_I32_Array (0 .. 4) :=
        ((X => 0, Y => 0),
         (X => 10, Y => 0),
         (X => 10, Y => 10),
         (X => 5, Y => 6),
         (X => 0, Y => 10));
      Hull      : aliased C_API.Int32_Array (0 .. 3) := (0, 1, 2, 4);
      Bad_Range : aliased C_API.Int32_Array (0 .. 3) := (0, 1, 2, 9);
      Bad_Order : aliased C_API.Int32_Array (0 .. 3) := (0, 2, 1, 4);
      Garbage   : aliased C_API.Int32_Array (0 .. 2) := (99, -4, 1000);
      Sentinel  : constant C_API.C_Convexity_Defect_Array (0 .. 3) :=
        (others => (-5, -6, -7, -8));
      Output    : aliased C_API.C_Convexity_Defect_Array (0 .. 3) := Sentinel;
      Count     : aliased Interfaces.Integer_32 := -1;
      Status    : C_API.Status;
   begin
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           5,
           Hull (0)'Access,
           4,
           Output (0)'Access,
           4,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Count = 1
         and then Output (0) = (2, 4, 3, 1_024),
         "raw defect must use zero-based offsets and fixed-point depth");

      --  OpenCV 4.6/4.10/5.0 assert every hull index before dereferencing
      --  the contour, and reject non-monotonic hulls, by raising.
      Output := Sentinel;
      Count := -1;
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           5,
           Bad_Range (0)'Access,
           4,
           Output (0)'Access,
           4,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then C_API.Last_Error_Message'Length > 0
         and then Count = 0
         and then Output = Sentinel,
         "a raw out-of-range hull index must fail in OpenCV unpublished");

      Count := -1;
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           5,
           Bad_Order (0)'Access,
           4,
           Output (0)'Access,
           4,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "monotonous")
                  /= 0
         and then Count = 0
         and then Output = Sentinel,
         "a raw non-monotonic hull must fail in OpenCV unpublished");

      Count := -1;
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access, 5, null, 0, Output (0)'Access, 4, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV and then Count = 0,
         "a raw empty hull for more than three points must fail in OpenCV");

      --  Native convexityDefects returns before reading the hull when the
      --  contour has at most three points.
      Count := -1;
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           3,
           Garbage (0)'Access,
           3,
           Output (0)'Access,
           4,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0 and then Output = Sentinel,
         "three raw points must give no defects without reading the hull");
   end C_ABI_Native_Results;

   procedure C_ABI_Capacity_And_Extent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points      : aliased C_API.Point_I32_Array (0 .. 5) :=
        ((X => 0, Y => 0),
         (X => 12, Y => 0),
         (X => 9, Y => 6),
         (X => 12, Y => 12),
         (X => 0, Y => 12),
         (X => 2, Y => 5));
      Hull        : aliased C_API.Int32_Array (0 .. 3) := (0, 1, 3, 4);
      Unsafe      : aliased C_API.Point_I32_Array (0 .. 3) :=
        ((X => 0, Y => 0),
         (X => Maximum_Extent + 1, Y => 0),
         (X => Maximum_Extent + 1, Y => 1),
         (X => 0, Y => 1));
      Unsafe_Hull : aliased C_API.Int32_Array (0 .. 3) := (0, 1, 2, 3);
      Sentinel    : constant C_API.C_Convexity_Defect_Array (0 .. 3) :=
        (others => (-5, -6, -7, -8));
      Output      : aliased C_API.C_Convexity_Defect_Array (0 .. 3) :=
        Sentinel;
      Count       : aliased Interfaces.Integer_32 := -1;
      Status      : C_API.Status;
   begin
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           6,
           Hull (0)'Access,
           4,
           Output (0)'Access,
           1,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "capacity")
                  /= 0,
         "two native defects must not fit a capacity of one");
      AUnit.Assertions.Assert
        (Count = 0 and then Output = Sentinel,
         "insufficient capacity must not publish a count or defect");

      Count := -1;
      Status :=
        C_API.Convexity_Defects
          (Points (0)'Access,
           6,
           Hull (0)'Access,
           4,
           Output (0)'Access,
           2,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Count = 2
         and then Output (0 .. 1) = ((4, 0, 5, 512), (1, 3, 2, 768)),
         "an exact capacity must receive both raw defects");

      Output := Sentinel;
      Count := -1;
      Status :=
        C_API.Convexity_Defects
          (Unsafe (0)'Access,
           4,
           Unsafe_Hull (0)'Access,
           4,
           Output (0)'Access,
           4,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index
                    (C_API.Last_Error_Message, "fixed-point")
                  /= 0
         and then Count = 0
         and then Output = Sentinel,
         "raw spans beyond the defect extent limit must be rejected");

      Count := -1;
      Status :=
        C_API.Convexity_Defects
          (Unsafe (0)'Access,
           4,
           Unsafe_Hull (0)'Access,
           2,
           Output (0)'Access,
           4,
           Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0,
         "the extent guard must not apply when native arithmetic is skipped");
   end C_ABI_Capacity_And_Extent;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Convexity defects notched square", Notched_Single_Defect'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects closing edge order",
            Closing_Edge_Order'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects independent of hull direction",
            Hull_Direction_Independent'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects against a non-hull polygon",
            Non_Hull_Polygon'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects fixed-point resolution",
            Fixed_Point_Resolution'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects nonzero array bounds",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects small inputs are empty",
            Small_Inputs_Are_Empty'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects collinear contour", Collinear_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects hull validation", Hull_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects self-intersecting contour",
            Self_Intersecting_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects extent limit", Extent_Limit'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects leave inputs unchanged",
            Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity helper arithmetic", Helper_Arithmetic'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects C ABI validation", C_ABI_Validation'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects C ABI native results",
            C_ABI_Native_Results'Access));
      Result.Add_Test
        (Caller.Create
           ("Convexity defects C ABI capacity and extent",
            C_ABI_Capacity_And_Extent'Access));
      return Result'Access;
   end Suite;

end Convexity_Defects_Tests;
