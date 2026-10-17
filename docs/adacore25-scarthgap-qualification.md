# GNAT Pro 25.2 / Scarthgap qualification — GEOMETRY-POST-002

This is a separate qualification track, not the GNAT 12 release adapter.
No proprietary compiler, installer material, license, SDK binary or raw
private build log belongs in this repository.

## Corrections and provenance

Core PR [#83](https://github.com/zackboll/opencv_core_ada/pull/83) was
merged as `a3a3535e3ba42ecf9d026a8e0c8a8d657bb58b0d`. It already corrects
Core's runtime discovery. Core main tested here is
`a9029026315411f8c228254438ffc8cfad4c876d`; no new Core correction is needed.
Core 0.5.0 predates that correction and its scripts remain unchanged.

Original release preflight failure: `Ada compiler runtime is unavailable`.
The real GCC driver returns literal `adalib`; matching GNATLS reports
`rts-native/adainclude` and `rts-native/adalib`. Geometry now resolves the
actual compiler, derives only its matching sibling GNATLS, requires both
complete search sections, canonicalizes every path and rejects foreign,
missing, ambiguous and mismatched runtimes. PATH is never used for GNATLS.

GCC 13.3.1 and GNAT Lib v25 use different version schemes. A fresh controlled
Ada probe with the exact verified runtime supplies the ALI signature and
compiler/object/runtime hashes. The target ELF and source unit are checked.
Core, Geometry, independent consumers and AUnit ALIs must agree with that
signature; it is not hardcoded from a product or GCC version.

A further real consumer failure exposed GPRinstall Pro retaining a dangling
`opencv_geometry_config` import. `--minimal-project` did not fix it. Removing
only the unused Core import from the exported switch-only abstract project
keeps that project a leaf and produces independently usable installed GPRs.
No installed metadata is patched after installation; no source-tree GPR
search path is supplied to consumers. GNAT 12 switch policy is unchanged.

The new `tests/cross/qualify_adacore25_yocto.sh` first runs
`verify_adacore25.py`, then reuses `qualify_target.sh`. It checks:

- GNATLS Pro 25.2, matching GCC 13.3.1 Ada/C++ build identities and installation;
- AArch64 ELF64 little-endian LP64 objects, verified runtime and actual ALI;
- the official Scarthgap 5.0 qemuarm64 minimal eSDK SHA-256;
- embedded glibc/GCC-runtime caches against that authenticated installer;
- assembled sysroot runtime files against those cache members;
- pinned Poky revision `fb91a49387cfb0c8d48303bb3354325ba2a05587`.

This eSDK's assembled development sysroot lacks os-release. None is invented:
the separate track authenticates runtime provenance from the installer.
The original GNAT 12 adapter, verifier and claim tests remain unchanged.

## Environment and execution

Rootless Podman 5.4.2 on Debian 13, pinned Ubuntu 22.04 container, keep-id
non-root user, no capabilities, no-new-privileges and seccomp enabled.
All builds/tests ran with external networking disabled. Existing official
SDK, AdaCore installation, OpenCV and QEMU were reused without downloads or
rebuilds of those prerequisites. No host package/configuration changes.

Toolchain: GNAT Pro/GPRbuild Pro 25.2 (20250603), GCC 13.3.1,
`aarch64-linux-gnu`, native target Ada runtime. Sysroot: Scarthgap 5.0,
glibc 2.39, libstdc++.so.6.0.32. OpenCV: 4.9.0, native Geometry backend
**imgproc** plus native core. No Ada Imgproc dependency was added.
QEMU: explicit `qemu-aarch64` 6.2.0 with the Yocto loader/sysroot; no binfmt.

The prior workspace profile listed a nonexistent pkg-config directory.
Selecting its existing target pkg-config directory fixed that input error;
no target dependency guard was relaxed. Failed attempts were retained.

## Recorded integrated results

Core main and corrected Geometry commit
`3c2b2cfbbf1633a13ce78e3b1f8b82cf97ddd313` completed:

| Gate | Result |
|---|---|
| Core main preflight/full cross-build | PASS |
| Geometry full cross-build | PASS |
| Both Ada libraries and both static-PIC C++ shims installed | PASS |
| Installed GPR resolution without build-tree paths | PASS |
| Independent Ada and mixed Ada/C++ links | PASS |
| Both consumer types executed under QEMU | PASS |
| Prefix relocation and repeated links/QEMU execution | PASS |
| Consumer ELF/dependency/symbol checks | PASS: 10 ELFs, 81 symbol requirements per executable |
| Geometry AUnit target cross-build | PASS |
| Geometry AUnit QEMU run | **542/542**, 0 failed assertions, 0 unexpected errors |
| Geometry/test object and ALI checks | PASS: 59 ALIs, 55 objects |
| AUnit library object and ALI checks | PASS: 46 ALIs, 24 objects |
| AUnit executable loader/dependency/symbol checks | PASS |
| Target hardware | NOT TESTED |

The exact build commits and evidence are recorded privately. **67 synthetic
controls passed**, including the unchanged GNAT 12 claim tests. Synthetic controls do not count as
target execution. The Core full unit suite is not part of these 542 Geometry
tests. No hardware qualification is inferred from QEMU.

Negative controls cover missing/foreign GNATLS, section/path ambiguity,
runtime mismatch, missing/wrong-source/unidentified probe output, host ELF,
GCC/ALI version divergence, stale/mixed ALIs, compiler replacement, incorrect
25.2 product/build identity, foreign SDK runtime and modified SDK caches.
Core main's 45 cross-control tests passed without duplicating PR #83.

## Exact release production equivalence

The complete `src/` and `cpp/` Git trees are identical between the tested
current sources and their immutable releases:

| Repository | Tree | Exact Git tree ID |
|---|---|---|
| Core main / 0.5.0 | src | `1391492417e408bd0b5bdc0327a1d659d229feed` |
| Core main / 0.5.0 | cpp | `7b6e6b34cf23e0c635a3e821e5e428bbb78aa7d8` |
| Geometry corrected / 0.3.0 | src | `1c253e7947a1afe4133dc54804a3029793682a41` |
| Geometry corrected / 0.3.0 | cpp | `3dbd7c17dc58701d33905dcd36af2b493d8e3880` |

Release commits: Core `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`,
Geometry `fa81e5140cbebf2aa41397a40c08ba194a5f6f73`.
Corrections are cross-build/qualification tooling, tests and documentation,
not production Ada/C++ algorithms, public API or ABI. The original release
scripts did **not** pass this campaign; corrected scripts qualified current
sources with byte-identical production trees.

Recommend independently reviewed tooling patch releases Core **0.5.1** and
Geometry **0.3.1** so published packages contain the cross-tool corrections.
No version, tag or release is created here. Maintainer approval and separate
release review are required. Stop at independent PR review; do not merge.