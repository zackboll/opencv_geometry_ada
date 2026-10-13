// Native test of opencv_geometry_intersect_convex_convex_extended_f32.
// Includes the shim source, so the shim and the private headers are compiled
// with whatever sanitizers this file is built with (run_native_tests.sh uses
// AddressSanitizer and UndefinedBehaviorSanitizer). Exercises the raw C ABI
// the way a C caller would, with exact-size heap buffers so AddressSanitizer
// sees any read or write beyond the declared counts or capacity.
#include "../../cpp/opencv_geometry_shim.cpp"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

namespace {

int failures = 0;

void check(bool ok, const char *what)
{
    if (!ok) {
        std::fprintf(stderr, "FAIL %s\n", what);
        ++failures;
    }
}

using point = opencv_geometry_point_f32;

std::vector<point> box(float x, float y, float side)
{
    return {{x, y}, {x + side, y}, {x + side, y + side}, {x, y + side}};
}

bool message_has(const char *fragment)
{
    return std::strstr(opencv_geometry_last_error_message(), fragment)
        != nullptr;
}

// Calls the export with heap buffers of exactly the stated sizes.
opencv_geometry_status run(
    const std::vector<point> &left,
    const std::vector<point> &right,
    int32_t nested,
    int32_t capacity,
    int32_t *count,
    float *area)
{
    std::vector<point> out(
        static_cast<std::size_t>(capacity > 0 ? capacity : 0));
    return opencv_geometry_intersect_convex_convex_extended_f32(
        left.data(), static_cast<int32_t>(left.size()),
        right.data(), static_cast<int32_t>(right.size()),
        nested, capacity > 0 ? out.data() : nullptr, capacity,
        count, area);
}

bool is_rejected(
    const std::vector<point> &left,
    const std::vector<point> &right,
    const char *fragment)
{
    int32_t count = 55;
    float area = 55.0f;
    const opencv_geometry_status status =
        run(left, right, 1, 16, &count, &area);
    return status == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && count == 0 && area == 0.0f && message_has(fragment);
}

std::vector<point> ngon(int k, double cx, double cy, double r, double phase)
{
    std::vector<point> v;
    for (int j = 0; j < k; ++j) {
        const double a = 6.283185307179586 * j / k + phase;
        v.push_back({static_cast<float>(cx + r * std::cos(a)),
                     static_cast<float>(cy + r * std::sin(a))});
    }
    return v;
}

void valid_and_capacity()
{
    const std::vector<point> unit = box(0.0f, 0.0f, 1.0f);
    int32_t count = -1;
    float area = -1.0f;
    check(run(box(0.1f, 0.1f, 0.3f), box(0.2f, 0.2f, 0.3f), 1, 4, &count,
              &area) == OPENCV_GEOMETRY_OK && count == 4,
          "fractional squares succeed with four vertices");
    check(std::fabs(area - 0.04f) < 1e-5f, "fractional area is 0.04");
    check(run(unit, box(0.5f, 0.25f, 1.0f), 1, 4, &count, &area)
              == OPENCV_GEOMETRY_OK && count == 4,
          "capacity equal to the count succeeds");
    check(run(unit, box(0.5f, 0.25f, 1.0f), 1, 3, &count, &area)
              == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
              && count == 0 && area == 0.0f && message_has("capacity"),
          "capacity one below the count fails unpublished");
    check(run(unit, box(0.5f, 0.25f, 1.0f), 1, 0, &count, &area)
              == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT,
          "zero capacity fails for a non-empty result");
    check(run(unit, box(9.0f, 9.0f, 1.0f), 1, 0, &count, &area)
              == OPENCV_GEOMETRY_OK && count == 0 && area == 0.0f,
          "disjoint input succeeds with zero capacity");
}

void invalid_polygons()
{
    const std::vector<point> unit = box(0.0f, 0.0f, 1.0f);
    check(is_rejected({{0, 0}, {4, 0}, {1, 1}, {0, 4}}, unit, "left"),
          "concave");
    check(is_rejected(unit, {{0, 0}, {2, 0}, {2, 0}, {1, 1}}, "right"),
          "repeated vertex");
    check(is_rejected({{0, 0}, {2, 2}, {2, 0}, {0, 2}}, unit, "left"),
          "bowtie");
    check(is_rejected({{0, 3}, {1, 1}, {3, 0}, {1, -1}, {0, -3}, {-1, -1},
                       {-3, 0}, {-1, 1}}, unit, "left"), "star");
    std::vector<point> twice = unit;
    twice.insert(twice.end(), unit.begin(), unit.end());
    check(is_rejected(twice, unit, "left"), "repeated traversal");
    check(is_rejected({{0, 0}, {1, 0}, {2, 0}, {1, 1}}, unit, "left"),
          "redundant collinear vertex");
    const float nan = std::numeric_limits<float>::quiet_NaN();
    const float inf = std::numeric_limits<float>::infinity();
    check(is_rejected({{0, 0}, {nan, 0}, {1, 1}, {0, 1}}, unit, "finite"),
          "NaN");
    check(is_rejected({{0, 0}, {inf, 0}, {1, 1}, {0, 1}}, unit, "finite"),
          "infinity");
    check(is_rejected({{-inf, 0}, {1, 0}, {1, 1}, {0, 1}}, unit, "finite"),
          "negative infinity");
    check(is_rejected(box(2147483648.0f, 0.0f, 256.0f), unit, "2**30"),
          "out of envelope");
    check(is_rejected(box(std::numeric_limits<float>::max() / 2, 0.0f, 1.0f),
                      unit, "2**30"), "huge coordinates");
}

// Controlled non-convergence is a documented possible result: whatever a
// pair does, the call either succeeds within capacity with finite output or
// fails with nothing published. Deterministic near-degenerate pairs run under
// the sanitizers with exact-size buffers.
void sweep()
{
    unsigned long long state = 12345;
    auto next = [&state]() {
        state = state * 6364136223846793005ULL + 1442695040888963407ULL;
        return static_cast<double>(state >> 11) / 9007199254740992.0;
    };
    int ok = 0, failed = 0;
    for (int i = 0; i < 4000; ++i) {
        const int n = 3 + static_cast<int>(next() * 40);
        const int m = 3 + static_cast<int>(next() * 40);
        const double r1 = 0.5 + next() * 300, r2 = 0.5 + next() * 300;
        const auto a = ngon(n, 0, 0, r1, next());
        const auto b = ngon(m, (next() - 0.5) * r1, (next() - 0.5) * r1, r2,
                            next());
        int32_t count = -1;
        float area = -1.0f;
        const int32_t capacity = n + m;
        if (run(a, b, 1, capacity, &count, &area) == OPENCV_GEOMETRY_OK) {
            ++ok;
            check(count >= 0 && count <= capacity && area >= 0.0f
                      && std::isfinite(area),
                  "sweep success is within capacity and finite");
        } else {
            ++failed;
            check(count == 0 && area == 0.0f,
                  "sweep failure publishes nothing");
        }
    }
    std::printf("sweep: %d succeeded, %d failed controlled\n", ok, failed);
}

void arguments()
{
    const std::vector<point> unit = box(0.0f, 0.0f, 1.0f);
    int32_t count = 7;
    float area = 99.0f;
    std::vector<point> out(8);
    check(opencv_geometry_intersect_convex_convex_extended_f32(
              unit.data(), 4, unit.data(), 4, 1, out.data(), 8, nullptr,
              &area) == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
              && area == 0.0f && message_has("output count"),
          "null count pointer resets the area");
    area = 7.0f;
    {
        // Ordinary validation failure and success leave both outputs right.
        count = 5;
        area = 5.0f;
        check(run(unit, {{0, 0}, {1, 0}, {2, 0}, {1, 1}}, 1, 8, &count,
                  &area) == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
                  && count == 0 && area == 0.0f,
              "validation failure zeroes both outputs");
        count = 5;
        area = 5.0f;
        check(run(unit, box(0.5f, 0.25f, 1.0f), 1, 8, &count, &area)
                  == OPENCV_GEOMETRY_OK && count == 4
                  && std::fabs(area - 0.375f) < 1e-6f,
              "success publishes count 4 and area 0.375");
        count = 7;
        area = 7.0f;
    }
    check(opencv_geometry_intersect_convex_convex_extended_f32(
              unit.data(), 4, unit.data(), 4, 1, out.data(), 8, &count,
              nullptr) == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
              && count == 0,
          "null area pointer resets the count");
    check(opencv_geometry_intersect_convex_convex_extended_f32(
              nullptr, 4, unit.data(), 4, 1, out.data(), 8, &count, &area)
              == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT,
          "null left");
    check(opencv_geometry_intersect_convex_convex_extended_f32(
              unit.data(), 4, unit.data(), 4, 3, out.data(), 8, &count,
              &area) == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
              && message_has("nested"),
          "bad selector");
    check(opencv_geometry_intersect_convex_convex_extended_f32(
              unit.data(), 4, unit.data(), 4, 1, out.data(), -1, &count,
              &area) == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT,
          "negative capacity");
    check(opencv_geometry_intersect_convex_convex_extended_f32(
              unit.data(), 2147483647, unit.data(), 2147483647, 1,
              out.data(), 8, &count, &area)
              == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT,
          "overflowing counts are rejected before any read");
}

}  // namespace

int main()
{
    valid_and_capacity();
    invalid_polygons();
    sweep();
    arguments();
    if (failures != 0) {
        std::fprintf(stderr, "%d failure(s)\n", failures);
        return 1;
    }
    std::printf("PASS extended convex intersection raw C ABI\n");
    return 0;
}
