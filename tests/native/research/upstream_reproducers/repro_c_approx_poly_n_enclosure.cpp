// Reproducer C: cv::approxPolyN returns a triangle that does not enclose
// the input polygon (OpenCV 4.11+ only; the function does not exist before).
//
// Standalone: public OpenCV headers only, C++17. Research only.
//
// Build (OpenCV 4, imgproc), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_c repro_c_approx_poly_n_enclosure.cpp $(pkg-config --cflags --libs opencv4) -ldl
// Build (OpenCV 5, geometry), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_c repro_c_approx_poly_n_enclosure.cpp $(pkg-config --cflags --libs opencv5) -ldl
//
// Usage: repro_c [unit_square | control_square_4]
//   unit_square      approxPolyN(unit square, 3 sides, eps -1, not
//                    convex-preserving) -- the defect input
//   control_square_4 same square with 4 sides (benign control)
// Exit: 0 returned and enclosure holds, 1 returned but enclosure FAILS,
//       10 cv::Exception, 11 std::exception, 12 other, 13 not applicable
//       (OpenCV < 4.11), 64 usage.
//
// The enclosure test is exact: every coordinate involved is a small integer
// that is exactly representable in binary32 and the cross products are
// computed in int64_t, so no rounding is involved.
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

void print_identity() {
    Dl_info info;
    Dl_info core;
    std::printf("compile %s\n", CV_VERSION);
    std::printf("runtime %s\n", cv::getVersionString().c_str());
#if CV_VERSION_MAJOR == 5 || CV_VERSION_MINOR >= 11
    using Fn = void (*)(cv::InputArray, cv::OutputArray, int, float, bool);
    Fn fn = &cv::approxPolyN;
#else
    // approxPolyN is absent; report the library defining approxPolyDP so the
    // identity block is still complete.
    using Fn = void (*)(cv::InputArray, cv::OutputArray, double, bool);
    Fn fn = &cv::approxPolyDP;
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

std::int64_t to_i64(float v) {
    return static_cast<std::int64_t>(std::llround(v));
}

bool integral(const cv::Point2f& p) {
    return p.x == std::floor(p.x) && p.y == std::floor(p.y) &&
           std::fabs(p.x) < 1e6f && std::fabs(p.y) < 1e6f;
}

// Sign of (b - a) x (p - a), exact in int64 for integral coordinates.
std::int64_t cross(const cv::Point2f& a, const cv::Point2f& b,
                   const cv::Point2f& p) {
    return (to_i64(b.x) - to_i64(a.x)) * (to_i64(p.y) - to_i64(a.y)) -
           (to_i64(b.y) - to_i64(a.y)) * (to_i64(p.x) - to_i64(a.x));
}

// True if every input point lies inside or on the convex output polygon.
// The output may be wound either way, so orient by its signed area.
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
        area2 += to_i64(a.x) * to_i64(b.y) - to_i64(b.x) * to_i64(a.y);
    }
    std::printf("output_signed_area2 %lld\n", static_cast<long long>(area2));
    const int orient = area2 > 0 ? 1 : (area2 < 0 ? -1 : 0);
    bool ok = orient != 0;
    for (const cv::Point2f& p : pts) {
        bool inside = orient != 0;
        for (std::size_t i = 0; i < poly.size(); ++i) {
            const std::int64_t c =
                cross(poly[i], poly[(i + 1) % poly.size()], p);
            if (c * orient < 0) {
                inside = false;
                std::printf("  edge %zu: cross=%lld\n", i,
                            static_cast<long long>(c));
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
#if CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR < 11
    (void)name;
    std::printf("not_applicable approxPolyN introduced in 4.11\n");
    return 13;
#else
    int sides = 0;
    if (name == "unit_square") {
        sides = 3;
    } else if (name == "control_square_4") {
        sides = 4;
    } else {
        std::fprintf(stderr, "unknown case %s\n", name.c_str());
        return 64;
    }
    const std::vector<cv::Point2f> points{
        {0.0f, 0.0f}, {1.0f, 0.0f}, {1.0f, 1.0f}, {0.0f, 1.0f}};
    print_points("input", points);
    std::vector<cv::Point2f> output;
    cv::approxPolyN(points, output, sides, -1.0f, false);
    print_points("output", output);
    const bool ok = encloses(output, points);
    std::printf("enclosure %s\n", ok ? "holds" : "FAILS");
    return ok ? 0 : 1;
#endif
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s unit_square|control_square_4\n",
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
