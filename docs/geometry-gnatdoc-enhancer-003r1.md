# GEOMETRY-GNATDOC-003R1: native Core link policy proposal

**Not a production migration or merge authorization.** Start: freshly fetched
Geometry main `294df5a`. Imgproc main inspected at
`a777f331cda1a00dc00d5173206779dffd4721c4`; its PR #81 qualifier is unchanged
(`7c8cc84b8a52dff7467c0a303acab32de1d019d9c7a0c64ea96eea40c51c3ebd`).

## Scope and preservation

The previous `policy/geometry-gnatdoc-003-core-bookmarks` branch had no
task-specific commit or PR and was still at `294df5a`. Its 566 MB evidence
workspace was inventoried without editing it. No running qualification process
was found. Preserve that workspace and branch; do not resume its publisher
bookmark evidence design. The inventory receipt is in the evidence directory.
PR #58 is neither modified nor merged. No Pages deployment is requested.

Only independent policy/qualification code changes here. The production
generator, production validator, workflow triggers/permissions/Pages jobs,
both Alire manifests, source, ABI, historical contracts and renderer requirements
remain unchanged. No production enhancer configuration is added.

## Reuse, not a new external evidence system

`qualify_current_core.py` adapts Imgproc's deployment discovery, same-run
push-to-main workflow/build/deploy binding, main-history/tree binding,
GitHub-digest-checked ZIP and ZIP/TAR readers, bounded members/inventory,
public complete declaration comparison, exact native section/anchor matching,
live HTTPS byte equality and deployment race detection.
`qualify_production_core_links.py` contains only the reusable source/native
matcher and bounded transport helpers from Imgproc, not its historical ledgers,
URLs, resolver, 0.5.2 dependency or full migration machinery.

Geometry reconstructs authority from its existing hash-pinned **Core 0.5.0**
source/native ledger (`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`). The freshly
generated 197-file native inventory equals that existing authority exactly.
All 681 recorded source files are checked. The Ada dependency is not the
publisher: newer Core documentation is accepted only for identical complete
referenced public declarations and genuine native anchors. No deployment ID,
whole-site count or live inventory is a future acceptance pin.

## Compatibility-first result

Official enhancer v0.1.5 wheel SHA-256:
`d712d330f213fc1909a66c47bc2c7e5e15d5ec687222bea3c4922f5243db4247`.
Its installation/module integrity was checked independently. A disposable
configuration uses ordinary `[external_types]` full HTTPS fragment destinations
and `external_type_target = "_top"`; no external bookmark or dependency
evidence extension is needed.

| Exact public Core type | Occurrences | Source/native/authenticated/live |
| --- | ---: | --- |
| OpenCV.Angle_Unit | 2 | PASS |
| OpenCV.Core.Mat | 5 | PASS |
| OpenCV.Float32_Point | 24 | PASS |
| OpenCV.Float32_Value | 6 | PASS |
| OpenCV.Float64_Value | 49 | PASS |
| OpenCV.Point_Array | 1 | PASS |
| OpenCV.Rect | 5 | PASS |
| OpenCV.Rotated_Rect | 12 | PASS |
| **Total** | **104** | **8/8 types, 104/104 occurrences** |

Current authenticated publication: deployment `7507096111`, source
`b4253d4af31f0bacd6c6e2828d4657a9842cb71e`, 210 files. The two referenced
pages match authenticated review/Pages artifacts and public HTTPS bytes.
Native URLs were discovered from fresh Core 0.5.0 GNATdoc output and verified
against that publisher, not copied from Imgproc's URL configuration.
Complete profiles, ownership, page/anchor and live digests are recorded in
`docs/evidence/geometry-gnatdoc-003r1/referenced-types.json`.

Focused desktop/mobile Chromium checks passed with JavaScript on and off:
top-level frame exit, exact visible native declaration/profile, reload,
Back/Forward and fresh tab. Incoming `?symbol=OpenCV.Type` URLs also pass with
JavaScript enabled (Core's existing symbol router requires JavaScript; this
proposal does not change Core or claim new no-JavaScript symbol routing).

All 138 Geometry declaration profiles and native anchors remain exact. All 178
existing local links retain their actual owner/page/anchor; the enhancer adds
four valid local constant-type links (182 total). This is explicit, not hidden
as byte parity. Overload/navigation identity is independently source-resolved.

## Narrow policy correction and bootstrap decision

The selected-base `verify_production` now has a distinct official-wheel branch
for candidates containing both finite migration configuration files. It calls
the base-owned `validate_migration_site`, not candidate `validate_docs.py`.
Legacy production and immutable historical/offline shadow verification still
use their original validators and URLs.

The new branch requalifies the current publisher, demands the exact finite
configuration derived by base policy, preserves Geometry's exact theme asset,
checks staged source equality, regenerates the complete site from independently
acquired native HTML, compares every file, and independently checks every
type occurrence, native profile/anchor, navigation/overload, warning and coverage
gate. A coordinated output-manifest rewrite is not authority. A final publisher
race check closes the validation. Candidate-selected hosts, paths, fragments,
targets, plugins/features or checkers are not allowed.

**Explicit independent policy-bootstrap authorization is required.** Current
main deliberately rejects changes to protected policy code; green proposal
tests cannot authorize that code. Do not change the selector or allow candidate
validators to bypass this. Review the final head/tree, evidence and finite diff,
then obtain explicit maintainer authorization before any merge. The repository
currently reports no main branch protection and no rulesets; this agent changes
neither setting. Auto-merge must stay disabled.

## Remaining work for PR #58

After independent policy establishment, reconstruct the migration on the then
current main in separate work: exact official wheel installation; finite
production configuration/authored manifest; workflow-owned authenticated Core
pre/post-browser qualification with credentials scoped to read-only publisher
access; standard generator/validator integration; full exact-head independent
historical/current/synthetic/negative/browser qualification; publication parity,
theme and rollback review. This proposal does not claim those future migration
steps complete and does not alter or merge #58.

Qualification outcomes and the exact changed-file inventory are appended after
the campaigns finish. Retained earlier runs are labelled historical/reused,
not relabelled as fresh evidence.