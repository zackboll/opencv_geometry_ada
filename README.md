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
`Convex_Hull`, `Approximate_Curve`, `Bounding_Rect`, `Is_Convex`,
`Hu_Moments`, `Match_Shapes`, `Locate_Point`,
`Signed_Distance_To_Contour`, `Minimum_Enclosing_Circle`, and
`Minimum_Area_Rectangle`, and `Get_Rotation_Matrix_2D`.
`Contour` is a subtype of `OpenCV.Point_Array`; storage stays
Ada-owned. `Convex_Hull` returns
hull points, not source indices. `Hull_Orientation` defaults to
counterclockwise using OpenCV's convention (X right, Y up); image coordinates
that increase Y downward may look reversed. `Approximate_Curve` applies
Douglas-Peucker; `Epsilon` is the maximum deviation in the range
`0.0 <= Epsilon < 1.0E30` and `Closed` connects the last vertex to the first.
Empty input yields an empty Ada-owned contour. `Bounding_Rect` returns an
upright axis-aligned `OpenCV.Rect`. Integer extent is inclusive, so a
point set spanning X=0..4 and Y=0..3 has Width=5 and Height=4. Empty input
returns (0, 0, 0, 0). Negative native origins are preserved as signed
`OpenCV.Rect` X/Y values. Inclusive extents that
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
`Match_Shapes` compares two contours with OpenCV Hu-moment matching.
Lower scores indicate more similar shapes. `Reciprocal_Log_Difference`,
`Log_Difference`, and `Relative_Log_Difference` select OpenCV I1, I2, and I3.
Relative comparison is directional because the Left contour supplies the
denominator. The unused native OpenCV parameter is not exposed. If native
matching produces a non-finite value that cannot be represented by
`Float64_Value`, `Match_Shapes` raises `OpenCV_Error`.
`Locate_Point` classifies a binary32 query as inside, on the boundary, or
outside a contour. `Signed_Distance_To_Contour` returns OpenCV's signed
distance: positive inside, zero on the boundary, negative outside. Empty
contours are outside and return the largest finite negative distance.
`Minimum_Enclosing_Circle` returns the smallest enclosing circle as a
binary32 center and radius, including OpenCV's native EPS. Empty input is
center (0, 0) and radius 0. Integer contours whose native signed-32-bit pair
addition or subtraction would overflow are rejected.
`Minimum_Area_Rectangle` returns `OpenCV.Rotated_Rect`, preserving native
binary32 center, size, and angle-in-degrees fields. OpenCV 4.x and 5.x may use
different width/height/angle representations for the same rectangle; no output
normalization is applied. Inputs unsafe for native integer convex-hull
arithmetic are rejected.

## Rotation matrix

API:

```ada
function Get_Rotation_Matrix_2D
  (Center : OpenCV.Float32_Point;
   Angle  : OpenCV.Float64_Value;
   Scale  : OpenCV.Float64_Value := 1.0;
   Units  : OpenCV.Angle_Unit := OpenCV.Degrees)
   return OpenCV.Core.Mat;
```

`Get_Rotation_Matrix_2D` is a transform generator. It does not warp an
image. The returned Mat is always:

```text
Rows     = 2
Columns  = 3
Depth    = Float64
Channels = 1
```

and is suitable for affine warping operations such as
`OpenCV.Image_Processing.Warp_Affine`. There is no Ada Imgproc dependency;
callers that already use Imgproc can pass this Core Mat through.

`Angle` may be supplied in `Degrees` or `Radians`. `Degrees` is the default
because that matches `cv::getRotationMatrix2D`. Finite angles are reduced
modulo one full turn before any radians-to-degrees conversion, so large
finite values cannot overflow the conversion. There is no OpenCV unit flag.

Positive angles are counter-clockwise according to OpenCV's image-coordinate
convention (origin at the top-left). The rotation center maps to itself.

`Scale` is isotropic and defaults to `1.0`. Finite zero and negative Scale
values are mathematically defined by OpenCV and remain accepted.

`Center.X`, `Center.Y`, `Angle`, and `Scale` must all be finite. NaN and
`+/-Infinity` raise `OpenCV.OpenCV_Error`.

OpenCV 4 implements the native call from the legacy Imgproc header;
OpenCV 5 implements it from Geometry. The public Ada API does not expose
that split.

The `opencv_core` crate still distributes the parent package. `OpenCV.Core`
continues to own `Mat`. Geometry does not redeclare `Point`,
`Point_Array`, `Size`, `Rect`, `Scalar`, `Float32_Point`,
`Rotated_Rect`, `Angle_Unit`, or `Float64_Value`.

This relocation is source-breaking. Callers that previously wrote
`OpenCV.Core.Point_Array` or `OpenCV.Core.Rect` must update
qualification to the root `OpenCV` package.

`Contour` remains a subtype of the shared point array:

```ada
subtype Contour is OpenCV.Point_Array;
```

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
