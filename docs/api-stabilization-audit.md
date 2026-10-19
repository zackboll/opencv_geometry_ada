# GEOM-029 API stabilization audit

This audit records the source review of `opencv_geometry` at the start of
GEOM-029 and the disposition of every finding. The reviewed tree started at
`2101e5c8757898b6904becfb899247e9f685c25b`. The correction is
`2fd9a036a4b5d43b61cc483e88983a8d947fe498`.

The review covered the public Geometry operations, the C ABI, and the native
count arithmetic those operations hand to OpenCV. It did not add operations.
Classifications are:

- `REQUIRED_BEFORE_MAINTENANCE`: a defect closed before maintenance
- `OPTIONAL_ENHANCEMENT`: useful later, not a maintenance blocker
- `UPSTREAM_BLOCKED`: OpenCV behavior prevents a safe binding
- `DEFERRED_BY_SAFETY_POLICY`: deliberately unbound by an existing safety gate
- `OUT_OF_SCOPE`: not a Geometry operation

## Closed before maintenance

Both count defects were `REQUIRED_BEFORE_MAINTENANCE`. Ada rejects the counts
before packing. The shim repeats the checks only as ABI safety, because native
OpenCV performs the overflowing signed arithmetic before it validates the
count.

| Operation | Native arithmetic | Ada and ABI limit |
| --- | --- | --- |
| `Minimum_Area_Rectangle` | rotating calipers allocates three binary32 values per hull vertex | `Integer_32'Last / 3` |
| `Minimum_Enclosing_Triangle` | hull allocation uses signed `total + 2` | `Integer_32'Last - 2` |

The integer rectangle overload uses the same limit. Every Float32 point can be
a hull vertex, and the integer overload reaches the same native allocator
through its hull.

Two failure-output defects, also `REQUIRED_BEFORE_MAINTENANCE`, are closed in
the shim. `opencv_geometry_intersect_convex_convex` sets `*out_area` to zero,
and `opencv_geometry_rotated_rectangle_intersection` sets `*out_kind` to
`OPENCV_GEOMETRY_RECTANGLES_INTERSECT_NONE`, before any argument rejection or
exception return. `*out_count` was already cleared. A raw C caller therefore
does not observe a stale area or classification after a failed call.

Regression tests reject the two oversized counts and check that failed convex
and rotated-rectangle calls clear the area, kind, and count.

No public semantic validation is duplicated in the C++ shim. The retained
count checks prevent native signed overflow, and the output initialization
prevents a failed ABI call from publishing a stale result.

## Not a defect

Integer `approxPolyDP` cleanup multiplies coordinate differences after
promoting them to `double` (`successive_inner_product` in `approx.cpp`,
OpenCV 4.10 imgproc and 5.0 geometry). A research probe of the existing
integer API, built with ASan and UBSan against OpenCV 4.10.0 and run under
`timeout 15`, returned three vertices and exited zero. It reported no
sanitizer error. The probe was not part of the suite and is not retained.
Float32 `Approximate_Curve` keeps its existing span limit.

## Deferred operations

| Operation | Classification | Disposition |
| --- | --- | --- |
| `approxPolyN` | `DEFERRED_BY_SAFETY_POLICY` | Finite convex input can develop sentinel and NaN heap candidates. No binding in this audit. |
| `minEnclosingConvexPolygon` | `UPSTREAM_BLOCKED` | Examined 4.13.0, 4.14.0, and 5.0.0 builds read out of bounds for finite input. Open PR 30111 is unreleased and still returns non-minimal polygons. |
| `Fit_Line_3D`, including L2 | `DEFERRED_BY_SAFETY_POLICY` | Core 0.5.0 supplies the shared 3D points, but neither eigen backend has a complete portable rounding-aware contract. Finite unit output can follow internal overflow. |
| Float32 `Minimum_Enclosing_Triangle` | `DEFERRED_BY_SAFETY_POLICY` | The integer search can already fail to return. Binary32 input adds tolerances, spans, and signed zeros that divide by zero. |
| Image modes and image processing | `OUT_OF_SCOPE` | Raster moments, grayscale bounds and shape matching, contours, components, Hough, warping, and drawing stay out of Geometry. |

`Is_Natively_Supported` may report `approxPolyN` as available on OpenCV 4.11
and later. That query is not binding coverage.

## Linux qualification

The correction was qualified on Linux only. macOS, Windows, Debian AArch64,
and GNATprove were not rerun for this audit.

The Linux matrix ran `2fd9a036a4b5d43b61cc483e88983a8d947fe498` against Core
0.5.0 (`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`) and Core 0.5.1
(`64d8a60b59acfe4334045280e430c4774b5cad89`). Every cell passed release and
validation AUnit 547/547 with no failed assertions or unexpected errors, and
passed all four native tests with no sanitizer report:

| OpenCV | Backend | Core 0.5.0 | Core 0.5.1 |
| --- | --- | --- | --- |
| 4.6.0 | `imgproc` | pass | pass |
| 4.10.0 | `imgproc` | pass | pass |
| 4.14.0 | `imgproc` | pass | pass |
| 5.0.0 | `geometry` | pass | pass |

The registered suite count is 547. The same tree at
`2101e5c8757898b6904becfb899247e9f685c25b` ran 542 tests; the five added tests
are three Subdiv2D chunking cases and two Voronoi facet cases. The count-guard
and failure-output regression assertions were added to existing suites; they
do not account for the five-case increase.

Debian 12 GNAT 12.2.0, in `localhost/core-rel007-native-prereqs:20261017`,
built the same Geometry commit with Core
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` and clean AUnit 26.0.0 sources. Its
production script printed:

    PASS GNAT 12.2.0 production, 547/547 AUnit in 3 profile(s) (release validation development), native tests; Geometry 2fd9a036a4b5d43b61cc483e88983a8d947fe498, Core f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f

## Maintenance readiness

The public contracts, C ABI, and coverage table now agree on the two count
limits and on the cleared intersection outputs. No deferred operation above
is required before maintenance. This audit does not merge, tag, or change the
Alire index.