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

   type Int32_Array is
     array (Natural range <>) of aliased Interfaces.Integer_32
   with Convention => C;

   --  Native zero-based offsets and OpenCV's eight-fractional-bit depth.
   type C_Convexity_Defect is record
      Start_Index       : Interfaces.Integer_32;
      End_Index         : Interfaces.Integer_32;
      Farthest_Index    : Interfaces.Integer_32;
      Fixed_Point_Depth : Interfaces.Integer_32;
   end record
   with Convention => C;

   type C_Convexity_Defect_Array is
     array (Natural range <>) of aliased C_Convexity_Defect
   with Convention => C;

   type Point_F32 is record
      X : Interfaces.C.C_float;
      Y : Interfaces.C.C_float;
   end record
   with Convention => C;

   type Point_F32_Array is array (Natural range <>) of aliased Point_F32
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

   type C_Enclosing_Circle is record
      Center_X : Interfaces.C.C_float;
      Center_Y : Interfaces.C.C_float;
      Radius   : Interfaces.C.C_float;
   end record
   with Convention => C;

   type C_Triangle is record
      V0_X : Interfaces.C.C_float;
      V0_Y : Interfaces.C.C_float;
      V1_X : Interfaces.C.C_float;
      V1_Y : Interfaces.C.C_float;
      V2_X : Interfaces.C.C_float;
      V2_Y : Interfaces.C.C_float;
   end record
   with Convention => C;

   type C_Box_Vertices is record
      V0_X : Interfaces.C.C_float;
      V0_Y : Interfaces.C.C_float;
      V1_X : Interfaces.C.C_float;
      V1_Y : Interfaces.C.C_float;
      V2_X : Interfaces.C.C_float;
      V2_Y : Interfaces.C.C_float;
      V3_X : Interfaces.C.C_float;
      V3_Y : Interfaces.C.C_float;
   end record
   with Convention => C;

   type C_Rotated_Rect is record
      Center_X      : Interfaces.C.C_float;
      Center_Y      : Interfaces.C.C_float;
      Width         : Interfaces.C.C_float;
      Height        : Interfaces.C.C_float;
      Angle_Degrees : Interfaces.C.C_float;
   end record
   with Convention => C;

   type C_Affine_2x3_F64 is record
      M00 : Interfaces.C.double;
      M01 : Interfaces.C.double;
      M02 : Interfaces.C.double;
      M10 : Interfaces.C.double;
      M11 : Interfaces.C.double;
      M12 : Interfaces.C.double;
   end record
   with Convention => C;

   function Last_Error_Message_Pointer return Interfaces.C.Strings.chars_ptr
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_last_error_message";

   function OpenCV_Major_Version return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_opencv_major_version";

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

   function Convex_Hull_Indices
     (Points       : access Point_I32;
      Point_Count  : Interfaces.Integer_32;
      Clockwise    : Interfaces.Integer_32;
      Out_Indices  : access Interfaces.Integer_32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_convex_hull_indices";

   function Convexity_Defects
     (Points       : access Point_I32;
      Point_Count  : Interfaces.Integer_32;
      Hull_Indices : access constant Interfaces.Integer_32;
      Hull_Count   : Interfaces.Integer_32;
      Out_Defects  : access C_Convexity_Defect;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_convexity_defects";

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

   function Min_Enclosing_Circle
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Enclosing_Circle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_min_enclosing_circle";

   function Min_Enclosing_Triangle
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Out_Area    : access Interfaces.C.double;
      Result      : access C_Triangle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_min_enclosing_triangle";

   function Min_Area_Rect
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_min_area_rect";

   function Fit_Ellipse
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_ellipse";

   function Fit_Ellipse_AMS
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_ellipse_ams";

   function Fit_Ellipse_Direct
     (Points      : access Point_I32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_ellipse_direct";

   function Box_Points
     (Box : access constant C_Rotated_Rect; Result : access C_Box_Vertices)
      return Status
   with Import, Convention => C, External_Name => "opencv_geometry_box_points";

   function Get_Rotation_Matrix_2D
     (Center_X      : Interfaces.C.C_float;
      Center_Y      : Interfaces.C.C_float;
      Angle_Degrees : Interfaces.C.double;
      Scale         : Interfaces.C.double;
      Result        : access C_Affine_2x3_F64) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_get_rotation_matrix_2d";

   function Intersect_Convex_Convex
     (Left_Points   : access Point_I32;
      Left_Count    : Interfaces.Integer_32;
      Right_Points  : access Point_I32;
      Right_Count   : Interfaces.Integer_32;
      Handle_Nested : Interfaces.Integer_32;
      Out_Vertices  : access Point_F32;
      Out_Capacity  : Interfaces.Integer_32;
      Out_Count     : access Interfaces.Integer_32;
      Out_Area      : access Interfaces.C.C_float) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_intersect_convex_convex";

   Rectangles_Intersect_None    : constant Interfaces.Integer_32 := 0;
   Rectangles_Intersect_Partial : constant Interfaces.Integer_32 := 1;
   Rectangles_Intersect_Full    : constant Interfaces.Integer_32 := 2;

   function Rotated_Rectangle_Intersection
     (Left         : access constant C_Rotated_Rect;
      Right        : access constant C_Rotated_Rect;
      Out_Kind     : access Interfaces.Integer_32;
      Out_Vertices : access Point_F32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_rotated_rectangle_intersection";

   function Last_Error_Message return String;

end OpenCV.Geometry.Internal.C_API;
