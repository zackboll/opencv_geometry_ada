// Research only (Task 025). NOT built by alr, AUnit or run_native_tests.sh.
// One named native case per process; use scripts/run_risk_reassessment.py.
// Cases exercise approxPolyN, Float32/integer minEnclosingTriangle and
// intersectConvexConvex with fixed, reproducible inputs. Every input and
// output float is printed as exact hexadecimal bits.
// Exit: 0 returned, 10 cv::Exception, 11 std::exception, 12 other,
//       64 usage error. A hang or signal is classified by the controller.
#include <opencv2/core.hpp>
#if CV_VERSION_MAJOR == 4
#include <opencv2/imgproc.hpp>
#elif CV_VERSION_MAJOR == 5
#include <opencv2/geometry.hpp>
#else
#error Unsupported OpenCV major
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

std::uint32_t bits(float f) {
    std::uint32_t b;
    std::memcpy(&b, &f, 4);
    return b;
}

void print_points(const char* label, const std::vector<cv::Point2f>& v) {
    std::printf("%s %zu\n", label, v.size());
    for (const auto& p : v)
        std::printf("  %08x %08x  %.9g %.9g\n", bits(p.x), bits(p.y),
                    static_cast<double>(p.x), static_cast<double>(p.y));
    std::fflush(stdout);
}

std::vector<cv::Point2f> square(float side) {
    return {{0, 0}, {side, 0}, {side, side}, {0, side}};
}

// Regular n-gon rounded to binary32, strictly convex after rounding for the
// radii used here (the controller does not rely on that: it only records).
std::vector<cv::Point2f> ngon(int n, double cx, double cy, double r) {
    std::vector<cv::Point2f> v;
    for (int i = 0; i < n; ++i) {
        double a = 2.0 * 3.14159265358979323846 * i / n;
        v.emplace_back(static_cast<float>(cx + r * std::cos(a)),
                       static_cast<float>(cy + r * std::sin(a)));
    }
    return v;
}

int apn(const std::vector<cv::Point2f>& in, int sides, double eps) {
#if CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR < 11
    (void)in; (void)sides; (void)eps;
    std::printf("not_applicable approxPolyN introduced in 4.11\n");
    return 13;
#else
    print_points("input", in);
    std::vector<cv::Point2f> out;
    cv::approxPolyN(in, out, sides, static_cast<float>(eps), false);
    print_points("output", out);
    return 0;
#endif
}

int met(const std::vector<cv::Point2f>& in) {
    print_points("input", in);
    std::vector<cv::Point2f> tri;
    double area = cv::minEnclosingTriangle(in, tri);
    std::printf("area %.17g\n", area);
    print_points("output", tri);
    return 0;
}

int met_i32(const std::vector<cv::Point>& in) {
    std::vector<cv::Point2f> tri;
    std::printf("input_i32 %zu\n", in.size());
    std::fflush(stdout);
    double area = cv::minEnclosingTriangle(in, tri);
    std::printf("area %.17g\n", area);
    print_points("output", tri);
    return 0;
}

int ict(const std::vector<cv::Point2f>& a, const std::vector<cv::Point2f>& b) {
    print_points("p1", a);
    print_points("p2", b);
    std::vector<cv::Point2f> out;
    float area = cv::intersectConvexConvex(a, b, out, true);
    std::printf("area %.9g\n", static_cast<double>(area));
    print_points("output", out);
    return 0;
}

int run(const std::string& name) {
    if (name == "apn_unit_square_3")
        return apn(square(1.f), 3, -1.0);
    if (name == "apn_unit_square_4")
        return apn(square(1.f), 4, -1.0);
    if (name == "apn_pentagon_3")
        return apn({{0, 0}, {4, 0}, {5, 2}, {3, 5}, {0, 3}}, 3, -1.0);
    if (name == "apn_pentagon_4")
        return apn({{0, 0}, {4, 0}, {5, 2}, {3, 5}, {0, 3}}, 4, -1.0);
    if (name == "apn_octagon_r10_4") {
        return apn(ngon(8, 0, 0, 10.0), 4, -1.0);
    }
    if (name == "apn_circle16_r100_6")
        return apn(ngon(16, 0, 0, 100.0), 6, -1.0);
    if (name == "apn_square_2e-6_pent")
        return apn({{0, 0}, {2e-6f, 0}, {3e-6f, 1e-6f}, {2e-6f, 2e-6f},
                    {0, 2e-6f}}, 3, -1.0);
    if (name == "met32_unit_square")
        return met(square(1.f));
    if (name == "met32_pentagon")
        return met({{0, 0}, {4, 0}, {5, 2}, {3, 5}, {0, 3}});
    if (name == "met32_ngon32_r100")
        return met(ngon(32, 50, 50, 100.0));
    if (name == "met32_square_1e-1")
        return met(square(0.1f));
    if (name == "met32_square_1e-3")
        return met(square(1e-3f));
    if (name == "met32_square_1e-5")
        return met(square(1e-5f));
    if (name == "met32_square_1e-6")
        return met(square(1e-6f));
    if (name == "met32_square_1e3")
        return met(square(1e3f));
    if (name == "met32_ngon32_r1e-4")
        return met(ngon(32, 0, 0, 1e-4));
    if (name == "met32_thin_sliver")
        return met({{0, 0}, {100, 0}, {100, 1e-4f}, {0, 1e-4f}});
    if (name == "met32_signed_zero")
        return met({{0.f, 0.f}, {-0.f, 0.f}});
    if (name == "met32_signed_zero_tri")
        return met({{0.f, 0.f}, {-0.f, 0.f}, {1.f, 0.f}, {0.f, 1.f}});
    if (name == "met_i32_hang_a")
        return met_i32({{0, 0}, {1, 0}, {100001, 1}, {100000, 1}});
    if (name == "met_i32_unit_square")
        return met_i32({{0, 0}, {10, 0}, {10, 10}, {0, 10}});
    if (name == "ict_triangles_0p1")
        return ict({{0.1f, 0.1f}, {0.7f, 0.1f}, {0.1f, 0.7f}},
                   {{0.2f, 0.05f}, {0.8f, 0.3f}, {0.3f, 0.9f}});
    if (name == "ict_ngon62_61_r1000")
        return ict(ngon(62, 0, 0, 1000.0), ngon(61, 3.3, 1.7, 1000.0));
    if (name == "ict_ngon62_61_r1")
        return ict(ngon(62, 0, 0, 1.0), ngon(61, 0.003, 0.002, 1.0));
    if (name == "ict_ngon_grid_p2")
        return ict({{0, 0}, {8, 0}, {8, 8}, {0, 8}},
                   {{4, 4}, {12, 4}, {12, 12}, {4, 12}});
    std::fprintf(stderr, "unknown case %s\n", name.c_str());
    return 64;
}

void identity() {
    Dl_info info;
    void* sym = reinterpret_cast<void*>(
        static_cast<float (*)(cv::InputArray, cv::InputArray,
                              cv::OutputArray, bool)>(
            &cv::intersectConvexConvex));
    if (dladdr(sym, &info) && info.dli_fname)
        std::printf("object %s\n", info.dli_fname);
    std::printf("runtime %s\n", CV_VERSION);
    std::fflush(stdout);
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: probe CASE\n");
        return 64;
    }
    identity();
    try {
        return run(argv[1]);
    } catch (const cv::Exception& e) {
        std::printf("cv_exception %s\n", e.msg.c_str());
        return 10;
    } catch (const std::exception& e) {
        std::printf("std_exception %s\n", e.what());
        return 11;
    } catch (...) {
        return 12;
    }
}