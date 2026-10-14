# Public Ada API documentation

The specifications `src/opencv-geometry.ads` and
`src/opencv-geometry-subdiv2d.ads` are authoritative. The generated site is
intended for `https://zackboll.github.io/opencv_geometry_ada/`; its landing
page is `_site/index.html` and the native GNATdoc reference is
`_site/api/index.html`. Do not commit generated HTML.

The tooling is adapted from the qualified `opencv_imgproc_ada` documentation
pipeline (Imgproc `main` `19ce3641254a3a9f5c97feca10fb3f2ef4a7f2b5`), which
itself adapts `opencv_core_ada` (Core `main`
`c0709f864a2f426c40eeaf1d21486c6d9859a741`). Campaign status, inventories and
the remaining roadmap are kept in
[the campaign record](gnatdoc-campaign-progress.md).

## Reproduce on Linux — pinned generation environment

Required qualification versions:

| Tool | Release / executable version |
| --- | --- |
| Alire | 2.1.1 |
| GNAT Native | Alire `gnat_native=16.1.0`, executable GNAT 16.1.0 |
| GPRbuild | Alire `gprbuild=26.0.1`, executable 26.0.0 (2026-04-15) |
| GNATdoc | Alire `gnatdoc_bin=26.0.0`, executable 26.0.0 (20260415) |
| opencv_core | 0.4.1, commit `386c5360ac51f2b62e522853d94290aec4ee14a0` |

Also install a supported native OpenCV development library, pkg-config, a
C++17 compiler, a POSIX shell, Git and Python 3.9 or newer.

The production manifest constrains `opencv_core` to `>=0.2.0 & <0.5.0` and
contains no pin; Core `main` is already `0.5.0-dev`. Documentation is
therefore generated against one exact Core release, applied as a temporary
pin exactly as the cross-platform CI does. Never commit the pin:

```sh
git clone https://github.com/zackboll/opencv_core_ada.git core
git -C core checkout --detach 386c5360ac51f2b62e522853d94290aec4ee14a0
git clone https://github.com/zackboll/opencv_geometry_ada.git geometry
cd geometry
alr -n --force toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
alr -n pin opencv_core --use=../core
alr -n with --solve
sh scripts/generate_docs.sh
git checkout -- alire.toml   # drop the temporary pin afterwards
```

(`alr -n pin --unpin opencv_core` leaves a trailing blank line in
`alire.toml`, so restore the file with Git instead.)

The script locates the repository root itself. It installs the pinned binary
GNATdoc crate into `.doc-tools/gnatdoc-26.0.0` when absent; Alire verifies the
archive against the index's SHA-256. An existing installation can be reused:

```sh
GNATDOC_PREFIX=/path/to/gnatdoc-26.0.0 sh scripts/generate_docs.sh
```

The script refuses other Alire, GNAT, GPRbuild or GNATdoc versions rather than
silently substituting them; in particular the `gnatdoc` that GNAT Studio puts
on `PATH` is never used. It builds the library through Alire (not the test
crate) to resolve dependencies and generate the normal OpenCV configuration.
It then requires the Alire-resolved `opencv_core` (`OPENCV_CORE_ALIRE_PREFIX`)
to be the top level of its own Git checkout, at exactly the commit above, with
no modified tracked files; an index-resolved, moved or locally edited Core
fails. Finally it runs:

```sh
alr exec -- "$GNATDOC_PREFIX/bin/gnatdoc" -P docs_api.gpr \
  --backend html --generate public --style leading --warnings -O "$PWD/_site/api"
python3 scripts/compare_gnatdoc_warnings.py --fail-on-removed \
  docs/gnatdoc-warning-baseline.txt obj/docs/gnatdoc.log
python3 scripts/validate_docs.py _site
```

`docs_api.gpr` parses `src/` with the production Ada compiler switches
(`Opencv_Geometry_Config.Ada_Compiler_Switches` plus `-Werror`, as in
`opencv_geometry.gpr`). `docs_internal.gpr` makes `src/internal` available for
name resolution with the same switches, and both import `opencv_core.gpr` for
the Core types. The `Documentation` package excludes `docs_internal.gpr`, the
generated configuration project and `opencv_core.gpr` (located through
`OpenCV_Core'Project_Dir`, because the attribute requires a resolvable path).
Only `OpenCV.Geometry` and `OpenCV.Geometry.Subdiv2D` are published; the
Subdiv2D private part, both bodies, every `OpenCV.Geometry.Internal` unit
(including `Internal.C_API`), the C++ shim and every Core package are not.
These projects do not import `opencv_geometry.gpr`: redeclaring its sources
would violate GPR source ownership. The library projects, ABI, manifest and
dependencies are unchanged.

`_site/` is deleted before each generation. Full diagnostics stay in
`obj/docs/gnatdoc.log` and are not published. `--warnings` stays enabled.
GNATdoc errors, partial-generation diagnostics, warning regressions, missing
public declarations and broken local links fail the script.

## Warning baseline

GNATdoc warnings are measured, not suppressed. After a successful run,
`compare_gnatdoc_warnings.py` maps every warning in the log to one Ada
declaration and compares the result with `docs/gnatdoc-warning-baseline.txt`,
which stores one identity per warning:

```text
filename: enclosing scope: normalized declaration signature: warning: message
```

The signature is the complete declaration with comments removed and
whitespace normalized, so overloads remain distinct and a function keeps its
return profile and contract aspects. The scope includes the enclosing package
(`OpenCV.Geometry` or `OpenCV.Geometry.Subdiv2D`), the enclosing record for
components and discriminants, including variant components, and the
enumeration type for literals. Line and column numbers only locate the
declaration in the current sources: line shifts, comment edits and log
reordering match, while a warning that moves to another declaration is an
addition. Unmapped or ambiguous locations, and warning-shaped lines that are
not the pinned `file:line:column: warning:` form, fail closed.
`--fail-on-removed` makes the baseline a ratchet: fixing a warning without
regenerating the baseline fails, so a fixed warning cannot silently return.
`generate_docs.sh` always uses it.

The comparator is Imgproc's with one Geometry correction, covered by
negative-first tests in `test_compare_gnatdoc_warnings.py`: a record whose
discriminant part spans several lines before `is record`
(`Rotated_Rectangle_Intersection`) is scanned for its `end record` from the
line after the header's own `record` keyword. The unchanged Imgproc scan
started two lines after `type`, counted that keyword as a nested record and
failed closed on `src/opencv-geometry.ads`. New Geometry shape tests cover
variant components, the two-name discriminant list of `Voronoi_Diagram`, and a
child package with `private with` clauses and an `overriding` private-part
subprogram.

After an intentional, reviewed documentation change, regenerate the baseline
from a complete pinned GNATdoc 26.0.0 log and the sources of the same revision:

```sh
python3 scripts/compare_gnatdoc_warnings.py --write-baseline \
    docs/gnatdoc-warning-baseline.txt obj/docs/gnatdoc.log
```

Never replace it with a raw log, and never rewrite it to accept new warnings.
Do not silence a warning with `@exclude`, an empty comment or a changed
generator invocation. The initial baseline records 360 warnings (246 in
`OpenCV.Geometry`, 114 in `OpenCV.Geometry.Subdiv2D`, of which 2 concern the
private-part `Finalize` override, which GNATdoc checks but does not publish).

## Site validation

`validate_docs.py` derives its expectations from `src/*.ads`, never from the
generated output, and modifies nothing:

- The site contains exactly `index.html`, `api/index.html`, `api/gnatdoc.css`
  and one native page per public package, two in total. GNATdoc 26.0.0 names
  package pages with 64-hex hashes; pages are identified by their actual
  `<h1>`, never by a computed filename. Any other file, an internal or Core
  package page, a duplicate or a missing public package fails.
- `api/index.html` must equal the pinned GNATdoc 26.0.0 serialization rebuilt
  from the discovered pages, including every `target=document-content`. Its
  Tagged Types list is empty: `Subdivision` is tagged only in the private
  part.
- Every visible-part declaration has exactly one native `h4` section of the
  same kind on its own package's page. Subprogram sections must reproduce the
  complete normalized profile, so removing, adding, altering or moving one
  overload fails, and private-part declarations must not appear.
- GNATdoc 26.0.0 does not render aspect specifications: the eight overloads
  with a `Post` contract (`Closest_Ellipse_Points`, `Convex_Hull_Indices`,
  `Convexity_Defects` and `Transform_Points`, two each) are shown without it.
  The expected profile therefore stops at the first `with` outside
  parentheses, and a rendered aspect fails closed. The guarantees those
  postconditions express must be stated in the comments.
- Representative declarations must be present in their own package, selected
  overloads must render their own comments in their own section (a
  Float32 `Contour_Area` arithmetic note, the
  `Intersect_Convex_Polygons_Extended_Float32` implementation note, the
  `Find_Nearest` liveness warning), and the Subdiv2D package description must
  render its task-safety rule.
- Links must be relative and resolve inside the site, including fragments.
  API pages have no external links; the landing page may link only to the
  Geometry and Core repositories and the Core and Imgproc documentation
  sites.
- Scripts, `base`/`object`/`embed`/`form` elements, `meta http-equiv`, event
  handler attributes, duplicate IDs, internal unit names, shim symbols and
  machine-local paths are rejected.
- The landing-page example must be exactly `docs/example.adb`.

`test_validate_docs.py` applies negative mutations to a synthetic
parent-and-child fixture in the pinned serialization and, when `_site`
exists, to a copy of the real generated site: missing stylesheet, broken and
redirected anchors, swapped index targets, duplicate IDs and pages, scripts
and handlers, root-absolute, traversal and external links, internal package
pages, a missing child page, stray files, removed, altered or moved overloads,
rendered aspects, published private declarations, misplaced overload
comments, a removed package-description rule, leaked paths and shim symbols,
and changed examples must all be rejected.

## Landing-page example

The example on `docs/index.html` is `docs/example.adb`, compiled with
assertions and warnings as errors and executed in documentation CI:

```sh
alr exec -- gprbuild -P docs/example.gpr
obj/docs-example/example
```

## CI and Pages review gate

`.github/workflows/documentation.yml` runs for every pull request
(including stacked documentation PRs whose base is another branch), pushes
to `main` and manual dispatch. It checks out Geometry and the qualified Core
commit side by side and applies the same temporary pin as the cross-platform
workflow. Pull-request runs have only `contents: read`: they test the tooling,
generate and validate the site, repeat the validator mutations on the
generated site, regenerate to prove byte-identical output, compile and run the
example, and upload the site and `gnatdoc.log` as review artifacts. They never
configure or deploy Pages.

Only `refs/heads/main` runs upload a Pages artifact. A separate job that
depends on the successful build deploys it with `pages: write`,
`id-token: write` and the `github-pages` environment. Superseded runs are
cancelled. Manual runs on other branches validate but cannot publish. No PAT
or `gh-pages` branch is used. On 2026-10-13 the repository already had Pages
configured with **Source: GitHub Actions** and a `github-pages` environment
whose deployment branch policy allows only `main`; no deployment had been
made, and the site URL returned 404. The first publication happens on the
first `main` push after this workflow merges.

## Comment convention

Use adjacent **leading** `--` comments: GNATdoc runs with `--style leading`,
and a blank line between a comment and its declaration detaches the comment.
A comment placed after a declaration documents the *next* declaration, so
existing trailing comments must be moved when their declaration is
documented. Use `@param`, `@return` and `@exception` with names matching the
actual declaration. The GNATdoc 26.0.0 conventions verified by the Imgproc
campaign (`@enum` for enumeration literals, `@field` for record components and
discriminants, `@exception OpenCV_Error` rather than the dotted name) are
re-verified on Geometry's sources before use. Do not change declarations or
behavior to improve generated output.

## Testing the documentation tooling

```sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
sh scripts/generate_docs.sh
python3 -m unittest discover -s scripts -p 'test_validate_docs.py' -v
alr exec -- gnatformat --check -P docs/example.gpr docs/example.adb
alr exec -- gprbuild -P docs/example.gpr && obj/docs-example/example
git diff --check
```

The documentation tools use only the Python standard library. None of them is
a dependency of the library or the `tests` crate.
