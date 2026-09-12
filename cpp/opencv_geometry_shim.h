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

typedef int32_t opencv_geometry_status;

#define OPENCV_GEOMETRY_OK                     ((opencv_geometry_status)0)
#define OPENCV_GEOMETRY_ERROR_OPENCV           ((opencv_geometry_status)1)
#define OPENCV_GEOMETRY_ERROR_STD              ((opencv_geometry_status)2)
#define OPENCV_GEOMETRY_ERROR_UNKNOWN          ((opencv_geometry_status)3)
#define OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT ((opencv_geometry_status)4)

const char *opencv_geometry_last_error_message(void);

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

#ifdef __cplusplus
}
#endif

#endif
