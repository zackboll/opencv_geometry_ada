# GEOMETRY-DOC-CONTRACT-RESET-001

This is a protected-policy proposal, **not bootstrap authorization**. Do not
merge or publish Pages on the strength of local preview results. The old main
must reject replacement policy code; explicit maintainer authorization and
independent review remain required. PR #58 is not changed by this proposal.

## Inputs and diagnosis

* Main: `05c6680cdf4f9fe544cfbbab21cf13eab41d0112`.
* Migration: `02b8b2f1b3d6ba1bdca8582b1c09f6bd5f1d1935` (PR #58).
* Production enhancer: official v0.1.5 wheel, SHA-256
  `d712d330f213fc1909a66c47bc2c7e5e15d5ec687222bea3c4922f5243db4247`.
* Core source dependency stays 0.5.0,
  `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`.

The former exact generator template could not execute its own approved
configuration. It omitted `qualification-public`, and copied `docs/index.html`
into an authored output destination before enhancement. Released
`authored-markdown` owns that destination and correctly refuses to overwrite
it. Its overwrite protection must not be bypassed.

Removing those two problems exposes **additional** legacy validator conflicts:

* Legacy `type-crossrefs.json` is not an official enhancer output.
* Native Core declaration URLs are not legacy symbol-query bookmarks.
* Official index serialization includes release-owned document metadata.
* Authored landing, guides and CSS must be reconstructed by the released
  pipeline, not the old project renderer.
* `presentation.json` has a different schema and is an untrusted claim, not
  independent native authority.

No official enhancer bytes, production dependencies, Ada/C++ sources, project
files, ABI or Pages permissions are modified.

## Bounded authorization

`migration_generator()` remains an executable example, **not an authorization
oracle**. The envelope checks separately named native/toolchain/Core/warning
gates, a bounded staging/enhancement program and the coverage/empty-baseline
ratchets. Whole-line comments, indentation and continuation layout do not
authorize or prohibit behavior. Quoted text remains significant. Unknown
commands, shell substitutions, helper scripts and downloads fail closed.
Additional explicit byte/file integrity checks are permitted; arbitrary
candidate shell is not.

The three existing documentation installation/generation/determinism `run`
bodies are validated as ordered critical commands with bounded additional
integrity checks. Everything outside those bodies remains unchanged, preserving
PR builds, main-only `current-trust`, `deploy.needs: [build, current-trust]`,
read-only PR permissions, independent base selection, immutable historical
qualification and main-only Pages publication. There are no new dependency
installers or candidate-controlled verifier authorities.

Generated staging contains exactly:

```
qualification-public/opencv-geometry.ads
qualification-public/opencv-geometry-subdiv2d.ads
```

Both files must be safe regular files, byte-identical to their `src/` inputs,
with no symlink ancestors, extra entries or tracked staging. Each production
generation recreates the directory, removing a deliberately injected stale Ada
file during preview. Staging is generated build input, never committed source.

The local validator adapter checks release-format reconstruction, fixed authored
inputs/configuration, source/native declarations and Core source bytes. It does
**not** claim live publisher authentication. The independently selected policy
separately generates pristine native output, authenticates current Core
publication/artifacts/live HTTPS, reconstructs the entire site with the official
wheel, checks every source/native/type occurrence, checks coverage/warnings,
and checks publisher identity again to detect deployment races. Candidate
validator edits cannot replace that authority.

## Executable production preview

Use a **clean separate checkout** of the proposed policy at an exact full SHA.
The preview clones it into a disposable candidate, overlays PR #58's pinned
configuration/workflow/authored manifest and applies only the generator and
validator adaptation. Its deterministic commit records policy ancestry and
exact candidate tree. PR #58's branch is neither checked out nor modified.

An existing official wheel environment must contain the pinned dependencies in
`docs/requirements.txt`; install the wheel non-editably with the policy's
`--wheel ... --install` command. Do not use the historical enhancer environment
for production. Supply existing exact Core and GNATdoc installations and
Playwright 1.64.1 with `/usr/bin/google-chrome` for the existing production
browser matrix. No browser assertion or historical test is removed.

Example (replace the absolute paths and exact policy SHA):

```sh
/absolute/wheel-venv/bin/python -I /absolute/policy/scripts/gnatdoc_migration_policy.py \
  --wheel /absolute/releases/ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl --install
/absolute/wheel-venv/bin/python /absolute/policy/scripts/preview_gnatdoc_migration.py \
  --policy-revision FULL_40_HEX_POLICY_COMMIT \
  --workspace /absolute/new-short-preview \
  --wheel /absolute/releases/ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl \
  --core /absolute/core-0.5.0-checkout \
  --gnatdoc-prefix /absolute/gnatdoc-26.0.0 \
  --playwright-module /absolute/browser/node_modules/playwright
```

The executable runs actual production generation twice; independent native
Geometry/Core acquisition; authenticated reconstruction; source/native and Core
link validation; clean warnings and complete coverage; byte-idempotence;
compilation/execution of all six examples; source-derived AUnit execution;
real-output negative mutations; the eight-cell live native Core browser matrix;
and the eight-cell authored guide matrix. It writes `preview.json`,
`independent-validation.json`, all command logs and their SHA-256 identities.
Omitting `--playwright-module` is explicitly a component-only preview, not full
qualification. The existing historical/current/synthetic campaign remains
separate and mandatory.

The first complete production component run demonstrated 138 declarations,
481/481 documented elements, zero warnings/gaps, eight authenticated Core
types, all 104 external occurrences and 182 local occurrences, six examples
and 562/562 AUnit cases. The live browser matrix visited 138 operation entries,
104 external links and 182 local links in **each** of eight desktop/mobile,
light/dark, JavaScript-enabled/disabled cells. Authored guides also passed all
eight cells. Exact-head results and remaining blockers belong in the PR report;
these measurements are evidence, never future publication pins.

## Maintainer bootstrap boundary

The unchanged old-base rejection is expected **red evidence**, not a green CI
result. Request explicit maintainer bootstrap authorization for the exact
policy commit/tree after independent review of the executable preview and all
historical/security results. Do not select the candidate policy as ordinary
verification authority or disable the rejection to make hosted checks green.