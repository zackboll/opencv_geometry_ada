// Private hardened compatibility implementation of cv::intersectConvexConvex
// for CV_32F polygons. It is not exported itself. In the production library
// its only caller is the shim's
// opencv_geometry_intersect_convex_convex_extended_f32.
//
// Source: OpenCV modules/imgproc/src/geometry.cpp (modules/geometry/src in
// 5.x), functions areaSign, between, parallelInt, intersectLineSegments,
// inOut, advance, addSharedSeg, intersectConvexConvex_ and the
// post-processing of intersectConvexConvex.
//   Structure: tag 4.11.0 (commit 31b0eeea0b44b370fd0712312df4214d4ae1b158),
//     the first release with the bounded result_size algorithm (PR 25725).
//   intersectLineSegments: the binary64-difference expressions first present
//     in tag 4.12.0 (commit 49486f61fb25722cbcf586b7f4320921d46fb38e),
//     identical in 4.13.0, 4.14.0 and 5.0.0. This is a later numerical
//     implementation than 4.11.0 and is NOT bit-for-bit equivalent to
//     OpenCV 4.6, 4.10 or 4.11.
//
// Adaptations for private compilation: public OpenCV types and functions
// only (cv::Point2f, cv::pointPolygonTest, cv::contourArea); typed vectors
// instead of InputArray/OutputArray/AutoBuffer; flip() replaced by
// std::reverse (identical for a vertical flip of an N x 1 array); the unused
// locals of between() removed.
//
// Hardening (each is a departure from upstream, documented in
// docs/universal-float32-intersection.md):
//   1. Every scratch write goes through scratch::push, which refuses a write
//      beyond the allocated capacity and records the refusal.
//   2. result[-1] is scratch::last(), valid because the sentinel is written
//      first; result0[nr-2] is read only after nr > 1 is established.
//   3. The input envelope (finite, magnitude at most 2**30) and the counts
//      are checked in wide arithmetic before any allocation.
//   4. intersectLineSegments tests s and t before narrowing the intersection
//      point to float, so an unused out-of-range point is never converted,
//      and reports a non-finite intermediate instead of deciding on NaN.
//   5. Non-convergence and numeric failure are returned as a status.
//
// The upstream notices follow verbatim; THIRD_PARTY_NOTICES reproduces them
// for binary redistributions. OpenCV's file header:
/*M///////////////////////////////////////////////////////////////////////////////////////
//
//  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.
//
//  By downloading, copying, installing or using the software you agree to this license.
//  If you do not agree to this license, do not download, install,
//  copy or use the software.
//
//
//                        Intel License Agreement
//                For Open Source Computer Vision Library
//
// Copyright (C) 2000, Intel Corporation, all rights reserved.
// Third party copyrights are property of their respective owners.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//   * Redistribution's of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//   * Redistribution's in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//   * The name of Intel Corporation may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
//
// This software is provided by the copyright holders and contributors "as is" and
// any express or implied warranties, including, but not limited to, the implied
// warranties of merchantability and fitness for a particular purpose are disclaimed.
// In no event shall the Intel Corporation or contributors be liable for any direct,
// indirect, incidental, special, exemplary, or consequential damages
// (including, but not limited to, procurement of substitute goods or services;
// loss of use, data, or profits; or business interruption) however caused
// and on any theory of liability, whether in contract, strict liability,
// or tort (including negligence or otherwise) arising in any way out of
// the use of this software, even if advised of the possibility of such damage.
//
//M*/
//
// Joseph O'Rourke's notice, from the same OpenCV file:
/*
 This code is described in "Computational Geometry in C" (Second Edition),
 Chapter 7.  It is not written to be comprehensible without the
 explanation in that book.

 Written by Joseph O'Rourke.
 Last modified: December 1997
 Questions to orourke@cs.smith.edu.
 --------------------------------------------------------------------
 This code is Copyright 1997 by Joseph O'Rourke.  It may be freely
 redistributed in its entirety provided that this copyright notice is
 not removed.
 --------------------------------------------------------------------
 */

#ifndef OPENCV_GEOMETRY_CONVEX_INTERSECTION_COMPAT_HPP
#define OPENCV_GEOMETRY_CONVEX_INTERSECTION_COMPAT_HPP

#include <opencv2/core.hpp>
#if CV_VERSION_MAJOR >= 5
#include <opencv2/geometry.hpp>
#else
#include <opencv2/imgproc.hpp>
#endif
#include <algorithm>
#include <cfloat>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace opencv_geometry_compat {

enum class convex_intersection_status {
    ok = 0,
    non_convergence,   // bounded loop ended with too many vertices
    invalid_input,     // count or coordinate envelope violated
    numeric_failure,   // a required intermediate was not finite
    internal_bound     // a scratch write was refused (must be unreachable)
};

// Native allocation is 2 * (n + m) + 4 points in a signed int.
constexpr std::int64_t convex_intersection_max_input_count =
    (static_cast<std::int64_t>(INT32_MAX) - 4) / 2;

// pointPolygonTest applies cvRound to a float, defined only below 2**31.
constexpr float convex_intersection_max_magnitude = 1073741824.0f;  // 2**30

struct convex_intersection_diagnostics {
    std::int64_t iterations = 0;
    std::int64_t max_writes_per_iteration = 0;
    std::int64_t capacity = 0;     // scratch slots allocated
    std::int64_t raw_count = 0;    // scratch slots used, sentinel included
    bool early_return = false;     // overlap or separated-parallel exit
    bool nested_path = false;
};

struct convex_intersection_result {
    convex_intersection_status status = convex_intersection_status::ok;
    float area = 0.0f;
    std::vector<cv::Point2f> vertices;
    convex_intersection_diagnostics diagnostics;
};

namespace convex_detail {

enum in_flag { Pin, Qin, Unknown };

enum line_segment_intersection {
    LS_NO_INTERSECTION = 0,
    LS_SINGLE_INTERSECTION = 1,
    LS_OVERLAP = 2,
    LS_ENDPOINT_INTERSECTION = 3
};

// Bounded result storage. Slot 0 holds the sentinel from the start, so
// count >= 1 for the whole run and last() is always a written element.
struct scratch {
    std::vector<cv::Point2f> buf;
    std::size_t count = 0;
    bool overflow = false;
    bool numeric = false;

    void push(const cv::Point2f& p)
    {
        if (count >= buf.size()) {
            overflow = true;
            return;
        }
        buf[count++] = p;
    }
    const cv::Point2f& last() const { return buf[count - 1]; }
};

inline int area_sign(cv::Point2f a, cv::Point2f b, cv::Point2f c)
{
    static const double eps = 1e-5;
    double area2 = (b.x - a.x) * (double)(c.y - a.y)
                 - (c.x - a.x) * (double)(b.y - a.y);
    return area2 > eps ? 1 : area2 < -eps ? -1 : 0;
}

// True iff c lies on the closed segment ab; c is already known collinear.
inline bool between(cv::Point2f a, cv::Point2f b, cv::Point2f c)
{
    if (a.x != b.x)
        return ((a.x <= c.x) && (c.x <= b.x)) ||
               ((a.x >= c.x) && (c.x >= b.x));
    return ((a.y <= c.y) && (c.y <= b.y)) ||
           ((a.y >= c.y) && (c.y >= b.y));
}

inline line_segment_intersection parallel_int(
    cv::Point2f a, cv::Point2f b, cv::Point2f c, cv::Point2f d,
    cv::Point2f& p, cv::Point2f& q)
{
    line_segment_intersection code = LS_OVERLAP;
    if (area_sign(a, b, c) != 0)
        code = LS_NO_INTERSECTION;
    else if (between(a, b, c) && between(a, b, d))
        p = c, q = d;
    else if (between(c, d, a) && between(c, d, b))
        p = a, q = b;
    else if (between(a, b, c) && between(c, d, b))
        p = c, q = b;
    else if (between(a, b, c) && between(c, d, a))
        p = c, q = a;
    else if (between(a, b, d) && between(c, d, b))
        p = d, q = b;
    else if (between(a, b, d) && between(c, d, a))
        p = d, q = a;
    else
        code = LS_NO_INTERSECTION;
    return code;
}


// Intersection of segments (a, b) and (c, d). Expressions follow OpenCV
// 4.12+ (binary64 differences). Hardening: p and q are narrowed to float
// only after s and t are known finite and within [0, 1]; otherwise they are
// not computed, since callers use them only for the two intersecting codes.
// On a non-finite intermediate, numeric is set and no intersection reported.
inline line_segment_intersection intersect_line_segments(
    cv::Point2f a, cv::Point2f b, cv::Point2f c, cv::Point2f d,
    cv::Point2f& p, cv::Point2f& q, bool& numeric)
{
    double denom = ((double)a.x - b.x) * ((double)d.y - c.y)
                 - ((double)a.y - b.y) * ((double)d.x - c.x);
    if (denom == 0.)
        return parallel_int(a, b, c, d, p, q);
    if (!std::isfinite(denom)) {
        numeric = true;
        return LS_NO_INTERSECTION;
    }
    double num = ((double)d.y - a.y) * ((double)a.x - c.x)
               + ((double)a.x - d.x) * ((double)a.y - c.y);
    double s = num / denom;
    num = ((double)b.y - a.y) * ((double)a.x - c.x)
        + ((double)c.y - a.y) * ((double)b.x - a.x);
    double t = num / denom;
    if (!std::isfinite(s) || !std::isfinite(t)) {
        numeric = true;
        return LS_NO_INTERSECTION;
    }
    if (s < 0. || s > 1. || t < 0. || t > 1.)
        return LS_NO_INTERSECTION;
    double px = a.x + s * ((double)b.x - a.x);
    double py = a.y + s * ((double)b.y - a.y);
    if (!std::isfinite(px) || !std::isfinite(py)
        || std::fabs(px) > (double)FLT_MAX
        || std::fabs(py) > (double)FLT_MAX) {
        numeric = true;
        return LS_NO_INTERSECTION;
    }
    p.x = (float)px;
    p.y = (float)py;
    q = p;
    return s == 0. || s == 1. || t == 0. || t == 1.
        ? LS_ENDPOINT_INTERSECTION : LS_SINGLE_INTERSECTION;
}

inline in_flag in_out(cv::Point2f p, in_flag inflag, int aHB, int bHA,
                      scratch& r)
{
    if (p != r.last())
        r.push(p);
    return aHB > 0 ? Pin : bHA > 0 ? Qin : inflag;
}

// Advances and prints out an inside vertex if appropriate.
inline std::int64_t advance(std::int64_t a, std::int64_t* aa,
                            std::int64_t n, bool inside, cv::Point2f v,
                            scratch& r)
{
    if (inside && v != r.last())
        r.push(v);
    (*aa)++;
    return (a + 1) % n;
}

inline void add_shared_seg(cv::Point2f p, cv::Point2f q, scratch& r)
{
    if (p != r.last())
        r.push(p);
    if (q != r.last())
        r.push(q);
}

// Runs the loop. On ok, r holds the sentinel followed by the raw vertices.
// Writes per iteration: first-intersection push (1; the in_out push of the
// same point is then suppressed), in_out (<= 1), advance (<= 1, exactly one
// call), or add_shared_seg (<= 2, then return, with no other push that
// iteration because an overlap code is neither intersecting code). So at most
// 3 pushes per iteration, and an iteration starts only while count <=
// result_size, hence count <= result_size + 3 = the allocated capacity.
inline convex_intersection_status run_algorithm(
    const cv::Point2f* P, std::int64_t n, const cv::Point2f* Q,
    std::int64_t m, std::int64_t result_size, scratch& r,
    convex_intersection_diagnostics& diag)
{
    std::int64_t a = 0, b = 0;
    cv::Point2f origin(0, 0);
    in_flag inflag = Unknown;
    std::int64_t aa = 0, ba = 0;
    bool first_point = true;
    r.push(cv::Point2f(FLT_MAX, FLT_MAX));
    // Termination: each non-returning iteration advances aa or ba once, and
    // aa, ba reset to 0 once; the cap only defends that argument.
    const std::int64_t iteration_cap = 4 * (n + m) + 8;
    auto note = [&](std::size_t before) {
        diag.max_writes_per_iteration = std::max<std::int64_t>(
            diag.max_writes_per_iteration, (std::int64_t)(r.count - before));
    };

    do {
        const std::size_t before = r.count;
        if (++diag.iterations > iteration_cap)
            return convex_intersection_status::non_convergence;
        std::int64_t a1 = (a + n - 1) % n;
        std::int64_t b1 = (b + m - 1) % m;
        cv::Point2f A = P[a] - P[a1], B = Q[b] - Q[b1];

        int cross = area_sign(origin, A, B);
        int aHB = area_sign(Q[b1], Q[b], P[a]);
        int bHA = area_sign(P[a1], P[a], Q[b]);

        cv::Point2f p, q;
        line_segment_intersection code = intersect_line_segments(
            P[a1], P[a], Q[b1], Q[b], p, q, r.numeric);
        if (r.numeric)
            return convex_intersection_status::numeric_failure;
        if (code == LS_SINGLE_INTERSECTION
            || code == LS_ENDPOINT_INTERSECTION) {
            if (inflag == Unknown && first_point) {
                aa = ba = 0;
                first_point = false;
                r.push(p);
            }
            inflag = in_out(p, inflag, aHB, bHA, r);
        }

        if (code == LS_OVERLAP && A.ddot(B) < 0) {
            add_shared_seg(p, q, r);
            diag.early_return = true;
            note(before);
            return r.overflow ? convex_intersection_status::internal_bound
                              : convex_intersection_status::ok;
        }
        if (cross == 0 && aHB < 0 && bHA < 0) {
            diag.early_return = true;
            note(before);
            return convex_intersection_status::ok;
        }
        else if (cross == 0 && aHB == 0 && bHA == 0) {
            if (inflag == Pin)
                b = advance(b, &ba, m, inflag == Qin, Q[b], r);
            else
                a = advance(a, &aa, n, inflag == Pin, P[a], r);
        }
        else if (cross >= 0) {
            if (bHA > 0)
                a = advance(a, &aa, n, inflag == Pin, P[a], r);
            else
                b = advance(b, &ba, m, inflag == Qin, Q[b], r);
        }
        else {
            if (aHB > 0)
                b = advance(b, &ba, m, inflag == Qin, Q[b], r);
            else
                a = advance(a, &aa, n, inflag == Pin, P[a], r);
        }
        note(before);
        if (r.overflow)
            return convex_intersection_status::internal_bound;
    } while (((aa < n) || (ba < m)) && (aa < 2 * n) && (ba < 2 * m)
             && (std::int64_t)r.count <= result_size);
    return convex_intersection_status::ok;
}

inline bool inside_or_on(const std::vector<cv::Point2f>& polygon,
                         const std::vector<cv::Point2f>& points)
{
    for (const cv::Point2f& pt : points)
        if (cv::pointPolygonTest(polygon, pt, false) < 0)
            return false;
    return true;
}

}  // namespace convex_detail

// Intersects two CV_32F polygons. Behaves like cv::intersectConvexConvex
// for convex input (departures are listed in the file header). The polygons
// must be simple and strictly convex; that is the caller's obligation. For
// any input inside the envelope the function guarantees bounded writes,
// bounded time and defined floating-point conversions.
//
// Early exits (overlapping opposite edges, separated parallel edges) return
// the raw vertices with area 0 and skip the tail and the nested test, as
// upstream does. Upstream leaves the sentinel as the first returned vertex
// there; this function always removes it (the existing shim does the same).
inline convex_intersection_result intersect_convex_convex_f32(
    const std::vector<cv::Point2f>& left,
    const std::vector<cv::Point2f>& right, bool handle_nested)
{
    using namespace convex_detail;
    convex_intersection_result out;
    const std::int64_t n = (std::int64_t)left.size();
    const std::int64_t m = (std::int64_t)right.size();
    if (n + m > convex_intersection_max_input_count) {
        out.status = convex_intersection_status::invalid_input;
        return out;
    }
    for (const auto* poly : {&left, &right})
        for (const cv::Point2f& pt : *poly)
            if (!std::isfinite(pt.x) || !std::isfinite(pt.y)
                || std::fabs(pt.x) > convex_intersection_max_magnitude
                || std::fabs(pt.y) > convex_intersection_max_magnitude) {
                out.status = convex_intersection_status::invalid_input;
                return out;
            }
    if (n < 2 || m < 2)
        return out;

    std::vector<cv::Point2f> fp1(left), fp2(right);
    int orientation = 0;
    for (int k = 1; k <= 2; k++) {
        std::vector<cv::Point2f>& dst = k == 1 ? fp1 : fp2;
        const std::size_t len = dst.size();
        cv::Point2f diff0 = dst[0] - dst[len - 1];
        for (std::size_t i = 1; i < len; i++) {
            double s = diff0.cross(dst[i] - dst[i - 1]);
            if (s != 0) {
                if (s < 0) {
                    orientation++;
                    std::reverse(dst.begin(), dst.end());
                }
                break;
            }
        }
    }

    const std::int64_t result_size = n + m + 1;
    scratch r;
    r.buf.assign((std::size_t)(result_size + 3), cv::Point2f());
    out.diagnostics.capacity = result_size + 3;
    out.status = run_algorithm(fp1.data(), n, fp2.data(), m, result_size, r,
                               out.diagnostics);
    out.diagnostics.raw_count = (std::int64_t)r.count;
    if (r.overflow)
        out.status = convex_intersection_status::internal_bound;
    if (out.status != convex_intersection_status::ok)
        return out;
    // Upstream applies this bound after the loop only; here it covers the
    // early exits too. r.count >= 1 (sentinel) in every case.
    if ((std::int64_t)r.count > result_size) {
        out.status = convex_intersection_status::non_convergence;
        return out;
    }

    // e = raw[1 .. count-1], the sentinel dropped; k = count - 1 >= 0.
    std::vector<cv::Point2f> e(r.buf.begin() + 1,
                               r.buf.begin() + (std::ptrdiff_t)r.count);
    if (out.diagnostics.early_return) {
        // Upstream returns the raw count straight out of the loop here:
        // no area (0), no tail shift, no nested test, orientation flip only.
        if (orientation == 2)
            std::reverse(e.begin(), e.end());
        out.vertices = std::move(e);
        return out;
    }

    std::size_t k = e.size();
    double area = 0;
    if (k > 0) {
        cv::Point2f prev = e[k - 1];
        for (std::size_t i = 0; i < k; i++) {
            area += (double)prev.x * e[i].y - (double)prev.y * e[i].x;
            prev = e[i];
        }
    }
    float area_f = (float)(area * 0.5);
    if (!std::isfinite(area_f)) {
        out.status = convex_intersection_status::numeric_failure;
        return out;
    }
    // Upstream: if (result0[nr-2] == result0[0] && nr > 1) nr--, which
    // reads result0[-1] when nr == 1. After its shift result0[nr-2] is
    // e[k-1] and result0[0] is e[0]; the test is only made for k >= 1,
    // where a single vertex equals itself and is dropped, as upstream does.
    if (k >= 1 && e[k - 1] == e[0])
        k--;
    e.resize(k);

    if (k == 0) {
        if (!handle_nested)
            return out;
        out.diagnostics.nested_path = true;
        const std::vector<cv::Point2f>* chosen = nullptr;
        if (inside_or_on(fp1, fp2))
            chosen = &fp2;
        else if (inside_or_on(fp2, fp1))
            chosen = &fp1;
        if (chosen == nullptr)
            return out;
        float nested_f = (float)cv::contourArea(*chosen, false);
        if (!std::isfinite(nested_f)) {
            out.status = convex_intersection_status::numeric_failure;
            return out;
        }
        out.vertices = *chosen;
        if (orientation == 2)
            std::reverse(out.vertices.begin(), out.vertices.end());
        out.area = (float)std::fabs(nested_f);
        return out;
    }

    if (orientation == 2)
        std::reverse(e.begin(), e.end());
    out.vertices = std::move(e);
    out.area = (float)std::fabs(area_f);
    return out;
}

}  // namespace opencv_geometry_compat
#endif
