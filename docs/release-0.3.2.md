# OpenCV Geometry Ada 0.3.2

## Release scope

0.3.2 is a maintenance patch release. It stabilizes existing operations;
it adds no public Geometry operations, types, or Ada dependencies.

The comparison baseline is immutable source tag `0.3.1`:

- Annotated tag object: `e5333cd2433f5f53dc5df0fd70fe3a01a4d4ddb5`.
- Source commit: `8690927853ffa74729206d8997b09046ad3d2246`.
- Source tree: `bd44db83e32d771df4b5000d15f086172bae4a9a`.

Release preparation starts from GEOM-029 PR #51's merged main:

- Commit: `8bbc33b793945ff00456427801bfa73639e4ed36`.
- Tree: `b032eb82c9b9d3f435daded81f9cb3283c3c7afd`.

The release-preparation PR records its exact final source commit, Git tree,
archive digest, qualification logs, artifact identities, and outstanding
gates. Those records, rather than historical test results or this release
description, determine candidate readiness. This preparation does not
authorize merging, tagging, publishing, or an Alire index submission.

## Production corrections since 0.3.1

### Native count-allocation overflow guards

Integer `Minimum_Area_Rectangle` rejects more than `Integer_32'Last / 3`
points before packing. Native rotating calipers allocates three binary32
values per hull vertex using signed count arithmetic. Integer
`Minimum_Enclosing_Triangle` rejects more than `Integer_32'Last - 2`
points before packing because the native convex hull allocates `total + 2`
entries. Rejections raise `OpenCV_Error` through the existing error model.

The C ABI retains the same bounds to prevent native signed overflow for
raw ABI callers. These are memory-safety conditions, not a second public
semantic policy. Existing Float32 safeguards are unchanged.

### C ABI failure-output initialization

Both integer and Float32 convex-intersection entry points clear a non-null
area output before any argument rejection or exception return. The
rotated-rectangle intersection entry point similarly clears a non-null
classification output to `OPENCV_GEOMETRY_RECTANGLES_INTERSECT_NONE`.
Output counts were already initialized. Failed calls no longer expose a
stale area or classification when another output argument is invalid.

Public Ada declarations, C ABI signatures, status values, buffer ownership,
and the Subdiv2D limited ownership model remain unchanged. No public
semantic validation is duplicated in the C++ shim: the retained count
bounds protect native signed allocation arithmetic, and the output
initialization protects failure-result safety.

## Tests, documentation, and tooling since 0.3.1

These changes improve assurance; they do not add production capabilities:

- Three Subdiv2D chunking cases and two Voronoi facet cases bring the
  registered AUnit suite to **547**. Count-guard and failure-output
  regression assertions extend existing cases. Historical 542-case results
  are not current qualification results.
- The GEOM-029 audit reconciles public contracts, ABI behavior, and the
  hand-maintained API coverage table. The API is maintenance-oriented;
  upstream availability alone is not binding coverage.
- GNATdoc shadow qualification independently reconstructs current native
  declarations, type-link destinations, navigation, and authored guides.
  Immutable historical evidence is kept distinct from current execution.
- Shadow trust checks independently resolve approved constant type
  references and freeze the independent verification machinery against a
  reviewed historical authority. Current output cannot approve its own
  replacement inputs. Browser, mutation, and fail-closed recorder checks
  remain part of qualification.
- Shared-enhancer output remains an offline, non-deployable shadow. The
  standard documentation generator and production deployment are unchanged.
- GEOM-028's 3D L2 investigation records native overflow and the absence of
  a complete portable rounding-aware contract; it does not enable a binding.

## Compatibility

The production dependency remains `opencv_core >=0.5.0 & <0.6.0`.
Qualification distinguishes immutable Core sources:

| Core | Source commit |
| --- | --- |
| 0.5.0 | `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` |
| 0.5.1 | `64d8a60b59acfe4334045280e430c4774b5cad89` |

GNAT 12 compatibility, GPRbuild/GPRinstall behavior, and platform C++
isolation are preserved. Native OpenCV 4 uses `imgproc`; OpenCV 5 uses
`geometry`. Both use native `core`. There is no Ada Imgproc dependency or
Geometry-to-Core C++ shim dependency. Linux retains the static-PIC shim;
macOS retains Apple clang++, libc++, and its `@rpath` dylib; Windows retains
the external DLL built by the matching MSYS2 MinGW toolchain.

## Post-merge Windows gate

[Actions run 39190443749](https://github.com/zackboll/opencv_geometry_ada/actions/runs/39190443749),
[Windows job 117861849405](https://github.com/zackboll/opencv_geometry_ada/actions/runs/39190443749/job/117861849405),
completed successfully on exact starting main. Its logs establish:

- Geometry `8bbc33b793945ff00456427801bfa73639e4ed36` and immutable Core
  0.5.0 `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`.
- OpenCV 5.0.0, native `geometry`, MSYS2 MinGW GCC 16.2.0 (Rev6).
- C++ driver under Alire's `msys64/mingw64/bin`, not `gnat_native`.
- External shim DLL, import library, and external object checks passed.
- Shim imports native `libopencv_core-500.dll` and
  `libopencv_geometry-500.dll`, without `imgproc` or `core_shim` imports.
- AUnit **547/547**, zero failed assertions, zero unexpected errors.

The complete workflow and all five other workflows on that main SHA
succeeded. Package-manager warnings are not compiler/runtime failures.
This is exact-main evidence, not a new Windows run of the release candidate.
Its applicability requires an explicit candidate-to-main production-tree
and build-configuration equivalence check in the release PR.

## Candidate qualification requirements

Fresh execution must identify the exact committed candidate. Keep raw logs
and artifact digests outside the source archive and link them from the PR.

| Gate | Required evidence |
| --- | --- |
| Linux matrix | OpenCV 4.6.0, 4.10.0, 4.14.0, 5.0.0, each with Core 0.5.0 and 0.5.1 |
| AUnit | 547/547 in release and validation, zero failures/errors |
| Native tests | All four existing sanitizer/fault-injection programs, no sanitizer reports |
| Debian 12 GNAT 12 | Production, validation, development; 547/547 per profile |
| Installed consumers | Independent Ada and mixed Ada/C++, installed and relocated |
| Debian AArch64 | Reference cross-build and QEMU execution, including 547/547 |
| Standard GNATdoc | 452/452 documented items, zero warnings and coverage regressions |
| Shared GNATdoc shadow | Independent current-head reconstruction, original/browser/adversarial checks, readiness recorder |
| Hosted CI | Linux/macOS and all applicable exact-head workflows successful |
| Windows | Qualified exact-main evidence above plus production-tree equivalence |
| Alire | Clean independent consumer resolves published Core 0.5.0 without a Core source pin |
| Source archive | Exact commit/tree/digest; LICENSE and THIRD_PARTY_NOTICES; no private/build material |

No GNAT Pro 25.2/Scarthgap requalification, AdaCore GNAT 12/Yocto result,
or real target-hardware execution is implied. Debian AArch64 under QEMU is
reference emulation only. Previously executed campaigns remain historical
evidence unless explicitly rerun with their compiler, sysroot, OpenCV,
QEMU, and Core identities recorded.

## Safety-deferred operations

The maintenance release does not enable:

- `approxPolyN`: unsafe sentinel/NaN heap-candidate behavior.
- `minEnclosingConvexPolygon`: upstream out-of-bounds and non-minimal-result
  findings; unreleased upstream work is not a safe released dependency.
- `Fit_Line_3D`, including L2: no complete portable rounding-aware contract;
  finite output can conceal native internal overflow.
- Float32 `Minimum_Enclosing_Triangle`: unresolved termination/numerical
  safety concerns in the native search.

Image processing and image-valued modes remain outside Geometry. See
[the stabilization audit](api-stabilization-audit.md) and
[API coverage](coverage.md) for the maintained dispositions.

Existing 0.3.1 tags and index PR #2248 are not changed by this preparation.
0.3.2 tagging and publication require separate authorization after source
review, merge, and exact post-merge qualification.