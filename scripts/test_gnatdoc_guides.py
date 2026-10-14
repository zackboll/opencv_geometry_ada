#!/usr/bin/env python3
"""Negative-first qualification of authoritative guide reconstruction.

Adapted from opencv_imgproc_ada. Needs the pinned Markdown renderer
(docs/requirements.txt) and a generated `_site`; run with the documentation
Python environment.
"""
import contextlib
import io
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent

try:
    import markdown_it  # noqa: F401
    RENDERER = True
except ImportError:
    RENDERER = False


@unittest.skipUnless(RENDERER and (ROOT / "_site/api/gnatdoc-navigation.js").is_file(),
                     "needs the pinned renderer and a generated site")
class Guides(unittest.TestCase):
    def setUp(self):
        import render_gnatdoc_guides as guides
        self.guides = guides
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.site = Path(self.tmp.name) / "site"
        shutil.copytree(ROOT / "_site", self.site)
        shutil.rmtree(self.site / "guides", ignore_errors=True)
        with contextlib.redirect_stdout(io.StringIO()):
            guides.generate(ROOT, self.site)
        self.page = self.site / "guides/shape-fitting-and-intersections.html"
        self.repo = Path(self.tmp.name) / "repo"
        for part in ("src", "docs", "scripts"):
            shutil.copytree(ROOT / part, self.repo / part,
                            ignore=shutil.ignore_patterns("__pycache__"))

    def rejected(self, root=None):
        with self.assertRaises(ValueError):
            self.guides.validate(root or ROOT, self.site)

    def mutation(self, old, new):
        text = self.page.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        self.page.write_text(text.replace(old, new, 1), encoding="utf-8")
        self.rejected()

    def source_mutation(self, name, old, new):
        path = self.repo / "docs/guides" / name
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")
        with self.assertRaises(ValueError):
            self.guides.expected(self.repo, self.site)

    def test_generated_guides_validate(self):
        self.assertEqual(self.guides.validate(ROOT, self.site), 5)

    def test_regeneration_is_idempotent(self):
        before = {p.name: p.read_bytes() for p in (self.site / "guides").iterdir()}
        with contextlib.redirect_stdout(io.StringIO()):
            self.guides.generate(ROOT, self.site)
        after = {p.name: p.read_bytes() for p in (self.site / "guides").iterdir()}
        self.assertEqual(before, after)

    def test_missing_and_extra_pages_are_rejected(self):
        shutil.copy(self.page, self.page.with_name("duplicate.html"))
        self.rejected()
        self.page.with_name("duplicate.html").unlink()
        self.page.unlink()
        self.rejected()

    def test_wrong_but_existing_api_anchor_is_rejected(self):
        api = self.guides.api_destinations(self.site, ROOT)
        self.mutation(api[("Intersect_Convex_Polygons", 2)],
                      api[("Intersect_Convex_Polygons", 1)])

    def test_overloads_resolve_to_distinct_declarations(self):
        api = self.guides.api_destinations(self.site, ROOT)
        for name in ("Insert", "Voronoi_Facets", "Transform_Point", "Convexity_Defects"):
            with self.subTest(name=name):
                self.assertNotEqual(api[(name, 1)], api[(name, 2)])

    def test_child_package_links_reach_the_child_page(self):
        api = self.guides.api_destinations(self.site, ROOT)
        self.assertNotEqual(api[("Subdivision", 1)].split("#")[0],
                            api[("Contour", 1)].split("#")[0])

    def test_name_declared_in_both_packages_is_ambiguous(self):
        import enhance_gnatdoc_navigation
        item = {"name": "Shared", "overload": None}
        packages = [
            ("OpenCV.Geometry", "a.html", [("Group", "group", [
                dict(item, href="a.html#1"),
                {"name": "Only_Parent", "overload": None, "href": "a.html#2"}])]),
            ("OpenCV.Geometry.Subdiv2D", "b.html", [("Group", "group", [
                dict(item, href="b.html#1")])]),
        ]
        with mock.patch.object(enhance_gnatdoc_navigation, "entries",
                               return_value=packages):
            api = self.guides.api_destinations(self.site, ROOT)
        self.assertEqual(api, {("Only_Parent", 1): "../api/a.html#2"})
        with self.assertRaises(ValueError):
            self.guides.resolve_link("api:Shared", "delaunay-and-voronoi", {}, api)

    def test_wrong_but_existing_guide_link_is_rejected(self):
        self.mutation('href="compatibility-ownership-and-safety.html"',
                      'href="delaunay-and-voronoi.html"')

    def test_missing_guide_heading_is_rejected(self):
        self.source_mutation("compatibility-ownership-and-safety.md",
                             "(delaunay-and-voronoi.md#identifiers-and-their-lifetimes)",
                             "(delaunay-and-voronoi.md#no-such-heading)")

    def test_wrong_title_is_rejected(self):
        self.source_mutation("delaunay-and-voronoi.md",
                             "# Delaunay and Voronoi with Subdiv2D",
                             "# Delaunay and Voronoi")

    def test_code_and_text_mutations_are_rejected(self):
        self.mutation("Ellipse.Size.Width in 19.0 .. 21.0",
                      "Ellipse.Size.Width in 19.0 .. 22.0")
        with contextlib.redirect_stdout(io.StringIO()):
            self.guides.generate(ROOT, self.site)
        self.mutation("need not enclose the points", "always encloses the points")

    def test_script_and_handler_are_rejected(self):
        self.mutation("</main>", "<script>alert(1)</script></main>")

    def test_tampered_stylesheet_is_rejected(self):
        css = self.site / "guides/gnatdoc-guides.css"
        css.write_text(css.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        self.rejected()

    def test_unknown_api_declaration_is_rejected(self):
        self.source_mutation("shape-fitting-and-intersections.md",
                             "(api:Box_Points)", "(api:Box_Point)")

    def test_unknown_overload_is_rejected(self):
        self.source_mutation("shape-fitting-and-intersections.md",
                             "(api:Intersect_Convex_Polygons/2)",
                             "(api:Intersect_Convex_Polygons/3)")

    def test_ada_code_that_is_not_a_compiled_example_is_rejected(self):
        self.source_mutation("shape-fitting-and-intersections.md",
                             "Ellipse.Size.Width in 19.0 .. 21.0",
                             "Ellipse.Size.Width in 19.0 .. 22.0")

    def test_unsupported_fence_language_is_rejected(self):
        self.source_mutation("affine-and-perspective-geometry.md", "```ada", "```c")

    def test_example_missing_from_guides_is_rejected(self):
        (self.repo / "docs/examples/unused.adb").write_text(
            "procedure Unused is\nbegin\n   null;\nend Unused;\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.guides.expected(self.repo, self.site)

    def test_unapproved_link_targets_are_rejected(self):
        for link in ("https://example.com/", "javascript:alert(1)",
                     "http://github.com/zackboll", "https://github.com.example/",
                     "https://user@github.com/", "https://github.com:8443/",
                     "api:Navigate/0", "../README.md", "missing-guide.md",
                     "delaunay-and-voronoi.md?x=1"):
            with self.subTest(link=link):
                self.source_mutation(
                    "delaunay-and-voronoi.md",
                    "[Navigate](api:Navigate)", f"[Navigate]({link})")
                shutil.copy(ROOT / "docs/guides/delaunay-and-voronoi.md",
                            self.repo / "docs/guides/delaunay-and-voronoi.md")

    def test_unapproved_guide_source_is_rejected(self):
        (self.repo / "docs/guides/extra.md").write_text("# Extra\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.guides.expected(self.repo, self.site)

    def test_raw_html_is_rejected(self):
        self.source_mutation("delaunay-and-voronoi.md", "## Voronoi diagrams",
                             "## Voronoi diagrams\n\n<div>raw</div>")


if __name__ == "__main__":
    unittest.main()
