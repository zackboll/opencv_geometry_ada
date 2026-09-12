with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with OpenCV;
with OpenCV.Core;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Bounding_Rect_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type OpenCV.Core.Point_Coordinate;
   use type OpenCV.Core.Size_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Square : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 3), (X => 0, Y => 3));

   Translated : constant OpenCV.Geometry.Contour :=
     ((X => 10, Y => 20),
      (X => 14, Y => 20),
      (X => 14, Y => 23),
      (X => 10, Y => 23));

   Unordered : constant OpenCV.Geometry.Contour :=
     ((X => 4, Y => 3), (X => 0, Y => 3), (X => 4, Y => 0), (X => 0, Y => 0));

   procedure Assert_Rect
     (Actual              : OpenCV.Core.Rect;
      X, Y, Width, Height : OpenCV.Core.Size_Coordinate;
      Message             : String) is
   begin
      AUnit.Assertions.Assert (Actual.X = X, Message & ": X");
      AUnit.Assertions.Assert (Actual.Y = Y, Message & ": Y");
      AUnit.Assertions.Assert (Actual.Width = Width, Message & ": Width");
      AUnit.Assertions.Assert (Actual.Height = Height, Message & ": Height");
   end Assert_Rect;

   procedure Assert_C_Rect
     (Actual              : C_API.Rect_I32;
      X, Y, Width, Height : Interfaces.Integer_32;
      Message             : String) is
   begin
      AUnit.Assertions.Assert (Actual.X = X, Message & ": X");
      AUnit.Assertions.Assert (Actual.Y = Y, Message & ": Y");
      AUnit.Assertions.Assert (Actual.Width = Width, Message & ": Width");
      AUnit.Assertions.Assert (Actual.Height = Height, Message & ": Height");
   end Assert_C_Rect;

   function Same_Point (Left, Right : OpenCV.Core.Point) return Boolean is
   begin
      return Left.X = Right.X and then Left.Y = Right.Y;
   end Same_Point;

   function Same_Sequence
     (Left, Right : OpenCV.Geometry.Contour) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for Offset in 0 .. Integer (Left'Length) - 1 loop
         if not Same_Point
                  (Left (Left'First + Offset), Right (Right'First + Offset))
         then
            return False;
         end if;
      end loop;

      return True;
   end Same_Sequence;

   procedure Ordinary_Rectangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Square);
   begin
      Assert_Rect
        (Box, 0, 0, 5, 4, "ordinary rectangle must use inclusive extent");
   end Ordinary_Rectangle;

   procedure Translated_Rectangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Translated);
   begin
      Assert_Rect
        (Box,
         10,
         20,
         5,
         4,
         "translation must move origin without changing size");
   end Translated_Rectangle;

   procedure Inclusive_Integer_Extent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 3));
      Box    : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Points);
   begin
      Assert_Rect
        (Box, 0, 0, 5, 4, "X=0..4 Y=0..3 must produce width 5 height 4");
   end Inclusive_Integer_Extent;

   procedure Single_Point (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        (0 => OpenCV.Core.Point'(X => 7, Y => 11));
      Box    : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Points);
   begin
      Assert_Rect (Box, 7, 11, 1, 1, "one point must have width and height 1");
   end Single_Point;

   procedure Two_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 1, Y => 2), (X => 4, Y => 6));
      Box    : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Points);
   begin
      Assert_Rect (Box, 1, 2, 4, 5, "two-point box must span both extrema");
   end Two_Points;

   procedure Horizontal_Collinear (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 5), (X => 3, Y => 5), (X => 8, Y => 5));
      Box    : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Points);
   begin
      Assert_Rect
        (Box, 0, 5, 9, 1, "horizontal collinear points must have height 1");
   end Horizontal_Collinear;

   procedure Vertical_Collinear (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 2, Y => 0), (X => 2, Y => 4), (X => 2, Y => 7));
      Box    : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Points);
   begin
      Assert_Rect
        (Box, 2, 0, 1, 8, "vertical collinear points must have width 1");
   end Vertical_Collinear;

   procedure Unordered_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Ordered_Box   : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Square);
      Unordered_Box : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Unordered);
   begin
      Assert_Rect
        (Unordered_Box,
         Ordered_Box.X,
         Ordered_Box.Y,
         Ordered_Box.Width,
         Ordered_Box.Height,
         "bounding rect must not depend on point order");
   end Unordered_Points;

   procedure Duplicate_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Duplicated : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 0, Y => 3),
         (X => 0, Y => 0),
         (X => 4, Y => 3));
      Box        : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Duplicated);
   begin
      Assert_Rect
        (Box,
         0,
         0,
         5,
         4,
         "duplicate points must not change the bounding rect");
   end Duplicate_Points;

   procedure Empty_Contour (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Empty : constant OpenCV.Geometry.Contour :=
        (1 .. 0 => OpenCV.Core.Point'(X => 0, Y => 0));
      Box   : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Empty);
   begin
      Assert_Rect (Box, 0, 0, 0, 0, "empty contour must return an empty rect");
   end Empty_Contour;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Shifted  : constant OpenCV.Geometry.Contour (7 .. 10) := Square;
      Ordinary : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Square);
      Offset   : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Shifted);
   begin
      Assert_Rect
        (Offset,
         Ordinary.X,
         Ordinary.Y,
         Ordinary.Width,
         Ordinary.Height,
         "bounding rect must not depend on Ada array lower bound");
   end Nonzero_Array_Bounds;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Square;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Box      : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Points);
   begin
      AUnit.Assertions.Assert
        (Same_Sequence (Points, Original),
         "Bounding_Rect must leave the input contour unchanged");
      Assert_Rect (Box, 0, 0, 5, 4, "input must still produce the square box");
   end Input_Unchanged;

   procedure Matches_Convex_Hull (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Concave : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 3),
         (X => 2, Y => 1),
         (X => 0, Y => 3));
      Direct  : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Concave);
      Hulled  : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (OpenCV.Geometry.Convex_Hull (Concave));
   begin
      Assert_Rect
        (Hulled,
         Direct.X,
         Direct.Y,
         Direct.Width,
         Direct.Height,
         "hull extrema must match the original axis-aligned box");
   end Matches_Convex_Hull;

   procedure Extreme_Representable_Extent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Last_Minus_One : constant OpenCV.Core.Point_Coordinate :=
        OpenCV.Core.Point_Coordinate (Interfaces.Integer_32'Last - 1);
      Points         : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => Last_Minus_One, Y => Last_Minus_One));
      Box            : constant OpenCV.Core.Rect :=
        OpenCV.Geometry.Bounding_Rect (Points);
   begin
      Assert_Rect
        (Box,
         0,
         0,
         OpenCV.Core.Size_Coordinate (Interfaces.Integer_32'Last),
         OpenCV.Core.Size_Coordinate (Interfaces.Integer_32'Last),
         "max representable inclusive extent must remain exact");
   end Extreme_Representable_Extent;

   procedure Assert_Rejected_Span
     (Points : in out C_API.Point_I32_Array; Message : String)
   is
      Box    : aliased C_API.Rect_I32 :=
        (X => -1, Y => -1, Width => -1, Height => -1);
      Status : C_API.Status;
   begin
      Status :=
        C_API.Bounding_Rect
          (Points (Points'First)'Access,
           Interfaces.Integer_32 (Points'Length),
           Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, Message & ": status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "extent") /= 0
         or else Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "range")
                 /= 0,
         Message & ": diagnostic");
      Assert_C_Rect
        (Box, 0, 0, 0, 0, Message & ": output must be reset to zero");
   end Assert_Rejected_Span;

   procedure Full_Signed_X_Range (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => Interfaces.Integer_32'Last, Y => 0));
   begin
      Assert_Rejected_Span
        (Buffer, "full signed X range must not reach native boundingRect");
   end Full_Signed_X_Range;

   procedure Full_Signed_Y_Range (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => Interfaces.Integer_32'First),
         (X => 0, Y => Interfaces.Integer_32'Last));
   begin
      Assert_Rejected_Span
        (Buffer, "full signed Y range must not reach native boundingRect");
   end Full_Signed_Y_Range;

   procedure Extent_One_Beyond_Maximum (Test : in out Fixture) is
      pragma Unreferenced (Test);
      --  Inclusive width is Integer_32'Last + 1: xmax - xmin + 1 with
      --  xmin = 0 and xmax = Integer_32'Last. Both coordinates remain
      --  representable; only the span is unrepresentable.
      Buffer : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => 0), (X => Interfaces.Integer_32'Last, Y => 0));
   begin
      Assert_Rejected_Span
        (Buffer, "inclusive extent Integer_32'Last + 1 must be rejected");
   end Extent_One_Beyond_Maximum;

   procedure Negative_Origin_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => -2, Y => -3), (X => 4, Y => 1));
      Raised : Boolean := False;
   begin
      begin
         declare
            Unused : constant OpenCV.Core.Rect :=
              OpenCV.Geometry.Bounding_Rect (Points);
            pragma Unreferenced (Unused);
         begin
            null;
         end;
      exception
         when Error : OpenCV.OpenCV_Error =>
            Raised :=
              Ada.Strings.Fixed.Index
                (Ada.Exceptions.Exception_Message (Error), "OpenCV.Core.Rect")
              /= 0;
      end;

      AUnit.Assertions.Assert
        (Raised,
         "negative origin must be rejected by OpenCV.Core.Rect conversion");
   end Negative_Origin_Rejected;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Box    : aliased C_API.Rect_I32 :=
        (X => -1, Y => -1, Width => -1, Height => -1);
      Buffer : aliased C_API.Point_I32_Array (0 .. 1) :=
        (0 => (X => -2, Y => -3), 1 => (X => 4, Y => 1));
      Status : C_API.Status;
   begin
      Status := C_API.Bounding_Rect (null, -1, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "count")
                  /= 0,
         "negative bounding-rect point count must be rejected");
      Assert_C_Rect
        (Box, 0, 0, 0, 0, "invalid count must initialize output to zero");

      Box := (X => -1, Y => -1, Width => -1, Height => -1);
      Status := C_API.Bounding_Rect (null, 1, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "points")
                  /= 0,
         "null points with positive count must be rejected");
      Assert_C_Rect
        (Box, 0, 0, 0, 0, "invalid points must initialize output to zero");

      Status := C_API.Bounding_Rect (null, 0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "output")
                  /= 0,
         "null bounding-rect output pointer must be rejected");

      Box := (X => -1, Y => -1, Width => -1, Height => -1);
      Status := C_API.Bounding_Rect (null, 0, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "zero-count null bounding rect must succeed");
      Assert_C_Rect
        (Box, 0, 0, 0, 0, "empty ABI input must return an empty rectangle");

      Box := (X => -1, Y => -1, Width => -1, Height => -1);
      Status := C_API.Bounding_Rect (Buffer (0)'Access, 2, Box'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success,
         "signed native bounding rect must succeed at the ABI");
      Assert_C_Rect
        (Box,
         -2,
         -3,
         7,
         5,
         "ABI must preserve OpenCV's signed origin and inclusive extent");
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Bounding rect ordinary rectangle", Ordinary_Rectangle'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect translated rectangle",
            Translated_Rectangle'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect inclusive integer extent",
            Inclusive_Integer_Extent'Access));
      Result.Add_Test
        (Caller.Create ("Bounding rect single point", Single_Point'Access));
      Result.Add_Test
        (Caller.Create ("Bounding rect two points", Two_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect horizontal collinear points",
            Horizontal_Collinear'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect vertical collinear points",
            Vertical_Collinear'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect unordered points", Unordered_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect duplicate points", Duplicate_Points'Access));
      Result.Add_Test
        (Caller.Create ("Bounding rect empty contour", Empty_Contour'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect preserves array order",
            Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect leaves input unchanged", Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect matches convex hull", Matches_Convex_Hull'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect extreme representable extent",
            Extreme_Representable_Extent'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect full signed X range rejected",
            Full_Signed_X_Range'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect full signed Y range rejected",
            Full_Signed_Y_Range'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect extent one beyond maximum",
            Extent_One_Beyond_Maximum'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect negative origin rejected",
            Negative_Origin_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Bounding rect C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Bounding_Rect_Tests;
