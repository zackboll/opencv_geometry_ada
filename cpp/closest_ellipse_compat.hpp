// Private backport of solveFast/getClosestEllipsePoints from OpenCV
// 4.12.0 modules/imgproc/src/shapedescr.cpp. The numerical code is identical
// in 4.13.0 and 5.0.0 (modules/geometry/src/shapedescr.cpp).
// Adaptation: typed vector input/output, no Mat or InputArray adapter.
// Retained upstream license (also distributed with binary sources):
//
//                        Intel License Agreement
//                For Open Source Computer Vision Library
//
// Copyright (C) 2000, Intel Corporation, all rights reserved.
// Third party copyrights are property of their respective owners.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * The name of Intel Corporation may not be used to endorse or promote
//   products derived from this software without specific prior written
//   permission.
//
// This software is provided by the copyright holders and contributors "as is"
// and any express or implied warranties, including, but not limited to, the
// implied warranties of merchantability and fitness for a particular purpose
// are disclaimed. In no event shall the Intel Corporation or contributors be
// liable for any direct, indirect, incidental, special, exemplary, or
// consequential damages (including, but not limited to, procurement of
// substitute goods or services; loss of use, data, or profits; or business
// interruption) however caused and on any theory of liability, whether in
// contract, strict liability, or tort (including negligence or otherwise)
// arising in any way out of the use of this software, even if advised of the
// possibility of such damage.

#ifndef OPENCV_GEOMETRY_CLOSEST_ELLIPSE_COMPAT_HPP
#define OPENCV_GEOMETRY_CLOSEST_ELLIPSE_COMPAT_HPP

#include <opencv2/core.hpp>
#include <algorithm>
#include <cmath>
#include <vector>

namespace opencv_geometry_compat {

// Chatfield, Carl (2017), A Simple Method for Distance to Ellipse.
// https://blog.chatfield.io/simple-method-for-distance-to-ellipse/
inline void solve_fast(float semi_major, float semi_minor,
                       const cv::Point2f& pt, cv::Point2f& closest_pt)
{
    float px = std::abs(pt.x);
    float py = std::abs(pt.y);
    float tx = 0.707f;
    float ty = 0.707f;
    float a = semi_major;
    float b = semi_minor;
    for (int iter = 0; iter < 3; iter++) {
        float x = a * tx;
        float y = b * ty;
        float ex = (a*a - b*b) * tx*tx*tx / a;
        float ey = (b*b - a*a) * ty*ty*ty / b;
        float rx = x - ex;
        float ry = y - ey;
        float qx = px - ex;
        float qy = py - ey;
        float r = std::hypotf(rx, ry);
        float q = std::hypotf(qx, qy);
        tx = std::min(1.0f, std::max(0.0f, (qx * r / q + ex) / a));
        ty = std::min(1.0f, std::max(0.0f, (qy * r / q + ey) / b));
        float t = std::hypotf(tx, ty);
        tx /= t;
        ty /= t;
    }
    closest_pt.x = std::copysign(a * tx, pt.x);
    closest_pt.y = std::copysign(b * ty, pt.y);
}

template<class Coordinate>
void closest_ellipse_points(const cv::RotatedRect& ellipse_params,
                           const std::vector<cv::Point_<Coordinate>>& points,
                           std::vector<cv::Point2f>& closest_pts)
{
    float semi_major = ellipse_params.size.width / 2.0f;
    float semi_minor = ellipse_params.size.height / 2.0f;
    float angle_deg = ellipse_params.angle;
    if (semi_major < semi_minor) {
        std::swap(semi_major, semi_minor);
        angle_deg += 90;
    }
    cv::Matx23f align_T_ori_f32;
    // CV_PI is the same binary64 constant as upstream's M_PI, and is
    // available with strict C++17 on all supported compiler platforms.
    float theta_rad = static_cast<float>(angle_deg * CV_PI / 180);
    float co = std::cos(theta_rad);
    float si = std::sin(theta_rad);
    float shift_x = ellipse_params.center.x;
    float shift_y = ellipse_params.center.y;
    align_T_ori_f32(0,0) = co;
    align_T_ori_f32(0,1) = si;
    align_T_ori_f32(0,2) = -co*shift_x - si*shift_y;
    align_T_ori_f32(1,0) = -si;
    align_T_ori_f32(1,1) = co;
    align_T_ori_f32(1,2) = si*shift_x - co*shift_y;
    cv::Matx23f ori_T_align_f32;
    ori_T_align_f32(0,0) = co;
    ori_T_align_f32(0,1) = -si;
    ori_T_align_f32(0,2) = shift_x;
    ori_T_align_f32(1,0) = si;
    ori_T_align_f32(1,1) = co;
    ori_T_align_f32(1,2) = shift_y;
    closest_pts.clear();
    closest_pts.reserve(points.size());
    for (const auto& point : points) {
        cv::Point2f p(static_cast<float>(point.x), static_cast<float>(point.y));
        cv::Matx31f pmat(p.x, p.y, 1);
        cv::Matx21f X_align = align_T_ori_f32 * pmat;
        cv::Point2f closest_pt;
        solve_fast(semi_major, semi_minor,
                   cv::Point2f(X_align(0,0), X_align(1,0)), closest_pt);
        pmat(0,0) = closest_pt.x;
        pmat(1,0) = closest_pt.y;
        cv::Matx21f closest_pt_ori = ori_T_align_f32 * pmat;
        closest_pts.push_back(
            cv::Point2f(closest_pt_ori(0,0), closest_pt_ori(1,0)));
    }
}

} // namespace opencv_geometry_compat
#endif