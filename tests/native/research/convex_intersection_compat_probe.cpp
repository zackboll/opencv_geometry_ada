// Research only (Task 027A). NOT built by alr, AUnit or run_native_tests.sh
// (that script compiles tests/native/*.cpp only; this file is in research/).
// Exercises the private compatibility algorithm in
// cpp/convex_intersection_compat.hpp, one named case per process.
//
//   probe list                 names of all cases
//   probe <case>               compat algorithm; exit 0 = expectation met
//   probe native <case>        original cv::intersectConvexConvex on the same
//                              input (may corrupt the heap on 4.6/4.10)
//
// Identity lines are printed first: compile-time CV_VERSION, runtime
// cv::getVersionString(), and the shared object defining it. Output is
// small and bounded. Exit: 0 met, 1 expectation failed, 10 cv::Exception,
// 11 std::exception, 64 usage. A signal or hang is classified by the
// controlling script. The independent reference is a binary64
// Sutherland-Hodgman clip, not an OpenCV call.
#include "../../../cpp/convex_intersection_compat.hpp"
#include <dlfcn.h>
#include <climits>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <string>

using namespace opencv_geometry_compat;
using Poly = std::vector<cv::Point2f>;

namespace {

double signed_area(const Poly& p)
{
    double a = 0;
    for (size_t i = 0; i < p.size(); ++i) {
        const cv::Point2f &u = p[i], &v = p[(i + 1) % p.size()];
        a += (double)u.x * v.y - (double)u.y * v.x;
    }
    return a * 0.5;
}

// Independent reference: area of subject clipped by a convex clip, binary64.
double reference_area(Poly subject, Poly clip)
{
    if (signed_area(subject) < 0) std::reverse(subject.begin(), subject.end());
    if (signed_area(clip) < 0) std::reverse(clip.begin(), clip.end());
    using P = std::pair<double, double>;
    std::vector<P> out;
    for (auto& s : subject) out.push_back({s.x, s.y});
    for (size_t i = 0; i < clip.size() && !out.empty(); ++i) {
        P a{clip[i].x, clip[i].y};
        P b{clip[(i + 1) % clip.size()].x, clip[(i + 1) % clip.size()].y};
        auto side = [&](const P& p) {
            return (b.first - a.first) * (p.second - a.second)
                 - (b.second - a.second) * (p.first - a.first);
        };
        std::vector<P> in = out;
        out.clear();
        for (size_t j = 0; j < in.size(); ++j) {
            P c = in[j], d = in[(j + 1) % in.size()];
            double sc = side(c), sd = side(d);
            if (sc >= 0) out.push_back(c);
            if ((sc > 0 && sd < 0) || (sc < 0 && sd > 0)) {
                double t = sc / (sc - sd);
                out.push_back({c.first + t * (d.first - c.first),
                               c.second + t * (d.second - c.second)});
            }
        }
    }
    double a = 0;
    for (size_t i = 0; i < out.size(); ++i) {
        const P &u = out[i], &v = out[(i + 1) % out.size()];
        a += u.first * v.second - u.second * v.first;
    }
    return std::fabs(a) * 0.5;
}

Poly ngon(int n, double cx, double cy, double r, double phase = 0)
{
    Poly v;
    for (int i = 0; i < n; ++i) {
        double a = 2.0 * CV_PI * i / n + phase;
        v.emplace_back((float)(cx + r * std::cos(a)),
                       (float)(cy + r * std::sin(a)));
    }
    return v;
}

Poly rev(Poly p) { std::reverse(p.begin(), p.end()); return p; }
Poly sq(float x, float y, float s)
{
    return {{x, y}, {x + s, y}, {x + s, y + s}, {x, y + s}};
}

// area_ref: compare area with the independent reference.
// count_in: vertex count within [lo, hi] and status ok.
// safe_only: any controlled status; never a refused write.
// status_is: exactly the wanted status.
struct Case {
    std::string name;
    Poly left, right;
    bool nested = true;
    enum Kind { area_ref, count_in, safe_only, status_is } kind = area_ref;
    int lo = 0, hi = 0;
    convex_intersection_status want = convex_intersection_status::ok;
    Poly expect;   // when non-empty: exact output vertices, in order
};

Case mk(const char* name, Poly l, Poly r, Case::Kind k = Case::area_ref,
        bool nested = true, int lo = 0, int hi = 0)
{
    Case c;
    c.name = name;
    c.left = std::move(l);
    c.right = std::move(r);
    c.kind = k;
    c.nested = nested;
    c.lo = lo;
    c.hi = hi;
    return c;
}

std::vector<Case> cases()
{
    std::vector<Case> c;
    Poly t1{{0.1f, 0.1f}, {4.3f, 0.2f}, {2.1f, 3.9f}};
    Poly t2{{0.7f, -0.5f}, {3.9f, 2.2f}, {-0.4f, 2.8f}};
    // Kinds: area_ref requires status ok, a vertex count in [lo, hi] (when
    // hi > 0), the reference area, and an output whose own shoelace area
    // equals the reported area. count_in requires status ok, a count in
    // [lo, hi] and area 0. safe_only accepts any controlled status except a
    // refused write or an envelope rejection. status_is pins the status.
    c.push_back(mk("tri_fractional", t1, t2, Case::area_ref, true, 6, 6));
    c.push_back(mk("sq_fractional", sq(0.3f, 0.2f, 2.3f),
                   sq(1.0f, 0.65f, 2.3f), Case::area_ref, true, 4, 4));
    c.push_back(mk("decimal_0_1_tri",
                   {{0.1f, 0.1f}, {0.3f, 0.1f}, {0.2f, 0.3f}},
                   {{0.2f, 0.1f}, {0.4f, 0.1f}, {0.3f, 0.3f}},
                   Case::area_ref, true, 3, 3));
    c.push_back(mk("decimal_0_1_sq", sq(0.1f, 0.1f, 0.3f),
                   sq(0.2f, 0.2f, 0.3f), Case::area_ref, true, 4, 4));
    for (int w = 0; w < 4; ++w)
        c.push_back(mk(("winding_" + std::to_string(w)).c_str(),
                       (w & 1) ? rev(t1) : t1, (w & 2) ? rev(t2) : t2,
                       Case::area_ref, true, 6, 6));
    c.push_back(mk("disjoint_nr1", sq(0, 0, 1), sq(5, 5, 1),
                   Case::count_in, true, 0, 0));
    c.push_back(mk("nested_true", sq(0, 0, 10), sq(2.5f, 2.5f, 3),
                   Case::area_ref, true, 4, 4));
    c.push_back(mk("nested_false", sq(0, 0, 10), sq(2.5f, 2.5f, 3),
                   Case::count_in, false, 0, 0));
    c.push_back(mk("nested_swapped", sq(2.5f, 2.5f, 3), sq(0, 0, 10),
                   Case::area_ref, true, 4, 4));
    // n + m = 160 > 136: the native AutoBuffer is on the heap. Normal loop
    // exit with nothing written (raw 1), so the native tail runs with
    // nr == 1 and reads result0[-1], which is fp2[m-1] in the SAME block.
    c.push_back(mk("nested_heap_buffer", ngon(80, 0, 0, 100),
                   ngon(80, 1, 2, 50, 0.01), Case::area_ref, true, 80, 80));
    // Disjoint with non-parallel edges: the loop should end normally with
    // nothing written rather than through the separated-parallel return.
    c.push_back(mk("disjoint_normal_exit",
                   {{0, 0}, {3, 0.5f}, {1, 2.7f}},
                   {{10, 10}, {13.3f, 10.2f}, {11.1f, 13}},
                   Case::count_in, true, 0, 0));
    c.push_back(mk("disjoint_normal_exit_heap", ngon(80, 0, 0, 10),
                   ngon(80, 100, 100, 10, 0.01), Case::count_in, true, 0, 0));
    // Contact cases (area 0): the early-return path hands back its raw
    // vertices (a shared segment, a point, ...). The exact counts below pin
    // the observed behavior of this implementation; native 4.10 returns one
    // more vertex because it keeps the sentinel. They are not a claim that
    // the vertices are a meaningful polygon.
    c.push_back(mk("shared_edge", sq(0, 0, 1), sq(1, 0, 1), Case::count_in,
                   true, 3, 3));
    c.push_back(mk("vertex_contact", sq(0, 0, 1), sq(1, 1, 1),
                   Case::count_in, true, 1, 1));
    c.push_back(mk("two_vertex_contact", sq(0, 0, 1), sq(1, 0.25f, 1),
                   Case::count_in, true, 2, 2));
    c.push_back(mk("near_parallel", {{0, 0}, {1000, 0.001f}, {0, 0.002f}},
                   {{0, 0.0005f}, {1000, 0.0015f}, {0, 0.0025f}},
                   Case::area_ref, true, 3, 3));
    // Geometry below the absolute 1e-5 orientation tolerance collapses to
    // area 0 by design of the upstream predicate; native does the same.
    c.push_back(mk("tiny_coordinates", sq(1e-20f, 1e-20f, 3e-20f),
                   sq(2e-20f, 2e-20f, 3e-20f), Case::count_in, true, 0, 3));
    c.push_back(mk("subnormal_coordinates", sq(1e-44f, 1e-44f, 3e-44f),
                   sq(2e-44f, 2e-44f, 3e-44f), Case::count_in, true, 0, 3));
    c.push_back(mk("large_coordinates",
                   sq(536870912.f, 536870912.f, 1048576.f),
                   sq(536870912.f + 524288.f, 536870912.f + 262144.f,
                      1048576.f), Case::area_ref, true, 4, 4));
    c.push_back(mk("signed_zero", {{-0.f, 0.f}, {2, -0.f}, {2, 2}, {0, 2}},
                   sq(1, 1, 2), Case::area_ref, true, 4, 4));
    c.push_back(mk("ngon_40_40", ngon(40, 0, 0, 100),
                   ngon(40, 3, 2, 100, 0.07), Case::area_ref, true, 40, 80));
    // Recovered input (AUnit Exact_Difference_Spans). Observed on 4.10.0
    // native: 14 vertices; on 4.13.0 native and here: the 12 vertices below.
    // The expectation is the exact compat output, status ok, count 12 and
    // area within 1e-6 of the independent reference (observed 2.6e-8).
    Case hex = mk("integer_hexagon_reproducer",
        {{-15767146, -1608888}, {-2320318, -15678251}, {15750659, 1762998},
         {15604050, 2775796}, {13860112, 7686919}, {-4538847, 15185200}},
        {{-15767147, -1608887}, {-2320318, -15678249}, {15750662, 1762996},
         {15604050, 2775793}, {13860114, 7686922}, {-4538847, 15185197}},
        Case::area_ref, true, 12, 12);
    hex.expect = {{-10668174.f, 6017608.5f}, {-15767146.f, -1608888.f},
                  {-15462922.f, -1927196.75f}, {-2320318.f, -15678249.f},
                  {2921097.75f, -10619485.f}, {15750659.f, 1762998.f},
                  {15624296.f, 2635932.75f}, {15604050.f, 2775793.f},
                  {15154281.f, 4042394.25f}, {13860112.f, 7686919.f},
                  {3560384.5f, 11884453.f}, {-4538847.f, 15185197.f}};
    c.push_back(hex);
    // The original 62/61-vertex pair was not recorded anywhere recoverable;
    // these regular n-gons are stand-ins and do NOT reproduce it.
    c.push_back(mk("ngon_62_61_standin_r1000", ngon(62, 0, 0, 1000),
                   ngon(61, 3, 2, 1000, 0.01), Case::safe_only));
    c.push_back(mk("ngon_62_61_standin_r1", ngon(62, 0, 0, 1),
                   ngon(61, 0.003, 0.002, 1, 0.01), Case::safe_only));
    c.push_back(mk("nonconvex_star",
                   {{0, 3}, {1, 1}, {3, 0}, {1, -1}, {0, -3}, {-1, -1},
                    {-3, 0}, {-1, 1}},
                   sq(-1, -1, 2), Case::safe_only));
    c.push_back(mk("bowtie", {{0, 0}, {2, 2}, {2, 0}, {0, 2}},
                   sq(0.5f, 0.5f, 1), Case::safe_only));
    Case big = mk("out_of_envelope", sq(0, 0, 1), sq(2e9f, 0, 1),
                  Case::status_is);
    big.want = convex_intersection_status::invalid_input;
    c.push_back(big);
    Case nan = mk("nonfinite", sq(0, 0, 1), {{0, 0}, {NAN, 1}, {1, 1}},
                  Case::status_is);
    nan.want = convex_intersection_status::invalid_input;
    c.push_back(nan);
    return c;
}


// Loaded-library identity. The compile-time version (headers) and the
// runtime version (cv::getVersionString, from the loaded Core) are reported
// separately. The library that actually provides each symbol is found with
// dladdr and checked on its own; the version of imgproc/geometry is never
// inferred from Core's. A mismatch returns false and the process exits 65
// before any case runs, so evidence from a wrong library cannot be recorded.
//
// Checks: (1) runtime version string equals the compile-time CV_VERSION;
// (2) cv::getVersionString comes from a libopencv_core object; (3) the
// other symbols come from a libopencv_ object that is not Core (imgproc in
// 4.x, geometry in 5.x); (4) each object's symlink-resolved file name ends
// in ".so.<CV_VERSION>" (e.g. libopencv_imgproc.so.4.10.0), so the file
// itself, not just Core, carries the expected version; (5) all objects are
// in one directory and, when T027_EXPECT_LIBDIR is set, in that directory.
struct SymbolHome {
    std::string symbol, path, base, dir;
};

SymbolHome home_of(const char* symbol, const void* address)
{
    SymbolHome h;
    h.symbol = symbol;
    Dl_info info{};
    if (address && dladdr(address, &info) && info.dli_fname) {
        char resolved[4096];
        h.path = realpath(info.dli_fname, resolved) ? resolved : info.dli_fname;
        size_t slash = h.path.rfind('/');
        h.dir = slash == std::string::npos ? "" : h.path.substr(0, slash);
        h.base = slash == std::string::npos ? h.path : h.path.substr(slash + 1);
    }
    return h;
}

bool identity(bool need_native)
{
    using PolyTest = double (*)(cv::InputArray, cv::Point2f, bool);
    using Area = double (*)(cv::InputArray, bool);
    using Isect = float (*)(cv::InputArray, cv::InputArray, cv::OutputArray,
                            bool);
    PolyTest ppt = &cv::pointPolygonTest;
    Area area = &cv::contourArea;
    Isect isect = &cv::intersectConvexConvex;
    using VerFn = cv::String (*)();
    VerFn ver = &cv::getVersionString;

    std::vector<SymbolHome> homes;
    homes.push_back(home_of("cv::getVersionString",
                            reinterpret_cast<const void*>(ver)));
    homes.push_back(home_of("cv::pointPolygonTest",
                            reinterpret_cast<const void*>(ppt)));
    homes.push_back(home_of("cv::contourArea",
                            reinterpret_cast<const void*>(area)));
    if (need_native)
        homes.push_back(home_of("cv::intersectConvexConvex",
                                reinterpret_cast<const void*>(isect)));

    const std::string runtime = cv::getVersionString();
    std::printf("compile_version %s\nruntime_version %s\n", CV_VERSION,
                runtime.c_str());
    bool ok = runtime == CV_VERSION;
    if (!ok) std::printf("IDENTITY REJECTED: runtime != compile version\n");
    const std::string suffix = std::string(".so.") + CV_VERSION;
    const char* want_dir = std::getenv("T027_EXPECT_LIBDIR");
    for (size_t i = 0; i < homes.size(); ++i) {
        const SymbolHome& h = homes[i];
        std::printf("provider %s %s\n", h.symbol.c_str(),
                    h.path.empty() ? "?" : h.path.c_str());
        // Exact module and exact version suffix: the resolved file name must
        // be libopencv_<module><suffix> with nothing after the version.
        const std::string module = i == 0 ? "core"
            : (CV_VERSION_MAJOR >= 5 ? "geometry" : "imgproc");
        const std::string exact = "libopencv_" + module + suffix;
        const bool good = !h.path.empty()
            && h.base == exact
            && h.dir == homes[0].dir
            && (!want_dir || h.dir == want_dir);
        if (!good) {
            std::printf("IDENTITY REJECTED: %s\n", h.symbol.c_str());
            ok = false;
        }
    }
    return ok;
}

const char* status_name(convex_intersection_status s)
{
    switch (s) {
    case convex_intersection_status::ok: return "ok";
    case convex_intersection_status::non_convergence: return "non_convergence";
    case convex_intersection_status::invalid_input: return "invalid_input";
    case convex_intersection_status::numeric_failure: return "numeric_failure";
    case convex_intersection_status::internal_bound: return "internal_bound";
    }
    return "?";
}

int run_compat(const Case& c)
{
    auto r = intersect_convex_convex_f32(c.left, c.right, c.nested);
    double ref = reference_area(c.left, c.right);
    std::printf("status %s count %zu area %.9g reference %.9g "
                "iterations %lld max_writes %lld capacity %lld raw %lld "
                "early %d nested %d\n",
                status_name(r.status), r.vertices.size(), (double)r.area, ref,
                (long long)r.diagnostics.iterations,
                (long long)r.diagnostics.max_writes_per_iteration,
                (long long)r.diagnostics.capacity,
                (long long)r.diagnostics.raw_count,
                (int)r.diagnostics.early_return,
                (int)r.diagnostics.nested_path);
    for (size_t i = 0; i < r.vertices.size() && i < 16; ++i)
        std::printf("  v %.9g %.9g\n", (double)r.vertices[i].x,
                    (double)r.vertices[i].y);
    if (r.status == convex_intersection_status::internal_bound) return 1;
    const int cnt = (int)r.vertices.size();
    auto fail = [](const char* why) {
        std::printf("EXPECTATION FAILED: %s\n", why);
        return 1;
    };
    switch (c.kind) {
    case Case::status_is:
        return r.status == c.want ? 0 : fail("status differs");
    case Case::safe_only:
        if (r.status == convex_intersection_status::invalid_input)
            return fail("unexpected envelope rejection");
        return 0;
    case Case::count_in:
        if (r.status != convex_intersection_status::ok)
            return fail("status not ok");
        if (cnt < c.lo || cnt > c.hi) return fail("count out of range");
        if (r.area != 0.f) return fail("area not zero");
        return 0;
    case Case::area_ref: {
        if (r.status != convex_intersection_status::ok)
            return fail("status not ok");
        if (c.hi > 0 && (cnt < c.lo || cnt > c.hi))
            return fail("count out of range");
        double tol = 2e-5 * std::max(ref, (double)r.area) + 1e-30;
        if (std::fabs((double)r.area - ref) > tol)
            return fail("area differs from reference");
        // The returned polygon must itself have the reported area.
        double own = std::fabs(signed_area(r.vertices));
        if (std::fabs(own - (double)r.area)
            > 2e-5 * std::max(own, (double)r.area) + 1e-30)
            return fail("output polygon area differs from reported area");
        if (!c.expect.empty()) {
            if (r.vertices.size() != c.expect.size())
                return fail("vertex count differs from expectation");
            for (size_t i = 0; i < c.expect.size(); ++i)
                if (r.vertices[i] != c.expect[i])
                    return fail("vertex differs from expectation");
            if (std::fabs((double)r.area - ref) > 1e-6 * ref)
                return fail("hexagon area outside 1e-6");
        }
        return 0;
    }
    }
    return 1;
}

int run_native(const Case& c)
{
    std::vector<cv::Point2f> out;
    float area = cv::intersectConvexConvex(c.left, c.right, out, c.nested);
    std::printf("native area %.9g count %zu\n", (double)area, out.size());
    for (size_t i = 0; i < out.size() && i < 16; ++i)
        std::printf("  v %.9g %.9g\n", (double)out[i].x, (double)out[i].y);
    return 0;
}

// Direct segment case: a horizontal edge of length 1e9 at y = 1e3 against a
// nearly parallel edge (0,0)-(1e3,1e-40). The binary64 denominator is about
// 1e-31 and s about 1e37, so the unused intersection coordinate a.x + s*dx
// is about 1e46, far beyond FLT_MAX. "segment_extreme" runs the hardened
// function, which range-tests s and t before it converts anything.
// "segment_extreme_upstream" reproduces the upstream order (convert first)
// for observation only. -fsanitize=float-cast-overflow covers
// floating-point to INTEGER conversions; it does not report a double to
// float narrowing, so a silent sanitizer run here proves nothing about that
// cast. On this target (IEEE binary32 with infinity) the observed result is
// +inf. Whether the C++ standard calls such a conversion undefined depends
// on whether the target type can represent the value; this probe does not
// rely on that question. The hardened code avoids the conversion by explicit
// finite and range checks, which stay in place.
int run_segment(bool upstream)
{
    cv::Point2f a(0.f, 1e3f), b(1e9f, 1e3f), c(0.f, 0.f), d(1e3f, 1e-40f);
    if (upstream) {
        double denom = ((double)a.x - b.x) * ((double)d.y - c.y)
                     - ((double)a.y - b.y) * ((double)d.x - c.x);
        double num = ((double)d.y - a.y) * ((double)a.x - c.x)
                   + ((double)a.x - d.x) * ((double)a.y - c.y);
        double s = num / denom;
        volatile float px = (float)(a.x + s * ((double)b.x - a.x));
        std::printf("upstream order: s %.9g cast %g\n", s, (double)px);
        return 0;
    }
    cv::Point2f p(-7.f, -7.f), q(-7.f, -7.f);
    bool numeric = false;
    auto code = convex_detail::intersect_line_segments(a, b, c, d, p, q,
                                                      numeric);
    std::printf("code %d numeric %d p %g %g\n", (int)code, (int)numeric,
                (double)p.x, (double)p.y);
    return (code == convex_detail::LS_NO_INTERSECTION && !numeric
            && p.x == -7.f) ? 0 : 1;
}

// Seeded sweep: random convex n-gons (binary32-rounded, so only nearly
// convex at large n) with fractional centers and radii. Reports the worst
// writes per iteration, refused writes, non-ok statuses and the largest
// relative area deviation from the independent reference. Deterministic.
int run_sweep(unsigned seed, int count)
{
    unsigned long long s = seed * 2654435761ULL + 1;
    auto next = [&]() {
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        return (double)(s >> 11) / 9007199254740992.0;
    };
    long long maxw = 0, bound = 0, nonok = 0, early = 0, nested = 0;
    long long compared = 0, tiny_ref = 0;
    double worst = 0;
    for (int i = 0; i < count; ++i) {
        int n = 3 + (int)(next() * 70), m = 3 + (int)(next() * 70);
        double r1 = 0.05 + next() * 500, r2 = 0.05 + next() * 500;
        double cx = (next() - 0.5) * r1, cy = (next() - 0.5) * r1;
        Poly a = ngon(n, 0, 0, r1, next()), b = ngon(m, cx, cy, r2, next());
        if (next() < 0.5) a = rev(a);
        auto r = intersect_convex_convex_f32(a, b, true);
        maxw = std::max<long long>(maxw, r.diagnostics.max_writes_per_iteration);
        bound += r.status == convex_intersection_status::internal_bound;
        nonok += r.status != convex_intersection_status::ok;
        early += r.diagnostics.early_return;
        nested += r.diagnostics.nested_path;
        // Only status-ok, non-early results enter the accuracy figure; every
        // other outcome is counted in its own bucket and, for the accuracy
        // claim, a non-ok status is a failure of the sweep, not a skip.
        if (r.status != convex_intersection_status::ok) continue;
        if (r.diagnostics.early_return) continue;
        double ref = reference_area(a, b);
        if (ref <= 1e-12) { ++tiny_ref; continue; }
        ++compared;
        worst = std::max(worst, std::fabs((double)r.area - ref) / ref);
    }
    const bool accuracy_ok = nonok == 0 && compared > 0 && worst <= 2e-5;
    std::printf("sweep seed %u pairs %d compared %lld non_ok %lld "
                "early_skipped %lld tiny_ref_skipped %lld nested %lld "
                "max_writes %lld refused %lld worst_rel_area %.3g "
                "accuracy_claim %s\n", seed, count, compared, nonok, early,
                tiny_ref, nested, maxw, bound, worst,
                accuracy_ok ? "SUPPORTED" : "NOT_SUPPORTED");
    return bound == 0 && maxw <= 3 && accuracy_ok ? 0 : 1;
}

// Chaos sweep: random NON-convex, possibly self-intersecting polygons with
// small integer-grid or fractional coordinates, which violate the caller's
// convexity obligation. Only the safety properties are checked: no refused
// write, writes per iteration at most 3, raw count within capacity, and a
// controlled status. Counts non-convergence so that path is shown reachable.
int run_chaos(unsigned seed, int count)
{
    unsigned long long s = seed * 2654435761ULL + 7;
    auto next = [&]() {
        s = s * 6364136223846793005ULL + 1442695040888963407ULL;
        return (double)(s >> 11) / 9007199254740992.0;
    };
    long long maxw = 0, bound = 0, nonconv = 0, numeric = 0, other = 0;
    long long over_capacity = 0;
    for (int i = 0; i < count; ++i) {
        auto poly = [&]() {
            int n = 3 + (int)(next() * 9);
            bool grid = next() < 0.5;
            Poly p;
            for (int k = 0; k < n; ++k) {
                double x = next() * 8, y = next() * 8;
                if (grid) { x = std::floor(x); y = std::floor(y); }
                p.emplace_back((float)x, (float)y);
            }
            return p;
        };
        Poly a = poly(), b = poly();
        auto r = intersect_convex_convex_f32(a, b, next() < 0.5);
        maxw = std::max<long long>(maxw, r.diagnostics.max_writes_per_iteration);
        over_capacity += r.diagnostics.raw_count > r.diagnostics.capacity;
        switch (r.status) {
        case convex_intersection_status::ok: break;
        case convex_intersection_status::non_convergence: ++nonconv; break;
        case convex_intersection_status::internal_bound: ++bound; break;
        case convex_intersection_status::numeric_failure: ++numeric; break;
        default: ++other;
        }
    }
    std::printf("chaos seed %u count %d max_writes %lld refused %lld "
                "over_capacity %lld non_convergence %lld numeric %lld "
                "other %lld\n", seed, count, maxw, bound, over_capacity,
                nonconv, numeric, other);
    return bound == 0 && over_capacity == 0 && maxw <= 3 ? 0 : 1;
}

}  // namespace

int main(int argc, char** argv)
{
    if (argc == 2 && std::string(argv[1]) == "list") {
        for (auto& c : cases()) std::printf("%s\n", c.name.c_str());
        return 0;
    }
    const bool native = argc == 3 && std::string(argv[1]) == "native";
    if (argc == 4 && std::string(argv[1]) == "chaos") {
        if (!identity(false)) return 65;
        return run_chaos((unsigned)std::atoi(argv[2]), std::atoi(argv[3]));
    }
    if (argc == 4 && std::string(argv[1]) == "sweep") {
        if (!identity(false)) return 65;
        return run_sweep((unsigned)std::atoi(argv[2]), std::atoi(argv[3]));
    }
    if (argc == 2 && std::string(argv[1]) == "segment_extreme") {
        if (!identity(false)) return 65;
        return run_segment(false);
    }
    if (argc == 2 && std::string(argv[1]) == "segment_extreme_upstream") {
        if (!identity(false)) return 65;
        return run_segment(true);
    }
    if (!native && argc != 2) return 64;
    auto all = cases();
    const std::string want = native ? argv[2] : argv[1];
    if (!identity(native)) return 65;
    for (auto& c : all) {
        if (c.name != want) continue;
        try {
            return native ? run_native(c) : run_compat(c);
        } catch (const cv::Exception& e) {
            std::printf("cv::Exception %s\n", e.what());
            return 10;
        } catch (const std::exception& e) {
            std::printf("std::exception %s\n", e.what());
            return 11;
        }
    }
    return 64;
}
