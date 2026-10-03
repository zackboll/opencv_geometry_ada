with Interfaces;
with OpenCV.Geometry.Internal.Convexity;

--  Pure Ada limits for convex-polygon intersection, derived from native
--  cv::intersectConvexConvex in OpenCV 4.6, 4.10, and 5.0.

package OpenCV.Geometry.Internal.Intersection
  with SPARK_Mode => On
is

   use type OpenCV.Float64_Value;

   --  OpenCV converts integer polygon vertices to binary32 before
   --  intersecting them. Every integer of magnitude at most 2**24 converts
   --  exactly, so the polygons OpenCV intersects are exactly the polygons
   --  validated in Ada.
   Binary32_Exact_Integer_Limit : constant := 2**24;

   function Is_Binary32_Exact (Points : OpenCV.Point_Array) return Boolean
   is (for all Point of Points =>
         Point.X
         in -Binary32_Exact_Integer_Limit .. Binary32_Exact_Integer_Limit
         and then Point.Y
                  in -Binary32_Exact_Integer_Limit
                   .. Binary32_Exact_Integer_Limit)
   with Global => null;

   --  OpenCV 4.x before 4.11 stays within its result buffer only while its
   --  orientation and segment tests are consistent. They are exact when the
   --  vertices are binary32-exact integers and the X and Y spans of both
   --  polygons together are at most Binary32_Exact_Integer_Limit: then every
   --  binary32 coordinate difference is an exact integer, every binary64
   --  product and sum in those tests is exact, its segment parameters
   --  compare exactly with 0 and 1, and its absolute 1.0E-5 tolerance never
   --  hides a nonzero orientation, which is at least 1. With rounded
   --  differences, valid convex polygons can overflow the native buffer.
   --  When every coordinate is even, differences of at most 2**25 are even
   --  and still exact, so Has_Exact_Differences also accepts those.
   function Joint_Spans_Are_At_Most
     (Left_Bounds, Right_Bounds : Convexity.Coordinate_Bounds; Limit : Natural)
      return Boolean
   is (Long_Long_Integer'Max
         (Long_Long_Integer (Left_Bounds.Max_X),
          Long_Long_Integer (Right_Bounds.Max_X))
       - Long_Long_Integer'Min
           (Long_Long_Integer (Left_Bounds.Min_X),
            Long_Long_Integer (Right_Bounds.Min_X))
       <= Long_Long_Integer (Limit)
       and then Long_Long_Integer'Max
                  (Long_Long_Integer (Left_Bounds.Max_Y),
                   Long_Long_Integer (Right_Bounds.Max_Y))
                - Long_Long_Integer'Min
                    (Long_Long_Integer (Left_Bounds.Min_Y),
                     Long_Long_Integer (Right_Bounds.Min_Y))
                <= Long_Long_Integer (Limit))
   with Global => null;

   function Is_Even (Points : OpenCV.Point_Array) return Boolean
   is (for all Point of Points => Point.X mod 2 = 0 and then Point.Y mod 2 = 0)
   with Global => null;

   --  The exact-difference rule for binary32-exact integer polygons with
   --  the given bounds: joint spans of at most 2**24, or all coordinates
   --  even AND joint spans of at most 2**25. No coordinate-range assumption
   --  from a prior Is_Binary32_Exact call is needed for this span rule.
   function Has_Exact_Differences
     (Left, Right               : OpenCV.Point_Array;
      Left_Bounds, Right_Bounds : Convexity.Coordinate_Bounds) return Boolean
   is (Joint_Spans_Are_At_Most
         (Left_Bounds, Right_Bounds, Binary32_Exact_Integer_Limit)
       or else (Is_Even (Left)
                and then Is_Even (Right)
                and then Joint_Spans_Are_At_Most
                           (Left_Bounds, Right_Bounds, 2**25)))
   with Global => null;

   --  Binary32 polygons are intersected as exactly as integer ones when they
   --  are a power-of-two scaling of integer polygons that satisfy the rules
   --  above: OpenCV's binary32 and binary64 arithmetic then scales exactly.
   --  The grid exponent is at least -8, so that a nonzero orientation,
   --  at least 2.0**(2 * Exponent), exceeds the tolerance, and at most 6, so
   --  that coordinate magnitudes, at most 2.0**30, stay below the 2.0**31 at
   --  which the int rounding in OpenCV's nested-polygon test overflows.
   subtype Grid_Exponent is Integer range -8 .. 6;

   --  2.0**(-Exponent) for each grid exponent.
   Grid_Divisor_Inverse :
     constant array (Grid_Exponent) of OpenCV.Float64_Value :=
       (2.0**8,
        2.0**7,
        2.0**6,
        2.0**5,
        2.0**4,
        2.0**3,
        2.0**2,
        2.0**1,
        1.0,
        2.0**(-1),
        2.0**(-2),
        2.0**(-3),
        2.0**(-4),
        2.0**(-5),
        2.0**(-6));

   --  Value divided by 2.0**Exponent, which is exact.
   function Grid_Scaled
     (Value : OpenCV.Float32_Value; Exponent : Grid_Exponent)
      return OpenCV.Float64_Value
   is (OpenCV.Float64_Value (Value) * Grid_Divisor_Inverse (Exponent))
   with Global => null;

   --  True when Value is an integer multiple of 2.0**Exponent whose
   --  quotient is binary32-exact.
   function Is_Grid_Coordinate
     (Value : OpenCV.Float32_Value; Exponent : Grid_Exponent) return Boolean
   is (OpenCV.Float64_Value'Truncation (Grid_Scaled (Value, Exponent))
       = Grid_Scaled (Value, Exponent)
       and then Grid_Scaled (Value, Exponent)
                in -OpenCV.Float64_Value (Binary32_Exact_Integer_Limit)
                 .. OpenCV.Float64_Value (Binary32_Exact_Integer_Limit))
   with Global => null;

   --  The integer coordinate Value / 2.0**Exponent.
   function Grid_Coordinate
     (Value : OpenCV.Float32_Value; Exponent : Grid_Exponent)
      return OpenCV.Point_Coordinate
   with
     Global => null,
     Pre    => Is_Grid_Coordinate (Value, Exponent),
     Post   =>
       Grid_Coordinate'Result
       in -Binary32_Exact_Integer_Limit .. Binary32_Exact_Integer_Limit
       and then OpenCV.Float64_Value (Grid_Coordinate'Result)
                = Grid_Scaled (Value, Exponent);

   --  Cyclic successor and predecessor of Index within First .. Last.
   function Next_Index (First, Last, Index : Natural) return Natural
   is (if Index >= Last then First else Index + 1)
   with Global => null;

   function Previous_Index (First, Last, Index : Natural) return Natural
   is (if Index <= First then Last else Index - 1)
   with Global => null;

   --  True when Hull lists all of First .. Last as one cyclic run in
   --  contour order, stepping +1 throughout or -1 throughout. When Hull is
   --  the convex hull of a polygon with those bounds, this holds exactly
   --  when the polygon is a simple, strictly convex polygon traversed once:
   --  every vertex is a hull vertex and the contour visits them in hull
   --  order. Self-intersecting stars, repeated traversals, and repeated or
   --  collinear vertices all fail it.
   function Is_Contour_Order_Hull
     (First, Last : Natural; Hull : Point_Index_Array) return Boolean
   is (Long_Long_Integer (Hull'Length)
       = Long_Long_Integer (Last) - Long_Long_Integer (First) + 1
       and then (for all Index of Hull => Index in First .. Last)
       and then ((for all Position in Hull'Range =>
                    (if Position < Hull'Last
                     then
                       Hull (Position + 1)
                       = Next_Index (First, Last, Hull (Position))))
                 or else (for all Position in Hull'Range =>
                            (if Position < Hull'Last
                             then
                               Hull (Position + 1)
                               = Previous_Index
                                   (First, Last, Hull (Position))))))
   with Global => null, Pre => First <= Last;

   --  Native intersectConvexConvex sizes its scratch buffer as
   --  2 * (n + m) + 4 points (4.11+ and 5.x) or 2 * (n + m) + 1 points
   --  (earlier 4.x) in signed int, so n + m must keep that product in
   --  Integer_32 range.
   Maximum_Input_Count : constant :=
     (Interfaces.Integer_32'Pos (Interfaces.Integer_32'Last) - 4) / 2;

   function Is_Safe_Input_Count
     (Left_Length, Right_Length : Natural) return Boolean
   is (Long_Long_Integer (Left_Length) + Long_Long_Integer (Right_Length)
       <= Maximum_Input_Count)
   with Global => null;

   --  The intersection has at most n + m vertices: upstream bounds the
   --  native result, including one sentinel slot, by n + m + 1 slots, and a
   --  nested result is one whole input polygon.
   function Output_Capacity
     (Left_Length, Right_Length : Natural) return Natural
   with
     Global => null,
     Pre    => Is_Safe_Input_Count (Left_Length, Right_Length),
     Post   =>
       Long_Long_Integer (Output_Capacity'Result)
       = Long_Long_Integer (Left_Length) + Long_Long_Integer (Right_Length);

end OpenCV.Geometry.Internal.Intersection;
