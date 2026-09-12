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

Initial operations: `Contour_Area`, `Arc_Length`, `Compute_Moments`, and
`Convex_Hull`. `Contour` is a subtype of `OpenCV.Core.Point_Array`; storage
stays Ada-owned. `Convex_Hull` returns hull points, not source indices.
`Hull_Orientation` defaults to counterclockwise using OpenCV's convention
(X right, Y up); image coordinates that increase Y downward may look reversed.
Moments include all 24 spatial, central and normalized fields through order 3.
Handle zero `M_00` before deriving a centroid; self-intersecting contours can
produce surprising results under Green's formula.

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
