# AArch64 cross-build and installation

`scripts/cross_install_geometry.sh` configures, builds and installs Geometry,
then independently cross-links the existing Ada-only and mixed Ada/C++
consumers against **installed** Core and Geometry projects. It reuses
`scripts/cross_geometry.py` and its production build/GPRinstall path; it is
not a new SDK installer or a replacement for the fail-closed preflight.

## Prerequisites and short command

Supply an existing compatible **installed Core** prefix, target Ada and C++
compilers, the matching Ada runtime, a complete target development sysroot
with OpenCV headers/libraries/pkg-config metadata, and host GPRconfig,
GPRbuild, GPRinstall, Python 3, pkg-config, Git (for Git sources) and readelf.
Core must have both installed GPR projects, both static archives and ALIs.
The dependency remains `opencv_core >=0.5.0 & <0.6.0`; Core 0.5.2 is **not**
required. A Core installation without a saved `.cgpr` is supported.

The intended GNAT Pro 25.0w / GCC 12.3.1 / Scarthgap invocation is:

```sh
sh scripts/cross_install_geometry.sh \
  --target aarch64-linux-gnu \
  --toolchain-bin /usr/local/gnat/aarch64-linux-gnu/bin \
  --runtime /usr/local/gnat/aarch64-linux-gnu/lib/gcc/aarch64-linux-gnu/12.3.1/rts-native \
  --sysroot /usr/local/yocto/scarthgap/aarch64 \
  --core-prefix /usr/local/lib/aarch64-linux-gnu/ada \
  --prefix /usr/local/lib/aarch64-linux-gnu/ada \
  --profile release
```

These are example **inputs**, not hardcoded SDK defaults. Separate Core and
Geometry prefixes are equally supported. Prefixes may be identical but
must not nest inside one another, a source checkout, sysroot or temporary
workspace. Existing files are never replaced: choose a fresh Geometry
installation (or a Core-only shared prefix), not an in-place Geometry upgrade.
No Core rebuild is requested and no Core files or metadata are removed.

Run from an environment without host search overrides (`GPR_PROJECT_PATH`,
`ADA_PROJECT_PATH`, `CPATH`, `LIBRARY_PATH`, `PKG_CONFIG_PATH`, etc.). The
preflight rejects contamination rather than silently discarding it. Only
target-local pkg-config directories under the supplied sysroot are selected.
The tools must be available on PATH, or selected using the existing explicit
`OPENCV_CROSS_GPRBUILD`, `OPENCV_CROSS_GPRINSTALL`,
`OPENCV_CROSS_PKG_CONFIG`, `OPENCV_CROSS_READELF` overrides. Likewise
`OPENCV_CROSS_ADA` and `OPENCV_CROSS_CXX` select actual compiler executables.
All advanced overrides remain subject to the existing validation.

## Automatic compiler configuration

Absent an explicit `OPENCV_CROSS_GPR_CONFIG`, a compatible installed Core
configuration (`share/gprconfig/TARGET.cgpr` or
`share/gprconfig/opencv_core-TARGET.cgpr`) may be reused. Otherwise the
bootstrap invokes GPRconfig directly, following Core PR #92:

```sh
gprconfig --batch --target="$target" \
  --config="Ada,,$runtime,$ada_compiler_directory,GNAT" \
  --config="C++,,,$cxx_compiler_directory,$cxx_executable_basename" \
  -o "$config_file"
```

No unprefixed compiler aliases, Python patches, generated-config edits or
manually authored projects are needed. Successful generation does not bypass
target, driver, runtime or linker validation. GNATLS must come from the
selected Ada installation; a freshly compiled Ada probe establishes the
actual ALI signature, not a guess based on GCC's major version.

The full Core compatibility preflight still checks contained installed GPR
paths, AArch64 archive members, compiler identities and every Core ALI.
Target OpenCV dependencies and their complete symbol-version closure must
resolve inside the sysroot. OpenCV 4.9.0 uses native `imgproc` + `core`;
OpenCV 5.0 uses native `geometry` + `core`. There is no Ada Imgproc dependency.
Linux retains the static-PIC shim and GNAT 12 profile switches/warnings.
macOS and Windows build strategies are unchanged.

## Sources, installation and diagnostics

The default source is this checkout. Git sources must be clean and are
exported by exact HEAD commit. Use `--source-root /absolute/source` to select
another checkout or an unpacked `.git`-free release tree. Git is queried only
when that exact directory has a `.git` marker; an enclosing unrelated
repository is never used. Git-free sources exclude native objects, libraries,
ALIs, generated configurations and Alire state, and record a deterministic
`staged-source-sha256:` identity of the retained content, **not** a Git commit.
Do not mutate a selected source tree while a build is running.

Installed artifacts include:

```text
share/gpr/opencv_geometry.gpr
share/gpr/opencv_geometry_shim.gpr
lib/opencv_geometry/libopencv_geometry_ada.a
lib/opencv_geometry_shim/libopencv_geometry_shim.a
share/gprconfig/opencv_geometry-aarch64-linux-gnu.cgpr
share/doc/opencv_geometry/LICENSE
share/doc/opencv_geometry/THIRD_PARTY_NOTICES
share/doc/opencv_geometry/cross-aarch64-linux-gnu/
```

GPRinstall first installs only the two Geometry projects into an owned staging
prefix. Installed GPRs, archive members, ALIs, identities and notices are
checked before a no-overwrite merge into the requested external prefix.
Core's configuration name is never reused as the Geometry output name.
The exported switch-only configuration correction preventing dangling
installed imports remains in place; installed projects are not patched.

Build, install, source identity, preflight and independent consumer logs are
retained under the Geometry documentation directory. The saved evidence
records the original build workspace and durable consumer configuration.
Temporary production/consumer workspaces are removed only after success.
On failure, the nonzero tool status and diagnostic workspace are retained
and printed. Installation is not transactional: a failed publication or
post-install consumer gate can leave partial Geometry files, which must be
inspected before retrying. The workflow never rolls back by deleting an
external prefix, which could contain Core or unrelated content.

## Independent installed consumers

The workflow copies `tests/installed_consumers/` into an external directory,
then reuses `tests/cross/qualify_reference_consumers.py`. Both projects resolve
only through `CORE_PREFIX/share/gpr:GEOMETRY_PREFIX/share/gpr`, use the
durable configuration and explicit sysroot, and preserve `gprbuild -R`.
The trace must include all four installed archives and selected tools.
Executables must be ELF64 little-endian AArch64, use a loader present in the
sysroot, have the expected native OpenCV dependencies and no RPATH/RUNPATH,
and satisfy complete target dependency/symbol-version closure. Link-time
`-rpath-link` is not a deployment RPATH.

For a manual fresh consumer directory containing the existing consumer
sources, the equivalent Ada build is:

```sh
GPR_PROJECT_PATH="$core_prefix/share/gpr:$prefix/share/gpr" \
  gprbuild --config="$prefix/share/gprconfig/opencv_geometry-$target.cgpr" \
  -P ada_consumer.gpr -p -v -R \
  -cargs:Ada "--sysroot=$sysroot" \
  -largs "--sysroot=$sysroot" -Wl,-t "-Wl,-rpath-link,$sysroot/usr/lib"
```

Use all target loader search directories as `-rpath-link` inputs when the
sysroot uses multiarch/lib64 locations. The qualification tool selects these
from the existing sysroot loader-directory machinery automatically.
Mixed consumers additionally use `-XCONSUMER_CXX_FROM=configuration`,
`-XCONSUMER_OPENCV_INCLUDE=-I...`, the selected backend and
`-cargs:C++ --sysroot=...`.

## Fresh-install qualification and evidence profiles

Use a **fresh, nonexistent Geometry prefix** and an already verified Core
installation. This forces automatic GPRconfig generation even when Core has
a reusable configuration, verifies production workspace cleanup, repeats
fresh installed consumer links after cleanup, and repeats links from
relocated copies of the installed prefixes. Core is never moved or rebuilt.
Evidence and PASS/FAIL dispositions are retained. Unset
`OPENCV_CROSS_GPR_CONFIG` first.

```sh
sh tests/cross/qualify_geometry_cross_install.sh \
  --target aarch64-linux-gnu \
  --toolchain-bin /usr/local/gnat/aarch64-linux-gnu/bin \
  --runtime /usr/local/gnat/aarch64-linux-gnu/lib/gcc/aarch64-linux-gnu/12.3.1/rts-native \
  --sysroot /usr/local/yocto/scarthgap/aarch64 \
  --core-prefix /usr/local/lib/aarch64-linux-gnu/ada \
  --prefix /usr/local/lib/aarch64-linux-gnu/geometry-cross-qualification \
  --profile release
```

Keep these evidence profiles distinct:

| Profile | Scope |
| --- | --- |
| Debian GNU GNAT 12 AArch64 reference | Public reference compiler/sysroot; not proprietary vendor qualification. Existing `qualify_debian_aarch64_reference.sh` includes QEMU/AUnit. |
| AdaCore GNAT Pro 25.0w / GCC 12.3.1 + Yocto Scarthgap + OpenCV 4.9.0 | User-qualified PR #55 head `ff4089671cb11837416fe1aa9892018c5fa24fda`: fresh build/install and installed/relocated Ada/mixed consumer cross-links passed. [0.3.3 provenance and byte-equivalence record](release-0.3.3-preparation.md). Core PR #92's separate qualification does not qualify Geometry. |
| Historical GNAT Pro 25.2 / GCC 13.3.1 + Scarthgap | Separate [historical record](adacore25-scarthgap-qualification.md), including its exact sources and 542-test QEMU result. Not evidence for 25.0w. |

The current native Geometry suite registers **547** tests, not the historical
542. Synthetic tests validate orchestration/rejection logic only. The new
entry point does **not execute** target binaries; no runtime correctness or
hardware qualification is implied. Comprehensive `qualify_target.sh`, vendor
provenance adapters, QEMU and AUnit paths remain separate and unchanged.
No version, tag, release or Alire-index change is part of this workflow.