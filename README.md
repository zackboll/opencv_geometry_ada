# OpenCV Geometry for Ada

Thick Ada binding to OpenCV Geometry, published as `opencv_geometry`.
Repository: https://github.com/zackboll/opencv_geometry_ada

The only production Ada dependency is `opencv_core`. The public package is
`OpenCV.Geometry` on both OpenCV versions:

| Native OpenCV | Header | Native implementation |
| --- | --- | --- |
| 4.x | `opencv2/imgproc.hpp` | `libopencv_imgproc` |
| 5.x | `opencv2/geometry.hpp` | `libopencv_geometry` |

Both link native OpenCV Core. There is no Ada Imgproc dependency.
Configuration searches pkg-config packages `opencv5`, `opencv4`, then `opencv`,
reports the actual version/backend and generates the install GPR configuration.

Initial operations: `Contour_Area`, `Arc_Length`, `Compute_Moments`,
`Convex_Hull`, `Approximate_Curve`, `Bounding_Rect`, `Is_Convex`, and
`Hu_Moments`.
`Contour` is a subtype of `OpenCV.Core.Point_Array`; storage stays
Ada-owned. `Convex_Hull` returns
hull points, not source indices. `Hull_Orientation` defaults to
counterclockwise using OpenCV's convention (X right, Y up); image coordinates
that increase Y downward may look reversed. `Approximate_Curve` applies
Douglas-Peucker; `Epsilon` is the maximum deviation in the range
`0.0 <= Epsilon < 1.0E30` and `Closed` connects the last vertex to the first.
Empty input yields an empty Ada-owned contour. `Bounding_Rect` returns an
upright axis-aligned `OpenCV.Core.Rect`. Integer extent is inclusive, so a
point set spanning X=0..4 and Y=0..3 has Width=5 and Height=4. Empty input
returns (0, 0, 0, 0). Negative native origins are preserved as signed
`OpenCV.Core.Rect` X/Y values. Inclusive extents that
cannot be represented as signed 32-bit width or height are rejected.
`Is_Convex` tests contour convexity and does not depend on winding direction.
The contour is expected to be simple; OpenCV leaves the result for
self-intersecting contours undefined. Empty, one-point, two-point, and
collinear contours are not convex. Integer contours whose native signed-32-bit
edge or cross-product arithmetic would overflow are rejected.

Moments include all 24 spatial, central and normalized fields through order 3.
Handle zero `M_00` before deriving a centroid; self-intersecting contours can
produce surprising results under Green's formula.
`Hu_Moments` takes an existing `Moments_Result` and returns the seven raw Hu
invariants indexed `1 .. 7`, not logarithmically transformed values.
Compose as `Hu_Moments (Compute_Moments (Points))`. The invariants are
unchanged by translation, scale, rotation, and reflection except the seventh,
whose sign changes under reflection.
If native Hu computation produces a non-finite value that cannot be represented
by `Float64_Value`, `Hu_Moments` raises `OpenCV_Error`.

Architecture: thick Ada -> thin Ada C interop -> C ABI -> C++ shim -> OpenCV.
No STL, C++ exceptions or native objects cross the C ABI. Native errors become
`OpenCV.OpenCV_Error`. No Core module bridge or Core shim is used by this shim.

Linux uses GNU g++, libstdc++ and a static-PIC shim. macOS and Windows build
the C++ shim outside GPRbuild so it cannot inherit Core's Ada C++ shim:
macOS uses Apple clang++, libc++ and a dylib; Windows uses a MinGW
DLL/import library from the same prefix as OpenCV, not GNAT's g++.

## Development

Place Core at `/home/zboll/git/opencv/core` alongside this repository at
`/home/zboll/git/opencv/geometry` (or use the same sibling layout elsewhere).
Install Alire, a native Ada/GPRbuild toolchain, OpenCV development files and
pkg-config. From the Geometry repository run:

```sh
alr -n build
alr -n -C tests run
```

Cross-platform CI validates Ubuntu OpenCV 4 and Homebrew/MSYS2 OpenCV 5,
including native shim dependencies. Licensed under Apache-2.0.
