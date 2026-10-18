# GNATDOC-009B — Geometry read-only shared shadow integration

This is a continuation of merged [Geometry PR #48](https://github.com/zackboll/opencv_geometry_ada/pull/48),
not a replacement of its blocked investigation. Production generation, deployment,
Core symbol-router URLs, source, examples, category oracle and Alire constraints
are unchanged. Generated shadow sites contain reserved `.invalid` URLs and are
**offline-test, non-deployable review artifacts**.

## Immutable identities and trust

| Component | Commit |
| --- | --- |
| Geometry starting main / merged PR #48 | `ec4d689eac748b7837abd4c3754c3090ca4bf814` |
| Historical source tested by GNATDOC-009 | `8690927853ffa74729206d8997b09046ad3d2246` |
| Historical enhancer | `53a321915da2c5a02a54581040673b61f8595b25` |
| Actual enhancer PR #11 merge | `426f38852ef7dfff264f73ad01aab458f5e12b23` |
| PR #11 implementation head (not the integration pin) | `07aa95a176e2b699b03a9d9199ee0bdad69dbac4` |
| Core 0.5.0 Ada dependency and native artifact | `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` |
| Separate documentation-only Core router fixture | `ccc2190f9bf0712d65a2b9d2983cde7ce68b4bae` |

GitHub reported PR #11 merged at `2026-10-18T05:29:02Z`; its actual merge is
an ancestor of fetched enhancer `origin/main`. Geometry main was exactly the
expected PR #48 merge, with no subsequent changes. The enhancer repository's
working tree is not changed by this integration.

`docs/evidence/gnatdoc009b/authority-transition.json` is the candidate trust
transition submitted for independent review. Its checked-in literal SHA-256 is
`ddf461928a5fc7a3ab4fc9ed0248c237aa465e581249708a5390496b7b447cb5`.
The regular runner can verify but cannot mint, update or approve it. Review of
this PR must include the transition; execution alone does not constitute review.

The record binds every file of the immutable 260-file starting snapshot,
including the original 267-occurrence ledger and navigation oracle. It also binds
the configuration, original pristine native map, authored output hashes, and
byte-identical GNATDOC-005 Core acquisition/type records and GNATDOC-007 authored
contract. The three copied records' provenance is checked against the exact
enhancer merge. Missing files, modified source/authority bytes and changed digests
fail closed. The Core source dependency remains `>=0.5.0 & <0.6.0`.

## Independent current-source reconstruction

The runner clones exact clean PR HEAD into separate `legacy` and `source`
workspaces. Only those disposable build clones receive a temporary Core path pin.
The original generator runs unchanged in `legacy`; `source` produces genuine
GNATdoc output only. Two fresh current native copies must match one another;
a separate historical checkout reproduces the reviewed native map. Core's full
native artifact is independently regenerated,
hash-checked and reconciled before any offline destination is used.

Required tools are Alire 2.1.1, GNAT 16.1.0, GPRbuild Alire 26.0.1 (executable
26.0.0, 2026-04-15), GNATdoc 26.0.0 (20260415), markdown-it-py 3.0.0 and mdurl
0.1.2. The default local GNATdoc 27.0w is not used. The initial local reconstruction
used native OpenCV 4.10.0, Geometry's imgproc backend, and passed:

| Original gate | Observed on starting main |
| --- | --- |
| Documentation Python tests | 232 = 224 original + 8 merged investigation tests |
| Geometry AUnit | 542/542 |
| Public packages / declarations | 2 / 130 |
| Coverage / warning delta | 452/452; 0 added, 0 removed |
| Compiled landing and guide programs | 6/6 |
| Original local / external type links | 167 / 96 |
| Two native acquisitions | Identical; reviewed map matches |
| Full native Core acquisition | Reviewed map matches |

These exploratory checks do not substitute for the exact final-head report or
hosted CI. The final qualification records and immutable Actions runs determine
the disposition, not this baseline table.

## Corrected reference comparison and ownership

The preserved GNATDOC-009 result remains **262 equivalent / 4 shared-only /
1 missing**. `compare_shared_gnatdoc_geometry.py` is a separate success gate;
it does not change or repurpose the blocked diagnostic.

The new source-backed reconstruction observed **263 equivalent / 4 shared-only /
0 missing = 267 occurrences**, **171 local / 96 external** links. Every occurrence
is compared at decoded declaration offsets, using the unchanged Geometry source
matcher, actual local declaration owners and the independently reconstructed Core
inventory. Router and offline-native URLs are compared by qualified declaration
identity, not string equality. The four typed constants retain their owners:

- `Identity_Affine_Transform` → `OpenCV.Geometry.Affine_Transform_2D`.
- `Identity_Perspective_Transform` → `OpenCV.Geometry.Perspective_Transform_2D`.
- `No_Edge` → `OpenCV.Geometry.Subdiv2D.Edge_Id`.
- `No_Vertex` → `OpenCV.Geometry.Subdiv2D.Vertex_Id`.

`subtype Contour is OpenCV.Point_Array;` has exactly one base-type link. The
verified Core destination recovered from acquisition, not synthesized, is:

```text
https://core.invalid/f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f/api/
ea2ebcbc108269c77d7c6d44d2dabdfb5f6d0179ad5622b1be3cbceaee5c44aa.html
#da696e09a1f1b297516365244e16533e23cca626f26df4bb3f727a64beb697b0
```

All 130 source/native navigation entries are checked for package ownership,
category, order, labels, source-order overload numbering, page, anchor and full
profile. Both public packages remain independent. Landing, five guides and guide
stylesheet must retain their original output bytes and executable ownership.

## Qualification commands and sequencing

In a separate virtual environment, install the exact detached enhancer merge
non-editably plus the pinned Markdown dependencies and Playwright 1.58.0. Install
Chromium with Playwright. Node original suites retain Playwright 1.64.1.
From a clean Geometry checkout run (paths below are illustrative absolute paths):

```sh
/tmp/shadow-tools/bin/python /path/to/geometry/scripts/qualify_shared_gnatdoc_shadow.py \
  --expected-head "$(git -C /path/to/geometry rev-parse HEAD)" \
  --enhancer /path/to/enhancer --core /path/to/core --workspace /tmp/geometry-shadow
/tmp/shadow-tools/bin/python /path/to/geometry/scripts/qualify_original_gnatdoc_browser.py \
  --workspace /tmp/geometry-shadow --core-repository /path/to/core \
  --gnatdoc-prefix /tmp/geometry-shadow/gnatdoc \
  --playwright-module /tmp/doc-browser/node_modules/playwright --chromium /path/to/chromium
/tmp/shadow-tools/bin/python /path/to/geometry/scripts/qualify_shared_gnatdoc_adversarial.py \
  --workspace /tmp/geometry-shadow --enhancer /path/to/enhancer
/tmp/shadow-tools/bin/python /path/to/geometry/scripts/qualify_shared_gnatdoc_browser.py \
  --workspace /tmp/geometry-shadow --chromium /path/to/chromium
/tmp/shadow-tools/bin/python /path/to/geometry/scripts/record_shared_gnatdoc_shadow.py \
  --workspace /tmp/geometry-shadow
```

Do not run mutation tests concurrently with Chromium on the same workspace.
The original router tests use a separately built fixture, never as the Ada
dependency. Offline Core interception serves only approved URLs and hash-verified
native HTML/CSS. Chromium covers both packages at 1280px/390px, light/dark and
JavaScript enabled/disabled, all 130 navigation entries, profiles, overloads,
history, direct declarations/reload, local and approved external links, repaired
Contour and authored headings. Traces and sites belong to artifacts, not Git.

The separate workflow triggers only on pull requests, checks out exact PR HEAD
and immutable dependency revisions, grants only `contents: read`, executes the
original and shadow gates, and uploads explicitly non-deployable review artifacts.
It has no Pages, OIDC, release or publishing steps. The original documentation
workflow is unchanged.

## Readiness and remaining production blockers

### Full locally qualified implementation

`docs/evidence/gnatdoc009b/qualified/` records the complete, independently
recorded run at **`268e95b0529a39cc309e1663a7c98f3545275634`**, run ID
`dd8403ae-24f6-4a54-9c3f-3e86f628c10b`. This includes:

- All original 232 Python tests, 542/542 AUnit and six compiled/executed examples.
- Original/native/shadow coverage 452/452 and warning delta 0 added/0 removed.
- Two independent pristine copies and enhanced copies, deterministic and idempotent.
- Native preservation: two public packages, 130 declarations, complete profiles.
- Source-backed 263 equivalent / 4 shared-only / 0 missing occurrence ledger;
  171 local / 96 external type links; unchanged 130-entry navigation oracle.
- Landing/five-guide/stylesheet byte parity and unchanged example ownership.
- All four unchanged original Chromium suites, including the separate router.
- **26 observed, rejected and hash-restored adversarial cases**, including
  coordinated tampered output plus rewritten manifest authorization.
- **6,904 real Chromium assertions**, all eight desktop/mobile, light/dark,
  JavaScript on/off cells; 16 history traces; all guide API links source/native
  checked; repaired Contour and every approved external Core identity exercised.
- Independent recorder: `full_shadow_qualification: true`, no failures,
  disposition `HOSTED_CI_PENDING` (never production readiness).

The exact implementation-head original documentation hosted run passed:
<https://github.com/zackboll/opencv_geometry_ada/actions/runs/39102179995>.
Its shadow hosted run is
<https://github.com/zackboll/opencv_geometry_ada/actions/runs/39102179882>.
Reports retain their original tested SHA, run bindings and hashes; checking in
evidence does not retroactively qualify a later evidence-only commit. Exact
final-head Actions results must be checked on PR #50. Large logs, generated
sites and browser trace ZIPs remain review artifacts, never committed source.

### Intermediate evidence (not final-head readiness)

`docs/evidence/gnatdoc009b/intermediate/` records the independent reconstruction
at `5728e76b2682a9de3b689bbad85c786481c40c88`: all original gates, full native
inventory, 267-occurrence ledger, 130-entry navigation oracle, authored parity,
six examples, determinism/idempotence, and four unchanged original Chromium
suites passed. The shadow Chromium report passed **4,648 assertions in eight
matrix cells**, with **16 history traces** and Chromium `156.0.8078.4`.
The separate exploratory adversarial record passed 25 observed/restored cases.
It is explicitly not represented as the same committed-head qualification run.

Subsequent hardening adds immutable Git-tree package-inventory checking,
historical occurrence/profile equality, full authored-guide API browser checks,
and coordinated output/manifest forgery. Those changes need a fresh exact-head
run. A concurrent-development reconstruction at `5a9e14d4ee79fac873f1f9ba2aa743366bb3947b`
correctly failed its end-of-run clean-snapshot check after implementation files
changed; no readiness credit is taken for that failed run.

`record_shared_gnatdoc_shadow.py` reexecutes independent verification and rejects
missing/stale evidence, changed HEAD, mismatched run IDs, tool/trust revisions,
native/output maps, occurrence/navigation results, examples, ratchets, browser
site bindings or tamper restoration. Local success is only `HOSTED_CI_PENDING`;
exact-final-head hosted success and independent review are separate requirements.

No production migration, stable Core hosting, release, deployment, merge or
auto-merge is authorized. `.invalid` destinations must never be published.

## GEOM-029 R1: historical authority is not a current-source golden file

The failure at [run 39150274405](https://github.com/zackboll/opencv_geometry_ada/actions/runs/39150274405)
compared legitimate GEOM-029 shim changes with pre-GEOM-029 hashes. Beyond that
first failure, current HTML contains updated comments, the historical occurrence
ledger contains old source lines, the authored contract embeds old native hashes,
and the AUnit denominator increased from 542 to 547. The always-run recorder also
failed to create an evidence directory when qualification stopped early.

The authority transition and its literal digest are unchanged. Historical source
is checked through Git objects at `ec4d689eac748b7837abd4c3754c3090ca4bf814`.
Historical GNATDOC-009/009B evidence is byte-compared with the reviewed merge
`2101e5c8757898b6904becfb899247e9f685c25b`, not rewritten or relabeled. Two new
historical native acquisitions must match the original immutable map; the old
267-occurrence ledger and 130-entry navigation oracle are checked against that
source. Historical AUnit execution must still register and pass exactly 542.

Current public/implementation/test inputs are bound to exact PR HEAD Git objects,
including inventory checks. Two current native acquisitions must agree. Each
independent publication verification regenerates native HTML again with the
pinned GNATdoc binary and compares it with both acquisitions. It then binds the
generated presentation manifest to those bytes and resolves type-mark positions
using the original source matcher, independent of the shared enhancer. The
current source-backed navigation oracle still requires 130 declarations in the
same two public packages. No historical source-line equality is imposed on new
source. Changes in declaration count require a separately reviewed policy change.

The immutable authored contract is retained. A disposable `current-authored.json`
changes **only** its native hash map; `current-shadow.toml` changes only that
contract path and digest. Both derivations are recomputed during verification.
Guide input/output hashes, example ownership, categories, original documentation
machinery, enhancer and Core requirements stay fixed. Coordinated generated
output/manifest changes cannot establish native authority. This is not an
authority-update command and does not affect the production generator.

Current AUnit evidence enumerates the suites wired into `Tests`, accounts for
every supported `Caller.Create` registration, and requires unique names, matching
executed/successful case names and exact totals, zero failures/errors, and at least
542 registrations. Unsupported dynamic suite construction fails closed. The
current 547 includes three new Subdiv2D chunking and two Voronoi facet cases;
count-guard and failure-output assertions extend existing cases.

Original browser suites, the eight-cell shadow matrix, original thresholds,
adversarial restoration, and independent run/HEAD-bound readiness remain required.
Early failure now writes non-ready evidence even when no workspace existed.