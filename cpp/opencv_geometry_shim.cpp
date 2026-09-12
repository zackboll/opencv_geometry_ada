#include "opencv_geometry_shim.h"

#include <opencv2/core/version.hpp>
#if CV_VERSION_MAJOR >= 5
#include <opencv2/geometry.hpp>
#else
#include <opencv2/imgproc.hpp>
#endif

#include <cstdio>
#include <exception>
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

