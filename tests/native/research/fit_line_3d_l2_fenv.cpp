// GEOM-028 research only; not part of the shim or default native suite.
// Observe native floating-point exceptions, not merely final finiteness.
// Build without fast-math. Run each executable under an external timeout.
#include <opencv2/core.hpp>
#if CV_VERSION_MAJOR == 4
#include <opencv2/imgproc.hpp>
#elif CV_VERSION_MAJOR == 5
#include <opencv2/geometry.hpp>
#else
#error Unsupported OpenCV major
#endif
#include <dlfcn.h>
#include <cfenv>
#include <cmath>
#include <cstdio>
#include <limits>
#include <vector>

namespace {
void flags(int f) {
    std::printf(" invalid=%d divzero=%d overflow=%d underflow=%d",
                !!(f & FE_INVALID), !!(f & FE_DIVBYZERO),
                !!(f & FE_OVERFLOW), !!(f & FE_UNDERFLOW));
}

bool run(const char* family, int exponent, int rounding) {
    const float s = std::ldexp(1.0f, exponent);
    std::vector<cv::Point3f> points;
    if (family[0] == 's') {
        for (int i = 0; i < 8; ++i)
            points.emplace_back(i % 2 ? s : -s, i % 2 ? s : -s,
                                i % 2 ? s : -s);
    }
    else if (family[0] == 'd') points = {{-s, -s, -s}, {s, s, s}};
    else if (family[0] == 'a') points = {{0, -s, 0}, {0, s, 0}};
    else points = {{s, s, s}, {s, s, s}, {s, s, s}};
    cv::Vec6f line = cv::Vec6f::all(0);
    if (std::fesetround(rounding) != 0 || std::feclearexcept(FE_ALL_EXCEPT))
        return false;
    try {
        cv::fitLine(points, line, cv::DIST_L2, 0, 0.01, 0.01);
    } catch (const cv::Exception& e) {
        std::printf("exception family=%s exponent=%d code=%d\n",
                    family, exponent, e.code);
        return false;
    } catch (...) {
        std::printf("unexpected_exception\n");
        return false;
    }
    const int raised = std::fetestexcept(FE_ALL_EXCEPT);
    if (std::fesetround(FE_TONEAREST)) return false;
    bool finite = true;
    double norm2 = 0;
    for (int i = 0; i < 6; ++i) {
        finite = finite && std::isfinite(line[i]);
        if (i < 3) norm2 += double(line[i]) * line[i];
    }
    std::printf("case=%s exponent=%d rounding=%d finite=%d norm2=%a",
                family, exponent, rounding, finite, norm2);
    flags(raised);
    std::printf(" line=");
    for (float x : line.val) std::printf("%a,", double(x));
    std::puts("");
    return true;
}
}

int main() {
    static_assert(std::numeric_limits<float>::is_iec559
                  && sizeof(float) == 4, "IEEE binary32 required");
    std::fenv_t saved;
    // Keep traps masked while observing flags, restoring the caller's
    // original environment (including trap masks) on normal completion.
    if (std::feholdexcept(&saved)) return 2;
    Dl_info algorithm{}, core{};
    dladdr(reinterpret_cast<void*>(static_cast<void (*)(cv::InputArray,
        cv::OutputArray, int, double, double, double)>(&cv::fitLine)),
        &algorithm);
    dladdr(reinterpret_cast<void*>(&cv::getVersionString), &core);
    std::printf("compile=%s runtime=%s fit_object=%s core_object=%s\n",
                CV_VERSION, cv::getVersionString().c_str(),
                algorithm.dli_fname ? algorithm.dli_fname : "unknown",
                core.dli_fname ? core.dli_fname : "unknown");
    std::printf("%s\n", cv::getBuildInformation().c_str());
    // Fixed exact powers of two, including product underflow, Jacobi's
    // absolute pivot cutoff, finite large sums, and overflowing sums.
    const int exponents[] = {-149, -100, -75, -74, -70, -64, -63,
                             -40, -20, -12, 0, 20, 40, 55, 60, 61, 62, 63,
                             64};
    const int modes[] = {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO};
    bool ok = true;
    for (int mode : modes)
        for (const char* family :
             {"diagonal", "axis_y", "coincident", "sum_overflow"})
            for (int exponent : exponents)
                ok = run(family, exponent, mode) && ok;
    if (std::fesetenv(&saved)) return 2;
    return ok ? 0 : 1;
}