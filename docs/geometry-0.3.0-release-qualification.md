# opencv_geometry 0.3.0 release qualification (GEOMETRY-REL-003)

This is the controlling record for preparing `opencv_geometry` 0.3.0. It
records, for every phase, the exact sources, commands, compiler and runtime
identities, native OpenCV version, disposition and unresolved blockers.

Nothing in this document authorizes a tag, a GitHub release or an Alire
index submission. Publication (REL-003-008) needs every mandatory gate of the
[2026-10-14 release policy](#maintainer-decision-2026-10-14-release-without-adacoreyocto-qualification)
to pass on the exact release-candidate commit, and the maintainer's own
review and merge of the release-candidate pull request.

A result applies only to the exact source revisions it names. A Core result
at one commit does not certify another Core commit, and a development-branch
result does not certify the release candidate.

## Phase status

| Phase | Subject | Disposition |
| --- | --- | --- |
| 000 | Release inventory and Core prerequisite gate | `CORE_RELEASE_PREREQUISITE_PENDING`: Core 0.5.0 is released (tag `0.5.0` = `f8aef00`), but its Alire index PR #2227 is open |
| 001 | Debian 12 GNAT 12 production and runtime | `GNAT12_NATIVE_BUILD_QUALIFIED`, `GNAT12_NATIVE_RUNTIME_QUALIFIED`; requalified against Core 0.5.0 `f8aef00` in REL-003-006 |
| 002 | Debian 12 installed consumers | `DEBIAN12_GNAT12_INSTALLED_CONSUMERS_QUALIFIED`; requalified against Core 0.5.0 `f8aef00` in REL-003-006 |
| 003 | Isolated AArch64 cross configuration | `CROSS_CONFIGURATION_CONTROLS_QUALIFIED` (synthetic positive and negative controls; not production cross-build qualification) |
| 004 | Debian AArch64 reference qualification | Reference cross build, install and consumer link PASS; emulated (qemu-user) execution PASS; target execution NOT RUN; requalified against Core 0.5.0 `f8aef00` in REL-003-006 |
| 005 | AdaCore GNAT 12 / Yocto Scarthgap | Never satisfied: `ADACORE_YOCTO_QUALIFICATION_BLOCKED` (inputs unavailable; external-input adapter ready). For 0.3.0: `DEFERRED_BY_MAINTAINER — NOT YET QUALIFIED` (maintainer decision, 2026-10-14) |
| 006 | Release regression and CI matrix | Core 0.5.0 bound and pins reconciled; every available gate PASS against Core 0.5.0; the AdaCore/Yocto gate remained blocked |
| 007 | Release candidate 0.3.0 | Candidate `4902b76`: all eight mandatory gates PASS (`GEOMETRY_0_3_0_SOURCE_RELEASE_READY` for that commit; the release PR head is requalified, see below). Alire: `CORE_INDEX_PENDING`. AdaCore/Yocto: `DEFERRED_BY_MAINTAINER — NOT YET QUALIFIED` |
| 008 | Tag and Alire index submission | After the maintainer merges the release-candidate PR; the Alire submission also waits for Core 0.5.0 to be indexed |

## Maintainer decision (2026-10-14): release without AdaCore/Yocto qualification

On 2026-10-14 the maintainer decided that `opencv_geometry` 0.3.0 may ship
on the existing Debian and cross-platform evidence, without actual AdaCore
GNAT 12 or Yocto Scarthgap validation. The maintainer will run that testing
independently and may publish a later corrective release.

This decision supersedes the mandatory AdaCore GNAT 12 / Yocto Scarthgap
(Platform B) acceptance gate that REL-003-000 to REL-003-006 defined. It
does not change their record: the original qualification requirement was
**not satisfied**. Neither input was ever available, REL-003-005 ended with
`ADACORE_YOCTO_QUALIFICATION_BLOCKED`, and none of
`ADACORE_GNAT12_CROSS_BUILD_QUALIFIED`, `YOCTO_SCARTHGAP_SYSROOT_QUALIFIED`,
`GEOMETRY_YOCTO_CROSS_INSTALL_QUALIFIED` or
`GEOMETRY_YOCTO_CONSUMER_LINK_QUALIFIED` was ever established.

AdaCore/Yocto qualification disposition for 0.3.0:

**`DEFERRED_BY_MAINTAINER — NOT YET QUALIFIED`**

Deferred testing is not successful testing. This disposition is not PASS,
and no release text may present AdaCore GNAT 12 or Yocto Scarthgap as a
tested or supported configuration of 0.3.0. The Debian AArch64 reference
uses Debian's cross GNAT 12 and a Debian arm64 sysroot; it substitutes for
neither.

### Mandatory release gates for 0.3.0

Each must pass on the exact release-candidate commit with Core 0.5.0
(`f8aef00`):

1. Debian 12 x86_64 GNAT 12 production and runtime (REL-003-001 job).
2. Debian 12 independent installed consumers (REL-003-002 job), now
   including the installed redistribution notices.
3. Debian AArch64 reference cross-build, install and consumer-link
   qualification (REL-003-004 job).
4. The existing Linux, macOS and Windows regression qualification
   (REL-003-006 matrix and hosted workflows).
5. GNATdoc generation and documentation completeness: zero warnings and
   452/452 documented public items, guide examples and site validation.
6. License and distribution packaging checks.
7. Immutable release-source qualification: exact commit and tree
   identities, a clean source export, and no production path pins.
8. A valid Alire manifest and dependency resolution.

Outside the 0.3.0 release scope: execution on target hardware, and AdaCore
or Yocto certification of any kind.

### Post-release validation and corrective releases

1. After the `0.3.0` tag exists, the maintainer runs
   `tests/cross/qualify_adacore_yocto.sh EVIDENCE` (REL-003-005) on a clean
   checkout of that tag, with Core 0.5.0, the AdaCore GNAT 12 AArch64 cross
   toolchain, the Scarthgap sysroot and `OPENCV_CROSS_YOCTO_PROVENANCE`. The
   result counts only if all four Platform B states are printed. Target
   execution, if hardware is available, is recorded separately.
2. The outcome, pass or fail, is recorded on `main` with the exact tag,
   Core, toolchain and sysroot identities. The `0.3.0` tag, its commit and
   its Alire manifest are never moved or rewritten.
3. A defect that admits a compatible correction is fixed in `0.3.1`: a
   branch from the `0.3.0` tag, narrowly scoped changes, a regression test
   for each defect, every mandatory gate above repeated on the 0.3.1
   candidate, and the AdaCore/Yocto adapter run on that candidate. A
   correction that needs an incompatible API change waits for 0.4.0.
4. Only a release whose own candidate passed that gate may describe AdaCore
   GNAT 12 / Yocto Scarthgap as tested, and then only for the exact
   configuration recorded.

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

Hosted: Cross configuration controls 38525930473 (push) and 38525937698
(pull request) on `a8daedc`, 41 tests OK. GNAT 12 native production,
installed consumers, Cross-Platform Geometry CI and documentation also
passed on `a8daedc`.

## REL-003-004: Debian AArch64 reference qualification

Public reference evidence only. Debian's `gnat-12-aarch64-linux-gnu` is not
the AdaCore GNAT 12 toolchain, the staged arm64 sysroot is not a Yocto
Scarthgap sysroot, and emulated execution is not target execution.

### Environment

`tests/cross/install_reference_tools.sh`, shared by the local
`tests/cross/Containerfile` and the hosted workflow, installs
`gcc-aarch64-linux-gnu`, `g++-aarch64-linux-gnu`,
`gnat-12-aarch64-linux-gnu` (all `12.2.0-14cross1`), `binutils`,
`pkg-config`, `python3` and `qemu-user-static`. It also installs the public
GPRbuild 26.0.0-1 x86_64 release, the one the Alire index lists for
`gprbuild=26.0.1`, verified by its index hash `e3f27f25...`. Debian 12's
GPRconfig 2023 does not recognize Debian's cross GNAT ("can't find a
toolchain for ... aarch64-linux-gnu"), while GPRconfig 26 does. The
environment contains no native `gcc`, `g++`, `gnat` or `gprbuild`; the
script verifies that.

### Steps (`tests/cross/qualify_debian_aarch64_reference.sh`)

1. Sysroot: `tests/cross/prepare_debian12_sysroot.sh` downloads the
   `libopencv-dev:arm64`, `libc6-dev:arm64`, `libstdc++-12-dev:arm64` and
   `libgnat-12:arm64` closure and unpacks the 400 arm64 and `all` packages
   without installing them, recording every package, version and SHA-256.
   It also records the 18 host-architecture packages that apt adds for
   `Multi-Arch: foreign` dependencies; none is unpacked. It applies the
   shared-library alternatives that the packages' `postinst` would
   register, `libblas.so.3` and `liblapack.so.3`, as recorded relative
   links.
2. GPR configuration: GPRconfig 26 for the Ada runtime
   `/usr/lib/gcc-cross/aarch64-linux-gnu/12` and the explicit cross `g++`.
3. Core 0.5.0-dev `8f1c5d0` cross-built and installed by its own
   `scripts/cross_build_core.sh` (release profile).
4. Geometry cross-built and installed by `scripts/cross_build_geometry.sh`
   from REL-003-003: OpenCV 4.6.0, `imgproc` backend, both compilers
   `GCC: (Debian 12.2.0-14) 12.2.0`, 211 GNAT 12 Core ALIs, a 363-ELF
   loader closure and 2,869 symbol versions checked.
5. The REL-003-002 consumers, cross-linked by
   `tests/cross/qualify_reference_consumers.py` against the installed
   prefixes and again after moving both. Links use `gprbuild -R`, so
   executables carry no run path. Each executable must:
   - be AArch64 ELF64 with the interpreter `/lib/ld-linux-aarch64.so.1`;
   - contain only Debian cross GCC 12.2.0 code;
   - resolve through a 22-ELF loader closure inside the sysroot, with 146
     symbol versions the target defines;
   - name the installed Core and Geometry archives in its link.
6. The consumers and the complete AUnit suite, cross-built in the release
   profile, run under `qemu-aarch64-static -L <sysroot>`.

### Findings

- Unpacking Debian packages runs no maintainer script, so the
  alternatives-managed `libblas.so.3` and `liblapack.so.3` were missing
  from the loader paths, and the consumer link failed on BLAS and LAPACK
  symbols. A name-anywhere dependency index (Imgproc's design) accepted
  that sysroot. The loader-semantics closure of REL-003-003 rejects it:
  "unresolved target dependency: liblapack.so.3 ... (not on the target
  loader's search path)". The sysroot preparation now applies the
  alternatives explicitly.
- GPRbuild's default consumer link embeds host run paths
  (`/usr/lib/gcc-cross/aarch64-linux-gnu/12/adalib`, and `$ORIGIN` paths
  into the build host's sysroot and prefixes). Target consumers are linked
  with `-R`, and any run path fails the check.
- The installed shim project's `Linker_Options` name the sysroot library
  directory by absolute path. That comes from the shim project's existing
  `Library_Search_Switch`; consumers cross-link on the host that holds the
  same sysroot.
- No AArch64 floating-point behavior difference surfaced: 542/542 tests
  pass under emulation, as natively.

### Evidence

| Geometry commit | Where | Result |
| --- | --- | --- |
| `ea9c1a410e23ec05bb64dc28f993ec4ab7fd5b35` | Local Podman (`tests/cross/Containerfile`) | All steps PASS |
| `ea9c1a4` | Hosted Debian AArch64 reference 38525933795 (push), 38525940473 (pull request) | All steps PASS; emulated AUnit 542/542 |

Dispositions (reference, against provisional Core `8f1c5d0`):

- `CORE_AARCH64_CROSS_BUILD_INSTALL` PASS
- `GEOMETRY_AARCH64_CROSS_BUILD_INSTALL` PASS
- `GEOMETRY_AARCH64_CONSUMER_LINK` PASS
- emulated consumer execution PASS and emulated AUnit 542/542 PASS, both
  user-mode emulation only
- target execution NOT RUN

## REL-003-005: AdaCore GNAT 12 / Yocto Scarthgap

### Inputs

Not available. Neither an AdaCore GNAT 12 AArch64 cross toolchain nor a
Yocto Scarthgap sysroot exists on the qualification host (see Platform B
above), and the maintainer confirmed on 2026-10-14 that they cannot be
supplied now. Disposition: `ADACORE_YOCTO_QUALIFICATION_BLOCKED`. The four
states
`ADACORE_GNAT12_CROSS_BUILD_QUALIFIED`, `YOCTO_SCARTHGAP_SYSROOT_QUALIFIED`,
`GEOMETRY_YOCTO_CROSS_INSTALL_QUALIFIED` and
`GEOMETRY_YOCTO_CONSUMER_LINK_QUALIFIED` stay pending, and they block
release certification.

Later on 2026-10-14 the maintainer removed this gate from the 0.3.0 release
([maintainer decision](#maintainer-decision-2026-10-14-release-without-adacoreyocto-qualification)).
The four states remain unestablished; the 0.3.0 disposition is
`DEFERRED_BY_MAINTAINER — NOT YET QUALIFIED`.

### External-input adapter

`tests/cross/qualify_adacore_yocto.sh EVIDENCE` runs the qualification once
the inputs exist. Its inputs:

- the `scripts/cross_geometry.py` variables for the AdaCore Ada driver and
  runtime, the target C++ compiler, the reviewed GPR configuration,
  GPRbuild and GPRinstall, and the Scarthgap sysroot and its pkg-config
  directories, set explicitly with no SDK script sourced;
- `OPENCV_CROSS_YOCTO_PROVENANCE`;
- the Core checkout, commit and AUnit sources;
- optionally an emulator.

It then:

1. Checks the provenance claims against binaries with
   `tests/cross/verify_target_claims.py`:
   - `yocto.release` must be `scarthgap` and must match the sysroot's
     `os-release` codename;
   - `yocto.distro` must match its `ID`;
   - `yocto.sysroot` must be `ENV_PREFIX`;
   - `toolchain.vendor` must be `AdaCore` and `gnat_major` must be 12. The
     Ada driver must report GCC 12, and `gnatls` beside it must identify
     as GNATLS Pro, or the objects it compiles must record GNAT Pro.

   Machine, image, build identity and export method are recorded as
   unverifiable claims. A missing or contradicted claim stops the run with
   `ADACORE_YOCTO_QUALIFICATION_BLOCKED`.
2. Records the SHA-256 and version of the compilers and project tools, the
   linker, the GPR configuration, `libgnat.a` and the search directories.
3. Runs `tests/cross/qualify_target.sh`, the same pipeline as the Debian
   reference:
   - Core by its own cross build;
   - Geometry by the fail-closed cross build, whose `libstdc++` symbol
     check and loader closure apply to the Yocto sysroot;
   - consumers cross-linked before and after relocation and inspected;
   - the AUnit suite cross-built;
   - optional emulation, recorded as emulation only.
4. Prints the four states only if every claim is verified and every gate
   passes.

Interoperability: Scarthgap's own C++ compiler is a later GCC than GNAT 12.
The fail-closed check then requires an explicit
`OPENCV_CROSS_INDEPENDENT_TOOLCHAINS=True`, which records the difference
and is never interoperability proof. The proof is the actual link, the
target `libstdc++` symbol-version subset check, the loader closure with
symbol versions, and execution where available. No C++ exception or
native object crosses the Geometry C ABI.

### Controls

- Nine synthetic controls (`tests/cross/test_verify_target_claims.py`):
  - verified claims with recorded evidence;
  - missing claims;
  - non-Scarthgap or contradicted codenames;
  - distribution and sysroot mismatches;
  - a sysroot without `os-release`;
  - an `os-release` link escaping the sysroot;
  - non-AdaCore toolchains;
  - either GNAT Pro identity;
  - GCC major 13.
- Real data: the Debian reference now runs through `qualify_target.sh` and
  then calls the adapter with AdaCore/Scarthgap claims about the Debian
  inputs. The adapter must block, and it does: "the sysroot has no
  os-release: the Yocto release claim cannot be verified" and "neither
  gnatls nor the compiled objects identify GNAT Pro (gnatls: 'GNATLS
  12.2.0'; objects: ['GCC: (Debian 12.2.0-14) 12.2.0'])". No qualified
  state is printed.

Local evidence on `cc40dc0`: the complete Debian reference passes through
the shared pipeline, and the negative control is rejected as described.

## REL-003-006: release regression and CI matrix

### Core bound

On 2026-10-14 the maintainer chose `opencv_core >=0.5.0 & <0.6.0`. That is
the decision REL-003-000 deferred to REL-003-007, taken in this phase so
that the regression matrix runs against the bound that will ship.

Rationale:

- Core 0.5.0 is the first Core release that builds with GNAT 12, and no
  0.4.x back-port exists.
- A range that still admitted Core 0.3.0 or 0.4.x would let Alire resolve
  Geometry 0.3.0 to a Core that cannot build on the GNAT 12 release
  platform.

Consequences:

- A combined consumer that also requires Core `~0.4.x` cannot resolve with
  Geometry 0.3.0.
- Geometry needs no source change (see `docs/core-compatibility.md`).
- The Geometry version stays 0.2.0 until REL-003-007.

### Pin reconciliation

Commit `c7aca1d` moves every row of the Core 0.4.1 reference audit, and
the development-commit pins of REL-003-001 to REL-003-004, to the Core 0.5.0
release commit `f8aef00`:

| Location | Before | After |
| --- | --- | --- |
| `alire.toml` | `>=0.2.0 & <0.5.0` | `>=0.5.0 & <0.6.0` |
| `.github/workflows/cross-platform.yml` | Linux and macOS legs at Core 0.3.0 and 0.4.1; Windows at `386c536` | One Core 0.5.0 leg at `f8aef00` on Linux, macOS and Windows, each asserting the actual Alire dependency checkout |
| `gnat12-production.yml`, `debian12-installed-consumers.yml`, `debian-aarch64-reference.yml` | Development commit `8f1c5d0` | `f8aef00` |
| `documentation.yml`, `scripts/generate_docs.sh` | 0.4.1 at `386c536` | 0.5.0 at `f8aef00` |
| `tests/compatibility/alire.toml` and its consumer | `=0.4.1`, Git pin `386c536` | `=0.5.0`, Git pin `f8aef00` |
| `scripts/run_linux_matrix_027c1.sh` | Core 0.3.0 and 0.4.1 | Adds Core 0.5.0 at `f8aef00` |
| `README.md`, `docs/documentation.md` | Core 0.4.1 constraint and reproduction | Core 0.5.0 |
| `docs/core-compatibility.md` | Task 023 record | New Core 0.5.0 section; the historical 0.3.0 and 0.4.1 evidence is unchanged |

The production manifest contains no pin. The workflow pins are temporary
and are applied inside the job. The independent compatibility consumer
keeps its exact-commit pin outside the production dependency graph.

### Consumer-step finding and correction

On `c7aca1d` the hosted Linux job failed at "Run independent Core 0.5.0
consumer" (runs 38527680055, 38527685136 and 38527747584). macOS, Windows
and every earlier Linux step passed.

`alr pin --unpin opencv_core` must solve without the path pin. While Core
0.5.0 is absent from the community index, that solve finds no
`opencv_core >=0.5.0`. In non-interactive mode Alire then declines and
leaves the path pin in place, and the consumer fails with conflicting path
and URL pins for `opencv_core`.

Correction (`0cb3ed1`): restore `alire.toml` with Git, as
`docs/documentation.md` already does. The consumer then resolves Core only
through its own exact-commit pin. The same step passed locally before the
push ("PASS Geometry / Core 0.5.0 consumer") and on every hosted run below.

### Local evidence

Geometry `c7aca1d484fbf0835a43dc9a3b39ee0961b5e20b`, Core
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`. The commit `0cb3ed1` changes
only the cross-platform workflow step above, so these results also apply
to it.

| Gate | Inputs | Result |
| --- | --- | --- |
| Debian 12 GNAT 12 production (REL-003-001 job) | Debian 12 mirror image, GNAT 12.2.0, OpenCV 4.6.0, AUnit 26.0.0 | PASS: 542/542 in the release, validation and development profiles; native tests |
| Debian 12 installed consumers (REL-003-002 job) | Same image, Podman 5.4.2 | PASS: prepare; Ada and mixed consumers, installed and relocated |
| Debian AArch64 reference (REL-003-004 job) | `tests/cross/Containerfile` image | `CORE_AARCH64_CROSS_BUILD_INSTALL` PASS at `f8aef00`; Geometry cross build, install and consumer link PASS; emulated consumers and AUnit 542/542 PASS (emulation only); target execution NOT RUN; AdaCore/Scarthgap claims on the Debian inputs REJECTED (negative control) |

GNAT 16 Linux matrix (`scripts/run_linux_matrix_027c1.sh <opencv> 0.5.0`,
Alire `gnat_native` 16.1.0). Each cell is a separate checkout. The release
and validation suites both run, followed by the native sanitizer tests, and
the release profile is restored at the end:

| Native OpenCV | Release | Validation | Native | Sanitizer findings |
| --- | --- | --- | --- | --- |
| 4.6.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.10.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.11.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.12.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.13.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.14.0 | 542/542 | 542/542 | 4/4 | 0 |
| 5.0.0 | 542/542 | 542/542 | 4/4 | 0 |

### Hosted evidence

| Geometry commit | Run | Result |
| --- | --- | --- |
| `c7aca1d` | GNAT 12 native production 38527680013 (push), 38527685031 (pull request) | PASS |
| `c7aca1d` | Debian 12 installed consumers 38527680072, 38527685294 | PASS |
| `c7aca1d` | Debian AArch64 reference 38527680056, 38527685126 | PASS |
| `c7aca1d` | Cross configuration controls 38527680194, 38527685205; documentation 38527684971 | PASS |
| `c7aca1d` | Cross-Platform Geometry CI 38527680055, 38527685136, 38527747584 (dispatch) | FAIL at the Linux consumer step only; macOS PASS; Windows PASS in the dispatch |
| `0cb3ed1dbfedddfb10fbd9c61e29744aeadca249` | GNAT 12 native production 38528963670 (push), 38528969562 (pull request) | PASS |
| `0cb3ed1` | Debian 12 installed consumers 38528963723, 38528969545 | PASS |
| `0cb3ed1` | Debian AArch64 reference 38528963711, 38528969508 | PASS |
| `0cb3ed1` | Cross configuration controls 38528963767, 38528969525 | PASS |
| `0cb3ed1` | Ada API Documentation 38528969506 | PASS: 452/452 items documented, against Core `f8aef00` |
| `0cb3ed1` | Cross-Platform Geometry CI 38528963720 (push), 38528969509 (pull request) | PASS on Linux and macOS; Windows skipped by policy |
| `0cb3ed1` | Cross-Platform Geometry CI 38528968404 (dispatch) | PASS on Linux, macOS and Windows |

Hosted versions in dispatch 38528968404, all with the Alire dependency
checkout asserted at `f8aef00`:

| Job | Native OpenCV | Results |
| --- | --- | --- |
| Linux x86_64 (Ubuntu 24.04) | 4.6.0 | 542/542 normal and validation; native tests; "PASS Geometry / Core 0.5.0 consumer" |
| macOS ARM64 (Homebrew) | 5.0.0 | 542/542 |
| Windows x86_64 (MSYS2 `mingw-w64-x86_64-opencv` 5.0.0-6) | 5.0.0 | 542/542 |

### License review

- The compatibility code derived from OpenCV keeps its notices:
  - the Intel License Agreement text in `cpp/closest_ellipse_compat.hpp`,
    `cpp/convex_intersection_compat.hpp` and
    `cpp/subdiv2d_compat_license.hpp`;
  - Joseph O'Rourke's notice for the convex intersection.
- Binary redistributions must reproduce these notices.
- The installed GPRinstall prefixes contain no license or notice file. The
  REL-003-006 consumer payload has none in either prefix.
- `opencv_geometry.gpr` declares `for Artifacts (".") use ("share");`, but
  the repository has no `share` directory, so nothing is installed.

Proposed for REL-003-007, not implemented here: install `LICENSE` and a
notices file (the Intel and O'Rourke texts) into the Geometry prefix, and
let the installed-consumer check require them.

### Release readiness

Superseded in part by the
[2026-10-14 maintainer decision](#maintainer-decision-2026-10-14-release-without-adacoreyocto-qualification):
Platform B no longer blocks 0.3.0, while Core 0.5.0 indexing still blocks
the Alire submission. The text below is the record as of REL-003-006.

The release candidate (REL-003-007) is not started. Two prerequisites are
outside this campaign's control:

1. Platform B: `ADACORE_YOCTO_QUALIFICATION_BLOCKED` (REL-003-005). The
   inputs are unavailable and the maintainer chose to keep the gate
   blocked.
2. Core 0.5.0 indexing: Alire index PR #2227 is open. Until it merges, no
   unpinned Geometry build can resolve, and Geometry 0.3.0 cannot be
   submitted.

Publication (REL-003-008) also needs explicit maintainer authorization.

Once both prerequisites are met, on the exact release-candidate commit:

1. Run `tests/cross/qualify_adacore_yocto.sh EVIDENCE` with the AdaCore
   GNAT 12 cross toolchain, the Scarthgap sysroot and
   `OPENCV_CROSS_YOCTO_PROVENANCE`. All four Platform B states must be
   printed.
2. After #2227 merges, resolve Core 0.5.0 from the index without a pin and
   repeat the cross-platform and documentation jobs on that resolution.
3. Bump the Geometry version to 0.3.0. Add the release notes and the
   README support statement. Install the notices proposed above and extend
   the installed-consumer check to require them.
4. Repeat every gate in this document on the release-candidate commit.
   Then run `alr publish` as a dry run only; the tag and the index
   submission wait for REL-003-008 authorization.

## REL-003-007: release candidate 0.3.0

### Starting state

Recorded 2026-10-14 after fetching Geometry, Core and the Alire index.

| Item | Finding |
| --- | --- |
| Geometry PRs #36 to #42 | All merged by the maintainer on 2026-10-14. `main` is `9142e9c3134ded907204ae0304acc28ab602b7a9`, the merge of #42 |
| Core tag `0.5.0` | Tag object `8f962690b3b25eafcb6c7e7363a6d097a3c22366`, commit `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` |
| Geometry Core constraint | `opencv_core = ">=0.5.0 & <0.6.0"`; `alire.toml` has no pin |
| Alire index PR [#2227](https://github.com/alire-project/alire-index/pull/2227), "Add opencv_core 0.5.0" | Open, review required, all 22 checks successful. Head `d4766195c226e4952fe78fb23d19f9b99684b870`; its only file is `index/op/opencv_core/opencv_core-0.5.0.toml` (SHA-256 `9895bc0265d856b74f489be4c69cb8988f07e5b3c05fce3571bf48fe312e3dfa`), origin commit `f8aef00` |
| Alire community index `stable-1.4.0` | `e88e083eaa59c7781622475a1ac769dd33afe16e`: Core 0.1.0 to 0.4.1 and Geometry 0.1.0 and 0.2.0; no Core 0.5.0 |
| Geometry 0.3.0 tag or release PR | None |

The release branch `release/opencv-geometry-0.3.0` starts at `origin/main`
`9142e9c` in its own worktree. No other worktree or branch was changed.

### Distribution notices

Finding (REL-003-006): no installed prefix carried a license or notice.

Review against the upstream sources, fetched by tag and checked by Git
blob identity:

- OpenCV's 40-line Intel License Agreement file header is byte-identical
  in 4.11.0 and 4.12.0 `modules/imgproc/src/geometry.cpp`, 4.12.0
  `shapedescr.cpp`, 4.13.0 `subdivision2d.cpp` and 5.0.0
  `modules/geometry/src/shapedescr.cpp`.
  `cpp/convex_intersection_compat.hpp` carried it verbatim. The headers
  `cpp/closest_ellipse_compat.hpp` and `cpp/subdiv2d_compat_license.hpp`
  carried a reworded and rewrapped text: no "IMPORTANT: READ BEFORE ..."
  preamble, and "Redistributions" for "Redistribution's".
- Joseph O'Rourke's notice: the copyright lines were verbatim, the preamble
  above them reworded.
- New finding: OpenCV's `solveFast`, copied as `solve_fast`, translates
  `ellipse_trig_free.py` of
  [0xfaded/ellipse_demo](https://github.com/0xfaded/ellipse_demo) line for
  line, and OpenCV's source cites that file. The repository is
  MIT-licensed, "Copyright (c) 2017 Carl Chatfield" (`LICENSE` blob
  `f163f238` at commit `a420f769`). No Geometry file carried that license.
- OpenCV 4.5.0 and later are Apache-2.0. OpenCV 4.12.0's `LICENSE` (blob
  `d6456956`) is byte-identical to Geometry's `LICENSE`. OpenCV has no
  `NOTICE` file at 4.11.0, 4.12.0, 4.13.0 or 5.0.0, but has a `COPYRIGHT`
  file.
- GPRinstall installs the shim's C++ body,
  `include/opencv_geometry_shim/opencv_geometry_shim.cpp`, which contains
  the adapted Subdiv2D initialization. The `.hpp` headers are not installed;
  under the default C++ naming they are not GPR sources.

Correction (commit `250942c4416cf0026fbc4a9b02fc35899470f8b9`):

- `THIRD_PARTY_NOTICES` names each piece of adapted code and its upstream
  file (tag and blob), and reproduces verbatim, between BEGIN and END lines:
  the Intel License Agreement header, OpenCV's 4.13.0 `COPYRIGHT` file
  (the 4.11.0 and 4.12.0 file lacks only the "OpenCV AI" line), O'Rourke's
  notice and the ellipse_demo MIT License. It states that OpenCV's
  Apache-2.0 text is the same as `LICENSE`.
- The three C++ headers now carry the upstream notices verbatim, the
  closest-ellipse header also the MIT License as `//` comments. These are
  comment-only changes.
- `opencv_geometry.gpr` declares
  `Required_Artifacts ("share/doc/opencv_geometry") use ("LICENSE",
  "THIRD_PARTY_NOTICES")`. A probe with Debian 12's GPRinstall 2023
  ("GPRINSTALL Pro 18.0w") showed that it installs both files with relative
  manifest entries, and fails with exit status 7 ("file does not exist") if
  one is missing. No path is written into the installed projects, so the
  prefix stays relocatable.
- `tests/installed_consumers/check_notices.sh` fails unless `LICENSE` is
  the Apache-2.0 text, every BEGIN/END block occurs exactly once with the
  SHA-256 of its upstream text, the C++ headers contain those blocks
  verbatim, and each given prefix holds byte-identical copies.
  `test_check_notices.sh` runs it on one unmodified case, which must pass,
  and 15 mutations, which must each be rejected for the intended reason:
  altered or missing lines in each block, duplicate and unclosed blocks,
  paraphrased or missing notices in each header, a changed `LICENSE`, and
  missing or stale installed copies.
- `prepare.sh` runs those controls, then the check on the Geometry prefix,
  and records the installed digests in the payload. `consume.sh` requires
  the same digests in the installed and relocated prefixes, without
  sources. The AArch64 reference consumer step
  (`qualify_reference_consumers.py`) runs the check on its installed and
  relocated Geometry prefixes, and so will the AdaCore/Yocto adapter, which
  shares that pipeline.

Pinned upstream digests:

| Block | Upstream text | SHA-256 |
| --- | --- | --- |
| `LICENSE` | Apache License 2.0; OpenCV 4.12.0 `LICENSE` | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |
| Intel License Agreement | Lines 1 to 40 of the OpenCV files above | `07088edcd6834f7c52694c468a0d591ad1acd77867849434b92de57a27f78c87` |
| OpenCV `COPYRIGHT` | 4.13.0, blob `23eb02ef` | `854538f426422b0f989a5e5b7641e5943753d10ef29ea54901dcd36039e43f58` |
| O'Rourke notice | Lines 256 to 269 of 4.11.0 and 4.12.0 `geometry.cpp` | `e9e841991f22b00d685e286179165f877314a8301e428f4e79a7de7c25829987` |
| MIT License | 0xfaded/ellipse_demo `LICENSE` at `a420f769` | `d1f3530a0383628c968e495e1793f7c279917506ff9ccf977594b2d97bcfc757` |

Not changed: `licenses = "Apache-2.0"` in `alire.toml` names the crate's own
license. Whether to declare an SPDX expression that also covers the
third-party code is left to the maintainer, because it changes published
index metadata. Outside this release: the installed Core 0.5.0 prefix
carries no license file either; that is Core packaging. This review records
engineering checks of notice obligations; it is not legal advice.

Development evidence on `250942c` (Core `f8aef00`), local:

- Debian 12 installed consumers PASS: 16/16 notice controls, notice check
  on the prepared prefix, and the recorded digests present in the installed
  and relocated prefixes (`LICENSE` `cfc7749b...`, `THIRD_PARTY_NOTICES`
  `9d1fc46a...`).
- Debian AArch64 reference PASS, with the notice check passing on the
  cross-installed prefix before and after relocation; emulated AUnit
  542/542; the AdaCore/Yocto claims on Debian inputs rejected as before.

### Version and documentation

- `alire.toml`: version `0.3.0`. The Core constraint is unchanged and the
  manifest has no pin.
- `docs/release-0.3.0.md`: the release notes.
- `README.md`: release summary, AdaCore/Yocto disposition, installation
  and redistribution notices.
- `docs/coverage.md`: the extended Float32 intersection is released.

### Release-candidate qualification

Candidate: commit `4902b762cb0b398c96b624c77171c758c81ca328`, tree
`362e8bce8f2c0f886470e026abd2f1f1ac969aeb`, with Core 0.5.0 `f8aef00`. Every
result in this section is for that exact commit. The next commit records
these results and changes only this document and the release notes. It is
requalified with the same gates, and because a commit cannot record its own
identity, its results are recorded in the release pull request.

Local evidence (Debian 13 x86_64 host, Podman 5.4.2; each gate starts from a
fresh clone at the exact commit):

| Gate | Environment | Result |
| --- | --- | --- |
| 1. Debian 12 GNAT 12 production and runtime | Image `bcc5eba3` from `tests/gnat12/Containerfile`: GNAT 12.2.0-14+deb12u1, GPRbuild 2023.0.0-3, OpenCV 4.6.0, AUnit 26.0.0 | PASS. Release, validation and development: 542/542 each, 0 failed assertions, 0 unexpected errors. Four native tests under ASan/UBSan, including Subdiv2D fault injection. 639 ALIs, all GNAT 12; 647 compiler records, all `GCC: (Debian 12.2.0-14+deb12u1) 12.2.0` |
| 2. Debian 12 installed consumers | Same image, two containers | PASS. 16/16 notice controls; notice check on the Geometry prefix; Ada and mixed Ada/C++ consumers built, run and inspected, installed and relocated, without sources or Alire; `LICENSE` and `THIRD_PARTY_NOTICES` present with the verified digests in both prefix locations |
| 3. Debian AArch64 reference | Image `101ea653` from `tests/cross/Containerfile` | PASS. Core and Geometry cross-built and installed (10 Geometry compilations; 16 AArch64 objects; 20 ALIs). Ada and mixed consumers cross-linked, installed and relocated: 22-ELF loader closure, 146 symbol versions. Notice check PASS on both prefix locations. Emulated consumers PASS; emulated AUnit 542/542 (user-mode emulation only). Target execution NOT RUN. AdaCore/Scarthgap claims on the Debian inputs REJECTED (negative control) |
| 4. GNAT 16 regression matrix | `scripts/run_linux_matrix_027c1.sh <opencv> 0.5.0`; Alire `gnat_native` 16.1.0, GPRbuild 26.0.1; exact-tag OpenCV prefixes | PASS, table below |
| 5. Documentation | Local mirror of `documentation.yml`: GNATdoc 26.0.0, markdown-it-py 3.0.0, Alire `gnat_native` 16.1.0 | PASS. 0 GNATdoc warnings (delta 0 added, 0 removed); 452/452 items documented; warning-comparison, validator, coverage, comment-only and type-link unit tests; site validation, coverage, navigation and guide tests; deterministic regeneration and idempotent enhancement; the landing-page example and five guide examples compiled and run |
| 6. License and distribution packaging | `check_notices.sh` and its controls (gates 2, 3 and 7) | PASS, see [Distribution notices](#distribution-notices) |
| 7. Immutable release source | `git archive --prefix=opencv_geometry-0.3.0/` of the commit | PASS. 269 entries, SHA-256 `7905aa4ff8043a75fdf9495db12a89044b17effadb7a3943973a370bdc395c1d`. No build output or generated configuration. `LICENSE`, `THIRD_PARTY_NOTICES`, both GPR projects and the release notes present. Manifest version 0.3.0 with the Core constraint and no pin. Notice check PASS on the export. No proprietary toolchain or sysroot path |
| 8. Alire manifest and resolution | See [Alire publisher preflight](#alire-publisher-preflight) | PASS against the candidate index; public-index resolution pending |

GNAT 16 Linux matrix, Core 0.5.0 `f8aef00`, Geometry `4902b76`:

| Native OpenCV | Release | Validation | Native | Sanitizer findings |
| --- | --- | --- | --- | --- |
| 4.6.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.10.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.11.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.12.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.13.0 | 542/542 | 542/542 | 4/4 | 0 |
| 4.14.0 | 542/542 | 542/542 | 4/4 | 0 |
| 5.0.0 | 542/542 | 542/542 | 4/4 | 0 |

Hosted evidence on `4902b76` (push to `release/opencv-geometry-0.3.0`, and a
manual dispatch):

| Run | Result |
| --- | --- |
| GNAT 12 native production 38653802256 | PASS: three profiles, 542/542 each, native tests |
| Debian 12 installed consumers 38653802237 | PASS: "independent Ada and mixed Ada/C++ consumers and redistribution notices, installed and relocated, without sources or Alire" |
| Debian AArch64 reference 38653802202 | PASS, as locally; emulated AUnit 542/542; target execution NOT RUN |
| Cross configuration controls 38653802207 | PASS: 50 synthetic tests |
| Cross-Platform Geometry CI 38653802205 (push) | PASS on Linux and macOS; Windows skipped by policy |
| Cross-Platform Geometry CI 38653885087 (dispatch) | PASS: Linux x86_64, Ubuntu 24.04, OpenCV 4.6.0: 542/542 normal and validation, native tests, "PASS Geometry / Core 0.5.0 consumer". macOS ARM64, Homebrew OpenCV 5.0.0: 542/542. Windows x86_64, MSYS2 `mingw-w64-x86_64-opencv` 5.0.0-6: 542/542 |

The Ada API Documentation workflow runs only for pull requests and on
`main`; its hosted result is recorded in the release pull request.

Engineering note: the first local attempts of the documentation and Alire
preflight runners stopped on defects in those runner scripts (a missing
execute bit, `head` under `pipefail`, a nonexistent settings directory, a
read-only index copy for `alr index --check`, `alr` not on `PATH` for the
publisher, and a missing `use type` clause in the preflight's own smoke
program). None involved the candidate; every recorded result is from a
complete rerun.

### Alire publisher preflight

Core 0.5.0 is not in the Alire community index: alire-index #2227 is
open, and `stable-1.4.0` (`e88e083e`) ends at Core 0.4.1. Public-index
resolution is therefore pending, and nothing below is public-index evidence.

Environment: the gate 1 image (Debian 12, GNAT 12.2.0, Debian GPRbuild
2023, OpenCV 4.6.0); the official Alire 2.1.1 binary (`alr` SHA-256
`2e2b8de009b793ad2aed10096e162649bbcc5b0711e3c21785ebe8a1261c5d64`, from
`alr-2.1.1-bin-x86_64-linux.zip`, SHA-256
`09c66bcd8c35dd4b97b72c3d9b76e44caa6964a2db35aba069f396f00f1f64c7`);
isolated Alire settings and home directories.

- A. Candidate index. `stable-1.4.0` `e88e083e` plus the exact #2227
  manifest (SHA-256 `9895bc02...`), with the community index disabled.
  `alr index --check` found no issues. Toolchain: `gnat_external` 12.2.0
  (`/usr/bin/gnat`) and `gprbuild` 18.0.0, which is how Alire reports Debian's
  GPRbuild 2023. A clean `git archive` export, with no pin, lock file or
  configuration, resolved `opencv_core=0.5.0` (origin `git`, commit `f8aef00`
  according to the index manifest), `opencv=4.6.0` and `pkg_config=1.8.1`
  (system). Geometry built in the development, release and validation
  profiles. The tests crate resolved AUnit, GNATprove and GNATcov and passed
  542/542 in the development (`alr run`), release and validation profiles.
  The native sanitizer tests passed, and all 503 ALIs read
  `V "GNAT Lib v12"`.
- B. Publisher dry run: `alr publish --skip-submit
  https://github.com/zackboll/opencv_geometry_ada.git 4902b76...`, with the
  build check enabled, a disk-backed `TMPDIR` and the candidate-index
  settings. The origin was verified (Git, trusted host github.com), the
  sources were deployed from GitHub, and the build check passed with Core
  0.5.0 from the candidate index and Debian GNAT 12. The generated manifest
  has version 0.3.0, `opencv_core = ">=0.5.0 & <0.6.0"`, no pin, and origin
  `commit = "4902b762..."`, `url =
  "git+https://github.com/zackboll/opencv_geometry_ada.git"` (SHA-256
  `26d6dc63...`). The manifest to submit is generated from the merged commit
  in REL-003-008.
- C. Pre-index installation path, public community index only: a new crate
  ran `alr with opencv_core --use=https://github.com/zackboll/opencv_core_ada.git
  --commit=f8aef00...` and `alr with opencv_geometry --use=... --commit=4902b76...`,
  then built with Debian GNAT 12 and ran a `Contour_Area` program. Finding:
  `--commit=0.5.0` fails for Core with "Reference is ambiguous: /0.5.0",
  because Core also has a branch `release/0.5.0`, and Alire does not accept
  `refs/tags/0.5.0`. The release notes therefore pin Core by full commit. An
  unambiguous tag name works: `--commit=0.2.0` for Geometry froze the pin at
  the annotated tag object `39821543...`, which resolves to the 0.2.0
  commit.
- D. Control: a clean unpinned `alr update` against the public community
  index alone leaves the solution incomplete, "opencv_core >=0.5.0 & <0.6.0
  (missing:unavailable)". In non-interactive mode Alire still exits 0, so the
  solution, not the exit status, is the evidence.

`GEOMETRY_0_3_0_ALIRE_READY` needs clean public-index resolution and a
publisher run against the public index; both wait for #2227.

### Dispositions

For candidate `4902b76`:

- `SOURCE_RELEASE_READY` (`GEOMETRY_0_3_0_SOURCE_RELEASE_READY`): all eight
  mandatory gates PASS. The disposition for the release pull request's head
  is stated in the pull request after its own requalification.
- `CORE_INDEX_PENDING`: Core 0.5.0 is not yet indexed (#2227 open), so
  `GEOMETRY_0_3_0_ALIRE_READY` is not reached. The manifest, candidate-index
  resolution and publisher dry run are ready for submission.
- `ADACORE_YOCTO_DEFERRED_BY_MAINTAINER`: `DEFERRED_BY_MAINTAINER — NOT YET
  QUALIFIED`. Not tested, not PASS.
- Target hardware execution: NOT RUN (outside the 0.3.0 scope).

Merging, tagging and the index submission wait for the maintainer's review
of the release pull request.

## REL-003-008: publication handoff (after the maintainer merges)

Nothing here runs before the maintainer has reviewed and merged the
release-candidate pull request. Do not move an existing tag or rewrite a
published commit; a correction after tagging is 0.3.1.

1. Verify the merge and the merged tree. `RC_HEAD` and `RC_TREE` are the
   commit and tree of the release pull request's requalified head, as
   recorded in that pull request.

   ```sh
   gh pr view "$RELEASE_PR" --json state,mergeCommit --jq '.state, .mergeCommit.oid'
   git fetch origin --tags
   MERGED=$(gh pr view "$RELEASE_PR" --json mergeCommit --jq .mergeCommit.oid)
   test "$(git rev-parse "$MERGED^{tree}")" = "$RC_TREE"
   test -z "$(git ls-remote origin 'refs/tags/0.3.0*')"
   ```

   If the merged tree differs from `RC_TREE` (for example, `main` moved
   before the merge), review `git diff "$RC_HEAD" "$MERGED"`. Any change
   outside documentation reruns the affected gates on `MERGED` before
   tagging.

2. Tag the merged commit and verify it:

   ```sh
   git tag -a 0.3.0 "$MERGED" -m "opencv_geometry 0.3.0"
   git push origin refs/tags/0.3.0
   test "$(git ls-remote origin 'refs/tags/0.3.0^{}' | cut -f1)" = "$MERGED"
   ```

3. Generate the index manifest from that immutable commit, with a
   disk-backed temporary directory and the build check enabled:

   ```sh
   TMPDIR="$PUBLISH_TMPDIR" alr -n publish --skip-submit \
     https://github.com/zackboll/opencv_geometry_ada.git "$MERGED"
   ```

   Until Core 0.5.0 is indexed, the build check can resolve only against a
   candidate index that adds the exact alire-index#2227 manifest (as in the
   preflight above); record which index was used.

4. Verify the generated `opencv_geometry-0.3.0.toml`: `version = "0.3.0"`,
   `opencv_core = ">=0.5.0 & <0.6.0"`, `[origin]` `commit = "$MERGED"` and
   `url = "git+https://github.com/zackboll/opencv_geometry_ada.git"`, no pin
   or path. Record its SHA-256.

5. After alire-index#2227 merges: in the maintainer's index fork, branch
   from upstream `stable-1.4.0`, add the manifest as
   `index/op/opencv_geometry/opencv_geometry-0.3.0.toml`, run
   `alr index --check` in isolated settings against that checkout, push, and
   open the index pull request against `stable-1.4.0`. Leave it open for
   independent review with auto-merge disabled.

6. After the index pull request merges: with fresh Alire settings and only
   the community index, `alr get opencv_geometry=0.3.0` (or a new crate
   with `alr with opencv_geometry=0.3.0`), build it, and run the test suite.
   Only then is `GEOMETRY_0_3_0_ALIRE_READY` reported as published.
