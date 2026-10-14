#include <opencv2/core.hpp>
#include <opencv2/core/version.hpp>
#if CV_VERSION_MAJOR >= 5
#include <opencv2/geometry.hpp>
#else
#include <opencv2/imgproc.hpp>
#endif

#include <cstddef>
#include <vector>

// Application-owned C++ code. It calls OpenCV directly and exchanges only
// plain values with Ada: no binding handle or native object crosses.
extern "C" double application_contour_area(const int *xy, int count) noexcept
{
    try {
        if (xy == nullptr || count < 0) {
            return -1.0;
        }
        std::vector<cv::Point> points;
        points.reserve(static_cast<std::size_t>(count));
        for (int index = 0; index < count; ++index) {
            points.emplace_back(xy[2 * index], xy[2 * index + 1]);
        }
        return cv::contourArea(points);
    } catch (...) {
        return -1.0;
    }
}
