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
    return opencv_geometry_subdiv2d_is_usable(handle) == 0
        && opencv_geometry_subdiv2d_quad_edge_count(handle, &count)
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
    exercise_create_and_initialize();
    std::printf("on-edge failures marking unusable: %d\n", on_edge_unusable);
    std::printf("inside failures marking unusable: %d\n", inside_unusable);
    std::printf("%s: %d failed check(s)\n",
                failed_checks == 0 ? "PASS" : "FAIL", failed_checks);
    return failed_checks == 0 ? 0 : 1;
}
