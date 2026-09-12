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

