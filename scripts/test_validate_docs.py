#!/usr/bin/env python3
"""Mutation tests for the generated-site validator.

The synthetic fixture reproduces the pinned GNATdoc 26.0.0 serialization of a
parent package and a child package, so every rule runs without GNATdoc. When
a generated `_site` exists, the same rejections are also exercised on a copy
of it. Adapted from opencv_imgproc_ada IMGPROC-DOC-001.
"""

import shutil
import tempfile
import textwrap
import unittest
from pathlib import Path

from validate_docs import DocumentationError, validate, without_aspects

ROOT = Path(__file__).resolve().parent.parent
PARENT_PAGE = "a" * 64 + ".html"
CHILD_PAGE = "b" * 64 + ".html"

PARENT_SPEC = textwrap.dedent(
    """\
    package OpenCV.Demo is

       type Mode is (Fast, Exact);

       --  Runs the demonstration.
       procedure Run (Value : Integer);
       procedure Run (Value : Integer; Selected : Mode);

       function Count (Limit : Natural) return Natural
       with Post => Count'Result <= Limit;

       Limit : constant := 3;

    end OpenCV.Demo;
    """
)

CHILD_SPEC = textwrap.dedent(
    """\
    private with Ada.Finalization;

    --  Child description. Objects must not be shared between tasks.

    package OpenCV.Demo.Child is

       type Object is limited private;

       procedure Reset (Item : in out Object);

    private

       type Object is new Ada.Finalization.Limited_Controlled with record
          Handle : Integer := 0;
       end record;

       overriding
       procedure Finalize (Item : in out Object);

    end OpenCV.Demo.Child;
    """
)

INTERNAL = "package OpenCV.Demo.Internal is\nend OpenCV.Demo.Internal;\n"

INDEX = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=main><div class=side-navigation><ul class=tab-bar>"
    "<li class=tab><a href=#compilation-units>Compilation Units</a>"
    "<li class=tab><a href=#tagged-types>Tagged Types</a></ul>"
    "<div class=content-column><h2 id=compilation-units>Compilation Units</h2>"
    f"<ul><li><a href={PARENT_PAGE} target=document-content>OpenCV.Demo</a>"
    f"<li><a href={CHILD_PAGE} target=document-content>OpenCV.Demo.Child</a></ul>"
    "<h2 id=tagged-types>Tagged types</h2><ul></ul></div></div>"
    "<div class=document-content><iframe name=document-content></iframe></div>"
)


def section(anchor, name, code, text=""):
    return (
        f"<h4 id={anchor}>{name}</h4><pre class=ada-code-snippet><code>"
        f"{code}\n</code></pre>{text}"
    )


PARENT = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=content><h1>OpenCV.Demo</h1><h2>Entities</h2>"
    "<h3>Simple Types</h3><ul><li><a href=#t1>Mode</a></ul>"
    "<h3>Constants</h3><ul><li><a href=#c1>Limit</a></ul>"
    "<h3>Subprograms</h3><ul><li><a href=#s1>Count</a><li><a href=#s2>Run</a>"
    "<li><a href=#s3>Run</a></ul><h2>Description</h2>"
    + section("t1", "Mode", "type Mode is (Fast, Exact)")
    + section("c1", "Limit", "Limit : constant := 3;")
    + section("s1", "Count", "function Count (Limit : Natural) return Natural")
    + section("s2", "Run", "procedure Run (Value : Integer)",
              "<p>Runs the demonstration.")
    + section("s3", "Run", "procedure Run\n  (Value : Integer; Selected : Mode)")
)

CHILD = (
    "<!DOCTYPE html>\n<html class=main>\n<link rel=stylesheet href=gnatdoc.css>"
    "<body class=content><h1>OpenCV.Demo.Child</h1><h2>Entities</h2>"
    "<h3>Simple Types</h3><ul><li><a href=#u1>Object</a></ul>"
    "<h3>Subprograms</h3><ul><li><a href=#u2>Reset</a></ul>"
    "<h2>Description</h2><p>Child description. Objects must not be shared "
    "between tasks."
    + section("u1", "Object", "type Object is limited private;")
    + section("u2", "Reset", "procedure Reset (Item : in out Object)")
)

LANDING = (
    '<!doctype html>\n<html lang="en">\n<title>Demo</title>\n<body>\n'
    '<p><a href="api/index.html">API</a>\n'
    '<p><a href="https://github.com/zackboll/opencv_geometry_ada">Source</a>\n'
)

FIXTURE_OPTIONS = {
    "declarations": {"OpenCV.Demo": ("Mode", "Run", "Count", "Limit"),
                     "OpenCV.Demo.Child": ("Object", "Reset")},
    "rendered": {("OpenCV.Demo", "procedure Run (Value : Integer)"):
                 ("Runs the demonstration.",)},
    "descriptions": {"OpenCV.Demo.Child": ("must not be shared between tasks",)},
}


class AspectTest(unittest.TestCase):
    def test_postcondition_is_removed_from_the_profile(self):
        self.assertEqual(
            without_aspects("function F (X : T) return T with Post => "
                            "F'Result = X;"),
            "function F (X : T) return T;",
        )

    def test_with_inside_parentheses_is_not_an_aspect(self):
        self.assertEqual(
            without_aspects("procedure P (X : T := (A with B)) with Pre => X;"),
            "procedure P (X : T := (A with B));",
        )

    def test_profile_without_aspects_is_unchanged(self):
        self.assertEqual(without_aspects("function F return T;"),
                         "function F return T;")


class SyntheticSiteTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.root = base / "repo"
        (self.root / "src/internal").mkdir(parents=True)
        (self.root / "src/opencv-demo.ads").write_text(PARENT_SPEC, encoding="utf-8")
        (self.root / "src/opencv-demo-child.ads").write_text(CHILD_SPEC,
                                                             encoding="utf-8")
        (self.root / "src/internal/opencv-demo-internal.ads").write_text(
            INTERNAL, encoding="utf-8"
        )
        self.site = base / "_site"
        (self.site / "api").mkdir(parents=True)
        (self.site / "index.html").write_text(LANDING, encoding="utf-8")
        (self.site / "api/index.html").write_text(INDEX, encoding="utf-8")
        (self.site / "api/gnatdoc.css").write_text("body{}\n", encoding="utf-8")
        (self.site / "api" / PARENT_PAGE).write_text(PARENT, encoding="utf-8")
        (self.site / "api" / CHILD_PAGE).write_text(CHILD, encoding="utf-8")

    def tearDown(self):
        self.temporary.cleanup()

    def validate(self):
        return validate(self.site, self.root, **FIXTURE_OPTIONS)

    def rewrite(self, relative, old, new):
        path = self.site / relative
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def assertRejected(self, fragment):
        with self.assertRaises(DocumentationError) as caught:
            self.validate()
        self.assertIn(fragment, str(caught.exception))

    def test_native_fixture_is_accepted(self):
        summary = self.validate()
        self.assertEqual(summary["packages"], 2)
        self.assertEqual(summary["pages"], 4)
        self.assertEqual(summary["sections"], 7)
        self.assertEqual(summary["subprograms"], 4)

    def test_missing_stylesheet_is_rejected(self):
        (self.site / "api/gnatdoc.css").unlink()
        self.assertRejected("missing/empty: api/gnatdoc.css")

    def test_broken_fragment_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<a href=#s1>", "<a href=#missing>")
        self.assertRejected("missing anchor")

    def test_fragment_into_the_other_package_page_is_checked(self):
        self.rewrite("api/" + PARENT_PAGE, "<a href=#s1>",
                     f"<a href={CHILD_PAGE}#s1>")
        self.assertRejected("missing anchor")

    def test_duplicate_id_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<h4 id=s3>", "<h4 id=s2>")
        self.assertRejected("duplicate id")

    def test_script_is_rejected(self):
        self.rewrite("api/" + CHILD_PAGE, "<h2>Entities</h2>",
                     "<script>alert(1)</script><h2>Entities</h2>")
        self.assertRejected("unapproved active content")

    def test_event_handler_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<h1>", "<h1 onclick=go()>")
        self.assertRejected("unapproved active content")

    def test_javascript_url_is_rejected(self):
        self.rewrite("index.html", 'href="api/index.html"',
                     'href="javascript:alert(1)"')
        self.assertRejected("unapproved link")

    def test_root_absolute_link_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "href=gnatdoc.css", "href=/api/gnatdoc.css")
        self.assertRejected("non-relative local link")

    def test_path_traversal_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "href=gnatdoc.css",
                     "href=../../repo/src/opencv-demo.ads")
        self.assertRejected("broken link")

    def test_external_link_in_api_page_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<a href=#s1>",
                     "<a href=https://example.com/>")
        self.assertRejected("unapproved link")

    def test_unapproved_landing_destination_is_rejected(self):
        self.rewrite("index.html", "https://github.com/zackboll/opencv_geometry_ada",
                     "https://github.com/zackboll/opencv_geometry_ada.evil.example")
        self.assertRejected("unapproved link")

    def test_landing_must_link_to_api_reference(self):
        self.rewrite("index.html", 'href="api/index.html"', 'href="#top"')
        self.assertRejected("landing page does not link to api/index.html")

    def test_internal_package_page_is_rejected(self):
        internal = "c" * 64 + ".html"
        (self.site / "api" / internal).write_text(
            PARENT.replace("<h1>OpenCV.Demo</h1>", "<h1>OpenCV.Demo.Internal</h1>"),
            encoding="utf-8",
        )
        self.assertRejected("unexpected package page: OpenCV.Demo.Internal")

    def test_duplicate_package_page_is_rejected(self):
        (self.site / "api" / ("d" * 64 + ".html")).write_text(CHILD,
                                                              encoding="utf-8")
        self.assertRejected("duplicate package page: OpenCV.Demo.Child")

    def test_stray_file_is_rejected(self):
        (self.site / "api/notes.txt").write_text("x", encoding="utf-8")
        self.assertRejected("unexpected file: api/notes.txt")

    def test_missing_child_package_page_is_rejected(self):
        (self.site / "api" / CHILD_PAGE).unlink()
        self.assertRejected("public package missing: OpenCV.Demo.Child")

    def test_index_redirected_to_existing_file_is_rejected(self):
        self.rewrite("api/index.html", f"href={PARENT_PAGE}", "href=gnatdoc.css")
        self.assertRejected("native API index does not match")

    def test_index_swapped_package_targets_are_rejected(self):
        self.rewrite("api/index.html", f"href={PARENT_PAGE}", "href=SWAP")
        self.rewrite("api/index.html", f"href={CHILD_PAGE}", f"href={PARENT_PAGE}")
        self.rewrite("api/index.html", "href=SWAP", f"href={CHILD_PAGE}")
        self.assertRejected("native API index does not match")

    def test_index_target_change_is_rejected(self):
        self.rewrite("api/index.html", "target=document-content>OpenCV.Demo<",
                     "target=_blank>OpenCV.Demo<")
        self.assertRejected("native API index does not match")

    def test_removed_overload_section_is_rejected(self):
        self.rewrite(
            "api/" + PARENT_PAGE,
            section("s3", "Run", "procedure Run\n  (Value : Integer; Selected : Mode)"),
            "",
        )
        self.rewrite("api/" + PARENT_PAGE, "<li><a href=#s3>Run</a>", "")
        self.assertRejected("declaration sections differ from the public source")

    def test_changed_overload_profile_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "procedure Run (Value : Integer)",
                     "procedure Run (Value : Long_Integer)")
        self.assertRejected("declaration sections differ from the public source")

    def test_rendered_aspect_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE,
                     "function Count (Limit : Natural) return Natural",
                     "function Count (Limit : Natural) return Natural\n"
                     "with Post => Count'Result &lt;= Limit")
        self.assertRejected("declaration sections differ from the public source")

    def test_declaration_moved_to_the_other_package_is_rejected(self):
        moved = section("u2", "Reset", "procedure Reset (Item : in out Object)")
        self.rewrite("api/" + CHILD_PAGE, moved, "")
        self.rewrite("api/" + CHILD_PAGE, "<li><a href=#u2>Reset</a>", "")
        self.rewrite("api/" + PARENT_PAGE, "<h2>Description</h2>",
                     "<h2>Description</h2>" + moved)
        self.assertRejected("OpenCV.Demo.Child: declaration sections differ")

    def test_published_private_declaration_is_rejected(self):
        self.rewrite(
            "api/" + CHILD_PAGE, "<h2>Description</h2>",
            "<h2>Description</h2>"
            + section("p1", "Finalize",
                      "overriding procedure Finalize (Item : in out Object)"),
        )
        self.assertRejected("declaration sections differ from the public source")

    def test_comment_rendered_in_another_overload_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<p>Runs the demonstration.", "")
        self.rewrite(
            "api/" + PARENT_PAGE,
            "procedure Run\n  (Value : Integer; Selected : Mode)\n</code></pre>",
            "procedure Run\n  (Value : Integer; Selected : Mode)\n</code></pre>"
            "<p>Runs the demonstration.",
        )
        self.assertRejected("lacks rendered text: Runs the demonstration.")

    def test_missing_package_description_text_is_rejected(self):
        self.rewrite("api/" + CHILD_PAGE, " Objects must not be shared between tasks.",
                     "")
        self.assertRejected("package description lacks rendered text")

    def test_description_text_only_in_a_declaration_is_rejected(self):
        self.rewrite("api/" + CHILD_PAGE, " Objects must not be shared between tasks.",
                     "")
        self.rewrite("api/" + CHILD_PAGE,
                     "procedure Reset (Item : in out Object)\n</code></pre>",
                     "procedure Reset (Item : in out Object)\n</code></pre>"
                     "<p>Objects must not be shared between tasks.")
        self.assertRejected("package description lacks rendered text")

    def test_unmatched_heading_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<h2>Description</h2>",
                     "<h2>Description</h2><h4 id=x1>Loose</h4>")
        self.assertRejected("unrecognized declaration heading")

    def test_machine_local_path_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<p>Runs the demonstration.",
                     "<p>Runs the demonstration. /home/builder/src")
        self.assertRejected("internal unit or machine-local path")

    def test_internal_unit_name_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<p>Runs the demonstration.",
                     "<p>Runs the demonstration. OpenCV.Geometry.Internal.C_API")
        self.assertRejected("internal unit or machine-local path")

    def test_shim_symbol_is_rejected(self):
        self.rewrite("api/" + PARENT_PAGE, "<p>Runs the demonstration.",
                     "<p>Runs the demonstration. opencv_geometry_contour_area (")
        self.assertRejected("internal unit or machine-local path")

    def test_missing_representative_declaration_is_rejected(self):
        with self.assertRaises(DocumentationError) as caught:
            validate(self.site, self.root,
                     declarations={"OpenCV.Demo.Child": ("Object", "Absent")},
                     rendered={}, descriptions={})
        self.assertIn("OpenCV.Demo.Child: missing representative declaration: Absent",
                      str(caught.exception))

    def test_representative_declaration_in_wrong_package_is_rejected(self):
        with self.assertRaises(DocumentationError) as caught:
            validate(self.site, self.root,
                     declarations={"OpenCV.Demo": ("Reset",)},
                     rendered={}, descriptions={})
        self.assertIn("OpenCV.Demo: missing representative declaration: Reset",
                      str(caught.exception))

    def test_unknown_representative_package_is_rejected(self):
        with self.assertRaises(DocumentationError) as caught:
            validate(self.site, self.root,
                     declarations={"OpenCV.Absent": ("Run",)},
                     rendered={}, descriptions={})
        self.assertIn("unknown package: OpenCV.Absent", str(caught.exception))

    def test_landing_example_must_match_compiled_example(self):
        (self.root / "docs").mkdir()
        (self.root / "docs/example.adb").write_text(
            "procedure Example is\nbegin\n   null;\nend Example;\n", encoding="utf-8"
        )
        self.assertRejected("landing page example differs from docs/example.adb")
        self.rewrite(
            "index.html", "<body>\n",
            "<body>\n<pre>procedure Example is\nbegin\n   null;\nend Example;</pre>\n",
        )
        self.validate()

    def test_validation_does_not_modify_the_site(self):
        before = {p: p.read_bytes() for p in self.site.rglob("*") if p.is_file()}
        self.validate()
        after = {p: p.read_bytes() for p in self.site.rglob("*") if p.is_file()}
        self.assertEqual(before, after)


@unittest.skipUnless((ROOT / "_site/api/index.html").is_file(),
                     "generated site not present; run scripts/generate_docs.sh")
class GeneratedSiteTest(unittest.TestCase):
    """Mutations of a copy of the real generated site must be rejected."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary.name) / "_site"
        shutil.copytree(ROOT / "_site", self.site)
        self.pages = {}
        for path in (self.site / "api").glob("*.html"):
            text = path.read_text(encoding="utf-8")
            for name in ("OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"):
                if f"<h1>{name}</h1>" in text:
                    self.pages[name] = path
        self.assertEqual(len(self.pages), 2)

    def tearDown(self):
        self.temporary.cleanup()

    def assertRejected(self, fragment):
        with self.assertRaises(DocumentationError) as caught:
            validate(self.site, ROOT)
        self.assertIn(fragment, str(caught.exception))

    def mutate(self, package, old, new, count=1):
        page = self.pages[package]
        text = page.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        page.write_text(text.replace(old, new, count), encoding="utf-8")

    def remove_section(self, package, name, occurrence=0):
        page = self.pages[package]
        text = page.read_text(encoding="utf-8")
        start = -1
        for _ in range(occurrence + 1):
            start = text.index(f">{name}</h4>", start + 1)
        begin = text.rindex("<h4 ", 0, start)
        end = text.index("<h4 ", start)
        page.write_text(text[:begin] + text[end:], encoding="utf-8")
        return text[begin:end]

    def test_generated_site_is_accepted(self):
        summary = validate(self.site, ROOT)
        self.assertEqual(summary["packages"], 2)
        self.assertEqual(summary["pages"], 4)

    def test_missing_stylesheet_is_rejected(self):
        (self.site / "api/gnatdoc.css").unlink()
        self.assertRejected("missing/empty: api/gnatdoc.css")

    def test_internal_package_publication_is_rejected(self):
        leak = self.site / "api" / ("c" * 64 + ".html")
        leak.write_text(
            self.pages["OpenCV.Geometry"].read_text(encoding="utf-8").replace(
                "<h1>OpenCV.Geometry</h1>",
                "<h1>OpenCV.Geometry.Internal.C_API</h1>",
            ),
            encoding="utf-8",
        )
        self.assertRejected("unexpected package page")

    def test_missing_subdivision_page_is_rejected(self):
        self.pages["OpenCV.Geometry.Subdiv2D"].unlink()
        self.assertRejected("public package missing: OpenCV.Geometry.Subdiv2D")

    def test_broken_declaration_anchor_is_rejected(self):
        self.mutate("OpenCV.Geometry", ">Convex_Hull</a>",
                    ">Convex_Hull</a><a href=#0>x</a>")
        self.assertRejected("missing anchor")

    def test_removed_convex_hull_overload_is_rejected(self):
        self.remove_section("OpenCV.Geometry", "Convex_Hull", occurrence=1)
        self.assertRejected("declaration sections differ from the public source")

    def test_removed_voronoi_facets_overload_is_rejected(self):
        self.remove_section("OpenCV.Geometry.Subdiv2D", "Voronoi_Facets")
        self.assertRejected("OpenCV.Geometry.Subdiv2D: declaration sections differ")

    def test_section_moved_between_packages_is_rejected(self):
        moved = self.remove_section("OpenCV.Geometry.Subdiv2D", "Is_Ready")
        self.mutate("OpenCV.Geometry", "<h2>Description</h2>",
                    "<h2>Description</h2>" + moved)
        self.assertRejected("declaration sections differ from the public source")

    def test_modified_native_declaration_text_is_rejected(self):
        self.mutate("OpenCV.Geometry",
                    "function Intersect_Rotated_Rectangles\n"
                    "  (Left, Right : OpenCV.Rotated_Rect)",
                    "function Intersect_Rotated_Rectangles\n"
                    "  (Left : OpenCV.Rotated_Rect)")
        self.assertRejected("declaration sections differ from the public source")

    def test_removed_liveness_warning_is_rejected(self):
        self.mutate("OpenCV.Geometry.Subdiv2D",
                    "The Ada binding cannot interrupt or recover from a native "
                    "call that does not return.", "")
        self.assertRejected("lacks rendered text: cannot interrupt or recover")

    def test_removed_task_safety_statement_is_rejected(self):
        self.mutate("OpenCV.Geometry.Subdiv2D",
                    "a Subdivision must not be used by more than one task at a time",
                    "a Subdivision may be shared")
        self.assertRejected("package description lacks rendered text")

    def test_injected_script_is_rejected(self):
        self.mutate("OpenCV.Geometry", "<h1>", "<script src=x.js></script><h1>")
        self.assertRejected("unapproved active content")

    def test_changed_landing_example_is_rejected(self):
        landing = self.site / "index.html"
        text = landing.read_text(encoding="utf-8")
        self.assertIn("Hull'Length = 4", text)
        landing.write_text(text.replace("Hull'Length = 4", "Hull'Length = 5"),
                           encoding="utf-8")
        self.assertRejected("landing page example differs from docs/example.adb")


if __name__ == "__main__":
    unittest.main()
