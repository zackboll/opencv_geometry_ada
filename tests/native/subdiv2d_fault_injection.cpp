// Fault-injection test for the Subdiv2D shim's unusable state.
//
// The shim marks a subdivision handle unusable when a failed modification may
// have left the native cv::Subdiv2D inconsistent; Subdiv2D::insert can delete
// an edge before it allocates the new vertex and edges. Ada tests cannot make
// OpenCV run out of memory, so this program includes the shim implementation,
// replaces the global allocation functions, and fails the Nth allocation of
// each operation for every N until the operation succeeds. It checks that:
//
// - a handle marked unusable rejects every operation until init_delaunay;
// - a handle left usable still holds a working triangulation;
// - a failed list query publishes a zero count and keeps the handle usable;
// - a failed Voronoi facet query publishes no counts, keeps the handle
//   usable, and a later query returns the complete facets;
// - failed creation publishes a null handle, and failed initialization marks
//   the handle unusable until a later successful initialization.
//
// Build and run with scripts/run_native_tests.sh after `alr -n build`.

#include "../../cpp/opencv_geometry_shim.cpp"

#include <cstdio>
#include <cstdlib>
#include <new>

namespace {

long allocation_countdown = -1;  // Negative: no failure is armed.
int failed_checks = 0;

void *checked_allocation(std::size_t size)
{
    if (allocation_countdown >= 0) {
        if (allocation_countdown == 0) {
            allocation_countdown = -1;
            throw std::bad_alloc();
        }
        --allocation_countdown;
    }
    void *memory = std::malloc(size == 0 ? 1 : size);
    if (memory == nullptr) {
        throw std::bad_alloc();
    }
    return memory;
}

void check(bool condition, const char *message, long step)
{
    if (!condition) {
        std::printf("FAIL: %s (allocation %ld)\n", message, step);
        ++failed_checks;
    }
}

const opencv_geometry_rect_i32 bounds{0, 0, 100, 100};

const opencv_geometry_point_f32 fixture[] = {
    {10.0f, 10.0f}, {90.0f, 10.0f}, {50.0f, 80.0f}, {50.0f, 40.0f}};

opencv_geometry_subdiv2d *make_fixture()
{
    opencv_geometry_subdiv2d *handle = nullptr;
    int32_t inserted = 0;
    if (opencv_geometry_subdiv2d_create(&bounds, &handle) != OPENCV_GEOMETRY_OK
        || opencv_geometry_subdiv2d_insert_points(
               handle, fixture, 4, &inserted)
            != OPENCV_GEOMETRY_OK) {
        std::printf("FAIL: fixture setup\n");
        std::exit(1);
    }
    return handle;
}

bool locates_on_vertex(opencv_geometry_subdiv2d *handle, float x, float y)
{
    int32_t location = 0;
    int32_t edge = 0;
    int32_t vertex = 0;
    return opencv_geometry_subdiv2d_locate(
               handle, x, y, &location, &edge, &vertex)
            == OPENCV_GEOMETRY_OK
        && location == OPENCV_GEOMETRY_SUBDIV2D_LOCATION_ON_VERTEX
        && vertex > 3;
}

bool triangulation_works(opencv_geometry_subdiv2d *handle)
{
    for (const opencv_geometry_point_f32 &point : fixture) {
        if (!locates_on_vertex(handle, point.x, point.y)) {
            return false;
        }
    }
    int32_t vertex = 0;
    opencv_geometry_point_f32 nearest{};
    return opencv_geometry_subdiv2d_find_nearest(
               handle, 52.0f, 43.0f, &vertex, &nearest)
            == OPENCV_GEOMETRY_OK
        && nearest.x == 50.0f && nearest.y == 40.0f;
}

bool rejects_everything(opencv_geometry_subdiv2d *handle)
{
    int32_t vertex = 0;
    int32_t count = 0;
    int32_t location = 0;
    int32_t edge = 0;
    int32_t kind = 0;
    opencv_geometry_point_f32 nearest{};
    opencv_geometry_edge_segment_f32 segments[64]{};
    opencv_geometry_voronoi_facet_f32 facets[8]{};
    opencv_geometry_point_f32 points[64]{};
    return opencv_geometry_subdiv2d_is_usable(handle) == 0
        && opencv_geometry_subdiv2d_quad_edge_count(handle, &count)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_voronoi_facet_counts(
               handle,
               OPENCV_GEOMETRY_SUBDIV2D_VORONOI_SELECT_ALL,
               nullptr,
               0,
               &count,
               &vertex)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_get_voronoi_facets(
               handle,
               OPENCV_GEOMETRY_SUBDIV2D_VORONOI_SELECT_ALL,
               nullptr,
               0,
               facets,
               8,
               points,
               64,
               &count,
               &vertex)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_get_edge_list(handle, segments, 64, &count)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_get_vertex(handle, 4, &nearest, &edge, &kind)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_edge_org(handle, 16, &vertex)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_insert(handle, 20.0f, 20.0f, &vertex)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_insert_points(handle, fixture, 4, &count)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_locate(
               handle, 20.0f, 20.0f, &location, &edge, &vertex)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT
        && opencv_geometry_subdiv2d_find_nearest(
               handle, 20.0f, 20.0f, &vertex, &nearest)
            == OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT;
}

// Fails each allocation of one insertion in turn. Returns how many failures
// left the handle unusable.
int exercise_insert(float x, float y, const char *label)
{
    int unusable = 0;
    for (long step = 0;; ++step) {
        opencv_geometry_subdiv2d *handle = make_fixture();
        int32_t vertex = 0;
        allocation_countdown = step;
        const opencv_geometry_status status =
            opencv_geometry_subdiv2d_insert(handle, x, y, &vertex);
        allocation_countdown = -1;
        if (status == OPENCV_GEOMETRY_OK) {
            check(locates_on_vertex(handle, x, y), label, step);
            opencv_geometry_subdiv2d_destroy(handle);
            break;
        }
        check(vertex == 0, "a failed insertion publishes no vertex", step);
        if (opencv_geometry_subdiv2d_is_usable(handle) == 1) {
            // Usable after a failure: the triangulation must still work and
            // accept the same point.
            check(triangulation_works(handle),
                  "a usable handle keeps a working triangulation", step);
            check(opencv_geometry_subdiv2d_insert(handle, x, y, &vertex)
                          == OPENCV_GEOMETRY_OK
                      && locates_on_vertex(handle, x, y),
                  "a usable handle accepts the point afterwards", step);
        } else {
            ++unusable;
            check(rejects_everything(handle),
                  "an unusable handle rejects every operation", step);
            check(opencv_geometry_subdiv2d_init_delaunay(handle, &bounds)
                          == OPENCV_GEOMETRY_OK
                      && opencv_geometry_subdiv2d_is_usable(handle) == 1,
                  "init_delaunay makes the handle usable again", step);
            int32_t inserted = 0;
            check(opencv_geometry_subdiv2d_insert_points(
                      handle, fixture, 4, &inserted)
                          == OPENCV_GEOMETRY_OK
                      && triangulation_works(handle),
                  "a reinitialized handle works", step);
        }
        opencv_geometry_subdiv2d_destroy(handle);
    }
    return unusable;
}

void exercise_find_nearest()
{
    for (long step = 0;; ++step) {
        opencv_geometry_subdiv2d *handle = make_fixture();
        int32_t vertex = 0;
        opencv_geometry_point_f32 nearest{};
        allocation_countdown = step;
        const opencv_geometry_status status =
            opencv_geometry_subdiv2d_find_nearest(
                handle, 52.0f, 43.0f, &vertex, &nearest);
        allocation_countdown = -1;
        check(opencv_geometry_subdiv2d_is_usable(handle) == 1,
              "Voronoi failures keep the handle usable", step);
        check(triangulation_works(handle),
              "Voronoi data is recomputed after a failure", step);
        opencv_geometry_subdiv2d_destroy(handle);
        if (status == OPENCV_GEOMETRY_OK) {
            break;
        }
    }
}

// Fails each allocation of the three list queries in turn.
void exercise_lists()
{
    opencv_geometry_edge_segment_f32 segments[64]{};
    int32_t leading[128]{};
    opencv_geometry_triangle_f32 triangles[128]{};
    for (int list = 0; list < 3; ++list) {
        for (long step = 0;; ++step) {
            opencv_geometry_subdiv2d *handle = make_fixture();
            int32_t count = 99;
            allocation_countdown = step;
            opencv_geometry_status status = OPENCV_GEOMETRY_OK;
            switch (list) {
            case 0:
                status = opencv_geometry_subdiv2d_get_edge_list(
                    handle, segments, 64, &count);
                break;
            case 1:
                status = opencv_geometry_subdiv2d_get_leading_edge_list(
                    handle, leading, 128, &count);
                break;
            default:
                status = opencv_geometry_subdiv2d_get_triangle_list(
                    handle, triangles, 128, &count);
                break;
            }
            allocation_countdown = -1;
            if (status == OPENCV_GEOMETRY_OK) {
                check(count > 0, "a successful list is not empty", step);
                opencv_geometry_subdiv2d_destroy(handle);
                break;
            }
            check(count == 0, "a failed list publishes a zero count", step);
            check(opencv_geometry_subdiv2d_is_usable(handle) == 1
                      && triangulation_works(handle),
                  "a failed list keeps a working triangulation", step);
            opencv_geometry_subdiv2d_destroy(handle);
        }
    }
}

struct VoronoiResult {
    int32_t facet_count = 0;
    int32_t point_count = 0;
    opencv_geometry_voronoi_facet_f32 facets[8]{};
    opencv_geometry_point_f32 points[64]{};
};

opencv_geometry_status read_voronoi(
    opencv_geometry_subdiv2d *handle, VoronoiResult &result)
{
    return opencv_geometry_subdiv2d_get_voronoi_facets(
        handle,
        OPENCV_GEOMETRY_SUBDIV2D_VORONOI_SELECT_ALL,
        nullptr,
        0,
        result.facets,
        8,
        result.points,
        64,
        &result.facet_count,
        &result.point_count);
}

bool same_voronoi(const VoronoiResult &left, const VoronoiResult &right)
{
    if (left.facet_count != right.facet_count
        || left.point_count != right.point_count) {
        return false;
    }
    for (int32_t index = 0; index < left.facet_count; ++index) {
        const opencv_geometry_voronoi_facet_f32 &a = left.facets[index];
        const opencv_geometry_voronoi_facet_f32 &b = right.facets[index];
        if (a.site != b.site || a.center_x != b.center_x
            || a.center_y != b.center_y || a.first_point != b.first_point
            || a.point_count != b.point_count || a.complete != b.complete) {
            return false;
        }
    }
    for (int32_t index = 0; index < left.point_count; ++index) {
        if (left.points[index].x != right.points[index].x
            || left.points[index].y != right.points[index].y) {
            return false;
        }
    }
    return true;
}

// Fails each allocation of the Voronoi facet functions in turn, on a fixture
// whose Voronoi data the failing call computes first.
void exercise_voronoi_facets()
{
    VoronoiResult reference;
    {
        opencv_geometry_subdiv2d *handle = make_fixture();
        check(read_voronoi(handle, reference) == OPENCV_GEOMETRY_OK
                  && reference.facet_count == 4,
              "reference Voronoi facets", -1);
        opencv_geometry_subdiv2d_destroy(handle);
    }

    for (long step = 0;; ++step) {
        opencv_geometry_subdiv2d *handle = make_fixture();
        int32_t facet_count = 99;
        int32_t point_count = 99;
        allocation_countdown = step;
        const opencv_geometry_status status =
            opencv_geometry_subdiv2d_voronoi_facet_counts(
                handle,
                OPENCV_GEOMETRY_SUBDIV2D_VORONOI_SELECT_ALL,
                nullptr,
                0,
                &facet_count,
                &point_count);
        allocation_countdown = -1;
        const bool counted = status == OPENCV_GEOMETRY_OK;
        check(counted ? facet_count == reference.facet_count
                            && point_count == reference.point_count
                      : facet_count == 0 && point_count == 0,
              "Voronoi counting publishes counts only on success", step);
        check(opencv_geometry_subdiv2d_is_usable(handle) == 1,
              "Voronoi counting failures keep the handle usable", step);
        VoronoiResult after;
        check(read_voronoi(handle, after) == OPENCV_GEOMETRY_OK
                  && same_voronoi(after, reference),
              "Voronoi facets are complete after a counting failure", step);
        opencv_geometry_subdiv2d_destroy(handle);
        if (counted) {
            break;
        }
    }

    for (long step = 0;; ++step) {
        opencv_geometry_subdiv2d *handle = make_fixture();
        VoronoiResult failed;
        failed.facet_count = 99;
        failed.point_count = 99;
        allocation_countdown = step;
        const opencv_geometry_status status = read_voronoi(handle, failed);
        allocation_countdown = -1;
        if (status == OPENCV_GEOMETRY_OK) {
            check(same_voronoi(failed, reference),
                  "unfailed Voronoi facets match the reference", step);
            opencv_geometry_subdiv2d_destroy(handle);
            break;
        }
        check(failed.facet_count == 0 && failed.point_count == 0,
              "failed Voronoi facets publish zero counts", step);
        check(opencv_geometry_subdiv2d_is_usable(handle) == 1
                  && triangulation_works(handle),
              "Voronoi facet failures keep a working triangulation", step);
        VoronoiResult after;
        check(read_voronoi(handle, after) == OPENCV_GEOMETRY_OK
                  && same_voronoi(after, reference),
              "Voronoi facets are complete after a failure", step);
        opencv_geometry_subdiv2d_destroy(handle);
    }
}

void exercise_create_and_initialize()
{
    for (long step = 0;; ++step) {
        opencv_geometry_subdiv2d *handle = nullptr;
        allocation_countdown = step;
        const opencv_geometry_status status =
            opencv_geometry_subdiv2d_create(&bounds, &handle);
        allocation_countdown = -1;
        if (status == OPENCV_GEOMETRY_OK) {
            check(handle != nullptr
                      && opencv_geometry_subdiv2d_is_usable(handle) == 1,
                  "successful creation publishes a usable handle", step);
            opencv_geometry_subdiv2d_destroy(handle);
            break;
        }
        check(handle == nullptr, "failed creation publishes null", step);
    }

    for (long step = 0;; ++step) {
        opencv_geometry_subdiv2d *handle = make_fixture();
        allocation_countdown = step;
        const opencv_geometry_status status =
            opencv_geometry_subdiv2d_init_delaunay(handle, &bounds);
        allocation_countdown = -1;
        if (status == OPENCV_GEOMETRY_OK) {
            check(opencv_geometry_subdiv2d_is_usable(handle) == 1,
                  "successful initialization is usable", step);
            opencv_geometry_subdiv2d_destroy(handle);
            break;
        }
        check(rejects_everything(handle),
              "failed initialization leaves the handle unusable", step);
        check(opencv_geometry_subdiv2d_init_delaunay(handle, &bounds)
                      == OPENCV_GEOMETRY_OK
                  && opencv_geometry_subdiv2d_is_usable(handle) == 1,
              "a later initialization succeeds", step);
        opencv_geometry_subdiv2d_destroy(handle);
    }
}

void exercise_float32_initialization()
{
    const opencv_geometry_rect_f32 fractional{-0.25f, 0.5f, 100.5f, 100.25f};
    long create_failures = 0;
    for (long step = 0;; ++step) {
        opencv_geometry_subdiv2d *handle = nullptr;
        allocation_countdown = step;
        const auto status =
            opencv_geometry_subdiv2d_create_f32(&fractional, &handle);
        allocation_countdown = -1;
        if (status == OPENCV_GEOMETRY_OK) {
            check(handle != nullptr
                      && opencv_geometry_subdiv2d_is_usable(handle) == 1,
                  "Float32 constructor publishes a usable handle", step);
            opencv_geometry_subdiv2d_destroy(handle);
            break;
        }
        ++create_failures;
        check(handle == nullptr, "failed Float32 creation publishes null", step);
        check(status == OPENCV_GEOMETRY_ERROR_STD,
              "Float32 constructor contains allocation failure", step);
    }

    // A ready native subdivision retains vector capacity across clear(), so
    // resetting it does not allocate. To cover exceptions while rebuilding,
    // use an existing default handle with no storage. This reaches the same
    // native rebuild failure path without a production hook; it is not an
    // injected public Ada Reset failure on an already-ready object.
    long reset_failures = 0;
    for (long step = 0;; ++step) {
        auto *handle = new opencv_geometry_subdiv2d();
        allocation_countdown = step;
        const auto status =
            opencv_geometry_subdiv2d_init_delaunay_f32(handle, &fractional);
        allocation_countdown = -1;
        if (status == OPENCV_GEOMETRY_OK) {
            check(opencv_geometry_subdiv2d_is_usable(handle) == 1,
                  "Float32 initialization restores readiness", step);
            opencv_geometry_subdiv2d_destroy(handle);
            break;
        }
        ++reset_failures;
        check(rejects_everything(handle),
              "failed Float32 rebuild leaves handle unusable", step);
        check(opencv_geometry_subdiv2d_init_delaunay_f32(handle, &fractional)
                      == OPENCV_GEOMETRY_OK
                  && opencv_geometry_subdiv2d_is_usable(handle) == 1,
              "Float32 Reset recovers after a native failure", step);
        opencv_geometry_subdiv2d_destroy(handle);
    }
    check(create_failures > 0 && reset_failures > 0,
          "Float32 allocation failure paths actually exercised", -1);

    auto *handle = make_fixture();
    allocation_countdown = 0;
    const auto status =
        opencv_geometry_subdiv2d_init_delaunay_f32(handle, &fractional);
    const bool no_allocation = allocation_countdown == 0;
    allocation_countdown = -1;
    check(status == OPENCV_GEOMETRY_OK && no_allocation,
          "ready Float32 Reset reuses retained native storage", -1);
    check(opencv_geometry_subdiv2d_is_usable(handle) == 1
              && !locates_on_vertex(handle, 10.0f, 10.0f),
          "Float32 Reset discards the old triangulation", -1);
    opencv_geometry_subdiv2d_destroy(handle);
    std::printf("Float32 creation/rebuild allocation failures: %ld/%ld\n",
                create_failures, reset_failures);
}

}

void *operator new(std::size_t size)
{
    return checked_allocation(size);
}

void *operator new[](std::size_t size)
{
    return checked_allocation(size);
}

void operator delete(void *memory) noexcept
{
    std::free(memory);
}

void operator delete[](void *memory) noexcept
{
    std::free(memory);
}

void operator delete(void *memory, std::size_t) noexcept
{
    std::free(memory);
}

void operator delete[](void *memory, std::size_t) noexcept
{
    std::free(memory);
}

int main()
{
    std::printf("Subdiv2D fault injection: OpenCV %s\n", CV_VERSION);
    // (50, 60) lies on the edge between (50, 80) and (50, 40), so insertion
    // deletes that edge before it allocates; (30, 20) lies inside a triangle.
    const int on_edge_unusable = exercise_insert(50.0f, 60.0f, "on-edge insert");
    const int inside_unusable = exercise_insert(30.0f, 20.0f, "inside insert");
    check(on_edge_unusable > 0,
          "some on-edge insertion failure marks the handle unusable", -1);
    exercise_find_nearest();
    exercise_lists();
    exercise_voronoi_facets();
    exercise_create_and_initialize();
    exercise_float32_initialization();
    std::printf("on-edge failures marking unusable: %d\n", on_edge_unusable);
    std::printf("inside failures marking unusable: %d\n", inside_unusable);
    std::printf("%s: %d failed check(s)\n",
                failed_checks == 0 ? "PASS" : "FAIL", failed_checks);
    return failed_checks == 0 ? 0 : 1;
}
