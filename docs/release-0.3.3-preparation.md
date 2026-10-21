# OpenCV Geometry 0.3.3 source-release preparation

## Scope and publication boundary

GEOM-REL-033 prepares the Alire crate `opencv_geometry` version **0.3.3**
from merged PR [#55](https://github.com/zackboll/opencv_geometry_ada/pull/55).
This is a cross-build tooling and installation improvement, not a new
public Geometry API or native algorithm release. The preparation branch is
`release/0.3.3-preparation`, based only on main below.

The source PR is for independent review, must remain non-draft, open and
unmerged, and must not have auto-merge enabled. This task does not authorize
a tag, GitHub Release, publisher invocation, or Alire-index submission.
A locally generated qualification archive is **not** a published release.

The existing annotated `0.3.2` tag and pending
[Alire-index PR #2257](https://github.com/alire-project/alire-index/pull/2257)
remain unchanged. The submission was OPEN when checked for this preparation;
source availability is not community-index acceptance. 0.3.2 and 0.3.3 may
be accepted independently. Do not close or supersede 0.3.2. Geometry PR #53
is unrelated, remains open, and is not incorporated here. Historical release
documentation and published archives are not rewritten.

## Starting source and provenance

Remote main was verified using `git ls-remote origin refs/heads/main`.
GitHub confirms PR #55 is MERGED into main with these exact identities:

| Identity | Git object |
| --- | --- |
| Actual starting main / PR #55 merge | `e90da6ec345099a9e4833d4bed11be204602c5ac` |
| User-qualified implementation / PR #55 head | `ff4089671cb11837416fe1aa9892018c5fa24fda` |
| Identical full tree of both commits | `7cc1769287c2400a8e162c573f0f51bceaf55c5c` |
| Existing annotated 0.3.2 tag object | `2763a13ece759ac2fccd45f7e8a9ec5ddfe6392c` |
| Peeled 0.3.2 commit | `5f71c9a6d5291adb032eb1a43954c5f9aaf047e6` |
| 0.3.2 tree | `cc8487634f66be422e835b95c2ee8cd57e952d45` |
| Starting `src` tree | `caf493af3f74bd450f0e845ed312d6fc5b4e1be2` |
| Starting `cpp` tree | `099d81734f31f723005942100e33374a280929d9` |
| Starting `scripts` tree | `5edafa6fa4e89e1bfc32e68f0d9388a0938cd378` |
| Starting `tests` tree | `34c2df74433c37f44ee7ff6510bdbb50c558bb06` |
| Starting `.github` tree | `ab97e5a645208b663f66e190bb70a32fbb89a471` |
| `opencv_geometry.gpr` blob | `0662cc7e6be7e6933a0fb8cf57a5cb794928fe72` |
| `opencv_geometry_shim.gpr` blob | `a372198921dbfb3b90b548f3327ebf74ad1eb6de` |
| `docs_api.gpr` blob | `9905fda74a89a67da53fe8645cc79a69d7b1b064` |
| `docs_internal.gpr` blob | `3c4344ead0fe0bb81c29192516b55a8b99a32a9a` |
| GNAT 12 Geometry compiler-policy GPR blob | `500567ecf267498fce766324f03663954f374ab4` |
| Starting root manifest blob (version 0.3.2) | `f73fc08c2da6a82fe51fd961eea6476d7fbf0727` |
| Candidate root manifest blob (version 0.3.3) | `494af4cb323712ef13d4cf2c6650eb5210f82ae0` |

Both `git rev-parse COMMIT^{tree}` values matched, and the merge-to-qualified
tree diff is empty. The release PR records the final committed candidate,
its tree, locally tested SHA, pushed SHA, PR head SHA, archive inventory,
SHA256/SHA512 digests, and current-run qualification results. These must be
recorded outside the candidate commit to avoid a self-referential commit or
archive digest. Results on a synthetic PR merge ref are not exact-head proof.

## Complete change review since immutable 0.3.2

The starting-main comparison changes exactly these eight files:

- `scripts/cross_geometry.py`: validated GPRconfig reuse/bootstrap support,
  actual GNAT/ALI identity probes, Git-free sanitized source export,
  stricter complete ELF archive inspection and command failure propagation.
- `scripts/cross_install_geometry.sh` and
  `scripts/cross_install_geometry.py`: the one-command install orchestration,
  installed Core checks, fresh isolated build, staged no-overwrite publication,
  durable configuration and independent consumer links.
- `tests/cross/qualify_geometry_cross_install.sh`: fresh automatic-config
  install qualification, cleanup checks and relocated-copy consumers.
- `tests/cross/qualify_reference_consumers.py`: installed archive trace
  verification for separate/shared/relocated prefixes, explicit backend and
  sysroot selection, and link-time dependency search (not deployment RPATH).
- `tests/cross/test_cross_geometry.py`: positive and negative controls for
  these paths, including host contamination and unsafe installation rejection.
- `docs/cross-install-geometry.md` and `README.md`: workflow documentation.

No other substantive change is hidden behind the tooling-only description.
The existing `scripts/cross_build_geometry.sh` remains present and unchanged.
Release preparation adds only the manifest version bump, active README and
cross-install evidence updates, and this document. All other documentation,
including historical release records, remains byte-identical to main.

Production `src/`, `cpp/`, every tracked GPR project, native build/configure
scripts and compiler policies are identical to 0.3.2. Public Ada declarations,
C ABI signatures/status values/ownership, native algorithms, numerical
safeguards and deferred unsafe operations are unchanged. No C++ shim guard
is added or modified; no public semantic validation is duplicated by this
release preparation.

## Delivered cross-install capabilities

See [the cross-install guide](cross-install-geometry.md) for exact invocation,
prerequisites, installed layout and failure behavior. PR #55 delivers:

- Automatic GPRconfig generation, or validated explicit/installed config reuse.
- GNAT Pro compiler/runtime verification, including actual compiled ALI identity.
- Verification of compatible **existing installed Core**, not a Core rebuild.
- Git checkouts and explicit unpacked `.git`-free source roots.
- Fresh isolated target production compilation and installation staging.
- Separate or shared Core/Geometry prefixes, never nested or overlapping
  protected paths; existing Core files are preserved.
- No-overwrite installation and fail-closed path/symlink handling.
- Durable installed Geometry GPR/compiler configuration after build cleanup.
- Verified installed Ada-only and mixed Ada/C++ consumer cross-links.
- Fresh consumer links after cleanup and from relocated **copies** of prefixes.
- AArch64 ELF, ALI, compiler, dependency and symbol-version checks.
- Rejection of unverified host compiler/library/search paths.

The production Ada dependency remains **`opencv_core >=0.5.0 & <0.6.0`**.
Core 0.5.2 is not a new minimum. Root manifest authors, maintainers, license,
tags, platform conditions, pre-build and test actions, `opencv`, `pkg_config`
and Windows system-library requirements are unchanged. Qualification may use
independently pinned Core fixtures, never committed production consumer pins.

Native OpenCV 4.x still uses **imgproc** (`opencv2/imgproc.hpp`,
`libopencv_imgproc`); OpenCV 5 uses **geometry** (`opencv2/geometry.hpp`,
`libopencv_geometry`). Both use native Core. No Ada Imgproc dependency is
added. Linux static-PIC, macOS Apple clang++/libc++ with the existing SDK and
`@rpath` model, and Windows MSYS2 external-shim behavior remain unchanged.
Existing GNAT 12 compiler policies and installed compatibility are retained.

## Proprietary vendor evidence carry-forward

The user reports successful qualification of exact PR #55 head
`ff4089671cb11837416fe1aa9892018c5fa24fda` using:

- GNAT Pro **25.0w**, GCC **12.3.1**, target `aarch64-linux-gnu`.
- Yocto **Scarthgap** sysroot and native OpenCV **4.9.0**.
- Compatible installed OpenCV Core.
- Fresh Geometry production cross-build/install and fresh/relocated installed
  Ada and mixed Ada/C++ consumer links.

The observed full qualification ended with:

```text
QUALIFICATION_EXIT_STATUS=0
PASS automatic GPRconfig, compatible installed Core, fresh production build/install, ELF/ALI/compiler checks, production cleanup, fresh installed and relocated Ada/mixed consumer links
```

User-container provenance references (not assumed accessible here):
`/tmp/geometry-pr55-r1.KRm8Ji/qualification.log` and
`/tmp/opencv-geometry-qualification-75jk7idm`.
This is user-observed evidence, not a locally repeated proprietary SDK run.

Carry-forward requires an empty qualified-head-to-candidate diff for **all
implementation/configuration/test paths**, not merely matching Ada sources:

```sh
git diff --exit-code ff4089671cb11837416fe1aa9892018c5fa24fda HEAD -- \
  src cpp scripts tests .github '*.gpr' .gitignore LICENSE THIRD_PARTY_NOTICES
git diff ff4089671cb11837416fe1aa9892018c5fa24fda HEAD -- alire.toml
git diff --name-status ff4089671cb11837416fe1aa9892018c5fa24fda HEAD
```

The first must be empty; the manifest diff must be solely `0.3.2` to `0.3.3`;
the full diff must list only the four release metadata/documentation files.
The `src`, `cpp`, `scripts`, `tests`, `.github` trees and GPR blobs above
must match the final candidate. Changes to production source, GPR projects,
compiler configuration, cross-install behavior or consumer qualification code
invalidate carry-forward and require fresh vendor qualification.

**Target execution remains NOT PERFORMED.** This track does not inherit the
historical GNAT Pro **25.2 / GCC 13.3.1** QEMU campaign or its 542-test count.
Debian GNAT 12 reference/QEMU checks are also distinct from proprietary
vendor and hardware qualification. AdaCore GNAT 12 remains NOT TESTED.

## Exact-candidate qualification and release gates

The source PR/evidence must distinguish completed passes, running/queued
jobs, policy skips and unavailable environments. Never count a workflow as
passing before completion or use another SHA's run as fresh candidate proof.
Post-merge workflows must separately be checked at starting main
`e90da6ec345099a9e4833d4bed11be204602c5ac`; several were still running at the
initial preparation check. Shared GNATdoc shadow is PR-only, not a missing
main push result. Documentation deployment is intentionally skipped on PRs.
Windows/MSYS2 is intentionally skipped on PR/release-branch push events;
that skip is not an executed Windows pass.

| Gate | Required current evidence |
| --- | --- |
| Native Alire | Successful build on the committed candidate, exact Core fixture recorded |
| AUnit | Actual registered count (expected 547), release and validation; zero failed assertions/unexpected errors |
| Native shim | All four existing sanitizer/fault-injection regressions, no sanitizer findings |
| Cross configuration/install | Shell syntax, Python compilation, full existing synthetic controls; synthetic results are not compiler/link/execution proof |
| Linux OpenCV matrix | 4.6.0, 4.10.0, 4.14.0 and 5.0.0, each with immutable Core 0.5.0 and 0.5.1 fixtures; backend/library identity, both AUnit profiles and native regressions |
| Debian GNAT 12 | Production build/AUnit in release, validation and development |
| Debian 12 installed consumers | Independent installed Ada/mixed consumers and relocation |
| Debian AArch64 reference | Cross-build/install, consumer links and separate QEMU/AUnit evidence |
| Linux/macOS compatibility | Both applicable Core combinations and established platform checks |
| Standalone macOS SDK | SDK links without ambient SDKROOT/LIBRARY_PATH workarounds |
| Ada API Documentation | Generation, coverage, warning, guide and browser checks |
| Shared GNATdoc shadow | Exact-head controls, independent reconstruction, original/browser/adversarial checks and recorder |
| Source hygiene | Shell syntax, Python compilation and `git diff --check` |
| Vendor | Exact implementation equivalence to qualified PR #55, as above |

Do not lower warnings, numerical tolerances, validation checks or coverage to
obtain a pass. Formatting/proof need no new campaign for unchanged Ada/SPARK
code. New failures must be diagnosed; unavailable or failed gates remain
explicit blockers, not waived results.

## Clean source archive requirements

After committing, create a fresh `git archive` of that exact SHA. Record the
commit and tree, complete inventory, manifest blob, and SHA256/SHA512 in the
PR evidence. Extract outside the checkout without `.git`; compare every
tracked file's bytes and mode with that commit and check for extraneous files.

Required contents include production Ada sources, C++ shim/headers, both
Geometry GPR projects, root manifest, existing cross-build scripts, the new
cross-install workflow and guide, installation/consumer tests, `LICENSE`,
`THIRD_PARTY_NOTICES`, and this release-preparation document. Reject generated
objects, ALIs, libraries, generated configurations, local logs, credentials,
and private SDK/toolchain files. Do not remove historical tracked evidence
merely because it documents an earlier campaign.

Run the cross-install controls and entry-point checks against the extracted
tree. Exercise its actual explicit Git-free export and verify the sanitized
staged source identity and content, without discovering an enclosing Git
repository. These checks establish archive/orchestration behavior, not a new
proprietary target build. A final archive cannot contain its own digest.

## Next stage (not authorized here)

After independent review, completed CI and user-authorized merge, reconcile
actual merged main before creating annotated tag `0.3.3`, verifying the public
archive, running the Alire publisher and submitting a separate
`opencv_geometry-0.3.3.toml` index PR. Preserve the pending 0.3.2 submission
throughout. No merge or publication is automatic.