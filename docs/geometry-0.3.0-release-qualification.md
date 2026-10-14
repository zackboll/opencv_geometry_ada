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
| 001 | Debian 12 GNAT 12 production and runtime | Not started |
| 002 | Debian 12 installed consumers | Not started |
| 003 | Isolated AArch64 cross configuration | Not started |
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
