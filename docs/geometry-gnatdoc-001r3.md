# GEOMETRY-GNATDOC-001R3 qualification compatibility

This correction is based on main `49afc3285d4e5e3d93c0f67cedd93c77eb0ffad3`.
PR #58 remains at `5691ec8d6d2f2bea0addd9fd0e7f90fe794f1c12` until this
correction is independently qualified and merged. No generated/release assets or
production Ada/C++ sources are changed.

## Reproduction and classification

The R2 clean checkout, with real released output and Core 0.5.0 as its sibling,
ran 384 tests: 34 failures, 12 errors, 7 skips. The original failure log was
retained outside the repository. The results partition as follows:

| Results | Classification | Cause and correction |
| --- | --- | --- |
| MigrationPolicyTests: 1 failure, 8 errors | Fixture/setup defect | Migration fixtures cloned the evolving production generator and configuration, then applied a legacy-only transformation. Reset only test generator/workflow/configuration inputs from immutable main into a disposable committed fixture; verifier modules still come from the candidate. Missing-configuration and every security mutation remain exercised. |
| GeneratedNavigationTest: 9 failures, 2 errors | Obsolete legacy assumption | Legacy data attributes, labels, button serialization and local generator were assumed for released output. Exercise released navigation serialization and released idempotence, using the existing independent source/category/native oracle. Retain legacy branches on legacy output. |
| GeneratedSiteTest: 24 failures, 2 errors | Obsolete legacy assumption | Legacy diagnostic wording, fragment-only local links, Core symbol-query links and type-crossrefs metadata were assumed. Mutate the actual release page/fragment URLs and presentation metadata. Require mutation-specific reconstruction/metadata diagnostics, not arbitrary errors. Retain legacy diagnostics and metadata attacks on legacy output. |
| ProductionMutations: 7 skips | Fixture/setup defect | GEOMETRY_MIGRATION_PREVIEW was absent. Supply a freshly generated real preview; execute all seven tests. Do not remove their precondition or count skipped tests as qualification. |

No actual production regression was found in that failure set: fresh generation,
independent native reconstruction, eight Core source/native identities, all
source-backed occurrences, coverage, warnings and browser matrices had passed.
This statement does not excuse unrelated errors: every attack must change bytes
and reject for the expected integrity reason, and full qualification remains
blocking.

## Boundaries

`migration_generator()` remains legacy-only. Already-migrated input is not
silently accepted. The production generator contract still checks executable
commands and all native/Core/toolchain/coverage/warning gates.

Baseline-owned tests are loaded from the independent base checkout. The selected
challenge runner supplies immutable legacy **input data** for the migration
suite only. Candidate verifier modules still execute; other security suites use
the actual candidate. No old tests are replaced by proposed test bytes.

Synthetic qualification is explicit, not inferred from filenames or a candidate
manifest. The fixture must match the policy-owned definition byte-for-byte,
including its exact parent, and that parent independently passes the production
migration envelope. Only the exact fixture delta is separated from that parent;
new verifier files, dependency changes, altered historical evidence and arbitrary
source/category/guide/test mutations remain rejected. Ordinary candidates do not
receive this path. Migrated synthetic sources use a disposable production
projection: only independently derived authored/native hashes are rebound there.
The fixture commit and its inherited configuration bytes remain unchanged. The
standard production generator and independent official-wheel/native verifier
both run on the projection; it is not release output.

An additional hosted-only fixture defect was found after the R2 reproduction:
the native-declaration mutation selected the first filesystem glob result and
assumed it was Geometry rather than Subdiv2D. It now selects the unique native
package owner and mutates the specific Contour declaration heading, independent
of filesystem order.

## Qualification

Focused tests precede full campaigns. Exact final commit/tree identities and
hosted results are reported in the corrective PR, rather than self-referential
committed approval records. Historical evidence stays immutable. No reviewers,
approval environments or branch protection settings are required by this change.
