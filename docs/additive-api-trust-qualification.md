# GEOM-DOC-010 — qualification progress and corrective disposition

**CORRECTIVE_WORK_REQUIRED. Not an approval record. GEOM-031 remains blocked.**

PR: <https://github.com/zackboll/opencv_geometry_ada/pull/53>.
Starting main: `2f5239a0e264ca2bb4106cdb338d3eac25abf674`;
tree: `c440b9901e1003f06ae555b3a8a80d9874229680`.
The PR's exact head/tree must be read from Git; no self-referential final commit
hash is embedded in this file. Later documentation/tool changes do not make
earlier whole-campaign evidence final-head qualification.

## Evidence actually executed

Local native backend: OpenCV **4.10.0**, **imgproc**, Core **0.5.0** at
`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`. The non-editable enhancer is
`426f38852ef7dfff264f73ad01aab458f5e12b23`. Predecessor qualification checks
Alire 2.1.1, GNAT 16.1.0, GPRbuild Alire 26.0.1 / executable 26.0.0 and
GNATdoc 26.0.0 (20260415), including its binary hash. Chromium used the existing
qualified local executable, reporting Chrome for Testing 145.0.7632.6.

| Check | Actual result and scope |
| --- | --- |
| Original focused trust tests | 16/16 pass; all 23 historical script mutations remain rejected |
| Successor focused tests | 17/17 pass before final report integration; not approval |
| Production library build and AUnit | Pass, 547/547, zero failures/errors; production source unchanged |
| Fresh predecessor exact-main qualification | Pass, historical 542/542 and current 547/547 AUnit; 232 original documentation tests; 130 declarations, 267 references, 452/452 items |
| Original predecessor browser suites | Four suites pass after correcting the local browser path and using a clean acquisition directory |
| Historical sequential adversarial campaign | 30/30 pass with independent restoration |
| Predecessor eight-cell browser matrix | Pass, 6,904 assertions; initial frame-navigation race retained as failed attempt |
| Independent predecessor recorder | Pass, exact main, full local shadow qualification, non-deployable |
| Successor exact component snapshot `b278cf9c210acec3b91554ac2dff490559bc5a8a` | Pass, 130 declarations, 267 references (171 local, 96 external), 452/452 items, zero warnings, 547/547 AUnit |
| Disposable fixture `4b5dcc8f11e0f2353fce023835d1065aa66b4c21` on that policy | Pass component checks: 132 declarations, 271 references (173 local, 98 external), 458/458 items, zero warnings, 548/548 AUnit; both synthetic overloads and all six examples execute |
| Current browser matrix on earlier `ac208036a9b5a6da036a6c6fba03a8f8f9885726` component output | Pass, 6,604 assertions, eight cells; not final-head or fixture-browser evidence |
| Successor sequential attacks on `b278cf9...` and its fixture | Both campaigns fail overall: 24 attacks observed, rejected and restored, then stale-commit rejection raises an unhandled `CalledProcessError` in the harness. Handling is corrected in source but full corrected campaign not yet qualified |
| Final-head independent successor recorder | Not complete; must remain non-ready |
| Hosted workflows | Queued/running when inspected, not represented as passing executions |
| Windows PR jobs | Skipped by the main/manual-only policy, not passed |

The disposable fixture adds `Policy_Probe` twice with distinct profiles. It
references real Core numeric and Geometry transform types, adds one transform
category name, genuine guide API links, executable example assertions and one
AUnit case. These names have no production authorization. No synthetic operation
is added to committed `src/` or `tests/src/`.

## Local evidence identities

Evidence is local, not claimed as hosted downloadable artifacts. The verified
predecessor workspace is `/tmp/geomdoc010-baseline`; component workspaces are
under `/home/zboll/qualification/geomdoc010/`.

| Evidence | SHA-256 at observation |
| --- | --- |
| Predecessor `qualification.json` | `bf08b4e628723f5a92ba05fdb8493517af6fceb0cf401627539361c30c58253e` |
| Predecessor `readiness.json` | `8eb73786eb6fadd887a4133496d899e05cb992ef33fd073df0ec206d2abed358` |
| `current-6/qualification.json` | `0920856298b519ac4f05bfcff4e1c607b5b4ade6a8a1a53128bf51c586825ad3` |
| `fixture-run-6/qualification.json` | `007ed6119f40188ce3b426322ce3e660663ce8d8552beaac342fd687ff5af043` |
| Earlier `current-4/browser.json` | `01c62bcecd92e8ff24805de978ecbac4329107cfb31b69ca02cb599fede6fdc5` |

These execution hashes are evidence locators, not new trust roots. The original
GNATDOC-009B authority digest remains
`ddf461928a5fc7a3ab4fc9ed0248c237aa465e581249708a5390496b7b447cb5`.

## Concrete remaining work

1. Integrate historical/current workflow routing. The unchanged standard docs
   workflow still runs protected fixed-count regressions against candidate
   output, and the predecessor shadow workflow still evaluates candidate HEAD.
   The successor shadow path alone does not unblock an additive feature PR.
   Preserve generator and Pages behavior while separating those test tracks.
2. Run corrected final-head current and fixture component checks, both browser
   matrices, the full successor sequential campaign, and independent readiness
   recording. Do not reuse earlier-head results as final-head success.
3. Complete actual-historical-checkout Python and original-browser qualification
   through the updated campaign driver; do not confuse same-count current output
   with the historical source identity.
4. Inspect final exact-head hosted documentation/platform controls and collect
   evidence artifacts. A queued check and a skipped Windows job are not passes.
5. Independently review the workflow bootstrap, trusted-base selection,
   protection of the required check, allowed authored scope, and all successor
   verifier dependencies. Neither the author nor its own tests can approve this.

Failed local attempts included a wrong browser executable path, retained clone
directory, fixture blank-line style rejection, `/tmp` inode exhaustion, a
case-normalization bug in constant-type resolution, a browser-ready attribute
typo, and the attack exception-handling defect. Corrections are reviewable in
the PR; none of those failures is converted into a passing whole-campaign claim.

No tag, release, Alire index submission, version change, production functionality
change or GEOM-031 branch change is part of this work.