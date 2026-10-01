with Interfaces;

--  Pure Ada limits for binary32 (CV_32F) point sets, derived from native
--  OpenCV 4.6, 4.10, and 5.0. The public Float32 operations first reject
--  NaN and infinite coordinates with run-time checks; these helpers then
--  work only with finite values, and GNATprove proves that their
--  conversions and their integer and binary64 arithmetic cannot overflow.

package OpenCV.Geometry.Internal.Float32_Points
  with SPARK_Mode => On
is

   subtype Float32 is OpenCV.Float32_Value;
   subtype Float64 is OpenCV.Float64_Value;

   use type Float32;
   use type Float64;

   Binary32_Last : constant Float64 := Float64 (Float32'Last);

   --  OpenCV converts binary32 coordinates to a signed 32-bit int with
   --  cvFloor or cvRound, which is defined only in [-2**31, 2**31). Both
   --  bounds are exact binary32 values.
   Int32_Conversion_Limit : constant := 2.0**31;

   function Is_Int32_Convertible (Value : Float32) return Boolean
   is (Value >= -Int32_Conversion_Limit
       and then Value < Int32_Conversion_Limit)
   with Global => null;

   --  The value of cvFloor (Value).
   function Floor_Of (Value : Float32) return Long_Long_Integer
   with
     Global => null,
     Pre    => Is_Int32_Convertible (Value),
     Post   =>
       Floor_Of'Result
       in Long_Long_Integer (Interfaces.Integer_32'First)
        .. Long_Long_Integer (Interfaces.Integer_32'Last);

   --  OpenCV's inclusive integer extent cvFloor (High) - cvFloor (Low) + 1.
   function Inclusive_Extent (Low, High : Float32) return Long_Long_Integer
   is (Floor_Of (High) - Floor_Of (Low) + 1)
   with
     Global => null,
     Pre    => Is_Int32_Convertible (Low) and then Is_Int32_Convertible (High);

   type Coordinate_Bounds is record
      Min_X : Float32 := 0.0;
      Max_X : Float32 := 0.0;
      Min_Y : Float32 := 0.0;
      Max_Y : Float32 := 0.0;
   end record;

   function Is_Ordered (Bounds : Coordinate_Bounds) return Boolean
   is (Bounds.Min_X <= Bounds.Max_X and then Bounds.Min_Y <= Bounds.Max_Y)
   with Global => null;

   function Contains
     (Bounds : Coordinate_Bounds; Point : OpenCV.Float32_Point) return Boolean
   is (Point.X >= Bounds.Min_X
       and then Point.X <= Bounds.Max_X
       and then Point.Y >= Bounds.Min_Y
       and then Point.Y <= Bounds.Max_Y)
   with Global => null;

   --  Tight axis-aligned bounds: every point lies within them and each
   --  bound is attained by some point.
   function Bounds_Of (Points : Float32_Point_Array) return Coordinate_Bounds
   with
     Global => null,
     Pre    => Points'Length > 0,
     Post   =>
       Is_Ordered (Bounds_Of'Result)
       and then (for all Point of Points => Contains (Bounds_Of'Result, Point))
       and then (for some Position in Points'Range =>
                   Points (Position).X = Bounds_Of'Result.Min_X)
       and then (for some Position in Points'Range =>
                   Points (Position).X = Bounds_Of'Result.Max_X)
       and then (for some Position in Points'Range =>
                   Points (Position).Y = Bounds_Of'Result.Min_Y)
       and then (for some Position in Points'Range =>
                   Points (Position).Y = Bounds_Of'Result.Max_Y);

   function X_Span (Bounds : Coordinate_Bounds) return Float64
   is (Float64 (Bounds.Max_X) - Float64 (Bounds.Min_X))
   with Global => null, Pre => Is_Ordered (Bounds);

   function Y_Span (Bounds : Coordinate_Bounds) return Float64
   is (Float64 (Bounds.Max_Y) - Float64 (Bounds.Min_Y))
   with Global => null, Pre => Is_Ordered (Bounds);

   --  True when the X and Y spans, evaluated in binary64, are at most
   --  Float32'Last. Then no binary32 difference of two coordinates within
   --  Bounds overflows: such a binary64 span exceeds the exact span by less
   --  than 2.0**74, far below the 2.0**103 by which an exact difference must
   --  exceed Float32'Last before binary32 rounding overflows.
   function Spans_Are_Binary32 (Bounds : Coordinate_Bounds) return Boolean
   is (X_Span (Bounds) <= Binary32_Last
       and then Y_Span (Bounds) <= Binary32_Last)
   with Global => null, Pre => Is_Ordered (Bounds);

   --  True when the product of the X and Y spans, evaluated in binary64, is
   --  at most Float32'Last / 2. Then no binary32 product of an X difference
   --  and a Y difference within Bounds overflows: rounding the differences
   --  and the product grows it by a factor below 1 + 2.0**(-22).
   function Span_Product_Is_Binary32
     (Bounds : Coordinate_Bounds) return Boolean
   is (X_Span (Bounds) * Y_Span (Bounds) <= Binary32_Last / 2.0)
   with
     Global => null,
     Pre    => Is_Ordered (Bounds) and then Spans_Are_Binary32 (Bounds);

   --  minEnclosingCircle's circle through three points forms binary32
   --  products of a coordinate sum and two coordinate differences, at most
   --  16 * M**3 for coordinates of magnitude at most M; M = 2.0**41 keeps
   --  them below 2.0**127.
   Circle_Coordinate_Limit : constant := 2.0**41;

   --  fitLine forms binary32 products of two raw coordinates; M = 2.0**63
   --  keeps them at most 2.0**126.
   Line_Coordinate_Limit : constant := 2.0**63;

   --  True when every coordinate of Points has magnitude at most Limit.
   function Magnitudes_Are_At_Most
     (Points : Float32_Point_Array; Limit : Float32) return Boolean
   is (for all Point of Points =>
         abs Point.X <= Limit and then abs Point.Y <= Limit)
   with Global => null;

   --  Bound on the binary64 sums of absolute coordinates for which a
   --  binary32 running sum of the coordinates cannot overflow. Each
   --  binary32 addition grows a partial sum by at most a factor
   --  1 + 2.0**(-24) beyond the exact sum of absolute values, and the
   --  binary64 sums here differ from exact by less than 2.0**(-22)
   --  relatively. For fewer than 2**28 points the growth is below e**16,
   --  less than 2.0**23.1, so every binary32 partial sum stays below
   --  2.0**126.2, and so do coordinate differences from their mean.
   Coordinate_Sum_Limit : constant := 2.0**103;

   --  True when the absolute X coordinates and the absolute Y coordinates
   --  of Points each sum, in binary64, to at most Coordinate_Sum_Limit.
   function Coordinate_Sums_Are_Bounded
     (Points : Float32_Point_Array) return Boolean
   with Global => null;

end OpenCV.Geometry.Internal.Float32_Points;
