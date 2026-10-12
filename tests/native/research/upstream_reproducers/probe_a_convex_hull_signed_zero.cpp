// Supporting probe for Reproducer A (not a defect reproducer itself).
//
// Shows what cv::convexHull returns for the two-point signed-zero input that
// minEnclosingTriangle passes on to its own code. Public OpenCV headers only.
//
// Build (OpenCV 4):
//   g++ -std=c++17 -Wall -Wextra -Werror -o probe_a probe_a_convex_hull_signed_zero.cpp $(pkg-config --cflags --libs opencv4) -ldl
// Build (OpenCV 5): use opencv5 instead of opencv4.
#include <opencv2/core.hpp>
#if CV_VERSION_MAJOR == 4
#include <opencv2/imgproc.hpp>
#elif CV_VERSION_MAJOR == 5
#include <opencv2/geometry.hpp>
#else
#error Unsupported OpenCV major version
#endif

#include <dlfcn.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

namespace {

float float_from_bits(std::uint32_t b) {
    float f;
    std::memcpy(&f, &b, sizeof f);
    return f;
}

void report(const char* label, const std::vector<cv::Point2f>& points) {
    std::vector<cv::Point2f> hull;
    cv::convexHull(points, hull, true);
    std::printf("%s input_size %zu hull_size %zu\n", label, points.size(),
                hull.size());
}

}  // namespace

int main() {
    Dl_info info;
    using Fn = void (*)(cv::InputArray, cv::OutputArray, bool, bool);
    Fn fn = &cv::convexHull;
    std::printf("compile %s\n", CV_VERSION);
    std::printf("runtime %s\n", cv::getVersionString().c_str());
    if (dladdr(reinterpret_cast<void*>(fn), &info) && info.dli_fname) {
        std::printf("object %s\n", info.dli_fname);
    }
    std::fflush(stdout);

    const float pos = float_from_bits(0x00000000u);
    const float neg = float_from_bits(0x80000000u);
    report("signed_zero_pair", {{pos, pos}, {neg, pos}});
    report("identical_pair", {{pos, pos}, {pos, pos}});
    report("distinct_pair", {{0.f, 0.f}, {1.f, 0.f}});
    return 0;
}
