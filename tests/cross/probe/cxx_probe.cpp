#include <numeric>
#include <vector>

// Uses the target C++ standard library so that the probe link needs it.
extern "C" int geometry_cross_cxx_probe(int count) noexcept
{
    std::vector<int> values(static_cast<std::vector<int>::size_type>(count));
    std::iota(values.begin(), values.end(), 1);
    return std::accumulate(values.begin(), values.end(), 0);
}
