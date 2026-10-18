# GNATDOC-009 — blocked Geometry shadow qualification

**Disposition: `BLOCKED_BY_SHARED_TOOL`. Not ready for independent integration
approval. No production migration or deployment is authorized.**

The explicit type-link review gate found a missing shared-enhancer capability.
Work stops at that gate: no shadow CI workflow, readiness claim, or deployment
configuration has been introduced. This report and diagnostic preserve the
reproduction for a separately reviewed shared-tool fix. The enhancer repository
was not modified.

## Exact identities

| Component | Verified revision |
| --- | --- |
| Geometry main and original/native tested source | `8690927853ffa74729206d8997b09046ad3d2246` |
| Shared enhancer, merged PR #9 | `53a321915da2c5a02a54581040673b61f8595b25` |
| Core 0.5.0 Ada dependency and offline native artifact | `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` |
| Core documentation-only symbol-router fixture | `ccc2190f9bf0712d65a2b9d2983cde7ce68b4bae` |
| Imgproc reference integration | `6715ed13ee8d2ea0f4ac089722ed926cfef77eb6` |

All repositories were fetched and the isolated starting checkouts were clean.
The enhancer commit has two parents and is an ancestor of fetched `origin/main`.
An isolated Python environment installed that checkout non-editably; every
installed module and asset was compared with its exact source bytes. The
diagnostic records the installed hashes and `direct_url.json`. `pip check`
passed. Markdown dependencies are exactly `markdown-it-py==3.0.0` and
`mdurl==0.1.2`.

The unchanged manifest remains version `0.3.1`, with
`opencv_core = ">=0.5.0 & <0.6.0"`. Only disposable acquisition checkouts received
temporary Alire source pins. Actual `OPENCV_CORE_ALIRE_PREFIX` resolved to
`/tmp/gnatdoc009-core`, a clean Core 0.5.0 Git checkout at the required SHA.
The router fixture was generated separately and never used as that dependency.

## Independently executed original baseline

Environment: Alire 2.1.1, GNAT 16.1.0, GPRbuild Alire 26.0.1 (executable
26.0.0, 2026-04-15), GNATdoc 26.0.0 (20260415). Native OpenCV is **4.10.0**,
using the **imgproc** Geometry backend. The unrelated default GNATdoc 27.0w
was not used.

The original `scripts/generate_docs.sh` ran unchanged in a fresh detached clone.

| Gate | Executed result |
| --- | --- |
| Library `alr -n build` | Pass |
| Original Python documentation tests | **224 tests, pass** |
| Public packages | **2**, exact expected identities |
| Native declaration sections | **130**, including 79 subprograms |
| Documentation coverage | **452/452**, no gaps or baseline changes |
| Documentation warning ratchet | **0 added, 0 removed** |
| Original source-backed navigation | **130 declarations**, 12 categories |
| Landing program | Compiled and executed, exit 0 |
| Five existing guide programs | Compiled and executed, all exit 0 |
| Original Core-router Chromium integration | Pass at 1280px and 390px |
| Original presentation Chromium suite | Pass |
| Original navigation Chromium suite | Pass |
| Original guides Chromium suite | Pass, desktop/mobile, light/dark, JS on/off |
| Library AUnit suite | **542 registered tests, 542 successful** |

The first Python run failed because the existing generated-site tests expect
the source-only Core checkout at the sibling `core` path. Providing a separate
exact Core 0.5.0 clone at `/tmp/core` made the unchanged 224-test suite pass.
The first landing-program launch used the wrong executable directory; the
actual project specifies `obj/docs-example`. It was then executed successfully
there, followed by all five programs in `obj/docs-examples`. These were harness
errors, not changes or waivers to original tests.

## Pristine and partial shadow results

Two native-only acquisitions from the real Geometry public Ada source are
byte-identical. No legacy postprocessor ran on either acquisition. Native
filenames and every declaration anchor/profile are in the machine-readable
report. The four native file hashes also equal the historical GNATDOC-007
reviewed acquisition, independently of the current aggregate counts.

Full Core 0.5.0 source specifications and genuine native GNATdoc output were
reacquired. All **195 public Core units** reconcile through the approved
external-dependency mechanism, and the reconstructed type inventory equals
the historical reviewed Core inventory. No Core pages enter Geometry's two
published public packages.

The diagnostic verifies three immutable historical authority records by
literal SHA-256, and validates actual input bytes against those authorities.
It does not approve whatever hashes happen to be observed. Its configuration
retains Geometry's category file and uses `authored-markdown` for the genuine
five guides and original compiled-example sources.

Two enhanced outputs were generated in separate output directories from the
two native acquisitions, using the same verified immutable input bundle.
This is **not** the requested final two-independent-workspace shadow runner.
Both outputs passed full shared publication reconstruction, native declaration
preservation, dry-run immutability, byte-idempotence and byte determinism.
The landing page, five rendered guides and approved guide stylesheet retain
exact byte parity with the original output.

Published operation labels, category membership, ordering and all 130 native
destinations are compared directly with the unchanged Geometry
`enhance_gnatdoc_navigation.entries` oracle, without using the shared
destination resolver to compute expectations. Its full profiles and
source-order overload ordinals remain in `original-navigation.json`.

These partial successes do **not** establish shadow compatibility.

## Type-link reconciliation: 167/96 versus 171/95

The occurrence comparison has **267 rows**: 262 equivalent references, four
shared-only local references, and one lost external reference. Each row records
the owning Geometry package, complete source declaration/profile, source line,
decoded token offset, referenced type, both actual link targets, native owner,
and independently qualified external Core owner where applicable.

| Declaration | Difference | Classification |
| --- | --- | --- |
| `Identity_Affine_Transform` | Added `Affine_Transform_2D` local link | Valid typed constant; legacy policy excludes constants |
| `Identity_Perspective_Transform` | Added `Perspective_Transform_2D` local link | Valid typed constant; legacy policy excludes constants |
| `OpenCV.Geometry.Subdiv2D.No_Edge` | Added `Edge_Id` local link | Valid typed constant; legacy policy excludes constants |
| `OpenCV.Geometry.Subdiv2D.No_Vertex` | Added `Vertex_Id` local link | Valid typed constant; legacy policy excludes constants |
| `Contour` | Lost `OpenCV.Point_Array` external link | **Blocking missing ordinary-subtype-base support** |

All four added local destinations belong to actual preceding public type
declarations in the correct package. The legacy `type_positions` function
explicitly returns no positions for declarations beginning with a constant
name. Their addition is explained, not automatically waived by link counts.

The lost reference is Geometry source line 76:

```ada
subtype Contour is OpenCV.Point_Array;
```

Its native Geometry section is:

```text
4f90dae6ae3d13b7eca2073a4084d7aafc29ca4b1a5df10de478124a1cd77135.html
#0c3fbeacf849b3776f9533db4d982b2125bc49319590c9215acbc2ffaff07503
```

Core's independently verified owner is `OpenCV.Point_Array`, declared in
`src/opencv.ads`, line 81, at Core 0.5.0's native destination:

```text
ea2ebcbc108269c77d7c6d44d2dabdfb5f6d0179ad5622b1be3cbceaee5c44aa.html
#da696e09a1f1b297516365244e16533e23cca626f26df4bb3f727a64beb697b0
```

Legacy output links to
`https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=OpenCV.Point_Array`.
The expected shadow contract is the verified native page/fragment under
`https://core.invalid/f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f/api/`.
These URLs are deliberately different contracts; the blocker is the absence
of **any** shared link at that source occurrence, not string inequality.

`OpenCV.Point_Array` is explicitly included in the diagnostic's dependency
configuration, so adding it to an allowlist cannot repair the omission.
Shared `syntax.TYPE_MARK` recognizes `is new`, `is access`, and
`is not null access`, but not an ordinary `subtype ... is Qualified.Type` base.

### Minimal installed-package reproduction

With the non-editable package installed from the exact enhancer checkout:

```sh
/tmp/gnatdoc009-tools/bin/python -c \
  'from ada_gnatdoc_enhancer.syntax import type_positions; print(type_positions("subtype Contour is OpenCV.Point_Array;"))'
```

Actual: `[]`. Required: a typed occurrence for `OpenCV.Point_Array`.
The full real-source diagnostic confirms this omission survives actual
enhancement even when its external native destination is explicitly configured.
This must be fixed and reviewed in the shared tool, not patched in Geometry.

## Reproduce the real-source gate

`scripts/investigate_shared_gnatdoc_types.py` consumes separately acquired real
sources, pristine native artifacts, and original legacy output. It requires a
new workspace and exits **2** with `BLOCKED_BY_SHARED_TOOL` when the lost
source-backed reference is observed. Invocation for this investigation:

```sh
/tmp/gnatdoc009-tools/bin/python \
  /home/zboll/git/opencv/geometry-gnatdoc009/scripts/investigate_shared_gnatdoc_types.py \
  --source /tmp/gnatdoc009-native \
  --legacy /tmp/gnatdoc009-legacy/_site \
  --pristine /tmp/gnatdoc009-pristine-first \
  --second-pristine /tmp/gnatdoc009-pristine-second \
  --core /tmp/gnatdoc009-core \
  --core-native /tmp/gnatdoc009-core-native \
  --enhancer /tmp/gnatdoc009-enhancer \
  --workspace /tmp/gnatdoc009-type-gate-final
```

The evidence directory retains compact qualification JSON and the complete
occurrence comparison, not generated sites, build trees, or large logs. Local
sites and logs remain under `/tmp/gnatdoc009-*`; log hashes are recorded for
traceability, not represented as hosted downloadable artifacts.

## Explicitly not completed

- No separate PR-only workflow or complete isolated qualification runner.
- No full shadow Chromium matrix or offline Core interception qualification.
- No complete adversarial mutation campaign or independent readiness recorder.
- No exact-final-head hosted shadow CI success or integration-readiness claim.
- No production Core HTTPS hosting verification; offline native reconstruction
  and original router-fixture browser tests cannot establish that.

Eight focused diagnostic tests check occurrence offsets, markup rejection,
symlink rejection, duplicate destinations and published navigation parsing.
They are not substitutes for the requested full adversarial campaign.

The production workflow, generator, navigation oracle, validators, authority
baselines, Ada/C++ implementation and manifest remain unchanged. Resume only
after a separately merged shared-tool fix and a reviewed authority transition,
following the GNATDOC-008C rule that the runner must not mint its own approval.