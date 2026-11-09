# GEOMETRY-DOC-CI-SIMPLIFY-001 — documentation qualification routing

## Scope and security boundary

The documentation workflow's reusable `current-trust` job now uses the same
main-only condition as Pages publication:

```text
github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
```

The independent **Additive GNATdoc policy review (non-deployable)** workflow
remains the authoritative PR policy check, including ordinary documentation
and stacked PRs. It is byte-identical to main
`a91f7fe6423ea439b08cb7c29f595a936d29c0e4`. No path filters, approval shortcuts,
selector changes, historical-test skips, negative-mutation changes or
`continue-on-error` settings are introduced.

| Event | Documentation build | Independent PR policy | Reusable current-trust | Pages |
| --- | --- | --- | --- | --- |
| PR, including stacked PR | Run | Run | Skip | Never |
| Push to main | Run | Not separately triggered | Run | Both dependencies must succeed |
| Manual dispatch on main | Run | Not separately triggered | Run | Both dependencies must succeed |
| Manual dispatch off main | Run | Not separately triggered | Skip | Never |
| Push off main | Workflow not triggered | Not triggered | Not triggered | Never |

The build, preflight, historical/browser checks, Pages artifact guards, permissions
and complete deploy job are unchanged. `deploy.needs: [build, current-trust]`
is retained. GitHub's implicit `success()` still prevents deployment if either
dependency fails, is cancelled or is skipped. A manual main run still selects
its first parent as independent authority; the unchanged selector rejects
non-main manual qualification.

## Reproducible focused checks

From `/home/zboll/git/geometry-doc-ci-simplify-001`:

```sh
python3 -m unittest discover -s tests/ci -v
git diff --check
```

The standard-library tests compare unchanged workflow/job bytes against the
exact reviewed base, exercise PR/push/manual routing and failed dependencies,
and execute that clean base's actual selector and candidate rules in isolated
subprocesses. An ordinary documentation-only fixture must pass candidate rules;
the workflow transition must fail. Expected rejection assertions are regression
tests, **not** a successful policy qualification or authorization.

These are local simulations, not a hosted main push, manual main deployment or
permission to publish. Hosted PR qualification must remain independently visible.

## Required one-time bootstrap authorization

**This change is protected by current policy and is not merge-authorized.**
The base's finite migration envelope does not authorize this routing change.
The independent policy check must reject it; adding tests/report files can make
the first diagnostic `migration includes unrelated files`, while testing the
isolated workflow change yields `migration configuration missing`. Neither is
a transient failure or a pass. The selector must keep selecting the independent
base for PR, main push and manual main scenarios, never candidate policy.

A maintainer must independently review the final head/tree, this narrow diff,
event/dependency tests and the actual failed policy evidence, then explicitly
authorize a one-time protected-workflow bootstrap before any merge. The first
main push would still use the old main policy and can reject the changed
workflow; Pages must stay blocked. Once the authorized transition is on main,
a subsequent independently qualified unchanged-policy revision can establish
the new baseline. Do not rewrite policy selection, relabel a failure as success,
or weaken publication dependencies to make the transition green.

If external branch rules require the redundant PR context
`current-trust / GNATdoc successor policy qualification`, maintainers should
review the required-check configuration: PR authority is the standalone
`GNATdoc successor policy qualification`, while reusable current-trust remains
a mandatory main publication dependency. No branch/ruleset configuration is
changed here. At inspection the protection API returned `Branch not protected`
and the ruleset list was empty; candidate-owned YAML does not replace external
enforcement or independent review.

Geometry PR #58 must remain unchanged. This work uses its own branch/worktree;
auto-merge must remain disabled and no merge is authorized.