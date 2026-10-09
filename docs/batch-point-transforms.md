# Batch affine and perspective point transforms

`OpenCV.Geometry.Transform_Points` has two overloads taking an
`Affine_Transform_2D` or `Perspective_Transform_2D` and a
`Float32_Point_Array`. No new public types, dependencies or C ABI are needed.

## Numerical and failure contract

Each result at index I is exactly `Transform_Point (Transform, Points (I))`.
The existing scalar arithmetic is authoritative: left-to-right binary64
linear forms, then binary32 output conversion; finite coordinates and finite
coefficients of magnitude at most `1.0E+269`; binary32 output-range checks.
Perspective evaluation divides U and V by every nonzero W, including tiny
and negative W. Zero W raises `OpenCV_Error`.

Transform coefficients are validated first, including for an empty input.
For a valid transform an empty array preserves its original null range.
Nonempty arrays are processed in Ada index order through `Points'Range`.
Bounds, ordering, cardinality and inputs are preserved, including bounds
adjacent to `Natural'Last`. The result is local until all points succeed;
any failed mapping raises `OpenCV_Error` without publishing a partial array.
The coefficient check reuses the existing scalar validator with a finite
placeholder point; it does not evaluate that point or add numerical policy.

## Native comparison

Reviewed OpenCV 4.10 declarations in `opencv2/core.hpp` and dispatch in
`modules/core/src/matmul.dispatch.cpp`, and the available OpenCV 5.0 source
in `modules/core/src/matmul.simd.hpp`. Native `transform` supports general
channel-wise linear mappings; the Float32 path uses float coefficients and
arithmetic (including optimized paths). Native `perspectiveTransform` uses
double coefficients, maps `|W| <= FLT_EPSILON` to zero, and otherwise
multiplies the numerators by `1 / W`. These are not exact equivalents of the
Ada numerical contract. No native transform call is added here.

## Point correspondence and registration

Construct an affine transform with three correspondences or a perspective
transform with four, then batch-map a larger set of feature points. The
tests use fractional pixel locations spanning an 800 by 600 image region
and map units spanning hundreds, with a well-conditioned projective fixture.
Batch/scalar comparisons use exact equality. Known geometric coordinates
use an absolute tolerance of `1.0E-4`, independently of exact arithmetic
equivalence, to allow native solver and binary32 rounding.

## Safety qualification scope

The established SPARK arithmetic helpers are unchanged. The public package
body, scalar validation and new batch loops are outside SPARK. Consequently
the batch indexing and bounds postconditions are runtime-qualified, not
claimed as formally proved: identical `Points'Range` constraints and direct
index iteration require no offset arithmetic, and normal and assertion/
validity suites exercise shifted, maximum-index and multiple null ranges.
Validity suppression is confined to the new input-passing operations, as in
the scalar operations, so NaN/Infinity reach the existing explicit checks
and raise `OpenCV_Error` instead of `Constraint_Error`.

## Task 024 executed qualification

Starting main: `34c31fecef6a70db3ba456553225680ec2340b35` (PR #22 merged).
Baseline OpenCV 4.10/Core 0.4.0: 525/525 AUnit tests.
Six batch tests were added without weakening existing cases: 531 registered.

| OpenCV | Backend | Core 0.3.0 normal / validation | Core 0.4.1 normal / validation |
| --- | --- | --- | --- |
| 4.6.0 | imgproc | 531/531 / 531/531 | 531/531 / 531/531 |
| 4.10.0 | imgproc | 531/531 / 531/531 | 531/531 / 531/531 |
| 4.12.0 | imgproc | 531/531 / 531/531 | 531/531 / 531/531 |
| 4.13.0 | imgproc | 531/531 / 531/531 | 531/531 / 531/531 |
| 4.14.0 | imgproc | 531/531 / 531/531 | 531/531 / 531/531 |
| 5.0.0 | geometry | 531/531 / 531/531 | 531/531 / 531/531 |

Core releases were checked out at immutable release commits:
0.3.0 `0e2753be8ea05fc972ec452c32b975f9e9b3912f` and
0.4.1 `386c5360ac51f2b62e522853d94290aec4ee14a0`.
OpenCV 4.6 ran in the existing Debian 12 Podman environment; other versions
ran against local Linux installations. OpenCV 4.11 was not available.
All successful batch points were compared exactly with scalar results;
registration expectations used the separate geometric tolerance above.
All runs had zero failed assertions and unexpected errors.

Established GNATprove scope: Float32_Points, Convexity, Intersection,
Transforms, and imported Core Safe_Arithmetic. Baseline and final:
277 total checks, 277 proved (92 flow, 185 prover), 0 unproved, 0 justified;
delta zero. GNATprove FSF 16.1.0 used `--level=2 --timeout=30 -j2`,
`--checks-as-errors=on --output-header` through the tests environment.
One intervening proof attempt failed during concurrent build/profile setup;
the final isolated invocation completed successfully. No changed SPARK code
or unproved arithmetic obligations were introduced.

All existing native tests ran with AddressSanitizer and
UndefinedBehaviorSanitizer on each of the six OpenCV versions, including
Subdiv2D allocation-fault injection, Float32 equivalence/ownership, and
closest-ellipse equivalence. All passed without sanitizer diagnostics.
GNATformat checks, the Ada 79-column check, and `git diff --check` passed.
Scalar implementation and proof helpers are unchanged. No C++ or C ABI
change was made; no public semantic validation is duplicated in the C++ shim.

Hosted Linux and macOS ARM64 qualification must be checked on the final PR
head. Windows MSYS2 is intentionally skipped for feature pushes and PRs;
its unchanged full job runs only for main pushes or manual dispatch. A
Windows skip is not a Windows test pass. No releases, tags or submissions
are part of this task.