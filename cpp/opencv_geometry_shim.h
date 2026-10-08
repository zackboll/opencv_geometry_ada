#ifndef OPENCV_GEOMETRY_SHIM_H
#define OPENCV_GEOMETRY_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t x;
    int32_t y;
} opencv_geometry_point_i32;

typedef struct {
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
} opencv_geometry_rect_i32;

typedef struct {
    float x;
    float y;
    float width;
    float height;
} opencv_geometry_rect_f32;

typedef struct opencv_geometry_moments {
    double m00;
    double m10;
    double m01;
    double m20;
    double m11;
    double m02;
    double m30;
    double m21;
    double m12;
    double m03;

    double mu20;
    double mu11;
    double mu02;
    double mu30;
    double mu21;
    double mu12;
    double mu03;

    double nu20;
    double nu11;
    double nu02;
    double nu30;
    double nu21;
    double nu12;
    double nu03;
} opencv_geometry_moments;

typedef struct {
    double hu1;
    double hu2;
    double hu3;
    double hu4;
    double hu5;
    double hu6;
    double hu7;
} opencv_geometry_hu_result;

typedef struct {
    float center_x;
    float center_y;
    float radius;
} opencv_geometry_enclosing_circle_f32;

typedef struct {
    float v0_x;
    float v0_y;
    float v1_x;
    float v1_y;
    float v2_x;
    float v2_y;
} opencv_geometry_triangle_f32;

typedef struct {
    float v0_x;
    float v0_y;
    float v1_x;
    float v1_y;
    float v2_x;
    float v2_y;
    float v3_x;
    float v3_y;
} opencv_geometry_box_vertices_f32;

typedef struct {
    float center_x;
    float center_y;
    float width;
    float height;
    float angle_degrees;
} opencv_geometry_rotated_rect_f32;

typedef struct {
    double m00;
    double m01;
    double m02;
    double m10;
    double m11;
    double m12;
} opencv_geometry_affine_2x3_f64;

/* One native convexity defect. Indices are zero-based offsets into the
   contour point buffer. fixed_point_depth is OpenCV's depth with eight
   fractional bits, so the geometric depth is fixed_point_depth / 256. */
typedef struct {
    int32_t start_index;
    int32_t end_index;
    int32_t farthest_index;
    int32_t fixed_point_depth;
} opencv_geometry_convexity_defect;

/* One binary32 point: an element of a variable-length Geometry result or of
   a fixed transform correspondence. */
typedef struct {
    float x;
    float y;
} opencv_geometry_point_f32;

/* Row-major 3x3 perspective transform coefficients; mRC is row R, column C. */
typedef struct {
    double m00;
    double m01;
    double m02;
    double m10;
    double m11;
    double m12;
    double m20;
    double m21;
    double m22;
} opencv_geometry_perspective_3x3_f64;

/* Exactly three binary32 points: one side of an affine correspondence. */
typedef struct {
    opencv_geometry_point_f32 points[3];
} opencv_geometry_triangle_points_f32;

/* Exactly four binary32 points: one side of a perspective correspondence. */
typedef struct {
    opencv_geometry_point_f32 points[4];
} opencv_geometry_quad_points_f32;

/* A fitted 2D line: OpenCV's unit direction (vx, vy) and a point (x0, y0)
   on the line. */
typedef struct {
    float direction_x;
    float direction_y;
    float point_x;
    float point_y;
} opencv_geometry_line_2d_f32;

typedef int32_t opencv_geometry_status;

#define OPENCV_GEOMETRY_OK                     ((opencv_geometry_status)0)
#define OPENCV_GEOMETRY_ERROR_OPENCV           ((opencv_geometry_status)1)
#define OPENCV_GEOMETRY_ERROR_STD              ((opencv_geometry_status)2)
#define OPENCV_GEOMETRY_ERROR_UNKNOWN          ((opencv_geometry_status)3)
#define OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT ((opencv_geometry_status)4)
#define OPENCV_GEOMETRY_ERROR_UNSUPPORTED      ((opencv_geometry_status)5)

/* Native availability, not Ada binding coverage. IDs are stable C ABI. */
#define OPENCV_GEOMETRY_FEATURE_APPROX_POLY_N               ((int32_t)1)
#define OPENCV_GEOMETRY_FEATURE_CLOSEST_ELLIPSE_POINTS      ((int32_t)2)
#define OPENCV_GEOMETRY_FEATURE_MIN_ENCLOSING_CONVEX_POLYGON ((int32_t)3)
#define OPENCV_GEOMETRY_FEATURE_FLOAT32_SUBDIVISION_BOUNDS  ((int32_t)4)

opencv_geometry_status opencv_geometry_native_feature_supported(
    int32_t feature, int32_t *out_supported);

/* Available on all supported versions; native beginning with 4.12.
   out_count is checked/zeroed before other arguments; failure leaves it zero.
   Empty input succeeds without a native call. */
opencv_geometry_status opencv_geometry_closest_ellipse_points_i32(
    const opencv_geometry_rotated_rect_f32 *ellipse,
    const opencv_geometry_point_i32 *points, int32_t point_count,
    opencv_geometry_point_f32 *output, int32_t capacity, int32_t *out_count);
opencv_geometry_status opencv_geometry_closest_ellipse_points_f32(
    const opencv_geometry_rotated_rect_f32 *ellipse,
    const opencv_geometry_point_f32 *points, int32_t point_count,
    opencv_geometry_point_f32 *output, int32_t capacity, int32_t *out_count);

const char *opencv_geometry_last_error_message(void);

int32_t opencv_geometry_opencv_major_version(void);
int32_t opencv_geometry_opencv_minor_version(void);

opencv_geometry_status
opencv_geometry_contour_area(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t oriented,
    double *out_area);

/* The _f32 functions take binary32 (CV_32F) point sets and call the native
   CV_32F path of the same OpenCV operation; coordinates are not rounded. */
opencv_geometry_status
opencv_geometry_contour_area_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    int32_t oriented,
    double *out_area);

opencv_geometry_status
opencv_geometry_arc_length(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t closed,
    double *out_length);

opencv_geometry_status
opencv_geometry_arc_length_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    int32_t closed,
    double *out_length);

opencv_geometry_status
opencv_geometry_contour_moments(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_moments *out_moments);

opencv_geometry_status
opencv_geometry_contour_moments_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    opencv_geometry_moments *out_moments);

opencv_geometry_status
opencv_geometry_convex_hull(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t clockwise,
    opencv_geometry_point_i32 *out_points,
    int32_t out_capacity,
    int32_t *out_count);

opencv_geometry_status
opencv_geometry_convex_hull_indices(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t clockwise,
    int32_t *out_indices,
    int32_t out_capacity,
    int32_t *out_count);

/* Hull points are bitwise copies of input points. Both hull functions
   reject NaN coordinates, which break OpenCV's sort. */
opencv_geometry_status
opencv_geometry_convex_hull_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    int32_t clockwise,
    opencv_geometry_point_f32 *out_points,
    int32_t out_capacity,
    int32_t *out_count);

opencv_geometry_status
opencv_geometry_convex_hull_indices_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    int32_t clockwise,
    int32_t *out_indices,
    int32_t out_capacity,
    int32_t *out_count);

opencv_geometry_status
opencv_geometry_convexity_defects(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    const int32_t *hull_indices,
    int32_t hull_count,
    opencv_geometry_convexity_defect *out_defects,
    int32_t out_capacity,
    int32_t *out_count);

opencv_geometry_status
opencv_geometry_approximate_curve(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    double epsilon,
    int32_t closed,
    opencv_geometry_point_i32 *out_points,
    int32_t out_capacity,
    int32_t *out_count);

/* Rejects NaN coordinates and X or Y spans above FLT_MAX, whose overflowing
   binary32 differences can make OpenCV read outside the curve. */
opencv_geometry_status
opencv_geometry_approximate_curve_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    double epsilon,
    int32_t closed,
    opencv_geometry_point_f32 *out_points,
    int32_t out_capacity,
    int32_t *out_count);

opencv_geometry_status
opencv_geometry_bounding_rect(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rect_i32 *out_rect);

/* Rejects NaN coordinates, coordinates outside [-2^31, 2^31), and floored
   extents whose inclusive width or height exceeds INT32_MAX, for which
   OpenCV's floor conversion or extent arithmetic is undefined. */
opencv_geometry_status
opencv_geometry_bounding_rect_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    opencv_geometry_rect_i32 *out_rect);

opencv_geometry_status
opencv_geometry_is_convex(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t *out_is_convex);

opencv_geometry_status
opencv_geometry_is_convex_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    int32_t *out_is_convex);

opencv_geometry_status
opencv_geometry_hu_moments(
    const opencv_geometry_moments *moments,
    opencv_geometry_hu_result *out_hu);

#define OPENCV_GEOMETRY_MATCH_SHAPES_RECIPROCAL_LOG_DIFFERENCE ((int32_t)0)
#define OPENCV_GEOMETRY_MATCH_SHAPES_LOG_DIFFERENCE            ((int32_t)1)
#define OPENCV_GEOMETRY_MATCH_SHAPES_RELATIVE_LOG_DIFFERENCE   ((int32_t)2)

opencv_geometry_status
opencv_geometry_match_shapes(
    const opencv_geometry_point_i32 *left_points,
    int32_t left_count,
    const opencv_geometry_point_i32 *right_points,
    int32_t right_count,
    int32_t method,
    double *out_score);

opencv_geometry_status
opencv_geometry_match_shapes_f32(
    const opencv_geometry_point_f32 *left_points,
    int32_t left_count,
    const opencv_geometry_point_f32 *right_points,
    int32_t right_count,
    int32_t method,
    double *out_score);

#define OPENCV_GEOMETRY_POINT_POLYGON_CLASSIFY ((int32_t)0)
#define OPENCV_GEOMETRY_POINT_POLYGON_DISTANCE ((int32_t)1)

opencv_geometry_status
opencv_geometry_point_polygon_test(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    float query_x,
    float query_y,
    int32_t measure_distance,
    double *out_result);

/* A nonempty contour rejects queries outside the cvRound range, as
   opencv_geometry_point_polygon_test does. */
opencv_geometry_status
opencv_geometry_point_polygon_test_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    float query_x,
    float query_y,
    int32_t measure_distance,
    double *out_result);

opencv_geometry_status
opencv_geometry_min_enclosing_circle(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_enclosing_circle_f32 *out_circle);

opencv_geometry_status
opencv_geometry_min_enclosing_circle_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    opencv_geometry_enclosing_circle_f32 *out_circle);

opencv_geometry_status
opencv_geometry_min_enclosing_triangle(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    double *out_area,
    opencv_geometry_triangle_f32 *out_triangle);

opencv_geometry_status
opencv_geometry_min_area_rect(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

/* Rejects NaN coordinates and more than INT32_MAX / 3 points: OpenCV sizes
   its rotating-calipers buffer as three floats per hull vertex in signed
   int, and every binary32 point can be a hull vertex. */
opencv_geometry_status
opencv_geometry_min_area_rect_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

opencv_geometry_status
opencv_geometry_fit_ellipse(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

opencv_geometry_status
opencv_geometry_fit_ellipse_ams(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

opencv_geometry_status
opencv_geometry_fit_ellipse_direct(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

/* Binary32 forms of the three ellipse fits, with the same count limits. */
opencv_geometry_status
opencv_geometry_fit_ellipse_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

opencv_geometry_status
opencv_geometry_fit_ellipse_ams_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

opencv_geometry_status
opencv_geometry_fit_ellipse_direct_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect);

/* Explicit fitLine distance selectors; the shim maps them to OpenCV's
   DistanceTypes. */
#define OPENCV_GEOMETRY_LINE_FIT_L2     ((int32_t)0)
#define OPENCV_GEOMETRY_LINE_FIT_L1     ((int32_t)1)
#define OPENCV_GEOMETRY_LINE_FIT_L12    ((int32_t)2)
#define OPENCV_GEOMETRY_LINE_FIT_FAIR   ((int32_t)3)
#define OPENCV_GEOMETRY_LINE_FIT_WELSCH ((int32_t)4)
#define OPENCV_GEOMETRY_LINE_FIT_HUBER  ((int32_t)5)

opencv_geometry_status
opencv_geometry_fit_line_2d(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t distance,
    double parameter,
    double radius_accuracy,
    double angle_accuracy,
    opencv_geometry_line_2d_f32 *out_line);

opencv_geometry_status
opencv_geometry_fit_line_2d_f32(
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    int32_t distance,
    double parameter,
    double radius_accuracy,
    double angle_accuracy,
    opencv_geometry_line_2d_f32 *out_line);

opencv_geometry_status
opencv_geometry_box_points(
    const opencv_geometry_rotated_rect_f32 *box,
    opencv_geometry_box_vertices_f32 *out_vertices);

opencv_geometry_status
opencv_geometry_get_rotation_matrix_2d(
    float center_x,
    float center_y,
    double angle_degrees,
    double scale,
    opencv_geometry_affine_2x3_f64 *out_transform);

opencv_geometry_status
opencv_geometry_get_affine_transform(
    const opencv_geometry_triangle_points_f32 *source,
    const opencv_geometry_triangle_points_f32 *destination,
    opencv_geometry_affine_2x3_f64 *out_transform);

/* transform may alias out_inverse: the shim copies the input before it
   writes any output. */
opencv_geometry_status
opencv_geometry_invert_affine_transform(
    const opencv_geometry_affine_2x3_f64 *transform,
    opencv_geometry_affine_2x3_f64 *out_inverse);

/* Explicit getPerspectiveTransform solve selectors; the shim maps them to
   OpenCV's DecompTypes. */
#define OPENCV_GEOMETRY_PERSPECTIVE_SOLVE_LU  ((int32_t)0)
#define OPENCV_GEOMETRY_PERSPECTIVE_SOLVE_SVD ((int32_t)1)
#define OPENCV_GEOMETRY_PERSPECTIVE_SOLVE_QR  ((int32_t)2)

opencv_geometry_status
opencv_geometry_get_perspective_transform(
    const opencv_geometry_quad_points_f32 *source,
    const opencv_geometry_quad_points_f32 *destination,
    int32_t solve_method,
    opencv_geometry_perspective_3x3_f64 *out_transform);

opencv_geometry_status
opencv_geometry_intersect_convex_convex(
    const opencv_geometry_point_i32 *left_points,
    int32_t left_count,
    const opencv_geometry_point_i32 *right_points,
    int32_t right_count,
    int32_t handle_nested,
    opencv_geometry_point_f32 *out_vertices,
    int32_t out_capacity,
    int32_t *out_count,
    float *out_area);

/* Binary32 polygons. Before OpenCV 4.11 both polygons must be an exact
   power-of-two scaling, by 2^k with k in [-8, 6], of integer polygons that
   opencv_geometry_intersect_convex_convex accepts there; otherwise OpenCV's
   rounded tests can overflow its own buffer. A vertex equal to
   (FLT_MAX, FLT_MAX) is taken to be OpenCV's sentinel and dropped. */
opencv_geometry_status
opencv_geometry_intersect_convex_convex_f32(
    const opencv_geometry_point_f32 *left_points,
    int32_t left_count,
    const opencv_geometry_point_f32 *right_points,
    int32_t right_count,
    int32_t handle_nested,
    opencv_geometry_point_f32 *out_vertices,
    int32_t out_capacity,
    int32_t *out_count,
    float *out_area);

/* Explicit rotated-rectangle intersection kinds; the shim maps OpenCV's
   RectanglesIntersectTypes to these values. */
#define OPENCV_GEOMETRY_RECTANGLES_INTERSECT_NONE    ((int32_t)0)
#define OPENCV_GEOMETRY_RECTANGLES_INTERSECT_PARTIAL ((int32_t)1)
#define OPENCV_GEOMETRY_RECTANGLES_INTERSECT_FULL    ((int32_t)2)

opencv_geometry_status
opencv_geometry_rotated_rectangle_intersection(
    const opencv_geometry_rotated_rect_f32 *left,
    const opencv_geometry_rotated_rect_f32 *right,
    int32_t *out_kind,
    opencv_geometry_point_f32 *out_vertices,
    int32_t out_capacity,
    int32_t *out_count);

/* Opaque owner of exactly one native cv::Subdiv2D. It is the only native
   object this ABI exposes. Create it with opencv_geometry_subdiv2d_create
   and release it with opencv_geometry_subdiv2d_destroy; the caller owns
   the handle in between. A handle must not be used after it is destroyed,
   and must not be used concurrently: OpenCV mutates internal state even in
   point location and nearest-vertex queries. Distinct handles are
   independent.

   A failed modification that may have left the native triangulation
   inconsistent, such as an allocation failure during insertion, marks the
   handle unusable. Every operation except init_delaunay, is_usable, and
   destroy then fails with OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT until
   init_delaunay succeeds. */
typedef struct opencv_geometry_subdiv2d opencv_geometry_subdiv2d;

/* Creates a subdivision initialised to an empty Delaunay triangulation of
   bounds. *out_handle is null unless the result is OPENCV_GEOMETRY_OK. */
opencv_geometry_status
opencv_geometry_subdiv2d_create(
    const opencv_geometry_rect_i32 *bounds,
    opencv_geometry_subdiv2d **out_handle);

/* Fixed symbols on all builds. Rect2f requires OpenCV 4.13+. Create checks
   out_handle and sets it null before returning UNSUPPORTED; no other
   arguments are inspected on old releases. Reset returns UNSUPPORTED before
   inspecting handle/bounds and leaves an existing handle unchanged. Native
   reset failure marks the handle unusable, as with integer initialization. */
opencv_geometry_status opencv_geometry_subdiv2d_create_f32(
    const opencv_geometry_rect_f32 *bounds,
    opencv_geometry_subdiv2d **out_handle);

opencv_geometry_status opencv_geometry_subdiv2d_init_delaunay_f32(
    opencv_geometry_subdiv2d *handle,
    const opencv_geometry_rect_f32 *bounds);

/* Destroys handle. A null handle is ignored. Never fails. */
void
opencv_geometry_subdiv2d_destroy(opencv_geometry_subdiv2d *handle);

/* Discards every point and reinitialises handle to an empty Delaunay
   triangulation of bounds. Success makes an unusable handle usable again. A
   failure of the native reinitialisation leaves the handle unusable; a null
   handle or bounds pointer is rejected without changing the handle. */
opencv_geometry_status
opencv_geometry_subdiv2d_init_delaunay(
    opencv_geometry_subdiv2d *handle,
    const opencv_geometry_rect_i32 *bounds);

/* 1 when handle is non-null and usable, otherwise 0. */
int32_t
opencv_geometry_subdiv2d_is_usable(const opencv_geometry_subdiv2d *handle);

opencv_geometry_status
opencv_geometry_subdiv2d_insert(
    opencv_geometry_subdiv2d *handle,
    float x,
    float y,
    int32_t *out_vertex);

/* Inserts points in order. On failure, *out_inserted_count reports how
   many leading points were inserted before the failing one. */
opencv_geometry_status
opencv_geometry_subdiv2d_insert_points(
    opencv_geometry_subdiv2d *handle,
    const opencv_geometry_point_f32 *points,
    int32_t point_count,
    int32_t *out_inserted_count);

/* Explicit point-location kinds; the shim maps OpenCV's PTLOC_* values to
   these. */
#define OPENCV_GEOMETRY_SUBDIV2D_LOCATION_INSIDE       ((int32_t)0)
#define OPENCV_GEOMETRY_SUBDIV2D_LOCATION_ON_EDGE      ((int32_t)1)
#define OPENCV_GEOMETRY_SUBDIV2D_LOCATION_ON_VERTEX    ((int32_t)2)
#define OPENCV_GEOMETRY_SUBDIV2D_LOCATION_OUTSIDE_RECT ((int32_t)3)
#define OPENCV_GEOMETRY_SUBDIV2D_LOCATION_ERROR        ((int32_t)4)

opencv_geometry_status
opencv_geometry_subdiv2d_locate(
    opencv_geometry_subdiv2d *handle,
    float x,
    float y,
    int32_t *out_location,
    int32_t *out_edge,
    int32_t *out_vertex);

/* Nearest inserted vertex and its position. *out_vertex is 0 when OpenCV
   reports no vertex. */
opencv_geometry_status
opencv_geometry_subdiv2d_find_nearest(
    opencv_geometry_subdiv2d *handle,
    float x,
    float y,
    int32_t *out_vertex,
    opencv_geometry_point_f32 *out_point);

/* Number of native quad-edge slots. Every edge identifier is below four
   times this count, and it bounds the list sizes: at most count - 4 edges,
   and at most 2 * count - 2 leading edges or triangles. */
opencv_geometry_status
opencv_geometry_subdiv2d_quad_edge_count(
    const opencv_geometry_subdiv2d *handle,
    int32_t *out_count);

/* One Delaunay edge as its origin and destination positions. */
typedef struct {
    float origin_x;
    float origin_y;
    float destination_x;
    float destination_y;
} opencv_geometry_edge_segment_f32;

/* List functions write at most out_capacity elements. When the native list
   is longer, they fail with OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT and
   publish nothing; *out_count is 0 unless the result is OPENCV_GEOMETRY_OK.
   A null buffer is accepted only with capacity 0. */
opencv_geometry_status
opencv_geometry_subdiv2d_get_edge_list(
    const opencv_geometry_subdiv2d *handle,
    opencv_geometry_edge_segment_f32 *out_edges,
    int32_t out_capacity,
    int32_t *out_count);

opencv_geometry_status
opencv_geometry_subdiv2d_get_leading_edge_list(
    const opencv_geometry_subdiv2d *handle,
    int32_t *out_edges,
    int32_t out_capacity,
    int32_t *out_count);

opencv_geometry_status
opencv_geometry_subdiv2d_get_triangle_list(
    const opencv_geometry_subdiv2d *handle,
    opencv_geometry_triangle_f32 *out_triangles,
    int32_t out_capacity,
    int32_t *out_count);

/* Explicit vertex-slot kinds reported by get_vertex. VERTEX_FREE includes
   slot 0, OpenCV's reserved null vertex; VERTEX_DELAUNAY includes the
   super-triangle vertices 1 .. 3; VERTEX_VORONOI is OpenCV's virtual
   (Voronoi) vertex. */
#define OPENCV_GEOMETRY_SUBDIV2D_VERTEX_FREE     ((int32_t)0)
#define OPENCV_GEOMETRY_SUBDIV2D_VERTEX_DELAUNAY ((int32_t)1)
#define OPENCV_GEOMETRY_SUBDIV2D_VERTEX_VORONOI  ((int32_t)2)

/* Every function taking an identifier fails with
   OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT, with zeroed outputs, unless the
   identifier indexes native storage: 0 <= vertex < vertex slots and
   0 <= edge < 4 * quad-edge slots. */
opencv_geometry_status
opencv_geometry_subdiv2d_get_vertex(
    const opencv_geometry_subdiv2d *handle,
    int32_t vertex,
    opencv_geometry_point_f32 *out_point,
    int32_t *out_first_edge,
    int32_t *out_kind);

opencv_geometry_status
opencv_geometry_subdiv2d_edge_org(
    const opencv_geometry_subdiv2d *handle,
    int32_t edge,
    int32_t *out_vertex);

opencv_geometry_status
opencv_geometry_subdiv2d_edge_dst(
    const opencv_geometry_subdiv2d *handle,
    int32_t edge,
    int32_t *out_vertex);

opencv_geometry_status
opencv_geometry_subdiv2d_next_edge(
    const opencv_geometry_subdiv2d *handle,
    int32_t edge,
    int32_t *out_edge);

/* Explicit getEdge navigation selectors; the shim maps them to OpenCV's
   NEXT_AROUND_* and PREV_AROUND_* bit encodings. */
#define OPENCV_GEOMETRY_SUBDIV2D_NEXT_AROUND_ORG   ((int32_t)0)
#define OPENCV_GEOMETRY_SUBDIV2D_NEXT_AROUND_DST   ((int32_t)1)
#define OPENCV_GEOMETRY_SUBDIV2D_PREV_AROUND_ORG   ((int32_t)2)
#define OPENCV_GEOMETRY_SUBDIV2D_PREV_AROUND_DST   ((int32_t)3)
#define OPENCV_GEOMETRY_SUBDIV2D_NEXT_AROUND_LEFT  ((int32_t)4)
#define OPENCV_GEOMETRY_SUBDIV2D_NEXT_AROUND_RIGHT ((int32_t)5)
#define OPENCV_GEOMETRY_SUBDIV2D_PREV_AROUND_LEFT  ((int32_t)6)
#define OPENCV_GEOMETRY_SUBDIV2D_PREV_AROUND_RIGHT ((int32_t)7)

opencv_geometry_status
opencv_geometry_subdiv2d_get_edge(
    const opencv_geometry_subdiv2d *handle,
    int32_t edge,
    int32_t navigation,
    int32_t *out_edge);

/* Explicit rotateEdge selectors; the shim maps them to OpenCV's rotate
   argument. */
#define OPENCV_GEOMETRY_SUBDIV2D_ROTATE_SAME             ((int32_t)0)
#define OPENCV_GEOMETRY_SUBDIV2D_ROTATE_ROTATED          ((int32_t)1)
#define OPENCV_GEOMETRY_SUBDIV2D_ROTATE_REVERSED         ((int32_t)2)
#define OPENCV_GEOMETRY_SUBDIV2D_ROTATE_REVERSED_ROTATED ((int32_t)3)

opencv_geometry_status
opencv_geometry_subdiv2d_rotate_edge(
    const opencv_geometry_subdiv2d *handle,
    int32_t edge,
    int32_t rotation,
    int32_t *out_edge);

opencv_geometry_status
opencv_geometry_subdiv2d_sym_edge(
    const opencv_geometry_subdiv2d *handle,
    int32_t edge,
    int32_t *out_edge);

/* One Voronoi facet: the Delaunay vertex it surrounds, that vertex's
   position (OpenCV's facet center), and the facet polygon as point_count
   points starting at zero-based index first_point of the shared point
   list. Facets' points are contiguous and in facet order. complete is 1
   when OpenCV computed every Voronoi vertex of the facet, and 0 when some
   point is only OpenCV's placeholder, the null vertex's position (0, 0),
   for a Voronoi vertex it never computed: that of the facet outside the
   super-triangle, or of a degenerate (collinear) triangle, which OpenCV's
   absolute tolerances can leave among closely spaced points. */
typedef struct {
    int32_t site;
    float center_x;
    float center_y;
    int32_t first_point;
    int32_t point_count;
    int32_t complete;
} opencv_geometry_voronoi_facet_f32;

/* Voronoi facet selection. SELECT_ALL takes every Delaunay vertex slot from
   identifier 4, the inserted points, in increasing identifier order, and
   requires a null vertex list with count 0. SELECT_LISTED takes
   vertices[0 .. vertex_count - 1] in order, each of which must index native
   storage; unlike OpenCV, an empty list selects nothing. */
#define OPENCV_GEOMETRY_SUBDIV2D_VORONOI_SELECT_LISTED ((int32_t)0)
#define OPENCV_GEOMETRY_SUBDIV2D_VORONOI_SELECT_ALL    ((int32_t)1)

/* Unless the selection is empty, both functions run
   cv::Subdiv2D::getVoronoiFacetList, which first computes Voronoi data
   inside handle unless it is current. As in OpenCV, a listed free slot or
   Voronoi vertex produces no facet, a listed vertex produces one facet each
   time it is listed, and a listed super-triangle vertex (1 .. 3) produces an
   incomplete facet. Without an intervening modification of handle, the two
   functions report the same facets, so a caller can size the buffers from
   voronoi_facet_counts. A failure leaves the triangulation usable. */
opencv_geometry_status
opencv_geometry_subdiv2d_voronoi_facet_counts(
    opencv_geometry_subdiv2d *handle,
    int32_t selection,
    const int32_t *vertices,
    int32_t vertex_count,
    int32_t *out_facet_count,
    int32_t *out_point_count);

/* Writes the facets and their points. When either list exceeds its
   capacity the function fails with OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
   and publishes nothing; both counts are 0 unless the result is
   OPENCV_GEOMETRY_OK. A null buffer is accepted only with capacity 0. */
opencv_geometry_status
opencv_geometry_subdiv2d_get_voronoi_facets(
    opencv_geometry_subdiv2d *handle,
    int32_t selection,
    const int32_t *vertices,
    int32_t vertex_count,
    opencv_geometry_voronoi_facet_f32 *out_facets,
    int32_t facet_capacity,
    opencv_geometry_point_f32 *out_points,
    int32_t point_capacity,
    int32_t *out_facet_count,
    int32_t *out_point_count);

#ifdef __cplusplus
}
#endif

#endif
