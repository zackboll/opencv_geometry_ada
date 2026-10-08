// Deterministic cross-version geometry transcript. Run under a hard timeout.
// Sort geometric coordinates, not identifiers or native traversal order.
#include "../../cpp/opencv_geometry_shim.cpp"
#include <array>
#include <cstdio>
#include <cstdlib>

namespace {
void require(bool condition)
{
    if (!condition) {
        std::fprintf(stderr, "Float32 equivalence assertion failed\n");
        std::exit(1);
    }
}

void transcript(GeometrySubdiv2D &native)
{
    for (int id = 1; id <= 3; ++id) {
        const auto p = native.getVertex(id);
        std::printf("super %a %a\n", p.x, p.y);
    }
    const std::vector<cv::Point2f> sites{
        {2.25f, 3.5f}, {8.25f, 2.5f}, {5.25f, 10.5f}, {5.25f, 6.5f}};
    for (const auto &p : sites) {
        const int id = native.insert(p);
        require(id > 3 && native.insert(p) == id);
        int edge = 0, vertex = 0;
        require(native.locate(p, edge, vertex) == cv::Subdiv2D::PTLOC_VERTEX
                && vertex == id);
    }
    cv::Point2f nearest;
    require(native.findNearest({2.5f, 3.75f}, &nearest) > 3);
    require(nearest == sites[0]);
    std::vector<cv::Vec6f> triangles;
    native.getTriangleList(triangles);
    require(triangles.size() == 3);
    std::vector<std::array<float, 6>> canonical;
    for (const auto &t : triangles) {
        std::array<std::array<float, 2>, 3> points{{
            {{t[0], t[1]}}, {{t[2], t[3]}}, {{t[4], t[5]}}}};
        std::sort(points.begin(), points.end());
        canonical.push_back({points[0][0], points[0][1], points[1][0],
                             points[1][1], points[2][0], points[2][1]});
    }
    std::sort(canonical.begin(), canonical.end());
    for (const auto &t : canonical) {
        std::printf("triangle");
        for (float value : t) std::printf(" %a", value);
        std::printf("\n");
    }
    std::vector<cv::Vec4f> edges;
    native.getEdgeList(edges);
    std::vector<std::array<float, 4>> canonical_edges;
    for (const auto &e : edges) {
        std::array<float, 2> a{{e[0], e[1]}}, b{{e[2], e[3]}};
        if (b < a) std::swap(a, b);
        canonical_edges.push_back({a[0], a[1], b[0], b[1]});
    }
    std::sort(canonical_edges.begin(), canonical_edges.end());
    for (const auto &e : canonical_edges)
        std::printf("edge %a %a %a %a\n", e[0], e[1], e[2], e[3]);
    std::vector<std::vector<cv::Point2f>> facets;
    std::vector<cv::Point2f> centers;
    native.getVoronoiFacetList({}, facets, centers);
    require(facets.size() == sites.size());
    // Sort each polygon and sort facets by site, without requiring walk order.
    std::vector<std::vector<std::array<float, 2>>> records;
    for (std::size_t i = 0; i < facets.size(); ++i) {
        std::vector<std::array<float, 2>> record;
        for (const auto &p : facets[i]) record.push_back({p.x, p.y});
        std::sort(record.begin(), record.end());
        record.insert(record.begin(), {centers[i].x, centers[i].y});
        records.push_back(record);
    }
    std::sort(records.begin(), records.end());
    for (const auto &record : records) {
        std::printf("facet");
        for (const auto &p : record) std::printf(" %a %a", p[0], p[1]);
        std::printf("\n");
    }
}
}

int main()
{
    const opencv_geometry_rect_f32 bounds{-0.25f, 0.5f, 10.5f, 12.25f};
    opencv_geometry_subdiv2d *handle = nullptr;
    require(opencv_geometry_subdiv2d_create_f32(&bounds, &handle)
            == OPENCV_GEOMETRY_OK);
    transcript(handle->native);
    for (int repetition = 0; repetition < 3; ++repetition) {
        require(opencv_geometry_subdiv2d_init_delaunay_f32(handle, &bounds)
                == OPENCV_GEOMETRY_OK);
        require(handle->native.vertex_slot_count() == 4);
        require(handle->native.quad_edge_count() == 4);
    }
    opencv_geometry_subdiv2d_destroy(handle);
    std::printf("PASS Float32 geometry/reset/ownership\n");
}