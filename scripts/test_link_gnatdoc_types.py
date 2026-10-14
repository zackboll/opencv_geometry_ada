#!/usr/bin/env python3
"""Source-backed type link, theme and highlighting tests on a native fixture.

Adapted from opencv_imgproc_ada; the fixture adds a child package whose
snippets link to its parent's page, as OpenCV.Geometry.Subdiv2D does.
"""

import contextlib
import hashlib
import io
import json
import tempfile
import textwrap
import unittest
from pathlib import Path

from highlight_gnatdoc_ada import highlight, strip_highlighting
from install_gnatdoc_theme import NATIVE, check_theme, install
from link_gnatdoc_types import (CORE_DESTINATIONS, LINK, CrossReferenceError,
                                process)

PAGE = "e" * 64 + ".html"
CHILD_PAGE = "f" * 64 + ".html"
SPEC = textwrap.dedent(
    """\
    package OpenCV.Demo is
       type Mode is (Fast, Exact);
       subtype Count is Natural range 0 .. 9;
       type Pair is record
          Image : OpenCV.Core.Mat;
          Kind  : Mode;
       end record;
       type Pair_Array is array (Positive range <>) of Pair;
       type Colors is (Red, Green, Blue, Cyan, Magenta, Yellow);
       procedure Run
         (Image : OpenCV.Core.Mat; Kind : Mode := Fast; Area : OpenCV.Size);
       function Make (Value : Count) return Pair;
       function Probe (Value : OpenCV.Core.Absent; Unit : OpenCV.Angle_Unit)
          return Boolean;
       procedure Shadow (Count : Natural; Limit : Positive);
    end OpenCV.Demo;
    """
)
CHILD_SPEC = textwrap.dedent(
    """\
    package OpenCV.Demo.Child is
       type Item is record
          Image : Pair;
          Other : OpenCV.Demo.Mode;
          Early : Mode;
       end record;
       type Mode is (Slow, Careful);
       procedure Use_Mode (Kind : Mode);
       function Make_Item (Value : Count) return Item;
    end OpenCV.Demo.Child;
    """
)
CORE_ROOT = ("package OpenCV is\n   type Size is record\n      Width : Integer;\n"
             "   end record;\n   type Angle_Unit is (Radians, Degrees);\nend OpenCV;\n")
CORE = ("package OpenCV.Core is\n   type Mat is tagged private;\nprivate\n"
        "   type Mat is tagged record\n      Handle : Integer;\n   end record;\n"
        "end OpenCV.Core;\n")
SNIPPETS = [
    ("Colors", "type Colors is\n  (Red,\n   Green,\n   …,\n   Yellow);"),
    ("Count", "subtype Count is Natural range 0 .. 9;"),
    ("Make", "function Make (Value : Count) return Pair"),
    ("Mode", "type Mode is (Fast, Exact);"),
    ("Pair", "type Pair is record\n   Image : OpenCV.Core.Mat;\n   Kind  : Mode;\nend record;"),
    ("Pair_Array", "type Pair_Array is array (Positive range &lt;&gt;) of Pair;"),
    ("Probe", "function Probe (Value : OpenCV.Core.Absent; Unit : OpenCV.Angle_Unit)\n"
              "   return Boolean"),
    ("Run", "procedure Run\n  (Image : OpenCV.Core.Mat; Kind : Mode := Fast; "
            "Area : OpenCV.Size)"),
    ("Shadow", "procedure Shadow (Count : Natural; Limit : Positive)"),
]
CHILD_SNIPPETS = [
    ("Item", "type Item is record\n   Image : Pair;\n   Other : OpenCV.Demo.Mode;\n"
             "   Early : Mode;\nend record;"),
    ("Make_Item", "function Make_Item (Value : Count) return Item"),
    ("Mode", "type Mode is (Slow, Careful);"),
    ("Use_Mode", "procedure Use_Mode (Kind : Mode)"),
]
ANCHORS = {name: hashlib.sha256(name.encode()).hexdigest() for name, _ in SNIPPETS}
CHILD_ANCHORS = {name: hashlib.sha256(("child." + name).encode()).hexdigest()
                 for name, _ in CHILD_SNIPPETS}


def native_page(package, snippets, anchors):
    sections = "".join(
        f"<h4 id={anchors[name]}>{name}</h4><pre class=ada-code-snippet><code>"
        f"{code}\n</code></pre><p>About {name}." for name, code in snippets)
    return ("<!DOCTYPE html>\n<html class=main>\n" + NATIVE +
            f"<body class=content><h1>{package}</h1><h2>Description</h2>" + sections)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.src = base / "repo/src"
        self.src.mkdir(parents=True)
        (self.src / "opencv-demo.ads").write_text(SPEC, encoding="utf-8")
        (self.src / "opencv-demo-child.ads").write_text(CHILD_SPEC, encoding="utf-8")
        self.core = base / "core"
        (self.core / "src").mkdir(parents=True)
        (self.core / "src/opencv.ads").write_text(CORE_ROOT, encoding="utf-8")
        (self.core / "src/opencv-core.ads").write_text(CORE, encoding="utf-8")
        self.api = base / "_site/api"
        self.api.mkdir(parents=True)
        self.page = self.api / PAGE
        self.page.write_text(native_page("OpenCV.Demo", SNIPPETS, ANCHORS),
                             encoding="utf-8")
        self.child = self.api / CHILD_PAGE
        self.child.write_text(
            native_page("OpenCV.Demo.Child", CHILD_SNIPPETS, CHILD_ANCHORS),
            encoding="utf-8")
        (self.api / "index.html").write_text(
            "<!DOCTYPE html>\n<html class=main>\n" + NATIVE + "<body class=main>"
            f"<a href={PAGE} target=document-content>OpenCV.Demo</a>"
            f"<a href={CHILD_PAGE} target=document-content>OpenCV.Demo.Child</a>",
            encoding="utf-8")
        (self.api / "gnatdoc.css").write_text("/* native */\n", encoding="utf-8")

    def tearDown(self):
        self.temporary.cleanup()

    def run_step(self, step, *args, **options):
        with contextlib.redirect_stdout(io.StringIO()):
            return step(*args, **options)

    def link(self, **options):
        return self.run_step(process, self.api, self.src, self.core, **options)

    def enhance(self):
        self.run_step(install, self.api)
        self.link()
        self.link(highlight=True)

    def section(self, name, page=None):
        text = (page or self.page).read_text(encoding="utf-8")
        start = text.index(f">{name}</h4>")
        return text[start:text.index("</code>", start)]

    def edit(self, path, old, new):
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def assertCheckFails(self, fragment):
        with self.assertRaises(CrossReferenceError) as caught:
            self.link(check=True)
        self.assertIn(fragment, str(caught.exception))


class TypeLinkTest(Fixture):
    def test_links_local_and_core_types_only(self):
        counts, families = self.link()
        self.assertEqual(counts["linked"], 10)
        self.assertEqual(counts["external"], 4)
        run = self.section("Run")
        self.assertIn(f'<a class="type-reference" href="#{ANCHORS["Mode"]}" '
                      'data-type="opencv.demo.mode">Mode</a>', run)
        self.assertIn('<a class="type-reference" href="'
                      + CORE_DESTINATIONS["opencv.core"] +
                      '" data-type="opencv.core.mat" target="_top">OpenCV.Core.Mat</a>', run)
        self.assertIn('href="' + CORE_DESTINATIONS["opencv"] +
                      '" data-type="opencv.size" target="_top">OpenCV.Size</a>', run)
        self.assertIn('data-type="opencv.demo.pair">Pair</a>', self.section("Pair_Array"))
        self.assertIn('data-type="opencv.demo.count">Count</a>', self.section("Make"))
        self.assertIn('data-type="opencv.demo.pair">Pair</a>', self.section("Make"))

    def test_child_links_to_parent_page_and_own_page(self):
        self.link()
        item = self.section("Item", self.child)
        self.assertIn(f'<a class="type-reference" href="{PAGE}#{ANCHORS["Pair"]}" '
                      'data-type="opencv.demo.pair">Pair</a>', item)
        self.assertIn(f'href="{PAGE}#{ANCHORS["Mode"]}" '
                      'data-type="opencv.demo.mode">OpenCV.Demo.Mode</a>', item)
        make = self.section("Make_Item", self.child)
        self.assertIn(f'href="{PAGE}#{ANCHORS["Count"]}" '
                      'data-type="opencv.demo.count">Count</a>', make)
        self.assertIn(f'href="#{CHILD_ANCHORS["Item"]}" '
                      'data-type="opencv.demo.child.item">Item</a>', make)
        self.assertIn(f'href="#{CHILD_ANCHORS["Mode"]}" '
                      'data-type="opencv.demo.child.mode">Mode</a>',
                      self.section("Use_Mode", self.child))

    def test_parent_name_redeclared_by_child_is_not_linked(self):
        self.link()
        item = self.section("Item", self.child)
        self.assertNotIn(">Mode</a>", item)
        self.assertEqual(item.count("type-reference"), 2)

    def test_standard_unknown_and_shadowed_names_stay_unlinked(self):
        self.link()
        probe = self.section("Probe")
        self.assertNotIn("opencv.core.absent", probe)
        self.assertIn('data-type="opencv.angle_unit"', probe)
        self.assertNotIn("type-reference", self.section("Shadow"))
        self.assertNotIn(">Natural</a>", self.section("Count"))
        self.assertNotIn(">Boolean</a>", probe)

    def test_text_is_preserved_and_elided_enumeration_matches(self):
        self.link()
        self.assertEqual(LINK.sub(lambda m: m[3], self.page.read_text(encoding="utf-8")),
                         native_page("OpenCV.Demo", SNIPPETS, ANCHORS))
        self.assertEqual(
            LINK.sub(lambda m: m[3], self.child.read_text(encoding="utf-8")),
            native_page("OpenCV.Demo.Child", CHILD_SNIPPETS, CHILD_ANCHORS))

    def test_check_passes_and_repeated_steps_are_byte_identical(self):
        self.enhance()
        snapshot = {p.name: p.read_bytes() for p in self.api.iterdir()}
        self.link(check=True)
        self.enhance()
        self.assertEqual({p.name: p.read_bytes() for p in self.api.iterdir()}, snapshot)
        self.run_step(check_theme, self.api)

    def test_wrong_but_existing_destination_is_rejected(self):
        self.link()
        self.edit(self.page, f'href="#{ANCHORS["Mode"]}"', f'href="#{ANCHORS["Pair"]}"')
        self.assertCheckFails("type identity/destination/markup mismatch")

    def test_wrong_but_existing_cross_page_destination_is_rejected(self):
        self.link()
        self.edit(self.child, f'href="{PAGE}#{ANCHORS["Pair"]}"',
                  f'href="{PAGE}#{ANCHORS["Pair_Array"]}"')
        self.assertCheckFails("type identity/destination/markup mismatch: Item")

    def test_cross_page_anchor_on_own_page_is_rejected(self):
        self.link()
        self.edit(self.child, f'href="{PAGE}#{ANCHORS["Count"]}"',
                  f'href="#{ANCHORS["Count"]}"')
        self.assertCheckFails("type identity/destination/markup mismatch: Make_Item")

    def test_fabricated_core_fragment_is_rejected(self):
        self.link()
        self.edit(self.page, CORE_DESTINATIONS["opencv.core"] + '"',
                  CORE_DESTINATIONS["opencv.core"] + '#mat"')
        self.assertCheckFails("type identity/destination/markup mismatch")

    def test_removed_core_type_is_rejected(self):
        self.link()
        self.edit(self.core / "src/opencv.ads", "type Angle_Unit", "type Angle_Kind")
        self.assertCheckFails("type identity/destination/markup mismatch")

    def test_modified_declaration_text_is_rejected(self):
        self.link()
        self.edit(self.page, "Limit : Positive", "Limit : Natural")
        self.assertCheckFails("source profile not unique")

    def test_declaration_on_the_other_page_is_rejected(self):
        self.edit(self.child, "<h4 id=", "<h4 id=x" + ANCHORS["Make"] + ">Make</h4>"
                  "<pre class=ada-code-snippet><code>function Make (Value : Count) "
                  "return Pair\n</code></pre><h4 id=")
        with self.assertRaises(CrossReferenceError) as caught:
            self.link()
        self.assertIn("source profile not unique", str(caught.exception))

    def test_modified_html_outside_snippets_is_rejected(self):
        self.link()
        self.edit(self.child, "<p>About Item.", "<p>About Items.")
        self.assertCheckFails("non-snippet HTML changed")

    def test_missing_or_corrupted_manifest_is_rejected(self):
        self.link()
        manifest = self.api / "type-crossrefs.json"
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["pages"][PAGE]["snippets"][1] = (
            data["pages"][PAGE]["snippets"][1].replace("0 .. 9", "0 .. 8"))
        manifest.write_text(json.dumps(data), encoding="utf-8")
        self.assertCheckFails("original Ada declaration text changed")
        manifest.unlink()
        self.assertCheckFails("missing cross-reference integrity manifest")

    def test_manifest_without_a_page_is_rejected(self):
        self.link()
        manifest = self.api / "type-crossrefs.json"
        data = json.loads(manifest.read_text(encoding="utf-8"))
        del data["pages"][CHILD_PAGE]
        manifest.write_text(json.dumps(data), encoding="utf-8")
        self.assertCheckFails("manifest package page mismatch")

    def test_missing_package_page_is_rejected(self):
        self.child.unlink()
        with self.assertRaises(CrossReferenceError) as caught:
            self.link()
        self.assertIn("public source/page coverage mismatch", str(caught.exception))

    def test_unknown_markup_in_snippet_is_rejected(self):
        self.edit(self.page, "function Make", "<b>function</b> Make")
        with self.assertRaises(CrossReferenceError):
            self.link()

    def test_linking_without_manifest_after_linking_is_rejected(self):
        self.link()
        (self.api / "type-crossrefs.json").unlink()
        with self.assertRaises(CrossReferenceError):
            self.link()

    def test_highlight_requires_qualified_links(self):
        with self.assertRaises(CrossReferenceError):
            self.link(highlight=True)


class ThemeTest(Fixture):
    def test_theme_installs_metadata_once_and_verifies(self):
        self.run_step(install, self.api)
        for page in (self.page, self.child):
            text = page.read_text(encoding="utf-8")
            self.assertEqual(text.count('href="gnatdoc-theme.css"'), 1)
            self.assertIn('<meta name="viewport"', text)
        text = self.page.read_text(encoding="utf-8")
        self.run_step(install, self.api)
        self.assertEqual(self.page.read_text(encoding="utf-8"), text)

    def test_theme_rejects_native_and_asset_changes(self):
        self.run_step(install, self.api)
        (self.api / "gnatdoc-theme.css").write_text("body{}", encoding="utf-8")
        with self.assertRaises(CrossReferenceError):
            self.run_step(check_theme, self.api)

    def test_theme_rejects_changed_native_stylesheet(self):
        self.run_step(install, self.api)
        (self.api / "gnatdoc.css").write_text("/* changed */", encoding="utf-8")
        with self.assertRaises(CrossReferenceError):
            self.run_step(check_theme, self.api)

    def test_theme_rejects_non_snippet_change(self):
        self.run_step(install, self.api)
        self.edit(self.child, "<p>About Mode.", "<p>About Mode!")
        with self.assertRaises(CrossReferenceError):
            self.run_step(check_theme, self.api)

    def test_theme_rejects_an_added_page(self):
        self.run_step(install, self.api)
        (self.api / ("a" * 64 + ".html")).write_text(
            self.page.read_text(encoding="utf-8"), encoding="utf-8")
        with self.assertRaises(CrossReferenceError):
            self.run_step(check_theme, self.api)


class HighlightTest(unittest.TestCase):
    def assert_token(self, text, category, value):
        output = highlight(text)
        self.assertIn(f'<span class="ada-{category}">{value}</span>', output)
        self.assertEqual(strip_highlighting(output), text)

    def test_keywords_respect_identifier_boundaries(self):
        self.assert_token('FuNcTiOn functional return_value RETURN', 'keyword', 'FuNcTiOn')
        self.assertNotIn('>functional</span>', highlight('functional'))

    def test_literals_attributes_and_operators(self):
        self.assert_token('"return ""x"""', 'string', '"return ""x"""')
        self.assert_token("'A'", 'character', "'A'")
        self.assert_token("A'Last", 'attribute', "'Last")
        for number in ('0', '1.0', '16#FF#', '2_147_483_647', '1.0e-5'):
            self.assert_token(number, 'number', number)
        for operator in (':=', '=&gt;', '..', '&lt;&gt;', '**'):
            self.assert_token(operator, 'operator', operator)

    def test_links_with_top_target_stay_atomic(self):
        link = ('<a class="type-reference" href="' + CORE_DESTINATIONS["opencv.core"] +
                '" data-type="opencv.core.mat" target="_top">OpenCV.Core.Mat</a>')
        output = highlight('function F return ' + link)
        self.assertEqual([m[0] for m in LINK.finditer(output)], [link])

    def test_cross_page_links_stay_atomic(self):
        link = ('<a class="type-reference" href="' + PAGE + '#' + ANCHORS["Pair"] +
                '" data-type="opencv.demo.pair">Pair</a>')
        output = highlight('procedure P (X : ' + link + ')')
        self.assertEqual([m[0] for m in LINK.finditer(output)], [link])


if __name__ == "__main__":
    unittest.main()
