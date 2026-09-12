#include "opencv_geometry_shim.h"

#include <opencv2/core/version.hpp>
#if CV_VERSION_MAJOR >= 5
#include <opencv2/geometry.hpp>
#else
#include <opencv2/imgproc.hpp>
#endif

#include <cstdio>
#include <exception>
#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>

namespace {

constexpr std::size_t error_message_capacity = 1024;
thread_local char last_error_message[error_message_capacity] = "";

void clear_error() noexcept
{
    last_error_message[0] = '\0';
}

void set_error(const char *message) noexcept
{
    const char *safe_message =
        message == nullptr
            ? "No diagnostic message is available"
            : message;

    std::snprintf(
        last_error_message,
        error_message_capacity,
        "%s",
        safe_message);
}

opencv_geometry_status invalid_argument(const char *message) noexcept
{
    set_error(message);
    return OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT;
}

opencv_geometry_status translate_current_exception() noexcept
{
    try {
        throw;
    } catch (const cv::Exception &error) {
        set_error(error.what());
        return OPENCV_GEOMETRY_ERROR_OPENCV;
    } catch (const std::exception &error) {
        set_error(error.what());
        return OPENCV_GEOMETRY_ERROR_STD;
    } catch (...) {
        set_error("Unknown C++ exception");
        return OPENCV_GEOMETRY_ERROR_UNKNOWN;
    }
}

}

const char *opencv_geometry_last_error_message(void)
{
    return last_error_message;
}

opencv_geometry_status
opencv_geometry_contour_area(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t oriented,
    double *out_area)
{
    clear_error();
    if (out_area == nullptr) {
        return invalid_argument("null contour area output pointer");
    }
    *out_area = 0.0;
    if (point_count < 0) {
        return invalid_argument("contour point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (oriented != 0 && oriented != 1) {
        return invalid_argument("contour oriented selector must be zero or one");
    }
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        *out_area = cv::contourArea(contour, oriented != 0);
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_arc_length(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t closed,
    double *out_length)
{
    clear_error();
    if (out_length == nullptr) {
        return invalid_argument("null arc length output pointer");
    }
    *out_length = 0.0;
    if (point_count < 0) {
        return invalid_argument("arc length point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (closed != 0 && closed != 1) {
        return invalid_argument("arc length closed selector must be zero or one");
    }
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        *out_length = cv::arcLength(contour, closed != 0);
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        return translate_current_exception();
    }
}

namespace {

void zero_moments(opencv_geometry_moments *out_moments) noexcept
{
    *out_moments = opencv_geometry_moments{};
}

void copy_moments(
    const cv::Moments &source,
    opencv_geometry_moments *out_moments) noexcept
{
    out_moments->m00 = source.m00;
    out_moments->m10 = source.m10;
    out_moments->m01 = source.m01;
    out_moments->m20 = source.m20;
    out_moments->m11 = source.m11;
    out_moments->m02 = source.m02;
    out_moments->m30 = source.m30;
    out_moments->m21 = source.m21;
    out_moments->m12 = source.m12;
    out_moments->m03 = source.m03;

    out_moments->mu20 = source.mu20;
    out_moments->mu11 = source.mu11;
    out_moments->mu02 = source.mu02;
    out_moments->mu30 = source.mu30;
    out_moments->mu21 = source.mu21;
    out_moments->mu12 = source.mu12;
    out_moments->mu03 = source.mu03;

    out_moments->nu20 = source.nu20;
    out_moments->nu11 = source.nu11;
    out_moments->nu02 = source.nu02;
    out_moments->nu30 = source.nu30;
    out_moments->nu21 = source.nu21;
    out_moments->nu12 = source.nu12;
    out_moments->nu03 = source.nu03;
}

void copy_moments_from_abi(
    const opencv_geometry_moments *source,
    cv::Moments &out_moments) noexcept
{
    out_moments.m00 = source->m00;
    out_moments.m10 = source->m10;
    out_moments.m01 = source->m01;
    out_moments.m20 = source->m20;
    out_moments.m11 = source->m11;
    out_moments.m02 = source->m02;
    out_moments.m30 = source->m30;
    out_moments.m21 = source->m21;
    out_moments.m12 = source->m12;
    out_moments.m03 = source->m03;

    out_moments.mu20 = source->mu20;
    out_moments.mu11 = source->mu11;
    out_moments.mu02 = source->mu02;
    out_moments.mu30 = source->mu30;
    out_moments.mu21 = source->mu21;
    out_moments.mu12 = source->mu12;
    out_moments.mu03 = source->mu03;

    out_moments.nu20 = source->nu20;
    out_moments.nu11 = source->nu11;
    out_moments.nu02 = source->nu02;
    out_moments.nu30 = source->nu30;
    out_moments.nu21 = source->nu21;
    out_moments.nu12 = source->nu12;
    out_moments.nu03 = source->nu03;
}

void zero_hu(opencv_geometry_hu_result *out_hu) noexcept
{
    *out_hu = opencv_geometry_hu_result{};
}

}

opencv_geometry_status
opencv_geometry_contour_moments(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_moments *out_moments)
{
    clear_error();
    if (out_moments == nullptr) {
        return invalid_argument("null contour moments output pointer");
    }
    zero_moments(out_moments);
    if (point_count < 0) {
        return invalid_argument("contour point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        copy_moments(cv::moments(contour), out_moments);
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_moments(out_moments);
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_convex_hull(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t clockwise,
    opencv_geometry_point_i32 *out_points,
    int32_t out_capacity,
    int32_t *out_count)
{
    clear_error();
    if (out_count == nullptr) {
        return invalid_argument("null convex hull output count pointer");
    }
    *out_count = 0;
    if (point_count < 0) {
        return invalid_argument(
            "convex hull point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (clockwise != 0 && clockwise != 1) {
        return invalid_argument(
            "convex hull clockwise selector must be zero or one");
    }
    if (out_capacity < 0) {
        return invalid_argument(
            "convex hull output capacity must not be negative");
    }
    // ABI safety: a positive capacity with a null buffer would be written
    // if OpenCV returned any hull points.
    if (out_capacity > 0 && out_points == nullptr) {
        return invalid_argument(
            "null convex hull output points with positive capacity");
    }
    // OpenCV compatibility: OpenCV 4.10 rejects an empty point vector
    // because checkVector cannot determine an element depth. Geometry
    // defines an empty contour to produce an empty hull.
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        std::vector<cv::Point> hull;
        cv::convexHull(contour, hull, clockwise != 0, true);
        // ABI safety: copying more points than capacity would overflow the
        // caller-provided buffer. Hull cardinality is at most point_count.
        if (hull.size() > static_cast<std::size_t>(out_capacity)) {
            return invalid_argument(
                "convex hull output capacity is insufficient");
        }
        for (std::size_t index = 0; index < hull.size(); ++index) {
            out_points[index].x = hull[index].x;
            out_points[index].y = hull[index].y;
        }
        *out_count = static_cast<int32_t>(hull.size());
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_count = 0;
        return translate_current_exception();
    }
}

namespace {

bool integer_contour_arithmetic_is_safe(
    const opencv_geometry_point_i32 *points,
    int32_t point_count) noexcept
{
    // Native-call arithmetic safety: OpenCV 4.10 and 5.x isContourConvex_
    // for CV_32S points computes each consecutive (and wrap-around) edge
    // as signed int subtraction, then multiplies those deltas as signed
    // int. Reject contours whose native int operations would overflow.
    if (point_count <= 0) {
        return true;
    }

    const int64_t int32_min = static_cast<int64_t>(INT32_MIN);
    const int64_t int32_max = static_cast<int64_t>(INT32_MAX);
    int32_t previous_index = point_count - 2;
    if (previous_index < 0) {
        previous_index += point_count;
    }

    int32_t current_x = points[point_count - 1].x;
    int32_t current_y = points[point_count - 1].y;
    int64_t dx0 =
        static_cast<int64_t>(current_x)
        - static_cast<int64_t>(points[previous_index].x);
    int64_t dy0 =
        static_cast<int64_t>(current_y)
        - static_cast<int64_t>(points[previous_index].y);
    if (dx0 < int32_min || dx0 > int32_max
        || dy0 < int32_min || dy0 > int32_max) {
        return false;
    }

    for (int32_t index = 0; index < point_count; ++index) {
        const int64_t dx =
            static_cast<int64_t>(points[index].x)
            - static_cast<int64_t>(current_x);
        const int64_t dy =
            static_cast<int64_t>(points[index].y)
            - static_cast<int64_t>(current_y);
        if (dx < int32_min || dx > int32_max
            || dy < int32_min || dy > int32_max) {
            return false;
        }
        const int64_t dxdy0 = dx * dy0;
        const int64_t dydx0 = dy * dx0;
        if (dxdy0 < int32_min || dxdy0 > int32_max
            || dydx0 < int32_min || dydx0 > int32_max) {
            return false;
        }
        dx0 = dx;
        dy0 = dy;
        current_x = points[index].x;
        current_y = points[index].y;
    }

    return true;
}

}

opencv_geometry_status
opencv_geometry_is_convex(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t *out_is_convex)
{
    clear_error();
    if (out_is_convex == nullptr) {
        return invalid_argument("null is-convex output pointer");
    }
    *out_is_convex = 0;
    if (point_count < 0) {
        return invalid_argument("is-convex point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    // OpenCV compatibility: OpenCV 4.10 and 5.x reject an empty point
    // vector because checkVector cannot determine an element depth.
    // Native isContourConvex returns false for total == 0 when the depth
    // is known, so Geometry preserves that empty-input result.
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }

    // ABI safety: OpenCV 4.10/5.x integer isContourConvex subtracts and
    // multiplies consecutive Point coordinates in signed int. Validate
    // those operations in int64_t so extreme int32 contours cannot
    // overflow native arithmetic. This check does not decide convexity.
    if (!integer_contour_arithmetic_is_safe(points, point_count)) {
        return invalid_argument(
            "is-convex contour exceeds signed 32-bit arithmetic range");
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        *out_is_convex = cv::isContourConvex(contour) ? 1 : 0;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_is_convex = 0;
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_hu_moments(
    const opencv_geometry_moments *moments,
    opencv_geometry_hu_result *out_hu)
{
    clear_error();
    if (out_hu == nullptr) {
        return invalid_argument("null Hu moments output pointer");
    }
    zero_hu(out_hu);
    if (moments == nullptr) {
        return invalid_argument("null Hu moments input pointer");
    }

    try {
        cv::Moments native;
        copy_moments_from_abi(moments, native);
        double hu[7] = {};
        cv::HuMoments(native, hu);
        out_hu->hu1 = hu[0];
        out_hu->hu2 = hu[1];
        out_hu->hu3 = hu[2];
        out_hu->hu4 = hu[3];
        out_hu->hu5 = hu[4];
        out_hu->hu6 = hu[5];
        out_hu->hu7 = hu[6];
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_hu(out_hu);
        return translate_current_exception();
    }
}

namespace {

std::vector<cv::Point> contour_from_points(
    const opencv_geometry_point_i32 *points,
    int32_t point_count)
{
    std::vector<cv::Point> contour;
    if (point_count <= 0) {
        return contour;
    }
    contour.reserve(static_cast<std::size_t>(point_count));
    for (int32_t index = 0; index < point_count; ++index) {
        contour.emplace_back(points[index].x, points[index].y);
    }
    return contour;
}

bool match_shapes_method(
    int32_t method,
    int *native_method) noexcept
{
    // OpenCV 4 exposes CONTOURS_MATCH_I1/I2/I3 in imgproc.hpp. OpenCV 5
    // matchShapes lives in geometry.hpp, which documents ShapeMatchModes
    // but does not declare the enumerators. Native 4.x/5.x still switch
    // on 1/2/3, matching those documented values.
#if CV_VERSION_MAJOR >= 5
    const int contours_match_i1 = 1;
    const int contours_match_i2 = 2;
    const int contours_match_i3 = 3;
#else
    const int contours_match_i1 = cv::CONTOURS_MATCH_I1;
    const int contours_match_i2 = cv::CONTOURS_MATCH_I2;
    const int contours_match_i3 = cv::CONTOURS_MATCH_I3;
#endif
    switch (method) {
    case OPENCV_GEOMETRY_MATCH_SHAPES_RECIPROCAL_LOG_DIFFERENCE:
        *native_method = contours_match_i1;
        return true;
    case OPENCV_GEOMETRY_MATCH_SHAPES_LOG_DIFFERENCE:
        *native_method = contours_match_i2;
        return true;
    case OPENCV_GEOMETRY_MATCH_SHAPES_RELATIVE_LOG_DIFFERENCE:
        *native_method = contours_match_i3;
        return true;
    default:
        return false;
    }
}

}

opencv_geometry_status
opencv_geometry_match_shapes(
    const opencv_geometry_point_i32 *left_points,
    int32_t left_count,
    const opencv_geometry_point_i32 *right_points,
    int32_t right_count,
    int32_t method,
    double *out_score)
{
    clear_error();
    if (out_score == nullptr) {
        return invalid_argument("null match shapes output pointer");
    }
    *out_score = 0.0;
    if (left_count < 0) {
        return invalid_argument(
            "left contour point count must not be negative");
    }
    if (right_count < 0) {
        return invalid_argument(
            "right contour point count must not be negative");
    }
    if (left_count > 0 && left_points == nullptr) {
        return invalid_argument(
            "null left contour points with positive count");
    }
    if (right_count > 0 && right_points == nullptr) {
        return invalid_argument(
            "null right contour points with positive count");
    }
    int native_method = 0;
    if (!match_shapes_method(method, &native_method)) {
        return invalid_argument("match shapes method selector is invalid");
    }

    try {
        const std::vector<cv::Point> left =
            contour_from_points(left_points, left_count);
        const std::vector<cv::Point> right =
            contour_from_points(right_points, right_count);
        // Supported OpenCV 4.x/5.x ignore the unused native parameter.
        *out_score = cv::matchShapes(left, right, native_method, 0.0);
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_score = 0.0;
        return translate_current_exception();
    }
}

namespace {

bool query_is_integral_int32(float query_x, float query_y) noexcept
{
    if (!std::isfinite(query_x) || !std::isfinite(query_y)) {
        return false;
    }
    // OpenCV's integer fast path requires cvRound(pt) == pt exactly.
    // Compare against every representable int32 rather than depending
    // on the current floating-point rounding mode.
    if (query_x < static_cast<float>(INT32_MIN)
        || query_x > static_cast<float>(INT32_MAX)
        || query_y < static_cast<float>(INT32_MIN)
        || query_y > static_cast<float>(INT32_MAX)) {
        return false;
    }
    const int32_t ix = static_cast<int32_t>(query_x);
    const int32_t iy = static_cast<int32_t>(query_y);
    return static_cast<float>(ix) == query_x
        && static_cast<float>(iy) == query_y;
}

bool product_fits_int64(int64_t left, int64_t right) noexcept
{
    if (left == 0 || right == 0) {
        return true;
    }
    const uint64_t int64_limit = static_cast<uint64_t>(INT64_MAX);
    const uint64_t a =
        left == INT64_MIN
            ? static_cast<uint64_t>(INT64_MAX) + 1U
            : static_cast<uint64_t>(left < 0 ? -left : left);
    const uint64_t b =
        right == INT64_MIN
            ? static_cast<uint64_t>(INT64_MAX) + 1U
            : static_cast<uint64_t>(right < 0 ? -right : right);
    return a <= int64_limit / b;
}

bool integer_point_polygon_edge_is_safe(
    const opencv_geometry_point_i32 *points,
    int32_t from,
    int32_t to,
    int32_t query_x,
    int32_t query_y) noexcept
{
    const int64_t int32_min = static_cast<int64_t>(INT32_MIN);
    const int64_t int32_max = static_cast<int64_t>(INT32_MAX);
    const int64_t v0x = static_cast<int64_t>(points[from].x);
    const int64_t v0y = static_cast<int64_t>(points[from].y);
    const int64_t vx = static_cast<int64_t>(points[to].x);
    const int64_t vy = static_cast<int64_t>(points[to].y);
    const int64_t ipy_v0y = static_cast<int64_t>(query_y) - v0y;
    const int64_t vx_v0x = vx - v0x;
    const int64_t ipx_v0x = static_cast<int64_t>(query_x) - v0x;
    const int64_t vy_v0y = vy - v0y;
    if (ipy_v0y < int32_min || ipy_v0y > int32_max
        || vx_v0x < int32_min || vx_v0x > int32_max
        || ipx_v0x < int32_min || ipx_v0x > int32_max
        || vy_v0y < int32_min || vy_v0y > int32_max) {
        return false;
    }
    return product_fits_int64(ipy_v0y, vx_v0x)
        && product_fits_int64(ipx_v0x, vy_v0y);
}

bool integer_point_polygon_arithmetic_is_safe(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t query_x,
    int32_t query_y) noexcept
{
    // Native-call arithmetic safety: OpenCV 4.10/5.x integer
    // pointPolygonTest subtracts contour and query coordinates in
    // signed int, then multiplies those deltas as int64_t. Reject
    // contours whose native int subtractions or int64 products would
    // overflow. This check does not classify the query.
    if (point_count <= 1) {
        return true;
    }
    for (int32_t index = 0; index + 1 < point_count; ++index) {
        if (!integer_point_polygon_edge_is_safe(
                points, index, index + 1, query_x, query_y)) {
            return false;
        }
    }
    return integer_point_polygon_edge_is_safe(
        points, point_count - 1, 0, query_x, query_y);
}

}

opencv_geometry_status
opencv_geometry_point_polygon_test(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    float query_x,
    float query_y,
    int32_t measure_distance,
    double *out_result)
{
    clear_error();
    if (out_result == nullptr) {
        return invalid_argument("null point polygon test output pointer");
    }
    *out_result = 0.0;
    if (point_count < 0) {
        return invalid_argument(
            "point polygon test point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (measure_distance != 0 && measure_distance != 1) {
        return invalid_argument(
            "point polygon test mode selector must be zero or one");
    }
    // OpenCV compatibility: OpenCV 4.10 and 5.x reject an empty point
    // vector because checkVector cannot determine an element depth.
    // Native pointPolygonTest returns -1 / -DBL_MAX for total == 0 when
    // the depth is known, so Geometry preserves those empty-input results.
    if (point_count == 0) {
        *out_result =
            measure_distance != 0
                ? -std::numeric_limits<double>::max()
                : -1.0;
        return OPENCV_GEOMETRY_OK;
    }
    if (measure_distance == 0 && query_is_integral_int32(query_x, query_y)) {
        const int32_t qx = static_cast<int32_t>(query_x);
        const int32_t qy = static_cast<int32_t>(query_y);
        if (!integer_point_polygon_arithmetic_is_safe(
                points, point_count, qx, qy)) {
            return invalid_argument(
                "point polygon test exceeds signed 32-bit arithmetic range");
        }
    }

    try {
        const std::vector<cv::Point> contour =
            contour_from_points(points, point_count);
        const cv::Point2f query(query_x, query_y);
        *out_result =
            cv::pointPolygonTest(contour, query, measure_distance != 0);
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_result = 0.0;
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_bounding_rect(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rect_i32 *out_rect)
{
    clear_error();
    if (out_rect == nullptr) {
        return invalid_argument("null bounding rect output pointer");
    }
    out_rect->x = 0;
    out_rect->y = 0;
    out_rect->width = 0;
    out_rect->height = 0;
    if (point_count < 0) {
        return invalid_argument(
            "bounding rect point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    // OpenCV compatibility: OpenCV 4.10 and 5.x reject an empty point
    // vector because checkVector cannot determine an element depth.
    // Geometry defines an empty contour to produce an empty rectangle,
    // matching pointSetBoundingRect npoints == 0 return Rect().
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }

    // ABI safety: supported OpenCV 4.10/5.0 point-set boundingRect
    // computes extrema spans in signed int. Validate the span in int64_t
    // before the native call so extreme int32 coordinates cannot overflow.
    int32_t xmin = points[0].x;
    int32_t xmax = points[0].x;
    int32_t ymin = points[0].y;
    int32_t ymax = points[0].y;
    for (int32_t index = 1; index < point_count; ++index) {
        const int32_t x = points[index].x;
        const int32_t y = points[index].y;
        if (x < xmin) {
            xmin = x;
        }
        if (x > xmax) {
            xmax = x;
        }
        if (y < ymin) {
            ymin = y;
        }
        if (y > ymax) {
            ymax = y;
        }
    }
    const int64_t width =
        static_cast<int64_t>(xmax) - static_cast<int64_t>(xmin) + 1;
    const int64_t height =
        static_cast<int64_t>(ymax) - static_cast<int64_t>(ymin) + 1;
    if (width <= 0 || height <= 0
        || width > static_cast<int64_t>(INT32_MAX)
        || height > static_cast<int64_t>(INT32_MAX)) {
        return invalid_argument(
            "bounding rect extent exceeds signed 32-bit range");
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        const cv::Rect box = cv::boundingRect(contour);
        out_rect->x = box.x;
        out_rect->y = box.y;
        out_rect->width = box.width;
        out_rect->height = box.height;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        out_rect->x = 0;
        out_rect->y = 0;
        out_rect->width = 0;
        out_rect->height = 0;
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_approximate_curve(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    double epsilon,
    int32_t closed,
    opencv_geometry_point_i32 *out_points,
    int32_t out_capacity,
    int32_t *out_count)
{
    clear_error();
    if (out_count == nullptr) {
        return invalid_argument(
            "null approximate curve output count pointer");
    }
    *out_count = 0;
    if (point_count < 0) {
        return invalid_argument(
            "approximate curve point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (closed != 0 && closed != 1) {
        return invalid_argument(
            "approximate curve closed selector must be zero or one");
    }
    if (out_capacity < 0) {
        return invalid_argument(
            "approximate curve output capacity must not be negative");
    }
    // ABI safety: a positive capacity with a null buffer would be written
    // if OpenCV returned any approximation points.
    if (out_capacity > 0 && out_points == nullptr) {
        return invalid_argument(
            "null approximate curve output points with positive capacity");
    }
    // OpenCV compatibility: OpenCV 4.10 rejects an empty point vector
    // because checkVector cannot determine an element depth. Geometry
    // defines an empty contour to produce an empty approximation.
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        std::vector<cv::Point> approx;
        cv::approxPolyDP(contour, approx, epsilon, closed != 0);
        // ABI safety: copying more points than capacity would overflow the
        // caller-provided buffer. Approximation cardinality is at most
        // point_count.
        if (approx.size() > static_cast<std::size_t>(out_capacity)) {
            return invalid_argument(
                "approximate curve output capacity is insufficient");
        }
        for (std::size_t index = 0; index < approx.size(); ++index) {
            out_points[index].x = approx[index].x;
            out_points[index].y = approx[index].y;
        }
        *out_count = static_cast<int32_t>(approx.size());
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_count = 0;
        return translate_current_exception();
    }
}

