# GNATdoc documentation campaign progress

Persistent resumption record for the GEOMETRY-DOC campaign: bring the public
documentation of `opencv_geometry_ada` to the standard of `opencv_core_ada`
and `opencv_imgproc_ada`. Documentation only: no production algorithm, C ABI,
Ada API declaration, contract or profile, manifest dependency, compiler or
linker policy, or runtime behavior changes. Never infer that a PR merged;
check GitHub before starting a dependent phase, and reconcile this record
with the actual remote heads after any interruption.

## Identity

- Campaign starting Geometry `main`:
  `517c804e7e6ea90c1b420486caa91fe506d189aa` (merge of PR #26), verified as
  `origin/main` on 2026-10-13. No open PRs. No documentation branch or
  documentation worktree existed; the other Geometry worktrees (task
  branches 021 to 027, bindgen and CV5 campaigns, three detached `/tmp`
  checkouts) were left untouched.
- References, verified with `git ls-remote` on 2026-10-13 and equal to the
  campaign brief:
  - Core `main` `c0709f864a2f426c40eeaf1d21486c6d9859a741` (includes
    CORE-DOC PRs #65 to #74; version `0.5.0-dev`).
  - Imgproc `main` `19ce3641254a3a9f5c97feca10fb3f2ef4a7f2b5` (includes
    IMGPROC-DOC PRs #52 to #62, merged). Per-phase reference snapshots:
    DOC-001 `3c99f34`, DOC-002 `df8d8d6`..`0685c0b`, DOC-003 `e35e758`,
    DOC-004 `cac3916`, DOC-005 `1883342`; no documentation file changed
    after `1883342`.
- Documentation Core: `opencv_core` 0.4.1,
  `386c5360ac51f2b62e522853d94290aec4ee14a0`. Core `main` is outside
  Geometry's `opencv_core >=0.2.0 & <0.5.0` constraint, so the newest Core
  release of the cross-platform matrix is used. The Alire index's
  `opencv_core=0.4.1` has the same origin commit.
- Isolated layout (mirrors CI's two-checkout layout):
  - `/home/zboll/git/opencv/geometry-doc-campaign/geometry` — worktree of
    the canonical repository, branch per phase.
  - `/home/zboll/git/opencv/geometry-doc-campaign/core` — detached Core
    worktree at `386c536`, the `../core` pin target, never edited.
  - `/home/zboll/git/opencv/geometry-doc-refs/` — reference clones of Core
    and Imgproc and the per-phase Imgproc snapshots.
  The canonical worktree `/home/zboll/git/opencv/geometry` and the shared
  `/home/zboll/git/opencv/core` checkout were not modified. The temporary
  pin (`alr -n pin opencv_core --use=../core`) lives only in the campaign
  worktree's `alire.toml` and is never committed.
- Tools: Alire 2.1.1; GNAT 16.1.0; GPRbuild Alire 26.0.1 (executable 26.0.0
  (2026-04-15)); GNATdoc 26.0.0 (20260415) installed by
  `alr install gnatdoc_bin=26.0.0` into `.doc-tools/gnatdoc-26.0.0`;
  GNATformat 26.0.0; Python 3.13.5; system OpenCV 4.10.0 (pkg-config
  `opencv4`, native `imgproc` backend). The `gnatdoc` on `PATH` is GNAT
  Studio's 27.0w and is refused by the generator. actionlint 1.7.12 and
  ShellCheck 0.11.0 are external lint tools.

## Gate 0 baseline

- AUnit on `517c804` with Core 0.4.1 (`386c536`) and OpenCV 4.10.0:
  `alr -n build` succeeded; `alr -n -C tests run` — 542 run, 542
  successful, 0 failed assertions, 0 unexpected errors.
- `sh scripts/run_native_tests.sh`: closest-ellipse, Subdiv2D
  allocation-failure and Float32 geometry/reset/ownership checks all PASS.
- GitHub Pages (API, 2026-10-13): configured with `build_type: workflow`,
  source `main`, `github-pages` environment with a custom branch policy
  allowing only `main`; zero deployments; the site URL returns 404.
- Hosted CI on `517c804` was not inspected for this phase; the
  documentation workflow does not exist on `main` yet.

## Execution model

Stacked review PRs: each phase branches from the previous phase's verified
head, its PR targets the previous phase's branch (the first targets `main`),
and work continues immediately after the PR opens. No PR is merged,
auto-merge stays off, nothing is force-pushed or amended after publication,
no release or tag is made, and Pages is never deployed from a feature
branch. Each PR body records its parent PR, parent commit and phase-specific
delta. Hosted CI is checked once per newly published head. If an ancestor
merges, verify GitHub state and reconcile downstream bases without rewriting
published history.

## Phase status

| Phase | Branch | PR (base) | State |
| --- | --- | --- | --- |
| DOC-001 infrastructure | `feature/geometry-doc-001-gnatdoc-pages` | pending (`main`) | Qualified locally |

## Feature-parity matrix (Core `c0709f8`, Imgproc `19ce364` versus Geometry)

| Capability | Reference | Geometry after DOC-001 |
| --- | --- | --- |
| Pinned generation with version gates | `scripts/generate_docs.sh` | Adapted; Core identity gate (exact commit, own checkout, clean) instead of a `../core` existence check |
| Public/internal GPR split | `docs_api.gpr`, `docs_internal.gpr` | Adapted; production switches plus `-Werror` in both |
| Partial-generation detection | `generate_docs.sh` grep | Same |
| Declaration-identity warning comparator | Imgproc `compare_gnatdoc_warnings.py` (36 tests) | Imgproc's plus the multi-line discriminant header fix (41 tests) |
| Warning baseline | Imgproc/Core empty (0) | 360 identities (target 0) |
| Site validator | Imgproc `validate_docs.py` | Two packages, per-package probes, aspect-free profiles, package-description probes |
| Validator mutation tests | Imgproc `test_validate_docs.py` | 53 tests (40 synthetic parent/child, 13 generated site) |
| Landing page | `docs/index.html` | Unstyled until DOC-003 |
| Compiled landing example | `docs/example.*`, run in CI | Same |
| PR artifact, diagnostics, main-only Pages | `.github/workflows/documentation.yml` | Adapted to Geometry's pinned Core layout |
| Deterministic regeneration check | CI `diff -r` | Same |
| Coverage and comment-only checkers | Imgproc `check_doc_coverage.py`, `check_comment_only.py` | DOC-002 |
| Theme, highlighting, type links | Core/Imgproc DOC-003 tools | DOC-003 |
| Searchable navigation | Imgproc operation-level browser | DOC-004; two packages |
| Generic-instance summaries | Core `enhance_gnatdoc_instances.py` | Not applicable: no public generic instantiations or tagged types |
| Guides and compiled examples | Imgproc DOC-005 | DOC-005 |

## Initial GNATdoc inventory (`517c804`, pinned tools)

Two public packages, `OpenCV.Geometry` and `OpenCV.Geometry.Subdiv2D`; 4 HTML
pages (landing, native index, two package pages). No internal or Core
package is published. 360 warnings:

| Message | `OpenCV.Geometry` | `OpenCV.Geometry.Subdiv2D` |
| --- | ---: | ---: |
| parameter not documented | 102 | 44 |
| return value not documented | 54 | 22 |
| component not documented | 40 | 20 |
| entity not documented | 26 | 13 |
| enumeration literal not documented | 24 | 15 |
| Total | 246 | 114 |

The `OpenCV.Geometry` package itself is undocumented (one entity warning).
The Subdiv2D package description, placed before `package` after its
`private with` clauses and a blank line, does render natively under
"Description" and draws no warning. Two Subdiv2D warnings concern the
private-part `overriding procedure Finalize` (entity and parameter), which
GNATdoc checks but does not publish.

Declarations (visible part, one native section each, 130 in total):

| Package | Total | Functions | Procedures | Types | Subtypes | Constants | Overloaded names (declarations) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `OpenCV.Geometry` | 86 | 54 | 0 | 28 | 2 | 2 | 22 (44) |
| `OpenCV.Geometry.Subdiv2D` | 44 | 22 | 3 | 17 | 0 | 2 | 2 (4): `Insert`, `Voronoi_Facets` |

Rendering facts found while building DOC-001 (input to DOC-002):

- GNATdoc 26.0.0 omits aspect specifications from snippets: the `Post`
  contracts of both `Closest_Ellipse_Points`, `Convex_Hull_Indices`,
  `Convexity_Defects` and `Transform_Points` overloads are invisible on the
  page, so their guarantees must be stated in the comments.
- Several comments document the next declaration rather than their own
  subject because a type is declared between them: the Convex_Hull notes
  attach to `Hull_Orientation`, the Hu_Moments notes to
  `Hu_Moment_Index`, the Convex_Hull_Indices notes to
  `Point_Index_Array`, the Box_Points notes to `Box_Vertex_Index`, the
  Match_Shapes notes to `Shape_Match_Method`, the Locate_Point notes to
  `Contour_Point_Location`, the Minimum_Enclosing_Circle notes to
  `Enclosing_Circle`, the Minimum_Enclosing_Triangle notes to
  `Triangle_Vertex_Index`, the transform-matrix notes to
  `Affine_Row_Index`, and the Moments_Result notes describe
  `Compute_Moments`. The Subdiv2D section preambles ("Extraction",
  "Navigation", "Voronoi diagram", including the Voronoi recomputation and
  failure paragraph) are detached by blank lines and never render at all.
- One comment describes three Float32 overloads at once (`Fit_Ellipse`,
  `Fit_Ellipse_AMS`, `Fit_Ellipse_Direct`) but renders only on the first;
  likewise the shared Float32 `Locate_Point` / `Signed_Distance_To_Contour`
  and the `Origin` / `Destination` comments, and the
  `Closest_Ellipse_Points` comment, which renders only on its integer
  overload.

## Current commands

```sh
cd /home/zboll/git/opencv/geometry-doc-campaign/geometry
python3 -m unittest discover -s scripts -p 'test_*.py' -v
sh scripts/generate_docs.sh
python3 -m unittest discover -s scripts -p 'test_validate_docs.py' -v
alr exec -- gprbuild -P docs/example.gpr && obj/docs-example/example
```

## Checkpoint log

### GEOMETRY-DOC-001 — generator, diagnostics and Pages foundation

Branch `feature/geometry-doc-001-gnatdoc-pages` from `main` `517c804`.

- `docs_api.gpr` / `docs_internal.gpr`, `scripts/generate_docs.sh` (pinned
  tool gates and the Core identity gate), `scripts/compare_gnatdoc_warnings.py`
  (Imgproc's comparator, imported verbatim and then corrected),
  `scripts/validate_docs.py` (Geometry validator),
  `docs/gnatdoc-warning-baseline.txt` (360 identities), the unstyled landing
  page `docs/index.html` with the compiled `docs/example.adb`,
  `.github/workflows/documentation.yml`, `docs/documentation.md` and this
  record. `.gitignore` adds `/_site/`, `/.doc-tools/` and `__pycache__/`.

Qualified locally on the branch content:

- Negative-first: the new multi-line discriminant header test and the real
  `opencv-geometry.ads` indexing test failed against the verbatim Imgproc
  comparator (`record has no end record`) before the fix. Sabotaging the
  validator's package-description check, aspect stripping or shim-symbol
  rule in a scratch copy makes the corresponding tests fail.
- `python3 -m unittest discover -s scripts -p 'test_*.py'`: 94 tests pass
  (41 comparator, 53 validator including 13 on the generated site).
- `sh scripts/generate_docs.sh`: GNATdoc 26.0.0, opencv_core 0.4.1
  `386c536`; 360 warnings, delta 0 added / 0 removed; validator: 2 public
  packages, 4 HTML pages, 130 declaration sections (79 subprograms); all
  local links and anchors resolve.
- Generator gates rejected the GNAT Studio GNATdoc 27.0w, a Core checkout at
  a different commit with an identical tree (`386c536^2`), and a Core
  checkout with a modified tracked file.
- A fresh regeneration is byte-identical (`diff -r`).
- `docs/example.adb` compiles with `-gnat2022 -gnata -gnatwa -Werror` and
  runs; a scratch copy with a false assertion fails with
  `ASSERTION_ERROR`; GNATformat 26.0.0 reports it formatted.
- actionlint 1.7.12 (with ShellCheck 0.11.0 for the `run:` blocks) reports
  nothing for the workflow; ShellCheck reports nothing for the script (one
  justified SC2016 directive); `sh -n` passes.
- No file under `src/`, `cpp/`, `tests/`, `alire.toml` or the production GPR
  projects changed. The Gate 0 AUnit and native results above are for the
  unchanged library sources.

Known limitations:

- The landing page is unstyled until DOC-003.
- The native index check reproduces the pinned GNATdoc 26.0.0 serialization;
  any generator change fails closed until requalified.
- The warning count says nothing about accuracy; DOC-002 adds source-backed
  coverage and semantic review.

## Remaining roadmap

Each step branches from the previous phase's verified head, rewrites the
baselines it reduces, and opens a stacked review PR; work then continues.

1. **GEOMETRY-DOC-001** — infrastructure (this checkpoint).
2. **GEOMETRY-DOC-002** — coverage and comment-only checkers, then complete
   declaration-by-declaration documentation of both packages, split by the
   actual inventory (contours and shape analysis; fitting, enclosing and
   transforms; Subdiv2D lifecycle and queries; Subdiv2D topology and
   Voronoi), ending with zero warnings, full coverage and empty baselines.
3. **GEOMETRY-DOC-003** — theme, verified type links, Ada highlighting.
4. **GEOMETRY-DOC-004** — two-package, operation-level searchable browser.
5. **GEOMETRY-DOC-005** — guides and compiled examples.
6. **GEOMETRY-DOC-006** — independent final qualification.

### GEOMETRY-DOC-001 publication

PR #27 (`main` <- `feature/geometry-doc-001-gnatdoc-pages`), open,
non-draft, auto-merge off; tested and pushed head `0db5455`. Hosted CI not
yet inspected. Coverage measured on `0db5455` in a scratch worktree: 94/452
items, with 10 attachment/rendering errors.

### GEOMETRY-DOC-002A — in progress (session interrupted by usage limit)

Branch `feature/geometry-doc-002a-coverage-contours` from `0db5455`.
Foundation commit `82eeac7`: `check_doc_coverage.py` (adds aspect-free
profiles and the leading-before-`package` description layout),
`check_comment_only.py` (compares committed revisions; Ada tokens plus
byte-identical production files), their tests (140 Python tests in total
pass), coverage ratchet in `generate_docs.sh` and the workflow, the Subdiv2D
section preambles moved verbatim into its package description, seven
formulas put in code spans, and an `OpenCV.Geometry` package description.
Results: 359 warnings, 95/452 items, zero attachment errors;
`check_comment_only.py 517c804 HEAD` passes; GNATformat clean.

Verified with a scratch spec on GNATdoc 26.0.0: `@enum`, `@field` (also
discriminants and variant components), multi-line `@param`, `@return`,
`@exception Name` render; a dotted exception name splits at the dot;
code spans keep `**`; paired `**` becomes `<strong>`; `Post` is omitted.

Planned split, by inventory: 002A group A (contours and shape analysis,
36 `OpenCV.Geometry` declarations); 002B group B (capability, fitting,
enclosing, intersections, transforms, 50 declarations); 002C Subdiv2D
lifecycle and queries (20 declarations plus private `Finalize`); 002D
Subdiv2D topology and Voronoi (24 declarations). The full lists are in the
agent briefs recorded in this session.

Stopped (no results kept): a Subdiv2D drafting agent and two read-only
auditors for groups A and B. Their isolated worktrees remain and can be
reused or removed: `agents/subdiv2d/{geometry,core}` (branch
`scratch/geometry-doc-002cd-subdiv2d`, pinned, unedited apart from the pin)
and `agents/audit` (detached `82eeac7`, read only).

## Next executable task

1. Inspect PR #27 hosted CI once.
2. Write group A comments on the DOC-002A branch, regenerate both baselines,
   qualify (`generate_docs.sh`, all tests, `check_comment_only.py 517c804`,
   GNATformat, `alr -n build`), commit, push, and open the DOC-002A PR
   against `feature/geometry-doc-001-gnatdoc-pages`.
3. Continue with 002B to 002D, then DOC-003 to DOC-006.
