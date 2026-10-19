# GEOM-INDEX-031R: standalone macOS SDK linking

## Scope and release gate

The source correction appends the generated
`Opencv_Geometry_Install.Cxx_Sysroot` as a GCC `--sysroot=` option to
Geometry's Apple_Clang / External_Relocatable executable linking and to
the Apple relocatable Ada library link. It preserves the existing `-L`,
shim library and rpath options. This matches Core 0.5.1's driver-level
SDK selection; it does not change the external Apple C++ build strategy.

No public Ada or private C ABI change is intended. `src/`, `cpp/`, the
547-test inventory, dependency constraints, backend detection and release
manifest version 0.3.2 must remain unchanged.

This is source-review work only. Independent approval, user merge,
successful post-merge CI and explicit release/tag authorization are
required before publishing 0.3.2 or replacing the index submission.
Never move the existing 0.3.1 tag. Documentation PR 53 is separate.

## Refreshed baseline identities

- Geometry main: `2f5239a0e264ca2bb4106cdb338d3eac25abf674`.
- Geometry 0.3.1 source: `8690927853ffa74729206d8997b09046ad3d2246`.
- No Geometry 0.3.2 source tag at initial refresh.
- Failing index PR [2248](https://github.com/alire-project/alire-index/pull/2248):
  `65010403a0b59b72700191f3ca08774eba9a8ca7` (open).
- Accepted/indexed Core 0.5.0: `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`.
- Core 0.5.1 source: `64d8a60b59acfe4334045280e430c4774b5cad89`.
- Core index PR [2243](https://github.com/alire-project/alire-index/pull/2243):
  `eb816dad96569ba052f424888e5c8a5db2f76a2e` (open, all reported checks
  successful; not accepted into stable-1.4.0 at initial refresh).

Original Geometry failures:

- [native / macos-latest](https://github.com/alire-project/alire-index/actions/runs/39196584901/job/117880570244)
- [macports / macos-latest](https://github.com/alire-project/alire-index/actions/runs/39196584852/job/117880569993)

Both archived logs show `macos-26-arm64`, failure reading CLT
`MacOSX.sdk/usr/lib/libSystem.tbd`, and `unknown architecture`
`arm64e.x1-macos`. This is the linker/SDK incompatibility described in
[GNAT-FSF-builds 112](https://github.com/alire-project/GNAT-FSF-builds/issues/112),
not an AUnit assertion failure.

## Permanent independent qualification

`.github/workflows/macos-standalone-sdk.yml` leaves the normal macOS
qualification intact and adds four fresh native ARM64 combinations:
Homebrew / MacPorts, each with Core 0.5.0 / 0.5.1 and GNAT 16.1.0.
It invokes `tests/macos/qualify_standalone_sdk.sh` with both `SDKROOT` and
`LIBRARY_PATH` unset. It never exports either variable, passes a sysroot
through test linker arguments, selects a hardcoded Xcode installation,
or changes an index workflow.

Core 0.5.0 is version-selected from the accepted index, not source/path
pinned. Its origin commit is checked in both lockfiles. Core 0.5.1 is
temporarily pinned to its immutable release source in the runner only.
These qualification selections must not be committed to the source manifest.

The evidence artifact records the exact source head, runner image,
selected Xcode and SDK, CLT information, compiler and bundled linker,
both dependency lockfiles, generated configuration, actual verbose linker
commands and trace, SDK `libSystem` input, Mach-O dependencies, runtime
dylib loading, all 547 AUnit results, relocatable Ada library linking,
and independent installed/relocated consumer builds and runs.

The Core 0.5.0 combinations also build the actual pre-correction Geometry
revision with the same environment. Only an old-project failure naming
the CLT stub and its unsupported architecture counts as reproduction.
If a future runner can link the old project, the evidence explicitly says
`NOT_REPRODUCED`: a corrected-source pass alone is not proof of regression
on the affected configuration. Inspect the runner identity and both old
and new logs before claiming that acceptance criterion.

Hosted results and exact tested commit identities belong in the source PR
and its current-head qualification report. A queued or running job is not
a pass; a merge-ref check is not an exact-source-head qualification.