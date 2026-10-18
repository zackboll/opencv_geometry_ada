# Core compatibility

## Core 0.5.1 tooling patch (GEOMETRY-REL-004)

Geometry 0.3.1 preserves `opencv_core >=0.5.0 & <0.6.0`. Core 0.5.0
(`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`) remains supported on
previously qualified platforms. Core 0.5.1
(`64d8a60b59acfe4334045280e430c4774b5cad89`, annotated tag object
`4190bb68c0b089475db4fb385349bc6d2a62cb31`) supplies corrected tooling
for the specifically qualified GNAT Pro 25.2 / Scarthgap environment; it
is not a new global minimum. Core's production `src/` and `cpp/` trees
are also identical between these releases. Geometry needs no 0.5.1-only API.

The [0.3.1 candidate record](geometry-0.3.1-release-qualification.md)
distinguishes indexed Core 0.5.0 resolution from temporary immutable-source
Core 0.5.1 qualification. An open index PR is not index availability.
The minimum-dependency documentation fixture remains Core 0.5.0.

## Historical Task 023: Core 0.4.x compatibility

This is the historical Task 023 record. GEOMETRY-REL-003 replaced the
constraint with `>=0.5.0 & <0.6.0`; see [Core 0.5.0](#core-050-geometry-rel-003)
below.

Baseline: `beed29fa63a3ef1bc0450d1433367e32611373a0`, the merge of
Geometry PR #21. Qualification changes no production Ada source, C ABI,
native algorithm, ownership model, or Geometry version (still 0.2.0).
Historical release evidence remains in `release-0.2.0.md`.

## Exact dependency sources

| Core | Immutable source commit | Qualification source |
| --- | --- | --- |
| 0.2.0 | `d273c674bd24ca32e1a714245c41ce2ab2a89696` | Indexed release, temporary version pin |
| 0.3.0 | `0e2753be8ea05fc972ec452c32b975f9e9b3912f` | Indexed release, temporary version pin |
| 0.4.0 | `99867564ad5d4560a95ed18038104771a1673ac6` | Unpinned public-index resolution after widening |
| 0.4.1 | `386c5360ac51f2b62e522853d94290aec4ee14a0` | Temporary immutable Git pin |

Core repository: <https://github.com/zackboll/opencv_core_ada>.
The annotated release tags were peeled and compared with indexed origins.
Core 0.4.1 index [PR #2208](https://github.com/alire-project/alire-index/pull/2208)
was OPEN and unmerged during qualification. Do not infer public-index
availability from the successful pinned builds. The production manifest
contains no Core pin. The independent test consumer deliberately pins the
exact 0.4.1 commit, outside the production crate's dependency graph.

Constraint before: `>=0.2.0 & <0.4.0`.
Constraint after qualification: `>=0.2.0 & <0.5.0`.
The minimum remains 0.2.0; no claim is made for future Core 0.5.x.

## Source/API evidence

Comparisons use the exact commits above, not Core main:

- `src/opencv.ads` is identical between 0.3.0 and 0.4.1. Shared Point,
  Point_Array, Size, Rect, Scalar, Float32/Float64 values, Angle_Unit and
  OpenCV_Error therefore retain their declarations and representations.
  The 0.2.0-to-0.3.0 root change only adds Int8_Value; Geometry does not
  require it.
- Geometry's only Core Mat-producing operation is
  `Get_Rotation_Matrix_2D` (`src/opencv-geometry.adb`). It uses public
  `Core.Create` and `Core.Float64_Access.Set`, passing six doubles through
  Geometry's ABI, never a Mat handle. Those declarations and Float64_Access
  bodies are unchanged. Core 0.4.1's new UMat overloads do not make these
  calls ambiguous.
- In `src/opencv-core.adb`, Mat Initialize/Adjust/Finalize retain the native
  header ownership protocol. Adjust constructs a distinct reference-counted
  header; Finalize nulls the handle before destruction. Assignment shares
  storage, while Clone remains independent. The consumer tests survival
  after the original header's finalization and public typed access.
- Core's module-interoperability additions in
  `src/opencv-core-module_interop.ads` and
  `cpp/opencv_core_module_bridge.hpp` add UMat callbacks/resolvers. Geometry
  neither imports this bridge nor borrows Core native objects. No new Core
  bridge or Core shim dependency is introduced into Geometry's native shim.
- `opencv_core.gpr`, `scripts/configure_opencv.sh`, and the Float64 accessor
  source are unchanged across the examined 0.2.0-to-0.4.1 range.
  `opencv_core_shim.gpr` adds C++ source metadata for externally built
  Windows libraries and installs `libopencv_core_shim.dll.a` beside the DLL.
  This corrects installed-consumer metadata, without changing Geometry's
  separate MSYS2 compiler or DLL/import-library strategy.
- Geometry still uses Linux GNU/static-PIC, Apple clang++/libc++/@rpath,
  and external MSYS2/MinGW shims. Its native dependencies remain Core plus
  imgproc on OpenCV 4, or Core plus geometry on OpenCV 5. Core's own Ada Mat
  implementation may link its shim; Geometry's C++ shim does not.

No Geometry production source changes are required. No public semantic
validation is duplicated in the C++ shim by this task; no shim guards change.

## Local qualification

The starting indexed Core 0.3.0/OpenCV 4.10.0 baseline passed 525/525 AUnit
tests. Each full normal or validation suite registers 525 tests, with zero
failed assertions and zero unexpected errors in successful runs.

| Native OpenCV | Backend | Core 0.3.0 | Core 0.4.1 |
| --- | --- | --- | --- |
| 4.10.0 | imgproc | Normal + validation + native | Normal + validation + native |
| 4.12.0 | imgproc | Normal + validation + native | Normal + validation + native |
| 4.13.0 | imgproc | Normal + validation + native | Normal + validation + native |
| 4.14.0 | imgproc | Normal + validation + native | Normal + validation + native |
| 5.0.0 | geometry | Normal + validation + native | Normal + validation + native |

Core 0.2.0 additionally passes the complete normal suite on OpenCV 4.10.0.
Unpinned indexed Core 0.4.0 passes normal and validation suites on 4.10.0.
OpenCV 4.6.0 is not installed locally; hosted Ubuntu CI supplies the older
native release check, with its actual version reported in the job log.

Native qualification runs `scripts/run_native_tests.sh`: closest-ellipse
equivalence, Subdiv2D allocation-failure injection, and Float32 Subdiv2D
equivalence/reset/ownership, compiled with ASan and UBSan. This instruments
the included Geometry shim/backports and test code, not the prebuilt native
OpenCV libraries themselves. Portable ellipse and Float32 bounds remain
covered on 4.10.0; Is_Natively_Supported semantics are unchanged.

Each matrix cell uses a separate temporary checkout and records Alire
resolution, root compilation, normal/validation results, native results,
and `ldd` runtime resolution. Evidence is retained under
`/tmp/geometry023-matrix/core{030,041}-cv<VERSION>/`. The host system package
detector reports OpenCV 4.10.0 even when pkg-config selects a custom native
installation. The generated install GPR, build log and runtime library paths,
not that external-package label, establish the actual native version.
Custom 4.12/4.13/4.14 installations are under
`/tmp/geometry021-matrix/install-<VERSION>`; 5.0.0 is under
`/tmp/features-008a-install500`. Validation profiles are reset to release.

Reproduce release qualification with a temporary pin (do not commit it):

```sh
alr -n pin opencv_core --use=https://github.com/zackboll/opencv_core_ada.git \
  --commit=386c5360ac51f2b62e522853d94290aec4ee14a0
alr -n with --solve
alr -n -C tests with --solve
alr -n build
alr -n -C tests run
alr -n -C tests build --profiles=opencv_geometry=validation
alr -n -C tests run
sh scripts/run_native_tests.sh
alr -n -C tests build --profiles=opencv_geometry=release
alr -n pin --unpin opencv_core
alr -n -C tests/compatibility run
```

## Co-resolution and remaining limits

Read-only clones of Features main `87058d4a87e0bf9412b7f877017a1bc1e11c9c27`
and Calib3D main `8a4a09c573ccb2086650a644a6e688ed8fa577b5` both require
Core `~0.4.0`, which overlaps Geometry's widened constraint. However,
Features pins Core `386c5360...` and Calib3D pins `4da9d35e...`; Alire rejects
the combined solution with **Conflicting pin links for crate opencv_core**.
Neither repository was modified. Their pins must converge before a combined
consumer can build; widening Geometry alone cannot resolve conflicting pins.
Neither Features nor Calib3D is currently available in the inspected index.

## Hosted CI

Linux and macOS ARM64 retain existing platform checks, now with explicit
Core 0.3.0/0.4.1 commit matrices and assertions of the actual Alire dependency
checkout. CI no longer checks out unrelated Core main. Linux runs both full
profiles and native sanitizers, plus the independent 0.4.1 consumer.
Windows retains its main-push/manual-dispatch-only policy and now explicitly
pins 0.4.1. It is intentionally skipped on PR and feature-branch push events.
The exact final-head run results and actual hosted OpenCV versions belong in
the PR review report; configuration alone is not a cross-platform pass.

## Core 0.5.0 (GEOMETRY-REL-003)

| Core | Immutable source commit | Qualification source |
| --- | --- | --- |
| 0.5.0 | `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` (tag `0.5.0`, merge of Core PR #82) | Temporary immutable Git pin; Alire index [PR #2227](https://github.com/alire-project/alire-index/pull/2227) open at qualification time |

Constraint before: `>=0.2.0 & <0.5.0`. Constraint after: `>=0.5.0 & <0.6.0`.

Core 0.5.0 is the first Core release that builds with GNAT 12 (Core PRs #77
to #81). No GNAT 12 back-port to Core 0.4.x exists. The maintainer chose to
require Core 0.5.0, so every resolvable Geometry 0.3.0 build can satisfy the
GNAT 12 release platform. The earlier Core 0.3.0 and 0.4.1 legs were
removed from the cross-platform CI; their results above remain historical
evidence for Geometry 0.2.x. A combined consumer that also requires Core
`~0.4.x` cannot resolve with Geometry 0.3.0.

Source and API evidence, Core 0.4.1 to 0.5.0:

- no public declaration was removed or renamed;
- the root `OpenCV` package adds 3-D point types only;
- `OpenCV.Core` adds region and destination overloads;
- the private `Mat` record gains a field, so Core must be rebuilt;
- `Float64_Access` changes in comments only.

Geometry uses `Mat`, `Create`, `Float64_Access` and the root value types,
all unchanged. Between the development commit `8f1c5d0` and the release
`f8aef00`, Core changes only its version, changelog, README, documentation
and a consumer-validation script; no `src/` or `cpp/` file changes.
Geometry needs no source change for Core 0.5.0. Qualification results are
in [the release record](geometry-0.3.0-release-qualification.md).