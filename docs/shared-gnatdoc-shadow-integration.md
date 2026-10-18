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
GNATdoc output only. Two fresh native copies must match one another and the
reviewed native map. Core's full native artifact is independently regenerated,
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

`record_shared_gnatdoc_shadow.py` reexecutes independent verification and rejects
missing/stale evidence, changed HEAD, mismatched run IDs, tool/trust revisions,
native/output maps, occurrence/navigation results, examples, ratchets, browser
site bindings or tamper restoration. Local success is only `HOSTED_CI_PENDING`;
exact-final-head hosted success and independent review are separate requirements.

No production migration, stable Core hosting, release, deployment, merge or
auto-merge is authorized. `.invalid` destinations must never be published.