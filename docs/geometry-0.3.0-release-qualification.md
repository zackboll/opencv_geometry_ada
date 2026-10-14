# opencv_geometry 0.3.0 release qualification (GEOMETRY-REL-003)

This is the controlling record for preparing `opencv_geometry` 0.3.0. It
records, for every phase, the exact sources, commands, compiler and runtime
identities, native OpenCV version, disposition and unresolved blockers.

Nothing in this document authorizes a tag, a GitHub release or an Alire
index submission. Publication (REL-003-008) needs every mandatory gate to
pass on the exact release-candidate commit and explicit maintainer
authorization.

A result applies only to the exact source revisions it names. A Core result
at one commit does not certify another Core commit, and a development-branch
result does not certify the release candidate.

## Phase status

| Phase | Subject | Disposition |
| --- | --- | --- |
| 000 | Release inventory and Core prerequisite gate | `CORE_RELEASE_PREREQUISITE_PENDING` |
| 001 | Debian 12 GNAT 12 production and runtime | `GNAT12_NATIVE_BUILD_QUALIFIED`, `GNAT12_NATIVE_RUNTIME_QUALIFIED` against provisional Core `8f1c5d0`; repeat on Core 0.5.0 |
| 002 | Debian 12 installed consumers | `DEBIAN12_GNAT12_INSTALLED_CONSUMERS_QUALIFIED` against provisional Core `8f1c5d0`; repeat on Core 0.5.0 |
| 003 | Isolated AArch64 cross configuration | `CROSS_CONFIGURATION_CONTROLS_QUALIFIED` (synthetic positive and negative controls; not production cross-build qualification) |
| 004 | Debian AArch64 reference qualification | Not started |
| 005 | AdaCore GNAT 12 / Yocto Scarthgap | `ADACORE_YOCTO_QUALIFICATION_BLOCKED` |
| 006 | Release regression and CI matrix | Not started |
| 007 | Release candidate 0.3.0 | Not started; blocked by 000 and 005 |
| 008 | Tag and Alire index submission | Requires maintainer authorization |

## Source identities

Recorded 2026-10-14 after fetching all three remotes.

| Source | Identity |
| --- | --- |
| Geometry `main` (campaign base) | `268bf7e67288d2aeb1d30c9eb4e683c8f1f49285` |
| Geometry tag `0.2.0` | `42afa67a2f7c42c04612d3a019e5fdd029cea257` |
| Core `main` (PR #81 merge) | `8f1c5d0626b463c291a4d919767f7a2d77c54ba9`, version `0.5.0-dev` |
| Core tag `0.4.1` | `386c5360ac51f2b62e522853d94290aec4ee14a0` |
| Core tag `0.3.0` | `0e2753be8ea05fc972ec452c32b975f9e9b3912f` |
| Imgproc `main` | `98c5fcc4` (PR #68 merge) |
| Alire community index `stable-1.4.0` | `068f3873c7732229d4d586836882266494a6d50d` |

Open pull requests at the start: none on Geometry or Imgproc; Core #81 only,
which merged during the inventory (2026-10-14T05:58:03Z).

## REL-003-000: release inventory

### Changes since 0.2.0

`0.2.0..268bf7e` contains PRs #18 to #35 (49 commits, 104 files). Most of
the line count is generated API documentation, research evidence and
GNATdoc tooling.

Public API additions in `OpenCV.Geometry`:

- `Transform_Points`, two overloads (affine and perspective), from PR #23,
  batch point transforms. See `docs/batch-point-transforms.md`.
- `Intersect_Convex_Polygons_Extended_Float32`, from PR #26, an opt-in
  hardened Float32 convex intersection that never calls native
  `intersectConvexConvex`. See `docs/universal-float32-intersection.md`.

Behavior made universal across the supported OpenCV range, without new
public declarations:

- `Closest_Ellipse_Points` on OpenCV 4.6 to 4.11 through a private
  compatibility backport (PR #20); native on 4.12+ and 5.x.
- `Subdiv2D.Create_Float32` / `Reset_Float32` on OpenCV 4.6 to 4.12
  through a private initialization backport (PR #21); native on 4.13+/5.x.

C ABI and shim additions:

- `opencv_geometry_intersect_convex_convex_extended_f32`, with its Ada
  import in `OpenCV.Geometry.Internal.C_API`.
- Private C++ compatibility headers: `cpp/closest_ellipse_compat.hpp`,
  `cpp/convex_intersection_compat.hpp`, `cpp/strict_convex_validation.hpp`
  and `cpp/subdiv2d_compat_license.hpp` (upstream-derived code; see
  REL-003-007 for the redistribution review).

Tests: new AUnit units for affine and perspective transforms and the
extended Float32 intersection; extended Subdiv2D bounds and versioned
feature tests. Native C++ tests: closest-ellipse equivalence, extended
convex intersection, Subdiv2D Float32 equivalence, plus the existing
Subdiv2D fault injection. Research probes live under `tests/native/research`
and are not built by the library or the test suite.

Documentation: the GNATdoc site, guides and compiled examples
(PRs #27 to #35), with zero GNATdoc warnings and 452/452 public-item
coverage recorded at PR #31 and later.

Dependency change: the manifest constraint was widened from
`opencv_core >=0.2.0 & <0.4.0` (indexed 0.2.0) to `>=0.2.0 & <0.5.0`
(PR #22). The indexed Geometry 0.1.0 and 0.2.0 both still declare
`>=0.2.0 & <0.4.0`.

### Inclusion decision

All merged work since 0.2.0 belongs to 0.3.0. No unrelated feature is merged
on `main`. Research-only material (`tests/native/research`, the research
scripts and research documents) stays in the source tree; it is not part of
any library, test or consumer build.

Unmerged historical branches (for example `feature/013-*` to `feature/016-*`
and `feature/019-fit-line-3d`) are not part of the release.

### Intentionally deferred native operations

These stay deferred in 0.3.0; release hardening does not change them
(`docs/coverage.md`):

- `minEnclosingTriangle` for Float32 point sets.
- `approxPolyN` (4.11+): unresolved numerical-safety contract.
- `minEnclosingConvexPolygon` (4.13+): native out-of-bounds reads.
- `fitLine` on 3-D point sets: `SAFETY_GATE_NOT_ESTABLISHED` (task 020).
- Float32 `intersectConvexConvex` off a binary grid through the native
  operation; the opt-in extended Float32 operation covers that input
  without calling native code.

## REL-003-000: Core prerequisite gate

### Findings

- Core 0.4.1 (`386c536`) is the newest indexed Core. It predates the
  GNAT 12 compatibility work (Core PRs #77 to #81) and is not an ancestor
  of Core `main`; the merge base is 0.4.0 (`9986756`).
- `maintenance/opencv_core-0.4.x` equals tag 0.4.1. No GNAT 12 back-port
  exists on any 0.4.x branch, and there is no 0.4.2 tag.
- Core PR #81 merged as `8f1c5d0`. All its pull-request checks passed on
  head `242299e`, including the hosted Debian 12 GNAT 12 production job;
  MacPorts and Windows MSYS2 run only on `main` pushes. At the time of the
  inventory, the first post-merge `main` runs had passed GNAT 12 native,
  source units and cross configuration, with OpenCV compatibility
  (including the first Windows and MacPorts runs of the GNAT 12 change)
  still in progress.
- Core `main` declares version `0.5.0-dev`. No 0.5.0 tag, release PR or
  Alire index entry exists. A Core 0.5.0 version bump is being prepared
  separately; it is not part of this campaign.
- Between 0.4.1 and `main` no public Core declaration was removed or
  renamed. Geometry uses `OpenCV.Core.Mat`, `Create`, `Float64_Access` and
  root value types, all unchanged.
- Semantic-versioning note: `0.5.0-dev` satisfies `<0.5.0`, because a
  pre-release orders before its release. That is why a local `../core` pin
  at Core `main` resolves under Geometry's current bound. The released
  Core 0.5.0 will not satisfy it.

### Decision

Qualify Geometry 0.3.0 against **Core 0.5.0**, released from Core `main`
after #81, rather than a GNAT 12 back-port to Core 0.4.x.

- Core `main` already carries all GNAT 12 production fixes, with hosted
  Debian 12 GNAT 12 production, AUnit and installed-consumer evidence. A
  0.4.x back-port would re-apply about 70 body changes, the per-unit
  language policy and the Float16 layout work to a branch that diverged at
  0.4.0, and it would need its own complete qualification.
- Core 0.5.0 is already in preparation, so a back-port would duplicate a
  release the maintainer is producing anyway.
- No Geometry source change is expected. Geometry `268bf7e` compiled
  unchanged against Core `8f1c5d0` under Debian GNAT 12 (exploratory
  diagnosis below).

The manifest constraint is not changed in this phase. Choosing the 0.3.0
bound (for example `>=0.5.0 & <0.6.0`, or a range that still admits
Core 0.3.0/0.4.x on GNAT 16) is a REL-003-007 decision, made against the
actual published Core 0.5.0 and its API.

### Provisional and final Core identities

- Provisional development candidate for building infrastructure:
  Core `8f1c5d0626b463c291a4d919767f7a2d77c54ba9`. It is immutable, but it
  is not a release; results against it are development evidence only.
- Final candidate: the Core 0.5.0 release commit, once published and
  indexed. Every mandatory gate must be repeated against that commit.

Disposition: `CORE_RELEASE_PREREQUISITE_PENDING` until Core 0.5.0 is
published and indexed.

### Core 0.4.1 reference audit

These references must be reconciled with the released Core dependency in
REL-003-006. Historical evidence keeps the Core version it actually used.

| Location | Reference | Planned handling |
| --- | --- | --- |
| `.github/workflows/cross-platform.yml` | Linux/macOS matrix Core 0.3.0 and 0.4.1 by commit; Windows job and its pin checks at `386c536`; independent consumer step | Add the released Core 0.5.0 leg; decide whether 0.3.0/0.4.1 legs remain (depends on the 0.3.0 bound) |
| `.github/workflows/documentation.yml` | Core checkout at `386c536` | Move to the released Core 0.5.0 commit |
| `scripts/generate_docs.sh` | `core_release=0.4.1`, `core_commit=386c536` | Move to the released Core 0.5.0 commit; regenerate and re-verify 0 warnings and 452/452 |
| `tests/compatibility/alire.toml` | `opencv_core = "=0.4.1"`, Git pin `386c536` | Retarget to the released Core 0.5.0 |
| `README.md` lines 25 to 26 | Supported constraint and Core 0.4.1 qualification | Update at REL-003-007 |
| `docs/documentation.md` | Core 0.4.1 reproduction steps | Update with the documentation pin |
| `docs/core-compatibility.md`, `docs/batch-point-transforms.md`, `docs/universal-float32-intersection.md`, `docs/coverage.md` row text | Historical Core 0.3.0/0.4.0/0.4.1 qualification | Keep as historical evidence; add new results, do not rewrite |
| `docs/fit-line-3d-research.md`, `docs/gnatdoc-campaign-progress.md` | Historical | Unchanged |

## Platform input inventory

Recorded 2026-10-14 on the qualification host (Debian 13, x86_64, rootless
Podman 5.4.2; Docker is not installed).

### Platform A: Debian 12 x86_64

Available from Debian 12 (`bookworm`) packages: `gnat-12` and `g++-12`
`12.2.0-14+deb12u1`, `gprbuild` `2023.0.0-3` (its banner reads
"GPRBUILD Pro 18.0w (19940713)"), `libopencv-dev` `4.6.0+dfsg-12`,
`gnat-12-aarch64-linux-gnu` and `g++-12-aarch64-linux-gnu`
`12.2.0-14cross1`, and `qemu-user-static` `1:7.2+dfsg-7+deb12u18+b3`.

### Platform B: AdaCore GNAT 12 and Yocto Scarthgap

Not found. The host, `/opt`, `/usr/local`, `/srv`, `/mnt`, `/media`, the
user's home directory, the Alire cache and the local Podman image layers
contain no AdaCore GNAT 12 AArch64 Linux compiler, runtime, GPRbuild or
GPRinstall, and no Yocto Scarthgap SDK, `environment-setup-*` script,
`version-*` file or AArch64 sysroot. The only AArch64 Ada cross compilers
present are Debian's `gnat-12-aarch64-linux-gnu` (inside container images)
and an unrelated FSF GCC 13.4 build. Neither substitutes for the requested
toolchain. Imgproc's earlier adapter work (PR #68,
`docs/imgproc-ext-002c-adacore-cross.md`) recorded the same absence.

Disposition: `ADACORE_YOCTO_QUALIFICATION_BLOCKED`. The REL-003-005 states
`ADACORE_GNAT12_CROSS_BUILD_QUALIFIED`, `YOCTO_SCARTHGAP_SYSROOT_QUALIFIED`,
`GEOMETRY_YOCTO_CROSS_INSTALL_QUALIFIED` and
`GEOMETRY_YOCTO_CONSUMER_LINK_QUALIFIED` stay pending until the maintainer
supplies the toolchain and sysroot.

## Exploratory GNAT 12 diagnosis (not qualification)

Purpose: size the REL-003-001 work before building qualification tooling.

- Environment: `debian:12` plus `gnat-12 gnat gprbuild g++ g++-12
  libaunit22-dev libopencv-dev pkg-config git ca-certificates file
  binutils make`; GCC `12.2.0-14+deb12u1`; OpenCV 4.6.0, `imgproc` backend.
- Sources: `git archive` exports of Geometry `268bf7e` and Core `8f1c5d0`;
  AUnit 26.0.0 sources.
- Core configuration: Core's own `tests/gnat12/opencv_core_config.gpr`.
  Geometry and tests: Alire's generated development switch set
  (`-Og -g -gnatwa -gnatw.X -gnatVa -gnaty... -gnatW8`) plus the projects'
  own `-Werror`.

Results:

- The Geometry production library, including the C++ shim, built without
  errors or warnings.
- The AUnit harness failed: GNAT 12 reports
  `float32_convex_intersection_tests.adb:962:60: warning: lower bound check
  only fails if it is invalid [-gnatwc]` for
  `Corner.Vertex_Count in 0 .. 3` on a `Natural` component, and
  warnings are errors. That unit then also reported 21 Core
  `opencv-internal-c_api.ads` size-mismatch errors. Those are a cascade:
  GNAT evaluates those deferred size checks after back-end annotation,
  which does not happen once the unit has failed.
- With the condition written as `Corner.Vertex_Count <= 3` in the
  diagnostic copy only, the harness built and all 542 AUnit tests passed.
  All four native C++ tests, including Subdiv2D fault injection, built with
  g++ 12 under AddressSanitizer and UndefinedBehaviorSanitizer and passed.

This diagnosis is not a qualification result. REL-003-001 repeats it with
checked-in tooling, all production profiles and a negative-first test.

## REL-003-001: Debian 12 GNAT 12 production and runtime

### Tooling

`tests/gnat12/run_production.sh` qualifies the complete production library
and C++ shim with Debian 12's native compiler, independent of Alire
toolchain selection. It:

- requires clean Geometry and Core Git checkouts, the Core one at the exact
  commit given in `GNAT12_CORE_COMMIT`, and exports both with `git archive`
  into a fresh workspace that must contain no prebuilt `.ali`, `.o`, `.a`
  or `.so` file;
- requires `gcc` and `g++` 12.2.0 for `x86_64-linux-gnu`, the
  `/usr/lib/gcc/x86_64-linux-gnu/12/adalib` runtime and OpenCV 4.6.0;
- builds Core with Alire's release switch set, as an Alire dependency is
  built, and Geometry in each Alire build profile (release, validation,
  development), using `tests/gnat12/*_config.gpr`, which reproduce
  Alire 2.1.1's generated switch sets without forcing an Ada version;
- requires the OpenCV 4 `imgproc` backend, `-lopencv_imgproc` and
  `-lopencv_core`, and the Linux `Static_PIC` shim;
- fails on any warning in a build log, and on any language-version switch
  other than Core's documented per-unit Ada 2022 typed-access body (whose
  presence proves that the scan reads compile commands);
- builds the AUnit harness (the tests crate is always an Alire root, so
  it uses the development set) and requires 542 registered tests, 542
  successful, 0 failed assertions and 0 unexpected errors per profile;
- runs the four native C++ tests under AddressSanitizer and
  UndefinedBehaviorSanitizer, including Subdiv2D allocation-failure
  injection, and requires every one to run;
- requires every ALI to read `V "GNAT Lib v12"`, every object and archive
  to carry only `GCC: (Debian 12.2.0-14+deb12u1) 12.2.0`, and the test
  executables to have no unresolved dependency.

`.github/workflows/gnat12-production.yml` runs it on `debian:12` with the
packages `ca-certificates curl unzip git binutils gnat-12 gprbuild g++
libopencv-dev pkg-config`. Alire 2.1.1 only fetches AUnit 26.0.0 sources
(`alr -n get --only aunit=26.0.0`); it selects no compiler.

### GNATprove and GNATcov in the tests crate

`tests/alire.toml` depends on `aunit ^26.0.0`, `gnatprove ^16.1.0` and
`gnatcov ^26.2.1`. None of the three declares a compiler dependency
(`alr show`), so they do not themselves select GNAT 16; the toolchain is
whatever `alr toolchain` selects. Their binary archives provide only
`bin/gnatprove` and `bin/gnatcov`, which shadow no compiler. The GNAT 12
qualification does not use `tests/alire.toml` at all: it builds
`tests/tests.gpr` directly with AUnit from source, so proof and coverage
tooling stays out of the mandatory GNAT 12 path.

### Finding and correction (negative first)

GNAT 12 with `-gnatwa -gnatVa` reports, for
`Corner.Vertex_Count in 0 .. 3` on a `Natural` discriminant,
`float32_convex_intersection_tests.adb:962:60: warning: lower bound check
only fails if it is invalid [-gnatwc]`; the harness treats warnings as
errors. GNAT 16 does not report it. The failed unit then also prints 21
`opencv-internal-c_api.ads` size errors. These are a cascade: GNAT checks
those deferred size conditions only after back-end annotation, which does
not happen once a unit has failed. Any compile error in a client of
`OpenCV.Core` shows the same cascade under GNAT 12 (it reappeared during
REL-003-002 consumer development for an unrelated error). It is noisy but
harmless, and is recorded here for Core.

Correction: the equivalent `Corner.Vertex_Count <= 3`. No production
source changes; the shim is unchanged.

### Evidence

Core: provisional `8f1c5d0626b463c291a4d919767f7a2d77c54ba9`. Packages:
`gnat-12`, `gcc-12`, `g++-12`, `libgnat-12` `12.2.0-14+deb12u1`,
`gprbuild` `2023.0.0-3`, `libopencv-dev` `4.6.0+dfsg-12`. AUnit 26.0.0.

| Geometry commit | Where | Result |
| --- | --- | --- |
| `862eec46e445d96cb929e420d098c2355e649b31` (tooling only) | Local mirror image | FAIL as expected: release-profile production library and shim built without warnings; the AUnit harness failed on the `-gnatwc` warning and its cascade |
| `862eec4` | Hosted run 38521130562 (push) | FAIL as expected, same warning in the uploaded log |
| `618ee6dc933e2e6012e290171a56a710e089a436` (correction) | Local mirror image | PASS: 3 profiles × 542/542, 4/4 native tests, 639 GNAT 12 ALIs, 391 objects and archives all from Debian GCC 12.2.0 |
| `618ee6d` | Hosted runs 38521249165 (push), 38521253403 (pull request) | PASS: 3 × 542/542, 647 compiler records all Debian GCC 12.2.0 |
| `618ee6d` | Hosted Cross-Platform Geometry CI 38521249151, 38521253392 (GNAT 16) | PASS; the correction is neutral under GNAT 16 |

Local command (mirror of the hosted job, image built from the same package
list; the workspace and sources are separate mounts):

```sh
podman run --rm \
  -v "$GEOMETRY_CLONE:/sources/geometry:ro" \
  -v "$CORE_CLONE:/sources/core:ro" \
  -v "$AUNIT_26_SOURCES:/sources/aunit:ro" \
  -v "$EVIDENCE/work:/work" \
  -e GNAT12_WORK=/work/gnat12-qualified \
  -e GNAT12_CORE_ROOT=/sources/core \
  -e GNAT12_CORE_COMMIT=8f1c5d0626b463c291a4d919767f7a2d77c54ba9 \
  -e GNAT12_AUNIT_ROOT=/sources/aunit \
  -e GNAT12_SOURCE_ROOT=/sources/geometry \
  "$DEBIAN12_GNAT12_IMAGE" sh /sources/geometry/tests/gnat12/run_production.sh
```

Dispositions, as development evidence against the provisional Core:
`GNAT12_NATIVE_BUILD_QUALIFIED` and `GNAT12_NATIVE_RUNTIME_QUALIFIED`. The
release gate repeats this job against the published Core 0.5.0 and the
release-candidate commit.

## REL-003-002: Debian 12 installed consumers

### Two stages

Preparation (`tests/installed_consumers/prepare.sh`, Debian 12 builder with
GNAT 12.2.0, GPRbuild 2023 and OpenCV 4.6.0):

1. `tests/gnat12/run_production.sh` in the release profile: production
   build, 542/542 AUnit tests and the native tests, at the exact commits.
2. `gprinstall -P opencv_core.gpr -p -r` from that tested Core tree into a
   clean `core-prefix`.
3. A fresh `git archive` export of Geometry, configured natively and built
   against the installed Core only (`GPR_PROJECT_PATH` is the Core prefix's
   `share/gpr`). `gprls -v` must report the installed Core source and
   object directories, and neither the build log nor `gprls` may name the
   Core build tree.
4. `gprinstall -p` of `opencv_geometry_shim.gpr` and then
   `opencv_geometry.gpr` into a separate `geometry-prefix`, without `-r`, so
   Core is not reinstalled.
5. Installed-content checks: projects, specifications, ALIs (`GNAT Lib
   v12`), archives (only Debian GCC 12.2.0 objects), the shim's
   `Linker_Options` (`-lopencv_imgproc -lopencv_core -lstdc++`), no Core
   content in the Geometry prefix or Geometry content in the Core prefix,
   no build, source or payload path in any installed project, and no
   reference from the Geometry shim objects to a Core shim symbol (`nm`).

Consumer (`tests/installed_consumers/consume.sh`, a separate Debian 12
container with GNAT 12, GPRbuild, g++ and OpenCV, and nothing else): it fails
if Alire, `/sources`, or any Core or Geometry source outside the payload is
present. It resolves projects only through the two installed `share/gpr`
directories and plain `gprbuild`, then builds, runs and inspects:

- an independent Ada consumer: integer `Contour_Area`, `Arc_Length`,
  `Bounding_Rect` and `Convex_Hull`; Float32 `Contour_Area`,
  `Intersect_Convex_Polygons_Extended_Float32` and `Transform_Points`;
  `Get_Rotation_Matrix_2D` read through Core's `Float64_Access`; and the
  `Subdiv2D` lifecycle (create, insert, triangles, locate, nearest, Voronoi,
  a native out-of-bounds failure raised as `OpenCV_Error` with the object
  still ready, and 100 create, insert and finalize cycles);
- a mixed Ada/C++ consumer whose own C++ unit calls `cv::contourArea`
  directly, exchanging plain values only, and must equal Geometry's result.

Both prefixes are then moved to longer paths, and the consumers are rebuilt
from fresh object directories and checked again. Every build must be free
of warnings. `gprls -v` must resolve exactly the installed Core and
Geometry directories, and the link must use the installed archives.
Executables must be x86-64 with GCC 12.2.0 code only. `ldd -r` must be
clean, with OpenCV 4.6, libstdc++ and libgnat-12 resolved from
`/usr/lib/x86_64-linux-gnu`. Every loaded library must come from a system
directory. No run path may lead into a build or payload directory, and
neither prefix may contain a shared object. Installed files are never
edited.

### Findings

- GPRinstall writes `with "opencv_core_shim"` into the installed Geometry
  projects because it withs every library project of the static closure,
  and `opencv_core` needs its shim anyway. Imgproc's installed projects
  show the same. Geometry declares no Core shim link option and its shim
  objects reference no Core shim symbol.
- GPRinstall serializes the shim project's top-level `Common_Cxx_Switches`,
  including the OpenCV include switch (`-I/usr/include/opencv4`, a system
  path), into the installed shim project. Consumers do not use it.
- Debian's GPRbuild gives consumers `$ORIGIN`-relative run paths to every
  library directory of the project closure, including the static Core and
  Geometry library directories. With static-only prefixes these can load
  nothing; the first entry is the system library directory. Applications
  that want no run path can link with `gprbuild -R`.
- An unrelated compile error in a consumer again produced the 21 cascaded
  Core size-check errors described in REL-003-001.

### Evidence

Core: provisional `8f1c5d0`.

| Geometry commit | Where | Result |
| --- | --- | --- |
| `e580bea0e302ebf006c623c8c29f7fad589b8400` | Local, `tests/installed_consumers/qualify_local.sh` (Podman) | PASS: prepare, and both consumers installed and relocated |
| `e580bea` | Hosted `Debian 12 installed consumers` 38522508988 (push) and 38522513657 (pull request) | PASS: `consumer PASS` for the Ada and mixed consumers, installed and relocated; prepare and consume as separate jobs, the consumer job without a checkout, Git or Alire |
| `e580bea` | Hosted GNAT 12 native production 38522508992 and 38522513382; Cross-Platform Geometry CI 38522508906 and 38522513602; documentation 38522513597 | PASS |

Disposition, as development evidence against the provisional Core:
`DEBIAN12_GNAT12_INSTALLED_CONSUMERS_QUALIFIED`.

## REL-003-003: isolated AArch64 cross configuration

### Mechanism

`scripts/cross_build_geometry.sh` runs `scripts/cross_geometry.py`, a
standard-library Python tool adapted from Core's `cross_build_core.sh` and
Imgproc's `cross_configuration.py`. Its operations are:

- `check` validates every input and prints the resolved settings;
- `--prepare WORKSPACE` exports the clean HEAD into a new workspace,
  generates the target configuration and builds a toolchain probe;
- `--build WORKSPACE` does `--prepare`, builds the production library and
  C++ shim, and installs both into `WORKSPACE/install`.

Inputs are explicit environment variables, with the same names as Core and
Imgproc: `OPENCV_CROSS_TARGET`, `ENV_PREFIX` (sysroot), `OPENCV_CROSS_ADA`,
`OPENCV_CROSS_CXX`, `OPENCV_CROSS_RUNTIME`, `OPENCV_CROSS_GPR_CONFIG`,
`OPENCV_CROSS_GPRBUILD`, `OPENCV_CROSS_GPRINSTALL`,
`OPENCV_CROSS_PKG_CONFIG`, `PKG_CONFIG_LIBDIR` and
`OPENCV_CROSS_CORE_PREFIX`. The optional ones are `PKG_CONFIG_SYSROOT_DIR`
(must equal the sysroot), `OPENCV_CROSS_READELF`, `OPENCV_CROSS_PROFILE`
(release by default) and `OPENCV_CROSS_INDEPENDENT_TOOLCHAINS`. Compilers
and project tools must be absolute paths. Nothing is taken from `CC`,
`CXX` or `PATH`, and `readelf` is the only inspection tool with a PATH
default. `PKG_CONFIG_PATH`, `CPATH`, `C_INCLUDE_PATH`,
`CPLUS_INCLUDE_PATH`, `LIBRARY_PATH`, `GCC_EXEC_PREFIX`, `COMPILER_PATH`,
`ADA_INCLUDE_PATH`, `ADA_OBJECTS_PATH`, `GPR_PROJECT_PATH`,
`ADA_PROJECT_PATH` and `LD_LIBRARY_PATH` must be empty.

Checks, all fail-closed:

- Toolchain:
  - an `aarch64[-vendor]-linux[-abi]` target;
  - `-dumpmachine` of both compilers equals it;
  - the Ada runtime is the compiler's own `adalib`, and `libgnat.a` is
    ELF64 little-endian AArch64;
  - the Ada and C++ compilers report the same GCC version, unless
    `OPENCV_CROSS_INDEPENDENT_TOOLCHAINS=True` records that they differ (no
    interoperability claim follows from that);
  - the C++ compiler's `libstdc++` needs no `GLIBCXX`/`CXXABI` version that
    the target lacks.
- Sysroot and metadata:
  - every `PKG_CONFIG_LIBDIR` entry, header tree, `-I`, `-L` and library
    path resolves inside the sysroot, through symbolic links, with broken
    links and cycles rejected;
  - only `-lopencv_*`, `-lstdc++`, `-D` and `-pthread` flags are accepted;
  - header and `pkg-config` versions agree;
  - SONAMEs match the version;
  - `libc` and `libstdc++` are AArch64.
- Backend: OpenCV 4.x requires `opencv2/imgproc.hpp` and
  `-lopencv_imgproc`, OpenCV 5.0 requires `opencv2/geometry.hpp` and
  `-lopencv_geometry`, and other versions are rejected. Both require
  `opencv_core`. No Ada Imgproc dependency is introduced.
- Dependency closure: every `DT_NEEDED`, recursively, is resolved as the
  target loader would. Lookup goes through the object's `RPATH`/`RUNPATH`
  (with `$ORIGIN`), then the sysroot's `ld.so.conf`, then the multiarch and
  standard directories, to an AArch64 ELF inside the sysroot. Every symbol
  version an object needs must be defined by the library resolved for it.
  A library that exists only outside the loader's search path is
  unresolved; REL-003-004 found exactly that case in a real sysroot.
- GPR configuration: it must name the target, both compilers, the runtime
  and the C++ driver as linker. Commented text does not count.
- Core prefix: it must be installed (`Externally_Built`) and must not
  overlap the checkout. Every path named by its installed projects stays
  inside the prefix or the sysroot. Its archives are AArch64, their
  `.comment` compiler identities are a subset of the identities of probe
  objects compiled by the supplied compilers, and every Core ALI reads
  `V "GNAT Lib v<major>"`. This is binary evidence, not a Core-written
  attestation; Core does not emit one.
- Workspace:
  - the destination must be new, absolute and canonical (a symlinked alias
    into a protected tree is rejected), and must not overlap the checkout,
    sysroot or Core prefix;
  - the checkout must be clean, untracked files included;
  - the exported tree must contain no `.ali`, `.o`, `.a` or `.so`;
  - a generated configuration must not already exist.

Generated configuration: `config/opencv_geometry_install.gpr` has the same
variables that `scripts/configure_opencv.sh` writes natively, with
sysroot-rooted include and library switches, the target backend library and
the supplied C++ driver. `config/opencv_geometry_config.gpr` is the Alire
profile switch set from REL-003-001. `--sysroot` is passed to C++ compiles
and links on the command line; the production GPR projects are unchanged.

Build checks: in every `gprbuild -v` trace, each compiler or linker is one
of the supplied drivers, each `gnat*` tool lies beside the Ada driver with
the target prefix, and each archiver carries the target prefix. Compiles may
name no host include or library directory and no `x86_64` path. Every
object and archive is AArch64 and carries only the supplied compilers'
identities, and every ALI has the compiler's GNAT version. Installed
projects name only paths inside the install prefix or the sysroot. The
evidence file says `production_qualified: false`.

### Synthetic controls

`tests/cross/test_cross_geometry.py` has 41 negative-first tests with fake
compilers, `readelf`, `pkg-config`, `gprbuild` and `gprinstall`. Each
rejection must leave its inputs unmodified. They cover:

- host contamination: search variables, `PKG_CONFIG_PATH`, host
  `pkg-config` directories, host flags and libraries, `-Wl,-rpath`, host run
  paths, and host compilers, binders, archivers or directories in the build
  trace;
- wrong architecture: target names, compiler targets, and X86-64, ELF32
  or big-endian objects;
- incompatible Core compiler identity or ALI version, and Core prefix
  structure and imports;
- missing headers and libraries, transitive and loader-path dependencies,
  and undefined symbol versions;
- incorrect metadata: versions, SONAMEs, unsupported releases, missing
  backend libraries, and OpenCV 5 without the geometry module;
- stale output: existing or symlinked workspaces, overlap with protected
  trees, dirty or artifact-bearing sources;
- sysroot symlink escapes, broken links and cycles;
- the reviewed GPR configuration.

Positive controls cover the OpenCV 4 and OpenCV 5 backends, the generated
configuration, a complete build and install, and an explicit
independent-toolchain record.

Mutation check: seven separate mutations, each disabling one fail-closed
check, were each detected by the suite:

- the trace driver check;
- the Core identity check;
- symlink containment;
- loader resolution;
- host-variable emptiness;
- the stale-workspace check;
- the `libstdc++` symbol versions.

`.github/workflows/cross-configuration.yml` runs the suite, `py_compile`,
`sh -n` and ShellCheck.

Disposition: `CROSS_CONFIGURATION_CONTROLS_QUALIFIED`. These are synthetic
controls of the fail-closed logic, not compiler, link or execution
evidence. The real toolchain, sysroot, Core build and links are
REL-003-004.
