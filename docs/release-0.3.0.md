# OpenCV Geometry 0.3.0 release notes

`opencv_geometry` 0.3.0 adds batch point transforms and an opt-in hardened
Float32 convex intersection, makes two version-gated features available on
every supported OpenCV release, requires `opencv_core` 0.5.0, and adds
Debian 12 GNAT 12 support, a generated API reference with developer guides,
and installed redistribution notices.

**AdaCore GNAT 12 and Yocto Scarthgap are not qualified.** By maintainer
decision (2026-10-14), this release ships without that testing; see
[Deferred AdaCore GNAT 12 / Yocto Scarthgap testing](#deferred-adacore-gnat-12--yocto-scarthgap-testing).
The Debian AArch64 reference evidence below does not make either a tested
or supported configuration.

The controlling qualification record, with exact source identities,
commands and results, is
[`geometry-0.3.0-release-qualification.md`](geometry-0.3.0-release-qualification.md).

## Requirements

- `opencv_core >=0.5.0 & <0.6.0`. Core 0.5.0 (tag `0.5.0`, commit
  `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`) is the first Core release that
  builds with GNAT 12. Core 0.3.x and 0.4.x are no longer accepted, so a
  project that also requires Core `~0.4` cannot resolve with Geometry 0.3.0.
- Native OpenCV 4.x with `imgproc` (`opencv2/imgproc.hpp`,
  `libopencv_imgproc`) or OpenCV 5.x with `geometry` (`opencv2/geometry.hpp`,
  `libopencv_geometry`), both with `opencv_core`, found through
  `pkg-config` (`opencv5`, `opencv4`, then `opencv`). There is no Ada Imgproc
  dependency.
- Alire dependencies: `opencv` and `pkg_config` (external), and
  `mingw_w64_gcc` on Windows.
- Compilers qualified for this release: Debian 12 `gnat-12` 12.2.0 with
  Debian's GPRbuild 2023, and Alire `gnat_native` 16.1.0 with GPRbuild 26.
  No other compiler is claimed.

## Changes since 0.2.0

The release contains pull requests #18 to #42 and the release-candidate
changes listed under [Packaging](#packaging-and-redistribution-notices).

### Public API additions

Three public functions are new in `OpenCV.Geometry`. No public declaration
was removed or changed.

- `Transform_Points`, two overloads, for `Affine_Transform_2D` and
  `Perspective_Transform_2D` with a `Float32_Point_Array`. Each result
  element equals `Transform_Point` for the same point. Bounds, order and
  cardinality are preserved, coefficients are validated even for empty
  input, and any failed mapping raises `OpenCV_Error` without a partial
  result. Pure Ada; no native call. See
  [batch point transforms](batch-point-transforms.md).
- `Intersect_Convex_Polygons_Extended_Float32`, an opt-in convex
  intersection for ordinary fractional binary32 polygons on OpenCV 4.6
  through 5.x. It never calls native `intersectConvexConvex`: a private
  hardened copy of OpenCV's bounded 4.11 algorithm with the 4.12 binary64
  segment expressions runs on every version. Each polygon needs 3 to 4096
  strictly convex vertices with finite coordinates of magnitude at most
  `2.0**30` and a conditioning margin of `1.0E-4`; ambiguous input raises
  `OpenCV_Error`. See
  [universal Float32 intersection](universal-float32-intersection.md).

The grid-restricted Float32 `Intersect_Convex_Polygons` overload and its
safety contract are unchanged.

### Compatibility implementations

Two operations that 0.2.0 offered only on newer native releases now work on
every supported release, with no new declarations:

- `Closest_Ellipse_Points` on OpenCV 4.6 to 4.11 uses a private backport of
  OpenCV 4.12's Float32 algorithm; 4.12+ and 5.x call the native
  implementation.
- `Subdiv2D.Create_Float32`, `Reset_Float32` and `Bounds_Float32` on OpenCV
  4.6 to 4.12 use a private backport of 4.13's Float32 initialization;
  triangulation, location, nearest queries and Voronoi stay native. 4.13+
  and 5.x call native `Rect2f` initialization.

`Is_Natively_Supported` still reports the native capability, so it returns
False for these features before 4.12 and 4.13 respectively. Code that
checked it before calling keeps working; calls that raised `OpenCV_Error`
on older OpenCV in 0.2.0 now succeed.

### C ABI and shim

The shim adds `opencv_geometry_intersect_convex_convex_extended_f32`. The
C ABI is internal to this crate; rebuild the shim with the Ada library.
The compatibility code lives in private headers under `cpp/`.

### Core dependency

The constraint changes from `>=0.2.0 & <0.4.0` (0.2.0) to
`>=0.5.0 & <0.6.0`. Geometry needs no source change for Core 0.5.0. See
[Core compatibility](core-compatibility.md).

### GNAT 12 and Debian 12

Geometry builds and runs with Debian 12's native GNAT 12.2.0 in the
release, validation and development profiles. Only one test needed a
change: GNAT 12 warns about `Vertex_Count in 0 .. 3` on a `Natural` value,
so the test now uses the equivalent `<= 3`. No production source changed.

### Documentation and compiled examples

A GNATdoc 26 API reference with a searchable operation browser, Ada
highlighting, verified type links, and five developer guides whose examples
compile and run in CI:

- geometry fundamentals and contours;
- shape fitting and intersections;
- affine and perspective geometry;
- Delaunay and Voronoi;
- compatibility, ownership and safety.

Generation reports zero GNATdoc warnings and documents 452 of 452 public
items. The site is built by `sh scripts/generate_docs.sh` and published from
`main` to <https://zackboll.github.io/opencv_geometry_ada/>. See
[documentation](documentation.md).

### Tests and qualification tooling

- The AUnit suite grows from 524 tests in 0.2.0 to 542. Four native C++
  tests (closest-ellipse equivalence, extended convex intersection,
  Subdiv2D Float32 equivalence and Subdiv2D allocation-fault injection) run
  under AddressSanitizer and UndefinedBehaviorSanitizer.
- `tests/gnat12/run_production.sh`: Debian 12 GNAT 12 production build and
  test qualification from exact commits.
- `tests/installed_consumers/`: GPRinstall prefixes and independent Ada and
  mixed Ada/C++ consumers, built without sources or Alire, before and after
  relocation.
- `scripts/cross_build_geometry.sh` and `tests/cross/`: a fail-closed
  AArch64 cross configuration with synthetic controls, the Debian AArch64
  reference qualification, and an external-input adapter for an AdaCore
  GNAT 12 / Yocto Scarthgap environment.

### Research without API change

The 3-D `fitLine` safety gate (PRs #18 and #19), the native risk
reassessment (#24) and upstream reproducer drafts (#25) are documented
research. They change no binding status.

## Packaging and redistribution notices

The compatibility code is adapted from OpenCV, from Joseph O'Rourke's
convex-polygon intersection, and, through OpenCV's `solveFast`, from Carl
Chatfield's MIT-licensed `ellipse_trig_free.py`. The new
[`THIRD_PARTY_NOTICES`](../THIRD_PARTY_NOTICES) file reproduces each of
those notices verbatim, with upstream Git blob identities, and the C++
headers now carry them verbatim too. OpenCV's `LICENSE` is the same
Apache-2.0 text as this crate's.

GPRinstall now installs `LICENSE` and `THIRD_PARTY_NOTICES` into
`share/doc/opencv_geometry/` of the Geometry prefix and fails if either is
missing. Keep both files with every source or binary redistribution. The
installed-consumer and AArch64 reference qualifications check that the
installed copies match the verified sources, before and after relocation.

The Alire manifest still declares `licenses = "Apache-2.0"`, the crate's
own license.

## Platforms and qualification

| Configuration | Toolchain | Native OpenCV | Scope |
| --- | --- | --- | --- |
| Debian 12 x86_64 | Debian GNAT 12.2.0, GPRbuild 2023 | 4.6.0 (Debian) | Production library and shim in three profiles, AUnit, native sanitizer tests, installed and relocated consumers |
| Debian 12 x86_64 to AArch64 (reference) | Debian `gnat-12-aarch64-linux-gnu` 12.2.0, GPRbuild 26 | 4.6.0 (Debian arm64 packages) | Cross build, install, consumer link, loader closure; consumers and AUnit under `qemu-aarch64` user-mode emulation |
| Linux x86_64 | Alire GNAT 16.1.0 | Exact upstream tags 4.6.0, 4.10.0, 4.11.0, 4.12.0, 4.13.0, 4.14.0, 5.0.0 | Release and validation AUnit, native sanitizer tests |
| Ubuntu 24.04 x86_64 (hosted) | Alire GNAT 16.1.0 | 4.6.0 | AUnit in two profiles, native tests, independent Core 0.5.0 consumer |
| macOS ARM64 (hosted, Homebrew) | Alire GNAT 16.1.0 | 5.0.0 | AUnit |
| Windows x86_64 (hosted, MSYS2) | Alire GNAT 16.1.0 | 5.0.0 | AUnit |
| AdaCore GNAT 12 / Yocto Scarthgap | Not available | Not available | **Not qualified: deferred by the maintainer** |

The Debian AArch64 reference uses Debian's cross compiler and a Debian arm64
sysroot. It is neither the AdaCore toolchain nor a Yocto sysroot, and
emulation is not target execution. No result here was obtained on target
hardware.

The release-candidate results are recorded in the qualification record,
section REL-003-007.

## Installation

### Alire

Once Core 0.5.0 and Geometry 0.3.0 are in the Alire community index:

```sh
alr with opencv_geometry^0.3.0
alr build
```

When this release was prepared, Core 0.5.0 was not yet indexed
([alire-index#2227](https://github.com/alire-project/alire-index/pull/2227)
was open), so Geometry 0.3.0 could not be indexed either. Until then, pin
both crates to their release commits:

```sh
alr with opencv_core --use=https://github.com/zackboll/opencv_core_ada.git \
  --commit=f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f
alr with opencv_geometry --use=https://github.com/zackboll/opencv_geometry_ada.git \
  --commit=0.3.0
```

On Debian 12, Alire can use the distribution's GNAT 12 and GPRbuild
(`gnat-12`, `gprbuild`) as external tools. Alire reports Debian's GPRbuild
2023 as version 18.0.0:

```sh
alr toolchain --select gnat_external=12.2.0 gprbuild=18.0.0
```

### GPRinstall (without Alire)

The qualified sequence is `tests/installed_consumers/prepare.sh`:

1. install Core into its own prefix with `gprinstall -P opencv_core.gpr`;
2. in a Geometry source tree, run `sh scripts/configure_opencv.sh` (it writes
   `config/opencv_geometry_install.gpr`) and provide
   `config/opencv_geometry_config.gpr` (Alire generates it;
   `tests/gnat12/opencv_geometry_config.gpr` is a non-Alire equivalent);
3. build with `GPR_PROJECT_PATH=<core-prefix>/share/gpr gprbuild -P
   opencv_geometry.gpr`;
4. install `opencv_geometry_shim.gpr` and then `opencv_geometry.gpr` into a
   Geometry prefix with `gprinstall -p --prefix=<geometry-prefix>`.

Consumers add both `share/gpr` directories to `GPR_PROJECT_PATH` and
`with "opencv_geometry";`. On Linux the installed libraries are static-PIC
archives, and the prefixes may be moved.

## Intentionally deferred native operations

These remain unbound in 0.3.0 (see [coverage](coverage.md)):

- Float32 `minEnclosingTriangle`: the native search can fail to return.
- `approxPolyN` (4.11+): no portable numerical-safety contract.
- `minEnclosingConvexPolygon` (4.13+): finite input can make the native
  code read out of bounds in 4.13.0, 4.14.0 and 5.0.0.
- `fitLine` on 3-D point sets: `SAFETY_GATE_NOT_ESTABLISHED`.
- Native Float32 `intersectConvexConvex` for input off a binary grid; use
  `Intersect_Convex_Polygons_Extended_Float32` instead.

## Deferred AdaCore GNAT 12 / Yocto Scarthgap testing

The release qualification originally made an AdaCore GNAT 12 AArch64
cross toolchain with a Yocto Scarthgap sysroot a mandatory gate. Neither
was available, the gate was never satisfied (`ADACORE_YOCTO_QUALIFICATION_BLOCKED`),
and on 2026-10-14 the maintainer decided that 0.3.0 may ship without it.
Its disposition is:

**`DEFERRED_BY_MAINTAINER — NOT YET QUALIFIED`**

This is not a pass. Do not treat AdaCore GNAT 12 or Yocto Scarthgap as a
tested or supported configuration of 0.3.0. Execution on target hardware
is also outside this release.

### Post-release testing and corrective releases

1. The maintainer runs `tests/cross/qualify_adacore_yocto.sh` against the
   immutable `0.3.0` tag and Core 0.5.0, with the AdaCore GNAT 12 AArch64
   toolchain, the Scarthgap sysroot and a provenance record. It must print
   all four qualification states, and target execution is recorded
   separately if hardware is available.
2. The results are recorded on `main` with exact identities. The 0.3.0 tag,
   its source and its Alire manifest are never changed.
3. A defect that can be fixed compatibly is corrected in 0.3.1, branched
   from the `0.3.0` tag, with narrowly scoped changes, a regression test for
   each, the mandatory gates repeated, and the AdaCore/Yocto gate run on the
   0.3.1 candidate. A fix that needs an incompatible API change waits for
   0.4.0.
4. Only a release that passes that gate may describe AdaCore GNAT 12 /
   Yocto Scarthgap as tested, and only for the exact configuration tested.
