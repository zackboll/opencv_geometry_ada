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
| opencv_core | 0.5.0, commit `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` |

Also install a supported native OpenCV development library, pkg-config, a
C++17 compiler, a POSIX shell, Git and Python 3.9 or newer.

The production manifest constrains `opencv_core` to `>=0.5.0 & <0.6.0` and
contains no pin. Documentation is generated against one exact Core release,
the Core 0.5.0 release commit, applied as a temporary pin exactly as the
cross-platform CI does. Never commit the pin:

```sh
git clone https://github.com/zackboll/opencv_core_ada.git core
git -C core checkout --detach f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f
git clone https://github.com/zackboll/opencv_geometry_ada.git geometry
cd geometry
alr -n --force toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
alr -n pin opencv_core --use=../core
alr -n with --solve
python3 -m venv .doc-tools/markdown   # documentation-only guide renderer
.doc-tools/markdown/bin/pip install -r docs/requirements.txt
DOC_PYTHON=$PWD/.doc-tools/markdown/bin/python sh scripts/generate_docs.sh
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
"$DOC_PYTHON" scripts/render_gnatdoc_guides.py _site
"$DOC_PYTHON" scripts/validate_docs.py _site
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
generator invocation. The initial baseline recorded 360 warnings (246 in
`OpenCV.Geometry`, 114 in `OpenCV.Geometry.Subdiv2D`, of which 2 concerned
the private-part `Finalize` override, which GNATdoc checks but does not
publish). GEOMETRY-DOC-002D reached zero, and the baseline is now required to
stay empty (see "Current status" below).

## Site validation

`validate_docs.py` derives its expectations from `src/*.ads`, never from the
generated output, and modifies nothing:

- The site contains exactly `index.html`, `api/index.html`, `api/gnatdoc.css`,
  the presentation files listed below and one native page per public
  package, two in total. GNATdoc 26.0.0 names
  package pages with 64-hex hashes; pages are identified by their actual
  `<h1>`, never by a computed filename. Any other file, an internal or Core
  package page, a duplicate or a missing public package fails.
- `api/index.html` must equal the pinned GNATdoc 26.0.0 serialization rebuilt
  from the discovered pages, including every `target=document-content`, plus
  only the approved presentation changes. Its Tagged Types list is empty:
  `Subdivision` is tagged only in the private part.
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
  The only external links in API pages are the two recomputed package-level
  Core type links described below; the landing page may link only to the
  Geometry and Core repositories and the Core and Imgproc documentation
  sites.
- Scripts (except the one approved browser script in `api/index.html`),
  `base`/`object`/`embed`/`form` elements, `meta http-equiv`, event handler
  attributes, duplicate IDs, internal unit names, shim symbols and
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

## Declaration coverage (GEOMETRY-DOC-002A)

`scripts/check_doc_coverage.py` measures documentation by declaration
identity, independently of GNATdoc's warnings. Its inventory comes from the
visible part of `src/*.ads`, separately for each package: the package
description; every declaration, identified by package, kind, name and, for
subprograms, the complete normalized profile, so each overload is a separate
item; every parameter and every function's return value; every enumeration
literal; every record component and discriminant. It reads the native
section of that exact declaration on its own package page, matching
subprograms by their profile without aspects (GNATdoc 26.0.0 omits them),
and requires:

- the members GNATdoc lists to be exactly the source members, in order;
- non-trivial text for each item: at least two words, not merely its name,
  so an empty `@param` or a copied identifier does not count;
- every visible-part comment block to be attached and every line of it to
  render where it belongs: immediately preceding a declaration, or the
  package description, which is either the last block before `package`,
  separated from it only by blank lines (the layout both Geometry packages
  use and GNATformat keeps), or the first block inside the package followed
  by a blank line. Detached, trailing and markup-mangled comments fail.

Undocumented items are ratcheted in `docs/gnatdoc-coverage-baseline.txt`
exactly like warnings (`--fail-on-removed`, `--write-baseline`); attachment
errors and member mismatches can never be baselined. `generate_docs.sh` runs
the check after validation; `--report` prints coverage per package and per
item kind. The inventory has 452 items: 2 package descriptions, 130
declarations, 145 parameters, 76 function returns, 39 enumeration literals
and 60 record components and discriminants.

On the DOC-001 head the checker found 10 attachment defects: the three
Subdiv2D section preambles ("Extraction", "Navigation", "Voronoi diagram"),
separated by blank lines, never rendered, and seven formulas lost their
`**` or `*` to emphasis. DOC-002A moved the preambles verbatim into the
Subdiv2D package description and put the formulas in code spans.

### Current status: zero warnings, complete coverage

Since GEOMETRY-DOC-002D, GNATdoc reports zero warnings and all 452 items are
documented: both package descriptions, 130 declarations (76 functions, 3
procedures, 45 types, 2 subtypes, 4 constants), 145 parameters, 76 function
returns, 39 enumeration literals and 60 components and discriminants, in
`OpenCV.Geometry` (307) and `OpenCV.Geometry.Subdiv2D` (145). Both baselines
are empty and `generate_docs.sh` fails if either records an identity again,
so a new public declaration must be documented completely in the same
change. Neither the zero count nor full coverage proves that every statement
is correct; the per-phase records in the campaign progress file list what
was verified against the body, the shim and exact OpenCV sources, the
statements added after that verification, and the findings for the
maintainers.

`scripts/check_comment_only.py BASE [TARGET]` proves that a documentation
change altered only comments. It compares two committed revisions (`TARGET`
defaults to `HEAD`), so the temporary Core pin in a working tree cannot
affect it. Every Ada source under `src/` must have the same tokens at both
revisions once comments and layout are removed, with string and character
literals kept, so a changed declaration, default, literal, pragma or
contract fails, as does an added or removed source. Every other file tracked
at `BASE`, apart from `docs/`, `README.md` and `.gitignore`, must be
byte-identical and present: the C++ shim, the tests, `alire.toml`, the
production GPR projects, the build and configuration scripts and the
cross-platform workflow. New documentation tooling files are allowed. It
qualifies documentation pull requests; it is not a CI gate, because feature
work legitimately changes declarations.

## Presentation: theme, type links and Ada highlighting (GEOMETRY-DOC-003)

Adapted from Imgproc's IMGPROC-DOC-003 tooling (itself from Core's
DOC-069/DOC-070). `generate_docs.sh` runs three deterministic, idempotent
steps after the warning check; each verifies the previous ones before writing
anything:

1. `install_gnatdoc_theme.py` inserts one viewport `meta` and one stylesheet
   link after GNATdoc's native stylesheet in every API page and copies
   `docs/assets/gnatdoc-theme.css` (responsive layout, light and dark color
   schemes, visible keyboard focus, code blocks that scroll inside themselves
   on narrow screens; no web fonts or CDN). `api/presentation.json` records
   every page's native HTML outside declaration snippets and the hash of the
   native `gnatdoc.css`; any other change to that HTML or either stylesheet
   fails.
2. `link_gnatdoc_types.py` links type marks inside native declaration
   snippets only: parameter, component, return, array component, subtype and
   derived-type positions, never defaults, constraints or attributes.
   - A Geometry type links to its own native section anchor, discovered from
     the source-matched section of its package page. An unqualified name
     links when exactly one visible-part declaration of that name precedes
     the reference in the same package and no parameter or discriminant
     shadows it. In `OpenCV.Geometry.Subdiv2D`, an unqualified name that the
     child does not declare links to the parent's declaration on the
     `OpenCV.Geometry` page (`Float32_Point_Array`, three times), as does the
     qualified `OpenCV.Geometry.Triangle_Vertices`; a name declared in both
     packages stays unlinked.
   - `OpenCV.X` and `OpenCV.Core.X` link only when Core's `src/opencv.ads` or
     `src/opencv-core.ads` (from the Core checkout verified by the generator's
     gate, opencv_core 0.4.1) declares that type in the visible part of
     exactly that package. The destination is the published Core browser's
     package bookmark,
     `https://zackboll.github.io/opencv_core_ada/api/index.html?package=OpenCV`
     or `...?package=OpenCV.Core`; no declaration fragment is invented. These
     links carry `target="_top"` and are drawn with a dashed underline. The
     Core site documents Core `main`; every linked type exists in the visible
     part of both releases' root packages.
   - Standard types (`Natural`, `Positive`, `Boolean`) stay unlinked.
   `api/type-crossrefs.json` keeps, per package page, the original snippets
   and a hash of the page outside them; validation recomputes every link and
   requires byte-identical snippets. The current output has 167 Geometry
   (including 4 cross-page) and 96 Core links in 130 snippets; 24 Standard
   type marks stay unlinked.
3. `highlight_gnatdoc_ada.py` colors Ada keywords, numbers, strings,
   characters, attributes, comments and operators inside snippets with flat
   `ada-*` spans, keeps type links atomic and proves that removing the spans
   restores the exact snippet text.

`validate_docs.py` then repeats the theme, link and highlighting checks
independently and probes representative declarations (`Convex_Hull`,
`Get_Rotation_Matrix_2D`, the Subdiv2D batch `Insert`) for the exact type
identities their own snippets must link. `test_link_gnatdoc_types.py` covers
a synthetic parent-and-child fixture, and `test_validate_docs.py` mutates the
real site: wrong-but-existing type destinations on the same page and across
pages, a cross-page anchor moved onto the wrong page, fabricated Core
declaration fragments, removed links, changed declaration text and
descriptions, a tampered theme asset, corrupted or downgraded manifests and
stray presentation files are all rejected. Repeating the three steps on a
finished site is byte-identical.

The optional real-browser harness `scripts/test_gnatdoc_presentation_browser.cjs`
uses an externally installed Playwright module and Google Chrome (never a
site or library dependency). At 1280 and 390 pixels in light and dark it
checks the landing and both package pages (backgrounds, no horizontal page
overflow, highlighting, snippets that scroll internally), that every Core link
is an approved package bookmark opening at top level, that an internal type
link lands on the native anchor, that the Subdiv2D link to
`Float32_Point_Array` opens the `OpenCV.Geometry` page at that declaration,
keyboard focus outlines, a Core link replacing the window, and native
navigation to both packages with JavaScript disabled:

```sh
python3 -m http.server 8073 --bind 127.0.0.1 --directory _site
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright \
DOC_URL=http://127.0.0.1:8073/ node scripts/test_gnatdoc_presentation_browser.cjs
```

## Package- and operation-level API browser (GEOMETRY-DOC-004)

Core's browser searches 195 packages and Imgproc's the declarations of one
package. Geometry publishes two packages with 130 declarations, so its
browser works per package and per declaration.
`enhance_gnatdoc_navigation.py` changes only `api/index.html`, adding:

- one hidden search control group (label, search field, Clear button and a
  polite live status), revealed by the script;
- a static "Public API" list in the sidebar: one section per package, headed
  by a link to that package's page, each with collapsible `<details>`
  categories listing every visible-part declaration. Each entry is a native
  link to the declaration's verified anchor in the documentation frame and
  shows its kind and, for overloads, "overload N of M"; the full profile is
  the link title;
- one deferred repository-owned script, `gnatdoc-navigation.js`.

Entries come from the public specifications (names, kinds, profiles, overload
order), the reviewed category manifest `docs/api-categories.json` and anchors
discovered from source-matched native sections. The manifest lists the two
packages in order and assigns every public declaration name of each package
to exactly one of that package's categories (seven for `OpenCV.Geometry`:
point sets, contours and moments; hulls, convexity and curve approximation;
shape matching and geometric queries; fitting and enclosing shapes;
intersections and rotated geometry; affine and perspective transformations;
native capability and compatibility; five for `OpenCV.Geometry.Subdiv2D`:
lifecycle and bounds; insertion and point queries; edge and vertex
navigation; triangles and extraction; Voronoi diagrams and facets). Category
identifiers are unique across packages; a new declaration fails generation
until it is categorized. No filename or anchor is computed.

The script provides case-insensitive search over package, name, kind,
category title and profile (every word must match, so `subdiv2d insert`
finds the Subdiv2D `Insert` overloads), category expansion for matches,
hiding of a package section without matches, a count or "No matching
declarations." in the live status, and Clear, which restores the list and
returns focus to the field. Selecting an entry marks it with
`aria-current="page"`, loads its anchor in the frame by replacing the
frame's history entry, and records a bookmark such as
`api/index.html?package=OpenCV.Geometry.Subdiv2D&op=Voronoi_Facets&overload=1`
in the outer history; selecting a package link records
`api/index.html?package=OpenCV.Geometry.Subdiv2D`. Back, Forward and reload
restore the selection. Lookups ignore identifier case and canonicalize the
URL; unknown, path-like or wrong-package requests select nothing and are
removed from the URL. Destinations always come from the static entries and
package links, never from query or search text. Without JavaScript the
controls stay hidden and the categorized links, package links and tabs still
work. Declaration pages are unchanged.

Validation rebuilds the expected index from the pinned native serialization,
the theme metadata and the recomputed entries and compares it byte for byte;
the script bytes must equal the repository asset, and it is the only script
allowed, once, in the index. `test_gnatdoc_navigation.py` rejects category
manifest errors (duplicates, a category identifier reused across packages, a
package listed twice, bad versions, empty categories), wrong-but-existing
destinations, an entry moved to the other package, missing entries, inline
handlers, extra scripts including one on a package page, a tampered asset, a
redirected package heading and changed frame targets, and checks that every
declaration has exactly one entry and that enhancement is idempotent.

`scripts/test_gnatdoc_navigation_browser.cjs` (optional Playwright and
Chrome, as above) qualifies the browser at 1280 and 390 pixels in light and
dark: the 130 entries, 2 package sections and 12 categories; searches for
`cOnVeX_hUlL`, `voronoi`, `subdiv2d insert`, `fit ellipse`, `perspective`,
`nearest`, `moments`, `intersection` and `native capability`; a search
confined to one package; overload labels, no-results and Clear; frame
navigation to native anchors on both package pages; declaration and package
bookmarks, Back, Forward and reload; copied case-insensitive bookmarks in a
fresh context; unknown, path-like and wrong-package requests; keyboard
search and selection through the package heading and category with visible
focus; no page overflow; and JavaScript-disabled navigation through
categories of both packages.

## Developer guides and compiled examples (GEOMETRY-DOC-005)

Five task-oriented guides, written in `docs/guides/*.md`, are rendered to
`_site/guides/` and linked from the landing page:

| Guide | Covers |
| --- | --- |
| `geometry-fundamentals-and-contours` | point types, area, length, moments, hulls, defects, approximation, bounding boxes, location and matching |
| `shape-fitting-and-intersections` | rotated rectangles, ellipse and line fitting, enclosing shapes, convex polygon and rotated-rectangle intersections |
| `affine-and-perspective-geometry` | transform values, transforms from correspondences, inversion, Ada point mapping and rotation matrices |
| `delaunay-and-voronoi` | Subdiv2D ownership, readiness, insertion, location, identifier lifetimes, quad-edge navigation, Voronoi facets and scale |
| `compatibility-ownership-and-safety` | release differences, native capabilities versus binding coverage, ownership, errors and native calls that may not return |

Each guide states that the specifications are authoritative and embeds
exactly one complete program from `docs/examples/`, which
`docs/examples/examples.gpr` compiles with `-gnata -gnatwa -Werror` and the
documentation workflow runs. The examples assert only what is portable across
the supported OpenCV releases: areas, vertex sets, mapped points and
tolerances, never a native starting vertex, angle convention or exact
binary32 value where releases differ. They use well-conditioned inputs, so no
native search that may not return is reached. Deferred native operations are
described as unbound, never as callable.

`scripts/render_gnatdoc_guides.py` (adapted from Imgproc DOC-005) renders the
Markdown with the pinned `markdown-it-py` 3.0.0 and `mdurl` 0.1.2 of
`docs/requirements.txt`, installed only in a documentation environment
(`DOC_PYTHON`). Before emitting HTML it rejects raw HTML, images, fenced code
other than `ada`, `sh` and `text`, an `ada` fence that is not byte-identical to
one example, an example that no guide embeds, a wrong title, unapproved guide
sources and invalid heading hierarchies. Links must be local guide headings,
other guides, `https` pages on `github.com` or `zackboll.github.io` (no
credentials, ports or queries), or `api:Name` / `api:Name/N` (overload N in
source order). API links resolve to the verified native anchor of that
declaration in either package page, taken from the API browser's entries; a
name declared in both packages would be rejected as ambiguous. Every page
also lists its native API entry points and links to its Markdown source.

`validate_docs.py` reconstructs every guide and the guide stylesheet and
compares bytes, allows the guides the same project websites as the landing
page and requires the landing page to link every guide.
`scripts/test_gnatdoc_guides.py` rejects wrong-but-existing API anchors and
guide links, missing headings, titles, overloads and declarations, changed
code and text, scripts, a tampered stylesheet, extra and missing pages,
unapproved sources, fences and link targets, raw HTML, ambiguous names, and
checks idempotent regeneration and that overloads and child-package links
resolve to distinct, correct pages. `scripts/test_gnatdoc_guides_browser.cjs`
(optional Playwright and Chrome) visits every guide from the landing page at
1280 and 390 pixels, light and dark, with and without JavaScript, follows a
sample of API anchors, including every link labelled as an overload, and
every cross-guide link, and checks the current-page marker, focus, the skip
link and overflow.

```sh
alr exec -- gprbuild -P docs/examples/examples.gpr
for example in contours_and_moments fitting_and_intersections \
    affine_and_perspective delaunay_and_voronoi compatibility_and_safety; do
  "obj/docs-examples/$example"
done
```

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
workflow. It installs the guide renderer into a documentation-only virtual
environment and runs every Python step with it. Pull-request runs have only
`contents: read`: they test the tooling, generate and validate the site and
guides, repeat the validator, coverage, navigation and guide mutations on the
generated site, regenerate to prove byte-identical output and re-run every
enhancement to prove idempotence, compile and run the landing-page and guide
examples, and upload the site and `gnatdoc.log` as review artifacts. They
never configure or deploy Pages.

Only `refs/heads/main` runs upload a Pages artifact. A separate job that
depends on the successful build deploys it with `pages: write`,
`id-token: write` and the `github-pages` environment. Superseded runs are
cancelled. Manual runs on other branches validate but cannot publish. No PAT
or `gh-pages` branch is used. On 2026-10-13 the repository already had Pages
configured with **Source: GitHub Actions** and a `github-pages` environment
whose deployment branch policy allows only `main`; no deployment had been
made, and the site URL returned 404. The first publication followed the merge
of GEOMETRY-DOC-001 (PR #27, merge commit `2240b06`) on 2026-10-14: its `main`
run deployed, and the site URL then returned 200. Later phases are published
only when they reach `main`.

## Comment convention

Use adjacent **leading** `--` comments: GNATdoc runs with `--style leading`,
and a blank line between a comment and its declaration detaches the comment.
A comment placed after a declaration documents the *next* declaration, so
existing trailing comments must be moved when their declaration is
documented. Use `@param`, `@return` and `@exception` with names matching the
actual declaration; tag text may continue on the following comment lines.
Verified on GNATdoc 26.0.0 with a scratch specification during DOC-002A:
enumeration literals are documented in the type's leading block with `@enum`,
record components, including discriminants and variant components, with
`@field`, and exceptions as `@exception OpenCV_Error`, because a dotted name
such as `OpenCV.OpenCV_Error` is split at the dot. A pair of `*` or `**`
becomes emphasis (`2**24 .. 2**25` renders as bold "24 .. 2"), so formulas
go in backtick code spans, which render verbatim; backslash escapes are not
supported. Lines starting with `- ` or `* ` form bullet lists and a bare `--`
line separates paragraphs. Because `Post` aspects are not rendered, a
function with a postcondition states its guarantee in its `@return` text.
Do not change declarations or behavior to improve generated output.

Describe purpose, parameter ranges and validation, result representation and
bounds, ownership, exceptions and meaningful numerical or OpenCV-version
limitations, from the specification, implementation, tests and reviewed
source research rather than from the C++ name. A zero warning count is not
proof of accuracy.

## Testing the documentation tooling

```sh
export DOC_PYTHON=$PWD/.doc-tools/markdown/bin/python
sh scripts/generate_docs.sh
"$DOC_PYTHON" -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/check_doc_coverage.py --report docs/gnatdoc-coverage-baseline.txt _site
python3 scripts/check_comment_only.py 517c804   # committed documentation changes
alr exec -- gnatformat --check -P opencv_geometry.gpr src/opencv-geometry.ads \
  src/opencv-geometry-subdiv2d.ads
alr exec -- gnatformat --check -P docs/example.gpr docs/example.adb
alr exec -- gnatformat --check -P docs/examples/examples.gpr
alr exec -- gprbuild -P docs/example.gpr && obj/docs-example/example
git diff --check
```

`check_comment_only.py` accepts changes only to `src/` comments, `docs/`,
`README.md`, `.gitignore` and files added since its base revision. Its base
must therefore predate the documentation tooling being changed: `517c804`,
the `main` commit before this campaign, qualifies every campaign phase. With
`origin/main` as the base, edits to already merged documentation tooling
(the scripts and the documentation workflow) are reported as production
changes and must be reviewed by hand.

The tests that need a generated site, or the guide renderer, skip without
them. Apart from the guide renderer, whose two pinned packages are installed
only in the documentation environment, the documentation tools use only the
Python standard library. None of them is a dependency of the library or the
`tests` crate.
