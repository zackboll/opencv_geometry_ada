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
   Error_Unsupported      : constant Status := 5;

   Feature_Approx_Poly_N                : constant Interfaces.Integer_32 := 1;
   Feature_Closest_Ellipse_Points       : constant Interfaces.Integer_32 := 2;
   Feature_Min_Enclosing_Convex_Polygon : constant Interfaces.Integer_32 := 3;
   Feature_Float32_Subdivision_Bounds   : constant Interfaces.Integer_32 := 4;

   function Native_Feature_Supported
     (Feature   : Interfaces.Integer_32;
      Supported : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_native_feature_supported";

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

   function Closest_Ellipse_Points_I32
     (Ellipse     : access constant C_Rotated_Rect;
      Points      : access constant Point_I32;
      Point_Count : Interfaces.Integer_32;
      Output      : access Point_F32;
      Capacity    : Interfaces.Integer_32;
      Count       : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_closest_ellipse_points_i32";

   function Closest_Ellipse_Points_F32
     (Ellipse     : access constant C_Rotated_Rect;
      Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Output      : access Point_F32;
      Capacity    : Interfaces.Integer_32;
      Count       : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_closest_ellipse_points_f32";

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

   --  Binary32 (CV_32F) point-set variants. Points may be null only when
   --  Point_Count is zero.

   function Contour_Area_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Oriented    : Interfaces.Integer_32;
      Area        : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_contour_area_f32";

   function Arc_Length_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Closed      : Interfaces.Integer_32;
      Length      : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_arc_length_f32";

   function Contour_Moments_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Moments) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_contour_moments_f32";

   function Bounding_Rect_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Result      : access Rect_I32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_bounding_rect_f32";

   function Is_Convex_F32
     (Points        : access constant Point_F32;
      Point_Count   : Interfaces.Integer_32;
      Out_Is_Convex : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_is_convex_f32";

   function Convex_Hull_F32
     (Points       : access constant Point_F32;
      Point_Count  : Interfaces.Integer_32;
      Clockwise    : Interfaces.Integer_32;
      Out_Points   : access Point_F32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_convex_hull_f32";

   function Convex_Hull_Indices_F32
     (Points       : access constant Point_F32;
      Point_Count  : Interfaces.Integer_32;
      Clockwise    : Interfaces.Integer_32;
      Out_Indices  : access Interfaces.Integer_32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_convex_hull_indices_f32";

   function Approximate_Curve_F32
     (Points       : access constant Point_F32;
      Point_Count  : Interfaces.Integer_32;
      Epsilon      : Interfaces.C.double;
      Closed       : Interfaces.Integer_32;
      Out_Points   : access Point_F32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_approximate_curve_f32";

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

   function Match_Shapes_F32
     (Left_Points  : access constant Point_F32;
      Left_Count   : Interfaces.Integer_32;
      Right_Points : access constant Point_F32;
      Right_Count  : Interfaces.Integer_32;
      Method       : Interfaces.Integer_32;
      Out_Score    : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_match_shapes_f32";

   function Point_Polygon_Test_F32
     (Points           : access constant Point_F32;
      Point_Count      : Interfaces.Integer_32;
      Query_X          : Interfaces.C.C_float;
      Query_Y          : Interfaces.C.C_float;
      Measure_Distance : Interfaces.Integer_32;
      Out_Result       : access Interfaces.C.double) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_point_polygon_test_f32";

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

   function Min_Enclosing_Circle_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Enclosing_Circle) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_min_enclosing_circle_f32";

   function Min_Area_Rect_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_min_area_rect_f32";

   function Fit_Ellipse_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_ellipse_f32";

   function Fit_Ellipse_AMS_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_ellipse_ams_f32";

   function Fit_Ellipse_Direct_F32
     (Points      : access constant Point_F32;
      Point_Count : Interfaces.Integer_32;
      Result      : access C_Rotated_Rect) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_ellipse_direct_f32";

   type C_Line_2D is record
      Direction_X : Interfaces.C.C_float;
      Direction_Y : Interfaces.C.C_float;
      Point_X     : Interfaces.C.C_float;
      Point_Y     : Interfaces.C.C_float;
   end record
   with Convention => C;

   Line_Fit_L2     : constant Interfaces.Integer_32 := 0;
   Line_Fit_L1     : constant Interfaces.Integer_32 := 1;
   Line_Fit_L12    : constant Interfaces.Integer_32 := 2;
   Line_Fit_Fair   : constant Interfaces.Integer_32 := 3;
   Line_Fit_Welsch : constant Interfaces.Integer_32 := 4;
   Line_Fit_Huber  : constant Interfaces.Integer_32 := 5;

   function Fit_Line_2D
     (Points          : access Point_I32;
      Point_Count     : Interfaces.Integer_32;
      Distance        : Interfaces.Integer_32;
      Parameter       : Interfaces.C.double;
      Radius_Accuracy : Interfaces.C.double;
      Angle_Accuracy  : Interfaces.C.double;
      Result          : access C_Line_2D) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_line_2d";

   function Fit_Line_2D_F32
     (Points          : access constant Point_F32;
      Point_Count     : Interfaces.Integer_32;
      Distance        : Interfaces.Integer_32;
      Parameter       : Interfaces.C.double;
      Radius_Accuracy : Interfaces.C.double;
      Angle_Accuracy  : Interfaces.C.double;
      Result          : access C_Line_2D) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_fit_line_2d_f32";

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

   --  Row-major 3x3 perspective coefficients; MRC is row R, column C.
   type C_Perspective_3x3_F64 is record
      M00 : Interfaces.C.double;
      M01 : Interfaces.C.double;
      M02 : Interfaces.C.double;
      M10 : Interfaces.C.double;
      M11 : Interfaces.C.double;
      M12 : Interfaces.C.double;
      M20 : Interfaces.C.double;
      M21 : Interfaces.C.double;
      M22 : Interfaces.C.double;
   end record
   with Convention => C;

   type Triangle_Point_Array is array (0 .. 2) of Point_F32
   with Convention => C;

   --  Exactly three binary32 points of an affine correspondence.
   type C_Triangle_Points is record
      Points : Triangle_Point_Array;
   end record
   with Convention => C;

   type Quad_Point_Array is array (0 .. 3) of Point_F32 with Convention => C;

   --  Exactly four binary32 points of a perspective correspondence.
   type C_Quad_Points is record
      Points : Quad_Point_Array;
   end record
   with Convention => C;

   function Get_Affine_Transform
     (Source      : access constant C_Triangle_Points;
      Destination : access constant C_Triangle_Points;
      Result      : access C_Affine_2x3_F64) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_get_affine_transform";

   function Invert_Affine_Transform
     (Transform : access constant C_Affine_2x3_F64;
      Result    : access C_Affine_2x3_F64) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_invert_affine_transform";

   Perspective_Solve_LU  : constant Interfaces.Integer_32 := 0;
   Perspective_Solve_SVD : constant Interfaces.Integer_32 := 1;
   Perspective_Solve_QR  : constant Interfaces.Integer_32 := 2;

   function Get_Perspective_Transform
     (Source       : access constant C_Quad_Points;
      Destination  : access constant C_Quad_Points;
      Solve_Method : Interfaces.Integer_32;
      Result       : access C_Perspective_3x3_F64) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_get_perspective_transform";

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

   function Intersect_Convex_Convex_F32
     (Left_Points   : access constant Point_F32;
      Left_Count    : Interfaces.Integer_32;
      Right_Points  : access constant Point_F32;
      Right_Count   : Interfaces.Integer_32;
      Handle_Nested : Interfaces.Integer_32;
      Out_Vertices  : access Point_F32;
      Out_Capacity  : Interfaces.Integer_32;
      Out_Count     : access Interfaces.Integer_32;
      Out_Area      : access Interfaces.C.C_float) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_intersect_convex_convex_f32";

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

   --  Opaque native cv::Subdiv2D owner. Ada never allocates, copies, or
   --  dereferences it; only OpenCV.Geometry.Subdiv2D holds a handle. The
   --  zero storage size makes an Ada allocator for the handle type illegal.
   type Subdiv2D_Record is null record with Convention => C;

   type Subdiv2D_Handle is access all Subdiv2D_Record
   with Convention => C, Storage_Size => 0;

   function Subdiv2D_Create
     (Bounds : access constant Rect_I32; Out_Handle : access Subdiv2D_Handle)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_create";

   procedure Subdiv2D_Destroy (Handle : Subdiv2D_Handle)
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_destroy";

   function Subdiv2D_Init_Delaunay
     (Handle : Subdiv2D_Handle; Bounds : access constant Rect_I32)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_init_delaunay";

   function Subdiv2D_Is_Usable
     (Handle : Subdiv2D_Handle) return Interfaces.Integer_32
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_is_usable";

   function Subdiv2D_Insert
     (Handle     : Subdiv2D_Handle;
      X          : Interfaces.C.C_float;
      Y          : Interfaces.C.C_float;
      Out_Vertex : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_insert";

   function Subdiv2D_Insert_Points
     (Handle             : Subdiv2D_Handle;
      Points             : access constant Point_F32;
      Point_Count        : Interfaces.Integer_32;
      Out_Inserted_Count : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_insert_points";

   Subdiv2D_Location_Inside       : constant Interfaces.Integer_32 := 0;
   Subdiv2D_Location_On_Edge      : constant Interfaces.Integer_32 := 1;
   Subdiv2D_Location_On_Vertex    : constant Interfaces.Integer_32 := 2;
   Subdiv2D_Location_Outside_Rect : constant Interfaces.Integer_32 := 3;
   Subdiv2D_Location_Error        : constant Interfaces.Integer_32 := 4;

   function Subdiv2D_Locate
     (Handle       : Subdiv2D_Handle;
      X            : Interfaces.C.C_float;
      Y            : Interfaces.C.C_float;
      Out_Location : access Interfaces.Integer_32;
      Out_Edge     : access Interfaces.Integer_32;
      Out_Vertex   : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_locate";

   function Subdiv2D_Find_Nearest
     (Handle     : Subdiv2D_Handle;
      X          : Interfaces.C.C_float;
      Y          : Interfaces.C.C_float;
      Out_Vertex : access Interfaces.Integer_32;
      Out_Point  : access Point_F32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_find_nearest";

   function Subdiv2D_Quad_Edge_Count
     (Handle : Subdiv2D_Handle; Out_Count : access Interfaces.Integer_32)
      return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_quad_edge_count";

   type C_Edge_Segment is record
      Origin_X      : Interfaces.C.C_float;
      Origin_Y      : Interfaces.C.C_float;
      Destination_X : Interfaces.C.C_float;
      Destination_Y : Interfaces.C.C_float;
   end record
   with Convention => C;

   type C_Edge_Segment_Array is
     array (Natural range <>) of aliased C_Edge_Segment
   with Convention => C;

   type C_Triangle_Array is array (Natural range <>) of aliased C_Triangle
   with Convention => C;

   function Subdiv2D_Get_Edge_List
     (Handle       : Subdiv2D_Handle;
      Out_Edges    : access C_Edge_Segment;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_get_edge_list";

   function Subdiv2D_Get_Leading_Edge_List
     (Handle       : Subdiv2D_Handle;
      Out_Edges    : access Interfaces.Integer_32;
      Out_Capacity : Interfaces.Integer_32;
      Out_Count    : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_get_leading_edge_list";

   function Subdiv2D_Get_Triangle_List
     (Handle        : Subdiv2D_Handle;
      Out_Triangles : access C_Triangle;
      Out_Capacity  : Interfaces.Integer_32;
      Out_Count     : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_get_triangle_list";

   Subdiv2D_Vertex_Free     : constant Interfaces.Integer_32 := 0;
   Subdiv2D_Vertex_Delaunay : constant Interfaces.Integer_32 := 1;
   Subdiv2D_Vertex_Voronoi  : constant Interfaces.Integer_32 := 2;

   function Subdiv2D_Get_Vertex
     (Handle         : Subdiv2D_Handle;
      Vertex         : Interfaces.Integer_32;
      Out_Point      : access Point_F32;
      Out_First_Edge : access Interfaces.Integer_32;
      Out_Kind       : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_get_vertex";

   function Subdiv2D_Edge_Org
     (Handle     : Subdiv2D_Handle;
      Edge       : Interfaces.Integer_32;
      Out_Vertex : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_edge_org";

   function Subdiv2D_Edge_Dst
     (Handle     : Subdiv2D_Handle;
      Edge       : Interfaces.Integer_32;
      Out_Vertex : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_edge_dst";

   function Subdiv2D_Next_Edge
     (Handle   : Subdiv2D_Handle;
      Edge     : Interfaces.Integer_32;
      Out_Edge : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_next_edge";

   Subdiv2D_Next_Around_Org   : constant Interfaces.Integer_32 := 0;
   Subdiv2D_Next_Around_Dst   : constant Interfaces.Integer_32 := 1;
   Subdiv2D_Prev_Around_Org   : constant Interfaces.Integer_32 := 2;
   Subdiv2D_Prev_Around_Dst   : constant Interfaces.Integer_32 := 3;
   Subdiv2D_Next_Around_Left  : constant Interfaces.Integer_32 := 4;
   Subdiv2D_Next_Around_Right : constant Interfaces.Integer_32 := 5;
   Subdiv2D_Prev_Around_Left  : constant Interfaces.Integer_32 := 6;
   Subdiv2D_Prev_Around_Right : constant Interfaces.Integer_32 := 7;

   function Subdiv2D_Get_Edge
     (Handle     : Subdiv2D_Handle;
      Edge       : Interfaces.Integer_32;
      Navigation : Interfaces.Integer_32;
      Out_Edge   : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_get_edge";

   Subdiv2D_Rotate_Same             : constant Interfaces.Integer_32 := 0;
   Subdiv2D_Rotate_Rotated          : constant Interfaces.Integer_32 := 1;
   Subdiv2D_Rotate_Reversed         : constant Interfaces.Integer_32 := 2;
   Subdiv2D_Rotate_Reversed_Rotated : constant Interfaces.Integer_32 := 3;

   function Subdiv2D_Rotate_Edge
     (Handle   : Subdiv2D_Handle;
      Edge     : Interfaces.Integer_32;
      Rotation : Interfaces.Integer_32;
      Out_Edge : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_rotate_edge";

   function Subdiv2D_Sym_Edge
     (Handle   : Subdiv2D_Handle;
      Edge     : Interfaces.Integer_32;
      Out_Edge : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_sym_edge";

   type C_Voronoi_Facet is record
      Site        : Interfaces.Integer_32;
      Center_X    : Interfaces.C.C_float;
      Center_Y    : Interfaces.C.C_float;
      First_Point : Interfaces.Integer_32;
      Point_Count : Interfaces.Integer_32;
      Complete    : Interfaces.Integer_32;
   end record
   with Convention => C;

   type C_Voronoi_Facet_Array is
     array (Natural range <>) of aliased C_Voronoi_Facet
   with Convention => C;

   Subdiv2D_Voronoi_Select_Listed : constant Interfaces.Integer_32 := 0;
   Subdiv2D_Voronoi_Select_All    : constant Interfaces.Integer_32 := 1;

   function Subdiv2D_Voronoi_Facet_Counts
     (Handle          : Subdiv2D_Handle;
      Selection       : Interfaces.Integer_32;
      Vertices        : access constant Interfaces.Integer_32;
      Vertex_Count    : Interfaces.Integer_32;
      Out_Facet_Count : access Interfaces.Integer_32;
      Out_Point_Count : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_voronoi_facet_counts";

   function Subdiv2D_Get_Voronoi_Facets
     (Handle          : Subdiv2D_Handle;
      Selection       : Interfaces.Integer_32;
      Vertices        : access constant Interfaces.Integer_32;
      Vertex_Count    : Interfaces.Integer_32;
      Out_Facets      : access C_Voronoi_Facet;
      Facet_Capacity  : Interfaces.Integer_32;
      Out_Points      : access Point_F32;
      Point_Capacity  : Interfaces.Integer_32;
      Out_Facet_Count : access Interfaces.Integer_32;
      Out_Point_Count : access Interfaces.Integer_32) return Status
   with
     Import,
     Convention    => C,
     External_Name => "opencv_geometry_subdiv2d_get_voronoi_facets";

   function Last_Error_Message return String;

end OpenCV.Geometry.Internal.C_API;
