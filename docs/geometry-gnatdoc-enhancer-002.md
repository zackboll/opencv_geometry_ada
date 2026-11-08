# GEOMETRY-GNATDOC-002: successor policy proposal

**Disposition: CORRECTIVE_WORK_REQUIRED — bootstrap authorization outstanding.**

## R2 publication and corrective qualification

The prior credential blocker is resolved. The maintainer-published branch was
fetched and verified unchanged at original head
`906def7fb2f9971525365a2f24169d2c09c59d54`, tree
`f02c50067bcbb92d538d81eef33779efaf91441c`. Latest main still matches the
baseline below. [PR #59](https://github.com/zackboll/opencv_geometry_ada/pull/59)
is non-draft with auto-merge disabled. No rewrite, rebase or forced push occurred.

The original full exploratory campaign completed after the previous handoff:
historical and current components, browsers and attacks passed, but its positive
additive fixture failed the new independent production validator. This is a real
successor-policy defect, not the expected bootstrap rejection: nested theme and
navigation checks used their policy-checkout default sources even though
`validate(..., root=source)` selected the exact fixture source. The new fixture
overloads therefore failed `source profile not unique`.

R2 threads explicit source/category paths through the base-owned navigation and
theme checks, preserving all exact HTML, asset, profile and ownership checks.
Default production calls are unchanged. Added regressions verify context
propagation and continued tamper rejection. The migration file allowance is
unchanged; both corrected verifier helpers remain protected from candidates.
No current-source test expectation or historical authority hash is repaired.

Original-head exact qualification uses clean `original-policy` checkout under
`/home/zboll/git/geometry-gnatdoc-002r2-evidence/`, campaign `/tmp/gd2r2`.
Correction commit `4a54a6556acedabc1d11d47e165ebadd2feb759c`, tree
`fc01359b101f28cb434adf3ed56488e42d66c3aa`, was normally pushed and qualified
from separate clean `corrected-policy`, campaign `/tmp/gd2r2f`. A final
report/evidence commit must itself receive a fresh complete campaign; earlier
component successes never substitute for exact-final-head qualification.
The sections below retain original delivery history; this R2 section supersedes
their publication/pending statements. Final identities and completed results
belong in PR #59 and the external R2 evidence ledger, avoiding self-referential
commit hashes and repeated evidence-only head changes.

### R2 local evidence and reproducible commands

At the correction head, 15 successor tests and 14 selector tests pass. Unchanged
historical tests pass at their matching immutable merge (16 shadow, 47 additive).
The existing validator suite passes 68 tests with 28 generated-site skips in the
site-free policy checkout; these skips are not generated-site qualification.
Real generated-site checks additionally accept the independent positive fixture
(140 declarations, 89 subprograms, 487/487 documented elements) and reject anchor,
declaration and type-destination mutations, restoring the original after each.
The current reference independently retains 138 declarations, 87 subprograms,
481/481 items, 112 category owners and zero warnings. Final campaigns must
rebuild both ordinary and fixture sites and independently record all results.

The official wheel was freshly installed using the policy installer in a separate
R2 environment; digest, installed origin and complete module/asset bytes pass.
Actual corrupted-wheel and installed-module mutations are rejected, and restored
contents reverify. The historical development tool remains confined to the
unchanged historical/offline campaign, never the official production environment.
No production enhancer configuration is introduced in this PR.

Qualification commands (clean, detached checkout of the exact head; new short
workspace; paths are the retained local qualification environments):

```sh
PY=/home/zboll/git/geometry-gnatdoc-002-evidence/historical-tools/bin/python
"$PY" -m unittest discover -s scripts -p test_gnatdoc_migration_policy.py -v
"$PY" -m unittest discover -s scripts -p test_select_gnatdoc_policy.py -v
"$PY" scripts/run_additive_gnatdoc_review.py \
  --workspace /tmp/gd2r2final \
  --candidate-repository /home/zboll/git/opencv_geometry_ada \
  --candidate-revision "$(git rev-parse HEAD)" \
  --enhancer /home/zboll/git/geometry-gnatdoc-002-evidence/historical-enhancer \
  --core /home/zboll/git/geometry-gnatdoc-001-evidence/core-0.5.0 \
  --gnatdoc-prefix /home/zboll/git/opencv_geometry_ada/.doc-tools/gnatdoc-26.0.0 \
  --playwright-module /home/zboll/git/geometry-gnatdoc-001-evidence/browser/node_modules/playwright \
  --chromium /home/zboll/.cache/ms-playwright/chromium-1248/chrome-linux64/chrome \
  --policy-review
```

The campaign records exact subprocess commands, exit codes, logs/digests, source
and site identities, compiled/runnable examples, AUnit registrations/results,
native reconstruction, determinism/idempotence, eight browser cells, history,
adversarial rejection/restoration, positive additive fixture and independent
recorders. Python 3.13.5, Alire 2.1.1, GNAT 16.1.0, GPRbuild Alire 26.0.1,
GNATdoc 26.0.0, exact Core 0.5.0 source, Markdown 3.0.0/mdurl 0.1.2, Python
Playwright 1.58.0 and Node Playwright 1.64.1 remain unchanged locally. Chromium
is the same retained 1248 executable used for the successful earlier long
campaign; no failed assertion is retried with altered policy or tool versions.

### Hosted results and bootstrap classification

Original published head:

- [successor policy 42442260860](https://github.com/zackboll/opencv_geometry_ada/actions/runs/42442260860): failure;
- [documentation 42442260964](https://github.com/zackboll/opencv_geometry_ada/actions/runs/42442260964): cancelled after the correction push;
- [historical shadow 42442260884](https://github.com/zackboll/opencv_geometry_ada/actions/runs/42442260884): cancelled after the correction push;
- [original push platform CI 42441933909](https://github.com/zackboll/opencv_geometry_ada/actions/runs/42441933909): success, not documentation qualification.

Correction head:

- [successor policy 42442528716](https://github.com/zackboll/opencv_geometry_ada/actions/runs/42442528716): failure;
- [documentation 42442528701](https://github.com/zackboll/opencv_geometry_ada/actions/runs/42442528701): build success, current-trust failure, deploy skipped;
- [historical shadow 42442528690](https://github.com/zackboll/opencv_geometry_ada/actions/runs/42442528690): pending at report snapshot.

Raw run-log ZIPs (rather than the incomplete job-log API) confirm the exact
successor failure: the checkout selects old base `e3f6764`; the 16 historical,
47 historical additive and 14 selector tests pass, then
`test -f scripts/test_gnatdoc_migration_policy.py` exits 1 because that test does
not exist in the selected old base. This is an additional explicit bootstrap
constraint, not a failed proposal test or toolchain failure. It is not skipped,
renamed or falsely satisfied. No candidate verifier is substituted.

Independent old-base checks against unchanged main pass (138 declarations, 562
AUnit registrations). Against original `906def7`, candidate rules reject
`protected verification component changed: .github/workflows/documentation-additive-policy.yml`.
Against corrected `4a54a65`, the earlier historical-byte gate rejects
`authority bytes differ: scripts/enhance_gnatdoc_navigation.py`. Both are real,
reproduced old-policy rejections; their order differs because the correction
changes a historical verifier helper. A maintainer cannot infer authorization
from independent proposal tests or from the absence of branch protection.

### Maintainer decision record (not an approval)

**Requested decision:** after reviewing the exact final PR head/tree and its
completed independent qualification ledger, decide whether to establish these
successor policy bytes as the base authority despite the documented old-base
rejections. No decision is made by this report or by the agent.

**Consequences if approved and merged by a maintainer:** subsequent ordinary PRs
select this merged base and still cannot alter their own verifier/selector.
Historical fixed-byte evidence remains bound to its immutable checkout; new
source is checked against its own exact commit and base-owned verifiers.
The transition's own main-push check still selects the older first parent;
approval is not permission to deploy from a failed transition or skip any gate.
No migration, new dependency, publication privilege or current-source expectation
repair is authorized here. `GEOMETRY-DOC-TEST-001` remains a separate follow-up.

**Not yet ready at report snapshot:** original, correction and final-head complete
campaign outcomes, positive-fixture recorders, final-head hosted checks and any
non-bootstrap failures must be inspected and recorded in PR #59. Keep
CORRECTIVE_WORK_REQUIRED until technical failures are resolved; use
HOSTED_CI_PENDING only if local qualification passes and hosted evidence remains
pending. READY_FOR_MAINTAINER_DECISION requires complete independent technical
qualification with only the reproduced legacy bootstrap decision remaining.

The exact changed-file inventory is the PR diff against main. R2 adds source-root
context plumbing to `scripts/enhance_gnatdoc_navigation.py`,
`scripts/install_gnatdoc_theme.py` and `scripts/validate_docs.py`, regression tests
only in `scripts/test_gnatdoc_migration_policy.py`, this report and the separately
named R2 evidence files. The finite migration allowance is unchanged; no existing
current-source test constants, historical evidence, selector, build manifest,
production generator/workflow or Ada/C++ source is modified by R2.

This branch proposes policy for a later migration; it does not perform one.
PR #58 is unchanged and must not be merged as a completed migration. No branch
protection, required check, production generator, build manifest, source,
authored input or publication permission is changed here.

## Baseline and authority

Fetched `main` is commit `e3f676489edaf0ce8a30ebc2cb7ce22ca1db4972`, tree
`27f527ce707846c9f997b0d7bce7f0a420d659b8`. PR #58 remains at
`641d794b13e89458a5882613c93d287c38160e96`; its report and evidence were read from
that branch, not copied into this proposal as new qualification.

`select_gnatdoc_policy.py` remains unchanged. Ordinary PRs select the exact
event's base SHA; main pushes select their actual first parent; dispatch selects
the main commit's first parent. Existing first-policy bootstrap allowlists do
not apply to this transition: main already contains a selector/verifier. No new
allowlist or candidate-policy selection exception is introduced.

The existing workflow executes `run_additive_gnatdoc_review.py` from the selected
policy checkout. Its `qualify_additive_gnatdoc.py` calls `candidate_rules`, which
protects all scripts/workflows and their inventories. Previously it additionally
required current generator/verifier bytes to match the older historical source.
The proposal retains immutable historical Git and evidence verification, but
compares contemporary executable inputs with the independently selected base.
It does not import candidate policy, validator or test modules for authorization.

`validate_gnatdoc_inputs.py` remains unchanged: root/test Alire manifests and
Markdown requirements retain the existing exact-input policy, including the
already authorized version exception and exact disposable qualification pins.
Source-derived declaration/order/profile checks, category ownership, AUnit
registrations/execution, zero gaps/warnings, compiled examples, native acquisition,
two-copy determinism, browsers, mutation restoration and final recorders remain.
Production qualification additionally checks native declarations/anchors directly
against independently acquired pristine output and invokes the base validator.

## Finite authorization

`scripts/gnatdoc_migration_policy.py` defines the entire scope, not a glob:

| Purpose | Files |
| --- | --- |
| Future production replacement | `scripts/generate_docs.sh`, `.github/workflows/documentation.yml` |
| Consumer compatibility validation | `scripts/validate_docs.py`, `scripts/test_validate_docs.py` |
| Contemporary test repair | `scripts/test_check_doc_coverage.py`, `scripts/test_gnatdoc_navigation.py`, `scripts/test_gnatdoc_navigation_browser.cjs`, `scripts/test_shared_gnatdoc_shadow.py`, `scripts/test_additive_gnatdoc_policy.py` |
| Future configuration | `docs/gnatdoc-enhancer.toml`, `docs/gnatdoc-authored.json` |
| Consumer instructions | `docs/documentation.md` |

The generator and workflow are not freely editable even within that scope.
Base-owned templates authorize only replacement of the duplicated enhancement
block and three workflow step bodies. They retain native generation, compiler,
Core, coverage/warning gates, preflight, historical checkout/tests, compiled
examples, browser checks, deployment dependency, main-only conditions and
permissions verbatim. Arbitrary command additions, editable/source installs,
floating versions and substituted downloads do not match the template.
The production workflow itself is **not** edited in this proposal.

The only production enhancer is the official `v0.1.5` wheel:

```text
ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl
d712d330f213fc1909a66c47bc2c7e5e15d5ec687222bea3c4922f5243db4247
```

The policy installer checks the entire wheel digest before pip, uses
`--no-index --no-deps --only-binary=:all:`, and checks installed version,
non-editable archive-origin digest and every package module/asset against the
wheel before and after production generation. The release has no mandatory
Python dependencies; the existing independently pinned Markdown requirements
remain separate. No policy approval is inferred from package metadata.

Scope recognition is not output qualification. A candidate-supplied TOML/manifest
cannot replace the independently reconstructed source/native inventories,
historical contracts, ratchets, browsers, tamper tests or base validator. The
scope-positive fixture intentionally has invalid production configuration and is
never reported as a migrated, qualified site. No search/examples opt-in is
authorized by this task.

New scripts/workflows, selector/verifier changes, unrelated script changes,
manifest dependencies/actions/pins, Core substitutions, historical evidence,
authored assets and Pages/PR permission changes are outside the envelope.
The test-only repair path permits only the five named tests plus consumer
instructions; it cannot accompany unrelated source/build changes. Historical
fixed-count suites are not edited or discarded.

## Historical execution and test-failure classification

The complete predecessor campaign remains bound to
`2f5239a0e264ca2bb4106cdb338d3eac25abf674`, its original source baseline
`ec4d689eac748b7837abd4c3754c3090ca4bf814`, immutable enhancer
`426f38852ef7dfff264f73ad01aab458f5e12b23` and Core
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`. It retains original native hashes,
fixed-count tests, examples, browser campaigns, adversarial thresholds and
independent recorder. That old enhancer is installed only in the isolated
historical/shadow test environment, never the production wheel environment.

The workflow's two policy-test modules now execute unchanged from their matching
pre-transform merge `20d5da104dcb156833e194067979dd6682a6d912`. Current selector
tests and new migration-policy tests execute from the independently selected
policy. This is explicit historical routing, not skipping a required check or
claiming current-tree discovery is green. The independent historical workflow
and historical verifier are otherwise untouched.

PR #58 recorded 309 tests, 27 failures, 5 errors in the expected sibling-Core
layout. Inspection classifies them as follows:

| Evidence | Classification and follow-up |
| --- | --- |
| 138 declarations vs 130; 87 subprograms vs 79 | Obsolete current-source assertions after eight approved transform overloads. Derive full package/kind/profile multisets from public source and compare with actual native sections; do not merely change constants. Keep 130/79 on the historical checkout. |
| 481 documented elements | Current baseline, not a failure. Derive package/declaration/member/parameter/return/literal identities from source and require all corresponding rendered documentation. Retain the independent empty gap/warning ratchets. |
| 112 category owners vs 106 | Six new public names with eight overloads. Compare the exact source-owned `(package, name)` set, enforce unique ownership and preserve category/order rules; do not confuse names with overload counts. |
| Duplicate `OpenCV.Geometry.Compose` positive fixture | Fixture defect: the current category manifest already owns Compose and the old positive fixture appends it again. Duplicate rejection is correct. Construct an actually absent controlled declaration/category fixture, keeping separate duplicate-rejection tests. No production category defect was observed. |
| Affine guide/example authored hashes | Historical fixture misuse: `trusted_inputs` is intentionally historical; current files changed legitimately in #57. Four errors and 23 subtest failures arise before the intended script mutation. Construct historical fixtures from immutable historical Git, not current files, and run current checks through base policy plus exact-head authored derivation. Do not regenerate historical authority hashes. |
| Authored-manifest derivation equality | Test assumes unchanged authored inputs despite the explicit two-file evolving scope. Compare frozen fields exactly; verify only those scoped hashes from current exact source and pristine native bindings. Keep old equality in its matching checkout. |

The navigation browser's `138 !== 130` assertion stops later assertions; it is
not a full navigation pass. A follow-up should supply an independent
source-derived expected navigation inventory to the current browser, validating
each package/profile/native-anchor/order rather than trusting HTML counts.
Test failures demonstrate defects in contemporary regression setup/assertions,
not permission to relax declaration, anchor or coverage validation. No actual
test repair is included here.

## Bootstrap: explicit maintainer decision, not a green-check bypass

1. Review the exact diff and independently acquire this PR's exact head/tree into
   a separate checkout. Execute the proposal tests there as **proposal
   qualification only**, with negative mutations and restored controls.
2. Independently execute the untouched old base against unchanged main and the
   proposal. The first passes (138 declarations, 562 AUnit registrations); the
   second rejects `protected verification component changed:
   .github/workflows/documentation-additive-policy.yml`. Script-only transition
   would likewise be rejected. Candidate code must not satisfy that check.
3. Keep the red current-trust result visible. The old selected-base workflow also
   encounters the previously recorded historical-input fixture errors before
   reaching its current-candidate campaign. Neither failure is approval.
4. Maintainer must explicitly decide whether to accept this exact policy
   transition despite the documented, structurally unavoidable old-policy
   rejection, after reviewing independent evidence. No permission to merge has
   been given to this agent. No required check is disabled, renamed or waived
   in code. If GitHub requires that check, stop: the maintainer must decide the
   repository-supported one-time bootstrap action; do not edit protection.
5. At inspection, the API reports main `protected=false`, protection endpoint
   HTTP 404 "Branch not protected", and applicable branch rules `[]`. There is
   therefore no observed GitHub required-check prohibition, but repository
   settings can change and must be rechecked by the maintainer. An unprotected
   branch is not automatic authorization to merge red checks.
6. A maintainer merge would make the successor available as a future base, not
   retroactively approve its own PR. The transition's main-push check still
   selects its old first parent and may remain red; do not deploy from it. A
   later ordinary PR based on the merged successor selects that base, not its
   own code. Do not change the selector to turn the bootstrap green.

This is the minimum bootstrap decision, not a new approval-record framework.
No auto-merge, protection changes or merge command is part of this delivery.

## Qualification and limitations

Local evidence workspace: `/home/zboll/git/geometry-gnatdoc-002-evidence/`.
The separate `successor-policy` checkout was clean for proposal tests:

- 13 new policy tests cover unrelated scripts/workflows, candidate
  selector/verifiers, new executables, wheel/version/origin substitutions,
  build dependencies, native anchor/declaration removal, coverage/diagnostics,
  historical evidence, Core/workflow changes and post-verification commit change.
- 14 unchanged selector tests pass.
- Historical policy tests: 16 shadow and 47 additive tests pass at their matching
  immutable revision, using the pinned Markdown environment.
- Official release assets still pass SHA256SUMS; the new isolated-mode verifier
  accepts the previously verified installed official wheel.
- The policy installer also installed the official wheel in a new disposable
  environment; an actual installed-module byte mutation was rejected and the
  original module restored/reverified. Real site mutations removed a declaration,
  changed its anchor, removed documentation and replaced it with name-only text:
  independent native/coverage gates rejected them and restored controls passed.
- Independent source/site recheck confirms 138 preserved declarations,
  87 subprograms, 481/481 documented elements, 112 category owners, zero warnings.
- Existing coverage mutation suite: 32 tests, 4 generated-site skips in the clean
  site-free policy checkout; validator suite: 68 tests, 28 generated-site skips.
  These synthetic passes do not replace generated-site qualification.

Focused tests were repeated in the clean `final-policy` checkout at
`11861670e50376b1f45dc5238873aeb7610e4859` (13 policy, 14 selector tests, all
passing). The long exploratory campaign is bound to earlier implementation
commit `a7616e4db05842b3e879cd145af25f6f3dbc49fd`, not the final delivery head;
its historical component reports identify the immutable predecessor, not this
proposal as approved. Final-head focused checks are re-run at handoff. A complete
final-head successor campaign remains required even if that earlier run finishes.

An initial run against uncommitted files correctly rejected differing executable
inputs. A historical test retry without Markdown errored; the pinned-environment
retry passed. A full campaign reached successful historical native/library/AUnit/
example/test qualification, then failed launching Chromium because its temporary
Unix socket path exceeded the OS limit. It was not counted as tamper rejection.
A short `/tmp` workspace retry is recorded separately. It has passed the original
historical browser suites and all 30 historical adversarial mutations with
restoration. Its full outcome remains pending; exact-head hosted runs are blocked
by the rejected workflow push. No readiness claim follows from these components.

The full successor campaign, migrated positive fixture and production compatibility
are not claimed qualified by the unit tests. In particular the base-owned legacy
validator intentionally remains fail-closed: if the release emits an incompatible
manifest or link representation, the migration must stop for independent policy
review rather than execute a candidate replacement validator as authority.
Any additional Core bookmark evidence files outside the finite configuration
scope need a narrowly reviewed scope update, not arbitrary directory permission.

Final commit/tree and exact-head hosted run URLs belong in the PR body/comment,
not a self-referential hash in this document. A passing unrelated build does not
erase the bootstrap blocker. Use READY_FOR_MAINTAINER_REVIEW only after complete
successor qualification and explicit remaining bootstrap requirements; until then
this proposal is CORRECTIVE_WORK_REQUIRED.

Exact changed-file inventory (relative to the starting tree):

- `.github/workflows/documentation-additive-policy.yml`
- `scripts/additive_gnatdoc_policy.py`
- `scripts/gnatdoc_migration_policy.py`
- `scripts/qualify_additive_gnatdoc.py`
- `scripts/test_gnatdoc_migration_policy.py`
- `docs/geometry-gnatdoc-enhancer-002.md`
- `docs/evidence/geometry-gnatdoc-002/` contains only qualification logs listed in
  the PR's exact diff inventory; it is not loaded as policy authority.

Reproduction in a clean, independently acquired proposal checkout:

```sh
python3 -m unittest discover -s scripts -p test_gnatdoc_migration_policy.py -v
python3 -m unittest discover -s scripts -p test_select_gnatdoc_policy.py -v
```

Run the two historical modules with the pinned Markdown Python against
`20d5da104dcb156833e194067979dd6682a6d912/scripts`, as specified in the proposed
workflow. For full campaign reproduction, use the existing
`scripts/run_additive_gnatdoc_review.py` from the independent proposal checkout,
an isolated historical enhancer environment, exact proposal candidate SHA,
qualified Core/GNATdoc/Playwright/Chromium paths and a short new `/tmp` workspace.
`--policy-review` labels this exploratory proposal run; it does not authorize
the proposal under the old selected-base policy or enable deployment.

## Follow-up after independent establishment

First submit the focused current-source test repair described above. Retain
original fixed assertions on historical source and execute both contexts with
their real generated sites. Then resume migration work from the independently
merged successor base, carrying forward PR #58's inventory and rollback evidence
without modifying or merging #58 in this task. Apply reviewed configuration,
run official CLI inventory/dry-run/enhance/verify, native/site comparison,
determinism/idempotence, examples, tamper, all browser profiles and exact-head CI.
If finite templates or the base validator cannot accept compatible release
behavior, stop for a specific policy correction; do not broaden candidate trust.