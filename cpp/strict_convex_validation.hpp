// Private input validator for the extended Float32 convex intersection.
// Written for this project (no upstream code). The shim runs it before
// convex_intersection_compat.hpp, so a direct C caller cannot bypass it.
//
// Accepted polygon (binary32 input, n vertices):
//   * 3 <= n <= strict_convex_max_vertices;
//   * every coordinate finite with magnitude at most 2**30;
//   * for EVERY directed edge (p[i], p[i+1]) and EVERY other vertex p[k],
//     the orientation is provably nonzero (see exact_sign) and has one sign
//     for the whole polygon.
//
// Why that is strict convexity with a single traversal: a vertex k strictly
// on one side of the line through edge (i, i+1), for all k, makes that line
// a supporting line meeting the vertex set exactly in {p[i], p[i+1]}. So
// every edge joins two ADJACENT hull vertices and every vertex is a hull
// vertex. The n directed edges are n distinct hull edges (a repeated point
// would give an orientation of exactly zero), all of one rotational sense,
// and the hull has exactly n edges, so the contour is the hull boundary
// visited once. Repeated vertices, redundant collinear vertices, concave
// corners, bowties, stars and repeated traversals all produce a zero or a
// mixed-sign orientation.
//
// Conditioning (a policy, not a proof of convergence): the compatibility
// engine's area_sign treats |area| <= 1e-5 as zero, from binary32 coordinate
// differences. Each (edge, vertex) orientation is therefore also computed the
// way the engine computes it and must have the same sign and a magnitude
// above strict_convex_min_orientation, 10 times that tolerance. Polygons
// with features below that scale are rejected, never guessed at. Orientation
// tests BETWEEN the two polygons cannot be checked per polygon; that is
// covered only by the engine's own controlled non-convergence status.
//
// Cost: O(n**2), about 1.7e7 orientation evaluations at n = 4096.
// Execution time depends on hardware, compiler, and input geometry.
// This count is not a portable wall-clock bound; see qualification timings.
#ifndef OPENCV_GEOMETRY_STRICT_CONVEX_VALIDATION_HPP
#define OPENCV_GEOMETRY_STRICT_CONVEX_VALIDATION_HPP

#include <opencv2/core.hpp>
#include <cmath>
#include <cstdint>

namespace opencv_geometry_compat {

constexpr std::int64_t strict_convex_max_vertices = 4096;
constexpr float strict_convex_max_magnitude = 1073741824.0f;  // 2**30
constexpr double strict_convex_min_orientation = 1.0e-4;

enum class strict_convex_verdict {
    ok = 0,
    bad_count,
    non_finite,
    out_of_envelope,
    not_strictly_convex,
    degenerate_or_ambiguous,
    ill_conditioned
};

namespace strict_detail {

// Sign of the orientation of (a, b, c), or 0 when it is zero or cannot be
// decided. Shewchuk's error filter for the naive double formula: each
// binary32 coordinate is exact in binary64; the subtractions and products
// are rounded; with eps = 2**-53 the computed det differs from the true
// determinant by at most (3 + 16 eps) eps (|detleft| + |detright|). Only a
// det beyond that bound has a proven sign. No overflow: magnitudes are at
// most 2**30. No underflow concern: the bound is relative and a nonzero
// binary32 difference product is at least 2**-298, far above 2**-1022.
inline int exact_sign(const cv::Point2f& a, const cv::Point2f& b,
                      const cv::Point2f& c)
{
    const double eps = 1.1102230246251565e-16;  // 2**-53
    const double bound_factor = (3.0 + 16.0 * eps) * eps;
    const double detleft = ((double)a.x - c.x) * ((double)b.y - c.y);
    const double detright = ((double)a.y - c.y) * ((double)b.x - c.x);
    const double det = detleft - detright;
    const double bound =
        bound_factor * (std::fabs(detleft) + std::fabs(detright));
    if (det > bound) return 1;
    if (-det > bound) return -1;
    return 0;
}

// The engine's area_sign value for (a, b, c) before its tolerance:
// binary32 differences, binary64 products. Mirrors
// convex_intersection_compat.hpp.
inline double engine_orientation(const cv::Point2f& a, const cv::Point2f& b,
                                 const cv::Point2f& c)
{
    return (b.x - a.x) * (double)(c.y - a.y)
         - (c.x - a.x) * (double)(b.y - a.y);
}

inline int sign_of(double v) { return v > 0 ? 1 : v < 0 ? -1 : 0; }

}  // namespace strict_detail

inline strict_convex_verdict validate_strictly_convex_f32(
    const cv::Point2f* p, std::int64_t n)
{
    using namespace strict_detail;
    if (n < 3 || n > strict_convex_max_vertices || p == nullptr)
        return strict_convex_verdict::bad_count;
    for (std::int64_t i = 0; i < n; ++i) {
        if (!std::isfinite(p[i].x) || !std::isfinite(p[i].y))
            return strict_convex_verdict::non_finite;
        if (std::fabs(p[i].x) > strict_convex_max_magnitude
            || std::fabs(p[i].y) > strict_convex_max_magnitude)
            return strict_convex_verdict::out_of_envelope;
    }
    int polygon_sign = 0;
    for (std::int64_t i = 0; i < n; ++i) {
        const std::int64_t j = (i + 1) % n;
        const std::int64_t l = (i + 2) % n;
        for (std::int64_t k = 0; k < n; ++k) {
            if (k == i || k == j) continue;
            const int s = exact_sign(p[i], p[j], p[k]);
            if (s == 0) return strict_convex_verdict::degenerate_or_ambiguous;
            if (polygon_sign == 0)
                polygon_sign = s;
            else if (s != polygon_sign)
                return strict_convex_verdict::not_strictly_convex;
            const double e = engine_orientation(p[i], p[j], p[k]);
            if (sign_of(e) != s
                || std::fabs(e) <= strict_convex_min_orientation)
                return strict_convex_verdict::ill_conditioned;
        }
        // The engine also evaluates the turn between consecutive edge
        // vectors, formed from binary32 differences.
        const cv::Point2f ea = p[j] - p[i], eb = p[l] - p[j];
        const double turn = ea.x * (double)eb.y - eb.x * (double)ea.y;
        if (sign_of(turn) != polygon_sign
            || std::fabs(turn) <= strict_convex_min_orientation)
            return strict_convex_verdict::ill_conditioned;
    }
    return strict_convex_verdict::ok;
}

inline const char* strict_convex_message(strict_convex_verdict v)
{
    switch (v) {
    case strict_convex_verdict::ok: return "ok";
    case strict_convex_verdict::bad_count:
        return "polygon needs 3 to 4096 vertices";
    case strict_convex_verdict::non_finite:
        return "polygon coordinates must be finite";
    case strict_convex_verdict::out_of_envelope:
        return "polygon coordinate magnitude exceeds 2**30";
    case strict_convex_verdict::not_strictly_convex:
        return "polygon is not strictly convex traversed once";
    case strict_convex_verdict::degenerate_or_ambiguous:
        return "polygon has repeated, collinear or numerically ambiguous "
               "vertices";
    case strict_convex_verdict::ill_conditioned:
        return "polygon features are below the conditioning limit of 1e-4";
    }
    return "invalid polygon";
}

}  // namespace opencv_geometry_compat
#endif
