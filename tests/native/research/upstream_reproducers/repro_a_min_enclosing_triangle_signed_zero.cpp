// Reproducer A: cv::minEnclosingTriangle with a signed-zero point pair.
//
// Standalone: public OpenCV headers only, C++17, no other dependencies.
// Research only. NOT built by alr, AUnit or CI.
//
// Build (OpenCV 4, imgproc), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_a repro_a_min_enclosing_triangle_signed_zero.cpp $(pkg-config --cflags --libs opencv4) -ldl
// Build (OpenCV 5, geometry), one command:
//   g++ -std=c++17 -Wall -Wextra -Werror -o repro_a repro_a_min_enclosing_triangle_signed_zero.cpp $(pkg-config --cflags --libs opencv5) -ldl
// If pkg-config metadata is missing use -I<prefix>/include/opencv4 (or
// opencv5), -L<prefix>/lib, -lopencv_imgproc (4.x) or -lopencv_geometry
// (5.x), -lopencv_core, and run with LD_LIBRARY_PATH=<prefix>/lib.
//
// Usage: repro_a [signed_zero | control_square | control_triangle]
//   signed_zero      the defect input, built from exact binary32 bits
//   control_square   nondegenerate unit square (benign control)
//   control_triangle nondegenerate triangle (benign control)
// The program prints identity lines first, then the exact input bits.
// A crash is a process signal; the exit status reports exceptions:
//   0 returned, 10 cv::Exception, 11 std::exception, 12 other, 64 usage.
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

float float_from_bits(std::uint32_t b) {
    float f;
    std::memcpy(&f, &b, sizeof f);
    return f;
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

// Identity: compile-time macro, runtime query, and the shared objects that
// actually define the function under test and cv::getVersionString.
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

int run(const std::string& name) {
    std::vector<cv::Point2f> points;
    if (name == "signed_zero") {
        // +0.0f is 0x00000000 and -0.0f is 0x80000000. Built from bits so a
        // literal or optimizer cannot drop the sign.
        const float pos_zero = float_from_bits(0x00000000u);
        const float neg_zero = float_from_bits(0x80000000u);
        points = {{pos_zero, pos_zero}, {neg_zero, pos_zero}};
    } else if (name == "control_square") {
        points = {{0.f, 0.f}, {1.f, 0.f}, {1.f, 1.f}, {0.f, 1.f}};
    } else if (name == "control_triangle") {
        points = {{0.f, 0.f}, {4.f, 0.f}, {0.f, 3.f}};
    } else {
        std::fprintf(stderr, "unknown case %s\n", name.c_str());
        return 64;
    }
    print_points("input", points);

    std::vector<cv::Point2f> output;
    const double area = cv::minEnclosingTriangle(points, output);
    std::printf("area %.17g\n", area);
    print_points("output", output);
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr,
                     "usage: %s signed_zero|control_square|control_triangle\n",
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
