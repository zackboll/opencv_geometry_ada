# GEOM-DOC-010 — additive API successor policy (candidate)

**Not approved. Tests do not authorize this policy. GEOM-031 remains blocked
until independent review and merge of the dedicated policy PR.**

## Migration inventory, recorded before implementation

The immutable predecessor is main
`2f5239a0e264ca2bb4106cdb338d3eac25abf674`, tree
`c440b9901e1003f06ae555b3a8a80d9874229680`. Its GNATDOC-009B authority is
`docs/evidence/gnatdoc009b/authority-transition.json`, SHA-256
`ddf461928a5fc7a3ab4fc9ed0248c237aa465e581249708a5390496b7b447cb5`.
The historical source is `ec4d689eac748b7837abd4c3754c3090ca4bf814`;
the reviewed evidence revision is `2101e5c8757898b6904becfb899247e9f685c25b`.
Historical artifacts, identities and hashes are never updated by this policy.

| Component | Constraint to separate from current-source qualification |
| --- | --- |
| `qualify_shared_gnatdoc_shadow.py:trusted_inputs` | Frozen categories, authored inputs, scripts, configuration, guide/example/assets and documentation projects |
| `qualify_shared_gnatdoc_shadow.py:qualify` | Exact Ada and source/guide/example/assets file inventories |
| `qualify_shared_gnatdoc_shadow.py:historical_references` | 130 declarations and 267 occurrences; remains historical |
| `qualify_shared_gnatdoc_shadow.py:gates` | Exactly 452/452 documented items |
| `qualify_shared_gnatdoc_shadow.py:staged_contract` | Only native hashes may change in the authored contract |
| `qualify_shared_gnatdoc_shadow.py:verify_publication` | Exactly 130 declarations and fixed authored output hashes |
| `compare_shared_gnatdoc_geometry.py` | 130 entries, 267 occurrences, 171 local/96 external links, exact 263/4 classification and four constant owners |
| `record_shared_gnatdoc_shadow.py` | Exact 452-item current gates; historical 542 tests; fixed browser/adversarial floors |
| `qualify_shared_gnatdoc_browser.py` | 130 navigation entries; historical authored contract; eight cells and 16 history transitions |
| `qualify_shared_gnatdoc_adversarial.py` | Frozen categories/guides/contracts and 30 observed attacks; retain intact |
| `qualify_original_gnatdoc_browser.py` | Runs original fixed-count browser scripts on its legacy checkout |
| Protected `test_check_doc_coverage.py` | 79 subprograms and 130 declarations in generated-site tests |
| Protected `test_gnatdoc_navigation.py` | 106 unique category names and 130 navigation entries |
| Protected `test_gnatdoc_navigation_browser.cjs` | 130 total/reset entries, two packages, 12 categories |
| `test_shared_gnatdoc_shadow.py` | Immutable guides and 23 script-mutation checks; source registrations are enumerated, minimum 542 |
| `documentation-shared-shadow.yml` | Executes candidate verifier; successor must obtain verifier separately |
| `shared-gnatdoc-shadow.toml` | Fixed historical authored/Core manifests, dependency hashes, hosts and offline publication |
| `geometry-authored.json` | Fixed guide/input/example ownership, exact examples, native hash map |
| `authority-transition.json` | Fixed source, native and authored-output hashes; unchanged historical root |

The existing production generator, coverage/warning baselines, standard Pages
workflow, Core 0.5.0 source identity and external type manifests stay unchanged.

## Protected historical verification components

All 23 names remain protected by the predecessor authority, not fresh hashes:

- `scripts/check_comment_only.py`
- `scripts/check_doc_coverage.py`
- `scripts/compare_gnatdoc_warnings.py`
- `scripts/enhance_gnatdoc_navigation.py`
- `scripts/generate_docs.sh`
- `scripts/highlight_gnatdoc_ada.py`
- `scripts/install_gnatdoc_theme.py`
- `scripts/investigate_shared_gnatdoc_types.py`
- `scripts/link_gnatdoc_types.py`
- `scripts/render_gnatdoc_guides.py`
- `scripts/validate_docs.py`
- `scripts/test_check_comment_only.py`
- `scripts/test_check_doc_coverage.py`
- `scripts/test_compare_gnatdoc_warnings.py`
- `scripts/test_gnatdoc_guides.py`
- `scripts/test_gnatdoc_navigation.py`
- `scripts/test_investigate_shared_gnatdoc_types.py`
- `scripts/test_link_gnatdoc_types.py`
- `scripts/test_validate_docs.py`
- `scripts/test_core_type_links_browser.cjs`
- `scripts/test_gnatdoc_guides_browser.cjs`
- `scripts/test_gnatdoc_navigation_browser.cjs`
- `scripts/test_gnatdoc_presentation_browser.cjs`

## Review boundaries

The predecessor remains the historical authority. A reviewed, merged successor
revision must be supplied separately from the candidate revision. The verifier
must be executed from that clean policy checkout. Candidate Python modules are
never imported. Candidate scripts, workflows, tool configuration and evidence
cannot replace the trusted implementations. Native generation, compilation and
AUnit execute candidate code only in read-only-token, disposable CI jobs without
publication credentials. This is not a sandbox against malicious native code;
runner/environment integrity and independent workflow review remain assumptions.

During this PR, executing the candidate policy is exploratory review evidence,
not proof that it has an independently approved trust root. There is no command
that creates approval, updates historical authority, or makes synthetic APIs
releasable. Repository administrators must protect the required base-policy CI
check and review changes to workflows; a candidate-controlled Actions definition
alone cannot enforce its own non-bypassability.

## Narrow current-source scope

The intended first scope is additive transform functions in `OpenCV.Geometry`:
`To_Mat`, `Affine_From_Mat`, `Perspective_From_Mat`,
`Get_Rotation_Affine_Transform_2D`, `Compose`, and conditionally
`Invert_Perspective_Transform`. Naming these is not approval of signatures,
contracts, arithmetic or implementation. Existing complete declarations,
including aspects and values, remain byte-token compatible and in order.
New overloads follow existing overloads; compatibility transitions require
separate review, not an editable exception manifest.

Only the existing `transforms` category may gain new names. Other membership,
category identities, titles and package ownership remain unchanged. Only
`docs/guides/affine-and-perspective-geometry.md` and its existing compiled example
may change authored content. The renderer still rejects active content and
unapproved destinations, requires exact compiled Ada examples and real current
API anchors. Other authored inputs retain historical hashes. README, coverage
and related audit prose are not executable authority.

Track A must execute historical fixed-count tests against historical sources
and output: 130 declarations, 267 references, 452 items, 542 AUnit cases.
Track B derives inventories from candidate source, matches genuine native
output one-to-one, checks every resolved occurrence/destination and requires
100% coverage and zero warnings. Existing baseline AUnit names cannot disappear;
new registrations must match executed successful cases, not merely a count.

The disposable positive fixture is a policy test only. It must demonstrate
actual build, native generation, source/type/navigation growth, authored guide
validation, example execution and AUnit execution without editing committed
production files. Historical results do not establish current-source success.

## Successor components and invocation

The candidate successor verification components are:

- `scripts/additive_gnatdoc_policy.py`: predecessor authority, complete source
  profiles, additive compatibility, category restrictions and independent
  occurrence/destination reconstruction.
- `scripts/qualify_additive_gnatdoc.py`: clean policy/exact candidate identities,
  disposable build pins, independently regenerated native output, examples,
  AUnit, two-copy generation and verification.
- `scripts/additive_gnatdoc_fixture.py`: exact disposable fixture, never a
  production API or an arbitrary source-authorizing manifest.
- `scripts/browser_additive_gnatdoc.py`: current derived navigation inventory
  in eight configurations, overloads, search, anchors and history.
- `scripts/adversarial_additive_gnatdoc.py`: observed sequential attacks with
  complete restoration and independent reconstruction after each attack.
- `scripts/record_additive_gnatdoc.py`: fail-closed independent reconstruction,
  executed command/example/AUnit evidence, browser inventory and fixture checks.
- `scripts/run_additive_gnatdoc_review.py`: separate historical/current campaign.
- `scripts/test_additive_gnatdoc_policy.py`: focused mechanism regression tests.
- `.github/workflows/documentation-additive-policy.yml`: read-only bootstrap
  review and subsequent base-checkout execution, never publication.

All tracked `scripts/` and `.github/workflows/` files in a candidate must match
the selected policy checkout, including the original 23 protected files. New
candidate verifier files are rejected too. A future verifier change is a new
independent policy review, not a feature-side exception. A clean selected
policy base supplies the evolving published declaration and AUnit-name baseline;
the immutable predecessor supplies historical evidence. The review campaign
does not call a changed candidate Python validator.

For a local policy-PR review, use a clean detached policy checkout, the exact
candidate SHA, and separately acquired qualified tool/dependency checkouts:

```sh
/path/to/qualified-tools/bin/python /path/to/policy/scripts/run_additive_gnatdoc_review.py \
  --workspace /path/to/new-offline-workspace \
  --candidate-repository /path/to/candidate --candidate-revision FULL_SHA \
  --enhancer /path/to/enhancer --core /path/to/core \
  --gnatdoc-prefix /path/to/gnatdoc-26.0.0 \
  --playwright-module /path/to/node_modules/playwright \
  --chromium /path/to/chromium --policy-review
```

`--policy-review` permits exploratory same-revision policy/candidate execution;
it never marks `policy_approved` true. Without it the candidate cannot be its
own policy authority. The workflow obtains the future verifier from the PR's
exact base revision, not from candidate scripts. The first-policy bootstrap is
limited to the named immutable predecessor base and clearly logs its review
status. Neither this workflow nor an output digest is proof of human approval.

Core remains `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`; the enhancer remains
`426f38852ef7dfff264f73ad01aab458f5e12b23`. GNATdoc 26.0.0 binary identity,
GNAT 16.1.0, GPRbuild 26.0.1 Alire release, Alire 2.1.1, Markdown 3.0.0/0.1.2
and the existing browser environment remain the qualification tools. No runtime
dependency is added. Native OpenCV/platform isolation is outside this policy.

## Known integration gate: production regression workflow routing

The production generator and Pages workflow are deliberately unchanged in this
candidate. Their protected historical regression scripts still contain fixed
130-entry assertions. The old shared-shadow workflow also still invokes the
predecessor runner on candidate HEAD. Consequently **a successful additive
shadow fixture alone does not yet establish that an additive feature PR can
pass all ordinary documentation workflows**. A reviewed routing integration
must keep production generation and Pages behavior, run fixed historical tests
on historical output, and invoke the successor current-source checks on the
candidate. Until that integration and final-head qualification are complete,
this policy is not an unblocking authorization for GEOM-031.