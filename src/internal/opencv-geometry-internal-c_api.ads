with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;

package OpenCV.Geometry.Internal.C_API is

   type Status is new Interfaces.Integer_32;

   Success                : constant Status := 0;
   Error_OpenCV           : constant Status := 1;
   Error_Standard_CPP     : constant Status := 2;
   Error_Unknown          : constant Status := 3;
   Error_Invalid_Argument : constant Status := 4;

   type Point_I32 is record
      X : Interfaces.Integer_32;
      Y : Interfaces.Integer_32;
   end record
   with Convention => C;

   type Point_I32_Array is array (Natural range <>) of aliased Point_I32
   with Convention => C;

   type Rect_I32 is record
      X      : Interfaces.Integer_32;
      Y      : Interfaces.Integer_32;
      Width  : Interfaces.Integer_32;
      Height : Interfaces.Integer_32;
   end record
   with Convention => C;

   type C_Moments is record
      M00 : Interfaces.C.double;
      M10 : Interfaces.C.double;
      M01 : Interfaces.C.double;
      M20 : Interfaces.C.double;
      M11 : Interfaces.C.double;
      M02 : Interfaces.C.double;
      M30 : Interfaces.C.double;
      M21 : Interfaces.C.double;
      M12 : Interfaces.C.double;
      M03 : Interfaces.C.double;

      Mu20 : Interfaces.C.double;
      Mu11 : Interfaces.C.double;
      Mu02 : Interfaces.C.double;
      Mu30 : Interfaces.C.double;
      Mu21 : Interfaces.C.double;
      Mu12 : Interfaces.C.double;
      Mu03 : Interfaces.C.double;

      Nu20 : Interfaces.C.double;
      Nu11 : Interfaces.C.double;
      Nu02 : Interfaces.C.double;
      Nu30 : Interfaces.C.double;
      Nu21 : Interfaces.C.double;
      Nu12 : Interfaces.C.double;
      Nu03 : Interfaces.C.double;
   end record
   with Convention => C;

   type C_Hu_Result is record
      Hu_1 : Interfaces.C.double;
      Hu_2 : Interfaces.C.double;
      Hu_3 : Interfaces.C.double;
      Hu_4 : Interfaces.C.double;
      Hu_5 : Interfaces.C.double;
      Hu_6 : Interfaces.C.double;
      Hu_7 : Interfaces.C.double;
   end record
   with Convention => C;

   function Last_Error_Message_Pointer return Interfaces.C.Strings.chars_ptr
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_last_error_message";

   function Contour_Area
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Oriented    : Interfaces.Integer_32;
      Area        : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_contour_area";

   function Arc_Length
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Closed      : Interfaces.Integer_32;
      Length      : access Interfaces.C.double) return Status
   with Import, Convention => C, External_Name => "opencv_geometry_arc_length";

   function Contour_Moments
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Moments) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_contour_moments";

   function Convex_Hull
     (Points       : access Point_I32;
      Point_Count  : Interfaces.Integer_32;
      Clockwise    : Interfaces.Integer_32;
      Out_Points   : access Point_I32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_convex_hull";

   function Approximate_Curve
     (Points       : access Point_I32;
      Point_Count  : Interfaces.Integer_32;
      Epsilon      : Interfaces.C.double;
      Closed       : Interfaces.Integer_32;
      Out_Points   : access Point_I32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_approximate_curve";

   function Bounding_Rect
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Result      : access Rect_I32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_bounding_rect";

   function Is_Convex
     (Points        : access Point_I32;
      Point_Count   : Interfaces.Integer_32;
      Out_Is_Convex : access Interfaces.Integer_32) return Status
   with Import, Convention => C, External_Name => "opencv_geometry_is_convex";

   function Hu_Moments
     (Moments : access constant C_Moments; Result : access C_Hu_Result)
      return Status
   with Import, Convention => C, External_Name => "opencv_geometry_hu_moments";

   Match_Shapes_Reciprocal_Log_Difference : constant Interfaces.Integer_32 :=
     0;
   Match_Shapes_Log_Difference            : constant Interfaces.Integer_32 :=
     1;
   Match_Shapes_Relative_Log_Difference   : constant Interfaces.Integer_32 :=
     2;

   function Match_Shapes
     (Left_Points  : access Point_I32;
      Left_Count   : Interfaces.Integer_32;
      Right_Points : access Point_I32;
      Right_Count  : Interfaces.Integer_32;
      Method       : Interfaces.Integer_32;
      Out_Score    : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_match_shapes";

   Point_Polygon_Classify : constant Interfaces.Integer_32 := 0;
   Point_Polygon_Distance : constant Interfaces.Integer_32 := 1;

   function Point_Polygon_Test
     (Points           : access Point_I32;
      Point_Count      : Interfaces.Integer_32;
      Query_X          : Interfaces.C.C_float;
      Query_Y          : Interfaces.C.C_float;
      Measure_Distance : Interfaces.Integer_32;
      Out_Result       : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_point_polygon_test";

   function Last_Error_Message return String;

end OpenCV.Geometry.Internal.C_API;
