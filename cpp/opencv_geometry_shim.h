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

const char *opencv_geometry_last_error_message(void);

int32_t opencv_geometry_opencv_major_version(void);

opencv_geometry_status
opencv_geometry_contour_area(
    const opencv_geometry_point_i32 *points,
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
opencv_geometry_contour_moments(
    const opencv_geometry_point_i32 *points,
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

opencv_geometry_status
opencv_geometry_bounding_rect(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rect_i32 *out_rect);

opencv_geometry_status
opencv_geometry_is_convex(
    const opencv_geometry_point_i32 *points,
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

opencv_geometry_status
opencv_geometry_min_enclosing_circle(
    const opencv_geometry_point_i32 *points,
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

#ifdef __cplusplus
}
#endif

#endif
