# Documentation technical CI

`Documentation policy acceptance` is the single acceptance check. It requires
the documentation build and technical qualification to succeed. There are no
required reviewers, approval environments, approval API calls, bootstrap
authorization records or branch-protection prerequisites.

## Qualification

The event's exact candidate and base commits determine a NUL-delimited Git diff
with renames disabled. Script, workflow, CI-test, evidence, asset, configuration
and build-input changes select policy maintenance. Labels and uploaded manifests
do not select the path.

- **Ordinary PRs:** run the existing strict, independently checked-out base-policy
  campaign against the actual candidate.
- **Policy changes:** run independent baseline input/source compatibility and
  security tests, then one proposed-policy campaign. A disposable source
  compatibility projection restores baseline verifier/workflow/test bytes;
  requirements, historical evidence, assets and warning/coverage baselines are
  not replaced. Only known old-envelope rejection is diagnostic; unexpected
  baseline failures or projected source/security regressions remain blocking.
  Base-owned negative test bytes also challenge proposed verifier modules.
- **Production preview:** policy changes execute the real official-wheel
  migration preview, deterministic native generation/reconstruction, publisher
  and Core link validation, coverage, compiled examples, AUnit, output mutations
  and browser matrices. Proposed tests run on actual generated documentation.
- **Main:** qualify its actual merged policy and source, not the old policy's
  prohibition on replacing verifier files. No commit/tree bootstrap allowlist or
  approval-history audit is involved.

There is one historical/current/synthetic campaign per qualification job, not
separate full baseline and proposed campaigns. The baseline static compatibility
and negative-test checks are deliberately separate from proposed executable
qualification. Diagnostic artifacts never authorize changes or substitute for
executed tests. The existing legacy `--policy-review` driver switch only permits
technical self-testing; it requires no review or external configuration.

## Publication and security boundary

PR jobs use read-only credentials with checkout credential persistence disabled.
No privileged `pull_request_target` execution or blanket failure suppression is
used. Official enhancer wheel digest/installed-byte verification, pinned Core
sources, native declarations/destinations, coverage, warning, browser and security
checks remain blocking.

Pages is main-only. Main's build waits for successful current qualification.
`deploy.needs: [build, current-trust]` is preserved; failure, cancellation or skip
of either prerequisite blocks deployment. Only the deployment job receives Pages
and OIDC write permissions. Its existing `github-pages` environment is the Pages
publication target, not a reviewer gate introduced by this change.

These are technical tests, not a sandbox or a guarantee against arbitrary
malicious workflow replacements. Untrusted native/candidate code runs on
disposable read-only-token runners without publication secrets. No repository
reviewer/protection configuration is necessary for green CI.

## Focused reproduction

From a clean committed checkout:

```sh
python3 -m unittest discover -s scripts -p test_documentation_policy_transition.py -v
python3 -m unittest discover -s tests/ci -v
actionlint .github/workflows/documentation.yml .github/workflows/documentation-additive-policy.yml
git diff --check
```

The workflow contains the pinned tool installation and exact production-preview
commands. Existing SHA-bound native/browser/adversarial evidence can be reused
locally when those implementations are unchanged; hosted CI still runs the
appropriate technical campaign for its exact candidate. No Pages deployment or
PR #58 modification is part of CI stabilization.