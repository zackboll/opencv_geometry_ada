// Reproducer B: cv::minEnclosingTriangle that did not return in a bounded
// wall-clock time.
//
// Standalone: public OpenCV headers only, C++17. Research only.
//
// Build (OpenCV 4, imgproc), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_b repro_b_min_enclosing_triangle_non_return.cpp $(pkg-config --cflags --libs opencv4) -ldl
// Build (OpenCV 5, geometry), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_b repro_b_min_enclosing_triangle_non_return.cpp $(pkg-config --cflags --libs opencv5) -ldl
//
// Usage: repro_b CASE
//   square_1e-5        float32 square, side 1e-5f (defect candidate)
//   square_1e-3        larger-scale control
//   square_1e-1        larger-scale control
//   square_1          larger-scale control
//   int_hang           integer-input case, separate control
//   int_square         integer-input benign control
//
// RUN EACH CASE UNDER AN EXTERNAL HARD TIMEOUT, e.g. `timeout -s KILL 10`.
// This program has no internal watchdog. If the call does not return, the
// controller terminates the child. That shows non-return within the limit
// only; it does not prove an infinite loop.
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
#include <exception>
#include <string>
#include <vector>

namespace {

std::uint32_t bits_of(float f) {
    std::uint32_t b;
    std::memcpy(&b, &f, sizeof b);
    return b;
}

void print_points(const char* label, const std::vector<cv::Point2f>& v) {
    std::printf("%s %zu\n", label, v.size());
    for (const cv::Point2f& p : v) {
        std::printf("  x=0x%08x y=0x%08x  (%.9g, %.9g)\n", bits_of(p.x),
                    bits_of(p.y), static_cast<double>(p.x),
                    static_cast<double>(p.y));
    }
    std::fflush(stdout);
}

void print_identity() {
    using Fn = double (*)(cv::InputArray, cv::OutputArray);
    Fn fn = &cv::minEnclosingTriangle;
    Dl_info info;
    std::printf("compile %s\n", CV_VERSION);
    std::printf("runtime %s\n", cv::getVersionString().c_str());
    if (dladdr(reinterpret_cast<void*>(fn), &info) && info.dli_fname) {
        std::printf("object %s\n", info.dli_fname);
    }
    Dl_info core;
    if (dladdr(reinterpret_cast<void*>(&cv::getVersionString), &core) &&
        core.dli_fname) {
        std::printf("runtime_object %s\n", core.dli_fname);
    }
    std::fflush(stdout);
}

int run_float(float side) {
    // Compiled binary32 coordinates; printed exactly below.
    const std::vector<cv::Point2f> points{
        {0.0f, 0.0f}, {side, 0.0f}, {side, side}, {0.0f, side}};
    print_points("input", points);
    std::vector<cv::Point2f> output;
    const double area = cv::minEnclosingTriangle(points, output);
    std::printf("area %.17g\n", area);
    print_points("output", output);
    return 0;
}

int run_int(const std::vector<cv::Point>& points) {
    std::printf("input_i32 %zu\n", points.size());
    for (const cv::Point& p : points) {
        std::printf("  (%d, %d)\n", p.x, p.y);
    }
    std::fflush(stdout);
    std::vector<cv::Point2f> output;
    const double area = cv::minEnclosingTriangle(points, output);
    std::printf("area %.17g\n", area);
    print_points("output", output);
    return 0;
}

int run(const std::string& name) {
    if (name == "square_1e-5") return run_float(1e-5f);
    if (name == "square_1e-3") return run_float(1e-3f);
    if (name == "square_1e-1") return run_float(1e-1f);
    if (name == "square_1") return run_float(1.0f);
    if (name == "int_hang") {
        return run_int({{0, 0}, {1, 0}, {100001, 1}, {100000, 1}});
    }
    if (name == "int_square") {
        return run_int({{0, 0}, {10, 0}, {10, 10}, {0, 10}});
    }
    std::fprintf(stderr, "unknown case %s\n", name.c_str());
    return 64;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s CASE (see source header)\n", argv[0]);
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
