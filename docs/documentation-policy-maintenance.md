# Documentation policy maintenance (GEOMETRY-DOC-CI-STABILIZE-001)

## Trust modes

The independently checked-out PR base computes a NUL-delimited, no-renames
Git diff against the exact event head. Both sides of a rename, removals, new
files, scripts, workflow helpers, CI tests, evidence, assets, build inputs and
documentation baselines are included. Labels, uploaded manifests and proposed
policy configuration do not choose a mode. Both technical jobs recompute the
inventory; no GitHub file-list truncation is used for PR mode selection.

Ordinary candidates run the existing independent base-policy campaign unchanged:
historical qualification, actual source/native comparison, examples, AUnit,
coverage, publisher authentication, browser matrices and negative mutations.

Protected candidates run a separate **non-deployable** maintenance qualification:

1. Record the actual old-policy verdict, exit code and diagnostic in
   `compatibility.json`. Rejection is evidence, **not a passed old-policy test**.
2. Build a disposable compatibility projection using the proposed source and
   old verifier/workflow/CI-test bytes. Dependency inputs, historical evidence,
   assets and baselines are **not** replaced. Independent old-policy rules and
   the complete old-policy executable campaign must pass on this projection.
   Its commit/tree are recorded; it is not the PR candidate or a release.
3. Challenge proposed modules with base-owned negative test bytes. Execute
   proposed-policy historical/current/synthetic campaigns and negative mutations,
   then the released-wheel executable production preview and actual-site attacks.
   No test changes or candidate-written JSON establish approval.
4. Require the separately configured maintainer environment. That job checks out
   **no source**, executes no candidate code, and receives no write permissions.
5. Verify GitHub's approval history and live exact head/base, not a local approval
   file. The stable `Documentation policy acceptance` PR check also requires the
   documentation `build`; failure, cancellation, rejected approval or a skipped
   protected gate cannot produce acceptance.

There is no automatic approval, blanket failure suppression or Pages artifact in
the maintenance workflow. A deliberately malicious replacement verifier must
still face independent old-policy source qualification, old negative tests and
explicit human review. CI is not a sandbox for native code: these jobs use
disposable GitHub-hosted runners, read-only tokens and no environment secrets.

This intentionally does not authorize new dependencies or rewrite historical
trust anchors. Such a change failing independent compatibility requires a
separate, explicitly reviewed contract correction, not an unrestricted allowlist.

## Main publication

`current-trust` runs before main's build. Its base-owned metadata verifier audits
first-parent transitions back to authorized contract merge
`23701d526bd0870de5fb126c2ecdd0b9c24913e2` (PR #63, reviewed head
`0007f8d557aae51593560675b96c161542348164`, tree
`04363fb712f15514f7ba11909c595176e4907b62`). For later protected transitions it
requires a two-parent merge, an exact-head merged PR, a successful documentation
workflow including technical qualification, environment approval and stable
acceptance, approval before merge, and no protected merge-only substitutions.
Missing/expired API records, truncation, direct protected pushes, rejected reviews,
superseded main and unauthorized transitions fail closed. Keep workflow records
for this audit; deleting them can intentionally block later publication.

Only after that check does qualification/build use the approved merged policy.
`deploy.needs: [build, current-trust]`, the main-only Pages guards, deployment
environment, Pages permissions and deployment action are preserved. Deployment
action failures remain failures. No Pages deployment is part of this task.

## Required external configuration — NOT configured by this PR

Verified at task resumption: the only environment was `github-pages`; main had
neither branch protection nor repository rulesets. No configuration mutation or
approval has been performed by the agent.

An administrator must:

- Create `documentation-policy-maintenance`, with explicit maintainer users as
  required reviewers, administrator bypass disabled, and **no secrets**. Restrict
  reviewers to administrators/maintainers. Self-review prevention is recommended
  when another maintainer exists; no bot or workflow automatically approves.
- Require `Documentation policy acceptance` on main, from GitHub Actions, with
  up-to-date branches, stale approval dismissal and no merge bypass. Protect
  workflow/policy changes with independently enforced maintainer/CODEOWNER review
  (or an organization-required workflow pinned outside the candidate). A check
  name alone cannot prevent a malicious PR from replacing its own workflow.
- Require merge commits for protected transitions; squash/rebase policy merges
  intentionally fail the publication provenance check.
- Preserve the existing main-only `github-pages` environment restrictions.
- Ensure read-only Actions tokens can read environment configuration and run
  approval history. API permission failure is blocking, never assumed approval.

The workflow verifies required-reviewer configuration, disabled bypass, actual
maintainer role, live head/base and server-side approval. An absent or weak
environment fails configuration; a correctly configured environment waits for
approval after technical success. Skipped jobs are not enforcement.

## One-time installation boundary

The existing approved main lacks this orchestration. Only that literal base
commit **and** tree permit exploratory candidate orchestration for this PR.
The workflow itself computes the initial changed-file mode with Git. Old policy
validators still execute from a separate clean approved base. This is not
approval of the router, does not permit unknown bases, and does not authorize
merging this PR. External workflow review and maintainer environment approval are
required. After merge, subsequent runs execute orchestration from their base.

## Reproduction

From a clean exact commit, run:

```sh
python3 -m unittest discover -s scripts -p test_documentation_policy_transition.py -v
python3 -m unittest discover -s tests/ci -v
node --test tests/ci/test_policy_provenance.cjs
actionlint .github/workflows/documentation.yml .github/workflows/documentation-additive-policy.yml
git diff --check
```

Existing tool environments and SHA-bound production/historical evidence from
PR #63 remain reusable for unchanged native, publisher, browser and adversarial
implementations. New hosted environment approval and actual Pages failure results
must not be inferred from local routing/API simulations. PR #58 remains untouched.