// Research only (Task 027C1). NOT built by alr, AUnit or run_native_tests.sh.
//
//   boundary   count limits, 4096-gon acceptance and timing, both windings
//   search N   bounded deterministic search for a production-domain
//              non-convergence or numeric failure of the extended export
//
// Everything goes through the PRODUCTION export, so strict validation always
// runs first; nothing here bypasses it and nothing calls the native
// cv::intersectConvexConvex.
#include "../../../cpp/opencv_geometry_shim.cpp"

#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {

using point = opencv_geometry_point_f32;
using poly = std::vector<point>;

poly ngon(int k, double cx, double cy, double r, double phase, bool cw = false)
{
    poly v;
    for (int j = 0; j < k; ++j) {
        const double a = (cw ? -1 : 1) * 6.283185307179586 * j / k + phase;
        v.push_back({static_cast<float>(cx + r * std::cos(a)),
                     static_cast<float>(cy + r * std::sin(a))});
    }
    return v;
}

struct outcome {
    opencv_geometry_status status;
    int32_t count;
    float area;
    std::string message;
    double seconds;
};

outcome call(const poly &a, const poly &b, bool nested, int32_t capacity = -1)
{
    if (capacity < 0) capacity = static_cast<int32_t>(a.size() + b.size());
    std::vector<point> out(
        static_cast<std::size_t>(capacity > 0 ? capacity : 1));
    outcome o{OPENCV_GEOMETRY_OK, 77, 77.0f, "", 0};
    const auto t0 = std::chrono::steady_clock::now();
    o.status = opencv_geometry_intersect_convex_convex_extended_f32(
        a.data(), static_cast<int32_t>(a.size()), b.data(),
        static_cast<int32_t>(b.size()), nested ? 1 : 0, out.data(), capacity,
        &o.count, &o.area);
    o.seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t0).count();
    o.message = opencv_geometry_last_error_message();
    return o;
}

void show(const char *label, const outcome &o)
{
    std::printf("%-34s status=%d count=%d area=%g time=%.3fs %s\n", label,
                static_cast<int>(o.status), static_cast<int>(o.count),
                static_cast<double>(o.area), o.seconds, o.message.c_str());
}

int boundary()
{
    int bad = 0;
    auto expect = [&bad](bool ok, const char *what) {
        if (!ok) { std::printf("EXPECTATION FAILED: %s\n", what); ++bad; }
    };
    const poly tri = {{0, 0}, {4, 0}, {0, 4}};
    const poly tri2 = {{1, 1}, {5, 1}, {1, 5}};
    outcome o = call(tri, tri2, true);
    show("3 vertices accepted", o);
    expect(o.status == OPENCV_GEOMETRY_OK && o.count > 0, "3-gon accepted");

    for (const bool cw : {false, true}) {
        for (const double r : {5.0, 170.0, 300.0, 1000.0, 1.0e5, 1.0e8}) {
            const poly big = ngon(4096, 0, 0, r, 0.0, cw);
            const poly other = ngon(4096, r * 0.01, 0, r * 0.9, 0.001, cw);
            char label[96];
            std::snprintf(label, sizeof label, "4096 x 4096 r=%g %s", r,
                          cw ? "cw" : "ccw");
            show(label, call(big, other, true, 8192));
        }
    }
    {
        const poly big = ngon(4096, 0, 0, 1000.0, 0.0);
        show("4096 vs triangle", call(big, tri, true));
    }
    // Count limit: rejected before expensive validation.
    for (const int k : {4097, 5000, 100000}) {
        const poly huge(static_cast<std::size_t>(k), point{0, 0});
        char label[64];
        std::snprintf(label, sizeof label, "%d vertices (left)", k);
        o = call(huge, tri, true, 16);
        show(label, o);
        expect(o.status == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
                   && o.count == 0 && o.area == 0.0f
                   && o.message.find("4096") != std::string::npos
                   && o.seconds < 0.05,
               "oversized polygon rejected by count, outputs zero");
        o = call(tri, huge, false, 16);
        expect(o.status == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
                   && o.count == 0 && o.area == 0.0f,
               "oversized right polygon rejected, outputs zero");
    }
    std::printf("boundary: %d unexpected\n", bad);
    return bad != 0;
}

// Deterministic generator.
struct rng {
    unsigned long long s;
    double next()
    {
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        return static_cast<double>(s >> 11) / 9007199254740992.0;
    }
};

int search(long pairs)
{
    rng g{20270112};
    long engine = 0, nonconv = 0, numeric = 0, ok = 0, rejected = 0, other = 0;
    long nonempty = 0;
    double total_seconds = 0;
    for (long i = 0; i < pairs; ++i) {
        const int mode = static_cast<int>(i % 6);
        const int n = 3 + static_cast<int>(g.next() * 12);
        const int m = 3 + static_cast<int>(g.next() * 12);
        double r1 = 1.0 + g.next() * 20, r2 = r1, dx = 0;
        switch (mode) {
        case 0: dx = (g.next() - 0.5) * 1e-3; break;           // near equal
        case 1: r2 = r1 * (1.0 + 1e-6 * g.next()); break;      // near parallel
        case 2: r1 = 0.1 + g.next(); r2 = 1.0e6 * (1 + g.next()); break;
        case 3: dx = 2 * r1 * (1.0 - 1e-6 * g.next()); break;  // near contact
        case 4: r1 = 1.0e7 * (1 + g.next()); r2 = r1 * 0.5; dx = r1 * 0.3;
                break;
        default: r2 = r1 * 0.5; dx = r1 * 0.5 * (1 + 1e-5 * g.next()); break;
        }
        const double phase = g.next();
        const poly a = ngon(n, 0, 0, r1, phase);
        const poly b = ngon(m, dx, 0, r2, phase * (mode == 1 ? 1.0 : 0.37));
        const outcome o = call(a, b, (i & 1) != 0);
        if (o.status == OPENCV_GEOMETRY_OK) {
            ++engine; ++ok;
            if (o.count > 0) ++nonempty;
            total_seconds += o.seconds;
        } else if (o.message.find("did not converge") != std::string::npos) {
            ++engine; ++nonconv;
            std::printf("NONCONVERGENCE pair=%ld mode=%d n=%d m=%d\n", i, mode,
                        n, m);
        } else if (o.message.find("non-representable") != std::string::npos) {
            ++engine; ++numeric;
            std::printf("NUMERIC pair=%ld mode=%d\n", i, mode);
        } else if (o.message.find("polygon") != std::string::npos) {
            ++rejected;   // strict validation, as designed
        } else {
            ++other;
            std::printf("OTHER pair=%ld mode=%d: %s\n", i, mode,
                        o.message.c_str());
        }
        if (o.status != OPENCV_GEOMETRY_OK
            && (o.count != 0 || o.area != 0.0f)) {
            std::printf("OUTPUT NOT ZERO pair=%ld\n", i);
            return 2;
        }
    }
    std::printf("search pairs=%ld engine_reached=%ld ok=%ld "
                "nonconvergence=%ld numeric=%ld validator_rejected=%ld "
                "other=%ld nonempty_results=%ld export_seconds=%.3f\n", pairs,
                engine, ok, nonconv, numeric, rejected, other, nonempty,
                total_seconds);
    return other != 0;
}

// Thin rectangles, rotated by tiny angles against each other, with edge
// lengths near the validator's conditioning threshold: the engine's absolute
// 1e-5 orientation tolerance is most sensitive here.
poly sliver(double cx, double cy, double length, double width, double angle)
{
    const double c = std::cos(angle), s = std::sin(angle);
    const double hx = length / 2, hy = width / 2;
    const double px[4] = {-hx, hx, hx, -hx}, py[4] = {-hy, -hy, hy, hy};
    poly v;
    for (int k = 0; k < 4; ++k) {
        v.push_back({static_cast<float>(cx + c * px[k] - s * py[k]),
                     static_cast<float>(cy + s * px[k] + c * py[k])});
    }
    return v;
}

int slivers(long pairs)
{
    rng g{97531};
    long ok = 0, nonconv = 0, numeric = 0, rejected = 0, other = 0;
    for (long i = 0; i < pairs; ++i) {
        const double length = 1.0 + g.next() * 1.0e4;
        const double width = 1.0e-3 * std::pow(10.0, g.next() * 3.0);
        const double angle = 1.0e-7 * std::pow(10.0, g.next() * 5.0);
        const double shift = (g.next() - 0.5) * width;
        const poly a = sliver(0, 0, length, width, 0.0);
        const poly b = sliver(0, shift, length * (0.5 + g.next()), width,
                              angle);
        const outcome o = call(a, b, (i & 1) != 0);
        if (o.status == OPENCV_GEOMETRY_OK) {
            ++ok;
        } else if (o.message.find("did not converge") != std::string::npos) {
            ++nonconv;
            std::printf("NONCONVERGENCE i=%ld length=%g width=%g angle=%g\n",
                        i, length, width, angle);
        } else if (o.message.find("non-representable") != std::string::npos) {
            ++numeric;
        } else if (o.message.find("polygon") != std::string::npos) {
            ++rejected;
        } else {
            ++other;
            std::printf("OTHER i=%ld: %s\n", i, o.message.c_str());
        }
        if (o.status != OPENCV_GEOMETRY_OK
            && (o.count != 0 || o.area != 0.0f)) {
            return 2;
        }
    }
    std::printf("slivers pairs=%ld ok=%ld nonconvergence=%ld numeric=%ld "
                "validator_rejected=%ld other=%ld\n", pairs, ok, nonconv,
                numeric, rejected, other);
    return other != 0;
}

}  // namespace

int main(int argc, char **argv)
{
    if (argc >= 3 && std::strcmp(argv[1], "slivers") == 0)
        return slivers(std::atol(argv[2]));
    if (argc >= 2 && std::strcmp(argv[1], "boundary") == 0) return boundary();
    if (argc >= 3 && std::strcmp(argv[1], "search") == 0)
        return search(std::atol(argv[2]));
    std::fprintf(stderr, "usage: boundary | search <pairs>\n");
    return 64;
}
