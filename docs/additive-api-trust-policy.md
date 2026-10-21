# GEOM-DOC-010 — additive API successor policy (candidate)

## R3 trusted build inputs and 0.3.3 integration

Independent review found two gaps in R2: a candidate could change the pip
requirements file, and snapshot identity did not authorize Alire dependencies,
actions or environment settings. A later current-trust failure did **not**
prevent production's earlier candidate installation. R3 corrects that ordering,
not merely the final status check.

`validate_gnatdoc_inputs.py` is a standard-library-only preflight. It imports no
candidate code and executes no package manager. `candidate_rules` invokes it
before other candidate checks, and qualification invokes the real rules before
any `alr pin`/build/generator. Requirements must be byte-identical to the selected
reviewed policy, retaining the existing comment, `markdown-it-py==3.0.0` and
`mdurl==0.1.2`. Missing files, symlinks, changed line endings, package additions,
removals, versions, URLs, editable packages, indexes and pip options all fail.

The tests manifest must also be byte-identical. The root manifest is compared
byte-for-byte after replacing only its unique canonical root version line with
the reviewed line. TOML parsing additionally rejects duplicate/ambiguous root
versions. All other bytes are protected, including comments, crate identity,
metadata, dependencies/platform constraints, actions, pins, environment and any
unknown keys. Version syntax is canonical three-component nonnegative decimal
without leading zeros or suffixes. Unchanged versions pass; the **only** reviewed
exception is `0.3.2` to `0.3.3`, independently established by merged PR #56.
This is not a general patch-release permission, downgrade permission or
candidate exception list. A future release requires new independent review.
The integrated policy itself contains 0.3.3, so normal candidates match it.

Only disposable qualification source copies receive the documented Core pins
(`../core` for root and `../../core` for tests). Initial validation forbids new
committed pins; the post-build verifier requires exactly the candidate original
plus that suffix, and strips exactly one known suffix for compatibility checks.
An extra pin, modified suffix, or arbitrary manifest content remains rejected.
The tests crate's existing parent-crate pin remains part of reviewed bytes.

Production documentation checks out the exact event base separately. **Before**
candidate Alire actions or pip dependency installation it runs only that base's
preflight in Python isolated mode. In the first-policy transition, where main
does not have that script, the workflow's literal reviewed commit/tree guard
and shell `cmp` check all three inputs without loading any candidate verifier.
Candidate input must then match those immutable reviewed base bytes exactly.
Pip consumes the separate base's requirements file, never candidate requirements.
Subsequent ordinary feature validation uses the independently reviewed base
implementation. This ordering is tested by executing the actual workflow shell
with valid and mutated disposable checkouts; no action or installation is run
by that test. Candidate YAML still requires external review/enforcement: a PR
cannot secure its own arbitrary workflow replacement merely by reporting green.

Main `aad0b1b65814ac472bf5a9ea1b266f47aa3baf06`, tree
`be543978b6fe33cc7bb18c4c1ca58328ae741ee6`, incorporates PR #55 (cross-install)
and PR #56 (0.3.3 preparation). Their full diff, ten-path inventory, merge parents
and exact final blob identities were inspected. Core `>=0.5.0 & <0.6.0`, public
Ada/C ABI sources, test registrations and historical authority are unchanged.
The selector explicitly verifies both merged PR parent pairs, all ten blobs,
and ancestry back through PR #54; only this literal newer base/tree joins the
earlier reviewed bootstrap pairs. Intermediate or arbitrary mutable-main bases
are not authorized. Initial PR execution stays exploratory. First main push
requires its actual first parent/event-before plus policy second parent; merge
substitution protection now also covers both manifests and requirements.
Later additive features retain independently sourced ordinary policy selection.
`policy_approved` stays false on every execution path.

The mutation catalog covers documentation versions/addition/deletion/index/
editable/direct URL/options/missing/CRLF, Core constraint, extra dependency,
pre-build/extra action, MSYS2 environment, unauthorized pin, AUnit/GNATprove/
GNATcov, unknown key, duplicate/unreviewed version, missing manifests and
manifest CRLF. Every attack first validates a real disposable candidate, changes
one input, requires a specific policy ValueError (not a tool failure), restores
all bytes, and independently revalidates. Both successor campaigns include this
catalog in addition to all original 25 attacks; readiness requires every named
input attack as well as the raised total. Historical 30-attack tests are intact.
Additional focused tests exercise symlink substitution, temporary-pin isolation,
valid authorized version-only change and unchanged inputs.

Required-check names and maintainer rules below remain applicable. The R3
protection query again returned main unprotected and zero rulesets. **No external
settings were applied; BRANCH_PROTECTION_REQUIRED.** Independent approval,
workflow/trust owner review, dismissal of stale approval, latest-push approval,
required checks, and no force-push/deletion or silent bypass remain necessary.
DO NOT MERGE remains in effect; no release/tag/index/GEOM-031 action is authorized.

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

R1 explicitly authorizes one synchronization-only successor change to
`qualify_shared_gnatdoc_browser.py` (not one of the protected 23 originals):
history restoration waits for the actual iframe URL and complete document
instead of the next navigation event, which may be an aborted superseded load.
All 130 entries, 12 categories, eight cells, source/profile/type checks and
16 history transitions remain asserted. The selected policy checkout supplies
this driver while immutable historical output supplies its inputs. The original
historical Git object and all 23 protected original scripts remain unchanged.

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

## R1 routing and publication boundary

The standard `Ada API Documentation / build` job still builds and generates
the actual candidate with the unchanged production `scripts/generate_docs.sh`,
checks deterministic fresh output/idempotence, executes all six examples and
uploads the actual current `_site`. Its unchanged fixed-count Python and four
Chromium suites now run on `ec4d689eac748b7837abd4c3754c3090ca4bf814`, with
that checkout's generated output. No historical output is substituted for the
current artifact. The existing `Shared GNATdoc shadow / qualify` identity now
executes the immutable predecessor campaign at `2f5239a...`, including native,
542/542 historical AUnit, 30 attacks and the eight-cell historical matrix.

The standard workflow also calls the successor workflow as `current-trust`.
Pages deployment needs **both** `build` and `current-trust`; only authorized
non-PR main events retain Pages/OIDC permissions. The uploaded Pages artifact
comes exclusively from production `geometry/_site`, never an offline workspace.
The successor independently regenerates production output, checks its complete
coverage and forbids `.invalid` destinations, in addition to its shadow checks.
Both current and disposable additive fixture execute this same production
generator twice and independently again during verification. Fixed historical
regressions are never applied to the expanded candidate output.

All three workflows retain read-only contents permissions and non-persistent
checkout credentials for source execution. There is no label/name/path bypass.
The additive workflow is reusable as well as PR-triggered. PR policy selection
uses the exact base SHA; main push uses the event's predecessor, and manual main
uses its first parent. A missing successor is bootstrapped only from the named
immutable predecessor and is explicitly exploratory/unapproved. A candidate
cannot change scripts/workflows to authorize new verifier bytes. Future policy
changes require a separate human-reviewed policy transition.

Administrators must protect the existing `build` and `qualify` required-check
identities and the new reusable current-trust check, and require independent
workflow review (for example through repository rules/CODEOWNERS managed by the
maintainer). No API call in this task changes branch protection. Candidate-owned
workflow YAML, read-only tokens and evidence hashes alone cannot prevent an
authorized attacker from replacing the workflow or runner; those are explicit
external trust assumptions, not self-proven guarantees. **DO NOT MERGE** until
final technical qualification and independent review are complete.

## R2: reviewed newer-main transition and exact check contexts

Main advanced through independently merged PR #54 to
`5f71c9a6d5291adb032eb1a43954c5f9aaf047e6`, tree
`cc8487634f66be422e835b95c2ee8cd57e952d45`. Its parents are the immutable
predecessor `2f5239a...` and `43e7a398a5c154ef7d63e44d12c5251d6647dc3e`.
The reviewed change inventory is exactly the macOS standalone workflow, its
qualification shell script/report, `opencv_geometry.gpr`, and
`opencv_geometry_shim.gpr`. GPR changes select the configured SDK for Apple
Ada links and preserve externally-built shim metadata for installation. Apple
clang/libc++, shim ownership/linkage, public Ada and the C ABI are unchanged.
R2 incorporates those exact bytes through a normal merge, not a rebase.

`select_gnatdoc_policy.py` contains the literal two allowed first-policy
base/tree pairs, the newer merge's exact parents, and all five Git blob IDs.
Before exploratory candidate code can run, both workflow definitions independently
enforce those same literal pairs. There is no mutable-main allowlist, editable
approval manifest, changed-path/label exemption, or automatic approval bit.
Unknown bases, substituted event heads, changed trees and wrong ancestry fail.

Three separate paths are qualified:

1. **Initial policy PR:** event base must be an exact ancestor, and only a
   literal reviewed base lacking successor scripts permits candidate policy
   execution. That selection is explicitly exploratory, never approved.
2. **First main push:** event `before` must equal candidate first parent;
   `after` must equal candidate. With an allowed predecessor lacking the
   policy, require a two-parent merge and select its second parent (the policy
   PR revision). The reviewed base must be an ancestor of that parent, and
   scripts/workflows/historical evidence must match the merge candidate.
   Squash/rebase-style initial publication is rejected rather than guessed.
   This gate remains exploratory/unapproved; independent human merge review
   supplies approval, not workflow execution. Manual main runs check the same
   first-parent ancestry.
3. **Later feature PR:** execute the selector and verifier from the clean exact
   event base. The candidate is untrusted and cannot replace scripts, workflows
   or historical evidence. The genuine additive fixture exercises this path
   and records `fixture-policy-selection.json` with distinct base/head.

Both historical and successor workflows now use explicit unique job display
names; old generic `qualify` contexts must not remain the configured protection
rule. GitHub Actions workflow names are not sufficient to distinguish two
same-app check runs named `qualify`. Maintainers should configure a ruleset for
`refs/heads/main` with these exact observed check names (GitHub Actions app):

- `build` (standard production documentation)
- `GNATdoc historical shadow qualification`
- `GNATdoc successor policy qualification` (standalone)
- `current-trust / GNATdoc successor policy qualification` (standard reusable)
- `Linux x86_64 / Core 0.5.0` and `Linux x86_64 / Core 0.5.1`
- `macOS ARM64 / Core 0.5.0` and `macOS ARM64 / Core 0.5.1`
- `Debian 12 / Core 0.5.0` and `Debian 12 / Core 0.5.1`
- `reference` (Debian AArch64), `consume` (installed consumers), `synthetic`
  (cross-configuration), plus the four `Standalone homebrew ARM64 / Core ...`
  and `Standalone macports ARM64 / Core ...` checks from merged PR #54.

Require PRs with at least one approval from an independent non-author reviewer,
dismiss stale approvals, require approval of the most recent push, require
up-to-date branches and resolved conversations, and block force pushes/deletion.
Require owner review for `.github/workflows/`, `scripts/` verifier components,
`docs/evidence/`, policy documents and policy scope. An independently maintained
CODEOWNERS/ruleset must assign actual trusted owners; this task does not invent
reviewer identities. Protect the owner/ruleset definitions too. Disable routine
bypass (including administrator bypass where supported); emergency exceptions
must be explicit, audited, and must not silently approve candidate verifier
replacement. Required-workflow rules should come from a maintainer-controlled
source where the hosting plan permits them. Windows PR skips and Pages `deploy`
are not required success checks. A merge queue needs separately reviewed
`merge_group` routing before adoption.

The repository protection API currently reports main unprotected and no enforced
ruleset was observed. **BRANCH_PROTECTION_REQUIRED**: these settings have not
been applied by this task. Human approval and external workflow/runner integrity
remain necessary; candidate-owned YAML alone cannot guarantee non-bypassability.