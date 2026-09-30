with Interfaces;

--  Pure Ada limits for convex-polygon intersection, derived from native
--  cv::intersectConvexConvex in OpenCV 4.6, 4.10, and 5.0.

package OpenCV.Geometry.Internal.Intersection
  with SPARK_Mode => On
is

   --  OpenCV converts integer polygon vertices to binary32 before
   --  intersecting them. Every integer of magnitude at most 2**24 converts
   --  exactly, so the polygons OpenCV intersects are exactly the polygons
   --  validated in Ada. OpenCV's intersection predicates themselves still
   --  use rounded binary32 and binary64 arithmetic.
   Binary32_Exact_Integer_Limit : constant := 2**24;

   function Is_Binary32_Exact (Points : OpenCV.Point_Array) return Boolean
   is (for all Point of Points =>
         Point.X
         in -Binary32_Exact_Integer_Limit .. Binary32_Exact_Integer_Limit
         and then Point.Y
                  in -Binary32_Exact_Integer_Limit
                   .. Binary32_Exact_Integer_Limit)
   with Global => null;

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
