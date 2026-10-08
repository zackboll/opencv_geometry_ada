// Deterministic backport/native comparison and C ABI safety qualification.
#include "../../cpp/opencv_geometry_shim.cpp"
#include "../../cpp/closest_ellipse_compat.hpp"

#include <cstdlib>
#include <iostream>
#include <iomanip>

namespace {
void require(bool condition)
{
    if (!condition) {
        std::cerr << "closest ellipse qualification failed\n";
        std::abort();
    }
}

float maximum_error = 0.0f;
std::size_t compared = 0;

template<class Coordinate>
void compare(const cv::RotatedRect& ellipse,
             const std::vector<cv::Point_<Coordinate>>& input)
{
    std::vector<cv::Point2f> portable;
    opencv_geometry_compat::closest_ellipse_points(ellipse, input, portable);
    require(portable.size() == input.size());
#if CV_VERSION_MAJOR >= 5 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 12)
    std::vector<cv::Point2f> native;
    cv::getClosestEllipsePoints(ellipse, input, native);
    require(native.size() == portable.size());
    for (std::size_t i = 0; i < native.size(); ++i) {
        const float expected[] = {native[i].x, native[i].y};
        const float actual[] = {portable[i].x, portable[i].y};
        for (int axis = 0; axis < 2; ++axis) {
            require(std::isfinite(expected[axis]) == std::isfinite(actual[axis]));
            if (std::isfinite(expected[axis])) {
                float error = std::abs(expected[axis] - actual[axis]);
                maximum_error = std::max(maximum_error, error);
                // Allows compiler/libm rounding, not solver accuracy changes.
                require(error <= 2.0e-5f * std::max(1.0f, std::abs(expected[axis])));
            } else {
                require(std::isnan(expected[axis]) == std::isnan(actual[axis]));
                require(std::isinf(expected[axis]) == std::isinf(actual[axis]));
            }
            ++compared;
        }
    }
#endif
}
}

int main()
{
#if CV_VERSION_MAJOR >= 5 || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 12)
    std::vector<cv::Point2f> fixture{{-4.25f, 2.5f}, {0.375f, -0.5f},
                                   {12.5f, -8.75f}, {3.25f, -6.0f}};
    std::vector<cv::Point2f> golden;
    cv::getClosestEllipsePoints(
        cv::RotatedRect(cv::Point2f(3.25f, -7.5f), cv::Size2f(3, 8), 17.5f),
        fixture, golden);
    std::cout << std::setprecision(9);
    for (const auto& point : golden) {
        std::cout << "Native fixture: " << point.x << ", " << point.y << '\n';
    }
#endif
    std::vector<cv::Point2f> fractional;
    std::vector<cv::Point> integer;
    for (int i = 0; i < 257; ++i) {
        integer.emplace_back(i * 7919 - 1000000, i * 3571 - 400000);
        fractional.emplace_back((i - 128) * 0.375f, (i % 17 - 8) * 0.625f);
    }
    integer.emplace_back(INT32_MAX, INT32_MIN);
    integer.emplace_back(INT32_MIN, INT32_MAX);
    fractional.emplace_back(0.0f, 0.0f);
    fractional.emplace_back(-0.0f, -0.0f);
    fractional.emplace_back(1.0e30f, -1.0e30f);
    for (float angle : {0.0f, 17.5f, 90.0f, -137.0f, 360.0f}) {
        for (const cv::Size2f& size : {cv::Size2f(2, 2), cv::Size2f(8, 3),
                                     cv::Size2f(3, 8), cv::Size2f(1.0e20f, 1.0e20f),
                                     cv::Size2f(1.0e-30f, 2.0e-30f)}) {
            for (const cv::Point2f& center : {cv::Point2f(0, 0), cv::Point2f(3.25f, -7.5f)}) {
                const cv::RotatedRect ellipse(center, size, angle);
                compare(ellipse, fractional);
                compare(ellipse, integer);
            }
        }
    }
    opencv_geometry_rotated_rect_f32 ellipse{0, 0, 2, 2, 0};
    opencv_geometry_point_f32 input{4, 0}, output{99, 99};
    int32_t count = 99;
    require(opencv_geometry_closest_ellipse_points_f32(
        &ellipse, &input, 1, &output, 0, &count)
        == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT);
    require(count == 0 && output.x == 99 && output.y == 99);
    require(opencv_geometry_closest_ellipse_points_f32(
        &ellipse, nullptr, 0, nullptr, 0, &count) == OPENCV_GEOMETRY_OK);
    require(count == 0);
    require(opencv_geometry_closest_ellipse_points_f32(
        &ellipse, &input, 1, &output, 1, &count) == OPENCV_GEOMETRY_OK);
    require(count == 1 && std::abs(output.x - 1.0f) < 1.0e-4f);
    std::cout << "OpenCV " << CV_VERSION << ": compared " << compared
              << " coordinates; maximum absolute error " << maximum_error
              << "; ABI checks passed\n";
}