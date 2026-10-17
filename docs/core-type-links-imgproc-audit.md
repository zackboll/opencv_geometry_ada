# Imgproc audit: declaration-level Core type links

Audit only; no files in `opencv_imgproc_ada` were modified. Inspected remote
`main` at `9ce22ae5ab70008e1147475a9e6d7baef82f1df0`.

## Findings and required follow-up

1. `scripts/link_gnatdoc_types.py` has the same package-only link design as
   Geometry had. `CORE_PACKAGES` correctly identifies `OpenCV` and `OpenCV.Core`,
   but `CORE_DESTINATIONS` discards the type identity and `core_types` reduces
   declarations to name sets. Replace these with unique, exact qualified public
   type/subtype identities mapped to
   `https://zackboll.github.io/opencv_core_ada/api/index.html?symbol=...`.
   Preserve canonical source spelling, `_top`, scope checks and Imgproc's native
   local type anchors. Retain `DOC_CORE_SOURCE` support; do not broaden Ada
   visibility or infer identity from a simple-name/suffix match.
2. `scripts/validate_docs.py` imports `CORE_DESTINATIONS` and permits its two
   package bookmarks in `_check_links`. Recompute the declaration URL allowlist
   from the qualified Core sources and keep the full source/markup/integrity
   reconstruction. Reject package-only links, wrong existing symbols, invented
   fragments, removed/private declarations and altered targets.
3. Update `scripts/test_link_gnatdoc_types.py` and
   `scripts/test_validate_docs.py` with exact identities (including Rect, Size,
   Angle_Unit, Mat and a subtype), duplicate declarations and wrong-owner
   negatives. Preserve all existing internal-link and integrity mutation tests.
4. `scripts/test_gnatdoc_presentation_browser.cjs` currently intercepts Core
   requests with a `<title>Core stub</title>` response and asserts only package
   destinations. Update its URL assertions and add a separate real-Core browser
   integration test, as Geometry does: actual iframe `h4:target` and declaration
   snippet, scroll position, top-level navigation, reload, Back/Forward including
   return to Imgproc, desktop and mobile. A stub is not declaration evidence.
5. Extend `.github/workflows/documentation.yml` to run that integration against
   an immutable Core documentation-router revision or published Core after it
   is deployed. Keep the current indexed-release Core source snapshot
   (`386c5360ac51f2b62e522853d94290aec4ee14a0`) and production dependency
   resolution separate from the documentation artifact used for browser tests.
   Keep warning/coverage ratchets, final validation, deterministic fresh builds
   and idempotent enhancement checks intact.
6. Update `docs/documentation.md` and any package-only bookmark statements in
   the campaign record to distinguish the new symbol contract from historical
   qualification evidence. Document that Core must be published first.

This is a separate future documentation PR, not an Ada API, dependency, native
backend or ABI change. No generated hashes should be checked in or inferred.