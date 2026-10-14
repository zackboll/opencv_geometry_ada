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
| DOC-001 infrastructure | `feature/geometry-doc-001-gnatdoc-pages` | #27 (`main`) | Merged as `2240b06`; Pages deployed |
| DOC-002A coverage, repairs, group A | `feature/geometry-doc-002a-coverage-contours` | #28 (`main`) | Open; head `9b7d334` |
| DOC-002B group B fitting, enclosing, transforms | `feature/geometry-doc-002b-fitting-transforms` | #29 (DOC-002A branch) | Open; head `426cb97`; `OpenCV.Geometry` complete |
| DOC-002C Subdiv2D lifecycle and queries | `feature/geometry-doc-002c-subdiv2d-lifecycle` | #30 (DOC-002B branch) | Open; head `d3ec186` |
| DOC-002D Subdiv2D topology and Voronoi | `feature/geometry-doc-002d-subdiv2d-topology` | #31 (DOC-002C branch) | Open; head `3705332`; zero warnings, 452/452 |
| DOC-003 theme, highlighting, type links | `feature/geometry-doc-003-presentation` | #32 (DOC-002D branch) | Open; head `a03cf97` |
| DOC-004 package- and operation-level browser | `feature/geometry-doc-004-navigation` | #33 (DOC-003 branch) | Open; head `661ad73` |
| DOC-005 guides and compiled examples | `feature/geometry-doc-005-guides` | pending (DOC-004 branch) | Qualified locally |

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
| Guides and compiled examples | Imgproc DOC-005 (5 guides, 5 examples) | DOC-005: 5 guides, 5 compiled and executed examples, API links across both packages |

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
export DOC_PYTHON=$PWD/.doc-tools/markdown/bin/python
sh scripts/generate_docs.sh
"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_*.py' -v
alr exec -- gprbuild -P docs/example.gpr && obj/docs-example/example
alr exec -- gprbuild -P docs/examples/examples.gpr
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

PR #27 (`main` <- `feature/geometry-doc-001-gnatdoc-pages`), tested head
`0db5455`. Hosted CI on that head (checked once): Ada API Documentation
`build` success, `deploy` skipped (pull request); Cross-Platform Geometry CI
Linux and macOS jobs for Core 0.3.0 and 0.4.1 success, Windows skipped by
policy. The maintainer merged it as `2240b06`. The `main` push run 38510318686
succeeded in `build` and `deploy`: the `github-pages` deployment for
`2240b06` exists and `https://zackboll.github.io/opencv_geometry_ada/` serves
the generated landing page and an index listing both packages (verified
2026-10-14 with `curl`). Coverage measured on `0db5455` in a scratch worktree:
94/452 items, with 10 attachment/rendering errors.

### GEOMETRY-DOC-002A — coverage checks, rendering repairs, group A

Branch `feature/geometry-doc-002a-coverage-contours` from `0db5455` (now in
`main`), so its PR targets `main`.

- Foundation commit `82eeac7`: `check_doc_coverage.py` (Imgproc's, with
  aspect-free profiles, the leading-before-`package` description layout and
  per-package reporting) and `check_comment_only.py` (compares committed
  revisions: Ada tokens plus byte-identical production files), with tests;
  the coverage ratchet in `generate_docs.sh` and the workflow; the Subdiv2D
  preambles moved verbatim into its package description; seven formulas in
  code spans; a new `OpenCV.Geometry` package description.
- Verified with a scratch specification on GNATdoc 26.0.0: `@enum`,
  `@field` (also discriminants and variant components), multi-line
  `@param`, `@return` and `@exception Name` render; a dotted exception name
  splits at the dot; code spans keep `**`; paired `**` becomes `<strong>`;
  `Post` is omitted.
- Group A (contours and shape analysis, 36 declarations) documented,
  verified against `src/opencv-geometry.adb`, the shim and exact OpenCV
  4.10 sources: `Contour`, `Contour_Area`, `Arc_Length`, `Moments_Result`
  (24 fields), `Compute_Moments`, the Hu types and `Hu_Moments`,
  `Hull_Orientation`, `Convex_Hull`, `Point_Index_Array`,
  `Convex_Hull_Indices`, `Convexity_Defect(_Array)`, `Convexity_Defects`,
  `Approximate_Curve`, `Bounding_Rect`, `Is_Convex`, `Shape_Match_Method`,
  `Match_Shapes`, `Contour_Point_Location`, `Locate_Point` and
  `Signed_Distance_To_Contour`, every overload. The comments misattached to
  `Hull_Orientation`, `Hu_Moment_Index`, `Point_Index_Array`,
  `Moments_Result`, `Shape_Match_Method` and `Contour_Point_Location` now
  document their functions, and each type has its own text. The four `Post`
  guarantees of this group are stated in `@return`. The Float32
  `Signed_Distance_To_Contour`, which rendered no description, has its own.
- Additions verified in the shim and stated now: integer `Convex_Hull` also
  rejects input whose signed 32-bit hull arithmetic would overflow (only
  the indices overload said so); integer `Locate_Point` with an
  integer-valued Query rejects input whose native signed 32-bit edge
  differences would overflow (`integer_classification_path_is_safe`).
  `Shape_Match_Method` literals are documented with the native formulas of
  `matchcontours.cpp` (I1 and I2 sums, I3 maximum).
- Results: warnings 359 -> 243 (243 remain, all in group B and Subdiv2D);
  coverage 95 -> 211 of 452 items; zero attachment errors.

Qualified locally: `sh scripts/generate_docs.sh` passes (delta 0/0,
validator 2 packages / 4 pages / 130 sections, coverage 211/452); 140
Python tests pass; GNATformat 26.0.0 check passes for both specifications;
`git diff --check` clean; `alr -n build` (production `-gnatyM79 -Werror`)
succeeds inside the generator; `check_comment_only.py 517c804 HEAD` run
after commit (see the PR).

Planned remaining split, by inventory: 002B group B (capability, fitting,
enclosing, intersections, transforms, 50 declarations); 002C Subdiv2D
lifecycle and queries (20 declarations plus the private `Finalize`); 002D
Subdiv2D topology and Voronoi (24 declarations).

Environment note (2026-10-14): `/tmp` (a 43 GB tmpfs) was full of other
projects' evidence directories; nothing outside this campaign was deleted.
Campaign commands use `TMPDIR=/home/zboll/git/opencv/geometry-doc-campaign/tmp`
and avoid background agents, whose transcripts are written to `/tmp`. The
stopped agents left `agents/subdiv2d/{geometry,core}` (scratch branch,
unedited apart from the pin) and `agents/audit` (detached `82eeac7`).

### GEOMETRY-DOC-002A publication

PR #28 (`main` <- `feature/geometry-doc-002a-coverage-contours`), opened
2026-10-14 with head `9b7d334`; open, non-draft, auto-merge off.

### GEOMETRY-DOC-002B — capability, fitting, enclosing, intersections, transforms

Branch `feature/geometry-doc-002b-fitting-transforms` from DOC-002A head
`9b7d334`; its PR targets the DOC-002A branch.

- Group B (50 declarations) documented, verified against the body, the shim
  and exact OpenCV sources: `Native_Feature` (each literal with its native
  function and first 4.x release, from the shim's compile-time
  `native_feature_supported`), `Is_Natively_Supported` (native availability
  only), both `Closest_Ellipse_Points`, both `Minimum_Area_Rectangle`, all
  six ellipse fits, `Line_Fit_Distance` (`DIST_*` mapping),
  `Fitted_Line_2D`, both `Fit_Line_2D`, the box types and `Box_Points`,
  `Convex_Polygon_Intersection`, all three convex intersections, the
  rotated-rectangle intersection types (`INTERSECT_*` mapping) and
  operation, the enclosing circle and triangle types and operations,
  `Get_Rotation_Matrix_2D`, the transform index, matrix and identity
  declarations, `Get_Affine_Transform`, `Invert_Affine_Transform`,
  `Perspective_Solve_Method` (`DECOMP_*` mapping),
  `Get_Perspective_Transform`, and both `Transform_Point` and
  `Transform_Points`.
- Comments misattached to `Box_Vertex_Index`, `Enclosing_Circle`,
  `Triangle_Vertex_Index` and `Affine_Row_Index` now document their
  functions or matrix types; the shared Float32 ellipse-fit comment and the
  `Closest_Ellipse_Points` comment are complemented by per-overload text.
  The remaining four `Post` guarantees are stated in `@return`.
- Statements added after verification: integer `Fit_Ellipse` also enforces
  the `Integer_32'Last / 13` count limit; both convex-polygon overloads
  require `Left'Length + Right'Length <= (Integer_32'Last - 4) / 2` for the
  native scratch buffer; `Get_Rotation_Matrix_2D` reduces Angle modulo a full
  turn in either unit and raises on non-finite native coefficients; the
  Float32 `Fit_Line_2D` rejects an all-zero native direction for every
  distance; `Box_Points` vertices are consecutive around the rectangle
  (`RotatedRect::points` in 4.10 and 5.0 reflects pt[0] and pt[1] through
  the center). The `Transform_Point` proof claim keeps its scope: the
  `Internal.Transforms` arithmetic is proved (277/277 checks recorded in
  `docs/batch-point-transforms.md`); batch bounds are runtime-checked.
- Results: warnings 243 -> 114 (all remaining in Subdiv2D); coverage 211 ->
  340 of 452; `OpenCV.Geometry` 307/307 items and zero warnings.

Qualified locally: `sh scripts/generate_docs.sh` passes (delta 0/0,
validator 2 / 4 / 130, coverage 340/452); all Python tests pass; GNATformat
check passes; `git diff --check` clean; rendered sections inspected.

### GEOMETRY-DOC-002B publication

PR #29 (DOC-002A branch <- `feature/geometry-doc-002b-fitting-transforms`),
head `426cb97`; open, non-draft, auto-merge off. Hosted CI of #28 (head
`9b7d334`, checked once): documentation `build` success, `deploy` skipped;
cross-platform Linux and macOS jobs for Core 0.3.0 and 0.4.1 success,
Windows skipped by policy.

### GEOMETRY-DOC-002C — Subdiv2D lifecycle, bounds, insertion and queries

Branch `feature/geometry-doc-002c-subdiv2d-lifecycle` from DOC-002B head
`426cb97`; its PR targets the DOC-002B branch. The Subdiv2D drafting agent
stopped in the earlier session produced nothing; this phase was written
directly, verified against `src/opencv-geometry-subdiv2d.adb`.

- Documented (20 visible declarations and the private `Finalize`):
  `Subdivision` (exclusive native ownership, readiness, and the rule that it
  must not be used by more than one task at a time), `Float32_Rectangle`,
  `Vertex_Id`, `No_Vertex`, `Edge_Id`, `No_Edge`, `Create`,
  `Create_Float32`, `Reset`, `Reset_Float32`, `Is_Ready`, `Bounds`,
  `Bounds_Float32`, both `Insert` overloads, `Point_Location_Kind`,
  `Locate_Result` (discriminant and variant components), `Locate`,
  `Nearest_Result`, `Find_Nearest`; private `Finalize` (idempotent release,
  not published).
- Verified in the body: semantic bounds rejection precedes any change; a
  failed native creation leaves no handle; `Bounds` and `Bounds_Float32`
  keep the last successful initialization; batch `Insert` checks every
  coordinate before inserting, inserts in chunks of 4096, is not atomic and
  names the rejected index; `Locate` maps `PTLOC_OUTSIDE_RECT` and location
  errors to `OpenCV_Error`; `Find_Nearest` rejects a nonpositive native
  vertex. The `Find_Nearest` liveness warning is unchanged, and its
  `@return` and `@exception` state that a call that does not return raises
  nothing; no convergence guarantee is claimed.
- Results: warnings 114 -> 69 (all remaining in group D); coverage 340 ->
  383 of 452; Subdiv2D 76/145.

Qualified locally: `sh scripts/generate_docs.sh` passes (delta 0/0,
validator 2 / 4 / 130, coverage 383/452); 140 Python tests pass; GNATformat
check passes; `git diff --check` clean; rendered `Subdivision` and
`Locate_Result` sections inspected.

### GEOMETRY-DOC-002C publication

PR #30 (DOC-002B branch <- `feature/geometry-doc-002c-subdiv2d-lifecycle`),
head `d3ec186`; open, non-draft, auto-merge off. Hosted CI of #29 (head
`426cb97`) was still pending at its single inspection.

### GEOMETRY-DOC-002D — Subdiv2D topology, extraction and Voronoi

Branch `feature/geometry-doc-002d-subdiv2d-topology` from DOC-002C head
`d3ec186`; its PR targets the DOC-002C branch.

- Documented (24 declarations), verified against the body: `Edge_Segment`,
  `Edge_Segment_Array`, `Edge_Id_Array`, `Triangle_Array`, `Edge_List`,
  `Leading_Edge_List` (Ada-owned array, identifiers valid only until the
  next Insert or Reset), `Triangle_List`, `Edge_Navigation` (each literal
  with its `getEdge` constant and the tested quad-edge identities),
  `Edge_Rotation`, `Navigate`, `Next_Edge`, `Rotate`, `Symmetric_Edge`
  (identifiers below 4 are rejected in Ada), `Origin` and `Destination`
  (separate comments; No_Vertex cases kept), `Vertex_Point`, `First_Edge`,
  `Vertex_Id_Array`, `Voronoi_Facet`, `Voronoi_Facet_Array`,
  `Voronoi_Diagram`, `Facet_Points` (`Constraint_Error` for out-of-range
  input), and both `Voronoi_Facets` (sites checked before any native
  computation; empty Sites give an empty diagram; the facet slices are
  verified to be consecutive, nonempty and covering).
- `generate_docs.sh` now fails if either baseline records any identity
  ("documentation baselines must stay empty"), as Imgproc's does.
- **Phase 2 acceptance reached:** zero GNATdoc warnings and 452/452 items
  documented (`OpenCV.Geometry` 307/307, `OpenCV.Geometry.Subdiv2D`
  145/145); both baselines empty.
- Results: warnings 69 -> 0; coverage 383 -> 452 of 452.

Qualified locally: `sh scripts/generate_docs.sh` passes (0 warnings, delta
0/0, validator 2 / 4 / 130, coverage 452/452); 140 Python tests pass;
GNATformat check passes; ShellCheck clean; `git diff --check` clean;
rendered sections inspected; negative check of the empty-baseline rule
recorded in the PR.

### GEOMETRY-DOC-002D publication

PR #31 (DOC-002C branch <- `feature/geometry-doc-002d-subdiv2d-topology`),
head `3705332`; open, non-draft, auto-merge off. Hosted CI of #30 (head
`d3ec186`) was pending at its single inspection.

### GEOMETRY-DOC-003 — theme, verified type links and Ada highlighting

Branch `feature/geometry-doc-003-presentation` from DOC-002D head `3705332`;
its PR targets the DOC-002D branch.

- Imgproc's `install_gnatdoc_theme.py` and `highlight_gnatdoc_ada.py` (lexer
  and integrity checks unchanged) and theme stylesheet; a Geometry
  `link_gnatdoc_types.py` for two package pages: per-page integrity manifest,
  child-to-parent links that name the parent page's actual file, a name
  declared in both packages left unlinked, and Core types checked against
  the gate-verified Core checkout (`--core "$core"`). Validator integration:
  presentation files allowed, themed index, Core bookmarks as the only
  external API links, independent recomputation and representative probes.
  The landing page uses the theme.
- Measured: 130 snippets in 2 pages; 167 Geometry links (4 cross-page:
  `Float32_Point_Array` three times, `Triangle_Vertices` once) and 96 Core
  links; 0 ambiguous; 24 Standard type marks unlinked (`Boolean`,
  `Natural`, `Positive`). Every linked Core type (`Angle_Unit`,
  `Float32_Point`, `Float32_Value`, `Float64_Value`, `Point_Array`, `Rect`,
  `Rotated_Rect`, `Core.Mat`) is in the visible part of Core 0.4.1 and of
  Core `main` `c0709f8`, which the Core site documents.
- Tests: 29 type-link/theme/highlight tests (synthetic parent and child;
  sabotaging the redeclared-name rule makes its test fail) and 12 new
  generated-site validator mutations, including wrong-but-existing
  cross-page destinations; 179 Python tests in total, all passing.
- Fresh regeneration is byte-identical; repeating the three steps is
  byte-identical.
- Browser (Playwright module from `~/.npm/_npx/e41f203b7505f1fb`, Google
  Chrome from `/usr/bin/google-chrome`, local `http.server`): 1280/390 px,
  light/dark; landing and both package pages; Core links; native anchor;
  cross-page link landing on `Float32_Point_Array`; focus outline; Core link
  replacing the window; JavaScript-disabled navigation to both packages.
  Twelve screenshots in
  `/home/zboll/git/opencv/geometry-doc-campaign/evidence/doc-003`, of which
  the dark desktop package page and the light mobile cross-page target were
  inspected.

### GEOMETRY-DOC-003 publication

PR #32 (DOC-002D branch <- `feature/geometry-doc-003-presentation`), head
`a03cf97`; open, non-draft, auto-merge off. Hosted CI of #31 (head
`3705332`, checked once): documentation `build` success (zero warnings and
empty baselines enforced in CI), `deploy` skipped; one macOS job passed and
the other cross-platform jobs were pending.

### GEOMETRY-DOC-004 — package- and operation-level searchable browser

Branch `feature/geometry-doc-004-navigation` from DOC-003 head `a03cf97`;
its PR targets the DOC-003 branch.

- `docs/api-categories.json`: reviewed manifest of 2 packages and 12
  categories (7 + 5) covering all 106 distinct public names (130
  declarations) exactly once, derived from the DOC-002 groups and the
  brief's proposal, checked against both specifications at every
  generation.
- `enhance_gnatdoc_navigation.py`: per-package sections headed by package
  links, categorized declaration lists with verified native anchors, kinds
  and overload labels; hidden controls and one deferred script added only to
  the native index; exact rebuild check; idempotent.
  `gnatdoc-navigation.js`: case-insensitive multi-word search including the
  package name, live status, Clear, `aria-current` selection, package
  (`?package=`) and declaration (`?package=&op=&overload=`) bookmarks with
  Back/Forward/reload, canonicalization that drops unknown, path-like and
  wrong-package requests. Theme rules added for the browser.
- Validator: the navigation script is the only allowed script, once, in the
  index; the index must equal the rebuilt themed and augmented
  serialization; navigation is rechecked independently.
- Tests: 15 navigation tests (manifest errors, real-site mutations,
  idempotency); 195 Python tests in total, all passing.
- Browser: the navigation harness and the presentation harness (package
  clicks scoped to the native compilation-unit list, now that package
  headings also link) pass at 1280/390 px in light and dark, with
  JavaScript disabled for both; screenshots in
  `/home/zboll/git/opencv/geometry-doc-campaign/evidence/doc-004`; the
  desktop dark search, mobile light and no-JavaScript views were inspected.
  The mobile sidebar keeps Imgproc's 30 % band and scrolls internally.

### GEOMETRY-DOC-004 publication

PR #33 (DOC-003 branch <- `feature/geometry-doc-004-navigation`), head
`661ad73`; open, non-draft, auto-merge off. Hosted CI of #32 (head
`a03cf97`) was pending at its single inspection.

### GEOMETRY-DOC-005 — developer guides and compiled examples

Branch `feature/geometry-doc-005-guides` from DOC-004 head `661ad73`; its PR
targets the DOC-004 branch.

- Five guides in `docs/guides/`: geometry fundamentals and contour analysis;
  shape fitting and intersections; affine and perspective geometry; Delaunay
  and Voronoi with Subdiv2D; compatibility, ownership and native safety. Each
  states that the specifications are authoritative and embeds one of five
  examples in `docs/examples/` (`examples.gpr`, `-gnat2022 -gnata -gnatwa
  -Werror`, GNATformat-clean). Every statement was checked against the
  declaration's own documentation; the examples assert only properties that
  hold on every supported release, and deferred native operations appear
  only as unbound.
- `render_gnatdoc_guides.py` adapted from Imgproc: two-package `api:` links
  resolved from the API browser's verified anchors, with names declared in
  both packages rejected as ambiguous; pinned `markdown-it-py` 3.0.0 and
  `mdurl` 0.1.2 in `docs/requirements.txt`. Validator, generator, landing
  page (Developer Guides section), workflow (documentation virtual
  environment, guide mutation tests, idempotent re-render, examples built
  and run) and `docs/documentation.md` integrated.
- README: documentation pointer with the authoritative-specification note,
  and the stale Core-index sentence corrected (verified again on 2026-10-14:
  `alr show opencv_core=0.4.1` resolves the community index at `386c536`).
- Tests: 21 guide tests and 3 new generated-site validator mutations (guide
  integrity, landing links, guide external links); 219 Python tests in the
  documentation environment, all passing; with plain `python3` the
  renderer-dependent tests skip.
- `generate_docs.sh`: 0 warnings, 452/452 coverage, empty baselines, 9 HTML
  pages validated, 5 guides; fresh regeneration and repeated enhancement
  byte-identical; all five examples and the landing example run; ShellCheck
  and actionlint clean.
- Browser: the guide harness passes at 1280/390 px, light/dark, with and
  without JavaScript (every guide from the landing page, API anchors
  including every overload-labelled link, cross-guide links, current-page
  marker, focus, skip link, overflow); the presentation and navigation
  harnesses still pass. Screenshots in
  `/home/zboll/git/opencv/geometry-doc-campaign/evidence/doc-005`; the
  desktop light compatibility table and the mobile dark fitting guide were
  inspected.

## Findings for the maintainers (not changed: outside documentation scope)

- None open. The README's stale Core-index sentence, recorded here during
  DOC-004, was corrected in DOC-005 as documentation.

## Next executable task

1. Commit DOC-005, push, open its PR against the DOC-004 branch; check
   hosted CI of #33 once.
2. DOC-006 independent final qualification and campaign report.
