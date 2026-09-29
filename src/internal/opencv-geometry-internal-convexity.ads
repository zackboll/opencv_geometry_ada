with Interfaces;

--  Pure Ada helpers for convex-hull indices and convexity defects: exact
--  translation between public indices in Points'Range and native zero-based
--  C ABI offsets, hull index ordering, and the coordinate-extent limit that
--  keeps native convexityDefects arithmetic within signed 32-bit range.

package OpenCV.Geometry.Internal.Convexity
  with SPARK_Mode => On
is

   use type Interfaces.Integer_32;

   --  Every Natural offset Index - First is representable in the signed
   --  32-bit C ABI.
   pragma
     Compile_Time_Error
       (Long_Long_Integer (Natural'Last)
          > Long_Long_Integer (Interfaces.Integer_32'Last),
        "Natural offsets must fit the signed 32-bit C ABI");

   --  True when Offset is a native zero-based offset of an array whose Ada
   --  bounds are First .. Last.
   function Is_Native_Offset
     (First, Last : Natural; Offset : Interfaces.Integer_32) return Boolean
   is (First <= Last
       and then Offset >= 0
       and then Long_Long_Integer (Offset)
                <= Long_Long_Integer (Last) - Long_Long_Integer (First))
   with Global => null;

   --  Ada index of native Offset in an array whose bounds are First .. Last.
   function To_Point_Index
     (First, Last : Natural; Offset : Interfaces.Integer_32) return Natural
   with
     Global => null,
     Pre    => Is_Native_Offset (First, Last, Offset),
     Post   =>
       To_Point_Index'Result in First .. Last
       and then Long_Long_Integer (To_Point_Index'Result)
                - Long_Long_Integer (First)
                = Long_Long_Integer (Offset);

   --  Native zero-based offset of Index in an array whose bounds are
   --  First .. Last. To_Point_Index inverts it.
   function To_Native_Offset
     (First, Last, Index : Natural) return Interfaces.Integer_32
   with
     Global => null,
     Pre    => Index in First .. Last,
     Post   =>
       Is_Native_Offset (First, Last, To_Native_Offset'Result)
       and then Long_Long_Integer (To_Native_Offset'Result)
                = Long_Long_Integer (Index) - Long_Long_Integer (First)
       and then To_Point_Index (First, Last, To_Native_Offset'Result) = Index;

   function Is_Strictly_Increasing (Hull : Point_Index_Array) return Boolean
   is (for all Position in Hull'Range =>
         (if Position > Hull'First then Hull (Position - 1) < Hull (Position)))
   with Global => null;

   function Is_Strictly_Decreasing (Hull : Point_Index_Array) return Boolean
   is (for all Position in Hull'Range =>
         (if Position > Hull'First then Hull (Position - 1) > Hull (Position)))
   with Global => null;

   --  The hull index ordering accepted by native convexityDefects without
   --  repeated indices.
   function Is_Strictly_Monotonic (Hull : Point_Index_Array) return Boolean
   is (Is_Strictly_Increasing (Hull) or else Is_Strictly_Decreasing (Hull))
   with Global => null;

   --  A strictly monotonic hull within First .. Last has at most
   --  Last - First + 1 indices, so a Points'Length capacity holds it.
   procedure Lemma_Monotonic_Hull_Length
     (First, Last : Natural; Hull : Point_Index_Array)
   with
     Ghost,
     Global => null,
     Pre    =>
       First <= Last
       and then Is_Strictly_Monotonic (Hull)
       and then (for all Index of Hull => Index in First .. Last),
     Post   =>
       Long_Long_Integer (Hull'Length)
       <= Long_Long_Integer (Last) - Long_Long_Integer (First) + 1;

   --  OpenCV stores a convexity-defect depth as cvRound (Depth * 256) in a
   --  signed 32-bit int, so this is the largest integral depth whose
   --  fixed-point value is representable.
   Fixed_Point_Depth_Scale : constant := 256;

   Maximum_Defect_Extent : constant :=
     Interfaces.Integer_32'Last / Fixed_Point_Depth_Scale;

   type Coordinate_Bounds is record
      Min_X : OpenCV.Point_Coordinate := 0;
      Max_X : OpenCV.Point_Coordinate := 0;
      Min_Y : OpenCV.Point_Coordinate := 0;
      Max_Y : OpenCV.Point_Coordinate := 0;
   end record;

   function Is_Ordered (Bounds : Coordinate_Bounds) return Boolean
   is (Bounds.Min_X <= Bounds.Max_X and then Bounds.Min_Y <= Bounds.Max_Y)
   with Global => null;

   function Contains
     (Bounds : Coordinate_Bounds; Point : OpenCV.Point) return Boolean
   is (Point.X in Bounds.Min_X .. Bounds.Max_X
       and then Point.Y in Bounds.Min_Y .. Bounds.Max_Y)
   with Global => null;

   --  Tight axis-aligned bounds: every point lies within them and each
   --  bound is attained by some point.
   function Bounds_Of (Points : OpenCV.Point_Array) return Coordinate_Bounds
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

   function Span (Low, High : OpenCV.Point_Coordinate) return Long_Long_Integer
   is (Long_Long_Integer (High) - Long_Long_Integer (Low))
   with Global => null, Pre => Low <= High;

   --  Width**2 + Height**2 <= Maximum_Defect_Extent**2, evaluated without
   --  overflow.
   function Defect_Extent_Is_Safe (Bounds : Coordinate_Bounds) return Boolean
   is (Span (Bounds.Min_X, Bounds.Max_X) <= Maximum_Defect_Extent
       and then Span (Bounds.Min_Y, Bounds.Max_Y) <= Maximum_Defect_Extent
       and then Span (Bounds.Min_X, Bounds.Max_X)
                * Span (Bounds.Min_X, Bounds.Max_X)
                + Span (Bounds.Min_Y, Bounds.Max_Y)
                  * Span (Bounds.Min_Y, Bounds.Max_Y)
                <= Maximum_Defect_Extent * Maximum_Defect_Extent)
   with Global => null, Pre => Is_Ordered (Bounds);

   --  Within safe bounds, every coordinate difference, and so every native
   --  signed int subtraction, is at most Maximum_Defect_Extent in magnitude,
   --  and the distance between any two points, which bounds every native
   --  defect depth, is at most Maximum_Defect_Extent.
   procedure Lemma_Pair_Within_Defect_Extent
     (Bounds : Coordinate_Bounds; Left, Right : OpenCV.Point)
   with
     Ghost,
     Global => null,
     Pre    =>
       Is_Ordered (Bounds)
       and then Defect_Extent_Is_Safe (Bounds)
       and then Contains (Bounds, Left)
       and then Contains (Bounds, Right),
     Post   =>
       abs (Long_Long_Integer (Left.X) - Long_Long_Integer (Right.X))
       <= Maximum_Defect_Extent
       and then abs (Long_Long_Integer (Left.Y) - Long_Long_Integer (Right.Y))
                <= Maximum_Defect_Extent
       and then (Long_Long_Integer (Left.X) - Long_Long_Integer (Right.X))
                * (Long_Long_Integer (Left.X) - Long_Long_Integer (Right.X))
                + (Long_Long_Integer (Left.Y) - Long_Long_Integer (Right.Y))
                  * (Long_Long_Integer (Left.Y) - Long_Long_Integer (Right.Y))
                <= Maximum_Defect_Extent * Maximum_Defect_Extent;

end OpenCV.Geometry.Internal.Convexity;
