// Research only (Task 027C1). NOT built by alr, AUnit or run_native_tests.sh.
// Runs a fixed corpus through the PRODUCTION export
// opencv_geometry_intersect_convex_convex_extended_f32 (the shim source is
// included) and prints one line per case: status, count, area bits, vertex
// bits in result order, whether the nested path was reached, and an
// independent binary64 Sutherland-Hodgman reference area. Identity lines
// (compile and runtime version, providers) start with '#'; diff two runs
// with grep -v '^#'. Never calls cv::intersectConvexConvex.
#include "../../../cpp/opencv_geometry_shim.cpp"

#include <dlfcn.h>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {

using point = opencv_geometry_point_f32;
using poly = std::vector<point>;

double signed_area(const std::vector<std::pair<double, double>> &p)
{
    double a = 0;
    for (size_t i = 0; i < p.size(); ++i) {
        const auto &u = p[i], &v = p[(i + 1) % p.size()];
        a += u.first * v.second - u.second * v.first;
    }
    return a / 2;
}

// Independent reference: clip subject by every edge of a CCW clip polygon.
double reference_area(const poly &a, const poly &b)
{
    using P = std::pair<double, double>;
    auto conv = [](const poly &s) {
        std::vector<P> r;
        for (const point &q : s) r.push_back({q.x, q.y});
        if (signed_area(r) < 0) {
            const std::vector<P> copy(r.rbegin(), r.rend());
            return copy;
        }
        return r;
    };
    std::vector<P> subject = conv(a);
    const std::vector<P> clip = conv(b);
    for (size_t i = 0; i < clip.size() && !subject.empty(); ++i) {
        const P e0 = clip[i], e1 = clip[(i + 1) % clip.size()];
        auto side = [&](const P &q) {
            return (e1.first - e0.first) * (q.second - e0.second)
                 - (e1.second - e0.second) * (q.first - e0.first);
        };
        std::vector<P> out;
        for (size_t j = 0; j < subject.size(); ++j) {
            const P s = subject[j], t = subject[(j + 1) % subject.size()];
            const double ds = side(s), dt = side(t);
            if (ds >= 0) out.push_back(s);
            if ((ds >= 0) != (dt >= 0)) {
                const double u = ds / (ds - dt);
                out.push_back({s.first + u * (t.first - s.first),
                               s.second + u * (t.second - s.second)});
            }
        }
        subject = out;
    }
    return subject.size() < 3 ? 0.0 : std::fabs(signed_area(subject));
}

unsigned bits(float f)
{
    unsigned u;
    std::memcpy(&u, &f, sizeof u);
    return u;
}

poly box(float x, float y, float w, float h)
{
    return {{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}};
}

poly reversed(poly p)
{
    return poly(p.rbegin(), p.rend());
}

poly ngon(int k, double cx, double cy, double r, double phase)
{
    poly v;
    for (int j = 0; j < k; ++j) {
        const double a = 6.283185307179586 * j / k + phase;
        v.push_back({static_cast<float>(cx + r * std::cos(a)),
                     static_cast<float>(cy + r * std::sin(a))});
    }
    return v;
}

void run_case(const std::string &name, const poly &a, const poly &b,
              bool nested)
{
    std::vector<point> out(a.size() + b.size() + 1);
    int32_t count = -1;
    float area = -1.0f;
    const opencv_geometry_status status =
        opencv_geometry_intersect_convex_convex_extended_f32(
            a.data(), static_cast<int32_t>(a.size()), b.data(),
            static_cast<int32_t>(b.size()), nested ? 1 : 0, out.data(),
            static_cast<int32_t>(out.size()), &count, &area);
    bool nested_reached = false;
    if (status == OPENCV_GEOMETRY_OK) {
        std::vector<cv::Point2f> l, r;
        for (const point &q : a) l.emplace_back(q.x, q.y);
        for (const point &q : b) r.emplace_back(q.x, q.y);
        nested_reached = opencv_geometry_compat::intersect_convex_convex_f32(
            l, r, nested).diagnostics.nested_path;
    }
    const double ref = reference_area(a, b);
    std::printf("%s nested=%d status=%d count=%d area_bits=%08x "
                "area=%.9g ref=%.9g nested_path=%d verts=",
                name.c_str(), nested ? 1 : 0, static_cast<int>(status),
                static_cast<int>(count), bits(area), area, ref,
                nested_reached ? 1 : 0);
    for (int i = 0; i < count; ++i) {
        std::printf("%s%08x:%08x", i ? ";" : "", bits(out[i].x),
                    bits(out[i].y));
    }
    if (status != OPENCV_GEOMETRY_OK) {
        std::printf("msg=%s", opencv_geometry_last_error_message());
    }
    std::printf("\n");
}

void both(const std::string &name, const poly &a, const poly &b)
{
    run_case(name, a, b, true);
    run_case(name, a, b, false);
}

std::string provider(void *symbol)
{
    Dl_info info;
    char resolved[4096];
    if (dladdr(symbol, &info) && info.dli_fname
        && realpath(info.dli_fname, resolved)) {
        return resolved;
    }
    return "unknown";
}

}  // namespace

int main()
{
    std::printf("# compile CV_VERSION %s\n", CV_VERSION);
    std::printf("# runtime %s\n", cv::getVersionString().c_str());
    std::printf("# provider core %s\n",
                provider(reinterpret_cast<void *>(&cv::getVersionString))
                    .c_str());
    std::printf("# provider pointPolygonTest %s\n",
                provider(reinterpret_cast<void *>(
                    static_cast<double (*)(cv::InputArray, cv::Point2f, bool)>(
                        &cv::pointPolygonTest))).c_str());
    std::printf("# provider contourArea %s\n",
                provider(reinterpret_cast<void *>(&cv::contourArea)).c_str());

    const poly tri_a = {{0.1f, 0.1f}, {4.3f, 0.2f}, {2.1f, 3.9f}};
    const poly tri_b = {{0.7f, -0.5f}, {3.9f, 2.2f}, {-0.4f, 2.8f}};
    both("tri_fractional", tri_a, tri_b);
    both("tri_fractional_ba", tri_b, tri_a);
    both("tri_tenths", {{0.1f, 0.1f}, {0.5f, 0.1f}, {0.3f, 0.5f}},
         {{0.2f, 0.2f}, {0.6f, 0.2f}, {0.4f, 0.6f}});
    both("square_overlap", box(0.3f, 0.2f, 2.3f, 2.3f),
         box(1.0f, 0.65f, 2.3f, 2.3f));
    for (int w = 0; w < 4; ++w) {
        const poly a = (w & 1) ? reversed(tri_a) : tri_a;
        const poly b = (w & 2) ? reversed(tri_b) : tri_b;
        both("winding_" + std::to_string(w), a, b);
    }
    const poly outer = box(0.0f, 0.0f, 10.0f, 10.0f);
    const poly inner = box(2.3f, 2.3f, 3.1f, 3.1f);
    both("nested_outer_first", outer, inner);
    both("nested_inner_first", inner, outer);
    both("nested_reversed", reversed(outer), inner);
    both("disjoint", box(0.0f, 0.0f, 1.0f, 1.0f), box(5.1f, 5.1f, 1.0f, 1.0f));
    both("shared_edge", box(0.0f, 0.0f, 1.0f, 1.0f),
         box(1.0f, 0.0f, 1.0f, 1.0f));
    both("shared_edge_partial", box(0.0f, 0.0f, 1.0f, 1.0f),
         box(1.0f, 0.25f, 1.0f, 0.5f));
    both("vertex_contact", box(0.0f, 0.0f, 1.0f, 1.0f),
         box(1.0f, 1.0f, 1.0f, 1.0f));
    const poly hex_a = {{-15767146.0f, -1608888.0f}, {-2320318.0f, -15678251.0f},
                        {15750659.0f, 1762998.0f}, {15604050.0f, 2775796.0f},
                        {13860112.0f, 7686919.0f}, {-4538847.0f, 15185200.0f}};
    const poly hex_b = {{-15767147.0f, -1608887.0f}, {-2320318.0f, -15678249.0f},
                        {15750662.0f, 1762996.0f}, {15604050.0f, 2775793.0f},
                        {13860114.0f, 7686922.0f}, {-4538847.0f, 15185197.0f}};
    both("recovered_hexagons", hex_a, hex_b);
    both("recovered_hexagons_ba", hex_b, hex_a);
    both("thin", {{0.0f, 0.0f}, {100.0f, 0.0f}, {100.0f, 0.01f}, {0.0f, 0.01f}},
         box(40.0f, -1.0f, 20.0f, 2.0f));
    both("large", box(5.0e8f, 5.0e8f, 1048576.0f, 1048576.0f),
         box(5.0e8f + 524288.0f, 5.0e8f, 1048576.0f, 1048576.0f));
    both("edge_of_envelope", box(1073741824.0f - 512.0f, 0.0f, 512.0f, 512.0f),
         box(1073741824.0f - 768.0f, 256.0f, 512.0f, 512.0f));
    for (int i = 0; i < 24; ++i) {
        const int n = 3 + (i * 7) % 29;
        const int m = 3 + (i * 11) % 31;
        const double r1 = 5.0 + i * 3.7, r2 = 4.0 + i * 2.9;
        both("ngon_" + std::to_string(n) + "_" + std::to_string(m) + "_"
                 + std::to_string(i),
             ngon(n, 0.1 * i, 0.0, r1, 0.013 * i),
             ngon(m, 0.37 * i, -0.21 * i, r2, 0.101 * i));
    }
    // Boundaries that cross: similar radii, offset centers.
    for (int i = 0; i < 40; ++i) {
        const int n = 3 + (i * 5) % 37;
        const int m = 3 + (i * 13) % 41;
        const double r = 10.0 + 0.7 * i;
        both("cross_" + std::to_string(n) + "_" + std::to_string(m) + "_"
                 + std::to_string(i),
             ngon(n, 0.0, 0.0, r, 0.017 * i),
             ngon(m, 0.45 * r, 0.2 * r * ((i % 3) - 1), r * (0.8 + 0.01 * i),
                  0.23 * i));
    }
    return 0;
}
