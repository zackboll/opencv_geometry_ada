# opencv_geometry 0.3.1 release candidate

This is a compatibility-preserving **tooling and platform qualification
patch**, not a feature release. Publication is not authorized by this
document. See the [candidate qualification record](geometry-0.3.1-release-qualification.md)
for the current disposition and fresh candidate results.

## Compatibility

The complete production `src/` and `cpp/` Git trees are unchanged from
immutable Geometry 0.3.0 (`fa81e5140cbebf2aa41397a40c08ba194a5f6f73`):

| Tree | Git object identity |
| --- | --- |
| `src/` | `1c253e7947a1afe4133dc54804a3029793682a41` |
| `cpp/` | `3dbd7c17dc58701d33905dcd36af2b493d8e3880` |

Public Ada declarations, the private C ABI, algorithms, numerical behavior,
ownership, exceptions and safety contracts are unchanged. No public semantic
validation is duplicated in the C++ shim by this release; no C++ production
file is modified. The supported OpenCV version range and native backend
selection are unchanged: OpenCV 4 uses `opencv2/imgproc.hpp` and native
`libopencv_imgproc`; OpenCV 5 uses `opencv2/geometry.hpp` and native
`libopencv_geometry`. Both use native OpenCV Core. There is no Ada Imgproc
dependency. Existing Alire actions and Windows dependency metadata remain.

The production Core constraint remains `>=0.5.0 & <0.6.0`. Core 0.5.0 remains
supported on previously qualified platforms; no Core 0.5.1-only public API
is introduced. Core 0.5.1 is the preferred corrected tooling release for
the specifically tested GNAT Pro 25.2 / Yocto Scarthgap environment. While
Core index PR [#2243](https://github.com/alire-project/alire-index/pull/2243)
is open, 0.5.1 qualification uses its immutable source, not claimed public
index availability. No source pin is committed to the production manifest.

## Tooling corrections

Merged corrective PR [#46](https://github.com/zackboll/opencv_geometry_ada/pull/46)
provides matching-GNATLS runtime discovery, derived from the actual compiler
installation rather than an unrelated executable on PATH. GCC 13.3.1 and
GNAT Lib v25 are distinct version schemes: actual compiler-generated Ada
probes identify ALIs, rather than inferring an ALI version from GCC's major.

The exported switch-only GPR configuration is a leaf, avoiding a dangling
configuration import in installed projects. Target-only compiler, ELF ABI,
runtime, loader, dependency and provenance checks remain enforced. GNAT 12
policy and its historical qualification labels are not repurposed for 25.2.

Documentation tooling also includes the merged declaration-level Core type
links and real browser checks. The minimum-dependency GNATdoc fixture remains
immutable Core 0.5.0; the 452-item documentation coverage ratchet is unchanged.

## Platform qualification scope

The earlier [GNAT Pro 25.2 qualification](adacore25-scarthgap-qualification.md)
established AArch64 cross-compilation with GCC/G++ 13.3.1, GNAT Lib v25,
Yocto Scarthgap 5.0, OpenCV 4.9.0 and AUnit 26.0.0: **542/542 Geometry AUnit
tests under QEMU**, plus installed and relocated independent Ada and mixed
Ada/C++ consumers. That record names earlier exact sources; it does not
substitute for fresh qualification of this release candidate against Core
0.5.1. Candidate gates also retain Debian GNAT 12, Core 0.5.0 compatibility,
the separate Debian AArch64 reference and existing OpenCV 4/5 coverage.

Fresh release preflight at `df7fd96376af0771660bb51ea59b9e2158634786`
has now reproduced the Scarthgap results against immutable Core 0.5.1,
including both installed/relocated consumer kinds and 542/542 tests under
QEMU with exit status 0. Separate Debian 12 GNAT 12 qualification passes
all three profiles against each Core release, and the Debian AArch64
reference passes against Core 0.5.0. The qualification record distinguishes
these exact-source results from the final PR-head release gates.

**AdaCore GNAT 12: NOT TESTED. Target hardware: NOT TESTED.** User-mode QEMU
execution is not hardware execution. The historical 0.3.0 AdaCore/Yocto
deferral remains accurate and is not rewritten by later GNAT Pro testing.