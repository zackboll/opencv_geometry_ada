// Reproducer D: cv::minEnclosingConvexPolygon on a unit square with k = 3.
//
// Standalone: public OpenCV headers only, C++17. Research only.
// minEnclosingConvexPolygon is declared from OpenCV 4.13 (imgproc) and in
// 5.x (geometry). Earlier 4.x releases report "not applicable" (the 4.10.0
// and 4.12.0 headers do not declare it).
//
// Build (OpenCV 4, imgproc), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_d repro_d_min_enclosing_convex_polygon.cpp $(pkg-config --cflags --libs opencv4) -ldl
// Build (OpenCV 5, geometry), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_d repro_d_min_enclosing_convex_polygon.cpp $(pkg-config --cflags --libs opencv5) -ldl
//
// Usage: repro_d [unit_square_3 | unit_square_4]
//   unit_square_3  the defect input (k = 3)
//   unit_square_4  k = 4 control on the same input
// Exit: 0 returned and every input point enclosed, 1 returned but not
//       enclosing, 10 cv::Exception, 11 std::exception, 12 other,
//       13 not applicable, 64 usage. A crash is a process signal.
//
// The enclosure check is exact: all values are small integers in binary32
// and cross products are evaluated in int64_t.
#include <opencv2/core.hpp>
#if CV_VERSION_MAJOR == 4
#include <opencv2/imgproc.hpp>
#elif CV_VERSION_MAJOR == 5
#include <opencv2/geometry.hpp>
#else
#error Unsupported OpenCV major version
#endif

#include <dlfcn.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <exception>
#include <string>
#include <vector>

namespace {

std::uint32_t bits_of(float f) {
    std::uint32_t b;
    std::memcpy(&b, &f, sizeof b);
    return b;
}

[[maybe_unused]] void print_points(const char* label,
                                   const std::vector<cv::Point2f>& v) {
    std::printf("%s %zu\n", label, v.size());
    for (const cv::Point2f& p : v) {
        std::printf("  x=0x%08x y=0x%08x  (%.9g, %.9g)\n", bits_of(p.x),
                    bits_of(p.y), static_cast<double>(p.x),
                    static_cast<double>(p.y));
    }
    std::fflush(stdout);
}

#if CV_VERSION_MAJOR == 5 || CV_VERSION_MINOR >= 13
#define REPRO_D_HAS_FUNCTION 1
#else
#define REPRO_D_HAS_FUNCTION 0
#endif

void print_identity() {
    Dl_info info;
    Dl_info core;
    std::printf("compile %s\n", CV_VERSION);
    std::printf("runtime %s\n", cv::getVersionString().c_str());
#if REPRO_D_HAS_FUNCTION
    using Fn = double (*)(cv::InputArray, cv::OutputArray, int);
    Fn fn = &cv::minEnclosingConvexPolygon;
#else
    using Fn = double (*)(cv::InputArray, cv::OutputArray);
    Fn fn = &cv::minEnclosingTriangle;
#endif
    if (dladdr(reinterpret_cast<void*>(fn), &info) && info.dli_fname) {
        std::printf("object %s\n", info.dli_fname);
    }
    if (dladdr(reinterpret_cast<void*>(&cv::getVersionString), &core) &&
        core.dli_fname) {
        std::printf("runtime_object %s\n", core.dli_fname);
    }
    std::fflush(stdout);
}

std::int64_t cross(const cv::Point2f& a, const cv::Point2f& b,
                   const cv::Point2f& p) {
    const auto i = [](float v) { return static_cast<std::int64_t>(std::llround(v)); };
    return (i(b.x) - i(a.x)) * (i(p.y) - i(a.y)) -
           (i(b.y) - i(a.y)) * (i(p.x) - i(a.x));
}

bool integral(const cv::Point2f& p) {
    return p.x == std::floor(p.x) && p.y == std::floor(p.y) &&
           std::fabs(p.x) < 1e6f && std::fabs(p.y) < 1e6f;
}

[[maybe_unused]] bool encloses(const std::vector<cv::Point2f>& poly,
                               const std::vector<cv::Point2f>& pts) {
    for (const cv::Point2f& p : poly) {
        if (!integral(p)) {
            std::printf("enclosure_check not_exact_integral\n");
            return false;
        }
    }
    std::int64_t area2 = 0;
    for (std::size_t i = 0; i < poly.size(); ++i) {
        const cv::Point2f& a = poly[i];
        const cv::Point2f& b = poly[(i + 1) % poly.size()];
        area2 += std::llround(a.x) * std::llround(b.y) -
                 std::llround(b.x) * std::llround(a.y);
    }
    std::printf("output_signed_area2 %lld\n", static_cast<long long>(area2));
    const int orient = area2 > 0 ? 1 : (area2 < 0 ? -1 : 0);
    bool ok = orient != 0;
    for (const cv::Point2f& p : pts) {
        bool inside = orient != 0;
        for (std::size_t i = 0; i < poly.size() && inside; ++i) {
            if (cross(poly[i], poly[(i + 1) % poly.size()], p) * orient < 0) {
                inside = false;
            }
        }
        std::printf("  point (%g, %g) %s\n", static_cast<double>(p.x),
                    static_cast<double>(p.y),
                    inside ? "enclosed" : "NOT ENCLOSED");
        ok = ok && inside;
    }
    return ok;
}

int run(const std::string& name) {
#if !REPRO_D_HAS_FUNCTION
    (void)name;
    std::printf("not_applicable minEnclosingConvexPolygon introduced in 4.13\n");
    return 13;
#else
    int k = 0;
    if (name == "unit_square_3") {
        k = 3;
    } else if (name == "unit_square_4") {
        k = 4;
    } else {
        std::fprintf(stderr, "unknown case %s\n", name.c_str());
        return 64;
    }
    const std::vector<cv::Point2f> points{
        {0.0f, 0.0f}, {1.0f, 0.0f}, {1.0f, 1.0f}, {0.0f, 1.0f}};
    print_points("input", points);
    std::vector<cv::Point2f> output;
    const double area = cv::minEnclosingConvexPolygon(points, output, k);
    std::printf("k %d\narea %.17g\n", k, area);
    print_points("output", output);
    const bool ok = encloses(output, points);
    std::printf("enclosure %s\n", ok ? "holds" : "FAILS");
    return ok ? 0 : 1;
#endif
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s unit_square_3|unit_square_4\n",
                     argv[0]);
        return 64;
    }
    print_identity();
    try {
        return run(argv[1]);
    } catch (const cv::Exception& e) {
        std::printf("cv_exception %s\n", e.msg.c_str());
        return 10;
    } catch (const std::exception& e) {
        std::printf("std_exception %s\n", e.what());
        return 11;
    } catch (...) {
        std::printf("other_exception\n");
        return 12;
    }
}
