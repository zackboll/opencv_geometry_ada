# GEOMETRY-GNATDOC-001: migration blocked at independent qualification

**Disposition: CORRECTIVE_WORK_REQUIRED. This is not the migration.**

The production generator, validators, trust policy, workflows, public sources,
dependencies and published site are unchanged. No enhancer configuration has
been approved or installed in CI. No legacy implementation or test was removed.
This report retains release verification and pre-migration evidence so that
the migration can resume without disguising existing failures or bypassing the
independent policy.

## Release and repository authority

Fresh Geometry `main`:

- commit `e3f676489edaf0ce8a30ebc2cb7ce22ca1db4972`;
- tree `27f527ce707846c9f997b0d7bce7f0a420d659b8`.

Fresh enhancer `main` and the dereferenced `v0.1.5` tag:

- commit `0120bee2f2455e4c832d1d5ddae0a4cb03cb9477`;
- tree `01900ddb099c801eeb92fba718f4c528f87d865f`;
- annotated tag object `c6ca2b445b089e7f50abc1779d76dd4ff3f0f1eb`.

`gh release list` and `gh release view` independently identify
[v0.1.5](https://github.com/zackboll/ada-gnatdoc-enhancer/releases/tag/v0.1.5)
as the latest published stable release: non-draft, non-prerelease, published
2026-11-01T21:44:44Z. The tag alone was not treated as publication evidence.

Official downloaded assets pass `sha256sum -c SHA256SUMS`:

| Asset | SHA-256 |
| --- | --- |
| `ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl` | `d712d330f213fc1909a66c47bc2c7e5e15d5ec687222bea3c4922f5243db4247` |
| `ada_gnatdoc_enhancer-0.1.5.tar.gz` | `2bc2cc4160a182a2a9b1a4907f47198daabf88883888fa09d736913bd2931079` |
| `release-provenance.json` | `6c30b7a4ec987ab4f74a44d04586dcd57308dd592ac13f33c9444ef3acf0a8f3` |

The audit checked every recorded source path/hash/blob against independently
fetched release Git source; complete wheel/sdist member hashes against
provenance; wheel RECORD hashes/sizes, metadata, license and entry point;
module/asset equality with release source; and the non-editably installed
official wheel's origin hash and module bytes. No independently rebuilt sdist
wheel is claimed. These records are unsigned consistency evidence, not a
cryptographic publisher attestation.

The provenance deliberately says `publication_authorized = false`; the actual
release notes explicitly explain that technical qualification is separate from
the maintainer's publication authorization. GitHub publication is the release
authority. Preparation-era wording also remains in the released migration and
compatibility documents; it was not used to infer publication.

Read the released `docs/migration.md`, `docs/configuration.md`,
`docs/release-compatibility.md` and authored-content contract, not working-tree
development documentation. The installed executable is **`gnatdoc-enhancer`**,
version `0.1.5`. Its actual help supports `inventory`, `enhance --dry-run`,
`enhance` and `verify`, with `--config`, `--source-root` and `--site`.
Only version/help inspection was executed: production inventory/enhance/verify
qualification has **not** run. No main-branch, editable or development install
was used for this release inspection. Search and compiler-verified examples
remain disabled by non-adoption.

## Independent policy blocker

The existing documentation workflow calls `documentation-additive-policy.yml`.
That workflow selects policy from the independently checked-out base, never the
candidate. At the starting `main`, `candidate_rules` in
`scripts/additive_gnatdoc_policy.py`:

1. calls `historical_inputs`, which freezes the generator and legacy validators
   against historical authority hashes;
2. requires all tracked `scripts/` and `.github/workflows/` files to equal the
   selected policy checkout;
3. requires exact file inventories under both directories, rejecting additions.

This was reproduced in isolated clones with the unchanged base's Python code:

| Probe | Result |
| --- | --- |
| Untouched main against itself | Pass: 138 declarations, no additions, 562 AUnit registrations |
| Append only a comment to `.github/workflows/documentation.yml` | Reject: `protected verification component changed: .github/workflows/documentation.yml` |
| Append only a comment to `scripts/generate_docs.sh` | Reject: `authority bytes differ: scripts/generate_docs.sh` |

Consequently a real generator/workflow replacement cannot pass the current
independently selected policy. Changing that policy in the migration candidate
does not authorize the change: the workflow still executes the base policy.
Pointing the check at candidate policy or removing it would waive an existing
security gate, contrary to this task. Even after a transition, the historical
trust path's explicit source installation must be reconciled with the requirement
that CI install only the official wheel, without losing historical regression
coverage. No such reconciliation or approval is claimed here.

**Required next action:** independently review how the existing policy can
authorize the specific release-backed generator/workflow transition while
retaining source-derived checks, historical regression coverage, mutation tests,
and non-candidate authority. Establish that authority before resuming migration.
Do not add a candidate-controlled exception to turn this report green.

## Untouched baseline results

The historical 452-item/130-declaration figures are no longer current. Fresh
main contains **481 documented items, 138 declarations and 87 subprograms**.
The inventories retain complete native snippet text, actual filenames and
anchors, source declaration identities, link occurrences and navigation order.
Native profiles and destination anchors match the pristine generation. Exactly
`OpenCV.Geometry` and `OpenCV.Geometry.Subdiv2D` are published; the original
validator accepts the site and all local links/anchors. No internal, private,
Core-owned or C++ shim declaration was added to publication.

| Qualification | Result |
| --- | --- |
| Library build, original generator and independent validator | Pass |
| GNATdoc warnings / warning ratchet | 0 / pass |
| Source-derived declaration/member coverage | 481/481, no gaps |
| Full site inventory | 15 files; 4 pristine native files |
| Native type-reference occurrences | 282: 178 Geometry, 104 source-verified Core |
| Two fresh native generations plus complete legacy enhancement | Byte-identical complete sites |
| Landing example and all five guide programs | Compiled and executed, all six exit 0 |
| Original assertion/warning settings | Unchanged: `-gnat2022 -gnata -gnatwa -Werror` |
| Unchanged Python discovery, expected sibling Core layout | **Fail: 309 tests, 27 failures, 5 errors** |
| Chromium presentation suite | Pass, both packages, mobile/desktop, light/dark |
| Chromium guides suite | Pass, all eight width/theme/JavaScript profiles |
| Real Core cross-repository suite | Pass, desktop/mobile declaration visibility, reload and Back/Forward |
| Chromium native navigation suite | **Fail at `138 !== 130`, before later assertions** |

The Python failures include stale 79-subprogram/130-declaration expectations,
historical authored-input hashes for the subsequently changed affine guide and
example, and a duplicate-category fixture. Tests were not edited, deleted or
skipped to conceal these failures. An initial test attempt also lacked the
default sibling `core` path; the recorded qualification log is the rerun in a
fresh unchanged source clone with that expected Core layout. An initial
determinism retry omitted `DOC_PYTHON` and failed to import Markdown; the retained
successful retry uses the pinned renderer. None of those failed attempts is
reported as a pass.

The real Core browser fixture was built unchanged at
`ccc2190f9bf0712d65a2b9d2983cde7ce68b4bae`, separately from Geometry's production
Core 0.5.0 resolution. Core/browser tests used actual generated declarations,
not HTTP-success substitutes. The presentation suite's existing local stub is
not used as evidence of Core declaration navigation; the separate cross-repo
suite supplies that evidence. Playwright was 1.64.1, Chromium 156.0.8078.4.

The last observed successful main workflow is
[40263014835](https://github.com/zackboll/opencv_geometry_ada/actions/runs/40263014835),
at the starting SHA. That historical success is not a pass for this task or for
the broader current-tree discovery command: the existing workflow deliberately
runs some regression suites in a historical checkout.

## Reproduction and retained evidence

Tracked evidence is in `docs/evidence/geometry-gnatdoc-001/`. The full disposable
local workspace is `/home/zboll/git/geometry-gnatdoc-001-evidence/`, including
official assets, pristine output, original site, source clones, browser images
and diagnostics. The Geometry checkout is
`/home/zboll/git/opencv_geometry_ada/`.

Key commands, run with the qualified tools and temporary uncommitted Core pin:

```sh
gh release list --repo zackboll/ada-gnatdoc-enhancer --limit 100 \
  --json tagName,isDraft,isPrerelease,publishedAt
gh release view v0.1.5 --repo zackboll/ada-gnatdoc-enhancer \
  --json tagName,isDraft,isPrerelease,publishedAt,targetCommitish,url,assets
gh release download v0.1.5 --repo zackboll/ada-gnatdoc-enhancer --dir "$ASSETS"
(cd "$ASSETS" && sha256sum -c SHA256SUMS)
"$DOC_PYTHON" -m ada_gnatdoc_enhancer --version
"$DOC_PYTHON" -m ada_gnatdoc_enhancer enhance --help
DOC_PYTHON="$DOC_PYTHON" sh scripts/generate_docs.sh
"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_*.py' -v
alr exec -- gprbuild -P docs/example.gpr
obj/docs-example/example
alr exec -- gprbuild -P docs/examples/examples.gpr
for example in contours_and_moments fitting_and_intersections \
    affine_and_perspective delaunay_and_voronoi compatibility_and_safety; do
  "obj/docs-examples/$example"
done
node scripts/test_gnatdoc_presentation_browser.cjs
node scripts/test_gnatdoc_navigation_browser.cjs
node scripts/test_gnatdoc_guides_browser.cjs
node scripts/test_core_type_links_browser.cjs
```

For browser reproduction, serve the retained Geometry and Core sites at
`http://127.0.0.1:18773/` and `http://127.0.0.1:18774/`; set `DOC_URL` and
`CORE_DOC_URL` accordingly, `PLAYWRIGHT_MODULE` to the separately installed
1.64.1 module, and `CHROME` to its Chromium executable. The complete logs retain
individual results, including the navigation failure.
One trailing space was removed from the committed unittest log for Git whitespace
checks; the untouched log remains in the local workspace. No result was changed.

The retained `audit.py` is an evidence-only script, not a production or policy
verifier. Run it with the isolated wheel environment's Python and the absolute
local evidence workspace as its sole argument. It checks the fetched Git source,
archives and installed wheel, then reconstructs the baseline inventories with
the independently checked-out original Geometry readers. It does not grant
release or consumer adoption authority.

## Behavior differences, limitations and rollback

There is **no migrated after-site**. Production behavior differences are zero
because the implementation was deliberately not changed. A complete old/new
enhancer comparison, reviewed production TOML, authored manifest, Core bookmark
contract or compatibility step, enhancer tamper/idempotence/determinism campaign,
and exact-head migration hosted qualification remain outstanding. The untouched
baseline itself is not fully qualified because the tests above fail. No
READY_FOR_INDEPENDENT_REVIEW claim is made.

Rollback is unnecessary for this report-only change. For the eventual migration,
retain or restore the original generator from starting main and regenerate with
Alire 2.1.1, GNAT 16.1.0, GPRbuild Alire 26.0.1, GNATdoc 26.0.0 and the exact
unmodified Core 0.5.0 checkout
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`. Native OpenCV resolution is unchanged
(local pkg-config OpenCV 4.10.0). Re-run the independent ratchets and browser
qualification before any main-only Pages publication. PRs receive no publication
credentials.

Local retained rollback archives:

- `previous-generator.tar`: SHA-256
  `6bda13fb2f26fa21a5d4d90ef846b571baa3eae59dcee9b900c0993be5a422e9`;
- `previous-site.tar.gz` (legacy site and pristine native output): SHA-256
  `edabc549c56a02854dc642677179bdaee6bed4f3f38e4f7c54111fe906f2f958`.

Both archives live in the local evidence workspace, not the generated-site Git
tree. The original generator is also recoverable from the starting Git commit;
site file hashes are committed here. Final PR head/tree and exact-head hosted
run URLs are recorded in the PR body after committing, avoiding self-referential
commit identity claims inside this file.