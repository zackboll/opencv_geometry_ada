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

bool integer_convex_hull_arithmetic_is_safe(
    const opencv_geometry_point_i32 *points,
    int32_t point_count) noexcept
{
    // Native-call arithmetic safety: Sklansky_ for CV_32S starts using
    // signed-int coordinate subtraction at three points. Every subtraction
    // is bounded by an axis span, so spans no greater than INT32_MAX keep
    // each native delta representable before its int64_t multiplication. If
    // D = INT32_MAX, each product is in [-D*D, D*D], and their difference is
    // in [-2*D*D, 2*D*D] = [-9223372028264841218, 9223372028264841218], which
    // lies within int64_t's [-9223372036854775808, 9223372036854775807].
    if (point_count < 3) {
        return true;
    }

    int64_t min_x = points[0].x;
    int64_t max_x = min_x;
    int64_t min_y = points[0].y;
    int64_t max_y = min_y;
    for (int32_t index = 1; index < point_count; ++index) {
        const int64_t x = points[index].x;
        const int64_t y = points[index].y;
        min_x = x < min_x ? x : min_x;
        max_x = x > max_x ? x : max_x;
        min_y = y < min_y ? y : min_y;
        max_y = y > max_y ? y : max_y;
    }
    return max_x - min_x <= static_cast<int64_t>(INT32_MAX)
        && max_y - min_y <= static_cast<int64_t>(INT32_MAX);
}

void zero_rotated_rect(opencv_geometry_rotated_rect_f32 *out_rect) noexcept
{
    *out_rect = opencv_geometry_rotated_rect_f32{};
}

void zero_box_vertices(opencv_geometry_box_vertices_f32 *out_vertices) noexcept
{
    *out_vertices = opencv_geometry_box_vertices_f32{};
}

}

const char *opencv_geometry_last_error_message(void)
{
    return last_error_message;
}

int32_t opencv_geometry_opencv_major_version(void)
{
    return CV_VERSION_MAJOR;
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
    if (!integer_convex_hull_arithmetic_is_safe(points, point_count)) {
        return invalid_argument(
            "convex hull exceeds signed 32-bit arithmetic range");
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

opencv_geometry_status
opencv_geometry_convex_hull_indices(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t clockwise,
    int32_t *out_indices,
    int32_t out_capacity,
    int32_t *out_count)
{
    clear_error();
    if (out_count == nullptr) {
        return invalid_argument(
            "null convex hull indices output count pointer");
    }
    *out_count = 0;
    if (point_count < 0) {
        return invalid_argument(
            "convex hull indices point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (clockwise != 0 && clockwise != 1) {
        return invalid_argument(
            "convex hull indices clockwise selector must be zero or one");
    }
    if (out_capacity < 0) {
        return invalid_argument(
            "convex hull indices output capacity must not be negative");
    }
    // ABI safety: a positive capacity with a null buffer would be written
    // if OpenCV returned any hull indices.
    if (out_capacity > 0 && out_indices == nullptr) {
        return invalid_argument(
            "null convex hull output indices with positive capacity");
    }
    // OpenCV compatibility: OpenCV 4.x rejects an empty point vector
    // because checkVector cannot determine an element depth. Geometry
    // defines an empty contour to produce an empty hull.
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }
    if (!integer_convex_hull_arithmetic_is_safe(points, point_count)) {
        return invalid_argument(
            "convex hull indices exceed signed 32-bit arithmetic range");
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        // A std::vector<int> output has fixed type CV_32S, so OpenCV returns
        // zero-based source indices rather than hull points.
        std::vector<int> hull;
        cv::convexHull(contour, hull, clockwise != 0, false);
        // ABI safety: copying more indices than capacity would overflow the
        // caller-provided buffer. Hull cardinality is at most point_count.
        if (hull.size() > static_cast<std::size_t>(out_capacity)) {
            return invalid_argument(
                "convex hull indices output capacity is insufficient");
        }
        for (std::size_t index = 0; index < hull.size(); ++index) {
            out_indices[index] = hull[index];
        }
        *out_count = static_cast<int32_t>(hull.size());
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_count = 0;
        return translate_current_exception();
    }
}

namespace {

// OpenCV stores a convexity-defect depth as cvRound(depth * 256) in a
// signed int, so INT32_MAX / 256 is the largest integral depth whose
// fixed-point value is representable.
constexpr int64_t maximum_convexity_defect_extent =
    static_cast<int64_t>(INT32_MAX) / 256;

bool convexity_defect_arithmetic_is_safe(
    const opencv_geometry_point_i32 *points,
    int32_t point_count) noexcept
{
    // Native-call arithmetic safety: convexityDefects in OpenCV 4.6, 4.10,
    // and 5.0 (identical source) computes pt1.x - pt0.x, pt1.y - pt0.y,
    // ptr[j].x - pt0.x, and ptr[j].y - pt0.y as signed int subtraction
    // between contour points, then stores cvRound(depth * 256) in an int,
    // where depth is the distance from ptr[j] to the line through the hull
    // points pt0 and pt1. That perpendicular distance never exceeds
    // |ptr[j] - pt0|, which never exceeds the bounding-box diagonal
    // sqrt(W * W + H * H), W and H being the X and Y spans. Requiring
    // W * W + H * H <= M * M with M = INT32_MAX / 256 = 8388607 therefore
    // bounds every native coordinate delta by M < INT32_MAX and every true
    // depth by M. Native deltas are exact doubles, their products are below
    // 2^47 and exact, and sqrt, division, and multiplication each add at
    // most half an ulp, so the computed depth times 256 stays below
    // 2147483393 < INT32_MAX before cvRound.
    int64_t min_x = points[0].x;
    int64_t max_x = min_x;
    int64_t min_y = points[0].y;
    int64_t max_y = min_y;
    for (int32_t index = 1; index < point_count; ++index) {
        const int64_t x = points[index].x;
        const int64_t y = points[index].y;
        min_x = x < min_x ? x : min_x;
        max_x = x > max_x ? x : max_x;
        min_y = y < min_y ? y : min_y;
        max_y = y > max_y ? y : max_y;
    }
    const int64_t width = max_x - min_x;
    const int64_t height = max_y - min_y;
    if (width > maximum_convexity_defect_extent
        || height > maximum_convexity_defect_extent) {
        return false;
    }
    return width * width + height * height
        <= maximum_convexity_defect_extent * maximum_convexity_defect_extent;
}

}

opencv_geometry_status
opencv_geometry_convexity_defects(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    const int32_t *hull_indices,
    int32_t hull_count,
    opencv_geometry_convexity_defect *out_defects,
    int32_t out_capacity,
    int32_t *out_count)
{
    clear_error();
    if (out_count == nullptr) {
        return invalid_argument(
            "null convexity defects output count pointer");
    }
    *out_count = 0;
    if (point_count < 0) {
        return invalid_argument(
            "convexity defects point count must not be negative");
    }
    if (hull_count < 0) {
        return invalid_argument(
            "convexity defects hull count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    if (hull_count > 0 && hull_indices == nullptr) {
        return invalid_argument("null hull indices with positive count");
    }
    if (out_capacity < 0) {
        return invalid_argument(
            "convexity defects output capacity must not be negative");
    }
    // ABI safety: a positive capacity with a null buffer would be written
    // if OpenCV returned any defects.
    if (out_capacity > 0 && out_defects == nullptr) {
        return invalid_argument(
            "null convexity defects output with positive capacity");
    }
    // Thick Ada returns no defects for contours of at most three points
    // without calling this function. A raw empty contour reaches OpenCV,
    // which rejects it by assertion before reading points or hull indices.

    // ABI safety: native convexityDefects performs signed int coordinate
    // subtraction and cvRound(depth * 256) only when the contour has more
    // than three points and the hull has at least three indices. Reject
    // extents for which that arithmetic could overflow a signed int.
    if (point_count > 3 && hull_count >= 3
        && !convexity_defect_arithmetic_is_safe(points, point_count)) {
        return invalid_argument(
            "convexity defects contour exceeds native fixed-point depth "
            "range");
    }

    try {
        std::vector<cv::Point> contour;
        contour.reserve(static_cast<std::size_t>(point_count));
        for (int32_t index = 0; index < point_count; ++index) {
            contour.emplace_back(points[index].x, points[index].y);
        }
        std::vector<int> hull;
        if (hull_count > 0) {
            hull.assign(hull_indices, hull_indices + hull_count);
        }
        // OpenCV asserts that every hull index lies in [0, point_count)
        // before it dereferences the contour, and raises for hull indices
        // that are not monotonic. Those native errors are translated below.
        std::vector<cv::Vec4i> defects;
        cv::convexityDefects(contour, hull, defects);
        // ABI safety: copying more defects than capacity would overflow the
        // caller-provided buffer. Native convexityDefects appends at most
        // one defect per hull index.
        if (defects.size() > static_cast<std::size_t>(out_capacity)) {
            return invalid_argument(
                "convexity defects output capacity is insufficient");
        }
        for (std::size_t index = 0; index < defects.size(); ++index) {
            out_defects[index].start_index = defects[index][0];
            out_defects[index].end_index = defects[index][1];
            out_defects[index].farthest_index = defects[index][2];
            out_defects[index].fixed_point_depth = defects[index][3];
        }
        *out_count = static_cast<int32_t>(defects.size());
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

bool query_coordinate_is_cvround_safe(float value) noexcept
{
    // Native-call conversion safety: OpenCV pointPolygonTest always
    // constructs Point ip(cvRound(pt.x), cvRound(pt.y)) for nonempty
    // contours. cvRound is undefined outside INT_MIN..INT_MAX. Widen
    // binary32 to binary64 so INT32_MAX is compared exactly; float
    // (INT32_MAX) rounds to 2147483648.0f and is not a valid bound.
    if (!std::isfinite(value)) {
        return false;
    }
    const double widened = static_cast<double>(value);
    return widened >= static_cast<double>(INT32_MIN)
        && widened <= static_cast<double>(INT32_MAX);
}

bool query_is_cvround_safe(float query_x, float query_y) noexcept
{
    return query_coordinate_is_cvround_safe(query_x)
        && query_coordinate_is_cvround_safe(query_y);
}

bool query_coordinate_is_integral_int32(float value) noexcept
{
    // Range has already been proven cvRound-safe, so the conversion
    // to int32_t is defined. Compare the original binary32 value with
    // the converted integer to detect exact integral queries without
    // depending on the current rounding mode.
    const int32_t integer = static_cast<int32_t>(value);
    return static_cast<float>(integer) == value;
}

bool query_is_integral_int32(float query_x, float query_y) noexcept
{
    return query_coordinate_is_integral_int32(query_x)
        && query_coordinate_is_integral_int32(query_y);
}

bool signed_int_delta_is_safe(int64_t left, int64_t right) noexcept
{
    const int64_t delta = left - right;
    return delta >= static_cast<int64_t>(INT32_MIN)
        && delta <= static_cast<int64_t>(INT32_MAX);
}

bool integer_classification_path_is_safe(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t query_x,
    int32_t query_y) noexcept
{
    // Native-call arithmetic safety: OpenCV's integer classification
    // path only evaluates signed-int subtractions on edges that pass
    // the skip/boundary shortcuts. Mirror that reachability so an
    // unreachable overflow does not reject a valid native result.
    // This helper does not classify inside versus outside.
    if (point_count <= 1) {
        return true;
    }

    const int64_t ipx = static_cast<int64_t>(query_x);
    const int64_t ipy = static_cast<int64_t>(query_y);
    int32_t previous = point_count - 1;
    for (int32_t index = 0; index < point_count; ++index) {
        const int32_t v0x = points[previous].x;
        const int32_t v0y = points[previous].y;
        const int32_t vx = points[index].x;
        const int32_t vy = points[index].y;
        previous = index;

        const bool skip =
            (v0y <= query_y && vy <= query_y)
            || (v0y > query_y && vy > query_y)
            || (v0x < query_x && vx < query_x);
        if (skip) {
            if (query_y == vy
                && (query_x == vx
                    || (query_y == v0y
                        && ((v0x <= query_x && query_x <= vx)
                            || (vx <= query_x && query_x <= v0x))))) {
                return true;
            }
            continue;
        }

        if (!signed_int_delta_is_safe(ipy, static_cast<int64_t>(v0y))
            || !signed_int_delta_is_safe(
                   static_cast<int64_t>(vx), static_cast<int64_t>(v0x))
            || !signed_int_delta_is_safe(ipx, static_cast<int64_t>(v0x))
            || !signed_int_delta_is_safe(
                   static_cast<int64_t>(vy), static_cast<int64_t>(v0y))) {
            return false;
        }

        const int64_t ipy_v0y = ipy - static_cast<int64_t>(v0y);
        const int64_t vx_v0x =
            static_cast<int64_t>(vx) - static_cast<int64_t>(v0x);
        const int64_t ipx_v0x = ipx - static_cast<int64_t>(v0x);
        const int64_t vy_v0y =
            static_cast<int64_t>(vy) - static_cast<int64_t>(v0y);
        const int64_t dist = ipy_v0y * vx_v0x - ipx_v0x * vy_v0y;
        if (dist == 0) {
            return true;
        }
    }
    return true;
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
    if (!query_is_cvround_safe(query_x, query_y)) {
        return invalid_argument(
            "point polygon query is outside the cvRound range");
    }
    if (measure_distance == 0 && query_is_integral_int32(query_x, query_y)) {
        const int32_t qx = static_cast<int32_t>(query_x);
        const int32_t qy = static_cast<int32_t>(query_y);
        if (!integer_classification_path_is_safe(
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

namespace {

void zero_enclosing_circle(
    opencv_geometry_enclosing_circle_f32 *out_circle) noexcept
{
    out_circle->center_x = 0.0f;
    out_circle->center_y = 0.0f;
    out_circle->radius = 0.0f;
}

bool signed_int_sum_is_safe(int64_t left, int64_t right) noexcept
{
    const int64_t sum = left + right;
    return sum >= static_cast<int64_t>(INT32_MIN)
        && sum <= static_cast<int64_t>(INT32_MAX);
}

bool signed_int_difference_is_safe(int64_t left, int64_t right) noexcept
{
    const int64_t delta = left - right;
    return delta >= static_cast<int64_t>(INT32_MIN)
        && delta <= static_cast<int64_t>(INT32_MAX);
}

bool enclosing_circle_extrema_are_safe(
    int64_t min_value,
    int64_t second_min,
    int64_t max_value,
    int64_t second_max) noexcept
{
    // Native-call arithmetic safety: integer minEnclosingCircle helpers
    // evaluate pts[a].x + pts[b].x and pts[a].x - pts[b].x (and the Y
    // equivalents) as signed int before converting to float. After a
    // possible OpenCV 5 shuffle, any distinct pair may be selected.
    // Every pair sum is between min+second_min and max+second_max.
    // Every pair difference is between min-max and max-min. Checking
    // those extrema in int64_t therefore covers all pairs.
    return signed_int_sum_is_safe(min_value, second_min)
        && signed_int_sum_is_safe(max_value, second_max)
        && signed_int_difference_is_safe(max_value, min_value)
        && signed_int_difference_is_safe(min_value, max_value);
}

bool enclosing_circle_pair_arithmetic_is_safe(
    const opencv_geometry_point_i32 *points,
    int32_t point_count) noexcept
{
    if (point_count < 2) {
        return true;
    }

    int64_t min_x = points[0].x;
    int64_t max_x = points[0].x;
    int64_t second_min_x = points[1].x;
    int64_t second_max_x = points[1].x;
    if (second_min_x < min_x) {
        const int64_t tmp = min_x;
        min_x = second_min_x;
        second_min_x = tmp;
    }
    if (second_max_x > max_x) {
        const int64_t tmp = max_x;
        max_x = second_max_x;
        second_max_x = tmp;
    }

    int64_t min_y = points[0].y;
    int64_t max_y = points[0].y;
    int64_t second_min_y = points[1].y;
    int64_t second_max_y = points[1].y;
    if (second_min_y < min_y) {
        const int64_t tmp = min_y;
        min_y = second_min_y;
        second_min_y = tmp;
    }
    if (second_max_y > max_y) {
        const int64_t tmp = max_y;
        max_y = second_max_y;
        second_max_y = tmp;
    }

    for (int32_t index = 2; index < point_count; ++index) {
        const int64_t x = points[index].x;
        if (x < min_x) {
            second_min_x = min_x;
            min_x = x;
        } else if (x < second_min_x) {
            second_min_x = x;
        }
        if (x > max_x) {
            second_max_x = max_x;
            max_x = x;
        } else if (x > second_max_x) {
            second_max_x = x;
        }

        const int64_t y = points[index].y;
        if (y < min_y) {
            second_min_y = min_y;
            min_y = y;
        } else if (y < second_min_y) {
            second_min_y = y;
        }
        if (y > max_y) {
            second_max_y = max_y;
            max_y = y;
        } else if (y > second_max_y) {
            second_max_y = y;
        }
    }

    return enclosing_circle_extrema_are_safe(
               min_x, second_min_x, max_x, second_max_x)
        && enclosing_circle_extrema_are_safe(
               min_y, second_min_y, max_y, second_max_y);
}

bool enclosing_circle_requires_pair_arithmetic(int32_t point_count) noexcept
{
    // OpenCV 4.10 converts count == 2 to Point2f before addition.
    // OpenCV 5.x routes count >= 2 through integer helper arithmetic.
#if CV_VERSION_MAJOR >= 5
    return point_count >= 2;
#else
    return point_count >= 3;
#endif
}

}

opencv_geometry_status
opencv_geometry_min_enclosing_circle(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_enclosing_circle_f32 *out_circle)
{
    clear_error();
    if (out_circle == nullptr) {
        return invalid_argument("null enclosing circle output pointer");
    }
    zero_enclosing_circle(out_circle);
    if (point_count < 0) {
        return invalid_argument(
            "enclosing circle point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    // OpenCV compatibility: OpenCV 4.10 and 5.x reject an empty point
    // vector because checkVector cannot determine an element depth.
    // Native minEnclosingCircle returns center (0,0) and radius 0 when
    // total == 0 and the depth is known, so Geometry preserves that result.
    if (point_count == 0) {
        return OPENCV_GEOMETRY_OK;
    }
    if (enclosing_circle_requires_pair_arithmetic(point_count)
        && !enclosing_circle_pair_arithmetic_is_safe(points, point_count)) {
        return invalid_argument(
            "enclosing circle exceeds signed 32-bit arithmetic range");
    }

    try {
        const std::vector<cv::Point> contour =
            contour_from_points(points, point_count);
        cv::Point2f center;
        float radius = 0.0f;
        cv::minEnclosingCircle(contour, center, radius);
        out_circle->center_x = center.x;
        out_circle->center_y = center.y;
        out_circle->radius = radius;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_enclosing_circle(out_circle);
        return translate_current_exception();
    }
}

namespace {

void zero_triangle(opencv_geometry_triangle_f32 *out_triangle) noexcept
{
    *out_triangle = opencv_geometry_triangle_f32{};
}

}

opencv_geometry_status
opencv_geometry_min_enclosing_triangle(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    double *out_area,
    opencv_geometry_triangle_f32 *out_triangle)
{
    clear_error();
    if (out_area == nullptr) {
        if (out_triangle != nullptr) {
            zero_triangle(out_triangle);
        }
        return invalid_argument("null enclosing triangle area output pointer");
    }
    *out_area = 0.0;
    if (out_triangle == nullptr) {
        return invalid_argument("null enclosing triangle output pointer");
    }
    zero_triangle(out_triangle);
    if (point_count < 0) {
        return invalid_argument(
            "enclosing triangle point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    // ABI safety: OpenCV minEnclosingTriangle always calls convexHull on
    // CV_32S input. Sklansky_ performs signed-int coordinate subtraction
    // once three or more points are present. Spans larger than INT32_MAX
    // overflow that arithmetic before the hull result is produced.
    if (!integer_convex_hull_arithmetic_is_safe(points, point_count)) {
        return invalid_argument(
            "enclosing triangle exceeds signed 32-bit arithmetic range");
    }

    try {
        const std::vector<cv::Point> contour =
            contour_from_points(points, point_count);
        std::vector<cv::Point2f> triangle;
        const double area = cv::minEnclosingTriangle(contour, triangle);
        // ABI safety: the public Ada result is a fixed three-vertex record.
        // Native success is documented to write three CV_32F points, but a
        // shorter or longer vector would overflow or leave vertices
        // uninitialized if copied blindly.
        if (triangle.size() != 3) {
            *out_area = 0.0;
            zero_triangle(out_triangle);
            set_error("enclosing triangle did not return three vertices");
            return OPENCV_GEOMETRY_ERROR_UNKNOWN;
        }
        *out_area = area;
        out_triangle->v0_x = triangle[0].x;
        out_triangle->v0_y = triangle[0].y;
        out_triangle->v1_x = triangle[1].x;
        out_triangle->v1_y = triangle[1].y;
        out_triangle->v2_x = triangle[2].x;
        out_triangle->v2_y = triangle[2].y;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_area = 0.0;
        zero_triangle(out_triangle);
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_min_area_rect(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect)
{
    clear_error();
    if (out_rect == nullptr) {
        return invalid_argument("null minimum area rectangle output pointer");
    }
    zero_rotated_rect(out_rect);
    if (point_count < 0) {
        return invalid_argument(
            "minimum area rectangle point count must not be negative");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    // OpenCV compatibility: an empty std::vector<cv::Point> has no depth for
    // checkVector. Native typed empty behavior is a zero rectangle with 0
    // degrees in OpenCV 4 and -90 degrees in OpenCV 5.
    if (point_count == 0) {
#if CV_VERSION_MAJOR >= 5
        out_rect->angle_degrees = -90.0f;
#endif
        return OPENCV_GEOMETRY_OK;
    }
    if (!integer_convex_hull_arithmetic_is_safe(points, point_count)) {
        return invalid_argument(
            "minimum area rectangle exceeds signed 32-bit arithmetic range");
    }

    try {
        const std::vector<cv::Point> contour =
            contour_from_points(points, point_count);
        const cv::RotatedRect rect = cv::minAreaRect(contour);
        out_rect->center_x = rect.center.x;
        out_rect->center_y = rect.center.y;
        out_rect->width = rect.size.width;
        out_rect->height = rect.size.height;
        out_rect->angle_degrees = rect.angle;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_rotated_rect(out_rect);
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_fit_ellipse(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect)
{
    clear_error();
    if (out_rect == nullptr) {
        return invalid_argument("null fit ellipse output pointer");
    }
    zero_rotated_rect(out_rect);
    if (point_count < 0) {
        return invalid_argument(
            "fit ellipse point count must not be negative");
    }
    // ABI safety: OpenCV fitEllipseNoDirect allocates
    // AutoBuffer<double>(n*12+n) with signed int arithmetic on the
    // point count. Overflowing n*13 truncates the allocation size and
    // can then write out of bounds.
    if (point_count > INT32_MAX / 13) {
        return invalid_argument(
            "fit ellipse point count exceeds native allocation range");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }

    try {
        const std::vector<cv::Point> contour =
            contour_from_points(points, point_count);
        const cv::RotatedRect rect = cv::fitEllipse(contour);
        out_rect->center_x = rect.center.x;
        out_rect->center_y = rect.center.y;
        out_rect->width = rect.size.width;
        out_rect->height = rect.size.height;
        out_rect->angle_degrees = rect.angle;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_rotated_rect(out_rect);
        return translate_current_exception();
    }
}

namespace {

using ellipse_fit = cv::RotatedRect (*)(cv::InputArray);

// Shared body of the AMS and Direct ellipse fits.
opencv_geometry_status fit_ellipse_variant(
    ellipse_fit fit,
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect)
{
    clear_error();
    if (out_rect == nullptr) {
        return invalid_argument("null ellipse fit output pointer");
    }
    zero_rotated_rect(out_rect);
    if (point_count < 0) {
        return invalid_argument(
            "ellipse fit point count must not be negative");
    }
    // ABI safety: fitEllipseAMS and fitEllipseDirect can both fall back to
    // fitEllipseNoDirect (OpenCV 4.6, 4.10, and 5.0), which allocates
    // AutoBuffer<double>(n*12+n) with signed int arithmetic; overflowing
    // n*13 truncates that allocation and can then write out of bounds. The
    // same bound keeps the other signed int count arithmetic on every
    // reachable path in range: n*2 (Direct; AMS from 4.12) and
    // mulTransposed's n * sizeof(double) row buffer size.
    if (point_count > INT32_MAX / 13) {
        return invalid_argument(
            "ellipse fit point count exceeds native allocation range");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }

    try {
        const std::vector<cv::Point> contour =
            contour_from_points(points, point_count);
        const cv::RotatedRect rect = fit(contour);
        out_rect->center_x = rect.center.x;
        out_rect->center_y = rect.center.y;
        out_rect->width = rect.size.width;
        out_rect->height = rect.size.height;
        out_rect->angle_degrees = rect.angle;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_rotated_rect(out_rect);
        return translate_current_exception();
    }
}

}

opencv_geometry_status
opencv_geometry_fit_ellipse_ams(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect)
{
    return fit_ellipse_variant(
        cv::fitEllipseAMS, points, point_count, out_rect);
}

opencv_geometry_status
opencv_geometry_fit_ellipse_direct(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    opencv_geometry_rotated_rect_f32 *out_rect)
{
    return fit_ellipse_variant(
        cv::fitEllipseDirect, points, point_count, out_rect);
}

namespace {

bool line_fit_distance(int32_t distance, int *native_distance) noexcept
{
    switch (distance) {
    case OPENCV_GEOMETRY_LINE_FIT_L2:
        *native_distance = cv::DIST_L2;
        return true;
    case OPENCV_GEOMETRY_LINE_FIT_L1:
        *native_distance = cv::DIST_L1;
        return true;
    case OPENCV_GEOMETRY_LINE_FIT_L12:
        *native_distance = cv::DIST_L12;
        return true;
    case OPENCV_GEOMETRY_LINE_FIT_FAIR:
        *native_distance = cv::DIST_FAIR;
        return true;
    case OPENCV_GEOMETRY_LINE_FIT_WELSCH:
        *native_distance = cv::DIST_WELSCH;
        return true;
    case OPENCV_GEOMETRY_LINE_FIT_HUBER:
        *native_distance = cv::DIST_HUBER;
        return true;
    default:
        return false;
    }
}

// fitLine narrows param, reps, and aeps to float. With IEC 559 floating
// point that narrowing is defined for every double, and OpenCV's reweighting
// tolerates NaN and infinite values, so their range is public Ada policy
// rather than an ABI-safety condition.
static_assert(
    std::numeric_limits<float>::is_iec559
        && std::numeric_limits<double>::is_iec559,
    "fit line parameter narrowing assumes IEC 559 floating point");

}

opencv_geometry_status
opencv_geometry_fit_line_2d(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    int32_t distance,
    double parameter,
    double radius_accuracy,
    double angle_accuracy,
    opencv_geometry_line_2d_f32 *out_line)
{
    clear_error();
    if (out_line == nullptr) {
        return invalid_argument("null fit line output pointer");
    }
    *out_line = opencv_geometry_line_2d_f32{};
    if (point_count < 0) {
        return invalid_argument("fit line point count must not be negative");
    }
    // ABI safety: OpenCV 4.6, 4.10, and 5.0 compute count*2 in signed int
    // for every distance (convertTo's continuous size of the CV_32S points)
    // and again for the robust distances (fitLine2D's AutoBuffer<float>).
    // Larger counts overflow that arithmetic, which is undefined behavior.
    if (point_count > INT32_MAX / 2) {
        return invalid_argument(
            "fit line point count exceeds native allocation range");
    }
    if (point_count > 0 && points == nullptr) {
        return invalid_argument("null contour points with positive count");
    }
    int native_distance = 0;
    if (!line_fit_distance(distance, &native_distance)) {
        return invalid_argument("fit line distance selector is invalid");
    }

    try {
        const std::vector<cv::Point> contour =
            contour_from_points(points, point_count);
        cv::Vec4f line;
        cv::fitLine(
            contour,
            line,
            native_distance,
            parameter,
            radius_accuracy,
            angle_accuracy);
        opencv_geometry_line_2d_f32 result{};
        result.direction_x = line[0];
        result.direction_y = line[1];
        result.point_x = line[2];
        result.point_y = line[3];
        *out_line = result;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_line = opencv_geometry_line_2d_f32{};
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_box_points(
    const opencv_geometry_rotated_rect_f32 *box,
    opencv_geometry_box_vertices_f32 *out_vertices)
{
    clear_error();
    if (out_vertices == nullptr) {
        return invalid_argument("null box vertices output pointer");
    }
    zero_box_vertices(out_vertices);
    if (box == nullptr) {
        return invalid_argument("null rotated rectangle pointer");
    }

    try {
        const cv::RotatedRect native_box(
            cv::Point2f(box->center_x, box->center_y),
            cv::Size2f(box->width, box->height),
            box->angle_degrees);
        cv::Mat points;
        cv::boxPoints(native_box, points);
        // ABI safety: this fixed four-vertex ABI can copy native storage only
        // after verifying cv::boxPoints produced exactly four CV_32F 2D points.
        if (points.rows != 4 || points.cols != 2 || points.type() != CV_32FC1) {
            zero_box_vertices(out_vertices);
            set_error("box points did not return four CV_32F vertices");
            return OPENCV_GEOMETRY_ERROR_UNKNOWN;
        }
        const cv::Point2f *vertices = points.ptr<cv::Point2f>();
        opencv_geometry_box_vertices_f32 result{};
        result.v0_x = vertices[0].x;
        result.v0_y = vertices[0].y;
        result.v1_x = vertices[1].x;
        result.v1_y = vertices[1].y;
        result.v2_x = vertices[2].x;
        result.v2_y = vertices[2].y;
        result.v3_x = vertices[3].x;
        result.v3_y = vertices[3].y;
        *out_vertices = result;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_box_vertices(out_vertices);
        return translate_current_exception();
    }
}

namespace {

void zero_affine_2x3(opencv_geometry_affine_2x3_f64 *out_transform) noexcept
{
    out_transform->m00 = 0.0;
    out_transform->m01 = 0.0;
    out_transform->m02 = 0.0;
    out_transform->m10 = 0.0;
    out_transform->m11 = 0.0;
    out_transform->m12 = 0.0;
}

}

opencv_geometry_status
opencv_geometry_get_rotation_matrix_2d(
    float center_x,
    float center_y,
    double angle_degrees,
    double scale,
    opencv_geometry_affine_2x3_f64 *out_transform)
{
    clear_error();
    if (out_transform == nullptr) {
        return invalid_argument("null rotation matrix output pointer");
    }
    zero_affine_2x3(out_transform);

    // ABI safety: OpenCV applies std::cos / std::sin and writes six
    // coefficients. Non-finite center, angle, or scale produce NaN/Inf
    // values rather than a documented rejection, so this ABI would copy
    // IEEE specials into the POD instead of a defined finite matrix.
    if (!std::isfinite(center_x)
        || !std::isfinite(center_y)
        || !std::isfinite(angle_degrees)
        || !std::isfinite(scale)) {
        return invalid_argument(
            "getRotationMatrix2D center, angle, and scale must be finite");
    }

    try {
        const cv::Mat matrix = cv::getRotationMatrix2D(
            cv::Point2f(center_x, center_y),
            angle_degrees,
            scale);
        out_transform->m00 = matrix.at<double>(0, 0);
        out_transform->m01 = matrix.at<double>(0, 1);
        out_transform->m02 = matrix.at<double>(0, 2);
        out_transform->m10 = matrix.at<double>(1, 0);
        out_transform->m11 = matrix.at<double>(1, 1);
        out_transform->m12 = matrix.at<double>(1, 2);
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        zero_affine_2x3(out_transform);
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

namespace {

// OpenCV 4.11.0 (upstream commit 6623c62f56, issue #25259) bounded the output
// of intersectConvexConvex_: each loop iteration writes at most three points,
// the loop stops once n + m + 1 result slots are exceeded inside a buffer with
// three spare slots, and the function then returns -1. OpenCV 5.0 has the same
// bound. OpenCV 4.x releases before 4.11, including 4.6 and 4.10, write without
// that bound into an n + m + 1 slot region of their AutoBuffer (inline or
// heap storage), so input that is not a simple convex polygon can overflow
// OpenCV's own buffer.
#if CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR < 11
constexpr bool native_convex_intersection_output_is_bounded = false;
#else
constexpr bool native_convex_intersection_output_is_bounded = true;
#endif

// OpenCV converts integer polygon vertices to binary32 before intersecting
// them. Every integer of magnitude at most 2^24 converts exactly.
constexpr int64_t binary32_exact_integer_limit = 16777216;

// Native intersectConvexConvex allocates 2 * (n + m) + 4 points (4.11+ and
// 5.x) or 2 * (n + m) + 1 points (earlier 4.x) with signed int arithmetic.
constexpr int64_t maximum_convex_intersection_input_count =
    (static_cast<int64_t>(INT32_MAX) - 4) / 2;

// True when polygon is a simple, strictly convex polygon traversed once, with
// binary32-exact coordinates: its convex hull has every vertex, visited as one
// cyclic run in contour order. isContourConvex alone accepts self-intersecting
// stars and repeated traversals.
bool polygon_is_simple_convex_in_binary32(
    const opencv_geometry_point_i32 *points,
    int32_t point_count,
    const std::vector<cv::Point> &polygon)
{
    if (point_count < 3) {
        return false;
    }
    for (int32_t index = 0; index < point_count; ++index) {
        const int64_t x = points[index].x;
        const int64_t y = points[index].y;
        if (x < -binary32_exact_integer_limit
            || x > binary32_exact_integer_limit
            || y < -binary32_exact_integer_limit
            || y > binary32_exact_integer_limit) {
            return false;
        }
    }
    if (!integer_convex_hull_arithmetic_is_safe(points, point_count)) {
        return false;
    }
    std::vector<int> hull;
    cv::convexHull(polygon, hull, false, false);
    if (hull.size() != static_cast<std::size_t>(point_count)) {
        return false;
    }
    bool forward = true;
    bool backward = true;
    for (std::size_t position = 0; position + 1 < hull.size(); ++position) {
        const int index = hull[position];
        const int next = index + 1 == point_count ? 0 : index + 1;
        const int previous = index == 0 ? point_count - 1 : index - 1;
        forward = forward && hull[position + 1] == next;
        backward = backward && hull[position + 1] == previous;
    }
    return forward || backward;
}

// OpenCV compatibility: intersectConvexConvex_ (OpenCV 4.6, 4.10, and 5.0)
// stores a (FLT_MAX, FLT_MAX) sentinel in its first result slot and drops it
// only on its normal exit. Its early exits, for parallel separated edges and
// for oppositely oriented overlapping edges, return that slot as a vertex:
// first, or last after intersectConvexConvex reverses a result whose inputs
// were both clockwise. Every genuine vertex is an input vertex or an edge
// crossing, so integer input never yields FLT_MAX and the sentinel is
// unambiguous.
bool is_convex_intersection_sentinel(const cv::Point2f &point) noexcept
{
    const float sentinel = std::numeric_limits<float>::max();
    return point.x == sentinel && point.y == sentinel;
}

void copy_points_f32(
    const std::vector<cv::Point2f> &points,
    opencv_geometry_point_f32 *out_points) noexcept
{
    for (std::size_t index = 0; index < points.size(); ++index) {
        out_points[index].x = points[index].x;
        out_points[index].y = points[index].y;
    }
}

}

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
    float *out_area)
{
    clear_error();
    if (out_count == nullptr) {
        return invalid_argument(
            "null convex intersection output count pointer");
    }
    *out_count = 0;
    if (out_area == nullptr) {
        return invalid_argument(
            "null convex intersection output area pointer");
    }
    *out_area = 0.0f;
    if (left_count < 0 || right_count < 0) {
        return invalid_argument(
            "convex intersection point count must not be negative");
    }
    if (left_count > 0 && left_points == nullptr) {
        return invalid_argument("null left polygon points with positive count");
    }
    if (right_count > 0 && right_points == nullptr) {
        return invalid_argument(
            "null right polygon points with positive count");
    }
    if (handle_nested != 0 && handle_nested != 1) {
        return invalid_argument(
            "convex intersection nested selector must be zero or one");
    }
    if (out_capacity < 0) {
        return invalid_argument(
            "convex intersection output capacity must not be negative");
    }
    // ABI safety: a positive capacity with a null buffer would be written
    // if OpenCV returned any intersection vertices.
    if (out_capacity > 0 && out_vertices == nullptr) {
        return invalid_argument(
            "null convex intersection output vertices with positive capacity");
    }
    // ABI safety: native intersectConvexConvex sizes its scratch buffer as
    // 2 * (n + m) + 4 (or + 1 before 4.11) in signed int before validating
    // anything, so larger combined counts would overflow native arithmetic.
    if (static_cast<int64_t>(left_count) + right_count
        > maximum_convex_intersection_input_count) {
        return invalid_argument(
            "convex intersection point counts exceed native allocation range");
    }

    try {
        const std::vector<cv::Point> left =
            contour_from_points(left_points, left_count);
        const std::vector<cv::Point> right =
            contour_from_points(right_points, right_count);
        // ABI safety: OpenCV 4.x before 4.11 can write past its own buffer
        // for input that is not a simple convex polygon (see above). It runs
        // that loop only when both polygons have at least two points, so on
        // those versions require both to be simple, strictly convex, and
        // binary32-exact exactly as OpenCV processes them.
        if (!native_convex_intersection_output_is_bounded
            && left_count >= 2 && right_count >= 2
            && (!polygon_is_simple_convex_in_binary32(
                    left_points, left_count, left)
                || !polygon_is_simple_convex_in_binary32(
                    right_points, right_count, right))) {
            return invalid_argument(
                "convex intersection version guard: polygons must be simple, "
                "strictly convex, and binary32-exact before OpenCV 4.11");
        }
        std::vector<cv::Point2f> native;
        const float area = cv::intersectConvexConvex(
            left, right, native, handle_nested != 0);
        std::vector<cv::Point2f> intersection;
        intersection.reserve(native.size());
        for (const cv::Point2f &point : native) {
            if (!is_convex_intersection_sentinel(point)) {
                intersection.push_back(point);
            }
        }
        // ABI safety: copying more vertices than capacity would overflow the
        // caller-provided buffer.
        if (intersection.size() > static_cast<std::size_t>(out_capacity)) {
            return invalid_argument(
                "convex intersection output capacity is insufficient");
        }
        copy_points_f32(intersection, out_vertices);
        *out_count = static_cast<int32_t>(intersection.size());
        *out_area = area;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_count = 0;
        *out_area = 0.0f;
        return translate_current_exception();
    }
}

opencv_geometry_status
opencv_geometry_rotated_rectangle_intersection(
    const opencv_geometry_rotated_rect_f32 *left,
    const opencv_geometry_rotated_rect_f32 *right,
    int32_t *out_kind,
    opencv_geometry_point_f32 *out_vertices,
    int32_t out_capacity,
    int32_t *out_count)
{
    clear_error();
    if (out_count == nullptr) {
        return invalid_argument(
            "null rectangle intersection output count pointer");
    }
    *out_count = 0;
    if (out_kind == nullptr) {
        return invalid_argument(
            "null rectangle intersection output kind pointer");
    }
    *out_kind = OPENCV_GEOMETRY_RECTANGLES_INTERSECT_NONE;
    if (left == nullptr || right == nullptr) {
        return invalid_argument("null rotated rectangle pointer");
    }
    if (out_capacity < 0) {
        return invalid_argument(
            "rectangle intersection output capacity must not be negative");
    }
    // ABI safety: a positive capacity with a null buffer would be written
    // if OpenCV returned any intersection vertices.
    if (out_capacity > 0 && out_vertices == nullptr) {
        return invalid_argument(
            "null rectangle intersection output vertices with positive "
            "capacity");
    }

    try {
        const cv::RotatedRect left_box(
            cv::Point2f(left->center_x, left->center_y),
            cv::Size2f(left->width, left->height),
            left->angle_degrees);
        const cv::RotatedRect right_box(
            cv::Point2f(right->center_x, right->center_y),
            cv::Size2f(right->width, right->height),
            right->angle_degrees);
        std::vector<cv::Point2f> region;
        const int native_kind =
            cv::rotatedRectangleIntersection(left_box, right_box, region);
        int32_t kind = OPENCV_GEOMETRY_RECTANGLES_INTERSECT_NONE;
        switch (native_kind) {
        case cv::INTERSECT_NONE:
            kind = OPENCV_GEOMETRY_RECTANGLES_INTERSECT_NONE;
            break;
        case cv::INTERSECT_PARTIAL:
            kind = OPENCV_GEOMETRY_RECTANGLES_INTERSECT_PARTIAL;
            break;
        case cv::INTERSECT_FULL:
            kind = OPENCV_GEOMETRY_RECTANGLES_INTERSECT_FULL;
            break;
        default:
            set_error("rectangle intersection returned an unknown kind");
            return OPENCV_GEOMETRY_ERROR_UNKNOWN;
        }
        // ABI safety: copying more vertices than capacity would overflow the
        // caller-provided buffer. OpenCV 4.6, 4.10, and 5.0 reduce the region
        // to at most eight vertices.
        if (region.size() > static_cast<std::size_t>(out_capacity)) {
            return invalid_argument(
                "rectangle intersection output capacity is insufficient");
        }
        copy_points_f32(region, out_vertices);
        *out_count = static_cast<int32_t>(region.size());
        *out_kind = kind;
        return OPENCV_GEOMETRY_OK;
    } catch (...) {
        *out_count = 0;
        *out_kind = OPENCV_GEOMETRY_RECTANGLES_INTERSECT_NONE;
        return translate_current_exception();
    }
}

