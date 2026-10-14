#!/usr/bin/env python3
"""Validate generated Geometry GNATdoc output before review or publication.

Expectations come from the public specifications in `src/*.ads`, never from
the generated output itself: `src/internal` is not public. Geometry publishes
two packages, `OpenCV.Geometry` and `OpenCV.Geometry.Subdiv2D`. The site must
contain exactly the landing page, the native API index and stylesheet, and one
native page per public package. GNATdoc 26.0.0 names package pages with
64-hex hashes, so pages are identified by their actual `<h1>` heading; no
filename is computed or assumed.

Every visible-part declaration of each package must have exactly one native
section on that package's page, and each subprogram section must reproduce
its complete source profile, so overloads cannot stand in for one another and
a declaration cannot move to the other package. Private-part declarations
must not appear.

Links must be relative and resolve inside the site, including fragments. Only
the landing page may link to a small set of project websites, and its example
must be exactly the compiled `docs/example.adb`. Scripts, event handlers,
duplicate IDs, internal unit names and machine-local paths are rejected.
External URLs are not fetched. The site is never modified.

Adapted from the opencv_imgproc_ada IMGPROC-DOC-001 validator.
"""

import collections
import html
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

from compare_gnatdoc_warnings import (
    WarningComparisonError,
    _normalize,
    code_tokens,
    declaration_index,
)

ROOT = Path(__file__).resolve().parent.parent
NATIVE_PAGE = re.compile(r"[0-9a-f]{64}\.html")
PACKAGE_RE = re.compile(r"^\s*package\s+([A-Za-z][\w.]*)\s+is\b", re.I)
SECTION_RE = re.compile(
    r"<h4 id=([^ >]+)>([^<]+)</h4><pre class=ada-code-snippet><code>(.*?)</code></pre>"
    r"(.*?)(?=<h4 |\Z)",
    re.S,
)
DESCRIPTION_RE = re.compile(r"<h2>Description</h2>(.*?)(?=<h4 |\Z)", re.S)
# The exact GNATdoc 26.0.0 index serialization, with no tagged types (the
# Subdivision completion is tagged only in the private part). Any other
# generator layout fails closed instead of being partially trusted.
INDEX_START = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=main><div class=side-navigation><ul class=tab-bar>"
    "<li class=tab><a href=#compilation-units>Compilation Units</a>"
    "<li class=tab><a href=#tagged-types>Tagged Types</a></ul>"
    "<div class=content-column><h2 id=compilation-units>Compilation Units</h2><ul>"
)
INDEX_END = (
    "</ul><h2 id=tagged-types>Tagged types</h2><ul></ul></div></div>"
    "<div class=document-content><iframe name=document-content></iframe></div>"
)
LANDING_DESTINATIONS = (
    "https://github.com/zackboll/opencv_geometry_ada",
    "https://github.com/zackboll/opencv_core_ada",
    "https://zackboll.github.io/opencv_core_ada/",
    "https://zackboll.github.io/opencv_imgproc_ada/",
)
ACTIVE_TAGS = {"script", "base", "object", "embed", "applet", "form"}
LEAKS = re.compile(
    r"OpenCV\.Geometry\.Internal|Internal\.C_API|Subdiv2D_Handle"
    r"|Opencv_Geometry_Config|OpenCV_Geometry_Install|OpenCV_Core_Config"
    r"|opencv_geometry_[a-z0-9_]+\s*\("
    r"|/home/|/Users/|/runner/|/workspace/|file://|[A-Za-z]:\\",
    re.I,
)
# Representative public operations of each package; the source comparison
# is the full check.
DECLARATIONS = {
    "OpenCV.Geometry": (
        "Native_Feature", "Is_Natively_Supported", "Contour", "Float32_Point_Array",
        "Contour_Area", "Arc_Length", "Compute_Moments", "Hu_Moments",
        "Convex_Hull", "Convex_Hull_Indices", "Convexity_Defects",
        "Approximate_Curve", "Is_Convex", "Bounding_Rect", "Match_Shapes",
        "Locate_Point", "Signed_Distance_To_Contour", "Minimum_Area_Rectangle",
        "Fit_Ellipse", "Fit_Line_2D", "Box_Points", "Closest_Ellipse_Points",
        "Intersect_Convex_Polygons", "Intersect_Convex_Polygons_Extended_Float32",
        "Intersect_Rotated_Rectangles", "Minimum_Enclosing_Circle",
        "Minimum_Enclosing_Triangle", "Get_Rotation_Matrix_2D",
        "Get_Affine_Transform", "Get_Perspective_Transform",
        "Invert_Affine_Transform", "Transform_Point", "Transform_Points",
    ),
    "OpenCV.Geometry.Subdiv2D": (
        "Subdivision", "Create", "Create_Float32", "Reset", "Reset_Float32",
        "Is_Ready", "Insert", "Locate", "Find_Nearest", "Edge_List",
        "Leading_Edge_List", "Triangle_List", "Navigate", "Rotate", "Origin",
        "Destination", "Vertex_Point", "Voronoi_Facets", "Facet_Points",
    ),
}
# (package, complete signature) -> text that must render inside that
# overload's own section.
RENDERED = {
    ("OpenCV.Geometry",
     "function Contour_Area (Points : Float32_Point_Array; Oriented : Boolean "
     ":= False) return OpenCV.Float64_Value"): (
        "accumulates the cross products of the binary32 coordinates in binary64",),
    ("OpenCV.Geometry",
     "function Intersect_Convex_Polygons_Extended_Float32 (Left, Right : "
     "Float32_Point_Array; Handle_Nested : Boolean := True) return "
     "Convex_Polygon_Intersection"): (
        "It never calls OpenCV's intersectConvexConvex",),
    ("OpenCV.Geometry.Subdiv2D",
     "function Find_Nearest (Object : in out Subdivision; Point : "
     "OpenCV.Float32_Point) return Nearest_Result"): (
        "cannot interrupt or recover from a native call that does not return",),
}
# Package -> text that must render in that package's own description.
PACKAGE_DESCRIPTIONS = {
    "OpenCV.Geometry.Subdiv2D": (
        "a Subdivision must not be used by more than one task at a time",),
}


class DocumentationError(Exception):
    """The generated site does not meet the publication contract."""


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.links = []
        self.ids = []
        self.active = []
        self.text = []
        self.headings = []
        self.preformatted = []
        self._heading = None
        self._pre = None
        self.feed(path.read_text(encoding="utf-8"))
        self.close()

    def handle_starttag(self, tag, attrs):
        if tag in ACTIVE_TAGS:
            self.active.append(f"<{tag}>")
        if tag == "meta" and any(k == "http-equiv" for k, _ in attrs):
            self.active.append("<meta http-equiv>")
        for key, value in attrs:
            if key.startswith("on"):
                self.active.append(f"{key} attribute")
            if key in ("href", "src"):
                self.links.append(value or "")
            if key == "id":
                self.ids.append(value or "")
        if tag == "h1":
            self._heading = []
        if tag == "pre":
            self._pre = []

    def handle_endtag(self, tag):
        if tag == "h1" and self._heading is not None:
            self.headings.append("".join(self._heading))
            self._heading = None
        if tag == "pre" and self._pre is not None:
            self.preformatted.append("".join(self._pre))
            self._pre = None

    def handle_data(self, data):
        self.text.append(data)
        if self._heading is not None:
            self._heading.append(data)
        if self._pre is not None:
            self._pre.append(data)


def _kind(signature):
    word = signature.split(maxsplit=1)[0]
    return word if word in ("function", "procedure", "type", "subtype", "package") else "object"


def _profile(text):
    """Normalized complete declaration text, with comments already removed."""
    return _normalize(text).rstrip(";").strip()


def without_aspects(signature):
    """Return a subprogram declaration without its aspect specification.

    GNATdoc 26.0.0 renders a subprogram profile without the `with Post =>`
    aspects that follow it, so the section is compared with the profile up
    to the first `with` outside parentheses. Comments and string literals
    have already been removed from the signature.
    """
    depth = 0
    for match in re.finditer(r"[()]|\bwith\b", signature):
        if match[0] == "(":
            depth += 1
        elif match[0] == ")":
            depth -= 1
        elif depth == 0:
            return signature[:match.start()].rstrip() + ";"
    return signature


def _text(fragment):
    return " ".join(html.unescape(re.sub(r"<[^>]+>", " ", fragment)).split())


def public_specifications(root):
    """Return {package: Counter of (name, kind, profile)} from src/*.ads.

    Only the visible part is public. Profiles are kept for subprograms only;
    the kind distinguishes types, subtypes and objects.
    """
    packages = {}
    for path in sorted((root / "src").glob("*.ads")):
        lines = path.read_text(encoding="utf-8").splitlines()
        code = [code_tokens(line) for line in lines]
        name = next((m[1] for m in map(PACKAGE_RE.match, code) if m), None)
        if name is None:
            raise DocumentationError(f"no package declaration in {path.name}")
        private = next(
            (number for number, text in enumerate(code, start=1)
             if text.strip().lower() == "private"),
            len(lines) + 1,
        )
        try:
            index = declaration_index(lines)
        except WarningComparisonError as error:
            raise DocumentationError(f"{path.name}: {error}") from error
        declarations = collections.Counter()
        for candidates in index.values():
            for declaration in candidates:
                if declaration["start"] >= private:
                    continue
                if declaration["scope"] != f"{name}.{declaration['name']}":
                    continue
                kind = _kind(declaration["signature"])
                if kind == "package":
                    raise DocumentationError(
                        f"unsupported public nested package: {declaration['name']}")
                profile = (_profile(without_aspects(declaration["signature"]))
                           if kind in ("function", "procedure") else None)
                declarations[(declaration["name"], kind, profile)] += 1
        if name in packages:
            raise DocumentationError(f"duplicate public package: {name}")
        packages[name] = declarations
    if not packages:
        raise DocumentationError("no public specifications found")
    return packages


def native_sections(source):
    """Return (Counter of (name, kind, profile), {signature: text}, errors)."""
    sections = collections.Counter()
    rendered = {}
    errors = []
    matches = list(SECTION_RE.finditer(source))
    if len(matches) != source.count("<h4 "):
        errors.append("unrecognized declaration heading")
    for match in matches:
        name = html.unescape(match[2])
        snippet = html.unescape(re.sub(r"<[^>]+>", "", match[3]))
        stripped = " ".join(snippet.split())
        if re.match(rf"{re.escape(name)}\s*:", stripped):
            kind = "object"
        else:
            kind = _kind(stripped) if stripped else "unknown"
            if not re.match(rf"\w+\s+{re.escape(name)}\b", stripped):
                errors.append(f"section heading does not name its declaration: {name}")
        profile = _profile(stripped) if kind in ("function", "procedure") else None
        sections[(name, kind, profile)] += 1
        if profile is not None:
            rendered.setdefault(profile, []).append(_text(match[4]))
    return sections, rendered, errors


def package_description(source):
    """Return the rendered text of the native package description, or None."""
    found = DESCRIPTION_RE.findall(source)
    return _text(found[0]) if len(found) == 1 else None


def _describe(entries):
    return "; ".join(
        f"{count} x {name} ({kind}{': ' + profile if profile else ''})"
        for (name, kind, profile), count in sorted(entries.items(), key=str)
    )


def _check_links(site, pages, path, page, errors):
    landing = path == site / "index.html"
    for link in page.links:
        url = urlsplit(link)
        if url.scheme or url.netloc:
            approved = landing and url.scheme == "https" and any(
                link == prefix or link.startswith(prefix.rstrip("/") + "/")
                for prefix in LANDING_DESTINATIONS
            )
            if not approved:
                errors.append(f"unapproved link in {path.relative_to(site)}: {link}")
            continue
        if not link or url.path.startswith("/"):
            errors.append(f"non-relative local link in {path.relative_to(site)}: {link}")
            continue
        target = (path.parent / unquote(url.path)).resolve() if url.path else path
        if not target.is_relative_to(site) or not target.is_file():
            errors.append(f"broken link in {path.relative_to(site)}: {link}")
        elif url.fragment:
            if target not in pages or unquote(url.fragment) not in pages[target].ids:
                errors.append(f"missing anchor in {path.relative_to(site)}: {link}")


def validate(site, root=ROOT, declarations=DECLARATIONS, rendered=RENDERED,
             descriptions=PACKAGE_DESCRIPTIONS):
    """Raise DocumentationError listing every violation; return a summary."""
    site = Path(site).resolve()
    root = Path(root).resolve()
    errors = []
    expected = public_specifications(root)
    api = site / "api"
    for required in (site / "index.html", api / "index.html", api / "gnatdoc.css"):
        if not required.is_file() or required.stat().st_size == 0:
            errors.append(f"missing/empty: {required.relative_to(site)}")
    pages = {}
    for path in sorted(site.rglob("*")):
        if path.is_dir():
            continue
        relative = path.relative_to(site).as_posix()
        native = path.parent == api and NATIVE_PAGE.fullmatch(path.name)
        if relative not in ("index.html", "api/index.html", "api/gnatdoc.css") and not native:
            errors.append(f"unexpected file: {relative}")
            continue
        if path.suffix == ".html":
            pages[path.resolve()] = Page(path)
    packages = {}
    for path, page in pages.items():
        if path.parent != api or path.name == "index.html":
            continue
        if len(page.headings) != 1:
            errors.append(f"package page without exactly one h1: {path.name}")
            continue
        name = page.headings[0]
        if name not in expected:
            errors.append(f"unexpected package page: {name}")
        elif name in packages:
            errors.append(f"duplicate package page: {name}")
        else:
            packages[name] = path
    for name in sorted(set(expected) - set(packages)):
        errors.append(f"public package missing: {name}")
    for path, page in pages.items():
        relative = path.relative_to(site)
        for item in page.active:
            errors.append(f"unapproved active content in {relative}: {item}")
        duplicates = [i for i, n in collections.Counter(page.ids).items() if n > 1]
        for identifier in duplicates:
            errors.append(f"duplicate id in {relative}: {identifier}")
        _check_links(site, pages, path, page, errors)
        if LEAKS.search(" ".join(page.text)):
            errors.append(f"internal unit or machine-local path in {relative}")
    landing = pages.get(site / "index.html")
    if landing is not None and "api/index.html" not in landing.links:
        errors.append("landing page does not link to api/index.html")
    example = root / "docs/example.adb"
    if landing is not None and example.is_file():
        source = example.read_text(encoding="utf-8").rstrip("\n")
        if source not in landing.preformatted:
            errors.append("landing page example differs from docs/example.adb")
    index = api / "index.html"
    if index.is_file():
        units = "".join(
            f"<li><a href={packages[name].name} target=document-content>{name}</a>"
            for name in sorted(packages, key=str.lower)
        )
        if index.read_text(encoding="utf-8") != INDEX_START + units + INDEX_END:
            errors.append("native API index does not match the pinned GNATdoc layout")
    sections_total = subprograms = 0
    for name, path in sorted(packages.items()):
        source = path.read_text(encoding="utf-8")
        sections, package_texts, section_errors = native_sections(source)
        errors.extend(f"{name}: {error}" for error in section_errors)
        if sections != expected[name]:
            errors.append(
                f"{name}: declaration sections differ from the public source; "
                f"missing: {_describe(expected[name] - sections) or 'none'}; "
                f"unexpected: {_describe(sections - expected[name]) or 'none'}"
            )
        sections_total += sum(sections.values())
        subprograms += sum(n for (_, kind, _), n in sections.items()
                           if kind in ("function", "procedure"))
        present = {entry[0] for entry in sections}
        for declaration in declarations.get(name, ()):
            if declaration not in present:
                errors.append(f"{name}: missing representative declaration: "
                              f"{declaration}")
        for (package, signature), phrases in rendered.items():
            if package != name:
                continue
            found = package_texts.get(_profile(signature), [])
            if len(found) != 1:
                errors.append(f"{name}: rendered section missing or ambiguous for "
                              f"{signature}")
                continue
            for phrase in phrases:
                if phrase not in found[0]:
                    errors.append(f"{name}: {signature} lacks rendered text: {phrase}")
        description = package_description(source)
        for phrase in descriptions.get(name, ()):
            if description is None or phrase not in description:
                errors.append(f"{name}: package description lacks rendered text: "
                              f"{phrase}")
    for name in sorted(set(declarations) - set(expected)):
        errors.append(f"representative declarations name an unknown package: {name}")
    if errors:
        raise DocumentationError("\n".join(errors))
    return {
        "packages": len(packages),
        "pages": len(pages),
        "sections": sections_total,
        "subprograms": subprograms,
    }


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        raise SystemExit("usage: validate_docs.py SITE_DIRECTORY")
    try:
        summary = validate(Path(argv[0]))
    except DocumentationError as error:
        print(error, file=sys.stderr)
        return 1
    print(
        "Validated {packages} public package(s), {pages} HTML pages and "
        "{sections} declaration sections ({subprograms} subprograms); all "
        "local links and anchors resolve.".format(**summary)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
