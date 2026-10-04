# OpenCV Geometry 0.2.0 release notes and certification

This is a release-hardening change, not a new binding feature. The release
candidate changes version `0.2.0-dev` to `0.2.0` and documents the safe
surface already merged on main. Public Ada declarations, C ABI, shim,
ownership, native backend selection, compiler isolation, and CI are unchanged.
No public feature was added solely to increase a coverage percentage.

## Delta from 0.1.0

- Ada-owned `Float32_Point_Array` support for subpixel point sets, with native
  `CV_32F` overloads, explicit packing, non-finite checks, and documented
  operation-specific numerical constraints. Convex intersection retains its
  exact binary-grid safety contract on older native releases.
- Version-gated `Closest_Ellipse_Points` (OpenCV 4.12+/5.x), for integer and
  Float32 queries, preserving cardinality, iteration order, and Ada bounds.
- Version-gated Float32 Subdiv2D bounds (OpenCV 4.13+/5.x):
  `Float32_Rectangle`, `Create_Float32`, `Reset_Float32`, and `Bounds_Float32`.
  Integer aggregate source compatibility and exclusive limited ownership are
  preserved. Older releases report unsupported; there is no integer fallback.
- OpenCV 4.13+ `minAreaRect` width/height/angle convention handling, including
  native empty results, fractional rectangles/segments, and unordered
  `Box_Points` integration. Results are not normalized to an older convention.
- Registered AUnit growth from **377 in 0.1.0 to 524**, with no tests added by
  this release-preparation task.

Safety decisions are preserved, not worked around for release:

- `approxPolyN` remains deferred: a portable contraction-wide safety contract
  is unresolved; finite convex input can develop sentinel/NaN candidates.
- Float32 `minEnclosingTriangle` remains deferred: some nearly degenerate
  inputs fail to return, and there is no established safe preflight.
- `minEnclosingConvexPolygon` remains deferred: released 4.13.0, 4.14.0, and
  5.0.0 can read out of bounds for finite inputs. The unreleased upstream
  PR 30111 is not a certification substitute and still has non-minimal results.
- 3-D `fitLine` is deferred. Raster-image modes, new Mat bridges, image
  processing, and the OpenCV 5 3-D/segmentation/MST families remain excluded.

See [coverage](coverage.md), [Float32 research](float32-research.md), and
[versioned-feature safety research](versioned-features-research.md).

## Starting gate and isolation

- Fetched `origin`; actual starting `origin/main` was
  `02109beb32e481fa575d394ece88bf792605dad9` (merged PR #16).
- The worktree was clean and there were no open Geometry PRs.
- Release branch: `release/opencv-geometry-0.2.0`, based on that remote main,
  not on the previously checked-out Task 016 branch.
- Unchanged local baseline: `alr -n build` and `alr -n -C tests run` passed,
  **524/524**, OpenCV **4.10.0**, native **imgproc**.
- The working checkout has pre-existing ignored Alire pins to live sibling
  Core. Therefore release certification uses a fresh detached clone with no
  inherited pins or lockfiles. Its independent 4.10 baseline also passes
  **524/524**, resolving indexed **opencv_core 0.3.0**. No release manifest
  dependency is pinned to a filesystem path.

## Completion-boundary audit

Exact upstream tags (peeled commit identities):

| Release | Commit | Headers inspected |
| --- | --- | --- |
| 4.14.0 | `0654a42e19215ef25b1d367d822f3c630447e7c7` | `modules/imgproc/include/opencv2/imgproc.hpp` |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` | `modules/geometry/include/opencv2/geometry.hpp`, `geometry/2d.hpp`; out-of-scope header families checked |

Re-read both public Ada specs and the entire coverage table. The 26 common
native free-function names (counting `getRotationMatrix2D_` separately), the
three version-gated free functions, and all public Subdiv2D operations and
Rect/Rect2f overloads are accounted for. No undocumented in-scope API gap was
found in 4.14.0. Protected Subdiv2D implementation details are not public APIs.
Image extraction, drawing, warping, and calib3d-derived APIs are not newly
classified as missing Geometry coverage.

Header SHA-256 identities:

- 4.14.0 `imgproc.hpp`:
  `6b1fb2db6daa6db0298160c029f6246b43808a81243bab00cd4ee01f08d3d3b0`
- 5.0.0 `geometry.hpp`:
  `b871ac6bca2cb01266025cfccadbf98ad3bdc020fdf05dda0bdeab50e975b3c3`
- 5.0.0 `geometry/2d.hpp`:
  `5f3c5cc89b88e83f5703c3113a0701ae8611dce9835a4facb68bacc027c74051`

## Exact OpenCV 4.14.0 certification

Linux x86-64; GNU C++ **14.2.0** (Debian 14.2.0-19), libstdc++; Ada
**GNAT 16.1.0**, GPRbuild **26.0.1**, Alire **2.1.1**.

Reused the Task 016 exact-tag native build, not its patched upstream PR build.
An independent `git archive 4.14.0` source tree compares identically with its
entire source tree, excluding only `.cache` downloads. The installed header
also matches. `cmake --build` confirms no pending work. CMake reports unknown
version control because the source was extracted from an archive; the tag
comparison, not that field, establishes provenance.

Native build: Release, shared, `BUILD_LIST=core,imgproc`, Ninja, pkg-config
generation enabled. Tests/performance tests/examples/docs/apps/Java/Python
disabled; IPP, ITT, OpenCL, CUDA, Eigen, LAPACK, TBB, OpenMP, KleidiCV disabled.
The system OpenCV installation was not changed.

Certification environment (local evidence paths, **not manifest dependencies**):

```sh
export PKG_CONFIG_PATH=/var/tmp/geometry-016-pr30111/install-414/lib/pkgconfig
export LD_LIBRARY_PATH=/var/tmp/geometry-016-pr30111/install-414/lib
alr -n build
alr -n -C tests build --profiles=opencv_geometry=release
alr -n -C tests run
alr -n -C tests build --profiles=opencv_geometry=validation
alr -n -C tests run
sh scripts/run_native_tests.sh
```

| Check | Result |
| --- | --- |
| Complete normal AUnit suite | **524/524**, 0 failed assertions, 0 unexpected errors |
| Complete validation AUnit suite | **524/524**, 0 failed assertions, 0 unexpected errors |
| Native ASan/UBSan allocation-fault suite | **PASS, 0 failed checks** |

Generated configuration records version **4.14.0**, backend **imgproc**,
`-lopencv_imgproc` and `-lopencv_core`. `ldd` confirms the test executable
loads the exact prefix's `libopencv_imgproc.so.414` and `libopencv_core.so.414`.

Supported-path evidence includes closest-ellipse fractional/high-bound/empty
and malformed-ABI cases; fractional Subdiv2D construction, operations,
half-open bounds, and reset/mode transitions; integer/Float32 minAreaRect
empty, nonsquare, and segment conventions. Version-aware test bodies were
inspected: these supported paths execute on 4.14, not merely old-version
unsupported branches. Native Float32 creation/rebuild injects **7/6**
allocation failures; on-edge and inside insertions each exercise **2**
failures marking the object unusable. The native harness and included shim
are sanitized; the separately built native OpenCV libraries are Release,
not an instrumented full OpenCV build.

## Preserved cross-version evidence

[Starting-main CI run 37172413937](https://github.com/zackboll/opencv_geometry_ada/actions/runs/37172413937)
completed successfully on all three platforms with indexed Core **0.3.0**:

| Platform | Native version/backend | AUnit |
| --- | --- | --- |
| Linux x86-64 | 4.6.0 / imgproc | 524/524 normal and validation; native sanitizer step passed |
| macOS ARM64 | 5.0.0 / geometry | 524/524 |
| Windows x86-64 MSYS2 | 5.0.0 / geometry | 524/524 |

CI topology is unchanged. Windows remains main-push/manual-only and is
intentionally skipped on this release branch and PR; it is not a missing
required PR check. macOS retains external Apple clang++/libc++/@rpath, Windows
retains same-prefix MSYS2/MinGW, and Linux retains its static-PIC GNU shim.

[PR #15](https://github.com/zackboll/opencv_geometry_ada/pull/15) records
524/524 normal and validation on exact 4.12.0 and 4.13.0 and on 5.0.0. The
relevant sources, production shim, AUnit registrations, and native harness
are unchanged since that tested feature commit `34f9dfa`; Task 016 only
added opt-in research outside the default tests. Its retained local logs
also confirm those counts. Release preparation does not rebuild that large
historical matrix unnecessarily; the candidate receives focused local
4.10/4.12/4.13 compatibility checks and mandatory full 4.14 checks.

Candidate focused normal-profile checks passed on each of **4.10.0, 4.12.0,
and 4.13.0**: minAreaRect **11/11**, closest ellipse **15/15**, and the complete
Subdiv2D family **60/60**. Every run had zero failed assertions and unexpected
errors. The main working checkout was restored to OpenCV 4.10/release and its
complete final AUnit run passed **524/524**.

## Proof and static validation scope

The established scope is the four Geometry helpers `Float32_Points`,
`Convexity`, `Intersection`, and `Transforms`, plus explicitly imported Core
`Safe_Arithmetic`. This is not proof of the C++ backend or all stateful Ada.
Run through the tests crate's Alire environment:

```sh
alr -n -C tests exec -- gnatprove -P "$PWD/opencv_geometry.gpr" \
  --subdirs=task017-proof -j2 --level=2 --timeout=30 \
  --checks-as-errors=on --output-header -u \
  opencv-geometry-internal-float32_points.adb \
  opencv-geometry-internal-convexity.adb \
  opencv-geometry-internal-intersection.adb \
  opencv-geometry-internal-transforms.adb \
  opencv-internal-safe_arithmetic.adb
```

Runtime tests establish native behavior and error translation. Ada runtime
checks enforce public preflight outside the proof scope; foreign operations
remain trusted. Warnings-as-errors are preserved. No Ada source is modified
or reformatted as a release side effect. Whitespace and changed-line
GNATformat checks passed before committing. A full GNATformat 26.0.0
`--check` of Geometry public/internal sources with the Geometry project also
passed, as did the 79-column Ada check and `git diff --check`.

Fresh exact-4.14 certification with indexed Core 0.3.0 reports **277/277**,
no unproved or justified checks, and no flow/proof warnings. The invocation
header records GNATprove FSF 16.1.0 and the switches above. The total comprises
**92 flow checks and 185 prover checks**, unchanged from the established
result (266 Geometry checks plus 11 imported Core checks).

## Publication and review gate

Publication validation passes from a fresh detached checkout of the candidate
commit using:

```sh
alr -n publish --skip-submit . <candidate-sha>
```

No `--skip-build` or private-index bypass is permitted. Inspect the generated
`opencv_geometry-0.2.0.toml` for the immutable GitHub origin commit, version,
absence of local paths/development pins, and preservation of:

- `opencv_core = ">=0.2.0 & <0.4.0"`;
- direct `opencv` and `pkg_config` dependencies;
- Windows `mingw_w64_gcc` dependency;
- MSYS2 `PATH.prepend = "${CRATE_ROOT}/lib"`;
- the existing configure and test actions.

The dry run includes a successful full build against exact OpenCV 4.14.0
and clean indexed resolution to **opencv_core 0.3.0**. The generated manifest
contains an immutable `git+https://github.com/zackboll/opencv_geometry_ada.git`
origin and version **0.2.0**, with no filesystem dependencies or development
pins. It is a generated local validation artifact, not an index submission.

The exact candidate SHA, publication result/resolved Core, candidate CI state,
and local/remote/PR head parity are recorded in the release PR description
after committing, avoiding a self-referential commit identifier here.

**Stop at review:** no merge, 0.2.0 tag, Alire-index submission, or auto-merge.